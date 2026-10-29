//! Scoring against a hand-written synthetic clip. No footage is involved.

use sportcut_eval::{
    aggregate, render_table, score_clip, ClipLabels, ClipOutcome, ClipReport, EvalReport,
    Prediction, PredictionSource, TargetStatus, TrackView, DEFAULT_TOLERANCE_MS,
};
use sportcut_rally::{ClassifiedSpan, SegmentationConfig, SpanKind, TimeSpan, TrackPosition};
use sportcut_vision::ObservedCount;

fn labels() -> ClipLabels {
    serde_json::from_str(include_str!("fixtures/synthetic.labels.json")).unwrap()
}

fn tracks() -> TrackView {
    serde_json::from_str(include_str!("fixtures/synthetic.player_tracks.json")).unwrap()
}

fn span(start_ms: i64, end_ms: i64, kind: SpanKind) -> ClassifiedSpan {
    ClassifiedSpan {
        time: TimeSpan { start_ms, end_ms },
        kind,
    }
}

/// Against labels 5–15 s, 20–30 s, 40–45 s: the first rally is found within a
/// second at both ends, the second starts 4 s late, the third is missed, and a
/// spurious 50–52 s rally is predicted.
fn stored_timeline() -> Vec<ClassifiedSpan> {
    vec![
        span(0, 6_000, SpanKind::Rest),
        span(6_000, 14_000, SpanKind::Rally),
        span(14_000, 24_000, SpanKind::Rest),
        span(24_000, 30_000, SpanKind::Rally),
        span(30_000, 50_000, SpanKind::Rest),
        span(50_000, 52_000, SpanKind::Rally),
        span(52_000, 60_000, SpanKind::Unknown),
    ]
}

fn scored(report: &ClipReport) -> &sportcut_eval::ClipMetrics {
    match &report.outcome {
        ClipOutcome::Scored(metrics) => metrics,
        ClipOutcome::Error { error } => panic!("clip was not scored: {error}"),
    }
}

fn error(report: &ClipReport) -> &str {
    match &report.outcome {
        ClipOutcome::Error { error } => error,
        ClipOutcome::Scored(_) => panic!("clip was scored"),
    }
}

fn score_synthetic() -> ClipReport {
    let timeline = stored_timeline();
    score_clip(
        &labels(),
        &tracks(),
        Prediction::Stored(&timeline),
        DEFAULT_TOLERANCE_MS,
    )
}

#[test]
fn synthetic_clip_scores_exactly() {
    let report = score_synthetic();
    let metrics = scored(&report);

    assert_eq!(report.clean, Some(true));
    assert_eq!(metrics.players.predicted, Some(ObservedCount::Four));
    assert!(metrics.players.correct);
    // Starts: 5 000↔6 000 hit, 20 000 vs 24 000 miss, 40 000 miss.
    // Ends: 15 000↔14 000 hit, 30 000↔30 000 hit, 45 000 miss.
    assert_eq!((metrics.boundaries.hit, metrics.boundaries.labeled), (3, 6));
    assert_eq!(metrics.boundaries.hit_rate, Some(0.5));
    assert_eq!(metrics.rallies.labeled, 3);
    assert_eq!(metrics.rallies.predicted, 3);
    assert_eq!((metrics.rallies.missed, metrics.rallies.spurious), (1, 1));
    assert_eq!(metrics.confidently_wrong_rate, 0.3333);
    // Intersection 8 000 + 6 000; union 25 000 + 16 000 - 14 000.
    assert_eq!(metrics.rally_time.intersection_ms, 14_000);
    assert_eq!(metrics.rally_time.union_ms, 27_000);
    assert_eq!(metrics.rally_time.iou, 0.5185);
}

#[test]
fn player_count_requires_a_matching_known_count() {
    let timeline = stored_timeline();
    let mut no_review = tracks();
    no_review.review = None;
    let report = score_clip(&labels(), &no_review, Prediction::Stored(&timeline), 2_000);
    assert_eq!(scored(&report).players.predicted, None);
    assert!(!scored(&report).players.correct);

    let mut unknown = tracks();
    unknown.review.as_mut().unwrap().count.count = ObservedCount::Unknown;
    let report = score_clip(&labels(), &unknown, Prediction::Stored(&timeline), 2_000);
    assert!(!scored(&report).players.correct);

    let mut singles = labels();
    singles.players = 2;
    let report = score_clip(&singles, &tracks(), Prediction::Stored(&timeline), 2_000);
    assert!(!scored(&report).players.correct);
}

#[test]
fn unusable_inputs_become_error_clips() {
    let timeline = stored_timeline();
    let mut drifted = labels();
    drifted.duration_ms = 61_001;
    let report = score_clip(&drifted, &tracks(), Prediction::Stored(&timeline), 2_000);
    assert!(error(&report).contains("61001 ms"));

    let overlapping = [
        span(0, 10_000, SpanKind::Rally),
        span(5_000, 20_000, SpanKind::Rally),
    ];
    let report = score_clip(
        &labels(),
        &tracks(),
        Prediction::Stored(&overlapping),
        2_000,
    );
    assert!(error(&report).contains("overlapping"));

    let mut invalid = labels();
    invalid.players = 3;
    let report = score_clip(&invalid, &tracks(), Prediction::Stored(&timeline), 2_000);
    assert!(error(&report).contains("players is 3"));
}

fn config() -> SegmentationConfig {
    SegmentationConfig {
        bin_ms: 500,
        max_track_gap_ms: 2_000,
        enter_motion_per_second: 4.0,
        exit_motion_per_second: 2.0,
        audio_intensity_threshold: 0.5,
        min_rally_ms: 1_500,
        min_rest_ms: 3_000,
        min_usable_coverage: 0.0,
    }
}

