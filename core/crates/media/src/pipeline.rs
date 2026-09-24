//! The media pipeline: probe, proxy, analysis audio, and frames into one match
//! directory.

use std::path::{Path, PathBuf};

use sportcut_common::{
    CancelToken, NoopProgress, ProgressEvent, ProgressSink, Result, SportcutError,
};
use sportcut_storage::{ArtifactKind, ArtifactManifest, ArtifactState, MatchDirectory};

use crate::audio;
use crate::frames::{self, FrameSamplingOptions, SampledFrame};
use crate::probe::{self, MediaMetadata};
use crate::proxy::{self, ProxyOptions};
use crate::toolchain::MediaToolchain;

/// Stage label for probing.
pub const STAGE_PROBE: &str = "probe";
/// Stage label for proxy generation.
pub const STAGE_PROXY: &str = "proxy";
/// Stage label for analysis audio extraction.
pub const STAGE_AUDIO: &str = "audio";
/// Stage label for frame sampling.
pub const STAGE_FRAMES: &str = "frames";

/// Relative path of the proxy inside a match directory.
pub const PROXY_RELATIVE_PATH: &str = "proxy/proxy.mp4";
/// Relative path of the analysis audio inside a match directory.
pub const AUDIO_RELATIVE_PATH: &str = "audio/analysis.m4a";
/// Relative path of the frame directory inside a match directory.
pub const FRAMES_RELATIVE_PATH: &str = "frames";

/// Every stage of the media pipeline, in execution order.
pub const STAGES: [&str; 4] = [STAGE_PROBE, STAGE_PROXY, STAGE_AUDIO, STAGE_FRAMES];

/// Artifact kinds this pipeline can rebuild on its own, from the original
/// recording.
///
/// Everything else is either user input — a court calibration the engine never
/// invents — or output that needs a request the caller supplies, like the edit
/// list an export renders. Reporting those as rebuilt would claim work that
/// never happened.
pub const REBUILDABLE_KINDS: [ArtifactKind; 3] = [
    ArtifactKind::Proxy,
    ArtifactKind::AnalysisAudio,
    ArtifactKind::Frames,
];

/// What a regeneration run found, and how much of it it could do.
#[derive(Debug, Clone, PartialEq)]
pub struct Regeneration {
    /// Artifact kinds that were missing and were rebuilt.
    pub rebuilt: Vec<ArtifactKind>,
    /// Artifact kinds that are missing but that this pipeline cannot rebuild,
    /// because they are supplied by the user or by a caller's request.
    pub not_rebuildable: Vec<ArtifactKind>,
}

impl Regeneration {
    /// Whether the match was missing nothing at all.
    pub fn is_empty(&self) -> bool {
        self.rebuilt.is_empty() && self.not_rebuildable.is_empty()
    }
}

/// Options for a full pipeline run.
#[derive(Debug, Clone, PartialEq)]
pub struct PipelineOptions {
    /// Original recording; referenced in place, never copied or modified.
    pub original: PathBuf,
    /// Frame sampling rate.
    pub sampling_rate: f64,
    /// Maximum proxy height.
    pub proxy_max_height: u32,
}

impl PipelineOptions {
    /// Options with the default sampling rate and proxy size.
    pub fn new(original: impl Into<PathBuf>) -> Self {
        Self {
            original: original.into(),
            sampling_rate: FrameSamplingOptions::default().rate,
            proxy_max_height: ProxyOptions::default().max_height,
        }
    }

    /// Override the frame sampling rate.
    pub fn with_sampling_rate(mut self, rate: f64) -> Self {
        self.sampling_rate = rate;
        self
    }

    fn frame_options(&self) -> FrameSamplingOptions {
        FrameSamplingOptions {
            rate: self.sampling_rate,
        }
    }

    fn proxy_options(&self) -> ProxyOptions {
        ProxyOptions {
            max_height: self.proxy_max_height,
        }
    }
}

/// What a pipeline run produced.
#[derive(Debug)]
pub struct PipelineReport {
    /// Metadata of the original recording.
    pub metadata: MediaMetadata,
    /// Proxy path, when one exists after this run.
    pub proxy: Option<PathBuf>,
    /// Analysis audio path, absent when the source has no audio track.
    pub audio: Option<PathBuf>,
    /// Sampled frames, empty when sampling was skipped.
    pub frames: Vec<SampledFrame>,
    /// The manifest after the run.
    pub manifest: ArtifactManifest,
    /// Stages skipped because a checkpoint recorded them as complete.
    pub skipped: Vec<String>,
}

/// Progress and cancellation context for a pipeline run.
pub struct PipelineContext<'a> {
    /// Cooperative cancellation signal.
    pub cancel: CancelToken,
    /// Progress destination.
    pub progress: &'a dyn ProgressSink,
}

impl Default for PipelineContext<'_> {
    fn default() -> Self {
        Self {
            cancel: CancelToken::new(),
            progress: &NoopProgress,
        }
    }
}

impl std::fmt::Debug for PipelineContext<'_> {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("PipelineContext")
            .field("cancelled", &self.cancel.is_cancelled())
            .finish_non_exhaustive()
    }
}

