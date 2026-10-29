//! Structured, local-only service logging.
//!
//! Background service §9.3: JSON lines in `<state-root>/logs/service.log`,
//! rotating at 10 MiB with five retained files. Tokens and file contents are
//! never logged. The logger is deliberately tiny: the service ships without a
//! logging framework so its dependency surface stays auditable.

use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result};
use serde_json::{json, Map, Value};

/// Rotate `service.log` when it reaches this many bytes.
pub const LOG_MAX_BYTES: u64 = 10 * 1024 * 1024;

/// Number of rotated files kept alongside the current log.
pub const LOG_RETAINED: usize = 5;

/// The log file name inside the log directory.
pub const LOG_FILE_NAME: &str = "service.log";

/// Severity of a log line; lower values are more severe.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum LogLevel {
    /// A failure that needs operator attention.
    Error,
    /// Something unexpected that the service recovered from.
    Warn,
    /// Normal lifecycle and request milestones.
    Info,
    /// Diagnostic detail.
    Debug,
}

impl LogLevel {
    /// Parse the documented `--log-level` values.
    pub fn parse(value: &str) -> Result<Self> {
        match value {
            "error" => Ok(Self::Error),
            "warn" => Ok(Self::Warn),
            "info" => Ok(Self::Info),
            "debug" => Ok(Self::Debug),
            other => {
                anyhow::bail!("--log-level expects one of error, warn, info, debug; got {other:?}")
            }
        }
    }

    /// The wire/string form.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Error => "error",
            Self::Warn => "warn",
            Self::Info => "info",
            Self::Debug => "debug",
        }
    }
}

impl std::fmt::Display for LogLevel {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(self.as_str())
    }
}

/// A cloneable handle to the process log.
#[derive(Debug, Clone)]
pub struct Logger {
    inner: Arc<LoggerInner>,
}

#[derive(Debug)]
struct LoggerInner {
    level: LogLevel,
    path: PathBuf,
    file: Mutex<Option<File>>,
}

impl Logger {
    /// A logger that discards every line, for tests and library consumers.
    pub fn disabled() -> Self {
        Self {
            inner: Arc::new(LoggerInner {
                level: LogLevel::Error,
                path: PathBuf::new(),
                file: Mutex::new(None),
            }),
        }
    }

    /// Open `<log_directory>/service.log` for appending at `level`.
    ///
    /// The directory is created `0700` and the file `0600`, matching the rest
    /// of the service-private state root.
    pub fn open(log_directory: &Path, level: LogLevel) -> Result<Self> {
        fs::create_dir_all(log_directory).with_context(|| {
            format!(
                "failed to create the log directory {}",
                log_directory.display()
            )
        })?;
        let path = log_directory.join(LOG_FILE_NAME);
        let file = open_append(&path)?;
        Ok(Self {
            inner: Arc::new(LoggerInner {
                level,
                path,
                file: Mutex::new(Some(file)),
            }),
        })
    }

    /// The file this logger writes.
    pub fn path(&self) -> &Path {
        &self.inner.path
    }

    /// The threshold this logger was opened with.
    pub fn level(&self) -> LogLevel {
        self.inner.level
    }

    /// Write one structured line when `level` is enabled.
    pub fn log(&self, level: LogLevel, message: impl AsRef<str>, fields: Map<String, Value>) {
        if level > self.inner.level || self.inner.path.as_os_str().is_empty() {
            return;
        }

        let mut record = Map::new();
        record.insert("ts".to_string(), json!(epoch_millis()));
        record.insert("level".to_string(), json!(level.as_str()));
        record.insert("pid".to_string(), json!(std::process::id()));
        record.insert("message".to_string(), json!(message.as_ref()));
        for (name, value) in fields {
            record.insert(name, value);
        }
        let mut line = serde_json::to_vec(&Value::Object(record)).unwrap_or_default();
        line.push(b'\n');

        let mut guard = self
            .inner
            .file
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let Some(file) = guard.as_mut() else {
            return;
        };
        if rotate_if_needed(&self.inner.path, file, line.len() as u64) {
            // `file` points at the old inode; reopen the fresh log.
            if let Ok(reopened) = open_append(&self.inner.path) {
                *file = reopened;
            }
        }
        let _ = file.write_all(&line);
    }

