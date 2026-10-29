//! Interval metrics over millisecond time spans.
//!
//! Every function takes spans sorted by start and pairwise disjoint, which is
//! what both the label validator and the segmenter's timeline guarantee.

use sportcut_rally::{ClassifiedSpan, SpanKind, TimeSpan};

/// Rally spans of a classified timeline, with touching rally spans merged.
pub fn rally_spans(timeline: &[ClassifiedSpan]) -> Vec<TimeSpan> {
    merge_touching(
        timeline
            .iter()
            .filter(|span| span.kind == SpanKind::Rally)
            .map(|span| span.time),
    )
}

/// Join spans where one ends exactly where the next starts.
///
/// Applied to labels and predictions alike, so back-to-back spans are scored
/// the same way on both sides.
pub fn merge_touching(spans: impl IntoIterator<Item = TimeSpan>) -> Vec<TimeSpan> {
    let mut merged: Vec<TimeSpan> = Vec::new();
    for span in spans {
        match merged.last_mut() {
            Some(last) if last.end_ms == span.start_ms => last.end_ms = span.end_ms,
            _ => merged.push(span),
        }
    }
    merged
}

/// Whether spans are non-empty, sorted by start, and pairwise disjoint.
pub fn is_sorted_disjoint(spans: &[TimeSpan]) -> bool {
    spans.iter().all(|span| span.start_ms < span.end_ms)
        && spans
            .windows(2)
            .all(|pair| pair[0].end_ms <= pair[1].start_ms)
}

/// Number of labeled boundaries matched one-to-one by a predicted boundary
/// within `tolerance_ms` (inclusive).
///
/// Every label has a window of the same width, so matching each label in order
/// to the earliest unused prediction inside its window gives the largest
/// possible number of matches. Both slices must be sorted ascending.
pub fn match_boundaries(labeled: &[i64], predicted: &[i64], tolerance_ms: i64) -> usize {
    let mut next = 0;
    let mut hits = 0;
    for &label in labeled {
        let earliest = label.saturating_sub(tolerance_ms);
        while next < predicted.len() && predicted[next] < earliest {
            next += 1;
        }
        if next < predicted.len() && predicted[next] <= label.saturating_add(tolerance_ms) {
            hits += 1;
            next += 1;
        }
    }
    hits
}

/// `(missed, spurious)`: labeled rallies no prediction overlaps, and predicted
/// rallies that overlap no labeled rally. Touching is not overlapping.
pub fn overlap_counts(labeled: &[TimeSpan], predicted: &[TimeSpan]) -> (usize, usize) {
    (unmatched(labeled, predicted), unmatched(predicted, labeled))
}

/// Share of all confident rally decisions that were wrong:
/// `(missed + spurious) / (labeled + predicted)`, or zero when both are empty.
pub fn confidently_wrong_rate(
    labeled: usize,
    predicted: usize,
    missed: usize,
    spurious: usize,
) -> f64 {
    let total = labeled + predicted;
    if total == 0 {
        0.0
    } else {
        (missed + spurious) as f64 / total as f64
    }
}

/// `(intersection_ms, union_ms)` of labeled and predicted rally time.
pub fn rally_time_overlap(labeled: &[TimeSpan], predicted: &[TimeSpan]) -> (i64, i64) {
    let intersection = intersection_ms(labeled, predicted);
    let union = total_ms(labeled) + total_ms(predicted) - intersection;
    (intersection, union)
}

fn overlap_ms(a: TimeSpan, b: TimeSpan) -> i64 {
    (a.end_ms.min(b.end_ms) - a.start_ms.max(b.start_ms)).max(0)
}

fn unmatched(spans: &[TimeSpan], others: &[TimeSpan]) -> usize {
    let mut other = 0;
    let mut count = 0;
    for &span in spans {
        while other < others.len() && others[other].end_ms <= span.start_ms {
            other += 1;
        }
        let overlapped = others[other..]
            .iter()
            .take_while(|candidate| candidate.start_ms < span.end_ms)
            .any(|&candidate| overlap_ms(span, candidate) > 0);
        if !overlapped {
            count += 1;
        }
    }
    count
}

