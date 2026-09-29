//! Per-clip scoring, aggregation, road-map targets, and the text table.

use std::fmt::Write as _;

use serde::Serialize;
use sportcut_rally::{SegmentationConfig, TimeSpan};
use sportcut_vision::ObservedCount;

use crate::labels::ClipLabels;
use crate::metrics::{
    confidently_wrong_rate, is_sorted_disjoint, match_boundaries, merge_touching, overlap_counts,
    rally_spans, rally_time_overlap,
};
use crate::predict::{predicted_count, predicted_timeline, Prediction, TrackView};

/// Format version of the JSON report.
pub const REPORT_SCHEMA_VERSION: u32 = 1;

/// Boundary tolerance behind the road-map target (±2 s).
pub const DEFAULT_TOLERANCE_MS: i64 = 2_000;

/// Largest accepted difference between the labeled and analysed duration.
pub const MAX_DURATION_DRIFT_MS: i64 = 1_000;

const PLAYER_COUNT_TARGET: f64 = 0.85;
const BOUNDARY_HIT_TARGET: f64 = 0.85;
const CONFIDENTLY_WRONG_TARGET: f64 = 0.05;

/// Which rally timeline was scored.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PredictionSource {
    /// The stored `rally_suggestions.json` timeline.
    Stored,
    /// Segmentation re-run with these thresholds.
    Replay(SegmentationConfig),
}

/// Expected versus predicted player count for one clip.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct PlayerMetrics {
    /// Labeled count, 2 or 4.
    pub expected: u8,
    /// Engine count, or `None` when the track artifact has no review.
    pub predicted: Option<ObservedCount>,
    /// Whether the engine count equals the label; `unknown` is never correct.
    pub correct: bool,
}

/// Labeled rally boundaries (starts and ends) and how many were hit.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct BoundaryMetrics {
    /// Labeled boundaries: two per labeled rally.
    pub labeled: usize,
    /// Labeled boundaries matched within the tolerance.
    pub hit: usize,
    /// `hit / labeled`, or `None` without labeled boundaries.
    pub hit_rate: Option<f64>,
}

impl BoundaryMetrics {
    fn new(labeled: usize, hit: usize) -> Self {
        Self {
            labeled,
            hit,
            hit_rate: ratio(hit as i64, labeled as i64),
        }
    }
}

/// Rally-level agreement counts.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Default)]
pub struct RallyMetrics {
    /// Labeled rallies.
    pub labeled: usize,
    /// Predicted rallies.
    pub predicted: usize,
    /// Labeled rallies that no prediction overlaps.
    pub missed: usize,
    /// Predicted rallies that overlap no labeled rally.
    pub spurious: usize,
}

impl RallyMetrics {
    fn confidently_wrong_rate(self) -> f64 {
        round(confidently_wrong_rate(
            self.labeled,
            self.predicted,
            self.missed,
            self.spurious,
        ))
    }
}

/// Labeled and predicted rally time compared as sets.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct RallyTimeMetrics {
    /// Time labeled and predicted as rally.
    pub intersection_ms: i64,
    /// Time labeled or predicted as rally.
    pub union_ms: i64,
    /// `intersection / union`; 1.0 when neither has rally time.
    pub iou: f64,
}

impl RallyTimeMetrics {
    fn new(intersection_ms: i64, union_ms: i64) -> Self {
        Self {
            intersection_ms,
            union_ms,
            iou: ratio(intersection_ms, union_ms).unwrap_or(1.0),
        }
    }
}

/// Every metric for one scored clip.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct ClipMetrics {
    /// Player-count comparison.
    pub players: PlayerMetrics,
    /// Boundary hits.
    pub boundaries: BoundaryMetrics,
    /// Rally agreement counts.
    pub rallies: RallyMetrics,
    /// `(missed + spurious) / (labeled + predicted)` rallies.
    pub confidently_wrong_rate: f64,
    /// Rally-time overlap.
    pub rally_time: RallyTimeMetrics,
}

/// Whether a clip could be scored.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum ClipOutcome {
    /// Metrics were computed.
    Scored(ClipMetrics),
    /// The clip's inputs were missing or unusable.
    Error {
        /// What was wrong, naming the file or field.
        error: String,
    },
}

/// One clip's line in the report.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct ClipReport {
    /// Identity from the manifest or labels.
    pub clip_id: String,
    /// The labels' `clean` flag, when labels were readable.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub clean: Option<bool>,
    /// Metrics or the reason there are none.
    #[serde(flatten)]
    pub outcome: ClipOutcome,
}

impl ClipReport {
    /// A clip whose inputs could not be read or used.
    pub fn error(clip_id: impl Into<String>, error: impl Into<String>) -> Self {
        Self {
            clip_id: clip_id.into(),
            clean: None,
            outcome: ClipOutcome::Error {
                error: error.into(),
            },
        }
    }

