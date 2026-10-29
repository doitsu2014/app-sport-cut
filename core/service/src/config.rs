//! Launcher options.
//!
//! The app launches the helper with explicit arguments, not through a shell
//! (background-service §4.1). This module parses those arguments without a
//! command-line crate so the service keeps its dependency surface small and
//! auditable.

use std::ffi::OsString;
use std::path::PathBuf;

use anyhow::{bail, Context, Result};

use crate::logging::LogLevel;

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
        }
    }

    /// The token file this configuration resolves to.
    pub fn resolved_token_file(&self) -> PathBuf {
        self.token_file
            .clone()
            .unwrap_or_else(|| self.state_root.join("run").join("token"))
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
