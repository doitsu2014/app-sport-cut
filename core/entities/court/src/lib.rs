//! Court geometry: the calibration a user marks, and the mapping it defines.
//!
//! The user marks the four corners of the court on the recording. Those corners
//! are captured in **normalized displayed frame coordinates** — `(0, 0)` is the
//! top-left of the frame as the user sees it and `(1, 1)` the bottom-right —
//! rather than in the source file's stored pixels. That is the one space the
//! on-screen preview, the analysis proxy, and the frames sampled from the proxy
//! agree on without conversion, because the proxy is written with the container's
//! rotation already applied.
//!
//! The corners are read as a walk around the court: nearest the camera on the
//! user's left, then nearest on the right, then farthest on the right, then
//! farthest on the left. They define a projective map between the image and a
//! **unit-square court** whose `u` axis runs across the edge nearest the camera
//! and whose `v` axis runs from that edge to the far one.
//!
//! One thing the corners cannot say is which way the court runs relative to the
//! camera, because the net falls on the midpoint of the court's *long* axis
//! either way, and a rectangle's corner order is only determined up to
//! reflection. [`CourtOrientation`] carries that answer, and the net — which is
//! what [`CalibrationSegment::side_of`] divides the court by — follows from it.

#![forbid(unsafe_code)]

mod homography;

use serde::{Deserialize, Serialize};
use sportcut_common::{Result, SportcutError};

pub use homography::{CourtMapping, CourtOutline};

/// Separator used when naming a calibration problem, so the message reads as a
/// sentence rather than a fragment.
const PROBLEM_PREFIX: &str = "court calibration:";

/// Smallest separation, in normalized frame units, between two court corners.
///
/// Two taps closer than this cannot describe a court — on a 1920-wide frame it
/// is under two pixels — and a quadrilateral that nearly repeats a corner makes
/// the homography numerically meaningless.
pub const MIN_CORNER_SEPARATION: f64 = 1e-3;

/// Smallest area, in normalized frame units squared, a marked quadrilateral may
/// enclose and still define a court.
pub const MIN_QUADRILATERAL_AREA: f64 = 1e-6;

/// Smallest turn, in normalized frame units squared, that counts as the corners
/// changing direction rather than lying in a straight line.
const MIN_TURN: f64 = 1e-12;

/// A position in the displayed frame.
///
/// Normalized: the frame spans `0.0..=1.0` on both axes, regardless of its
/// pixel dimensions or the rotation its container declares.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ImagePoint {
    /// Horizontal position, `0.0` at the left edge.
    pub x: f64,
    /// Vertical position, `0.0` at the top edge.
    pub y: f64,
}

impl ImagePoint {
    /// Build a point.
    pub const fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }

    /// Whether this point is finite and lies inside the frame.
    fn is_inside_frame(&self) -> bool {
        self.x.is_finite()
            && self.y.is_finite()
            && (0.0..=1.0).contains(&self.x)
            && (0.0..=1.0).contains(&self.y)
    }

    /// Squared distance to another point.
    fn distance_squared(&self, other: &Self) -> f64 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        dx * dx + dy * dy
    }
}

/// A position on the court plane.
///
/// Normalized: the marked court spans `0.0..=1.0` on both axes. `u` runs across
/// the edge nearest the camera and `v` runs from that edge to the far one.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CourtPoint {
    /// Position across the near edge.
    pub u: f64,
    /// Position from the near edge towards the far one.
    pub v: f64,
}

impl CourtPoint {
    /// Build a point.
    pub const fn new(u: f64, v: f64) -> Self {
        Self { u, v }
    }
}

/// Which way the court runs relative to where the camera was standing.
///
/// The four corners are read in image order, so on their own they cannot say
/// whether the edge nearest the camera is a baseline or a sideline. This is that
/// answer, and it places the net.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CourtOrientation {
    /// The court stretches away from the camera, so the edge nearest the camera
    /// is a baseline and the net cuts across the `v` axis.
    Away,
    /// The court stretches across the view, so the edge nearest the camera is a
    /// sideline and the net cuts across the `u` axis.
    Across,
}

/// Which half of the court, divided by the net, a position falls in.
///
/// The two halves are named for the corners that distinguish them, which holds
/// in both orientations and so never depends on where the camera stood.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CourtSide {
    /// The half containing the calibration's first corner.
    First,
    /// The half containing the calibration's third corner.
    Second,
}