    fn metrics(&self) -> Option<&ClipMetrics> {
        match &self.outcome {
            ClipOutcome::Scored(metrics) => Some(metrics),
            ClipOutcome::Error { .. } => None,
        }
    }
}

/// Player-count accuracy over all scored clips and over clean ones.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct CountMetrics {
    /// Clips with the correct count.
    pub correct: usize,
    /// Scored clips.
    pub total: usize,
    /// `correct / total`.
    pub accuracy: Option<f64>,
    /// Clean clips with the correct count.
    pub clean_correct: usize,
    /// Scored clean clips.
    pub clean_total: usize,
    /// `clean_correct / clean_total`.
    pub clean_accuracy: Option<f64>,
}

/// Outcome of one road-map target.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum TargetStatus {
    /// The measured value meets the target.
    Pass,
    /// The measured value misses the target.
    Fail,
    /// Nothing was measured.
    NoData,
}

/// One road-map target and its measured value.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct TargetResult {
    /// Stable identifier.
    pub name: &'static str,
    /// Human-readable comparison, such as `>= 0.85`.
    pub threshold: String,
    /// Measured value, if any.
    pub value: Option<f64>,
    /// Pass, fail, or no data.
    pub status: TargetStatus,
}

impl TargetResult {
    fn at_least(name: &'static str, target: f64, value: Option<f64>) -> Self {
        Self::new(name, format!(">= {target:.2}"), value, |value| {
            value >= target
        })
    }

    fn at_most(name: &'static str, target: f64, value: Option<f64>) -> Self {
        Self::new(name, format!("<= {target:.2}"), value, |value| {
            value <= target
        })
    }

    fn new(
        name: &'static str,
        threshold: String,
        value: Option<f64>,
        passes: impl Fn(f64) -> bool,
    ) -> Self {
        let status = match value {
            None => TargetStatus::NoData,
            Some(value) if passes(value) => TargetStatus::Pass,
            Some(_) => TargetStatus::Fail,
        };
        // Judge the unrounded value, so 0.84995 cannot pass a 0.85 target.
        Self {
            name,
            threshold,
            value: value.map(round),
            status,
        }
    }
}

/// Micro-averaged metrics over every scored clip.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct AggregateMetrics {
    /// Clips with metrics.
    pub scored_clips: usize,
    /// Clips that could not be scored, by id.
    pub error_clips: Vec<String>,
    /// Player-count accuracy.
    pub player_count: CountMetrics,
    /// Boundary hits summed across clips.
    pub boundaries: BoundaryMetrics,
    /// Rally counts summed across clips.
    pub rallies: RallyMetrics,
    /// Confidently-wrong rate of the summed counts; `None` without scored clips.
    pub confidently_wrong_rate: Option<f64>,
    /// Rally-time IoU of the summed times; `None` without scored clips.
    pub rally_time_iou: Option<f64>,
    /// Road-map targets.
    pub targets: Vec<TargetResult>,
}

/// The complete evaluation of a clip set.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct EvalReport {
    /// Report format version.
    pub schema_version: u32,
    /// Boundary tolerance used.
    pub tolerance_ms: i64,
    /// Which rally timeline was scored.
    pub prediction_source: PredictionSource,
    /// Per-clip results, sorted by id.
    pub clips: Vec<ClipReport>,
    /// Totals and targets.
    pub aggregate: AggregateMetrics,
}

impl EvalReport {
    /// True when a target failed or no clip could be scored.
    pub fn any_target_failed(&self) -> bool {
        self.aggregate.scored_clips == 0
            || self
                .aggregate
                .targets
                .iter()
                .any(|target| target.status == TargetStatus::Fail)
    }
}

