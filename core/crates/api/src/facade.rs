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
use serde::Deserialize;
use sportcut_common::{CancelToken, SportcutError};
use sportcut_court::{CalibrationSegment, CourtCalibration};
use sportcut_export::{render, EditClip, EditList, ExportContext, TitleCard, EXPORT_RELATIVE_PATH};
use sportcut_jobs::{execute_admitted, CheckpointStore, JobLease, JobPlan, JobSession};
use sportcut_media::{
    probe, regenerate_missing, run_stage, MediaToolchain, PipelineContext, PipelineOptions, STAGES,
    STAGE_PROBE,
};
use sportcut_rally::{segment_with_cancel, SegmentationConfig, SegmentationInput};
use sportcut_storage::{
    load_calibration, load_rally_suggestions, save_calibration, save_rally_suggestions,
    ArtifactKind, ArtifactManifest, ArtifactState, MatchDirectory, RallySuggestions,
    SuggestionInputs, CALIBRATION_RELATIVE_PATH,
};

use crate::dto::{
    ArtifactManifestDto, CalibrationSaveDto, CalibrationSaveRequestDto, CalibrationSegmentDto,
    CourtCalibrationDto, CourtGeometryDto, ExportRequestDto, JobHandleDto, JobStatusDto,
    MediaImportRequestDto, MediaMetadataDto, RallySegmentationRequestDto, RallySuggestionsDto,
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

/// Stage label for deriving rally suggestions from player tracks.
const RALLY_SEGMENTATION_STAGE: &str = "rally_segmentation";

/// Provisional track-artifact path until the Wave 2 producer is implemented.
const PLAYER_TRACKS_RELATIVE_PATH: &str = "tracks/player_tracks.json";

/// Versioned input envelope supplied by a future player-tracking stage.
#[derive(Debug, Deserialize)]
struct TrackArtifact {
    schema_version: u32,
    input: SegmentationInput,
}

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

/// Start motion-first rally analysis from a completed local track artifact.
///
/// Until Wave 2 writes `tracks/player_tracks.json`, this returns an actionable
/// unavailable-input error and does not claim that the match contains no rallies.
pub fn start_rally_segmentation(request: RallySegmentationRequestDto) -> Result<JobHandleDto> {
    let match_dir = MatchDirectory::new(&request.match_dir);
    let config = SegmentationConfig::from(&request.config);
    config.validate().map_err(to_anyhow)?;
    let (manifest, input, identity) = load_track_input(&match_dir, config)?;

    let session = JobSession::new(manifest.match_id.clone(), CancelToken::new());
    let lease = jobs::open(&session, match_dir.root(), false)?;
    let handle = handle_for(&session);
    spawn_worker(
        "rally-segmentation",
        &session,
        lease,
        move |session, lease| run_rally_segmentation(&match_dir, input, identity, session, lease),
    )?;
    Ok(handle)
}

/// Read only suggestions produced for the current tracks and configuration.
pub fn match_rally_suggestions(
    request: RallySegmentationRequestDto,
) -> Result<Option<RallySuggestionsDto>> {
    let match_dir = MatchDirectory::new(&request.match_dir);
    let config = SegmentationConfig::from(&request.config);
    let (_, _, identity) = load_track_input(&match_dir, config)?;
    let suggestions = load_rally_suggestions(&match_dir, &identity).map_err(to_anyhow)?;
    Ok(suggestions.as_ref().map(RallySuggestionsDto::from))
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

/// Derive the court geometry a marked segment defines.
///
/// Nothing is stored. This is what the application calls while the user is still
/// moving corners around, and again to redisplay a calibration it already holds,
/// so the homography lives in the engine rather than in two languages.
pub fn court_geometry(segment: CalibrationSegmentDto) -> Result<CourtGeometryDto> {
    let segment = CalibrationSegment::try_from(&segment).map_err(to_anyhow)?;
    CourtGeometryDto::from_segment(&segment).map_err(to_anyhow)
}

/// Store a match's court calibration.
///
/// The calibration is written into the match directory and recorded in the
/// manifest. A calibration that differs from the one it replaces invalidates the
/// artifacts derived from the previous court. The application writes its own
/// catalog copy after this call returns, so a calibration the catalog holds
/// always has a matching artifact behind it.
pub fn save_match_calibration(request: CalibrationSaveRequestDto) -> Result<CalibrationSaveDto> {
    if request.match_dir.trim().is_empty() {
        return Err(anyhow!("match_dir must not be empty"));
    }

    let calibration = CourtCalibration::try_from(&request.calibration).map_err(to_anyhow)?;
    let match_dir = MatchDirectory::new(&request.match_dir);
    let saved = save_calibration(&match_dir, &calibration).map_err(to_anyhow)?;

    let geometry = calibration
        .segments
        .iter()
        .map(CourtGeometryDto::from_segment)
        .collect::<sportcut_common::Result<Vec<_>>>()
        .map_err(to_anyhow)?;

    Ok(CalibrationSaveDto {
        changed: saved.changed,
        invalidated_kinds: saved.invalidated.iter().map(ToString::to_string).collect(),
        geometry,
    })
}

/// Read the court calibration stored in a match directory.
///
/// `None` when the match has never been calibrated, which is a normal state
/// rather than a failure.
pub fn match_calibration(match_dir: String) -> Result<Option<CourtCalibrationDto>> {
    let match_dir = MatchDirectory::new(&match_dir);
    let calibration = load_calibration(&match_dir).map_err(to_anyhow)?;
    Ok(calibration.as_ref().map(CourtCalibrationDto::from))
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

fn run_rally_segmentation(
    match_dir: &MatchDirectory,
    input: SegmentationInput,
    identity: SuggestionInputs,
    session: &Arc<JobSession>,
    lease: JobLease,
) -> Result<()> {
    let checkpoints = CheckpointStore::new(match_dir);
    let plan =
        JobPlan::new(session.match_id().to_string(), [RALLY_SEGMENTATION_STAGE]).without_resume();
    execute_admitted(lease, session, &checkpoints, &plan, |_stage, context| {
        context.check_cancelled()?;
        context.report(
            RALLY_SEGMENTATION_STAGE,
            0.1,
            Some("analyzing player motion".to_string()),
        );
        let result = segment_with_cancel(&input, identity.config, &context.cancel_token())?;
        context.check_cancelled()?;
        context.report(
            RALLY_SEGMENTATION_STAGE,
            0.9,
            Some("publishing rally suggestions".to_string()),
        );
        let (_, _, current) = load_track_input(match_dir, identity.config)
            .map_err(|error| SportcutError::Artifact(error.to_string()))?;
        if current != identity {
            return Err(SportcutError::Artifact(
                "tracking or calibration changed during rally analysis; run it again".to_string(),
            ));
        }
        context.check_cancelled()?;
        let suggestions = RallySuggestions::from_result(identity.clone(), result)?;
        session.commit_final(|| save_rally_suggestions(match_dir, &suggestions))?;
        context.report(RALLY_SEGMENTATION_STAGE, 1.0, None);
        Ok(())
    })
    .map(|_run| ())
    .map_err(to_anyhow)
}

fn load_track_input(
    match_dir: &MatchDirectory,
    config: SegmentationConfig,
) -> Result<(ArtifactManifest, SegmentationInput, SuggestionInputs)> {
    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).map_err(to_anyhow)?;
    let calibration = manifest.entry(ArtifactKind::Calibration).ok_or_else(|| {
        anyhow!("court calibration is unavailable; mark the court before rally analysis")
    })?;
    if calibration.state != ArtifactState::Final
        || calibration.relative_path != CALIBRATION_RELATIVE_PATH
        || !match_dir.resolve(CALIBRATION_RELATIVE_PATH).is_file()
    {
        return Err(anyhow!(
            "court calibration is unavailable; restore it before rally analysis"
        ));
    }
    let tracks = manifest.entry(ArtifactKind::Tracks).ok_or_else(|| {
        anyhow!("player tracks are unavailable; run player tracking before rally analysis")
    })?;
    if tracks.state != ArtifactState::Final || tracks.relative_path != PLAYER_TRACKS_RELATIVE_PATH {
        return Err(anyhow!(
            "player tracks are not a completed supported artifact; run player tracking again"
        ));
    }
    let path = match_dir.resolve(PLAYER_TRACKS_RELATIVE_PATH);
    let bytes = std::fs::read(&path)
        .map_err(|error| anyhow!("cannot read player tracks at {}: {error}", path.display()))?;
    let artifact: TrackArtifact = serde_json::from_slice(&bytes).map_err(|error| {
        anyhow!(
            "player tracks at {} are unreadable: {error}",
            path.display()
        )
    })?;
    if artifact.schema_version != 1 {
        return Err(anyhow!(
            "player track schema {} is unsupported; expected 1",
            artifact.schema_version
        ));
    }
    if let Some(recorded_duration) = manifest.original.duration_seconds {
        let track_duration = artifact.input.duration_ms as f64 / 1000.0;
        if !recorded_duration.is_finite() || (track_duration - recorded_duration).abs() > 0.5 {
            return Err(anyhow!(
                "player tracks do not match the recording duration; run tracking again"
            ));
        }
    }
    let calibration_path = match_dir.resolve(CALIBRATION_RELATIVE_PATH);
    let calibration_bytes = std::fs::read(&calibration_path).map_err(|error| {
        anyhow!(
            "cannot read court calibration at {}: {error}",
            calibration_path.display()
        )
    })?;
    if artifact.input.calibration_id != content_fingerprint(&calibration_bytes) {
        return Err(anyhow!(
            "player tracks were produced for a different court calibration; run tracking again"
        ));
    }
    let audio_fingerprint = artifact
        .input
        .audio
        .as_ref()
        .map(|audio| serde_json::to_vec(audio).map(|bytes| content_fingerprint(&bytes)))
        .transpose()?;
    let identity = SuggestionInputs {
        duration_ms: artifact.input.duration_ms,
        tracks_fingerprint: content_fingerprint(&bytes),
        calibration_id: artifact.input.calibration_id.clone(),
        audio_fingerprint,
        config,
    };
    identity.validate().map_err(to_anyhow)?;
    Ok((manifest, artifact.input, identity))
}

fn content_fingerprint(bytes: &[u8]) -> String {
    let hash = bytes.iter().fold(0xcbf29ce484222325_u64, |hash, byte| {
        (hash ^ u64::from(*byte)).wrapping_mul(0x100000001b3)
    });
    format!("fnv1a64:{hash:016x}")
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
