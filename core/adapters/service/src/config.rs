//! Launcher options.
//!
//! The app launches the helper with explicit arguments, not through a shell
//! (background-service §4.1). This module parses those arguments without a
//! command-line crate so the service keeps its dependency surface small and
//! auditable.

use std::ffi::OsString;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};

use crate::logging::LogLevel;

/// Environment variable the media pipeline reads for `ffmpeg`.
pub const FFMPEG_ENV: &str = "SPORTCUT_FFMPEG";

/// Environment variable the media pipeline reads for `ffprobe`.
pub const FFPROBE_ENV: &str = "SPORTCUT_FFPROBE";

/// Environment variable the player-tracking runtime reads for the TFLite
/// shared library.
pub const TFLITE_LIBRARY_ENV: &str = "SPORTCUT_TFLITE_LIBRARY";

/// Environment variable the player-tracking runtime reads for the person
/// model weights.
pub const PERSON_MODEL_ENV: &str = "SPORTCUT_PERSON_MODEL";

/// Bundle-relative location of the TFLite runtime, from `Contents/`.
const TFLITE_BUNDLE_PATH: [&str; 2] = ["Frameworks", "libtensorflowlite_c.dylib"];

/// Bundle-relative location of the person model, from `Contents/`.
const PERSON_MODEL_BUNDLE_PATH: [&str; 2] = ["Resources", "model.tflite"];

/// The service-owned inference assets as resolved at startup.
///
/// The fingerprint is computed once by [`Config::vision_assets`] when the
/// server binds, so `service.health` can apply the same model gate as the
/// player-tracking job without re-hashing the file on every request.
#[derive(Debug, Clone, Default)]
pub struct VisionAssets {
    /// TFLite runtime shared library, if one resolved.
    pub runtime: Option<PathBuf>,
    /// Person model weights, if one resolved.
    pub model: Option<PathBuf>,
    /// Content fingerprint of the model, when it could be read.
    pub model_fingerprint: Option<String>,
}

/// Seconds with no connections and no running jobs before the process exits.
pub const DEFAULT_IDLE_EXIT_SECONDS: u64 = 120;

/// Seconds the service waits after its parent disappears before exiting.
pub const DEFAULT_PARENT_GONE_GRACE_SECONDS: u64 = 30;

/// Usage text printed by `--help`.
pub const USAGE: &str = "\
Usage: sportcut-service --state-root <path> --endpoint <path> [options]

Options:
  --state-root <path>         Service-owned data root (required)
  --endpoint <path>           Unix socket path to bind (required, at most 103 bytes)
  --parent-pid <pid>          Supervise this process and exit when it disappears
  --token-file <path>         Token file to write (default: <state-root>/run/token)
  --log-level <level>         error, warn, info, or debug (default: info)
  --idle-exit-seconds <n>     Exit after n idle seconds (default: 120)
  --ffmpeg <path>            ffmpeg executable (default: PATH discovery)
  --ffprobe <path>           ffprobe executable (default: PATH discovery)
  --tflite-library <path>    TFLite runtime dylib (default: app bundle, then
                             SPORTCUT_TFLITE_LIBRARY)
  --person-model <path>      Person model weights (default: app bundle, then
                             SPORTCUT_PERSON_MODEL)
  --single-instance           Take an exclusive lock on <state-root>/run/service.lock
  --no-single-instance        Do not take the lock (tests and custom layouts)
  -h, --help                  Print this help
  -V, --version               Print the service version
";

/// Everything the service needs to start.
#[derive(Debug, Clone)]
pub struct Config {
    /// Unix domain socket path the service binds.
    pub endpoint: PathBuf,
    /// Service-owned data root.
    pub state_root: PathBuf,
    /// Process to supervise; the service exits once it is gone.
    pub parent_pid: Option<i32>,
    /// Token file to write. Defaults to `<state-root>/run/token`.
    pub token_file: Option<PathBuf>,
    /// Idle-exit threshold in seconds.
    pub idle_exit_seconds: u64,
    /// Whether to hold the single-instance lock.
    pub single_instance: bool,
    /// Grace period after the parent disappears, in seconds.
    pub parent_gone_grace_seconds: u64,
    /// Threshold for the structured service log.
    pub log_level: LogLevel,
    /// Media toolchain binary, or `None` to discover it on `PATH`.
    pub ffmpeg: Option<PathBuf>,
    /// Media probe binary, or `None` to discover it on `PATH`.
    pub ffprobe: Option<PathBuf>,
    /// TFLite runtime shared library, or `None` when none resolves.
    pub tflite_library: Option<PathBuf>,
    /// Person model weights, or `None` when none resolves.
    pub person_model: Option<PathBuf>,
}

