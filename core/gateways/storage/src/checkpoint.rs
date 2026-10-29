//! Persistence of the job checkpoint file inside a match directory.
//!
//! The checkpoint *schema* belongs to the job model (`sportcut-jobs`); writing
//! it to `checkpoints.json` is the storage adapter's work. The job crate
//! declares the port, this crate implements it, so the job model never depends
//! on the adapter.

use std::path::PathBuf;

use sportcut_common::artifact::now_rfc3339;
use sportcut_common::{Result, SportcutError};
use sportcut_jobs::{JobCheckpoint, JobId, JobState};

use crate::match_dir::MatchDirectory;

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
    pub fn path(&self) -> PathBuf {
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

impl sportcut_jobs::CheckpointStore for CheckpointStore {
    fn completed_stages(&self) -> Result<Vec<String>> {
        CheckpointStore::completed_stages(self)
    }

    fn record_stage_complete(
        &self,
        job_id: &JobId,
        match_id: &str,
        stage: &str,
        state: JobState,
    ) -> Result<JobCheckpoint> {
        CheckpointStore::record_stage_complete(self, job_id, match_id, stage, state)
    }

    fn set_state(&self, job_id: &JobId, match_id: &str, state: JobState) -> Result<JobCheckpoint> {
        CheckpointStore::set_state(self, job_id, match_id, state)
    }

    fn mark_artifacts_non_final(&self) -> Result<()> {
        self.match_dir.mark_artifacts_non_final()
    }
}
