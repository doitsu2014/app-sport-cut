//! Court-aware interpretation of person boxes, independent of the inference backend.

use serde::{Deserialize, Serialize};
use sportcut_common::{Result, SportcutError};
use sportcut_court::{CalibrationSegment, CourtPoint, CourtSide, ImagePoint};

use crate::{BoundingBox, Detection};

/// Thresholds for deciding whether a detected person can be tracked as a court player.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CourtCandidateConfig {
    /// Minimum detector confidence accepted for tracking.
    pub min_confidence: f32,
    /// Distance beyond the court edge, in court units, reported as borderline.
    pub court_margin: f64,
    /// Distance from the net, in court units, where the side stays unknown.
    pub net_margin: f64,
}

impl CourtCandidateConfig {
    /// Reject unusable thresholds before processing a frame.
    pub fn validate(self) -> Result<()> {
        if !self.min_confidence.is_finite() || !(0.0..=1.0).contains(&self.min_confidence) {
            return Err(invalid(
                "minimum detection confidence must be between zero and one",
            ));
        }
        if !self.court_margin.is_finite() || !(0.0..=0.5).contains(&self.court_margin) {
            return Err(invalid("court margin must be between zero and one half"));
        }
        if !self.net_margin.is_finite() || !(0.0..0.5).contains(&self.net_margin) {
            return Err(invalid("net margin must be between zero and one half"));
        }
        Ok(())
    }
}

/// Why a person box was or was not selected as a court player.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CandidateDecision {
    /// A reliable ground point projects inside the court.
    OnCourt,
    /// The detector score is below the configured threshold.
    LowConfidence,
    /// The detector returned a box that cannot locate a person in this frame.
    InvalidBox,
    /// No user calibration covers this frame.
    MissingCalibration,
    /// The image-to-court projection is undefined at the ground point.
    ProjectionFailed,
    /// The ground point is just outside the marked court.
    Borderline,
    /// The ground point is outside the marked court and its uncertainty margin.
    OffCourt,
}

/// A detector result with the evidence used for court-player selection.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ClassifiedDetection {
    /// Raw box and detector score, retained even when rejected.
    pub detection: Detection,
    /// Estimated contact point in normalized displayed-frame coordinates.
    pub ground_point: Option<ImagePoint>,
    /// Projected court point, when projection was defined.
    pub court_point: Option<CourtPoint>,
    /// Side of the net when the court point is reliable and clear of the net.
    pub side: Option<CourtSide>,
    /// Selection decision and rejection reason.
    pub decision: CandidateDecision,
}

/// Classify all detected people in one upright sampled frame.
///
/// The bottom center of each box is only an approximation of foot contact.
/// Borderline and off-court boxes stay in the result for reviewer inspection
/// but never become track candidates.
pub fn classify_detections(
    frame_width: u32,
    frame_height: u32,
    detections: Vec<Detection>,
    calibration: Option<&CalibrationSegment>,
    config: CourtCandidateConfig,
) -> Result<Vec<ClassifiedDetection>> {
    config.validate()?;
    if frame_width == 0 || frame_height == 0 {
        return Err(invalid("sampled frame dimensions must be positive"));
    }
    let mapping = calibration.map(CalibrationSegment::mapping).transpose()?;
    let mut classified = Vec::with_capacity(detections.len());
    for detection in detections {
        let mut item = ClassifiedDetection {
            detection,
            ground_point: None,
            court_point: None,
            side: None,
            decision: CandidateDecision::InvalidBox,
        };
        let bbox = item.detection.bbox;
        if !valid_box(bbox, frame_width, frame_height) {
            classified.push(item);
            continue;
        }
        let ground = ImagePoint::new(
            ((f64::from(bbox.x) + f64::from(bbox.width) / 2.0) / f64::from(frame_width))
                .clamp(0.0, 1.0),
            ((f64::from(bbox.y) + f64::from(bbox.height)) / f64::from(frame_height))
                .clamp(0.0, 1.0),
        );
        item.ground_point = Some(ground);
        if !item.detection.confidence.is_finite()
            || item.detection.confidence < config.min_confidence
            || item.detection.confidence > 1.0
        {
            item.decision = CandidateDecision::LowConfidence;
            classified.push(item);
            continue;
        }
        let Some(mapping) = mapping else {
            item.decision = CandidateDecision::MissingCalibration;
            classified.push(item);
            continue;
        };
        let Some(court_point) = mapping.to_court(ground) else {
            item.decision = CandidateDecision::ProjectionFailed;
            classified.push(item);
            continue;
        };
        item.court_point = Some(court_point);
        if !unit(court_point.u) || !unit(court_point.v) {
            item.decision = if in_margin(court_point, config.court_margin) {
                CandidateDecision::Borderline
            } else {
                CandidateDecision::OffCourt
            };
            classified.push(item);
            continue;
        }
        item.decision = CandidateDecision::OnCourt;
        if let Some(segment) = calibration {
            let axis = match segment.orientation {
                sportcut_court::CourtOrientation::Away => court_point.v,
                sportcut_court::CourtOrientation::Across => court_point.u,
            };
            if (axis - 0.5).abs() > config.net_margin {
                item.side = Some(segment.side_of(court_point));
            }
        }
        classified.push(item);
    }
    Ok(classified)
}

fn valid_box(bbox: BoundingBox, frame_width: u32, frame_height: u32) -> bool {
    bbox.x.is_finite()
        && bbox.y.is_finite()
        && bbox.width.is_finite()
        && bbox.height.is_finite()
        && bbox.width > 0.0
        && bbox.height > 0.0
        && bbox.x < frame_width as f32
        && bbox.y < frame_height as f32
        && f64::from(bbox.x) + f64::from(bbox.width) > 0.0
        && f64::from(bbox.y) + f64::from(bbox.height) > 0.0
}

fn unit(value: f64) -> bool {
    (0.0..=1.0).contains(&value)
}

fn in_margin(point: CourtPoint, margin: f64) -> bool {
    (-margin..=1.0 + margin).contains(&point.u) && (-margin..=1.0 + margin).contains(&point.v)
}

fn invalid(message: &str) -> SportcutError {
    SportcutError::InvalidInput(format!("person detection: {message}"))
}
