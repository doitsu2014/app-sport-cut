//! The calls the mobile client makes.
//!
//! Each one is a thin, typed wrapper over the engine: no business logic lives
//! here, so the contract the client depends on is exactly the contract the
//! engine tests cover.
//!
//! Long work is started, not awaited. A `start_*` call admits the job, hands it
//! to a worker thread, and returns a handle; [`job_status`] and [`job_cancel`]
//! take that handle back. Blocking for the whole run instead would give up
//! progress and cancellation on both mobile platforms, which suspend a
//! backgrounded application.

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::thread;

use anyhow::{anyhow, Result};
use sportcut_common::{CancelToken, SportcutError};
use sportcut_export::{render, EditClip, EditList, ExportContext, TitleCard, EXPORT_RELATIVE_PATH};
use sportcut_jobs::{execute_admitted, CheckpointStore, JobLease, JobPlan, JobSession};
use sportcut_media::{
    probe, regenerate_missing, run_stage, MediaToolchain, PipelineContext, PipelineOptions, STAGES,
    STAGE_PROBE,
};
use sportcut_storage::{ArtifactKind, ArtifactManifest, ArtifactState, MatchDirectory};

use crate::dto::{
    ArtifactManifestDto, ExportRequestDto, JobHandleDto, JobStatusDto, MediaImportRequestDto,
    MediaMetadataDto,
};
use crate::jobs;

/// Stage label a repair job carries.
///
/// A repair re-derives whatever the manifest reports as missing, which is not
/// one fixed pipeline stage, so the job names itself while the stages it
/// actually re-runs report their own labels.
const REGENERATE_STAGE: &str = "regenerate";

/// Stage label an export job carries.
///
/// The renderer reports `prepare`, `render`, and `finalize` as it works, so the
/// stage the client shows while it watches changes to whichever of those is
/// running. The job's own label is what a failure before the first of them is
/// recorded against.
const EXPORT_STAGE: &str = "export";

/// Stages of a media import, in order.
pub fn media_import_stages() -> Vec<String> {
    STAGES.iter().map(|stage| stage.to_string()).collect()
}

/// Read metadata from a local recording.
pub fn probe_media(path: String) -> Result<MediaMetadataDto> {
    let toolchain = MediaToolchain::discover().map_err(to_anyhow)?;
    let metadata = probe(Path::new(&path), &toolchain).map_err(to_anyhow)?;
    Ok(MediaMetadataDto::from(&metadata))
}

/// Start importing a recording: probe, proxy, analysis audio, and frame sampling.
///
/// Returns as soon as the job is admitted. The run is a job, so an interrupted
/// import resumes from the last completed stage and a match that already has all
/// its artifacts is not re-processed. Read the outcome from the match manifest
/// once the job reports a terminal state.
pub fn start_import(request: MediaImportRequestDto) -> Result<JobHandleDto> {
    if request.match_id.trim().is_empty() {
        return Err(anyhow!("match_id must not be empty"));
    }
    if request.original_path.trim().is_empty() {
        return Err(anyhow!("original_path must not be empty"));
    }

    let match_dir = MatchDirectory::new(&request.match_dir);
    let session = JobSession::new(request.match_id.clone(), CancelToken::new());
    let lease = jobs::open(&session, match_dir.root(), true)?;
    let handle = handle_for(&session);

    spawn_worker("import", &session, lease, move |session, lease| {
        run_import(&request, &match_dir, session, lease)
    })?;

    Ok(handle)
}

/// Start rebuilding the derived artifacts a match records but no longer has.
///
/// The manifest is read here so the job can be rejected synchronously when the
/// match has never been imported, rather than failing later on a worker thread.
pub fn start_regenerate_match_media(match_dir: String, sampling_rate: f64) -> Result<JobHandleDto> {
    let match_dir = MatchDirectory::new(&match_dir);
    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).map_err(to_anyhow)?;

    let session = JobSession::new(manifest.match_id.clone(), CancelToken::new());
    let lease = jobs::open(&session, match_dir.root(), false)?;
    let handle = handle_for(&session);

    spawn_worker("regenerate", &session, lease, move |session, lease| {
        run_regenerate(&manifest, &match_dir, sampling_rate, session, lease)
    })?;

    Ok(handle)
}

