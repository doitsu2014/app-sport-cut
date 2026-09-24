//! The frozen bridge contract.
//!
//! These types are the only thing the Flutter client sees. They are
//! intentionally decoupled from the internal crates: a DTO change is a contract
//! change for the generated bindings, and an internal refactor is not.

use serde::{Deserialize, Serialize};

/// Explicit thresholds for motion-first rally analysis.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RallySegmentationConfigDto {
    /// Width of one activity bin in milliseconds.
    pub bin_ms: i64,
    /// Largest track gap from which motion can be measured.
    pub max_track_gap_ms: i64,
    /// Motion required to start a proposed rally.
    pub enter_motion_per_second: f64,
    /// Motion required to continue a proposed rally.
    pub exit_motion_per_second: f64,
    /// Audio intensity that may support weak motion.
    pub audio_intensity_threshold: f64,
    /// Minimum accepted rally duration.
    pub min_rally_ms: i64,
    /// Rest shorter than this is joined between rallies.
    pub min_rest_ms: i64,
    /// Minimum fraction of the recording with usable tracks.
    pub min_usable_coverage: f64,
}

/// Start a local rally-analysis job for a match with a completed track artifact.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RallySegmentationRequestDto {
    /// Match artifact directory.
    pub match_dir: String,
    /// Explicit, footage-tuned thresholds.
    pub config: RallySegmentationConfigDto,
}

/// One proposed rally, never an accepted or scored point by itself.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RallySuggestionDto {
    /// Stable identity within the analysis generation.
    pub id: String,
    /// Start on the original recording timeline, in seconds.
    pub start_seconds: f64,
    /// End on the original recording timeline, in seconds.
    pub end_seconds: f64,
    /// Heuristic quality from zero to one; not winner confidence.
    pub quality: f64,
    /// Whether supporting audio evidence was supplied.
    pub audio_available: bool,
}

/// One classified span of the recording.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RallyActivitySpanDto {
    /// Start on the original recording timeline, in seconds.
    pub start_seconds: f64,
    /// End on the original recording timeline, in seconds.
    pub end_seconds: f64,
    /// `rally`, `rest`, or `unknown`.
    pub kind: String,
}

/// Current completed suggestion set for a match.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RallySuggestionsDto {
    /// File format version.
    pub schema_version: u32,
    /// Segmenter version.
    pub algorithm_version: u32,
    /// Stable identity of the exact input generation.
    pub generation_id: String,
    /// Rally proposals in recording order.
    pub candidates: Vec<RallySuggestionDto>,
    /// Rally, rest, and unknown partition.
    pub timeline: Vec<RallyActivitySpanDto>,
    /// Fraction supported by usable tracks.
    pub usable_coverage: f64,
    /// Whether audio evidence was supplied.
    pub audio_available: bool,
}

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
    /// Artifact kinds recorded but missing from disk.
    pub missing_kinds: Vec<String>,
    /// Missing artifact kinds the engine cannot rebuild on its own, because they
    /// are the user's own input or need a request the caller supplies.
    pub not_rebuildable_kinds: Vec<String>,
    /// Whether the original recording is still where the manifest says it is.
    pub original_present: bool,
}

/// One court corner, in normalized displayed frame coordinates.
///
/// Measured in the frame as the user sees it, not in the source file's stored
/// pixels, so the same value is valid for the preview, the proxy, and the frames
/// sampled from the proxy.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CourtCornerDto {
    /// Horizontal position, `0.0` at the left edge.
    pub x: f64,
    /// Vertical position, `0.0` at the top edge.
    pub y: f64,
}

/// Which way the court runs relative to where the camera was standing.
///
/// The four corners are read in image order, so on their own they cannot say
/// whether the edge nearest the camera is a baseline or a sideline. This is that
/// answer, and it is what places the net.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CourtOrientationDto {
    /// The court stretches away from the camera, so the nearest edge is a
    /// baseline and the net cuts across the court's depth.
    Away,
    /// The court stretches across the view, so the nearest edge is a sideline
    /// and the net cuts across the view from side to side.
    Across,
}

/// One calibrated span of a recording.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CalibrationSegmentDto {
    /// Timestamp on the recording timeline where this segment begins, in
    /// milliseconds.
    pub from_ms: i64,
    /// The four court corners, in the order the user marked them: nearest the
    /// camera on the left, nearest on the right, farthest on the right, then
    /// farthest on the left.
    pub corners: Vec<CourtCornerDto>,
    /// Which way the court runs relative to the camera.
    pub orientation: CourtOrientationDto,
}

/// A match's court calibration.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CourtCalibrationDto {
    /// Schema version of the record.
    pub schema_version: u32,
    /// Calibrated spans, in recording order.
    pub segments: Vec<CalibrationSegmentDto>,
}

/// The geometry one calibrated segment defines.
///
/// The matrices and the outline are the engine's arithmetic, handed over so the
/// application never has to repeat it. The outline is what the application draws
/// over the recording; the matrices are what a later stage uses to place a
/// position on the court.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CourtGeometryDto {
    /// Row-major 3x3 mapping from normalized image coordinates to court
    /// coordinates, as nine values.
    pub image_to_court: Vec<f64>,
    /// Row-major 3x3 mapping from court coordinates back to normalized image
    /// coordinates, as nine values.
    pub court_to_image: Vec<f64>,
    /// The four court corners, in the order they were marked.
    pub corners: Vec<CourtCornerDto>,
    /// The two ends of the net line, in normalized image coordinates.
    pub net: Vec<CourtCornerDto>,
}

/// Request to store a match's court calibration.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CalibrationSaveRequestDto {
    /// Directory holding the match's artifacts.
    pub match_dir: String,
    /// The calibration to store, replacing any already recorded.
    pub calibration: CourtCalibrationDto,
}

/// What storing a calibration did.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CalibrationSaveDto {
    /// Whether the stored calibration differs from the one it replaced.
    pub changed: bool,
    /// Artifact kinds invalidated because they were derived from the previous
    /// calibration rather than the new one.
    pub invalidated_kinds: Vec<String>,
    /// The geometry of each stored segment, in the same order.
    pub geometry: Vec<CourtGeometryDto>,
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
