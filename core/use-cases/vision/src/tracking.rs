//! Deterministic player association over sampled person detections.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use sportcut_common::{Result, SportcutError};
use sportcut_court::{CalibrationSegment, CourtSide, ImagePoint};

use crate::{
    classify_detections, BoundingBox, CandidateDecision, ClassifiedDetection, CourtCandidateConfig,
    Detection,
};

/// Person detections from one upright frame on the source timeline.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FrameDetections {
    /// Timestamp on the original recording timeline.
    pub timestamp_ms: i64,
    /// Decoded frame width.
    pub width: u32,
    /// Decoded frame height.
    pub height: u32,
    /// All person boxes, including possible spectators.
    pub detections: Vec<Detection>,
}

/// Half-open interval on the original recording timeline.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct TimeSpan {
    /// Inclusive start time.
    pub start_ms: i64,
    /// Exclusive end time.
    pub end_ms: i64,
}

/// A gap for one player whose observations could not be joined continuously.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlayerGap {
    /// Identity within this analysis generation.
    pub track_id: u64,
    /// Interval without a reliable observation.
    pub time: TimeSpan,
}

/// Thresholds for a first pass at track association and count assessment.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TrackingConfig {
    /// Court-player selection and net uncertainty thresholds.
    pub court: CourtCandidateConfig,
    /// Longest gap over which an old track ID can be reused.
    pub max_track_gap_ms: i64,
    /// Longest interval between sampled frames counted as continuous coverage.
    pub max_frame_gap_ms: i64,
    /// Maximum normalized image-plane ground-point travel per second.
    pub max_ground_speed_per_second: f64,
    /// Cost difference below which association remains ambiguous.
    pub ambiguity_margin: f64,
    /// Minimum observations before a track supports a player-count assessment.
    pub min_track_observations: usize,
    /// Minimum adequately observed frames supporting a count.
    pub min_count_frames: usize,
    /// Fraction of all sampled frames that must support the winning count.
    pub min_count_fraction: f64,
}

impl TrackingConfig {
    /// Validate configuration before processing any detections.
    pub fn validate(self) -> Result<()> {
        self.court.validate()?;
        if self.max_track_gap_ms <= 0 || self.max_frame_gap_ms <= 0 {
            return Err(invalid("track and frame gaps must be positive"));
        }
        if !self.max_ground_speed_per_second.is_finite() || self.max_ground_speed_per_second <= 0.0
        {
            return Err(invalid("maximum ground speed must be finite and positive"));
        }
        if !self.ambiguity_margin.is_finite() || !(0.0..=1.0).contains(&self.ambiguity_margin) {
            return Err(invalid(
                "association ambiguity margin must be between zero and one",
            ));
        }
        if self.min_track_observations < 2 || self.min_count_frames < 2 {
            return Err(invalid(
                "count observation minimums must be at least two frames",
            ));
        }
        if !self.min_count_fraction.is_finite() || !(0.0..=1.0).contains(&self.min_count_fraction) {
            return Err(invalid(
                "count agreement fraction must be between zero and one",
            ));
        }
        Ok(())
    }
}

/// A classified box with a possible generation-local track ID.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrackedDetection {
    /// Original person box and court-selection evidence.
    pub candidate: ClassifiedDetection,
    /// Stable ID only when association was reliable.
    pub track_id: Option<u64>,
    /// Whether multiple existing tracks could plausibly match this box.
    pub association_ambiguous: bool,
}

/// All detected people in one sampled frame.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FrameTracking {
    /// Timestamp on the original recording timeline.
    pub timestamp_ms: i64,
    /// Width of the upright sampled frame.
    pub width: u32,
    /// Height of the upright sampled frame.
    pub height: u32,
    /// Raw and selected observations.
    pub people: Vec<TrackedDetection>,
}

/// Count supported by sustained, stable on-court observations.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ObservedCount {
    /// One stable observed player on each side.
    Two,
    /// Two stable observed players on each side.
    Four,
    /// Visibility or association does not support either count.
    Unknown,
}

