//! Person detection and pose estimation boundaries.
//!
//! No inference ships in the bootstrap change. This crate exists to fix the
//! boundary the later phases plug into, so the choice of on-device runtime
//! (TensorFlow Lite by default, or a platform ML kit) does not reshape the
//! pipeline.
//!
//! The design decision behind this crate is D7 in
//! `openspec/changes/bootstrap-project-base/design.md`.

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use sportcut_common::Result;

mod court_candidates;
mod frames;
mod pipeline;
mod tracking;

#[cfg(all(target_os = "macos", feature = "macos-tflite-eval"))]
mod tflite_detector;

pub use court_candidates::{
    classify_detections, CandidateDecision, ClassifiedDetection, CourtCandidateConfig,
};
pub use frames::{decode_sampled_jpeg, DecodedRgbFrame};
pub use pipeline::analyze_sampled_frames;
#[cfg(all(target_os = "macos", feature = "macos-tflite-eval"))]
pub use tflite_detector::TflitePersonDetector;
pub use tracking::{
    track_detections, CountAssessment, FrameDetections, FrameTracking, ObservedCount, PlayerGap,
    TimeSpan, TrackedDetection, TrackingConfig, TrackingResult,
};

/// A sampled frame handed to an inference backend.
///
/// The buffer is borrowed: callers keep ownership of the decoded pixels for the
/// duration of the call and nothing in this crate retains them.
#[derive(Debug)]
pub struct FrameView<'a> {
    /// Timestamp on the original recording timeline, in milliseconds.
    pub timestamp_ms: i64,
    /// Frame width in pixels.
    pub width: u32,
    /// Frame height in pixels.
    pub height: u32,
    /// Pixel data in the format the backend was configured for.
    pub pixels: &'a [u8],
}

/// Axis-aligned box in image coordinates.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct BoundingBox {
    /// Left edge, in pixels.
    pub x: f32,
    /// Top edge, in pixels.
    pub y: f32,
    /// Width, in pixels.
    pub width: f32,
    /// Height, in pixels.
    pub height: f32,
}

/// One detected person.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Detection {
    /// Box around the detected person.
    pub bbox: BoundingBox,
    /// Confidence in the range `0.0..=1.0`.
    pub confidence: f32,
}

/// A single body keypoint.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Keypoint {
    /// Horizontal position, in pixels.
    pub x: f32,
    /// Vertical position, in pixels.
    pub y: f32,
    /// Confidence in the range `0.0..=1.0`.
    pub confidence: f32,
}

/// Pose of one person in a frame.
#[derive(Debug, Clone, PartialEq)]
pub struct PersonPose {
    /// Box around the person the keypoints belong to.
    pub bbox: BoundingBox,
    /// Keypoints in the backend's fixed order.
    pub keypoints: Vec<Keypoint>,
}

/// Backend that finds people in a frame.
pub trait PersonDetector: Send + Sync {
    /// Detect people in one frame.
    fn detect(&self, frame: &FrameView<'_>) -> Result<Vec<Detection>>;
}

/// Backend that estimates pose for people in a frame.
pub trait PoseEstimator: Send + Sync {
    /// Estimate poses in one frame.
    fn estimate(&self, frame: &FrameView<'_>) -> Result<Vec<PersonPose>>;
}
