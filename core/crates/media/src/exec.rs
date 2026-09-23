//! Running the media toolchain.
//!
//! Every external process the engine starts goes through this module, which is
//! what makes the offline guarantee checkable: the only binaries invoked are
//! the local `ffmpeg`/`ffprobe` pair, with local file paths, and no stage has a
//! network code path.

use std::ffi::OsString;
use std::path::Path;
use std::process::Command;

use sportcut_common::{Result, SportcutError};

/// Captured result of a tool invocation.
#[derive(Debug)]
pub(crate) struct ToolOutput {
    pub(crate) status: i32,
    pub(crate) stdout: Vec<u8>,
    pub(crate) stderr: String,
}

impl ToolOutput {
    /// Turn a non-zero exit status into an actionable error.
    pub(crate) fn into_success(self, tool: &str, input: &Path) -> Result<Self> {
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
pub(crate) fn run(
    tool: &Path,
    tool_label: &str,
    args: &[OsString],
    input: &Path,
) -> Result<ToolOutput> {
    let mut command = Command::new(tool);
    command.args(args);
    command.stdin(std::process::Stdio::null());

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
