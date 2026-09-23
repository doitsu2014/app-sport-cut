//! The media foundation: probe, proxy, analysis audio, and frame sampling.
//!
//! Every stage works on local files only. The crate shells out to an
//! `ffmpeg`/`ffprobe` pair discovered by [`MediaToolchain`]; nothing here opens
//! a network connection, and the pipeline is verified with network access
//! unavailable (see `tests/offline.rs`).
//!
//! Encoding note: the development toolchain on this machine is a GPL build, so
//! it is a developer tool and not a shipping path. See
//! `docs/legal/dependency-register.md`.

mod audio;
pub mod exec;
mod frames;
mod pipeline;
mod probe;
mod proxy;
mod toolchain;

pub use audio::{extract_analysis_audio, ANALYSIS_AUDIO_BITRATE, ANALYSIS_AUDIO_SAMPLE_RATE};
pub use frames::{
    expected_frame_count, sample_frames, sample_frames_collect_only, sample_frames_reported,
    validate_sampling_rate, FrameSamplingOptions, SampledFrame, MAX_SAMPLING_RATE,
};
pub use pipeline::{
    regenerate_missing, run, run_stage, PipelineContext, PipelineOptions, PipelineReport,
    AUDIO_RELATIVE_PATH, FRAMES_RELATIVE_PATH, PROXY_RELATIVE_PATH, STAGES, STAGE_AUDIO,
    STAGE_FRAMES, STAGE_PROBE, STAGE_PROXY,
};
pub use probe::{probe, MediaMetadata, Orientation};
pub use proxy::{generate_proxy, ProxyOptions, ProxyOutput, DEFAULT_PROXY_MAX_HEIGHT};
pub use toolchain::{MediaToolchain, FFMPEG_ENV, FFPROBE_ENV};