impl Config {
    /// A configuration with the documented defaults and no parent supervision.
    pub fn new(state_root: impl Into<PathBuf>, endpoint: impl Into<PathBuf>) -> Self {
        Self {
            endpoint: endpoint.into(),
            state_root: state_root.into(),
            parent_pid: None,
            token_file: None,
            idle_exit_seconds: DEFAULT_IDLE_EXIT_SECONDS,
            single_instance: true,
            parent_gone_grace_seconds: DEFAULT_PARENT_GONE_GRACE_SECONDS,
            log_level: LogLevel::Info,
            ffmpeg: None,
            ffprobe: None,
            tflite_library: None,
            person_model: None,
        }
    }

    /// The token file this configuration resolves to.
    pub fn resolved_token_file(&self) -> PathBuf {
        self.token_file
            .clone()
            .unwrap_or_else(|| self.state_root.join("run").join("token"))
    }

    /// Resolve the inference assets and publish every service-owned tool path
    /// to the environment.
    ///
    /// The service, not the client, owns where the media tools and inference
    /// assets live. Resolution precedence for the inference assets is: an
    /// explicit `--tflite-library`/`--person-model`, then the file next to the
    /// service executable inside the app bundle, then the matching environment
    /// variable. Media tool paths come from the explicit flags; when a flag is
    /// unset the existing discovery order is left in place, which honors
    /// `SPORTCUT_FFMPEG`/`SPORTCUT_FFPROBE` before `PATH`. A packaged launch
    /// always passes the explicit flags, so an inherited environment cannot
    /// choose its media binaries.
    ///
    /// Call this once, before any thread starts. The facade's toolchain
    /// discovery and the player-tracking job both read these variables, so the
    /// service-owned paths reach them without another wiring path.
    pub fn prepare_runtime(&mut self) {
        self.tflite_library = resolve_inference_asset(
            self.tflite_library.take(),
            bundle_asset_path(&TFLITE_BUNDLE_PATH),
            env_file(TFLITE_LIBRARY_ENV),
        );
        self.person_model = resolve_inference_asset(
            self.person_model.take(),
            bundle_asset_path(&PERSON_MODEL_BUNDLE_PATH),
            env_file(PERSON_MODEL_ENV),
        );

        for (name, value) in self.environment_updates() {
            std::env::set_var(name, value);
        }
    }

    /// The resolved inference assets plus the model fingerprint.
    ///
    /// Called once at bind time so `service.health` can apply the same model
    /// gate as the player-tracking job without re-hashing the file per request.
    pub fn vision_assets(&self) -> VisionAssets {
        VisionAssets {
            runtime: self.tflite_library.clone(),
            model: self.person_model.clone(),
            model_fingerprint: self
                .person_model
                .as_deref()
                .and_then(|path| sportcut_api::track_artifact::fingerprint_file(path).ok()),
        }
    }

    /// The environment assignments [`Self::prepare_runtime`] publishes.
    fn environment_updates(&self) -> Vec<(&'static str, OsString)> {
        let mut updates = Vec::new();
        let entries = [
            (FFMPEG_ENV, &self.ffmpeg),
            (FFPROBE_ENV, &self.ffprobe),
            (TFLITE_LIBRARY_ENV, &self.tflite_library),
            (PERSON_MODEL_ENV, &self.person_model),
        ];
        for (name, path) in entries {
            if let Some(path) = path {
                updates.push((name, path.as_os_str().to_os_string()));
            }
        }
        updates
    }
}