#[test]
fn replay_rejects_invalid_config_and_segments_valid_tracks() {
    let mut bad = config();
    bad.exit_motion_per_second = 5.0;
    let report = score_clip(&labels(), &tracks(), Prediction::Replay(bad), 2_000);
    assert!(error(&report).contains("segmentation replay failed"));

    // Two players move fast across the court from 10 s to 20 s and stand still
    // otherwise, sampled at 5 fps.
    let mut moving = tracks();
    moving.input.positions = (0..300)
        .flat_map(|step| {
            let timestamp_ms = step * 200;
            let active = (10_000..20_000).contains(&timestamp_ms);
            let u = if active && step % 2 == 0 { 0.1 } else { 0.9 };
            [1, 2].map(|track_id| TrackPosition {
                timestamp_ms,
                track_id,
                u: if active { u } else { 0.5 },
                v: if track_id == 1 { 0.25 } else { 0.75 },
            })
        })
        .collect();
    let report = score_clip(&labels(), &moving, Prediction::Replay(config()), 2_000);
    let metrics = scored(&report);
    assert_eq!(metrics.rallies.predicted, 1);
}

fn clip_with(clip_id: &str, clean: bool, players: u8) -> ClipReport {
    let mut labels = labels();
    labels.clip_id = clip_id.to_string();
    labels.clean = clean;
    labels.players = players;
    let timeline = stored_timeline();
    score_clip(&labels, &tracks(), Prediction::Stored(&timeline), 2_000)
}

fn mixed_report() -> EvalReport {
    aggregate(
        vec![
            clip_with("c3", false, 2),
            ClipReport::error("c2", "cannot read tracks"),
            clip_with("c1", true, 4),
        ],
        2_000,
        PredictionSource::Stored,
    )
}

#[test]
fn aggregate_micro_averages_scored_clips_only() {
    let report = mixed_report();
    let ids: Vec<_> = report
        .clips
        .iter()
        .map(|clip| clip.clip_id.as_str())
        .collect();
    assert_eq!(ids, ["c1", "c2", "c3"]);

    let total = &report.aggregate;
    assert_eq!(total.scored_clips, 2);
    assert_eq!(total.error_clips, ["c2"]);
    assert_eq!(
        (total.player_count.correct, total.player_count.total),
        (1, 2)
    );
    assert_eq!(total.player_count.accuracy, Some(0.5));
    assert_eq!(
        (
            total.player_count.clean_correct,
            total.player_count.clean_total
        ),
        (1, 1)
    );
    assert_eq!((total.boundaries.hit, total.boundaries.labeled), (6, 12));
    assert_eq!((total.rallies.missed, total.rallies.spurious), (2, 2));
    assert_eq!(total.confidently_wrong_rate, Some(0.3333));
    assert_eq!(total.rally_time_iou, Some(0.5185));
}

#[test]
fn targets_pass_fail_and_report_missing_data() {
    let report = mixed_report();
    let statuses: Vec<_> = report
        .aggregate
        .targets
        .iter()
        .map(|target| (target.name, target.status))
        .collect();
    assert_eq!(
        statuses,
        [
            ("player_count_clean", TargetStatus::Pass),
            ("boundary_hit_rate", TargetStatus::Fail),
            ("confidently_wrong_rate", TargetStatus::Fail),
        ]
    );
    assert!(report.any_target_failed());

    // Perfect predictions on a non-clean clip: no clean data, nothing failed.
    let mut labels = labels();
    labels.clean = false;
    let perfect: Vec<_> = labels
        .rally_spans()
        .into_iter()
        .map(|time| ClassifiedSpan {
            time,
            kind: SpanKind::Rally,
        })
        .collect();
    let clip = score_clip(&labels, &tracks(), Prediction::Stored(&perfect), 0);
    let report = aggregate(vec![clip], 0, PredictionSource::Stored);
    assert_eq!(report.aggregate.targets[0].status, TargetStatus::NoData);
    assert!(!report.any_target_failed());

    let empty = aggregate(
        vec![ClipReport::error("c1", "missing")],
        2_000,
        PredictionSource::Stored,
    );
    assert!(empty.any_target_failed());
}

#[test]
fn json_shape_matches_the_contract() {
    let value = serde_json::to_value(mixed_report()).unwrap();
    assert_eq!(value["schema_version"], 1);
    assert_eq!(value["prediction_source"], "stored");
    assert_eq!(value["clips"][0]["status"], "scored");
    assert_eq!(value["clips"][0]["players"]["predicted"], "four");
    assert_eq!(value["clips"][0]["rally_time"]["iou"], 0.5185);
    assert_eq!(value["clips"][1]["status"], "error");
    assert_eq!(value["clips"][1]["error"], "cannot read tracks");
    assert!(value["clips"][1].get("clean").is_none());
    assert_eq!(value["aggregate"]["targets"][1]["threshold"], ">= 0.85");
    assert_eq!(value["aggregate"]["targets"][1]["status"], "fail");

    let replay = aggregate(Vec::new(), 2_000, PredictionSource::Replay(config()));
    let value = serde_json::to_value(replay).unwrap();
    assert_eq!(value["prediction_source"]["replay"]["bin_ms"], 500);
}

#[test]
fn output_is_byte_identical_across_runs() {
    let first = mixed_report();
    let second = mixed_report();
    assert_eq!(
        serde_json::to_string_pretty(&first).unwrap(),
        serde_json::to_string_pretty(&second).unwrap()
    );
    let table = render_table(&first);
    assert_eq!(table, render_table(&second));
    assert!(table.contains("c2     -      error: cannot read tracks"));
    assert!(table.contains("boundary_hit_rate"));
    assert!(table.contains("not scored: c2"));
}