/// Recording-level count assessment, including the supporting interval.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CountAssessment {
    /// Two, four, or unknown.
    pub count: ObservedCount,
    /// Interval of sampled evidence.
    pub evidence: TimeSpan,
    /// Fraction of sampled frames supporting the reported count.
    pub quality: f64,
    /// Number of sampled frames with the reported per-side layout.
    pub supporting_frames: usize,
}

/// Reviewable result of one track generation.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrackingResult {
    /// Per-frame boxes, decisions, sides, and IDs.
    pub frames: Vec<FrameTracking>,
    /// Intervals where calibrated sampled frames attempted to observe the court.
    pub coverage: Vec<TimeSpan>,
    /// Intervals with a reliable observed player on both sides.
    pub usable_coverage: Vec<TimeSpan>,
    /// Explicit gaps in individual player tracks.
    pub gaps: Vec<PlayerGap>,
    /// Sustained player-count assessment.
    pub count: CountAssessment,
}

#[derive(Debug, Clone, Copy)]
struct ActiveTrack {
    id: u64,
    last_ms: i64,
    ground: ImagePoint,
    bbox: BoundingBox,
    side: Option<CourtSide>,
    missing_since: Option<i64>,
}

#[derive(Debug, Clone, Copy)]
struct PossibleMatch {
    cost: f64,
    track: usize,
    person: usize,
}

/// Link court-player detections across sampled frames without inventing positions.
///
/// The caller supplies detector outputs, so this deterministic stage can be
/// built and inspected independently of the selected inference runtime.
pub fn track_detections(
    frames: &[FrameDetections],
    calibrations: &[CalibrationSegment],
    duration_ms: i64,
    config: TrackingConfig,
) -> Result<TrackingResult> {
    config.validate()?;
    validate_inputs(frames, calibrations, duration_ms)?;
    let mut active = Vec::<ActiveTrack>::new();
    let mut next_id = 1_u64;
    let mut result_frames = Vec::with_capacity(frames.len());
    let mut gaps = Vec::new();
    let mut previous_calibration_start = None;
    for frame in frames {
        let calibration = calibration_at(calibrations, frame.timestamp_ms);
        let calibration_start = calibration.map(|segment| segment.from_ms);
        if calibration_start != previous_calibration_start {
            active.clear();
            previous_calibration_start = calibration_start;
        }
        let people = classify_detections(
            frame.width,
            frame.height,
            frame.detections.clone(),
            calibration,
            config.court,
        )?;
        for track in &active {
            if frame.timestamp_ms - track.last_ms > config.max_track_gap_ms {
                gaps.push(PlayerGap {
                    track_id: track.id,
                    time: TimeSpan {
                        start_ms: track.missing_since.unwrap_or(track.last_ms),
                        end_ms: frame.timestamp_ms,
                    },
                });
            }
        }
        active.retain(|track| frame.timestamp_ms - track.last_ms <= config.max_track_gap_ms);
        let mut observed: Vec<TrackedDetection> = people
            .into_iter()
            .map(|candidate| TrackedDetection {
                candidate,
                track_id: None,
                association_ambiguous: false,
            })
            .collect();
        let mut matches = Vec::<PossibleMatch>::new();
        for (person_index, person) in observed.iter_mut().enumerate() {
            if person.candidate.decision != CandidateDecision::OnCourt {
                continue;
            }
            let mut options = Vec::new();
            for (track_index, track) in active.iter().enumerate() {
                if let Some(cost) = association_cost(
                    track,
                    &person.candidate,
                    frame.timestamp_ms,
                    config.max_ground_speed_per_second,
                ) {
                    options.push(PossibleMatch {
                        cost,
                        track: track_index,
                        person: person_index,
                    });
                }
            }
            options.sort_by(|a, b| a.cost.total_cmp(&b.cost));
            if options.len() > 1 && options[1].cost - options[0].cost <= config.ambiguity_margin {
                person.association_ambiguous = true;
            } else {
                matches.extend(options);
            }
        }
        matches.sort_by(|a, b| a.cost.total_cmp(&b.cost));
        let mut used_tracks = vec![false; active.len()];
        for possible in matches {
            if used_tracks[possible.track]
                || observed[possible.person].track_id.is_some()
                || observed[possible.person].association_ambiguous
            {
                continue;
            }
            let track = &mut active[possible.track];
            let candidate = &observed[possible.person].candidate;
            if let Some(start_ms) = track.missing_since {
                gaps.push(PlayerGap {
                    track_id: track.id,
                    time: TimeSpan {
                        start_ms,
                        end_ms: frame.timestamp_ms,
                    },
                });
            }
            track.last_ms = frame.timestamp_ms;
            track.ground = candidate
                .ground_point
                .expect("on-court box has a ground point");
            track.bbox = candidate.detection.bbox;
            track.side = candidate.side;
            track.missing_since = None;
            observed[possible.person].track_id = Some(track.id);
            used_tracks[possible.track] = true;
        }
        for (index, track) in active.iter_mut().enumerate() {
            if !used_tracks[index] && track.missing_since.is_none() {
                track.missing_since = Some(track.last_ms);
            }
        }
        for person in &mut observed {
            if person.candidate.decision != CandidateDecision::OnCourt
                || person.track_id.is_some()
                || person.association_ambiguous
            {
                continue;
            }
            let ground = person
                .candidate
                .ground_point
                .expect("on-court box has a ground point");
            let id = next_id;
            next_id = next_id.saturating_add(1);
            active.push(ActiveTrack {
                id,
                last_ms: frame.timestamp_ms,
                ground,
                bbox: person.candidate.detection.bbox,
                side: person.candidate.side,
                missing_since: None,
            });
            person.track_id = Some(id);
        }
        result_frames.push(FrameTracking {
            timestamp_ms: frame.timestamp_ms,
            width: frame.width,
            height: frame.height,
            people: observed,
        });
    }
    let (coverage, usable_coverage) = coverage_intervals(&result_frames, calibrations, config);
    let count = assess_count(&result_frames, duration_ms, config);
    Ok(TrackingResult {
        frames: result_frames,
        coverage,
        usable_coverage,
        gaps,
        count,
    })
}

