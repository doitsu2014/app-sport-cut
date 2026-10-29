//! End-to-end transport tests over a real Unix domain socket.
//!
//! Each test uses a temporary state root and a socket path inside it, so no
//! test touches the developer's Application Support directory. The protocol
//! helpers are the same codec the service uses, which keeps the fixtures honest
//! without re-testing the framing crate.

use std::io::Write;
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::sync::mpsc;
use std::thread::{self, JoinHandle};
use std::time::Duration;

use serde_json::{json, Value};
use sportcut_protocol::{read_frame, write_frame, FrameError, MAX_FRAME_BYTES};
use sportcut_service::config::Config;
use sportcut_service::server::{BindResult, Server, ServerHandle};

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
    fn start() -> Self {
        Self::start_with(|_config| {})
    }

    fn start_with(configure: impl FnOnce(&mut Config)) -> Self {
        let directory = tempfile::tempdir().expect("temp dir");
        let state_root = directory.path().join("state");
        let endpoint = directory.path().join("run").join("s.sock");

        let mut config = Config::new(state_root.clone(), endpoint.clone());
        config.idle_exit_seconds = 60;
        configure(&mut config);

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
    hello_request_with(token, &["engine.v1", "catalog.v1", "notifications.v1"])
}

fn hello_request_with(token: &str, capabilities: &[&str]) -> Value {
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
            "capabilities": capabilities,
        },
    })
}

fn send(stream: &mut UnixStream, message: &Value) {
    write_frame(stream, message).expect("write frame");
}

fn receive(stream: &mut UnixStream) -> Value {
    read_frame(stream).expect("read frame")
}

