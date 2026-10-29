//! Checkpointed progress of a job.
//!
//! Completed stages are written to `checkpoints.json` inside the match
//! directory. The file outlives the process, which is what makes "resume after
//! the host application restarts" possible: a later run reads it from disk and
//! skips the stages recorded there.
//!
//! This module owns the *schema* and the port. Persisting the file is the
//! storage adapter's work, so the job model never depends on the crate that
//! writes it: [`CheckpointStore`] is declared here and implemented there.

use serde::{Deserialize, Serialize};
use sportcut_common::artifact::now_rfc3339;
use sportcut_common::Result;

use crate::id::JobId;
use crate::state::JobState;

/// Persisted progress of a job.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JobCheckpoint {
    /// Schema version, so the file can be migrated rather than guessed at.
    pub schema_version: u32,
    /// Job that last wrote this file.
    pub job_id: String,
    /// Match the job belongs to.
    pub match_id: String,
    /// Stages that finished successfully and must not be re-executed.
    #[serde(default)]
    pub completed_stages: Vec<String>,
    /// Last recorded lifecycle state.
    pub state: JobState,
    /// RFC 3339 timestamp of the last write.
    pub updated_at: String,
}

impl JobCheckpoint {
    /// Schema version written by this build.
    pub const SCHEMA_VERSION: u32 = 1;

    /// Start an empty checkpoint for a job.
    pub fn new(job_id: &JobId, match_id: &str, state: JobState) -> Self {
        Self {
            schema_version: Self::SCHEMA_VERSION,
            job_id: job_id.to_string(),
            match_id: match_id.to_string(),
            completed_stages: Vec::new(),
            state,
            updated_at: now_rfc3339(),
        }
    }
}

/// Where a job's progress is recorded.
///
/// The runner reads completed stages before it starts, records each stage as it
/// finishes, and — on cancellation — marks the match's artifacts non-final.
/// All three are storage operations; the port is declared here so the job model
/// stays free of the adapter that implements it.
pub trait CheckpointStore: std::fmt::Debug {
    /// Stages recorded as complete for this match.
    fn completed_stages(&self) -> Result<Vec<String>>;

    /// Record a stage as complete and persist it immediately.
    fn record_stage_complete(
        &self,
        job_id: &JobId,
        match_id: &str,
        stage: &str,
        state: JobState,
    ) -> Result<JobCheckpoint>;

    /// Persist the lifecycle state without touching completed stages.
    fn set_state(&self, job_id: &JobId, match_id: &str, state: JobState) -> Result<JobCheckpoint>;

    /// Mark every artifact the job could have touched as non-final.
    fn mark_artifacts_non_final(&self) -> Result<()>;
}