fn validate_inputs(
    frames: &[FrameDetections],
    calibrations: &[CalibrationSegment],
    duration_ms: i64,
) -> Result<()> {
    if duration_ms <= 0 {
        return Err(invalid("recording duration must be positive"));
    }
    let mut previous = -1;
    for frame in frames {
        if frame.timestamp_ms <= previous || frame.timestamp_ms >= duration_ms {
            return Err(invalid(
                "sampled frame timestamps must increase within the recording",
            ));
        }
        if frame.width == 0 || frame.height == 0 {
            return Err(invalid("sampled frame dimensions must be positive"));
        }
        previous = frame.timestamp_ms;
    }
    previous = -1;
    for calibration in calibrations {
        if calibration.from_ms <= previous || calibration.from_ms >= duration_ms {
            return Err(invalid(
                "calibration segments must increase within the recording",
            ));
        }
        calibration.validate()?;
        previous = calibration.from_ms;
    }
    Ok(())
}

fn calibration_at(
    calibrations: &[CalibrationSegment],
    timestamp_ms: i64,
) -> Option<&CalibrationSegment> {
    let count = calibrations.partition_point(|segment| segment.from_ms <= timestamp_ms);
    count
        .checked_sub(1)
        .and_then(|index| calibrations.get(index))
}

fn association_cost(
    track: &ActiveTrack,
    person: &ClassifiedDetection,
    timestamp_ms: i64,
    max_ground_speed_per_second: f64,
) -> Option<f64> {
    let elapsed_ms = timestamp_ms - track.last_ms;
    if elapsed_ms <= 0 {
        return None;
    }
    let ground = person.ground_point?;
    let distance =
        ((ground.x - track.ground.x).powi(2) + (ground.y - track.ground.y).powi(2)).sqrt();
    let allowed = max_ground_speed_per_second * elapsed_ms as f64 / 1000.0;
    if distance > allowed {
        return None;
    }
    let side_penalty = match (track.side, person.side) {
        (Some(a), Some(b)) if a != b => 0.4,
        _ => 0.0,
    };
    let overlap_penalty = 0.2 * (1.0 - iou(track.bbox, person.detection.bbox));
    Some(distance / allowed + side_penalty + overlap_penalty)
}