/// Score one clip. Unusable inputs produce an error outcome, never a panic.
pub fn score_clip(
    labels: &ClipLabels,
    tracks: &TrackView,
    prediction: Prediction<'_>,
    tolerance_ms: i64,
) -> ClipReport {
    let fail = |error: String| ClipReport {
        clip_id: labels.clip_id.clone(),
        clean: Some(labels.clean),
        outcome: ClipOutcome::Error { error },
    };
    if let Err(error) = labels.validate() {
        return fail(error.to_string());
    }
    let analysed_ms = tracks.input.duration_ms;
    if (analysed_ms - labels.duration_ms).abs() > MAX_DURATION_DRIFT_MS {
        return fail(format!(
            "labels say {} ms but the tracks cover {analysed_ms} ms",
            labels.duration_ms
        ));
    }
    let timeline = match predicted_timeline(tracks, prediction) {
        Ok(timeline) => timeline,
        Err(error) => return fail(format!("segmentation replay failed: {error}")),
    };

    let labeled = merge_touching(labels.rally_spans());
    let predicted = rally_spans(&timeline);
    if !is_sorted_disjoint(&predicted) {
        return fail("predicted rally spans are unsorted, empty, or overlapping".to_string());
    }
    let hits = boundary_hits(&labeled, &predicted, tolerance_ms);
    let (missed, spurious) = overlap_counts(&labeled, &predicted);
    let rallies = RallyMetrics {
        labeled: labeled.len(),
        predicted: predicted.len(),
        missed,
        spurious,
    };
    let (intersection_ms, union_ms) = rally_time_overlap(&labeled, &predicted);
    let count = predicted_count(tracks);

    ClipReport {
        clip_id: labels.clip_id.clone(),
        clean: Some(labels.clean),
        outcome: ClipOutcome::Scored(ClipMetrics {
            players: PlayerMetrics {
                expected: labels.players,
                predicted: count,
                correct: count.is_some_and(|count| matches_label(count, labels.players)),
            },
            boundaries: BoundaryMetrics::new(labeled.len() * 2, hits),
            rallies,
            confidently_wrong_rate: rallies.confidently_wrong_rate(),
            rally_time: RallyTimeMetrics::new(intersection_ms, union_ms),
        }),
    }
}

/// Combine clip results into a report with micro-averaged totals and targets.
pub fn aggregate(
    mut clips: Vec<ClipReport>,
    tolerance_ms: i64,
    prediction_source: PredictionSource,
) -> EvalReport {
    clips.sort_by(|a, b| a.clip_id.cmp(&b.clip_id));

    let mut count = CountMetrics {
        correct: 0,
        total: 0,
        accuracy: None,
        clean_correct: 0,
        clean_total: 0,
        clean_accuracy: None,
    };
    let (mut labeled_boundaries, mut hit_boundaries) = (0, 0);
    let mut rallies = RallyMetrics::default();
    let (mut intersection_ms, mut union_ms) = (0, 0);
    let mut error_clips = Vec::new();

    for clip in &clips {
        let Some(metrics) = clip.metrics() else {
            error_clips.push(clip.clip_id.clone());
            continue;
        };
        let correct = usize::from(metrics.players.correct);
        count.total += 1;
        count.correct += correct;
        if clip.clean == Some(true) {
            count.clean_total += 1;
            count.clean_correct += correct;
        }
        labeled_boundaries += metrics.boundaries.labeled;
        hit_boundaries += metrics.boundaries.hit;
        rallies.labeled += metrics.rallies.labeled;
        rallies.predicted += metrics.rallies.predicted;
        rallies.missed += metrics.rallies.missed;
        rallies.spurious += metrics.rallies.spurious;
        intersection_ms += metrics.rally_time.intersection_ms;
        union_ms += metrics.rally_time.union_ms;
    }
    count.accuracy = ratio(count.correct as i64, count.total as i64);
    count.clean_accuracy = ratio(count.clean_correct as i64, count.clean_total as i64);

    let scored_clips = count.total;
    let boundaries = BoundaryMetrics::new(labeled_boundaries, hit_boundaries);
    let raw_wrong = (scored_clips > 0).then(|| {
        confidently_wrong_rate(
            rallies.labeled,
            rallies.predicted,
            rallies.missed,
            rallies.spurious,
        )
    });
    let wrong = raw_wrong.map(round);
    let iou = (scored_clips > 0).then(|| RallyTimeMetrics::new(intersection_ms, union_ms).iou);
    let targets = vec![
        TargetResult::at_least(
            "player_count_clean",
            PLAYER_COUNT_TARGET,
            raw_ratio(count.clean_correct as i64, count.clean_total as i64),
        ),
        TargetResult::at_least(
            "boundary_hit_rate",
            BOUNDARY_HIT_TARGET,
            raw_ratio(hit_boundaries as i64, labeled_boundaries as i64),
        ),
        TargetResult::at_most(
            "confidently_wrong_rate",
            CONFIDENTLY_WRONG_TARGET,
            raw_wrong,
        ),
    ];

    EvalReport {
        schema_version: REPORT_SCHEMA_VERSION,
        tolerance_ms,
        prediction_source,
        clips,
        aggregate: AggregateMetrics {
            scored_clips,
            error_clips,
            player_count: count,
            boundaries,
            rallies,
            confidently_wrong_rate: wrong,
            rally_time_iou: iou,
            targets,
        },
    }
}