/// Read the current state of a job.
///
/// The checkpointed stages are filled in from the match directory, so a run that
/// resumed reports the work that was already done before it started.
pub fn job_status(job_id: String) -> Result<JobStatusDto> {
    let (session, match_dir, resumes) =
        jobs::lookup(&job_id).ok_or_else(|| jobs::unknown_job(&job_id))?;
    let completed = if resumes {
        CheckpointStore::new(&MatchDirectory::new(match_dir))
            .completed_stages()
            .map_err(to_anyhow)?
    } else {
        Vec::new()
    };
    Ok(JobStatusDto::from(&session.status_with_stages(completed)))
}

/// Ask a job to stop.
///
/// Cancellation is cooperative: the job stops at its next cancellation check and
/// reports itself as cancelled. The status returned is the state immediately
/// after the request, which may still be `running`.
pub fn job_cancel(job_id: String) -> Result<JobStatusDto> {
    let session = jobs::cancel(&job_id)?;
    Ok(JobStatusDto::from(&session.status()))
}

/// Start rendering a match's highlight video.
///
/// Returns as soon as the job is admitted, like the other start calls. The reel
/// is written inside the match directory at a stable path and left unrecorded
/// until the render succeeds, so a cancelled export changes nothing.
pub fn export_highlight(request: ExportRequestDto) -> Result<JobHandleDto> {
    if request.match_id.trim().is_empty() {
        return Err(anyhow!("match_id must not be empty"));
    }
    if request.source_path.trim().is_empty() {
        return Err(anyhow!("source_path must not be empty"));
    }
    if request.clips.is_empty() {
        return Err(anyhow!("an export needs at least one clip"));
    }

    let match_dir = MatchDirectory::new(&request.match_dir);
    let session = JobSession::new(request.match_id.clone(), CancelToken::new());
    // An export always renders the reel the user just described; it neither
    // resumes from nor writes to the pipeline's checkpoint file.
    let lease = jobs::open(&session, match_dir.root(), false)?;
    let handle = handle_for(&session);

    spawn_worker("export", &session, lease, move |session, lease| {
        run_export(&request, &match_dir, session, lease)
    })?;

    Ok(handle)
}

/// Read the manifest of a match, including which artifacts are missing.
pub fn match_manifest(match_dir: String) -> Result<ArtifactManifestDto> {
    let match_dir = MatchDirectory::new(&match_dir);
    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).map_err(to_anyhow)?;
    Ok(ArtifactManifestDto::from_manifest(
        &manifest,
        match_dir.root(),
    ))
}

fn handle_for(session: &Arc<JobSession>) -> JobHandleDto {
    JobHandleDto {
        job_id: session.id().to_string(),
        match_id: session.match_id().to_string(),
    }
}

/// Hand a job to its own thread, and make sure it always ends somewhere.
///
/// A body that returns an error without leaving the session terminal — a failure
/// before any stage could report it — is recorded here as a failure, and the job
/// is moved to the finished set even if the worker panics, so a client polling
/// the handle can never be left watching a job that has stopped.
fn spawn_worker<F>(
    label: &'static str,
    session: &Arc<JobSession>,
    lease: JobLease,
    body: F,
) -> Result<()>
where
    F: FnOnce(&Arc<JobSession>, JobLease) -> Result<()> + Send + 'static,
{
    let worker = Arc::clone(session);
    let job_id = session.id().to_string();

    let spawned = thread::Builder::new()
        .name(format!("sportcut-{label}-{job_id}"))
        .spawn(move || {
            let _finished = FinishOnDrop(job_id);
            if let Err(error) = body(&worker, lease) {
                if !worker.state().is_terminal() {
                    worker.fail(label, error.to_string());
                }
            }
        });

    match spawned {
        Ok(_handle) => Ok(()),
        Err(error) => {
            jobs::forget(session.id().as_str());
            Err(anyhow!("could not start the {label} worker: {error}"))
        }
    }
}

/// Moves a job into the finished set, including while unwinding a panic.
struct FinishOnDrop(String);

impl Drop for FinishOnDrop {
    fn drop(&mut self) {
        jobs::finish(&self.0);
    }
}

fn run_import(
    request: &MediaImportRequestDto,
    match_dir: &MatchDirectory,
    session: &Arc<JobSession>,
    lease: JobLease,
) -> Result<()> {
    let toolchain = match MediaToolchain::discover() {
        Ok(toolchain) => toolchain,
        Err(error) => {
            // Finding the toolchain is the one step that runs before a stage
            // exists to report it, so it is recorded against the first stage.
            session.fail(STAGE_PROBE, error.to_string());
            return Err(anyhow!(error.to_string()));
        }
    };

    let checkpoints = CheckpointStore::new(match_dir);
    let plan = JobPlan::new(request.match_id.clone(), STAGES);
    let options =
        PipelineOptions::new(&request.original_path).with_sampling_rate(request.sampling_rate);

    execute_admitted(lease, session, &checkpoints, &plan, |stage, context| {
        let pipeline_context = PipelineContext {
            cancel: context.cancel_token(),
            progress: context,
        };
        run_stage(match_dir, &toolchain, &options, stage, &pipeline_context).map(|_report| ())
    })
    .map(|_run| ())
    .map_err(to_anyhow)
}

