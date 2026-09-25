//! Frame sampling for analysis.

use std::ffi::OsString;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use sportcut_common::{
    CancelToken, NoopProgress, ProgressEvent, ProgressSink, Result, SportcutError,
};

use crate::exec;
use crate::probe::MediaMetadata;
use crate::toolchain::MediaToolchain;

/// Highest sampling rate the pipeline accepts, in frames per second.
///
/// The bound exists so a caller cannot ask for "every frame" of a long
/// recording and turn a bounded analysis stream into an unbounded disk fill.
pub const MAX_SAMPLING_RATE: f64 = 30.0;

/// Frame file name pattern passed to the media toolchain.
const FRAME_PATTERN: &str = "frame_%06d.jpg";

/// Frame file name prefix used when collecting the results.
const FRAME_PREFIX: &str = "frame_";

/// Frame file name suffix used when collecting the results.
const FRAME_SUFFIX: &str = ".jpg";

/// Options for frame sampling.
#[derive(Debug, Clone, PartialEq)]
pub struct FrameSamplingOptions {
    /// Sampling rate in frames per second.
    pub rate: f64,
}

impl Default for FrameSamplingOptions {
    fn default() -> Self {
        Self { rate: 1.0 }
    }
}

/// One sampled frame, mapped back to the original recording timeline.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SampledFrame {
    /// Zero-based index in the sampled stream.
    pub index: u32,
    /// Timestamp on the original recording timeline, in milliseconds.
    pub timestamp_ms: i64,
    /// Path of the written frame file.
    pub path: PathBuf,
}

/// Validate a requested sampling rate.
pub fn validate_sampling_rate(rate: f64) -> Result<()> {
    if !rate.is_finite() || rate <= 0.0 {
        return Err(SportcutError::InvalidInput(format!(
            "sampling rate must be a positive number, got {rate}"
        )));
    }
    if rate > MAX_SAMPLING_RATE {
        return Err(SportcutError::unsupported(
            "sampling rate",
            format!(
                "{rate} frames per second exceeds the supported maximum of {MAX_SAMPLING_RATE}"
            ),
        ));
    }
    Ok(())
}

/// Sample frames at the requested rate into `output_dir`.
///
/// The timestamps are computed for the source timeline, so a proxy generated
/// from the original keeps the same time base and a frame index maps directly
/// back to the recording.
pub fn sample_frames(
    input: &Path,
    output_dir: &Path,
    toolchain: &MediaToolchain,
    options: &FrameSamplingOptions,
    metadata: &MediaMetadata,
) -> Result<Vec<SampledFrame>> {
    sample_frames_reported(
        input,
        output_dir,
        toolchain,
        options,
        metadata,
        &NoopProgress,
        &CancelToken::new(),
    )
}

/// Sample frames, reporting progress and honouring cancellation.
pub fn sample_frames_reported(
    input: &Path,
    output_dir: &Path,
    toolchain: &MediaToolchain,
    options: &FrameSamplingOptions,
    metadata: &MediaMetadata,
    progress: &dyn ProgressSink,
    cancel: &CancelToken,
) -> Result<Vec<SampledFrame>> {
    validate_sampling_rate(options.rate)?;

    if !input.is_file() {
        return Err(SportcutError::Probe {
            path: input.display().to_string(),
            reason: "file not found".to_string(),
        });
    }

    std::fs::create_dir_all(output_dir).map_err(|e| SportcutError::io(output_dir, e))?;
    cancel.check()?;

    // A rerun at a lower rate may produce fewer numbered frames. Remove only
    // the previous sampler outputs so stale high-numbered JPEGs cannot enter
    // the new track generation.
    for entry in std::fs::read_dir(output_dir).map_err(|e| SportcutError::io(output_dir, e))? {
        let entry = entry.map_err(|e| SportcutError::io(output_dir, e))?;
        let path = entry.path();
        let is_sample = path
            .file_name()
            .map(|name| {
                let name = name.to_string_lossy();
                name.starts_with(FRAME_PREFIX) && name.ends_with(FRAME_SUFFIX)
            })
            .unwrap_or(false);
        if is_sample && path.is_file() {
            std::fs::remove_file(&path).map_err(|e| SportcutError::io(&path, e))?;
        }
    }
    cancel.check()?;

    let expected = expected_frame_count(metadata, options.rate);
    progress.report(ProgressEvent::new("frames", 0.0).with_message(format!(
        "sampling at {:.3} fps, about {expected} frames",
        options.rate
    )));

    let pattern = output_dir.join(FRAME_PATTERN);
    let args: Vec<OsString> = vec![
        "-hide_banner".into(),
        "-nostdin".into(),
        "-y".into(),
        "-i".into(),
        input.into(),
        "-vf".into(),
        format!("fps={}", options.rate).into(),
        "-q:v".into(),
        "4".into(),
        "-f".into(),
        "image2".into(),
        pattern.into(),
    ];

    exec::run(toolchain.ffmpeg(), "ffmpeg", &args, input)?.into_success("ffmpeg", input)?;
    cancel.check()?;

    let frames = collect_frames(output_dir, options.rate)?;
    progress.report(
        ProgressEvent::new("frames", 1.0).with_message(format!("{} frames sampled", frames.len())),
    );

    Ok(frames)
}

/// Collect frames already present in a directory without running the toolchain.
///
/// Used when a checkpoint says frame sampling is complete: the artifacts are
/// re-described from disk instead of re-rendered.
pub fn sample_frames_collect_only(output_dir: &Path, rate: f64) -> Result<Vec<SampledFrame>> {
    validate_sampling_rate(rate)?;
    collect_frames(output_dir, rate)
}

/// How many frames a sampling run is expected to produce.
pub fn expected_frame_count(metadata: &MediaMetadata, rate: f64) -> u32 {
    if rate <= 0.0 || !rate.is_finite() {
        return 0;
    }
    (metadata.duration_seconds * rate).floor().max(0.0) as u32
}

fn collect_frames(output_dir: &Path, rate: f64) -> Result<Vec<SampledFrame>> {
    let mut paths: Vec<PathBuf> = std::fs::read_dir(output_dir)
        .map_err(|e| SportcutError::io(output_dir, e))?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| {
            path.file_name()
                .map(|name| {
                    let name = name.to_string_lossy();
                    name.starts_with(FRAME_PREFIX) && name.ends_with(FRAME_SUFFIX)
                })
                .unwrap_or(false)
        })
        .collect();

    paths.sort();

    Ok(paths
        .into_iter()
        .enumerate()
        .map(|(index, path)| SampledFrame {
            index: index as u32,
            timestamp_ms: timestamp_ms_for(index as u32, rate),
            path,
        })
        .collect())
}

/// Timestamp of the `index`-th sampled frame on the source timeline.
fn timestamp_ms_for(index: u32, rate: f64) -> i64 {
    ((index as f64) * 1000.0 / rate).round() as i64
}
