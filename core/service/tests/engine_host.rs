//! Integration coverage for the Phase 1 engine host.
//!
//! These tests exercise the boundaries the service owns rather than the engine
//! internals: launcher flag parsing, what `service.health` reports about the
//! media toolchain and the inference assets, the service-owned inference rule
//! for `engine.tracking.start`, and `engine.probe` through a fake `ffprobe`.
//!
//! The service resolves and publishes the tool paths chosen on the command
//! line, so every test starts from real launcher arguments (the same
//! `parse_args` the binary uses) and then calls `Config::prepare_runtime`.
//! Environment changes are process-wide, so [`ENV_LOCK`] serializes the tests
//! in this binary and [`EnvScope`] restores the variables afterwards.

use std::ffi::OsString;
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::sync::Mutex;
use std::thread::{self, JoinHandle};
use std::time::Duration;

use serde_json::{json, Value};
use sportcut_protocol::{code, read_frame, write_frame};
use sportcut_service::config::{
    parse_args, Parsed, FFMPEG_ENV, FFPROBE_ENV, PERSON_MODEL_ENV, TFLITE_LIBRARY_ENV,
};
use sportcut_service::server::{BindResult, Server, ServerHandle};

/// Serializes tests that start a service or mutate the process environment.
static ENV_LOCK: Mutex<()> = Mutex::new(());

const TOOL_ENV_VARS: [&str; 4] = [
    FFMPEG_ENV,
    FFPROBE_ENV,
    TFLITE_LIBRARY_ENV,
    PERSON_MODEL_ENV,
];

/// Saves the media/inference environment and clears it for the test.
struct EnvScope {
    saved: Vec<(&'static str, Option<OsString>)>,
}

impl EnvScope {
    fn clear() -> Self {
        let saved = TOOL_ENV_VARS
            .iter()
            .map(|name| (*name, std::env::var_os(name)))
            .collect();
        for name in TOOL_ENV_VARS {
            std::env::remove_var(name);
        }
        Self { saved }
    }
}

impl Drop for EnvScope {
    fn drop(&mut self) {
        for (name, value) in self.saved.drain(..) {
            match value {
                Some(value) => std::env::set_var(name, value),
                None => std::env::remove_var(name),
            }
        }
    }
}

/// One running service plus the temporary directory that owns its files.
struct TestService {
    _directory: tempfile::TempDir,
    state_root: PathBuf,
    endpoint: PathBuf,
    token: String,
    handle: ServerHandle,
    completion: mpsc::Receiver<anyhow::Result<()>>,
    thread: Option<JoinHandle<()>>,
}

impl TestService {
    /// Start the service from launcher flags, just as the app would.
    fn start_with_flags(extra: &[&str]) -> Self {
        let directory = tempfile::tempdir().expect("temp dir");
        let state_root = directory.path().join("state");
        let endpoint = directory.path().join("run").join("s.sock");

        let mut args: Vec<OsString> = vec![
            "--state-root".into(),
            state_root.into_os_string(),
            "--endpoint".into(),
            endpoint.into_os_string(),
            "--idle-exit-seconds".into(),
            "60".into(),
        ];
        args.extend(extra.iter().map(OsString::from));

        let Parsed::Run(mut config) = parse_args(args).expect("parse launcher flags") else {
            panic!("expected a run command");
        };
        // The binary does this after parsing; the tests mirror that seam.
        config.prepare_runtime();

        let state_root = config.state_root.clone();
        let server = match Server::bind(config).expect("bind") {
            BindResult::Started(server) => server,
            BindResult::AlreadyRunning { endpoint } => {
                panic!(
                    "unexpected already-running instance at {}",
                    endpoint.display()
                )
            }
        };

        let token = std::fs::read_to_string(server.token_file()).expect("read token");
        let endpoint = server.endpoint().to_path_buf();
        let handle = server.handle();
        let (sender, completion) = mpsc::channel();
        let thread = thread::spawn(move || {
            let _ = sender.send(server.run());
        });

        Self {
            _directory: directory,
            state_root,
            endpoint,
            token,
            handle,
            completion,
            thread: Some(thread),
        }
    }

    fn connect(&self) -> UnixStream {
        let stream = UnixStream::connect(&self.endpoint).expect("connect");
        stream
            .set_read_timeout(Some(Duration::from_secs(5)))
            .expect("read timeout");
        stream
            .set_write_timeout(Some(Duration::from_secs(5)))
            .expect("write timeout");
        stream
    }