/// One calibrated span of a recording.
///
/// A recording holds a list of these so a camera that gets moved part-way
/// through can be re-marked without discarding the earlier calibration. A
/// segment runs until the next one begins, or to the end of the recording.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CalibrationSegment {
    /// Timestamp on the recording timeline where this segment begins.
    pub from_ms: i64,
    /// The four court corners, in image order: near-left, near-right,
    /// far-right, far-left as the user sees them.
    pub corners: [ImagePoint; 4],
    /// Which way the court runs relative to the camera.
    pub orientation: CourtOrientation,
}

impl CalibrationSegment {
    /// Check that this segment describes a court at all.
    ///
    /// Rejects corners that are not finite, that fall outside the frame, that
    /// repeat each other, or that are wound the wrong way — a quadrilateral that
    /// is collinear, self-crossing, or barely encloses any area cannot define a
    /// court and would otherwise produce a meaningless mapping.
    pub fn validate(&self) -> Result<()> {
        if self.from_ms < 0 {
            return Err(self.problem(format!("segment start {} is negative", self.from_ms)));
        }

        for (index, corner) in self.corners.iter().enumerate() {
            if !corner.is_inside_frame() {
                return Err(self.problem(format!(
                    "corner {} at ({}, {}) is outside the frame",
                    index + 1,
                    corner.x,
                    corner.y
                )));
            }
        }

        let separation = MIN_CORNER_SEPARATION * MIN_CORNER_SEPARATION;
        for (index, corner) in self.corners.iter().enumerate() {
            for (offset, other) in self.corners.iter().enumerate().skip(index + 1) {
                if corner.distance_squared(other) < separation {
                    return Err(self.problem(format!(
                        "corners {} and {} are in the same place",
                        index + 1,
                        offset + 1
                    )));
                }
            }
        }

        // A projected rectangle is always convex and consistently wound, so any
        // turn in the opposite direction means the corners were not marked as a
        // walk around the court.
        let mut area = 0.0_f64;
        let mut winding = 0.0_f64;
        for index in 0..4 {
            let current = self.corners[index];
            let next = self.corners[(index + 1) % 4];
            let after = self.corners[(index + 2) % 4];
            area += current.x * next.y - next.x * current.y;

            let turn = turn_at(current, next, after);
            if turn == 0.0 {
                return Err(self.problem(format!(
                    "corners {}, {} and {} are in a straight line",
                    index + 1,
                    (index + 1) % 4 + 1,
                    (index + 2) % 4 + 1
                )));
            }
            if winding == 0.0 {
                winding = turn.signum();
            } else if turn.signum() != winding {
                return Err(
                    self.problem("the corners do not go round the court in order".to_string())
                );
            }
        }

        if (area.abs() / 2.0) < MIN_QUADRILATERAL_AREA {
            return Err(self.problem(format!(
                "the marked court encloses almost no area ({:.6})",
                area.abs() / 2.0
            )));
        }

        Ok(())
    }

    /// The mapping this segment defines, validating it first.
    pub fn mapping(&self) -> Result<CourtMapping> {
        self.validate()?;
        CourtMapping::from_corners(&self.corners)
    }

    /// The net, as the two ends of its line in court coordinates.
    ///
    /// The net always falls on the midpoint of the court's long axis, so which
    /// axis it cuts across is what the orientation decides.
    pub fn net_in_court(&self) -> [CourtPoint; 2] {
        match self.orientation {
            CourtOrientation::Away => [CourtPoint::new(0.0, 0.5), CourtPoint::new(1.0, 0.5)],
            CourtOrientation::Across => [CourtPoint::new(0.5, 0.0), CourtPoint::new(0.5, 1.0)],
        }
    }

    /// Which half of the net a court position falls in.
    ///
    /// A position exactly on the net is reported as the first half; callers
    /// that care about a player near the net should ask about a representative
    /// position rather than a single frame.
    pub fn side_of(&self, point: CourtPoint) -> CourtSide {
        let along_long_axis = match self.orientation {
            CourtOrientation::Away => point.v,
            CourtOrientation::Across => point.u,
        };
        if along_long_axis <= 0.5 {
            CourtSide::First
        } else {
            CourtSide::Second
        }
    }

