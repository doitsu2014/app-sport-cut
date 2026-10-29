//! Accuracy evaluation of player count and rally/rest segmentation.
//!
//! This crate compares what the engine produced for a recording with labels a
//! person wrote by hand, and reports the metrics behind the road-map targets:
//! player-count accuracy, rally-boundary hit rate within a tolerance, and the
//! confidently-wrong rate. It is pure: callers read the label and artifact
//! files and pass typed values in, so the same inputs always give the same
//! report.
#![forbid(unsafe_code)]

mod labels;
mod metrics;
mod predict;
mod report;

pub use labels::{
    ClipLabels, LabeledRally, Manifest, ManifestEntry, LABELS_SCHEMA_VERSION,
    MANIFEST_SCHEMA_VERSION,
};
pub use metrics::{
    confidently_wrong_rate, is_sorted_disjoint, match_boundaries, merge_touching, overlap_counts,
    rally_spans, rally_time_overlap,
};
pub use predict::{predicted_count, predicted_timeline, Prediction, TrackView};
pub use report::{
    aggregate, render_table, score_clip, AggregateMetrics, BoundaryMetrics, ClipMetrics,
    ClipOutcome, ClipReport, CountMetrics, EvalReport, PlayerMetrics, PredictionSource,
    RallyMetrics, RallyTimeMetrics, TargetResult, TargetStatus, DEFAULT_TOLERANCE_MS,
    MAX_DURATION_DRIFT_MS, REPORT_SCHEMA_VERSION,
};
