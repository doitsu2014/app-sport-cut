//! Coverage for the `processing-jobs` spec: lifecycle, progress semantics,
//! cancellation, checkpoint/resume, and single-heavy-job admission.

use std::sync::{Arc, Mutex};

use sportcut_common::{CancelToken, SportcutError};
use sportcut_jobs::{execute, CheckpointStore, JobId, JobPlan, JobRegistry, JobSession, JobState};
use sportcut_storage::{ArtifactKind, ArtifactManifest, ArtifactState, MatchDirectory};

const STAGES: [&str; 4] = ["probe", "proxy", "audio", "frames"];

fn match_dir(name: &str) -> (tempfile::TempDir, MatchDirectory) {
    let dir = tempfile::tempdir().expect("temp dir");
    let match_dir = MatchDirectory::new(dir.path().join(name));
    match_dir.create().expect("create match directory");
    (dir, match_dir)
}

#[test]
fn progress_does_not_decrease_within_a_stage_and_resets_on_stage_change() {
    let session = JobSession::new("match-1", CancelToken::new());
    assert_eq!(session.state(), JobState::Pending);

    let context = session.context();
    for value in [0.2, 0.6, 0.3, 0.6, 0.9] {
        context.report("proxy", value, None);
    }
    assert_eq!(session.state(), JobState::Running);

    let proxy_values: Vec<f64> = session
        .events()
        .into_iter()
        .map(|event| event.value)
        .collect();
    assert_eq!(proxy_values, vec![0.2, 0.6, 0.6, 0.6, 0.9]);

    // A new stage starts its own scale, and its label is reported.
    context.report("audio", 0.1, Some("extracting".to_string()));
    let status = session.status();
    assert_eq!(status.stage.as_deref(), Some("audio"));
    let progress = status.progress.expect("progress");
    assert_eq!(progress.stage, "audio");
    assert_eq!(progress.value, 0.1);
    assert_eq!(progress.message.as_deref(), Some("extracting"));
}

#[test]
fn a_completed_job_reports_completed_and_records_its_stages() {
    let (_dir, match_dir) = match_dir("match-2");
    let registry = JobRegistry::new();
    let checkpoints = CheckpointStore::new(&match_dir);
    let session = JobSession::new("match-2", CancelToken::new());
    let plan = JobPlan::new("match-2", STAGES);

    let observed = Arc::new(Mutex::new(Vec::new()));
    let recorder = Arc::clone(&observed);

    let run = execute(
        &registry,
        &session,
        &checkpoints,
        &plan,
        move |stage, ctx| {
            recorder
                .lock()
                .expect("observed mutex")
                .push((stage.to_string(), ctx.status().state));
            ctx.report(stage, 0.5, None);
            Ok(())
        },
    )
    .expect("job should complete");

    assert_eq!(run.state, JobState::Completed);
    assert_eq!(run.executed_stages, STAGES.to_vec());
    assert!(run.skipped_stages.is_empty());
    assert_eq!(session.state(), JobState::Completed);

    let seen = observed.lock().expect("observed mutex").clone();
    assert_eq!(seen.len(), STAGES.len());
    assert!(
        seen.iter().all(|(_, state)| *state == JobState::Running),
        "{seen:?}"
    );

    let status = session.status_with_stages(checkpoints.completed_stages().expect("checkpoints"));
    assert_eq!(status.state, JobState::Completed);
    assert_eq!(status.completed_stages, STAGES.to_vec());
}

#[test]
fn a_failing_stage_reports_the_stage_and_a_reason() {
    let (_dir, match_dir) = match_dir("match-3");
    let registry = JobRegistry::new();
    let checkpoints = CheckpointStore::new(&match_dir);
    let session = JobSession::new("match-3", CancelToken::new());
    let plan = JobPlan::new("match-3", STAGES);

    let error = execute(&registry, &session, &checkpoints, &plan, |stage, _ctx| {
        if stage == "audio" {
            return Err(SportcutError::InvalidInput(
                "the source has no decodable audio".to_string(),
            ));
        }
        Ok(())
    })
    .expect_err("the job must fail");

    match error {
        SportcutError::JobFailed {
            stage, ref reason, ..
        } => {
            assert_eq!(stage, "audio");
            assert!(reason.contains("no decodable audio"), "{reason}");
        }
        other => panic!("unexpected error: {other}"),
    }

    let status = session.status();
    assert_eq!(status.state, JobState::Failed);
    assert_eq!(status.stage.as_deref(), Some("audio"));
    assert!(status.error.expect("reason").contains("no decodable audio"));

    // The stage that failed is not checkpointed, so a resume retries it.
    assert_eq!(
        checkpoints.completed_stages().expect("checkpoints"),
        vec!["probe".to_string(), "proxy".to_string()]
    );
}

