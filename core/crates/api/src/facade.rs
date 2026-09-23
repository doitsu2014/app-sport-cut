//! The calls the mobile client makes.
//!
//! Each one is a thin, typed wrapper over the engine: no business logic lives
//! here, so the contract the client depends on is exactly the contract the
//! engine tests cover.

use std::path::Path;

use anyhow::{anyhow, Result};
use sportcut_common::CancelToken;
use sportcut_jobs::{execute, CheckpointStore, JobPlan, JobRegistry, JobSession};
use sportcut_media::{
    probe, regenerate_missing, run_stage, MediaToolchain, PipelineContext, PipelineOptions,
    FRAMES_RELATIVE_PATH, STAGES,
};
use sportcut_storage::{ArtifactManifest, MatchDirectory};

use crate::dto::{
    ArtifactManifestDto, JobStatusDto, MediaImportRequestDto, MediaImportResultDto,
    MediaMetadataDto,
};

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

/// Import a recording: probe, proxy, analysis audio, and frame sampling.
///
/// The run is a job, so an interrupted import resumes from the last completed
/// stage, and a match that already has all its artifacts is not re-processed.
pub fn import_media(request: MediaImportRequestDto) -> Result<MediaImportResultDto> {
    if request.match_id.trim().is_empty() {
        return Err(anyhow!("match_id must not be empty"));
    }
    if request.original_path.trim().is_empty() {
        return Err(anyhow!("original_path must not be empty"));
    }

    let toolchain = MediaToolchain::discover().map_err(to_anyhow)?;
    let match_dir = MatchDirectory::new(&request.match_dir);
    let registry = JobRegistry::new();
    let checkpoints = CheckpointStore::new(&match_dir);
    let session = JobSession::new(request.match_id.clone(), CancelToken::new());
    let plan = JobPlan::new(request.match_id.clone(), STAGES);
    let options =
        PipelineOptions::new(&request.original_path).with_sampling_rate(request.sampling_rate);

    let run = execute(
        &registry,
        &session,
        &checkpoints,
        &plan,
        |stage, context| {
            let pipeline_context = PipelineContext {
                cancel: context.cancel_token(),
                progress: context,
            };
            run_stage(&match_dir, &toolchain, &options, stage, &pipeline_context)?;
            Ok(())
        },
    )
    .map_err(to_anyhow)?;

    // Read the outcome back from disk rather than from the stage that happened
    // to run last: a resumed import may execute no stages at all.
    let metadata = probe(Path::new(&request.original_path), &toolchain).map_err(to_anyhow)?;
    let status = session.status_with_stages(checkpoints.completed_stages().map_err(to_anyhow)?);
    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).map_err(to_anyhow)?;

    Ok(MediaImportResultDto {
        metadata: MediaMetadataDto::from(&metadata),
        manifest: ArtifactManifestDto::from_manifest(&manifest, match_dir.root()),
        job: JobStatusDto::from(&status),
        frames_sampled: count_sampled_frames(&match_dir),
        skipped_stages: run.skipped_stages,
    })
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

/// Regenerate derived artifacts that are recorded but missing from disk.
pub fn regenerate_match_media(
    match_dir: String,
    sampling_rate: f64,
) -> Result<ArtifactManifestDto> {
    let toolchain = MediaToolchain::discover().map_err(to_anyhow)?;
    let match_dir = MatchDirectory::new(&match_dir);
    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).map_err(to_anyhow)?;
    let options = PipelineOptions::new(&manifest.original.path).with_sampling_rate(sampling_rate);

    regenerate_missing(
        &match_dir,
        &toolchain,
        &options,
        &PipelineContext::default(),
    )
    .map_err(to_anyhow)?;

    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).map_err(to_anyhow)?;
    Ok(ArtifactManifestDto::from_manifest(
        &manifest,
        match_dir.root(),
    ))
}

fn to_anyhow(error: sportcut_common::SportcutError) -> anyhow::Error {
    anyhow!(error.to_string())
}

fn count_sampled_frames(match_dir: &MatchDirectory) -> u32 {
    let frames_dir = match_dir.resolve(FRAMES_RELATIVE_PATH);
    let Ok(entries) = std::fs::read_dir(frames_dir) else {
        return 0;
    };
    entries
        .flatten()
        .filter(|entry| entry.file_name().to_string_lossy().starts_with("frame_"))
        .count() as u32
}
