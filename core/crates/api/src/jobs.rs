//! Job handles the client can hold on to.
//!
//! Long work is started by a facade call that returns as soon as the job is
//! admitted, so the client can show progress and cancel while the work runs.
//! That only works if the engine remembers a job after the call that started it
//! has returned, which is what this module provides: one process-wide store of
//! running sessions, plus the registry that enforces one heavy job at a time.
//!
//! Everything here is crate-internal. The contract the client sees is the
//! facade: a start function that returns a job identifier, and status and cancel
//! functions that take one back.

use std::collections::{HashMap, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock};

use anyhow::{anyhow, Result};
use sportcut_jobs::{JobLease, JobRegistry, JobSession};

use crate::facade::to_anyhow;

/// How many finished jobs stay readable.
///
/// A client polls a job until it reaches a terminal state and stops, so it only
/// needs the last one or two answers. The bound is what keeps a long-lived
/// process — a whole match review, several imports, repeated exports — from
/// accumulating sessions forever.
const RETAINED_JOBS: usize = 16;

#[derive(Debug)]
struct JobEntry {
    session: Arc<JobSession>,
    match_dir: PathBuf,
    /// Whether the job's progress is recorded in the match's checkpoint file.
    ///
    /// Import resumes from checkpoints, so its completed stages are read from
    /// there. A repair or an export decides what to do from the manifest or from
    /// the request, records nothing, and must not be reported as having run the
    /// pipeline stages that happen to be recorded for that match.
    resumes_pipeline: bool,
}

#[derive(Debug, Default)]
struct StoreState {
    /// Jobs that have not reached a terminal state.
    running: HashMap<String, JobEntry>,
    /// Jobs that have finished, retained so a late poll still answers.
    finished: HashMap<String, JobEntry>,
    /// Identifiers of finished jobs, oldest first, for eviction.
    order: VecDeque<String>,
}

#[derive(Debug, Default)]
struct JobStore {
    registry: Arc<JobRegistry>,
    state: Mutex<StoreState>,
}

impl JobStore {
    /// The store for this process.
    fn global() -> &'static JobStore {
        static STORE: OnceLock<JobStore> = OnceLock::new();
        STORE.get_or_init(JobStore::default)
    }

    fn lock(&self) -> MutexGuard<'_, StoreState> {
        self.state.lock().expect("job store mutex")
    }
}

/// Admit a job and remember it, or reject it before any work starts.
///
/// Admission is synchronous on purpose: a caller that is going to be rejected
/// because another heavy job is running finds out now, and never receives a
/// handle for work that will not run.
pub(crate) fn open(
    session: &Arc<JobSession>,
    match_dir: &Path,
    resumes_pipeline: bool,
) -> Result<JobLease> {
    let store = JobStore::global();
    let lease = store
        .registry
        .try_admit(session.id().clone(), session.match_id())
        .map_err(to_anyhow)?;

    store.lock().running.insert(
        session.id().to_string(),
        JobEntry {
            session: Arc::clone(session),
            match_dir: match_dir.to_path_buf(),
            resumes_pipeline,
        },
    );
    Ok(lease)
}

/// Move a job to the finished set, evicting the oldest finished job past the cap.
pub(crate) fn finish(job_id: &str) {
    let store = JobStore::global();
    let mut state = store.lock();

    if let Some(entry) = state.running.remove(job_id) {
        state.finished.insert(job_id.to_string(), entry);
        state.order.push_back(job_id.to_string());
    }

    while state.order.len() > RETAINED_JOBS {
        if let Some(oldest) = state.order.pop_front() {
            state.finished.remove(&oldest);
        }
    }
}

/// Forget a job that was admitted but never handed to a worker.
pub(crate) fn forget(job_id: &str) {
    JobStore::global().lock().running.remove(job_id);
}

/// The session behind a job identifier, with the match directory its progress
/// is recorded in and whether that record is the job's to read.
pub(crate) fn lookup(job_id: &str) -> Option<(Arc<JobSession>, PathBuf, bool)> {
    let store = JobStore::global();
    let state = store.lock();
    state
        .running
        .get(job_id)
        .or_else(|| state.finished.get(job_id))
        .map(|entry| {
            (
                Arc::clone(&entry.session),
                entry.match_dir.clone(),
                entry.resumes_pipeline,
            )
        })
}

/// Cancel a job by identifier, answering with the session that was cancelled.
pub(crate) fn cancel(job_id: &str) -> Result<Arc<JobSession>> {
    let (session, _, _) = lookup(job_id).ok_or_else(|| unknown_job(job_id))?;
    session.cancel();
    Ok(session)
}

/// The error raised for a job identifier this process does not know.
pub(crate) fn unknown_job(job_id: &str) -> anyhow::Error {
    anyhow!(
        "no job {job_id} is known; it may never have started, or it finished long enough ago \
         that the engine stopped retaining it"
    )
}
