//! Stage-labelled progress reporting.

use serde::{Deserialize, Serialize};

/// A single progress update.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProgressEvent {
    /// Stage the job is currently in, for example `proxy` or `frames`.
    pub stage: String,
    /// Progress within that stage, in the range `0.0..=1.0`.
    pub value: f64,
    /// Optional human-readable detail.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

impl ProgressEvent {
    /// Build an event for a stage.
    pub fn new(stage: impl Into<String>, value: f64) -> Self {
        Self {
            stage: stage.into(),
            value: value.clamp(0.0, 1.0),
            message: None,
        }
    }

    /// Attach a human-readable detail line.
    pub fn with_message(mut self, message: impl Into<String>) -> Self {
        self.message = Some(message.into());
        self
    }
}

/// Destination for progress events.
///
/// The media pipeline only needs this trait, which keeps `sportcut-media` free
/// of any dependency on `sportcut-jobs`.
pub trait ProgressSink: Send + Sync {
    /// Report one progress event.
    fn report(&self, event: ProgressEvent);
}

/// A sink that discards everything, for tests and one-shot CLI runs.
#[derive(Debug, Default, Clone, Copy)]
pub struct NoopProgress;

impl ProgressSink for NoopProgress {
    fn report(&self, _event: ProgressEvent) {}
}