/// Fixed-width text rendering of a report.
pub fn render_table(report: &EvalReport) -> String {
    let width = report
        .clips
        .iter()
        .map(|clip| clip.clip_id.len())
        .chain(["clip".len(), "total".len()])
        .max()
        .unwrap_or(4);
    let mut out = String::new();
    let source = match report.prediction_source {
        PredictionSource::Stored => "stored suggestions",
        PredictionSource::Replay(_) => "replayed segmentation",
    };
    let _ = writeln!(
        out,
        "scoring {source}, boundary tolerance ±{} ms\n",
        report.tolerance_ms
    );
    let _ = writeln!(
        out,
        "{:<width$}  {:<5}  {:<13}  {:<14}  {:>6}  {:>8}  {:>10}  {:>5}",
        "clip", "clean", "players", "boundaries", "missed", "spurious", "conf-wrong", "IoU"
    );
    for clip in &report.clips {
        let clean = match clip.clean {
            Some(true) => "yes",
            Some(false) => "no",
            None => "-",
        };
        match &clip.outcome {
            ClipOutcome::Error { error } => {
                let _ = writeln!(out, "{:<width$}  {clean:<5}  error: {error}", clip.clip_id);
            }
            ClipOutcome::Scored(metrics) => {
                let players = format!(
                    "{}/{} {}",
                    metrics.players.expected,
                    count_name(metrics.players.predicted),
                    if metrics.players.correct { "ok" } else { "x" }
                );
                let _ = writeln!(
                    out,
                    "{:<width$}  {clean:<5}  {players:<13}  {:<14}  {:>6}  {:>8}  {:>10}  {:>5.3}",
                    clip.clip_id,
                    boundaries(metrics.boundaries),
                    metrics.rallies.missed,
                    metrics.rallies.spurious,
                    percent(Some(metrics.confidently_wrong_rate)),
                    metrics.rally_time.iou,
                );
            }
        }
    }

    let total = &report.aggregate;
    let players = format!(
        "{}/{}",
        total.player_count.correct, total.player_count.total
    );
    let _ = writeln!(
        out,
        "{:<width$}  {:<5}  {players:<13}  {:<14}  {:>6}  {:>8}  {:>10}  {:>5}",
        "total",
        "",
        boundaries(total.boundaries),
        total.rallies.missed,
        total.rallies.spurious,
        percent(total.confidently_wrong_rate),
        total
            .rally_time_iou
            .map_or_else(|| "-".to_string(), |iou| format!("{iou:.3}")),
    );

    let _ = writeln!(out, "\ntargets");
    for target in &total.targets {
        let status = match target.status {
            TargetStatus::Pass => "PASS",
            TargetStatus::Fail => "FAIL",
            TargetStatus::NoData => "NO DATA",
        };
        let _ = writeln!(
            out,
            "  {:<24}  {:<8}  {:>7}  {status}",
            target.name,
            target.threshold,
            percent(target.value)
        );
    }
    if !total.error_clips.is_empty() {
        let _ = writeln!(out, "\nnot scored: {}", total.error_clips.join(", "));
    }
    out
}

fn boundary_hits(labeled: &[TimeSpan], predicted: &[TimeSpan], tolerance_ms: i64) -> usize {
    let starts = |spans: &[TimeSpan]| spans.iter().map(|span| span.start_ms).collect::<Vec<_>>();
    let ends = |spans: &[TimeSpan]| spans.iter().map(|span| span.end_ms).collect::<Vec<_>>();
    match_boundaries(&starts(labeled), &starts(predicted), tolerance_ms)
        + match_boundaries(&ends(labeled), &ends(predicted), tolerance_ms)
}

fn matches_label(count: ObservedCount, players: u8) -> bool {
    matches!(
        (count, players),
        (ObservedCount::Two, 2) | (ObservedCount::Four, 4)
    )
}

fn count_name(count: Option<ObservedCount>) -> &'static str {
    match count {
        Some(ObservedCount::Two) => "two",
        Some(ObservedCount::Four) => "four",
        Some(ObservedCount::Unknown) => "unknown",
        None => "none",
    }
}

fn boundaries(metrics: BoundaryMetrics) -> String {
    format!(
        "{}/{} {}",
        metrics.hit,
        metrics.labeled,
        percent(metrics.hit_rate)
    )
}

fn percent(value: Option<f64>) -> String {
    value.map_or_else(|| "-".to_string(), |value| format!("{:.1}%", value * 100.0))
}

/// `numerator / denominator` rounded for stable output, or `None` for 0/0.
fn ratio(numerator: i64, denominator: i64) -> Option<f64> {
    raw_ratio(numerator, denominator).map(round)
}

fn raw_ratio(numerator: i64, denominator: i64) -> Option<f64> {
    (denominator > 0).then(|| numerator as f64 / denominator as f64)
}

fn round(value: f64) -> f64 {
    (value * 10_000.0).round() / 10_000.0
}