fn iou(a: BoundingBox, b: BoundingBox) -> f64 {
    let left = f64::from(a.x.max(b.x));
    let top = f64::from(a.y.max(b.y));
    let right = (f64::from(a.x) + f64::from(a.width)).min(f64::from(b.x) + f64::from(b.width));
    let bottom = (f64::from(a.y) + f64::from(a.height)).min(f64::from(b.y) + f64::from(b.height));
    let intersection = (right - left).max(0.0) * (bottom - top).max(0.0);
    let union = f64::from(a.width) * f64::from(a.height) + f64::from(b.width) * f64::from(b.height)
        - intersection;
    if union > 0.0 {
        intersection / union
    } else {
        0.0
    }
}

fn coverage_intervals(
    frames: &[FrameTracking],
    calibrations: &[CalibrationSegment],
    config: TrackingConfig,
) -> (Vec<TimeSpan>, Vec<TimeSpan>) {
    let mut attempted = Vec::new();
    let mut usable = Vec::new();
    for pair in frames.windows(2) {
        let [first, second] = pair else { continue };
        let first_calibration = calibration_at(calibrations, first.timestamp_ms);
        let second_calibration = calibration_at(calibrations, second.timestamp_ms);
        if second.timestamp_ms - first.timestamp_ms > config.max_frame_gap_ms
            || first_calibration.is_none()
            || first_calibration.map(|segment| segment.from_ms)
                != second_calibration.map(|segment| segment.from_ms)
        {
            continue;
        }
        let interval = TimeSpan {
            start_ms: first.timestamp_ms,
            end_ms: second.timestamp_ms,
        };
        append_span(&mut attempted, interval);
        if has_both_sides(first) && has_both_sides(second) {
            append_span(&mut usable, interval);
        }
    }
    (attempted, usable)
}

fn has_both_sides(frame: &FrameTracking) -> bool {
    let mut first = false;
    let mut second = false;
    for person in &frame.people {
        if person.track_id.is_none() {
            continue;
        }
        match person.candidate.side {
            Some(CourtSide::First) => first = true,
            Some(CourtSide::Second) => second = true,
            None => {}
        }
    }
    first && second
}

fn append_span(spans: &mut Vec<TimeSpan>, next: TimeSpan) {
    if let Some(last) = spans.last_mut() {
        if last.end_ms == next.start_ms {
            last.end_ms = next.end_ms;
            return;
        }
    }
    spans.push(next);
}

fn assess_count(
    frames: &[FrameTracking],
    duration_ms: i64,
    config: TrackingConfig,
) -> CountAssessment {
    let evidence = TimeSpan {
        start_ms: frames.first().map_or(0, |frame| frame.timestamp_ms),
        end_ms: frames
            .last()
            .map_or(0, |frame| (frame.timestamp_ms + 1).min(duration_ms)),
    };
    let mut observations = HashMap::<u64, usize>::new();
    for frame in frames {
        for person in &frame.people {
            if let Some(id) = person.track_id {
                *observations.entry(id).or_default() += 1;
            }
        }
    }
    let mut two = 0;
    let mut four = 0;
    for frame in frames {
        let mut first = 0;
        let mut second = 0;
        for person in &frame.people {
            let Some(id) = person.track_id else { continue };
            if observations.get(&id).copied().unwrap_or(0) < config.min_track_observations {
                continue;
            }
            match person.candidate.side {
                Some(CourtSide::First) => first += 1,
                Some(CourtSide::Second) => second += 1,
                None => {}
            }
        }
        match (first, second) {
            (1, 1) => two += 1,
            (2, 2) => four += 1,
            _ => {}
        }
    }
    let (count, supporting_frames) = if two > four {
        (ObservedCount::Two, two)
    } else if four > two {
        (ObservedCount::Four, four)
    } else {
        (ObservedCount::Unknown, 0)
    };
    let quality = if frames.is_empty() {
        0.0
    } else {
        supporting_frames as f64 / frames.len() as f64
    };
    let count =
        if supporting_frames >= config.min_count_frames && quality >= config.min_count_fraction {
            count
        } else {
            ObservedCount::Unknown
        };
    CountAssessment {
        count,
        evidence,
        quality,
        supporting_frames,
    }
}

fn invalid(message: &str) -> SportcutError {
    SportcutError::InvalidInput(format!("player tracking: {message}"))
}
