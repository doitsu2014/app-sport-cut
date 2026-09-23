//! Checkpoint persistence inside the match directory.
//!
//! Completed stages are written to `checkpoints.json` next to the artifact
//! manifest. The file outlives the process, which is what makes "resume after
//! the host application restarts" possible: a later run reads it from disk and
//! skips the stages recorded there.

use serde::{Deserialize, Serialize};
use sportcut_common::{Result, SportcutError};
use sportcut_storage::{now_rfc3339, MatchDirectory};

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

    fn new(job_id: &JobId, match_id: &str, state: JobState) -> Self {
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

/// Reads and writes the checkpoint file of one match directory.
#[derive(Debug, Clone)]
pub struct CheckpointStore {
    match_dir: MatchDirectory,
}

impl CheckpointStore {
    /// Store backed by a match directory.
    pub fn new(match_dir: &MatchDirectory) -> Self {
        Self {
            match_dir: match_dir.clone(),
        }
    }

    /// The match directory this store writes into.
    pub fn match_dir(&self) -> &MatchDirectory {
        &self.match_dir
    }

    /// Path of the checkpoint file.
    pub fn path(&self) -> std::path::PathBuf {
        self.match_dir.checkpoint_path()
    }

    /// Read the checkpoint file, or `None` when the match has never been run.
    pub fn load(&self) -> Result<Option<JobCheckpoint>> {
        let path = self.path();
        if !path.is_file() {
            return Ok(None);
        }
        let bytes = std::fs::read(&path).map_err(|e| SportcutError::io(&path, e))?;
        let checkpoint: JobCheckpoint = serde_json::from_slice(&bytes).map_err(|e| {
            SportcutError::Artifact(format!(
                "{} is not a readable checkpoint: {e}",
                path.display()
            ))
        })?;
        Ok(Some(checkpoint))
    }

    /// Stages recorded as complete.
    pub fn completed_stages(&self) -> Result<Vec<String>> {
        Ok(self
            .load()?
            .map(|checkpoint| checkpoint.completed_stages)
            .unwrap_or_default())
    }

    /// Record a stage as complete and persist it immediately.
    pub fn record_stage_complete(
        &self,
        job_id: &JobId,
        match_id: &str,
        stage: &str,
        state: JobState,
    ) -> Result<JobCheckpoint> {
        let mut checkpoint = self
            .load()?
            .unwrap_or_else(|| JobCheckpoint::new(job_id, match_id, state));
        if !checkpoint
            .completed_stages
            .iter()
            .any(|entry| entry == stage)
        {
            checkpoint.completed_stages.push(stage.to_string());
        }
        checkpoint.job_id = job_id.to_string();
        checkpoint.match_id = match_id.to_string();
        checkpoint.state = state;
        self.save(&checkpoint)?;
        Ok(checkpoint)
    }

    /// Persist the lifecycle state without touching completed stages.
    pub fn set_state(
        &self,
        job_id: &JobId,
        match_id: &str,
        state: JobState,
    ) -> Result<JobCheckpoint> {
        let mut checkpoint = self
            .load()?
            .unwrap_or_else(|| JobCheckpoint::new(job_id, match_id, state));
        checkpoint.job_id = job_id.to_string();
        checkpoint.match_id = match_id.to_string();
        checkpoint.state = state;
        self.save(&checkpoint)?;
        Ok(checkpoint)
    }

    /// Delete the checkpoint file, abandoning the recorded progress.
    pub fn clear(&self) -> Result<()> {
        let path = self.path();
        if path.is_file() {
            std::fs::remove_file(&path).map_err(|e| SportcutError::io(&path, e))?;
        }
        Ok(())
    }

    fn save(&self, checkpoint: &JobCheckpoint) -> Result<()> {
        let path = self.path();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| SportcutError::io(parent, e))?;
        }
        let mut checkpoint = checkpoint.clone();
        checkpoint.updated_at = now_rfc3339();
        let json = serde_json::to_vec_pretty(&checkpoint)
            .map_err(|e| SportcutError::Artifact(format!("could not serialize checkpoint: {e}")))?;
        std::fs::write(&path, json).map_err(|e| SportcutError::io(&path, e))?;
        Ok(())
    }
}
