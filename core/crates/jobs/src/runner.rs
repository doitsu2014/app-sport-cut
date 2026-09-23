//! Running a plan of stages as one job.

use std::sync::Arc;

use sportcut_common::{Result, SportcutError};
use sportcut_storage::{ArtifactManifest, MatchDirectory};

use crate::checkpoint::CheckpointStore;
use crate::id::JobId;
use crate::registry::JobRegistry;
use crate::session::{JobContext, JobSession};
use crate::state::JobState;

/// What a job is asked to do: an ordered list of stages for one match.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JobPlan {
    /// Match the job belongs to.
    pub match_id: String,
    /// Stages, in the order they must run.
    pub stages: Vec<String>,
}

impl JobPlan {
    /// Build a plan from stage names.
    pub fn new<I, S>(match_id: impl Into<String>, stages: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        Self {
            match_id: match_id.into(),
            stages: stages.into_iter().map(Into::into).collect(),
        }
    }
}

/// Outcome of a completed job.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JobRun {
    /// Identifier of the job that ran.
    pub job_id: JobId,
    /// Final lifecycle state.
    pub state: JobState,
    /// Stages executed in this run, in order.
    pub executed_stages: Vec<String>,
    /// Stages skipped because a checkpoint recorded them as complete.
    pub skipped_stages: Vec<String>,
}

/// Execute a plan, resuming from checkpoints and honouring cancellation.
///
/// The stage runner receives the stage label and a [`JobContext`] for progress
/// and cancellation. It returns `Err(SportcutError::Cancelled)` (or the token
/// is observed as cancelled) to stop the job.
pub fn execute<F>(
    registry: &Arc<JobRegistry>,
    session: &Arc<JobSession>,
    checkpoints: &CheckpointStore,
    plan: &JobPlan,
    mut stage_runner: F,
) -> Result<JobRun>
where
    F: FnMut(&str, &JobContext) -> Result<()>,
{
    if plan.match_id != session.match_id() {
        return Err(SportcutError::InvalidInput(format!(
            "job {} belongs to match {}, not {}",
            session.id(),
            session.match_id(),
            plan.match_id
        )));
    }

    // Admission happens before any work: a rejected job never starts.
    let _lease = registry.try_admit(session.id().clone(), &plan.match_id)?;

    let context = session.context();
    let mut completed = checkpoints.completed_stages()?;
    let mut executed = Vec::new();
    let mut skipped = Vec::new();

    for stage in &plan.stages {
        if completed.iter().any(|entry| entry == stage) {
            skipped.push(stage.clone());
            context.report(stage, 1.0, Some("skipped: already complete".to_string()));
            continue;
        }

        if context.is_cancelled() {
            return finish_cancelled(session, checkpoints, plan, SportcutError::Cancelled);
        }

        session.enter_stage(stage);
        context.report(stage, 0.0, None);

        match stage_runner(stage, &context) {
            Ok(()) => {
                checkpoints.record_stage_complete(
                    session.id(),
                    &plan.match_id,
                    stage,
                    JobState::Running,
                )?;
                completed.push(stage.clone());
                executed.push(stage.clone());
                context.report(stage, 1.0, None);
            }
            Err(error) if error.is_cancellation() || context.is_cancelled() => {
                return finish_cancelled(session, checkpoints, plan, SportcutError::Cancelled);
            }
            Err(error) => {
                let reason = error.to_string();
                session.fail(stage, reason.clone());
                checkpoints.set_state(session.id(), &plan.match_id, JobState::Failed)?;
                return Err(SportcutError::JobFailed {
                    job_id: session.id().to_string(),
                    stage: stage.clone(),
                    reason,
                });
            }
        }
    }

    session.complete();
    checkpoints.set_state(session.id(), &plan.match_id, JobState::Completed)?;

    Ok(JobRun {
        job_id: session.id().clone(),
        state: JobState::Completed,
        executed_stages: executed,
        skipped_stages: skipped,
    })
}

fn finish_cancelled(
    session: &Arc<JobSession>,
    checkpoints: &CheckpointStore,
    plan: &JobPlan,
    error: SportcutError,
) -> Result<JobRun> {
    session.cancel();
    checkpoints.set_state(session.id(), &plan.match_id, JobState::Cancelled)?;
    mark_artifacts_non_final(checkpoints.match_dir())?;
    Err(error)
}

/// Mark every artifact in a match directory as non-final.
///
/// Cancellation leaves partial output on disk for diagnosis, but nothing in it
/// may be presented as a result.
pub fn mark_artifacts_non_final(match_dir: &MatchDirectory) -> Result<()> {
    let manifest_path = match_dir.manifest_path();
    if !manifest_path.is_file() {
        return Ok(());
    }
    let mut manifest = ArtifactManifest::load(&manifest_path)?;
    manifest.mark_all_non_final();
    manifest.save(&manifest_path)?;
    Ok(())
}