    fn connected(&self) -> UnixStream {
        let mut stream = self.connect();
        send(&mut stream, &hello_request(&self.token));
        let response = receive(&mut stream);
        assert_eq!(response["id"], 1, "handshake response id");
        assert_eq!(response["result"]["service"]["name"], "sportcutd");
        stream
    }

    /// A recording inside the service-owned recording store.
    fn recording(&self, match_id: &str, name: &str, contents: &[u8]) -> PathBuf {
        let directory = self.state_root.join("recordings").join(match_id);
        std::fs::create_dir_all(&directory).expect("recording directory");
        let path = directory.join(name);
        std::fs::write(&path, contents).expect("write recording");
        path
    }

    fn call(&mut self, stream: &mut UnixStream, id: i64, method: &str, params: Value) -> Value {
        send(
            stream,
            &json!({ "jsonrpc": "2.0", "id": id, "method": method, "params": params }),
        );
        let response = receive(stream);
        assert_eq!(response["id"], id, "response id for {method}");
        response
    }

    fn wait(&mut self) {
        let result = self
            .completion
            .recv_timeout(Duration::from_secs(5))
            .expect("the service exits within five seconds");
        result.expect("the service run loop succeeds");
        if let Some(thread) = self.thread.take() {
            thread.join().expect("the server thread joins");
        }
    }
}

impl Drop for TestService {
    fn drop(&mut self) {
        if self.thread.is_some() {
            self.handle.shutdown("test teardown");
        }
    }
}

fn hello_request(token: &str) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "service.hello",
        "params": {
            "protocol": { "major": 1, "minor": 0 },
            "client": {
                "name": "Sportcut.app",
                "version": "0.1.0",
                "build": "test-build",
            },
            "token": token,
            "capabilities": ["engine.v1", "notifications.v1"],
        },
    })
}

fn send(stream: &mut UnixStream, message: &Value) {
    write_frame(stream, message).expect("write frame");
}

fn receive(stream: &mut UnixStream) -> Value {
    read_frame(stream).expect("read frame")
}

fn parse(args: &[&str]) -> anyhow::Result<Parsed> {
    parse_args(args.iter().map(OsString::from))
}

/// Write an executable shell script and return its path.
fn executable_script(directory: &Path, name: &str, body: &str) -> PathBuf {
    let path = directory.join(name);
    std::fs::write(&path, body).expect("write script");
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).expect("chmod");
    path
}

/// A fake `ffmpeg` that only answers `-version`, as health asks it to.
const FAKE_FFMPEG: &str = "#!/bin/sh\necho 'ffmpeg version 9.9-fake'\n";

/// A fake `ffprobe` that prints a valid probe document for any input.
const FAKE_FFPROBE: &str = r#"#!/bin/sh
cat <<'JSON'
{
  "format": { "duration": "12.5" },
  "streams": [
    {
      "codec_type": "video",
      "width": 1280,
      "height": 720,
      "duration": "12.5",
      "avg_frame_rate": "30/1",
      "r_frame_rate": "30/1",
      "nb_frames": "375",
      "side_data_list": [{ "rotation": -90 }],
      "tags": { "rotate": "0" }
    },
    { "codec_type": "audio" }
  ]
}
JSON
"#;

fn fake_media_tools(directory: &Path) -> (PathBuf, PathBuf) {
    (
        executable_script(directory, "ffmpeg", FAKE_FFMPEG),
        executable_script(directory, "ffprobe", FAKE_FFPROBE),
    )
}

/// The complete player-tracking config, mirroring the app's defaults.
fn tracking_config() -> Value {
    json!({
        "samplingRate": 5.0,
        "minConfidence": 0.2,
        "courtMargin": 0.04,
        "netMargin": 0.05,
        "maxTrackGapMs": 1200,
        "maxFrameGapMs": 500,
        "maxGroundSpeedPerSecond": 0.8,
        "ambiguityMargin": 0.1,
        "minTrackObservations": 3,
        "minCountFrames": 5,
        "minCountFraction": 0.7,
    })
}

fn vision_is_built_in() -> bool {
    cfg!(all(target_os = "macos", feature = "macos-tflite-eval"))
}

// ---------------------------------------------------------------------------
// 1. Launcher configuration
// ---------------------------------------------------------------------------

