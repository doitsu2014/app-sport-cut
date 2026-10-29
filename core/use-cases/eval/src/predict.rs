//! What the engine predicted for a recording.

use serde::{Deserialize, Serialize};
use sportcut_common::Result;
use sportcut_rally::{segment, ClassifiedSpan, SegmentationConfig, SegmentationInput};
use sportcut_vision::{ObservedCount, TrackingResult};

/// The fields of `tracks/player_tracks.json` that scoring needs.
///
/// Other fields of the artifact, such as provenance, are ignored. The types are
/// the engine's own, so a change to the artifact shape fails to compile here
/// rather than being misread.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrackView {
    /// Version of the track envelope.
    pub schema_version: u32,
    /// Positions and coverage consumed by segmentation.
    pub input: SegmentationInput,
    /// Detection, count, and quality evidence; absent in older artifacts.
    #[serde(default)]
    pub review: Option<TrackingResult>,
}

/// Which rally timeline to score.
#[derive(Debug, Clone, Copy)]
pub enum Prediction<'a> {
    /// The timeline stored in `tracks/rally_suggestions.json`.
    Stored(&'a [ClassifiedSpan]),
    /// Re-run segmentation on the stored track input with these thresholds.
    Replay(SegmentationConfig),
}

/// The recording-level player count, or `None` when the artifact has no review.
pub fn predicted_count(tracks: &TrackView) -> Option<ObservedCount> {
    tracks.review.as_ref().map(|review| review.count.count)
}

/// The rally/rest/unknown timeline for the chosen prediction source.
pub fn predicted_timeline(
    tracks: &TrackView,
    prediction: Prediction<'_>,
) -> Result<Vec<ClassifiedSpan>> {
    match prediction {
        Prediction::Stored(timeline) => Ok(timeline.to_vec()),
        Prediction::Replay(config) => Ok(segment(&tracks.input, config)?.timeline),
    }
}