fn run_regenerate(
    manifest: &ArtifactManifest,
    match_dir: &MatchDirectory,
    sampling_rate: f64,
    session: &Arc<JobSession>,
    lease: JobLease,
) -> Result<()> {
    let toolchain = match MediaToolchain::discover() {
        Ok(toolchain) => toolchain,
        Err(error) => {
            session.fail(REGENERATE_STAGE, error.to_string());
            return Err(anyhow!(error.to_string()));
        }
    };

    let checkpoints = CheckpointStore::new(match_dir);
    // Repair decides what to re-run from the manifest, not from the checkpoint
    // file, so the plan neither skips nor records stages.
    let plan = JobPlan::new(manifest.match_id.clone(), [REGENERATE_STAGE]).without_resume();
    let options = PipelineOptions::new(&manifest.original.path).with_sampling_rate(sampling_rate);

    execute_admitted(lease, session, &checkpoints, &plan, |_stage, context| {
        let pipeline_context = PipelineContext {
            cancel: context.cancel_token(),
            progress: context,
        };
        regenerate_missing(match_dir, &toolchain, &options, &pipeline_context).map(|_kinds| ())
    })
    .map(|_run| ())
    .map_err(to_anyhow)
}

fn run_export(
    request: &ExportRequestDto,
    match_dir: &MatchDirectory,
    session: &Arc<JobSession>,
    lease: JobLease,
) -> Result<()> {
    let toolchain = match MediaToolchain::discover() {
        Ok(toolchain) => toolchain,
        Err(error) => {
            session.fail(EXPORT_STAGE, error.to_string());
            return Err(anyhow!(error.to_string()));
        }
    };

    let edit_list = edit_list_from(request, match_dir);
    let checkpoints = CheckpointStore::new(match_dir);
    // An export always renders the reel the request describes, so the plan
    // neither resumes from nor writes to the pipeline's checkpoint file.
    let plan = JobPlan::new(request.match_id.clone(), [EXPORT_STAGE]).without_resume();

    execute_admitted(
        lease,
        session,
        &checkpoints,
        &plan,
        |_stage, job_context| {
            // The renderer reports its own `prepare`, `render`, and `finalize`
            // stages through the job's context, so the client watches those labels.
            let context = ExportContext {
                cancel: job_context.cancel_token(),
                progress: job_context,
            };
            let rendered = render(&edit_list, &toolchain, &context)?;

            let manifest_path = match_dir.manifest_path();
            let mut manifest = ArtifactManifest::load(&manifest_path)?;
            manifest.record_artifact(
                ArtifactKind::Export,
                EXPORT_RELATIVE_PATH,
                ArtifactState::Final,
                Some(rendered.size_bytes),
            );
            manifest.save(&manifest_path)?;
            Ok(())
        },
    )
    .map(|_run| ())
    .map_err(to_anyhow)
}

fn edit_list_from(request: &ExportRequestDto, match_dir: &MatchDirectory) -> EditList {
    let mut edit_list = EditList::new(
        &request.source_path,
        match_dir.resolve(EXPORT_RELATIVE_PATH),
    );
    edit_list.clips = request
        .clips
        .iter()
        .map(|clip| EditClip {
            start_seconds: clip.start_seconds,
            end_seconds: clip.end_seconds,
            overlay: clip.overlay_path.as_ref().map(PathBuf::from),
        })
        .collect();
    edit_list.lead_in_seconds = request.lead_in_seconds;
    edit_list.lead_out_seconds = request.lead_out_seconds;
    edit_list.title = request.title.as_ref().map(|title| TitleCard {
        image: PathBuf::from(&title.image_path),
        seconds: title.seconds,
    });
    edit_list.music = request.music_path.as_ref().map(PathBuf::from);
    edit_list.music_gain = request.music_gain;
    edit_list
}

pub(crate) fn to_anyhow(error: SportcutError) -> anyhow::Error {
    anyhow!(error.to_string())
}