#[test]
fn config_parses_media_and_inference_paths() {
    let directory = tempfile::tempdir().expect("temp dir");
    let (ffmpeg, ffprobe) = fake_media_tools(directory.path());
    let runtime = directory.path().join("libtensorflowlite_c.dylib");
    let model = directory.path().join("model.tflite");
    std::fs::write(&runtime, b"runtime").expect("write runtime");
    std::fs::write(&model, b"model").expect("write model");

    let Parsed::Run(config) = parse(&[
        "--state-root",
        "/state",
        "--endpoint",
        "/run/s.sock",
        "--ffmpeg",
        ffmpeg.to_str().expect("utf8"),
        "--ffprobe",
        ffprobe.to_str().expect("utf8"),
        "--tflite-library",
        runtime.to_str().expect("utf8"),
        "--person-model",
        model.to_str().expect("utf8"),
    ])
    .expect("parse") else {
        panic!("expected a run command");
    };

    assert_eq!(config.ffmpeg, Some(ffmpeg));
    assert_eq!(config.ffprobe, Some(ffprobe));
    assert_eq!(config.tflite_library, Some(runtime));
    assert_eq!(config.person_model, Some(model));
}

#[test]
fn config_rejects_flags_without_values() {
    for flag in [
        "--ffmpeg",
        "--ffprobe",
        "--tflite-library",
        "--person-model",
    ] {
        let error = parse(&["--state-root", "/state", "--endpoint", "/run/s.sock", flag])
            .expect_err("a flag without a value must fail");
        let message = format!("{error:#}");
        assert!(
            message.contains(flag) && message.contains("requires a value"),
            "{flag}: {message}"
        );
    }
}

#[test]
fn config_rejects_a_non_executable_media_path() {
    let directory = tempfile::tempdir().expect("temp dir");
    let not_executable = directory.path().join("ffprobe");
    std::fs::write(&not_executable, b"#!/bin/sh\n").expect("write file");

    let error = parse(&[
        "--state-root",
        "/state",
        "--endpoint",
        "/run/s.sock",
        "--ffprobe",
        not_executable.to_str().expect("utf8"),
    ])
    .expect_err("a file without an execute bit is not a tool");
    let message = format!("{error:#}");
    assert!(message.contains("--ffprobe"), "{message}");
    assert!(message.contains("executable"), "{message}");
}

#[test]
fn an_invalid_ffprobe_path_is_rejected_at_startup() {
    let directory = tempfile::tempdir().expect("temp dir");
    let missing = directory.path().join("missing-ffprobe");
    let not_executable = directory.path().join("plain-file");
    std::fs::write(&not_executable, b"not a program").expect("write file");

    for (label, path) in [
        ("missing", missing.as_path()),
        ("non-executable", not_executable.as_path()),
    ] {
        let error = parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--ffprobe",
            path.to_str().expect("utf8"),
        ])
        .expect_err("an invalid ffprobe path must be rejected before binding");
        assert!(
            format!("{error:#}").contains("executable"),
            "{label}: {error:#}"
        );
    }
}

// ---------------------------------------------------------------------------
// 2. Vision health
// ---------------------------------------------------------------------------