    /// Log at `error`.
    pub fn error(&self, message: impl AsRef<str>) {
        self.log(LogLevel::Error, message, Map::new());
    }

    /// Log at `warn`.
    pub fn warn(&self, message: impl AsRef<str>) {
        self.log(LogLevel::Warn, message, Map::new());
    }

    /// Log at `info`.
    pub fn info(&self, message: impl AsRef<str>) {
        self.log(LogLevel::Info, message, Map::new());
    }

    /// Log at `debug` with extra structured fields.
    pub fn debug(&self, message: impl AsRef<str>, fields: Map<String, Value>) {
        self.log(LogLevel::Debug, message, fields);
    }
}

fn open_append(path: &Path) -> Result<File> {
    OpenOptions::new()
        .create(true)
        .append(true)
        .mode(0o600)
        .open(path)
        .with_context(|| format!("failed to open the service log {}", path.display()))
}

fn rotate_if_needed(path: &Path, file: &File, incoming: u64) -> bool {
    let Ok(metadata) = file.metadata() else {
        return false;
    };
    if metadata.len() + incoming <= LOG_MAX_BYTES {
        return false;
    }
    rotate(path)
}

fn rotate(path: &Path) -> bool {
    let Some(name) = path.file_name() else {
        return false;
    };
    for index in (1..=LOG_RETAINED).rev() {
        let from = if index == 1 {
            path.to_path_buf()
        } else {
            path.with_file_name(format!("{}.{}", name.to_string_lossy(), index - 1))
        };
        let to = path.with_file_name(format!("{}.{index}", name.to_string_lossy()));
        if from.exists() {
            let _ = fs::rename(&from, &to);
        }
    }
    true
}

fn epoch_millis() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn levels_parse_and_order() {
        assert_eq!(LogLevel::parse("error").expect("error"), LogLevel::Error);
        assert_eq!(LogLevel::parse("warn").expect("warn"), LogLevel::Warn);
        assert_eq!(LogLevel::parse("info").expect("info"), LogLevel::Info);
        assert_eq!(LogLevel::parse("debug").expect("debug"), LogLevel::Debug);
        assert!(LogLevel::parse("trace").is_err());
        assert!(LogLevel::Error < LogLevel::Warn);
        assert!(LogLevel::Warn < LogLevel::Info);
        assert!(LogLevel::Info < LogLevel::Debug);
    }

    #[test]
    fn lines_are_json_and_respect_the_level() {
        let directory = tempfile::tempdir().expect("temp dir");
        let logger = Logger::open(directory.path(), LogLevel::Info).expect("open");
        logger.debug("not written", Map::new());
        logger.info("written");
        let contents = fs::read_to_string(logger.path()).expect("read log");
        assert_eq!(contents.lines().count(), 1);
        let line: Value =
            serde_json::from_str(contents.lines().next().expect("line")).expect("json line");
        assert_eq!(line["level"], "info");
        assert_eq!(line["message"], "written");
        assert!(line["ts"].as_u64().is_some());
        assert!(line["pid"].as_u64().is_some());
    }

    #[test]
    fn the_log_rotates_and_retains_five_files() {
        let directory = tempfile::tempdir().expect("temp dir");
        let logger = Logger::open(directory.path(), LogLevel::Debug).expect("open");
        // Push the current file over the rotation threshold.
        let padding = "x".repeat(LOG_MAX_BYTES as usize);
        logger.log(LogLevel::Info, padding, Map::new());
        logger.info("after rotation");

        let rotated = logger.path().with_file_name(format!("{}.1", LOG_FILE_NAME));
        assert!(rotated.is_file(), "the oversized log is rotated");
        let current = fs::read_to_string(logger.path()).expect("current log");
        assert!(current.contains("after rotation"));
    }
}
