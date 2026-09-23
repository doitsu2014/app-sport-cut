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

/// Result of an import job.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MediaImportResultDto {
    /// Metadata read from the original recording.
    pub metadata: MediaMetadataDto,
    /// The artifact manifest after the job.
    pub manifest: ArtifactManifestDto,
    /// Final job status, including the stages that ran and were skipped.
    pub job: JobStatusDto,
    /// Number of frames sampled by this run.
    pub frames_sampled: u32,
    /// Stages skipped because a checkpoint recorded them as complete.
    pub skipped_stages: Vec<String>,
}