#[test]
fn health_reports_vision_unavailable_without_the_feature_or_assets() {
    let _guard = ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let _env = EnvScope::clear();

    let mut service = TestService::start_with_flags(&[]);
    let mut stream = service.connected();
    let health = service.call(&mut stream, 2, "service.health", json!({}));

    let vision = &health["result"]["vision"];
    assert_eq!(vision["available"], json!(false), "{health}");
    let detail = vision["detail"]
        .as_str()
        .expect("an unavailable runtime explains itself");
    if vision_is_built_in() {
        assert!(detail.contains("not configured"), "{detail}");
    } else {
        assert!(detail.contains("macos-tflite-eval"), "{detail}");
    }
    assert!(vision.get("runtimePath").is_some());
    assert!(vision.get("modelPath").is_some());

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn health_reports_a_present_but_unsupported_model_as_not_runnable() {
    let _guard = ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let _env = EnvScope::clear();

    let tools = tempfile::tempdir().expect("toolchain dir");
    let (ffmpeg, ffprobe) = fake_media_tools(tools.path());
    let directory = tempfile::tempdir().expect("asset dir");
    let runtime = directory.path().join("libtensorflowlite_c.dylib");
    let model = directory.path().join("model.tflite");
    std::fs::write(&runtime, b"runtime").expect("write runtime");
    std::fs::write(&model, b"not the trial model").expect("write model");

    let mut service = TestService::start_with_flags(&[
        "--ffmpeg",
        ffmpeg.to_str().expect("utf8"),
        "--ffprobe",
        ffprobe.to_str().expect("utf8"),
        "--tflite-library",
        runtime.to_str().expect("utf8"),
        "--person-model",
        model.to_str().expect("utf8"),
    ]);
    let mut stream = service.connected();
    let health = service.call(&mut stream, 2, "service.health", json!({}));

    let vision = &health["result"]["vision"];
    assert_eq!(
        vision["assetsPresent"],
        json!(true),
        "both files exist: {health}"
    );
    assert_eq!(
        vision["available"],
        json!(false),
        "a present but unsupported model is not runnable: {health}"
    );
    assert_eq!(
        health["result"]["status"],
        json!("degraded"),
        "health must not claim ok when tracking is guaranteed to fail: {health}"
    );
    let detail = vision["detail"]
        .as_str()
        .expect("an unavailable runtime explains itself");
    if vision_is_built_in() {
        assert!(
            detail.contains("EfficientDet-Lite0") && detail.contains("fingerprint"),
            "{detail}"
        );
    } else {
        assert!(detail.contains("macos-tflite-eval"), "{detail}");
    }

    service.handle.shutdown("test complete");
    service.wait();
}

#[cfg(all(target_os = "macos", feature = "macos-tflite-eval"))]
#[test]
fn health_reports_vision_available_with_the_supported_trial_model() {
    let _guard = ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let _env = EnvScope::clear();

    // The supported model is a pinned binary asset; CI without the fetched
    // asset cannot exercise the positive path, so skip rather than assert on
    // bytes that are not the trial file.
    let supported_model =
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../third_party/inference/model.tflite");
    if !supported_model.is_file() {
        eprintln!("skipping: run tools/fetch-inference-assets.sh to provide the trial model");
        return;
    }

    let directory = tempfile::tempdir().expect("temp dir");
    let runtime = directory.path().join("libtensorflowlite_c.dylib");
    std::fs::write(&runtime, b"runtime").expect("write runtime");

    let mut service = TestService::start_with_flags(&[
        "--tflite-library",
        runtime.to_str().expect("utf8"),
        "--person-model",
        supported_model.to_str().expect("utf8"),
    ]);
    let mut stream = service.connected();
    let health = service.call(&mut stream, 2, "service.health", json!({}));

    let vision = &health["result"]["vision"];
    assert_eq!(vision["available"], json!(true), "{health}");
    assert_eq!(vision["assetsPresent"], json!(true), "{health}");
    assert_eq!(
        vision["modelFingerprint"],
        json!(sportcut_api::track_artifact::TRIAL_MODEL_FINGERPRINT),
        "{health}"
    );
    assert_eq!(
        vision["runtimePath"].as_str(),
        Some(runtime.to_str().expect("utf8"))
    );
    assert_eq!(
        vision["modelPath"].as_str(),
        Some(supported_model.to_str().expect("utf8"))
    );
    assert!(vision["detail"].is_null(), "{vision}");

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn health_reports_assets_resolved_from_the_environment() {
    let _guard = ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let _env = EnvScope::clear();

    let directory = tempfile::tempdir().expect("asset dir");
    let runtime = directory.path().join("libtensorflowlite_c.dylib");
    let model = directory.path().join("model.tflite");
    std::fs::write(&runtime, b"runtime").expect("write runtime");
    std::fs::write(&model, b"model").expect("write model");

    // No flags: the documented fallback is the environment.
    std::env::set_var(TFLITE_LIBRARY_ENV, &runtime);
    std::env::set_var(PERSON_MODEL_ENV, &model);

    let mut service = TestService::start_with_flags(&[]);
    let mut stream = service.connected();
    let health = service.call(&mut stream, 2, "service.health", json!({}));

    let vision = &health["result"]["vision"];
    assert_eq!(
        vision["runtimePath"].as_str(),
        Some(runtime.to_str().expect("utf8")),
        "{health}"
    );
    assert_eq!(
        vision["modelPath"].as_str(),
        Some(model.to_str().expect("utf8")),
        "{health}"
    );
    assert_eq!(vision["assetsPresent"], json!(true), "{health}");

    service.handle.shutdown("test complete");
    service.wait();
}

// ---------------------------------------------------------------------------
// 3-4. Player-tracking asset ownership
// ---------------------------------------------------------------------------

#[test]
fn tracking_rejects_client_supplied_inference_assets() {
    let _guard = ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let _env = EnvScope::clear();

    let mut service = TestService::start_with_flags(&[]);
    let mut stream = service.connected();

    for field in ["runtimePath", "modelPath"] {
        let mut params = json!({ "matchId": "match-1", "config": {} });
        params[field] = json!("/tmp/client-supplied-asset");

        let response = service.call(&mut stream, 3, "engine.tracking.start", params);
        assert_eq!(
            response["error"]["code"],
            json!(code::INVALID_PARAMS),
            "{field}: {response}"
        );
        assert_eq!(
            response["error"]["data"]["kind"],
            json!("invalid_params"),
            "{field}: {response}"
        );
        let message = response["error"]["message"]
            .as_str()
            .expect("diagnostic message");
        assert!(message.contains("service-owned"), "{field}: {message}");
        assert!(message.contains(field), "{field}: {message}");
    }

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn tracking_without_assets_reports_an_actionable_error() {
    let _guard = ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let _env = EnvScope::clear();

    let mut service = TestService::start_with_flags(&[]);
    let mut stream = service.connected();

    let response = service.call(
        &mut stream,
        4,
        "engine.tracking.start",
        json!({ "matchId": "match-1", "config": tracking_config() }),
    );

    let error = response.get("error").expect("the request fails");
    let message = error["message"].as_str().expect("diagnostic message");
    // A missing inference asset is an availability problem, never an
    // unexpected `internal` failure, in both build configurations.
    assert_eq!(error["code"], json!(code::UNSUPPORTED), "{response}");
    if vision_is_built_in() {
        assert!(
            message.contains("SPORTCUT_TFLITE_LIBRARY")
                || message.contains("SPORTCUT_PERSON_MODEL"),
            "a missing asset names the environment variable to set: {message}"
        );
    } else {
        assert!(message.contains("macos-tflite-eval"), "{message}");
    }

    service.handle.shutdown("test complete");
    service.wait();
}

// ---------------------------------------------------------------------------
// 5-6. Engine probe through the configured toolchain
// ---------------------------------------------------------------------------

#[test]
fn probe_uses_the_configured_ffprobe() {
    let _guard = ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let _env = EnvScope::clear();

    let tools = tempfile::tempdir().expect("toolchain dir");
    let (ffmpeg, ffprobe) = fake_media_tools(tools.path());

    let mut service = TestService::start_with_flags(&[
        "--ffmpeg",
        ffmpeg.to_str().expect("utf8"),
        "--ffprobe",
        ffprobe.to_str().expect("utf8"),
    ]);
    let clip = service.recording("match-1", "clip.mp4", b"fake recording bytes");
    let mut stream = service.connected();

    let response = service.call(
        &mut stream,
        5,
        "engine.probe",
        json!({
            "source": { "kind": "path", "value": clip.to_str().expect("utf8") }
        }),
    );
    assert!(
        response.get("error").is_none(),
        "probe must succeed through the fake ffprobe: {response}"
    );

    let metadata = &response["result"];
    let canonical = std::fs::canonicalize(&clip).expect("canonical clip");
    assert_eq!(
        metadata["path"].as_str(),
        Some(canonical.to_str().expect("utf8"))
    );
    assert_eq!(metadata["durationSeconds"].as_f64(), Some(12.5));
    assert_eq!(metadata["frameRate"].as_f64(), Some(30.0));
    assert_eq!(metadata["width"], json!(1280));
    assert_eq!(metadata["height"], json!(720));
    assert_eq!(metadata["rotationDegrees"], json!(270));
    assert_eq!(metadata["orientation"], json!("portrait_reversed"));
    assert_eq!(metadata["hasAudio"], json!(true));
    assert_eq!(metadata["sizeBytes"], json!(20));

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn health_reflects_the_configured_media_toolchain() {
    let _guard = ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let _env = EnvScope::clear();

    let tools = tempfile::tempdir().expect("toolchain dir");
    let (ffmpeg, ffprobe) = fake_media_tools(tools.path());

    let mut service = TestService::start_with_flags(&[
        "--ffmpeg",
        ffmpeg.to_str().expect("utf8"),
        "--ffprobe",
        ffprobe.to_str().expect("utf8"),
    ]);
    let mut stream = service.connected();

    let health = service.call(&mut stream, 6, "service.health", json!({}));
    let toolchain = &health["result"]["toolchain"];

    assert_eq!(toolchain["available"], json!(true), "{health}");
    assert_eq!(
        toolchain["ffmpeg"].as_str(),
        Some(ffmpeg.to_str().expect("utf8"))
    );
    assert_eq!(
        toolchain["ffprobe"].as_str(),
        Some(ffprobe.to_str().expect("utf8"))
    );
    assert_eq!(
        toolchain["version"].as_str(),
        Some("ffmpeg version 9.9-fake")
    );

    service.handle.shutdown("test complete");
    service.wait();
}