/// Run the media pipeline for one match.
///
/// `skip` holds stage labels a checkpoint already recorded as complete; those
/// stages are not re-executed. Whenever a stage is cancelled, every artifact
/// already produced is marked non-final before the error is returned, so
/// partial output can never be presented as a result.
pub fn run(
    match_dir: &MatchDirectory,
    toolchain: &MediaToolchain,
    options: &PipelineOptions,
    skip: &[String],
    context: &PipelineContext<'_>,
) -> Result<PipelineReport> {
    match_dir.create()?;

    let mut manifest = match_dir.load_or_init_manifest(&options.original)?;
    manifest.original.path = absolutize(&options.original);
    manifest.original.size_bytes = std::fs::metadata(&options.original)
        .ok()
        .map(|metadata| metadata.len());

    let mut skipped = Vec::new();
    let outcome = run_stages(
        match_dir,
        toolchain,
        options,
        skip,
        context,
        &mut manifest,
        &mut skipped,
    );

    let manifest_path = match_dir.manifest_path();
    let report = match outcome {
        Ok(report) => report,
        Err(error) => {
            if error.is_cancellation() {
                manifest.mark_all_non_final();
                manifest.save(&manifest_path)?;
            }
            return Err(error);
        }
    };

    Ok(report)
}

#[allow(clippy::too_many_arguments)]
fn run_stages(
    match_dir: &MatchDirectory,
    toolchain: &MediaToolchain,
    options: &PipelineOptions,
    skip: &[String],
    context: &PipelineContext<'_>,
    manifest: &mut ArtifactManifest,
    skipped: &mut Vec<String>,
) -> Result<PipelineReport> {
    frames::validate_sampling_rate(options.sampling_rate)?;

    context.cancel.check()?;
    context
        .progress
        .report(ProgressEvent::new(STAGE_PROBE, 0.0));
    let metadata = probe::probe(&options.original, toolchain)?;
    manifest.original.duration_seconds = Some(metadata.duration_seconds);
    context
        .progress
        .report(ProgressEvent::new(STAGE_PROBE, 1.0).with_message(format!(
            "{}x{}, {:.2}s, {:.2} fps, audio: {}",
            metadata.width,
            metadata.height,
            metadata.duration_seconds,
            metadata.frame_rate,
            if metadata.has_audio { "yes" } else { "no" }
        )));

    // --- proxy ---------------------------------------------------------------
    let proxy_path = match_dir.resolve(PROXY_RELATIVE_PATH);
    let proxy_output = if is_skipped(skip, STAGE_PROXY) {
        skipped.push(STAGE_PROXY.to_string());
        context
            .progress
            .report(ProgressEvent::new(STAGE_PROXY, 1.0).with_message("skipped: already complete"));
        proxy_path.is_file().then(|| proxy_path.clone())
    } else {
        context.cancel.check()?;
        context
            .progress
            .report(ProgressEvent::new(STAGE_PROXY, 0.0));
        let output = proxy::generate_proxy(
            &options.original,
            &proxy_path,
            toolchain,
            &options.proxy_options(),
        )?;
        manifest.record_artifact(
            ArtifactKind::Proxy,
            PROXY_RELATIVE_PATH,
            ArtifactState::Final,
            Some(output.size_bytes),
        );
        manifest.save(&match_dir.manifest_path())?;
        context.progress.report(
            ProgressEvent::new(STAGE_PROXY, 1.0)
                .with_message(format!("{}x{} proxy written", output.width, output.height)),
        );
        Some(output.path)
    };

    // --- analysis audio ------------------------------------------------------
    let audio_path = match_dir.resolve(AUDIO_RELATIVE_PATH);
    let mut audio_output = None;
    if !metadata.has_audio {
        context.progress.report(
            ProgressEvent::new(STAGE_AUDIO, 1.0)
                .with_message("no audio track in the source; continuing without analysis audio"),
        );
    } else if is_skipped(skip, STAGE_AUDIO) {
        skipped.push(STAGE_AUDIO.to_string());
        context
            .progress
            .report(ProgressEvent::new(STAGE_AUDIO, 1.0).with_message("skipped: already complete"));
        audio_output = audio_path.is_file().then(|| audio_path.clone());
    } else {
        context.cancel.check()?;
        context
            .progress
            .report(ProgressEvent::new(STAGE_AUDIO, 0.0));
        audio_output =
            audio::extract_analysis_audio(&options.original, &audio_path, toolchain, &metadata)?;
        if let Some(path) = &audio_output {
            let size = std::fs::metadata(path).ok().map(|metadata| metadata.len());
            manifest.record_artifact(
                ArtifactKind::AnalysisAudio,
                AUDIO_RELATIVE_PATH,
                ArtifactState::Final,
                size,
            );
            manifest.save(&match_dir.manifest_path())?;
        }
        context
            .progress
            .report(ProgressEvent::new(STAGE_AUDIO, 1.0));
    }

    // --- frames --------------------------------------------------------------
    let frames_dir = match_dir.resolve(FRAMES_RELATIVE_PATH);
    let sampled;
    if is_skipped(skip, STAGE_FRAMES) {
        skipped.push(STAGE_FRAMES.to_string());
        context.progress.report(
            ProgressEvent::new(STAGE_FRAMES, 1.0).with_message("skipped: already complete"),
        );
        sampled = if frames_dir.is_dir() {
            frames::sample_frames_collect_only(&frames_dir, options.sampling_rate)?
        } else {
            Vec::new()
        };
    } else {
        context.cancel.check()?;
        let sampling_input = proxy_output.clone().unwrap_or_else(|| proxy_path.clone());
        sampled = frames::sample_frames_reported(
            &sampling_input,
            &frames_dir,
            toolchain,
            &options.frame_options(),
            &metadata,
            context.progress,
            &context.cancel,
        )?;
        manifest.record_artifact(
            ArtifactKind::Frames,
            FRAMES_RELATIVE_PATH,
            ArtifactState::Final,
            directory_size(&frames_dir),
        );
        manifest.save(&match_dir.manifest_path())?;
    }

    Ok(PipelineReport {
        metadata,
        proxy: proxy_output,
        audio: audio_output,
        frames: sampled,
        manifest: manifest.clone(),
        skipped: skipped.clone(),
    })
}