/// Choose an inference asset from an explicit flag, the app bundle, or the
/// environment, in that order. A path that does not resolve to a file is not
/// selected.
fn resolve_inference_asset(
    explicit: Option<PathBuf>,
    bundle: Option<PathBuf>,
    environment: Option<PathBuf>,
) -> Option<PathBuf> {
    explicit.or(bundle).or(environment)
}

/// A file at `Contents/<relative...>`, where the executable is
/// `Contents/Helpers/SportcutService`.
fn bundle_asset_path(relative: &[&str]) -> Option<PathBuf> {
    let executable = std::env::current_exe().ok()?;
    let contents = executable.parent()?.parent()?;
    let mut path = contents.to_path_buf();
    for component in relative {
        path.push(component);
    }
    path.is_file().then_some(path)
}

fn env_file(name: &str) -> Option<PathBuf> {
    std::env::var_os(name)
        .map(PathBuf::from)
        .filter(|path| path.is_file())
}

/// An explicit executable path, validated at parse time.
fn executable_value(flag: &str, value: OsString) -> Result<PathBuf> {
    let path = PathBuf::from(value);
    if !is_executable(&path) {
        bail!(
            "{flag} expects an executable file, but {} is not one",
            path.display()
        );
    }
    Ok(path)
}

/// An explicit asset path, validated at parse time.
fn file_value(flag: &str, value: OsString) -> Result<PathBuf> {
    let path = PathBuf::from(value);
    if !path.is_file() {
        bail!(
            "{flag} expects a readable file, but {} is not one",
            path.display()
        );
    }
    Ok(path)
}

fn is_executable(path: &Path) -> bool {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        match std::fs::metadata(path) {
            Ok(metadata) => metadata.is_file() && metadata.permissions().mode() & 0o111 != 0,
            Err(_) => false,
        }
    }
    #[cfg(not(unix))]
    {
        path.is_file()
    }
}

/// The result of parsing the launcher arguments.
#[derive(Debug)]
pub enum Parsed {
    /// Start the service with this configuration.
    Run(Config),
    /// Print [`USAGE`] and exit successfully.
    Help,
    /// Print the version and exit successfully.
    Version,
}

