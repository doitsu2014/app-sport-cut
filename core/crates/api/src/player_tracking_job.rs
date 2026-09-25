//! macOS development job connecting local person inference to player tracks.

use std::path::PathBuf;
use std::sync::Arc;

use anyhow::{anyhow, Result};
use sportcut_common::SportcutError;
use sportcut_jobs::{execute_admitted, CheckpointStore, JobLease, JobPlan, JobSession};
use sportcut_media::{
    run_stage, validate_sampling_rate, MediaToolchain, PipelineContext, PipelineOptions,
    SampledFrame, PROXY_RELATIVE_PATH, STAGE_FRAMES,
};
use sportcut_storage::{
    load_calibration, ArtifactKind, ArtifactManifest, ArtifactState, MatchDirectory,
    CALIBRATION_RELATIVE_PATH,
};
use sportcut_vision::{
    analyze_sampled_frames, TflitePersonDetector, TrackingConfig, TrackingResult,
};

use crate::dto::{JobHandleDto, PlayerTrackingRequestDto};
use crate::facade::{handle_for, spawn_worker};
use crate::jobs;
use crate::track_artifact::{
    content_fingerprint, fingerprint_file, fingerprint_samples, save_track_artifact, TrackArtifact,
    TrackProvenance,
};

const ANALYSIS_STAGE: &str = "player_analysis";
const PUBLISH_STAGE: &str = "publish_tracks";
const RUNTIME_ENV: &str = "SPORTCUT_TFLITE_LIBRARY";
const MODEL_ENV: &str = "SPORTCUT_PERSON_MODEL";
const TRIAL_MODEL_FINGERPRINT: &str = "fnv1a64:0a4c9e64faa2dae8";

#[derive(Debug)]
struct JobInputs {
    match_dir: MatchDirectory,
    original_manifest: ArtifactManifest,
    sampling_rate: f64,
    config: TrackingConfig,
    detector: TflitePersonDetector,
    runtime_path: PathBuf,
    runtime_fingerprint: String,
    model_path: PathBuf,
    model_fingerprint: String,
}

pub(crate) fn start(request: PlayerTrackingRequestDto) -> Result<JobHandleDto> {
    let config = TrackingConfig::from(&request.config);
    config.validate().map_err(to_anyhow)?;
    validate_sampling_rate(request.config.sampling_rate).map_err(to_anyhow)?;
    let runtime_path = local_asset(RUNTIME_ENV, "TFLite runtime")?;
    let model_path = local_asset(MODEL_ENV, "person model weights")?;
    let model_fingerprint = fingerprint_file(&model_path).map_err(to_anyhow)?;
    if model_fingerprint != TRIAL_MODEL_FINGERPRINT {
        return Err(anyhow!(
            "person model bytes differ from the supported EfficientDet-Lite0 trial file"
        ));
    }
    let runtime_fingerprint = fingerprint_file(&runtime_path).map_err(to_anyhow)?;
    let detector =
        TflitePersonDetector::open(&runtime_path, &model_path, config.court.min_confidence)
            .map_err(to_anyhow)?;
    let match_dir = MatchDirectory::new(&request.match_dir);
    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).map_err(to_anyhow)?;
    let calibration = manifest.entry(ArtifactKind::Calibration).ok_or_else(|| {
        anyhow!("court calibration is unavailable; mark the court before player analysis")
    })?;
    if calibration.state != ArtifactState::Final
        || calibration.relative_path != CALIBRATION_RELATIVE_PATH
    {
        return Err(anyhow!(
            "court calibration is unavailable; restore it before player analysis"
        ));
    }
    let proxy = manifest.entry(ArtifactKind::Proxy).ok_or_else(|| {
        anyhow!("analysis proxy is unavailable; import or regenerate match media first")
    })?;
    if proxy.state != ArtifactState::Final
        || proxy.relative_path != PROXY_RELATIVE_PATH
        || !match_dir.resolve(PROXY_RELATIVE_PATH).is_file()
    {
        return Err(anyhow!(
            "analysis proxy is unavailable; import or regenerate match media first"
        ));
    }
    let session = JobSession::new(
        manifest.match_id.clone(),
        sportcut_common::CancelToken::new(),
    );
    let lease = jobs::open(&session, match_dir.root(), false)?;
    let handle = handle_for(&session);
    let inputs = JobInputs {
        match_dir,
        original_manifest: manifest,
        sampling_rate: request.config.sampling_rate,
        config,
        detector,
        runtime_path,
        runtime_fingerprint,
        model_path,
        model_fingerprint,
    };
    spawn_worker("player-tracking", &session, lease, move |session, lease| {
        run(&inputs, session, lease)
    })?;
    Ok(handle)
}