#[test]
fn the_service_binds_and_accepts_a_connection() {
    let mut service = TestService::start();

    assert!(service.endpoint.exists(), "the socket file exists");
    assert!(service.state_root.join("run").is_dir());
    assert!(service.state_root.join("recordings").is_dir());
    assert!(service.state_root.join("matches").is_dir());
    assert!(service.state_root.join("render-inputs").is_dir());

    let _stream = service.connect();
    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn hello_with_a_valid_token_returns_the_service_contract() {
    let mut service = TestService::start();
    let mut stream = service.connect();

    send(&mut stream, &hello_request(&service.token));
    let response = receive(&mut stream);

    assert_eq!(response["jsonrpc"], "2.0");
    assert_eq!(response["id"], 1);
    let result = &response["result"];
    assert_eq!(result["service"]["name"], "sportcutd");
    assert_eq!(result["service"]["version"], env!("CARGO_PKG_VERSION"));
    assert_eq!(result["protocol"], json!({ "major": 1, "minor": 0 }));
    assert_eq!(
        result["capabilities"],
        json!(["engine.v1", "notifications.v1"]),
        "catalog.v1 is offered but not served by this build"
    );
    assert_eq!(
        result["stateRoot"],
        service.state_root.to_string_lossy().as_ref()
    );
    assert_eq!(
        result["endpoint"],
        service.endpoint.to_string_lossy().as_ref()
    );
    let expected_recordings = format!(
        "{}/recordings",
        result["stateRoot"].as_str().expect("state root")
    );
    assert_eq!(
        result["paths"]["recordings"].as_str(),
        Some(expected_recordings.as_str())
    );
    assert_eq!(result["limits"]["maxFrameBytes"], 16_777_216);
    assert_eq!(result["limits"]["endpointMaxBytes"], 103);
    assert_eq!(result["catalog"]["owner"], "client");

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn hello_with_a_bad_token_is_unauthorized_and_closes_the_connection() {
    let mut service = TestService::start();
    let mut stream = service.connect();

    send(&mut stream, &hello_request("not-the-token"));
    let response = receive(&mut stream);

    assert_eq!(response["error"]["code"], -32000);
    assert_eq!(response["error"]["data"]["kind"], "unauthorized");
    assert_eq!(response["error"]["data"]["retryable"], false);
    assert!(response["result"].is_null());

    let closed = read_frame(&mut stream);
    assert!(
        closed.is_err(),
        "the connection closes after a failed handshake"
    );

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn ping_after_the_handshake_reports_uptime() {
    let mut service = TestService::start();
    let mut stream = service.connected();

    send(
        &mut stream,
        &json!({ "jsonrpc": "2.0", "id": 2, "method": "service.ping", "params": {} }),
    );
    let response = receive(&mut stream);

    assert_eq!(response["id"], 2);
    assert_eq!(response["result"]["pong"], true);
    assert!(response["result"]["uptimeMs"].as_u64().is_some());

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn an_oversized_frame_is_rejected_with_frame_too_large_and_closed() {
    let mut service = TestService::start();
    let mut stream = service.connect();

    let declared = (MAX_FRAME_BYTES + 1) as u32;
    stream
        .write_all(&declared.to_be_bytes())
        .expect("write frame prefix");

    let response = receive(&mut stream);
    assert_eq!(response["error"]["code"], -32003);
    assert_eq!(response["error"]["data"]["kind"], "frame_too_large");
    assert_eq!(response["id"], Value::Null);

    assert!(matches!(read_frame(&mut stream), Err(FrameError::Io(_))));

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn an_endpoint_longer_than_103_bytes_refuses_to_start() {
    let directory = tempfile::tempdir().expect("temp dir");
    let state_root = directory.path().join("state");
    let endpoint = directory.path().join("s".repeat(104));
    let config = Config::new(state_root.clone(), endpoint.clone());

    let error = match Server::bind(config) {
        Ok(_) => panic!("binding a too-long endpoint must fail"),
        Err(error) => error,
    };
    let message = format!("{error:#}");

    assert!(message.contains("endpoint_too_long"), "{message}");
    assert!(message.contains("103"), "{message}");
    assert!(
        message.contains(&endpoint.to_string_lossy().to_string()),
        "{message}"
    );
    assert!(!endpoint.exists(), "no socket is created");
    assert!(!state_root.exists(), "no state is created before the check");
}

#[test]
fn service_shutdown_is_accepted_and_the_process_exits() {
    let mut service = TestService::start();
    let mut stream = service.connected();

    send(
        &mut stream,
        &json!({
            "jsonrpc": "2.0",
            "id": 9,
            "method": "service.shutdown",
            "params": { "cancelRunningJobs": true, "reason": "app quit" },
        }),
    );
    let response = receive(&mut stream);
    assert_eq!(response["id"], 9);
    assert_eq!(response["result"]["accepted"], true);

    let notification = receive(&mut stream);
    assert_eq!(notification["method"], "service.shutdown");
    assert!(notification.get("id").is_none());
    assert_eq!(notification["params"]["reason"], "app quit");
    assert!(
        notification["params"]["deadlineMs"].as_u64().is_some(),
        "the notification names a deadline"
    );

    service.wait();
    assert!(!service.endpoint.exists(), "the socket is removed on exit");
}

#[test]
fn an_unknown_engine_method_is_not_found() {
    let mut service = TestService::start();
    let mut stream = service.connected();

    send(
        &mut stream,
        &json!({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "engine.start.doesNotExist",
            "params": {},
        }),
    );
    let response = receive(&mut stream);
    assert_eq!(response["error"]["code"], -32601);
    assert_eq!(response["error"]["data"]["kind"], "method_not_found");

    service.handle.shutdown("test complete");
    service.wait();
}

/// Serializes tests that start facade jobs or change the toolchain environment.
static JOB_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

fn recording_for(service: &TestService, match_id: &str) -> PathBuf {
    let directory = service.state_root.join("recordings").join(match_id);
    std::fs::create_dir_all(&directory).expect("recording directory");
    let clip = directory.join("clip.mp4");
    std::fs::write(&clip, b"fake recording").expect("recording");
    clip
}

fn start_import_request(match_id: &str, original: &std::path::Path, key: &str) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": 20,
        "method": "engine.import.start",
        "clientRequestId": key,
        "params": {
            "matchId": match_id,
            "samplingRate": 2.0,
            "originalPath": original.to_string_lossy(),
        },
    })
}

#[test]
fn engine_methods_require_the_negotiated_capability() {
    let mut service = TestService::start();
    let mut stream = service.connect();

    send(
        &mut stream,
        &hello_request_with(&service.token, &["notifications.v1"]),
    );
    let hello = receive(&mut stream);
    assert_eq!(hello["result"]["capabilities"], json!(["notifications.v1"]));

    send(
        &mut stream,
        &json!({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "engine.importStages",
            "params": {},
        }),
    );
    let response = receive(&mut stream);
    assert_eq!(response["error"]["code"], -32601);
    assert_eq!(response["error"]["data"]["kind"], "method_not_found");

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn a_relaunch_token_is_accepted_without_restarting_the_service() {
    let mut service = TestService::start();
    let mut first = service.connected();
    send(
        &mut first,
        &json!({ "jsonrpc": "2.0", "id": 2, "method": "service.ping", "params": {} }),
    );
    assert_eq!(receive(&mut first)["result"]["pong"], true);

    // The app relaunches while the helper is still alive and rewrites the file.
    std::fs::write(
        service.state_root.join("run").join("token"),
        "relaunch-token",
    )
    .expect("rewrite token");

    let mut second = service.connect();
    send(&mut second, &hello_request("relaunch-token"));
    let response = receive(&mut second);
    assert!(
        response["error"].is_null(),
        "the new token is accepted: {response}"
    );

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn a_repeated_client_request_id_creates_one_import_job() {
    let _guard = JOB_TEST_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let mut service = TestService::start();
    let clip = recording_for(&service, "match-1");
    let mut stream = service.connected();

    // Integration tests share one process-wide facade registry; another test's
    // job may still occupy the single admission slot for a moment. Retry the
    // same key until the slot frees; idempotency is what this test covers.
    let mut first = Value::Null;
    for _ in 0..50 {
        send(
            &mut stream,
            &start_import_request("match-1", &clip, "key-1"),
        );
        first = receive(&mut stream);
        if first.get("result").is_some() {
            break;
        }
        assert_eq!(
            first["error"]["code"], -32030,
            "only admission can delay the first request: {first}"
        );
        thread::sleep(Duration::from_millis(100));
    }
    let first_job = first["result"]["jobId"]
        .as_str()
        .expect("first job handle")
        .to_string();
    assert_eq!(first["result"]["matchId"], "match-1");

    send(
        &mut stream,
        &start_import_request("match-1", &clip, "key-1"),
    );
    let second = receive(&mut stream);
    assert_eq!(
        second["result"]["jobId"], first_job,
        "the retry returns the existing job instead of starting a second import"
    );

    // A different key is a different mutation and starts its own job, unless
    // the first still occupies the single admission slot.
    send(
        &mut stream,
        &start_import_request("match-1", &clip, "key-2"),
    );
    let third = receive(&mut stream);
    if let Some(error) = third.get("error") {
        assert_eq!(error["code"], -32030, "one heavy job at a time");
    } else {
        assert_ne!(third["result"]["jobId"], first_job);
    }

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn a_running_job_blocks_idle_exit_after_the_client_disconnects() {
    let _guard = JOB_TEST_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());

    let toolchain = tempfile::tempdir().expect("toolchain dir");
    let script = toolchain.path().join("slow-tool");
    std::fs::write(&script, "#!/bin/sh\nsleep 3\nexit 1\n").expect("write script");
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&script, std::fs::Permissions::from_mode(0o755)).expect("chmod");
    }
    std::env::set_var("SPORTCUT_FFMPEG", &script);
    std::env::set_var("SPORTCUT_FFPROBE", &script);

    let mut service = TestService::start_with(|config| {
        // A one-second idle-exit threshold makes the rule observable quickly.
        config.idle_exit_seconds = 1;
    });
    let clip = recording_for(&service, "match-1");
    let mut stream = service.connected();

    send(
        &mut stream,
        &start_import_request("match-1", &clip, "slow-key"),
    );
    let started = receive(&mut stream);
    let job_id = started["result"]["jobId"]
        .as_str()
        .expect("the slow job starts")
        .to_string();

    // Wait until the service counts the job as running.
    let mut running = false;
    for _ in 0..100 {
        send(
            &mut stream,
            &json!({ "jsonrpc": "2.0", "id": 3, "method": "service.health", "params": {} }),
        );
        let health = receive(&mut stream);
        if health["result"]["runningJobs"].as_u64() == Some(1) {
            running = true;
            break;
        }
        thread::sleep(Duration::from_millis(20));
    }
    assert!(running, "the running job is visible to the lifecycle");

    // Disconnect and wait past the idle threshold. The job still blocks exit.
    drop(stream);
    thread::sleep(Duration::from_millis(1_500));
    assert!(
        service.completion.try_recv().is_err(),
        "the service must not exit while a job runs"
    );

    service.handle.shutdown("test complete");
    service.wait();
    // The worker has observed the terminal state; the toolchain overrides are
    // no longer needed.
    std::env::remove_var("SPORTCUT_FFMPEG");
    std::env::remove_var("SPORTCUT_FFPROBE");

    // Let the process-wide facade registry release the admission slot before
    // another serialized test starts a job.
    for _ in 0..100 {
        match sportcut_api::job_status(job_id.clone()) {
            Ok(status)
                if matches!(
                    status.state,
                    sportcut_api::JobStateDto::Completed
                        | sportcut_api::JobStateDto::Cancelled
                        | sportcut_api::JobStateDto::Failed
                ) =>
            {
                thread::sleep(Duration::from_millis(200));
                break;
            }
            Err(_) => {
                thread::sleep(Duration::from_millis(200));
                break;
            }
            _ => thread::sleep(Duration::from_millis(50)),
        }
    }
}

#[test]
fn a_batch_frame_is_invalid_request() {
    let mut service = TestService::start();
    let mut stream = service.connect();

    // A JSON array is a batch, which protocol §1.4 and §8 reject with -32600.
    send(
        &mut stream,
        &json!([
            { "jsonrpc": "2.0", "id": 1, "method": "service.ping", "params": {} }
        ]),
    );
    let response = receive(&mut stream);
    assert_eq!(response["error"]["code"], -32600);
    assert_eq!(response["error"]["data"]["kind"], "invalid_request");
    assert!(response["id"].is_null());

    service.handle.shutdown("test complete");
    service.wait();
}

#[test]
fn a_pure_engine_method_is_served_over_the_socket() {
    let mut service = TestService::start();
    let mut stream = service.connected();

    send(
        &mut stream,
        &json!({
            "jsonrpc": "2.0",
            "id": 4,
            "method": "engine.servingSides",
            "params": {
                "rallies": [
                    { "rallyId": "rally-1", "winner": "left" },
                    { "rallyId": "rally-2", "winner": "right" }
                ]
            },
        }),
    );
    let response = receive(&mut stream);
    assert_eq!(response["id"], 4);
    assert_eq!(
        response["result"],
        json!({
            "rallies": [
                { "rallyId": "rally-1", "side": null },
                { "rallyId": "rally-2", "side": "left" }
            ]
        })
    );

    service.handle.shutdown("test complete");
    service.wait();
}