fn intersection_ms(a: &[TimeSpan], b: &[TimeSpan]) -> i64 {
    let (mut i, mut j, mut total) = (0, 0, 0);
    while i < a.len() && j < b.len() {
        total += overlap_ms(a[i], b[j]);
        if a[i].end_ms <= b[j].end_ms {
            i += 1;
        } else {
            j += 1;
        }
    }
    total
}

fn total_ms(spans: &[TimeSpan]) -> i64 {
    spans.iter().map(|span| span.end_ms - span.start_ms).sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn span(start_ms: i64, end_ms: i64) -> TimeSpan {
        TimeSpan { start_ms, end_ms }
    }

    fn classified(start_ms: i64, end_ms: i64, kind: SpanKind) -> ClassifiedSpan {
        ClassifiedSpan {
            time: span(start_ms, end_ms),
            kind,
        }
    }

    #[test]
    fn rally_spans_merge_touching_and_skip_unknown() {
        let timeline = [
            classified(0, 1_000, SpanKind::Rest),
            classified(1_000, 2_000, SpanKind::Rally),
            classified(2_000, 3_000, SpanKind::Rally),
            classified(3_000, 4_000, SpanKind::Unknown),
            classified(4_000, 5_000, SpanKind::Rally),
        ];
        assert_eq!(
            rally_spans(&timeline),
            vec![span(1_000, 3_000), span(4_000, 5_000)]
        );
    }

    #[test]
    fn boundary_tolerance_is_inclusive() {
        assert_eq!(match_boundaries(&[10_000], &[12_000], 2_000), 1);
        assert_eq!(match_boundaries(&[10_000], &[12_001], 2_000), 0);
        assert_eq!(match_boundaries(&[10_000], &[8_000], 2_000), 1);
    }

    #[test]
    fn boundary_matching_is_one_to_one() {
        // One prediction between two labels can only satisfy one of them.
        assert_eq!(match_boundaries(&[1_000, 3_000], &[2_000], 2_000), 1);
        // Two predictions near one label count once.
        assert_eq!(match_boundaries(&[1_000], &[900, 1_100], 2_000), 1);
        assert_eq!(match_boundaries(&[1_000, 2_500], &[1_200, 3_000], 2_000), 2);
        // Closest-pair-first would take 1 000↔600 and strand 0; the optimum is 2.
        assert_eq!(match_boundaries(&[0, 1_000], &[600, 1_500], 600), 2);
        assert_eq!(match_boundaries(&[0], &[5], i64::MAX), 1);
        assert_eq!(match_boundaries(&[], &[1_000], 2_000), 0);
    }

    #[test]
    fn sorted_disjoint_rejects_overlap_and_empty_spans() {
        assert!(is_sorted_disjoint(&[span(0, 1), span(1, 2)]));
        assert!(!is_sorted_disjoint(&[span(0, 2), span(1, 3)]));
        assert!(!is_sorted_disjoint(&[span(1, 1)]));
        assert_eq!(
            merge_touching([span(0, 1), span(1, 2), span(3, 4)]),
            vec![span(0, 2), span(3, 4)]
        );
    }

    #[test]
    fn overlap_counts_find_missed_and_spurious() {
        let labeled = [span(0, 1_000), span(5_000, 6_000), span(9_000, 10_000)];
        let predicted = [span(500, 1_500), span(6_000, 7_000), span(9_500, 9_600)];
        // 5 000..6 000 only touches 6 000..7 000: missed; that prediction is spurious.
        assert_eq!(overlap_counts(&labeled, &predicted), (1, 1));
        assert_eq!(overlap_counts(&[], &[]), (0, 0));
    }

    #[test]
    fn confidently_wrong_rate_handles_empty() {
        assert_eq!(confidently_wrong_rate(0, 0, 0, 0), 0.0);
        assert_eq!(confidently_wrong_rate(3, 1, 2, 0), 0.5);
    }

    #[test]
    fn rally_time_overlap_sums_partial_overlaps() {
        let labeled = [span(0, 1_000), span(2_000, 4_000)];
        let predicted = [span(500, 2_500)];
        // intersection 500 + 500; union 3 000 + 2 000 - 1 000.
        assert_eq!(rally_time_overlap(&labeled, &predicted), (1_000, 4_000));
        assert_eq!(rally_time_overlap(&[], &[]), (0, 0));
    }
}
