//! Local sampled-frame detection followed by court-aware tracking.

use sportcut_common::{CancelToken, ProgressEvent, ProgressSink, Result, SportcutError};
use sportcut_court::CalibrationSegment;
use sportcut_media::SampledFrame;

use crate::{
    decode_sampled_jpeg, track_detections, FrameDetections, PersonDetector, TrackingConfig,
    TrackingResult,
};

/// Run the backend over local sampled JPEGs and derive reviewable player tracks.
///
/// The detector is injected so runtime packaging stays separate from frame,
/// court, and tracking behavior. An error or cancellation returns no result for
/// publication as a final artifact.
pub fn analyze_sampled_frames(
    samples: &[SampledFrame],
    detector: &dyn PersonDetector,
    calibrations: &[CalibrationSegment],
    duration_ms: i64,
    config: TrackingConfig,
    progress: &dyn ProgressSink,
    cancel: &CancelToken,
) -> Result<TrackingResult> {
    if samples.is_empty() {
        return Err(SportcutError::InvalidInput(
            "person detection: no sampled frames are available; run frame sampling first"
                .to_string(),
        ));
    }
    config.validate()?;
    let mut frames = Vec::with_capacity(samples.len());
    progress.report(ProgressEvent::new("person_detection", 0.0));
    for (index, sample) in samples.iter().enumerate() {
        cancel.check()?;
        let decoded = decode_sampled_jpeg(&sample.path, sample.timestamp_ms)?;
        let detections = detector.detect(&decoded.view())?;
        frames.push(FrameDetections {
            timestamp_ms: decoded.timestamp_ms,
            width: decoded.width,
            height: decoded.height,
            detections,
        });
        progress.report(ProgressEvent::new(
            "person_detection",
            (index + 1) as f64 / samples.len() as f64,
        ));
    }
    cancel.check()?;
    progress.report(ProgressEvent::new("player_tracking", 0.0));
    let result = track_detections(&frames, calibrations, duration_ms, config)?;
    cancel.check()?;
    progress.report(ProgressEvent::new("player_tracking", 1.0));
    Ok(result)
}