fn run(inputs: &JobInputs, session: &Arc<JobSession>, lease: JobLease) -> Result<()> {
    let toolchain = MediaToolchain::discover().map_err(to_anyhow)?;
    let checkpoints = CheckpointStore::new(&inputs.match_dir);
    let plan = JobPlan::new(
        inputs.original_manifest.match_id.clone(),
        [STAGE_FRAMES, ANALYSIS_STAGE, PUBLISH_STAGE],
    )
    .without_resume();
    let options = PipelineOptions::new(&inputs.original_manifest.original.path)
        .with_sampling_rate(inputs.sampling_rate);
    let mut samples = Vec::<SampledFrame>::new();
    let mut duration_ms = 0_i64;
    let mut result = None::<TrackingResult>;
    execute_admitted(lease, session, &checkpoints, &plan, |stage, context| {
        context.check_cancelled()?;
        match stage {
            STAGE_FRAMES => {
                let pipeline_context = PipelineContext {
                    cancel: context.cancel_token(),
                    progress: context,
                };
                let report = run_stage(
                    &inputs.match_dir,
                    &toolchain,
                    &options,
                    STAGE_FRAMES,
                    &pipeline_context,
                )?;
                duration_ms = (report.metadata.duration_seconds * 1000.0).round() as i64;
                samples = report.frames;
                if duration_ms <= 0 || samples.is_empty() {
                    return Err(SportcutError::InvalidInput(
                        "player analysis has no usable sampled frames".to_string(),
                    ));
                }
            }
            ANALYSIS_STAGE => {
                let calibration = load_calibration(&inputs.match_dir)?.ok_or_else(|| {
                    SportcutError::Artifact(
                        "court calibration disappeared during player analysis".to_string(),
                    )
                })?;
                result = Some(analyze_sampled_frames(
                    &samples,
                    &inputs.detector,
                    &calibration.segments,
                    duration_ms,
                    inputs.config,
                    context,
                    &context.cancel_token(),
                )?);
            }
            PUBLISH_STAGE => {
                if fingerprint_file(&inputs.runtime_path)? != inputs.runtime_fingerprint
                    || fingerprint_file(&inputs.model_path)? != inputs.model_fingerprint
                {
                    return Err(SportcutError::Artifact(
                        "inference runtime or model changed during player analysis".to_string(),
                    ));
                }
                let manifest = ArtifactManifest::load(&inputs.match_dir.manifest_path())?;
                let calibration_path = inputs.match_dir.resolve(CALIBRATION_RELATIVE_PATH);
                let calibration = std::fs::read(&calibration_path)
                    .map_err(|error| SportcutError::io(&calibration_path, error))?;
                let provenance = TrackProvenance {
                    frames_fingerprint: fingerprint_samples(&samples)?,
                    proxy_fingerprint: fingerprint_file(
                        &inputs.match_dir.resolve(PROXY_RELATIVE_PATH),
                    )?,
                    calibration_id: content_fingerprint(&calibration),
                    runtime_id: format!("tflite-c-rs/0.0.1:{}", inputs.runtime_fingerprint),
                    model_id: "efficientdet-lite0-task-int8-v1".to_string(),
                    model_fingerprint: inputs.model_fingerprint.clone(),
                    sampling_rate: inputs.sampling_rate,
                    tracking: inputs.config,
                };
                let completed = result.take().ok_or_else(|| {
                    SportcutError::Artifact("player tracking result is unavailable".to_string())
                })?;
                let artifact = TrackArtifact::from_tracking(duration_ms, completed, provenance)?;
                context.check_cancelled()?;
                session.commit_final(|| {
                    let mut manifest = manifest;
                    save_track_artifact(
                        &inputs.match_dir,
                        &mut manifest,
                        &artifact,
                        &context.cancel_token(),
                    )
                })?;
                context.report(PUBLISH_STAGE, 1.0, None);
            }
            _ => {
                return Err(SportcutError::InvalidInput(format!(
                    "unknown player-analysis stage {stage}"
                )));
            }
        }
        Ok(())
    })
    .map(|_run| ())
    .map_err(to_anyhow)
}

fn local_asset(variable: &str, description: &str) -> Result<PathBuf> {
    let path = std::env::var_os(variable).ok_or_else(|| {
        anyhow!("{description} is unavailable; set {variable} to its local file path")
    })?;
    let path = PathBuf::from(path);
    if !path.is_file() {
        return Err(anyhow!(
            "{description} is unavailable at {}; set {variable} to a readable local file",
            path.display()
        ));
    }
    Ok(path)
}

/// Compare a saved generation with the locally configured trial assets, when
/// both paths are still configured. Saved review data remains readable if the
/// trial assets have simply been removed from this development machine.
pub(crate) fn configured_backend_is_current(provenance: &TrackProvenance) -> Result<bool> {
    let (Some(runtime), Some(model)) = (std::env::var_os(RUNTIME_ENV), std::env::var_os(MODEL_ENV))
    else {
        return Ok(true);
    };
    let runtime = PathBuf::from(runtime);
    let model = PathBuf::from(model);
    if !runtime.is_file() || !model.is_file() {
        return Ok(false);
    }
    let runtime_id = format!("tflite-c-rs/0.0.1:{}", fingerprint_file(&runtime)?);
    Ok(provenance.runtime_id == runtime_id
        && provenance.model_id == "efficientdet-lite0-task-int8-v1"
        && provenance.model_fingerprint == fingerprint_file(&model)?)
}

fn to_anyhow(error: SportcutError) -> anyhow::Error {
    anyhow!(error.to_string())
}
