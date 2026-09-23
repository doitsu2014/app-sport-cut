//! Job session: identity, state, progress, and cancellation.

use std::sync::{Arc, Mutex, MutexGuard};

use sportcut_common::{CancelToken, ProgressEvent, ProgressSink, Result};

use crate::id::JobId;
use crate::state::{JobProgress, JobState, JobStatus};

#[derive(Debug, Default)]
struct SessionState {
    state: Option<JobState>,
    stage: Option<String>,
    progress: Option<JobProgress>,
    error: Option<String>,
}

/// A running (or finished) job.
///
/// Shared behind an `Arc`: the caller keeps a handle for status queries while
/// stages receive a [`JobContext`] to report progress and observe cancellation.
#[derive(Debug)]
pub struct JobSession {
    id: JobId,
    match_id: String,
    cancel: CancelToken,
    state: Mutex<SessionState>,
    events: Mutex<Vec<JobProgress>>,
}

impl JobSession {
    /// Start a session in the `pending` state.
    pub fn new(match_id: impl Into<String>, cancel: CancelToken) -> Arc<Self> {
        Arc::new(Self {
            id: JobId::generate(),
            match_id: match_id.into(),
            cancel,
            state: Mutex::new(SessionState {
                state: Some(JobState::Pending),
                ..SessionState::default()
            }),
            events: Mutex::new(Vec::new()),
        })
    }

    /// Identifier of this job.
    pub fn id(&self) -> &JobId {
        &self.id
    }

    /// Match this job belongs to.
    pub fn match_id(&self) -> &str {
        &self.match_id
    }

    /// Cancellation token shared with the stages.
    pub fn cancel_token(&self) -> CancelToken {
        self.cancel.clone()
    }

    /// A handle for stage code.
    pub fn context(self: &Arc<Self>) -> JobContext {
        JobContext {
            session: Arc::clone(self),
        }
    }

    /// Current state.
    pub fn state(&self) -> JobState {
        self.lock_state().state.unwrap_or(JobState::Pending)
    }

    /// Snapshot of the current status.
    pub fn status(&self) -> JobStatus {
        let state = self.lock_state();
        JobStatus {
            job_id: self.id.clone(),
            match_id: self.match_id.clone(),
            state: state.state.unwrap_or(JobState::Pending),
            stage: state.stage.clone(),
            progress: state.progress.clone(),
            error: state.error.clone(),
            completed_stages: Vec::new(),
        }
    }

    /// Snapshot of the status, with the checkpointed stages filled in.
    pub fn status_with_stages(&self, completed_stages: Vec<String>) -> JobStatus {
        let mut status = self.status();
        status.completed_stages = completed_stages;
        status
    }

    /// Every progress event recorded so far, in order.
    pub fn events(&self) -> Vec<JobProgress> {
        self.events.lock().expect("job events mutex").clone()
    }

    /// Move to the running state and enter a stage.
    pub(crate) fn enter_stage(&self, stage: &str) {
        let mut state = self.lock_state();
        if state.state.map(JobState::is_terminal).unwrap_or(true) {
            return;
        }
        state.state = Some(JobState::Running);
        state.stage = Some(stage.to_string());
        if state
            .progress
            .as_ref()
            .map(|progress| progress.stage.as_str())
            != Some(stage)
        {
            state.progress = Some(JobProgress {
                stage: stage.to_string(),
                value: 0.0,
                message: None,
            });
        }
    }

    /// Record progress, enforcing that the value never decreases within a stage.
    pub(crate) fn record(&self, event: ProgressEvent) {
        let mut state = self.lock_state();
        if state.state.map(JobState::is_terminal).unwrap_or(true) {
            return;
        }
        state.state = Some(JobState::Running);

        let value = match state.progress.as_ref() {
            Some(previous) if previous.stage == event.stage => previous.value.max(event.value),
            _ => event.value,
        };

        let progress = JobProgress {
            stage: event.stage,
            value,
            message: event.message,
        };
        state.stage = Some(progress.stage.clone());
        state.progress = Some(progress.clone());
        self.events.lock().expect("job events mutex").push(progress);
    }

    /// Mark the job completed.
    pub(crate) fn complete(&self) {
        let mut state = self.lock_state();
        if state.state.map(JobState::is_terminal).unwrap_or(false) {
            return;
        }
        state.state = Some(JobState::Completed);
        if let Some(progress) = state.progress.as_mut() {
            progress.value = 1.0;
        }
    }

    /// Mark the job failed, naming the stage and the reason.
    pub(crate) fn fail(&self, stage: &str, reason: impl Into<String>) {
        let mut state = self.lock_state();
        state.state = Some(JobState::Failed);
        state.stage = Some(stage.to_string());
        state.error = Some(reason.into());
    }

    /// Request cancellation: flips the token and moves the job to `cancelled`.
    pub fn cancel(&self) {
        self.cancel.cancel();
        let mut state = self.lock_state();
        if state.state.map(JobState::is_terminal).unwrap_or(false) {
            return;
        }
        state.state = Some(JobState::Cancelled);
    }

    fn lock_state(&self) -> MutexGuard<'_, SessionState> {
        self.state.lock().expect("job state mutex")
    }
}

/// Stage-facing handle: report progress, observe cancellation.
#[derive(Debug, Clone)]
pub struct JobContext {
    session: Arc<JobSession>,
}

impl JobContext {
    /// Identifier of the owning job.
    pub fn job_id(&self) -> &JobId {
        self.session.id()
    }

    /// Report progress within a stage.
    pub fn report(&self, stage: &str, value: f64, message: Option<String>) {
        self.session.record(ProgressEvent {
            stage: stage.to_string(),
            value: value.clamp(0.0, 1.0),
            message,
        });
    }

    /// Shared cancellation token.
    pub fn cancel_token(&self) -> CancelToken {
        self.session.cancel_token()
    }

    /// Return `Err(Cancelled)` when cancellation has been requested.
    pub fn check_cancelled(&self) -> Result<()> {
        self.session.cancel_token().check()
    }

    /// Whether cancellation has been requested.
    pub fn is_cancelled(&self) -> bool {
        self.session.cancel_token().is_cancelled()
    }

    /// Request cancellation of this job.
    pub fn cancel(&self) {
        self.session.cancel();
    }

    /// Snapshot of the job status.
    pub fn status(&self) -> JobStatus {
        self.session.status()
    }
}

impl ProgressSink for JobContext {
    fn report(&self, event: ProgressEvent) {
        self.session.record(event);
    }
}