    /// The court outline and the net, projected back into image coordinates.
    pub fn outline(&self) -> Result<CourtOutline> {
        let mapping = self.mapping()?;
        let net = self.net_in_court();
        let project = |point: CourtPoint| {
            mapping.to_image(point).ok_or_else(|| {
                self.problem("the net projects outside the mapped image".to_string())
            })
        };
        Ok(CourtOutline {
            corners: self.corners,
            net: [project(net[0])?, project(net[1])?],
        })
    }

    /// A calibration problem, naming this segment's start so a message points at
    /// the right one when a recording holds several.
    fn problem(&self, detail: String) -> SportcutError {
        SportcutError::InvalidInput(format!(
            "{PROBLEM_PREFIX} segment from {}ms: {detail}",
            self.from_ms
        ))
    }
}

/// A match's court calibration.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CourtCalibration {
    /// Schema version, so a stored calibration can be migrated rather than
    /// guessed at.
    pub schema_version: u32,
    /// Calibrated spans, in recording order.
    pub segments: Vec<CalibrationSegment>,
}

impl CourtCalibration {
    /// Schema version written by this build.
    pub const SCHEMA_VERSION: u32 = 1;

    /// A calibration from a single set of corners covering the recording.
    pub fn from_corners(corners: [ImagePoint; 4], orientation: CourtOrientation) -> Self {
        Self {
            schema_version: Self::SCHEMA_VERSION,
            segments: vec![CalibrationSegment {
                from_ms: 0,
                corners,
                orientation,
            }],
        }
    }

    /// Check that this calibration is usable.
    pub fn validate(&self) -> Result<()> {
        if self.schema_version > Self::SCHEMA_VERSION {
            return Err(SportcutError::Artifact(format!(
                "calibration was written by a newer engine (schema {} > {})",
                self.schema_version,
                Self::SCHEMA_VERSION
            )));
        }
        if self.segments.is_empty() {
            return Err(SportcutError::InvalidInput(format!(
                "{PROBLEM_PREFIX} no corners have been marked"
            )));
        }

        let mut previous: Option<i64> = None;
        for segment in &self.segments {
            segment.validate()?;
            if let Some(previous) = previous {
                if segment.from_ms <= previous {
                    return Err(SportcutError::InvalidInput(format!(
                        "{PROBLEM_PREFIX} segment starting at {}ms does not come after the one \
                         at {previous}ms",
                        segment.from_ms
                    )));
                }
            }
            previous = Some(segment.from_ms);
        }
        Ok(())
    }

    /// The segment covering a point on the recording timeline, if any.
    ///
    /// Returns `None` before the first segment begins, so a recording whose
    /// calibration starts part-way through makes no claim about the earlier part.
    pub fn segment_at(&self, timestamp_ms: i64) -> Option<&CalibrationSegment> {
        self.segments
            .iter()
            .rev()
            .find(|segment| segment.from_ms <= timestamp_ms)
    }
}