/// Parse the process arguments, excluding the program name.
pub fn parse_args<I>(args: I) -> Result<Parsed>
where
    I: IntoIterator<Item = OsString>,
{
    let mut state_root: Option<PathBuf> = None;
    let mut endpoint: Option<PathBuf> = None;
    let mut parent_pid: Option<i32> = None;
    let mut token_file: Option<PathBuf> = None;
    let mut idle_exit_seconds = DEFAULT_IDLE_EXIT_SECONDS;
    let mut single_instance = true;
    let parent_gone_grace_seconds = DEFAULT_PARENT_GONE_GRACE_SECONDS;
    let mut log_level = LogLevel::Info;
    let mut ffmpeg: Option<PathBuf> = None;
    let mut ffprobe: Option<PathBuf> = None;
    let mut tflite_library: Option<PathBuf> = None;
    let mut person_model: Option<PathBuf> = None;

    let mut args = args.into_iter();
    while let Some(argument) = args.next() {
        let flag = argument
            .to_str()
            .with_context(|| format!("argument {argument:?} is not valid UTF-8"))?;

        let mut take_value = |name: &str| -> Result<OsString> {
            args.next()
                .with_context(|| format!("{name} requires a value; run with --help"))
        };

        match flag {
            "-h" | "--help" => return Ok(Parsed::Help),
            "-V" | "--version" => return Ok(Parsed::Version),
            "--state-root" => state_root = Some(PathBuf::from(take_value(flag)?)),
            "--endpoint" => endpoint = Some(PathBuf::from(take_value(flag)?)),
            "--token-file" => token_file = Some(PathBuf::from(take_value(flag)?)),
            "--idle-exit-seconds" => {
                let value = take_value(flag)?;
                let text = value
                    .to_str()
                    .with_context(|| format!("--idle-exit-seconds value {value:?} is not UTF-8"))?;
                idle_exit_seconds = text.parse::<u64>().with_context(|| {
                    format!("--idle-exit-seconds expects a non-negative integer, got {text:?}")
                })?;
            }
            "--parent-pid" => {
                let value = take_value(flag)?;
                let text = value
                    .to_str()
                    .with_context(|| format!("--parent-pid value {value:?} is not UTF-8"))?;
                let pid = text.parse::<i32>().with_context(|| {
                    format!("--parent-pid expects a positive process id, got {text:?}")
                })?;
                if pid <= 0 {
                    bail!("--parent-pid expects a positive process id, got {pid}");
                }
                parent_pid = Some(pid);
            }
            "--log-level" => {
                let value = take_value(flag)?;
                let text = value
                    .to_str()
                    .with_context(|| format!("--log-level value {value:?} is not UTF-8"))?;
                log_level = LogLevel::parse(text)?;
            }
            "--ffmpeg" => ffmpeg = Some(executable_value(flag, take_value(flag)?)?),
            "--ffprobe" => ffprobe = Some(executable_value(flag, take_value(flag)?)?),
            "--tflite-library" => {
                tflite_library = Some(file_value(flag, take_value(flag)?)?);
            }
            "--person-model" => {
                person_model = Some(file_value(flag, take_value(flag)?)?);
            }
            "--single-instance" => single_instance = true,
            "--no-single-instance" => single_instance = false,
            other => bail!("unknown argument {other:?}; run with --help"),
        }
    }

    let state_root = state_root.context("--state-root is required; run with --help")?;
    let endpoint = endpoint.context("--endpoint is required; run with --help")?;

    Ok(Parsed::Run(Config {
        endpoint,
        state_root,
        parent_pid,
        token_file,
        idle_exit_seconds,
        single_instance,
        parent_gone_grace_seconds,
        log_level,
        ffmpeg,
        ffprobe,
        tflite_library,
        person_model,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(args: &[&str]) -> Result<Parsed> {
        parse_args(args.iter().map(OsString::from))
    }

    #[test]
    fn parses_the_required_paths_and_defaults() {
        let Parsed::Run(config) =
            parse(&["--state-root", "/state", "--endpoint", "/run/s.sock"]).expect("parse")
        else {
            panic!("expected a run command");
        };

        assert_eq!(config.state_root, PathBuf::from("/state"));
        assert_eq!(config.endpoint, PathBuf::from("/run/s.sock"));
        assert_eq!(config.parent_pid, None);
        assert_eq!(config.token_file, None);
        assert_eq!(config.idle_exit_seconds, DEFAULT_IDLE_EXIT_SECONDS);
        assert!(config.single_instance);
        assert_eq!(
            config.parent_gone_grace_seconds,
            DEFAULT_PARENT_GONE_GRACE_SECONDS
        );
        assert_eq!(
            config.resolved_token_file(),
            PathBuf::from("/state/run/token")
        );
        assert_eq!(config.log_level, LogLevel::Info);
        assert_eq!(config.ffmpeg, None);
        assert_eq!(config.ffprobe, None);
        assert_eq!(config.tflite_library, None);
        assert_eq!(config.person_model, None);
    }

    #[cfg(unix)]
    #[test]
    fn parses_media_and_inference_paths_and_validates_them() {
        use std::os::unix::fs::PermissionsExt;

        let directory = tempfile::tempdir().expect("temp dir");
        let ffmpeg = directory.path().join("ffmpeg");
        std::fs::write(&ffmpeg, b"").expect("write ffmpeg");
        std::fs::set_permissions(&ffmpeg, std::fs::Permissions::from_mode(0o755)).expect("chmod");
        let model = directory.path().join("model.tflite");
        std::fs::write(&model, b"x").expect("write model");

        let Parsed::Run(config) = parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--ffmpeg",
            ffmpeg.to_str().expect("utf8"),
            "--tflite-library",
            model.to_str().expect("utf8"),
            "--person-model",
            model.to_str().expect("utf8"),
        ])
        .expect("parse") else {
            panic!("expected a run command");
        };

        assert_eq!(config.ffmpeg, Some(ffmpeg.clone()));
        assert_eq!(config.ffprobe, None);
        assert_eq!(config.tflite_library, Some(model.clone()));
        assert_eq!(config.person_model, Some(model));

        // A regular file without an execute bit is not an acceptable tool.
        let not_executable = directory.path().join("not-executable");
        std::fs::write(&not_executable, b"").expect("write");
        assert!(parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--ffmpeg",
            not_executable.to_str().expect("utf8"),
        ])
        .is_err());

        // A missing inference asset is rejected at parse time.
        let missing = directory.path().join("missing.tflite");
        assert!(parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--person-model",
            missing.to_str().expect("utf8"),
        ])
        .is_err());
    }

    #[test]
    fn inference_resolution_prefers_explicit_then_bundle_then_environment() {
        let explicit = PathBuf::from("/explicit");
        let bundle = PathBuf::from("/bundle");
        let environment = PathBuf::from("/environment");

        assert_eq!(
            resolve_inference_asset(
                Some(explicit.clone()),
                Some(bundle.clone()),
                Some(environment.clone()),
            ),
            Some(explicit)
        );
        assert_eq!(
            resolve_inference_asset(None, Some(bundle.clone()), Some(environment.clone())),
            Some(bundle)
        );
        assert_eq!(
            resolve_inference_asset(None, None, Some(environment.clone())),
            Some(environment)
        );
        assert_eq!(resolve_inference_asset(None, None, None), None);
    }

    #[test]
    fn environment_updates_use_the_documented_variable_names() {
        let mut config = Config::new("/state", "/run/s.sock");
        config.ffmpeg = Some(PathBuf::from("/tools/ffmpeg"));
        config.ffprobe = Some(PathBuf::from("/tools/ffprobe"));
        config.tflite_library = Some(PathBuf::from("/lib/libtensorflowlite_c.dylib"));
        config.person_model = Some(PathBuf::from("/models/model.tflite"));

        let updates: Vec<_> = config
            .environment_updates()
            .into_iter()
            .map(|(name, value)| (name, PathBuf::from(value)))
            .collect();
        assert_eq!(
            updates,
            vec![
                (FFMPEG_ENV, PathBuf::from("/tools/ffmpeg")),
                (FFPROBE_ENV, PathBuf::from("/tools/ffprobe")),
                (
                    TFLITE_LIBRARY_ENV,
                    PathBuf::from("/lib/libtensorflowlite_c.dylib")
                ),
                (PERSON_MODEL_ENV, PathBuf::from("/models/model.tflite")),
            ]
        );
    }

    #[test]
    fn parses_every_documented_flag() {
        let Parsed::Run(config) = parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--parent-pid",
            "42",
            "--token-file",
            "/run/token",
            "--idle-exit-seconds",
            "7",
            "--log-level",
            "debug",
            "--no-single-instance",
        ])
        .expect("parse") else {
            panic!("expected a run command");
        };

        assert_eq!(config.parent_pid, Some(42));
        assert_eq!(config.token_file, Some(PathBuf::from("/run/token")));
        assert_eq!(config.idle_exit_seconds, 7);
        assert_eq!(config.log_level, LogLevel::Debug);
        assert!(!config.single_instance);
    }

    #[test]
    fn rejects_unknown_and_incomplete_arguments() {
        assert!(parse(&["--state-root", "/state"]).is_err());
        assert!(parse(&["--state-root", "/state", "--endpoint"]).is_err());
        assert!(parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--idle-exit-seconds",
            "soon"
        ])
        .is_err());
        assert!(parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--parent-pid",
            "0"
        ])
        .is_err());
        assert!(parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--wat"
        ])
        .is_err());
        assert!(parse(&[
            "--state-root",
            "/state",
            "--endpoint",
            "/run/s.sock",
            "--log-level",
            "trace"
        ])
        .is_err());
    }

    #[test]
    fn help_and_version_short_circuit() {
        assert!(matches!(parse(&["--help"]).expect("help"), Parsed::Help));
        assert!(matches!(
            parse(&["--version"]).expect("version"),
            Parsed::Version
        ));
    }
}
