//! The frozen bridge contract.
//!
//! These types are the only thing the Flutter client sees. They are
//! intentionally decoupled from the internal crates: a DTO change is a contract
//! change for the generated bindings, and an internal refactor is not.

use serde::{Deserialize, Serialize};

/// Lifecycle state of a job, mirrored for the client.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum JobStateDto {
    /// Accepted but not started.
    Pending,
    /// Currently executing a stage.
    Running,
    /// Finished successfully.
    Completed,
    /// Stopped by an explicit cancel request.
    Cancelled,
    /// Stopped because a stage failed.
    Failed,
}

/// How the camera was rotated relative to the stored pixels.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OrientationDto {
    /// No rotation metadata; pixels are upright.
    Landscape,
    /// Rotated 90 degrees clockwise on playback.
    Portrait,
    /// Rotated 180 degrees.
    UpsideDown,
    /// Rotated 270 degrees clockwise (90 counter-clockwise).
    PortraitReversed,
    /// Rotation metadata was present but not a right angle.
    Unknown,
}

/// Media metadata the client shows and stores in its catalog.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MediaMetadataDto {
    /// Path of the original recording, referenced in place.
    pub path: String,
    /// Duration in seconds.
    pub duration_seconds: f64,
    /// Frame rate in frames per second.
    pub frame_rate: f64,
    /// Stored frame width in pixels, before rotation.
    pub width: u32,
    /// Stored frame height in pixels, before rotation.
    pub height: u32,
    /// Rotation implied by the container metadata.
    pub rotation_degrees: i32,
    /// Display orientation derived from the rotation.
    pub orientation: OrientationDto,
    /// Whether the source contains an audio track.
    pub has_audio: bool,
    /// Size of the original file in bytes.
    pub size_bytes: u64,
}

/// Progress within a stage.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JobProgressDto {
    /// Stage label, for example `proxy`.
    pub stage: String,
    /// Progress within the stage, in the range `0.0..=1.0`.
    pub value: f64,
    /// Optional human-readable detail.
    pub message: Option<String>,
}

/// Current state of a job.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JobStatusDto {
    /// Stable job identifier.
    pub job_id: String,
    /// Match the job belongs to.
    pub match_id: String,
    /// Lifecycle state.
    pub state: JobStateDto,
    /// Stage currently executing, or the last stage reached.
    pub stage: Option<String>,
    /// Latest progress within `stage`.
    pub progress: Option<JobProgressDto>,
    /// Human-readable failure reason when `state` is `failed`.
    pub error: Option<String>,
    /// Stages that have been checkpointed as complete.
    pub completed_stages: Vec<String>,
}

/// Handle for a job the client started and can now follow.
///
/// Returned as soon as the job is admitted, before any work has run. The
/// identifier is the value [`crate::job_status`] and [`crate::job_cancel`] take.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JobHandleDto {
    /// Stable job identifier.
    pub job_id: String,
    /// Match the job works on.
    pub match_id: String,
}

/// Whether a recorded artifact is a result or partial output.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ArtifactStateDto {
    /// Produced by a completed stage.
    Final,
    /// Produced by a stage that was cancelled or interrupted.
    NonFinal,
    /// Recorded but the file is gone.
    Missing,
}

/// One derived artifact in the match directory.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArtifactDto {
    /// Artifact kind, for example `proxy` or `analysis_audio`.
    pub kind: String,
    /// Path relative to the match directory.
    pub relative_path: String,
    /// Whether the artifact is final, partial, or missing.
    pub state: ArtifactStateDto,
    /// Size in bytes, when known.
    pub size_bytes: Option<u64>,
}

/// The artifact manifest as the client sees it.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArtifactManifestDto {
    /// Match identifier.
    pub match_id: String,
    /// Path of the original recording, referenced in place.
    pub original_path: String,
    /// Artifacts recorded for this match.
    pub artifacts: Vec<ArtifactDto>,
    /// Artifact kinds recorded but missing from disk; these can be regenerated.
    pub missing_kinds: Vec<String>,
    /// Whether the original recording is still where the manifest says it is.
    pub original_present: bool,
}

/// Request to import a recording into a match directory.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MediaImportRequestDto {
    /// Match identifier; also the match directory name.
    pub match_id: String,
    /// Original recording. Referenced in place, never copied or modified.
    pub original_path: String,
    /// Directory that holds this match's derived artifacts.
    pub match_dir: String,
    /// Frame sampling rate, in frames per second.
    pub sampling_rate: f64,
}

/// One clip in an export request.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EditClipDto {
    /// Start of the clip in the source recording, in seconds.
    pub start_seconds: f64,
    /// End of the clip in the source recording, in seconds.
    pub end_seconds: f64,
    /// Image the application rendered of the score at this clip, composited
    /// over it for its whole duration.
    pub overlay_path: Option<String>,
}

/// The card shown before the first clip.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EditTitleDto {
    /// Image the application rendered for the title card.
    pub image_path: String,
    /// How long the card is shown, in seconds.
    pub seconds: f64,
}

/// Everything needed to render one highlight video.
///
/// The engine renders from this list and never reads the application's catalog.
/// Scores and titles arrive as images the application drew, because burning text
/// needs a font-capable media toolchain and compositing an image does not.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ExportRequestDto {
    /// Match the export belongs to.
    pub match_id: String,
    /// Directory holding this match's artifacts; the reel is written inside it.
    pub match_dir: String,
    /// Recording to read. Referenced in place, never modified.
    pub source_path: String,
    /// Clips, in the order they must appear in the reel.
    pub clips: Vec<EditClipDto>,
    /// Material added before each clip, in seconds.
    pub lead_in_seconds: f64,
    /// Material added after each clip, in seconds.
    pub lead_out_seconds: f64,
    /// Title card, when the user asked for one.
    pub title: Option<EditTitleDto>,
    /// Music mixed under the match audio.
    pub music_path: Option<String>,
    /// Music volume relative to the match audio, in the range `0.0..=1.0`.
    pub music_gain: f64,
}
