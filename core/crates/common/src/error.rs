//! The engine-wide error type.

use std::path::Path;

/// Convenience alias used across every crate.
pub type Result<T, E = SportcutError> = std::result::Result<T, E>;

/// Everything that can go wrong in the engine.
///
/// Variants are deliberately coarse: callers decide how to present a failure,
/// and the message always names the input and the reason so a surface (CLI or
/// app UI) can show something actionable without re-deriving context.
#[derive(Debug, thiserror::Error)]
pub enum SportcutError {
    /// A filesystem operation failed, with the path that caused it.
    #[error("file system error at {path}: {source}")]
    Io {
        /// Path involved in the failed operation.
        path: String,
        /// Underlying OS error.
        #[source]
        source: std::io::Error,
    },

    /// Input was well-formed enough to read but not usable.
    #[error("invalid input: {0}")]
    InvalidInput(String),

    /// The request is valid but outside what this build supports.
    #[error("unsupported {feature}: {detail}")]
    Unsupported {
        /// The feature or parameter that is not supported.
        feature: String,
        /// Why it is not supported, or the nearest supported value.
        detail: String,
    },

    /// The media toolchain is absent or unusable.
    #[error("media toolchain unavailable: {0}")]
    ToolchainUnavailable(String),

    /// The media toolchain failed while processing a file.
    #[error("{tool} failed for {path} (exit status {status}): {stderr}")]
    MediaToolFailed {
        /// Tool that failed, for example `ffmpeg` or `ffprobe`.
        tool: String,
        /// Input the tool was given.
        path: String,
        /// Process exit status.
        status: i32,
        /// Captured standard error, trimmed.
        stderr: String,
    },

    /// A file could not be probed as media.
    #[error("could not read media metadata from {path}: {reason}")]
    Probe {
        /// File that failed to probe.
        path: String,
        /// Reason reported by the probe, or a description of what was missing.
        reason: String,
    },

    /// The artifact directory or manifest is inconsistent with what was asked.
    #[error("artifact error: {0}")]
    Artifact(String),

    /// A job was rejected before it started.
    #[error("job {job_id} was rejected: {reason}")]
    JobRejected {
        /// Identifier of the rejected job.
        job_id: String,
        /// Human-readable reason, suitable for showing to a user.
        reason: String,
    },

    /// The job or one of its stages failed while running.
    #[error("job {job_id} failed during stage {stage}: {reason}")]
    JobFailed {
        /// Identifier of the failed job.
        job_id: String,
        /// Stage that failed.
        stage: String,
        /// Human-readable reason.
        reason: String,
    },

    /// Work was cancelled cooperatively.
    #[error("operation cancelled")]
    Cancelled,
}

impl SportcutError {
    /// Build an [`SportcutError::Io`] from a path and the OS error.
    pub fn io(path: impl AsRef<Path>, source: std::io::Error) -> Self {
        Self::Io {
            path: path.as_ref().display().to_string(),
            source,
        }
    }

    /// Build an [`SportcutError::Unsupported`] error.
    pub fn unsupported(feature: impl Into<String>, detail: impl Into<String>) -> Self {
        Self::Unsupported {
            feature: feature.into(),
            detail: detail.into(),
        }
    }

    /// True when the error is a cooperative cancellation rather than a failure.
    pub fn is_cancellation(&self) -> bool {
        matches!(self, Self::Cancelled)
    }
}
