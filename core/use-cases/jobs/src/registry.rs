//! Admission control: one resource-intensive job at a time.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, MutexGuard};

use sportcut_common::{Result, SportcutError};

use crate::id::JobId;

#[derive(Debug, Default)]
struct RegistryState {
    /// Match identifier to the job currently working on it.
    active: HashMap<String, JobId>,
    /// The one resource-intensive job that may run.
    heavy: Option<JobId>,
}

/// Tracks which jobs are running.
#[derive(Debug, Default)]
pub struct JobRegistry {
    inner: Mutex<RegistryState>,
}

impl JobRegistry {
    /// Create a registry behind an `Arc`, ready to hand to jobs.
    pub fn new() -> Arc<Self> {
        Arc::new(Self::default())
    }

    /// The job currently working on a match, if any.
    pub fn active_job_for(&self, match_id: &str) -> Option<JobId> {
        self.lock().active.get(match_id).cloned()
    }

    /// The resource-intensive job currently running, if any.
    pub fn active_heavy_job(&self) -> Option<JobId> {
        self.lock().heavy.clone()
    }

    /// Admit a job, or reject it with a reason.
    ///
    /// Rejection is explicit rather than a silent queue: the caller — and the
    /// user interface behind it — learns why nothing started, and is never left
    /// waiting on work that will not run.
    pub fn try_admit(self: &Arc<Self>, job_id: JobId, match_id: &str) -> Result<JobLease> {
        let mut state = self.lock();

        if let Some(existing) = state.active.get(match_id) {
            return Err(SportcutError::JobRejected {
                job_id: job_id.to_string(),
                reason: format!(
                    "a job ({existing}) is already running for this match; wait for it to finish or cancel it"
                ),
            });
        }

        if let Some(existing) = state.heavy.as_ref() {
            return Err(SportcutError::JobRejected {
                job_id: job_id.to_string(),
                reason: format!(
                    "another resource-intensive job ({existing}) is already running; only one runs at a time"
                ),
            });
        }

        state.active.insert(match_id.to_string(), job_id.clone());
        state.heavy = Some(job_id.clone());

        Ok(JobLease {
            registry: Arc::clone(self),
            job_id,
            match_id: match_id.to_string(),
            released: false,
        })
    }

    fn lock(&self) -> MutexGuard<'_, RegistryState> {
        self.inner.lock().expect("job registry mutex")
    }
}

/// Permission to run one job.
///
/// Dropping the lease releases the slot, so a job that fails or returns early
/// cannot leave the engine permanently busy.
#[derive(Debug)]
pub struct JobLease {
    registry: Arc<JobRegistry>,
    job_id: JobId,
    match_id: String,
    released: bool,
}

impl JobLease {
    /// Identifier of the job holding the lease.
    pub fn job_id(&self) -> &JobId {
        &self.job_id
    }

    /// Release the slot early.
    pub fn release(mut self) {
        self.release_inner();
    }

    fn release_inner(&mut self) {
        if self.released {
            return;
        }
        let mut state = self.registry.lock();
        if state.active.get(&self.match_id) == Some(&self.job_id) {
            state.active.remove(&self.match_id);
        }
        if state.heavy.as_ref() == Some(&self.job_id) {
            state.heavy = None;
        }
        self.released = true;
    }
}

impl Drop for JobLease {
    fn drop(&mut self) {
        self.release_inner();
    }
}
