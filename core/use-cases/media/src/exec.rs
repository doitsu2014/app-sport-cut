//! Running the media toolchain.
//!
//! Every external process the engine starts goes through this module, which is
//! what makes the offline guarantee checkable: the only binaries invoked are
//! the local `ffmpeg`/`ffprobe` pair, with local file paths, and no stage has a
//! network code path.

use std::ffi::OsString;
use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use std::process::{Command, Stdio};

use sportcut_common::{CancelToken, Result, SportcutError};

/// Captured result of a tool invocation.
#[derive(Debug)]
pub struct ToolOutput {
    pub(crate) status: i32,
    pub(crate) stdout: Vec<u8>,
    pub(crate) stderr: String,
}

impl ToolOutput {
    /// Turn a non-zero exit status into an actionable error.
    pub fn into_success(self, tool: &str, input: &Path) -> Result<Self> {
        if self.status == 0 {
            Ok(self)
        } else {
            let stderr = if self.stderr.trim().is_empty() {
                format!(
                    "{tool} exited with status {} and produced no diagnostic",
                    self.status
                )
            } else {
                self.stderr.trim().to_string()
            };
            Err(SportcutError::MediaToolFailed {
                tool: tool.to_string(),
                path: input.display().to_string(),
                status: self.status,
                stderr,
            })
        }
    }
}

/// Run a tool with the given arguments, capturing its output.
///
/// Spawn failures are reported as a missing toolchain rather than as a media
/// failure, because the remediation is different: install the toolchain.
pub fn run(tool: &Path, tool_label: &str, args: &[OsString], input: &Path) -> Result<ToolOutput> {
    let mut command = Command::new(tool);
    command.args(args);
    command.stdin(Stdio::null());

    let output = command.output().map_err(|e| {
        SportcutError::ToolchainUnavailable(format!(
            "could not run {tool_label} at {} while processing {}: {e}",
            tool.display(),
            input.display()
        ))
    })?;

    Ok(ToolOutput {
        status: output.status.code().unwrap_or(-1),
        stdout: output.stdout,
        stderr: String::from_utf8_lossy(&output.stderr).to_string(),
    })
}

/// Run a tool that reports progress while it works.
///
/// Long renders cannot use [`run`]: it returns only when the process exits, so
/// the caller could neither show progress nor stop the work. This variant hands
/// every line the tool writes to standard output to `on_progress` — which is
/// what `-progress pipe:1` produces — and kills the process as soon as the
/// cancellation token flips.
///
/// Standard error is drained on its own thread, because a tool that fills that
/// pipe while nobody reads it would otherwise block forever.
pub fn run_with_progress(
    tool: &Path,
    tool_label: &str,
    args: &[OsString],
    input: &Path,
    cancel: &CancelToken,
    on_progress: &mut dyn FnMut(&str),
) -> Result<ToolOutput> {
    let mut command = Command::new(tool);
    command.args(args);
    command.stdin(Stdio::null());
    command.stdout(Stdio::piped());
    command.stderr(Stdio::piped());

    let mut child = command.spawn().map_err(|error| {
        SportcutError::ToolchainUnavailable(format!(
            "could not run {tool_label} at {} while processing {}: {error}",
            tool.display(),
            input.display()
        ))
    })?;

    let stderr = child.stderr.take().expect("standard error was piped above");
    let drain = std::thread::spawn(move || {
        let mut buffer = String::new();
        let mut reader = BufReader::new(stderr);
        let _ = reader.read_to_string(&mut buffer);
        buffer
    });

    let mut cancelled = false;
    if let Some(stdout) = child.stdout.take() {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            if cancel.is_cancelled() {
                cancelled = true;
                let _ = child.kill();
                break;
            }
            on_progress(&line);
        }
    }

    let status = child.wait();
    let stderr = drain.join().unwrap_or_default();

    if cancelled || cancel.is_cancelled() {
        return Err(SportcutError::Cancelled);
    }

    let status = status.map_err(|error| {
        SportcutError::ToolchainUnavailable(format!(
            "could not wait for {tool_label} at {} while processing {}: {error}",
            tool.display(),
            input.display()
        ))
    })?;

    Ok(ToolOutput {
        status: status.code().unwrap_or(-1),
        stdout: Vec::new(),
        stderr,
    })
}
