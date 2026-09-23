//! Job lifecycle state and status snapshots.

use serde::{Deserialize, Serialize};

use crate::id::JobId;

/// Lifecycle state of a job.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum JobState {
    /// Accepted but not started.
    Pending,
    /// Currently executing a stage.
    Running,
    /// Finished successfully.
    Completed,
    /// Stopped by an explicit cancel request.
    Cancelled,
    /// Stopped because a stage failed.
    Failed,
}

impl JobState {
    /// Whether no further work will happen without a new job.
    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Completed | Self::Cancelled | Self::Failed)
    }
}

/// Progress within one stage.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JobProgress {
    /// Stage label, for example `proxy`.
    pub stage: String,
    /// Progress within the stage, in the range `0.0..=1.0`.
    pub value: f64,
    /// Optional human-readable detail.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

/// A snapshot of a job's current state.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JobStatus {
    /// Stable job identifier.
    pub job_id: JobId,
    /// Match the job belongs to.
    pub match_id: String,
    /// Lifecycle state.
    pub state: JobState,
    /// Stage currently executing, or the last stage reached.
    pub stage: Option<String>,
    /// Latest progress within `stage`.
    pub progress: Option<JobProgress>,
    /// Human-readable failure reason when the state is `failed`.
    pub error: Option<String>,
    /// Stages checkpointed as complete.
    pub completed_stages: Vec<String>,
}