/// Signed turn at `next` along the path `current` -> `next` -> `after`.
///
/// Zero means the three points are in a straight line.
fn turn_at(current: ImagePoint, next: ImagePoint, after: ImagePoint) -> f64 {
    let turn =
        (next.x - current.x) * (after.y - next.y) - (next.y - current.y) * (after.x - next.x);
    if turn.abs() < MIN_TURN {
        0.0
    } else {
        turn
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A court seen from behind a baseline, marked in the order the user walks
    /// it: near-left, near-right, far-right, far-left.
    const TRAPEZOID: [ImagePoint; 4] = [
        ImagePoint::new(0.10, 0.90),
        ImagePoint::new(0.90, 0.90),
        ImagePoint::new(0.70, 0.40),
        ImagePoint::new(0.30, 0.40),
    ];

    fn segment(corners: [ImagePoint; 4]) -> CalibrationSegment {
        CalibrationSegment {
            from_ms: 0,
            corners,
            orientation: CourtOrientation::Away,
        }
    }

    fn valid_segment() -> CalibrationSegment {
        segment(TRAPEZOID)
    }

    fn rejection(corners: [ImagePoint; 4]) -> String {
        segment(corners)
            .validate()
            .expect_err("the corners must be rejected")
            .to_string()
    }

    #[test]
    fn a_valid_calibration_produces_a_mapping_in_both_directions() {
        let segment = valid_segment();
        let mapping = segment
            .mapping()
            .expect("a marked trapezoid defines a court");

        let court = mapping
            .to_court(ImagePoint::new(0.5, 0.65))
            .expect("an image point maps to the court");
        assert!(court.u.is_finite() && court.v.is_finite(), "{court:?}");

        let back = mapping
            .to_image(CourtPoint::new(0.5, 0.5))
            .expect("a court point maps to the image");
        assert!(back.x.is_finite() && back.y.is_finite(), "{back:?}");
    }

    #[test]
    fn a_duplicated_corner_is_rejected_by_name() {
        let mut corners = TRAPEZOID;
        corners[1] = corners[0];
        let message = rejection(corners);
        assert!(message.contains("same place"), "{message}");
        assert!(message.contains("corners 1 and 2"), "{message}");
    }

    #[test]
    fn three_corners_in_a_straight_line_are_rejected() {
        let corners = [
            ImagePoint::new(0.10, 0.50),
            ImagePoint::new(0.50, 0.50),
            ImagePoint::new(0.90, 0.50),
            ImagePoint::new(0.50, 0.90),
        ];
        let message = rejection(corners);
        assert!(message.contains("straight line"), "{message}");
    }

    #[test]
    fn a_corner_outside_the_frame_is_rejected_by_position() {
        let mut corners = TRAPEZOID;
        corners[2] = ImagePoint::new(1.20, 0.40);
        let message = rejection(corners);
        assert!(message.contains("corner 3"), "{message}");
        assert!(message.contains("outside the frame"), "{message}");

        let mut not_a_number = TRAPEZOID;
        not_a_number[0] = ImagePoint::new(f64::NAN, 0.90);
        let message = rejection(not_a_number);
        assert!(message.contains("outside the frame"), "{message}");
    }

    #[test]
    fn corners_marked_out_of_order_are_rejected() {
        // A bow tie: the walk crosses itself rather than going round the court.
        let corners = [TRAPEZOID[0], TRAPEZOID[1], TRAPEZOID[3], TRAPEZOID[2]];
        let message = rejection(corners);
        assert!(
            message.contains("do not go round the court in order"),
            "{message}"
        );
    }

    #[test]
    fn a_quadrilateral_enclosing_almost_no_area_is_rejected() {
        // A thin parallelogram: every corner is well separated from the others,
        // but the strip it encloses is far too narrow to define a court.
        let corners = [
            ImagePoint::new(0.100, 0.500000),
            ImagePoint::new(0.900, 0.500000),
            ImagePoint::new(0.901, 0.500001),
            ImagePoint::new(0.101, 0.500001),
        ];
        let message = rejection(corners);
        assert!(message.contains("almost no area"), "{message}");
    }

    #[test]
    fn the_net_falls_on_the_courts_long_axis() {
        // A court running away from the camera: the net cuts across the axis
        // from the near edge to the far one.
        let away = valid_segment();
        assert_eq!(
            away.net_in_court(),
            [CourtPoint::new(0.0, 0.5), CourtPoint::new(1.0, 0.5)]
        );

        // A court running across the view: the edge nearest the camera is a
        // sideline, so the long axis is the other one.
        let across = CalibrationSegment {
            orientation: CourtOrientation::Across,
            ..valid_segment()
        };
        assert_eq!(
            across.net_in_court(),
            [CourtPoint::new(0.5, 0.0), CourtPoint::new(0.5, 1.0)]
        );
    }

    #[test]
    fn a_position_is_assigned_the_half_of_the_net_it_falls_in() {
        let away = valid_segment();
        assert_eq!(away.side_of(CourtPoint::new(0.5, 0.2)), CourtSide::First);
        assert_eq!(away.side_of(CourtPoint::new(0.5, 0.8)), CourtSide::Second);
        // A position on the net itself is reported as the first half rather
        // than as no side at all.
        assert_eq!(away.side_of(CourtPoint::new(0.5, 0.5)), CourtSide::First);

        let across = CalibrationSegment {
            orientation: CourtOrientation::Across,
            ..valid_segment()
        };
        assert_eq!(across.side_of(CourtPoint::new(0.2, 0.5)), CourtSide::First);
        assert_eq!(across.side_of(CourtPoint::new(0.8, 0.5)), CourtSide::Second);
    }

    #[test]
    fn side_assignment_follows_the_net_rather_than_the_image() {
        // One image point, one court position, two answers: which half it is in
        // comes from where the net falls, not from where the camera stood.
        let away = valid_segment();
        let across = CalibrationSegment {
            orientation: CourtOrientation::Across,
            ..valid_segment()
        };
        let court = CourtPoint::new(0.8, 0.2);
        let image = away
            .mapping()
            .expect("a mapping")
            .to_image(court)
            .expect("the point maps");

        let seen_again = away
            .mapping()
            .expect("a mapping")
            .to_court(image)
            .expect("the point maps back");
        assert_eq!(away.side_of(seen_again), CourtSide::First);
        assert_eq!(across.side_of(seen_again), CourtSide::Second);
    }

    #[test]
    fn the_outline_carries_the_marked_corners_and_the_projected_net() {
        let segment = valid_segment();
        let outline = segment.outline().expect("the outline projects");
        assert_eq!(outline.corners, TRAPEZOID);

        let mapping = segment.mapping().expect("a mapping");
        for (index, endpoint) in segment.net_in_court().iter().enumerate() {
            let expected = mapping.to_image(*endpoint).expect("the net projects");
            assert!(
                (outline.net[index].x - expected.x).abs() < 1e-9
                    && (outline.net[index].y - expected.y).abs() < 1e-9,
                "net end {index}: expected {expected:?}, got {:?}",
                outline.net[index]
            );
        }
    }

    #[test]
    fn the_outline_follows_an_edited_corner() {
        let before = valid_segment().outline().expect("the outline projects");

        let mut corners = TRAPEZOID;
        corners[3] = ImagePoint::new(0.20, 0.30);
        let after = segment(corners)
            .outline()
            .expect("the edited outline projects");

        assert_eq!(after.corners[3], corners[3]);
        assert_ne!(after.corners[3], before.corners[3]);
        assert!(
            (after.net[0].x - before.net[0].x).abs() > 1e-9
                || (after.net[0].y - before.net[0].y).abs() > 1e-9,
            "the net should move with the corner: {before:?} vs {after:?}"
        );
    }

    #[test]
    fn a_segment_starting_before_the_recording_is_rejected() {
        let mut segment = valid_segment();
        segment.from_ms = -1;
        let error = segment.validate().expect_err("must be rejected");
        assert!(error.to_string().contains("is negative"), "{error}");
    }

    #[test]
    fn a_calibration_with_no_corners_claims_nothing() {
        let empty = CourtCalibration {
            schema_version: CourtCalibration::SCHEMA_VERSION,
            segments: Vec::new(),
        };
        let error = empty.validate().expect_err("must be rejected");
        assert!(
            error.to_string().contains("no corners have been marked"),
            "{error}"
        );
    }

    #[test]
    fn a_calibration_from_a_newer_schema_is_rejected_rather_than_guessed_at() {
        let calibration = CourtCalibration {
            schema_version: CourtCalibration::SCHEMA_VERSION + 1,
            segments: vec![valid_segment()],
        };
        let error = calibration.validate().expect_err("must be rejected");
        assert!(error.to_string().contains("newer engine"), "{error}");
    }

    #[test]
    fn segments_must_advance_through_the_recording() {
        let calibration = CourtCalibration {
            schema_version: CourtCalibration::SCHEMA_VERSION,
            segments: vec![valid_segment(), valid_segment()],
        };
        let error = calibration.validate().expect_err("must be rejected");
        assert!(error.to_string().contains("does not come after"), "{error}");
    }

    #[test]
    fn a_timestamp_before_the_first_segment_has_no_calibration() {
        // The first segment begins part-way through the recording, so the part
        // before it has no court rather than the first segment's.
        let calibration = CourtCalibration {
            schema_version: CourtCalibration::SCHEMA_VERSION,
            segments: vec![
                CalibrationSegment {
                    from_ms: 5_000,
                    ..valid_segment()
                },
                CalibrationSegment {
                    from_ms: 9_000,
                    orientation: CourtOrientation::Across,
                    ..valid_segment()
                },
            ],
        };

        assert!(calibration.segment_at(4_999).is_none());
        assert_eq!(
            calibration.segment_at(5_000).map(|s| s.orientation),
            Some(CourtOrientation::Away)
        );
        assert_eq!(
            calibration.segment_at(9_000).map(|s| s.orientation),
            Some(CourtOrientation::Across)
        );
    }
}