/// Regenerate derived artifacts that the manifest records but that are missing
/// from disk, without re-importing the match.
///
/// Answers with both halves of the request: what was rebuilt, and what is
/// missing but cannot be rebuilt here. A court calibration is the user's own
/// marking, so a missing one is reported as such rather than counted as
/// repaired.
pub fn regenerate_missing(
    match_dir: &MatchDirectory,
    toolchain: &MediaToolchain,
    options: &PipelineOptions,
    context: &PipelineContext<'_>,
) -> Result<Regeneration> {
    let manifest_path = match_dir.manifest_path();
    if !manifest_path.is_file() {
        return Err(SportcutError::Artifact(format!(
            "{} has no manifest; import the recording first",
            match_dir.root().display()
        )));
    }

    let manifest = ArtifactManifest::load(&manifest_path)?;
    let (rebuilt, not_rebuildable): (Vec<ArtifactKind>, Vec<ArtifactKind>) = manifest
        .missing_artifacts(match_dir.root())
        .into_iter()
        .partition(|kind| REBUILDABLE_KINDS.contains(kind));

    let missing = rebuilt.clone();
    if missing.is_empty() {
        return Ok(Regeneration {
            rebuilt,
            not_rebuildable,
        });
    }

    // Regenerating frames requires a proxy, so ask for the stage that produces
    // what disappeared, plus its dependency.
    let mut skip = Vec::new();
    let proxy_path = match_dir.resolve(PROXY_RELATIVE_PATH);
    let needs_proxy = missing.contains(&ArtifactKind::Proxy)
        || (missing.contains(&ArtifactKind::Frames) && !proxy_path.is_file());
    let needs_audio = missing.contains(&ArtifactKind::AnalysisAudio);
    if !needs_proxy {
        skip.push(STAGE_PROXY.to_string());
    }
    if !needs_audio {
        skip.push(STAGE_AUDIO.to_string());
    }
    if !missing.contains(&ArtifactKind::Frames) {
        skip.push(STAGE_FRAMES.to_string());
    }

    let options = PipelineOptions {
        original: PathBuf::from(&manifest.original.path),
        ..options.clone()
    };

    run(match_dir, toolchain, &options, &skip, context)?;
    Ok(Regeneration {
        rebuilt,
        not_rebuildable,
    })
}

/// Run a single stage of the pipeline.
///
/// This is what lets the job model checkpoint and resume one stage at a time
/// instead of treating the whole pipeline as one opaque call.
pub fn run_stage(
    match_dir: &MatchDirectory,
    toolchain: &MediaToolchain,
    options: &PipelineOptions,
    stage: &str,
    context: &PipelineContext<'_>,
) -> Result<PipelineReport> {
    if !STAGES.contains(&stage) {
        return Err(SportcutError::InvalidInput(format!(
            "unknown pipeline stage {stage:?}; expected one of {}",
            STAGES.join(", ")
        )));
    }

    let skip: Vec<String> = STAGES
        .iter()
        .filter(|candidate| **candidate != stage)
        .map(|candidate| candidate.to_string())
        .collect();

    run(match_dir, toolchain, options, &skip, context)
}

fn is_skipped(skip: &[String], stage: &str) -> bool {
    skip.iter().any(|entry| entry == stage)
}

fn absolutize(path: &Path) -> String {
    std::fs::canonicalize(path)
        .or_else(|_| {
            std::env::current_dir().map(|current| {
                if path.is_absolute() {
                    path.to_path_buf()
                } else {
                    current.join(path)
                }
            })
        })
        .unwrap_or_else(|_| path.to_path_buf())
        .to_string_lossy()
        .to_string()
}

fn directory_size(path: &Path) -> Option<u64> {
    let mut total = 0u64;
    for entry in std::fs::read_dir(path).ok()?.flatten() {
        if let Ok(metadata) = entry.metadata() {
            if metadata.is_file() {
                total += metadata.len();
            }
        }
    }
    Some(total)
}