#[test]
fn an_interrupted_job_resumes_from_the_last_completed_stage() {
    let (_dir, match_dir) = match_dir("match-4");
    let registry = JobRegistry::new();
    let checkpoints = CheckpointStore::new(&match_dir);
    let plan = JobPlan::new("match-4", STAGES);

    // First run: interrupted during `audio`.
    let first_session = JobSession::new("match-4", CancelToken::new());
    let first_attempt = execute(
        &registry,
        &first_session,
        &checkpoints,
        &plan,
        |stage, _ctx| {
            if stage == "audio" {
                return Err(SportcutError::InvalidInput(
                    "simulated interruption".to_string(),
                ));
            }
            Ok(())
        },
    );
    assert!(first_attempt.is_err());

    // A new process would build a fresh store from the same match directory.
    let reopened = CheckpointStore::new(&match_dir);
    assert_eq!(
        reopened.completed_stages().expect("checkpoints"),
        vec!["probe".to_string(), "proxy".to_string()]
    );
    assert!(
        reopened.path().is_file(),
        "checkpoints must survive a restart"
    );

    // Second run: resumes and does not re-execute the finished stages.
    let executed = Arc::new(Mutex::new(Vec::new()));
    let recorder = Arc::clone(&executed);
    let second_session = JobSession::new("match-4", CancelToken::new());
    let run = execute(
        &registry,
        &second_session,
        &reopened,
        &plan,
        move |stage, ctx| {
            recorder
                .lock()
                .expect("executed mutex")
                .push(stage.to_string());
            ctx.report(stage, 1.0, None);
            Ok(())
        },
    )
    .expect("resumed job should complete");

    assert_eq!(
        run.executed_stages,
        vec!["audio".to_string(), "frames".to_string()]
    );
    assert_eq!(
        run.skipped_stages,
        vec!["probe".to_string(), "proxy".to_string()]
    );
    assert_eq!(
        executed.lock().expect("executed mutex").clone(),
        vec!["audio".to_string(), "frames".to_string()]
    );
    assert_eq!(second_session.state(), JobState::Completed);
    assert_eq!(
        reopened.completed_stages().expect("checkpoints"),
        STAGES.to_vec()
    );
}

#[test]
fn cancellation_stops_work_and_marks_partial_artifacts_non_final() {
    let (_dir, match_dir) = match_dir("match-5");
    let registry = JobRegistry::new();
    let checkpoints = CheckpointStore::new(&match_dir);
    let session = JobSession::new("match-5", CancelToken::new());
    let plan = JobPlan::new("match-5", STAGES);

    // A previous stage leaves a finished artifact behind.
    let mut manifest = ArtifactManifest::new("match-5", std::path::Path::new("/tmp/original.mp4"));
    manifest.record_artifact(
        ArtifactKind::Proxy,
        "proxy/proxy.mp4",
        ArtifactState::Final,
        Some(1234),
    );
    manifest
        .save(&match_dir.manifest_path())
        .expect("save manifest");

    let error = execute(&registry, &session, &checkpoints, &plan, |stage, ctx| {
        if stage == "proxy" {
            // The stage notices the cancel request and stops what it is doing.
            ctx.cancel();
            return Err(SportcutError::Cancelled);
        }
        Ok(())
    })
    .expect_err("a cancelled job must not report success");

    assert!(error.is_cancellation(), "{error}");
    assert_eq!(session.state(), JobState::Cancelled);
    assert_eq!(
        checkpoints
            .load()
            .expect("checkpoint")
            .expect("checkpoint file")
            .state,
        JobState::Cancelled
    );

    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).expect("manifest");
    assert!(
        manifest
            .artifacts
            .iter()
            .all(|entry| entry.state == ArtifactState::NonFinal),
        "{:?}",
        manifest.artifacts
    );
    let summary = manifest.summarize(match_dir.root());
    assert!(summary.complete.is_empty(), "{summary:?}");
}

#[test]
fn a_second_job_for_the_same_match_is_rejected() {
    let registry = JobRegistry::new();
    let first = JobId::generate();
    let lease = registry
        .try_admit(first.clone(), "match-6")
        .expect("first admission");

    let second = JobId::generate();
    let error = registry
        .try_admit(second.clone(), "match-6")
        .expect_err("the second job must be rejected");
    match error {
        SportcutError::JobRejected { job_id, reason } => {
            assert_eq!(job_id, second.to_string());
            assert!(
                reason.contains("already running for this match"),
                "{reason}"
            );
        }
        other => panic!("unexpected error: {other}"),
    }

    // The rejection did not disturb the running job.
    assert_eq!(registry.active_job_for("match-6"), Some(first));
    drop(lease);
    assert_eq!(registry.active_job_for("match-6"), None);
}

#[test]
fn a_conflicting_heavy_job_is_rejected_and_the_slot_is_released() {
    let registry = JobRegistry::new();

    // A job that fails releases its slot, because the lease is dropped on the
    // way out. Without this, one bad recording would block every later job.
    let (_dir, match_dir) = match_dir("match-7");
    let checkpoints = CheckpointStore::new(&match_dir);
    let failing = JobSession::new("match-7", CancelToken::new());
    let plan = JobPlan::new("match-7", ["probe"]);
    let result = execute(&registry, &failing, &checkpoints, &plan, |_stage, _ctx| {
        Err(SportcutError::InvalidInput("boom".to_string()))
    });
    assert!(result.is_err());
    assert_eq!(registry.active_heavy_job(), None);
    assert_eq!(registry.active_job_for("match-7"), None);

    // While a heavy job runs, a second one for another match is rejected rather
    // than run concurrently.
    let lease = registry
        .try_admit(JobId::generate(), "match-8")
        .expect("first admission");
    let error = registry
        .try_admit(JobId::generate(), "match-9")
        .expect_err("only one heavy job may run");
    match error {
        SportcutError::JobRejected { reason, .. } => {
            assert!(reason.contains("only one runs at a time"), "{reason}");
        }
        other => panic!("unexpected error: {other}"),
    }

    drop(lease);
    assert_eq!(registry.active_heavy_job(), None);
    assert!(registry.try_admit(JobId::generate(), "match-9").is_ok());
}
