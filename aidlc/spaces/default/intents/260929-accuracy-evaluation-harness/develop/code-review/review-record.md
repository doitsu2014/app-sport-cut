# Review Record

Reviewer: code-reviewer-agent (independent, read-only), 2026-09-29. Every
changed line in `core/crates/eval/**`, `core/cli/**` and `core/Cargo.toml` was
read.

**Verdict: no blockers. Proceed to refactor with the fixes below.**

## Verified correct

- The `unmatched` two-pointer skip is exact for sorted, disjoint spans.
- The IoU sweep and the union formula are correct.
- Tolerance is inclusive at both ends, and matching is one-to-one.
- Aggregation is micro-averaged: raw counts are summed first.
- The serde shape matches contract §4: `"stored"` / `{"replay":…}`, and the
  flattened `status` tag.
- Output is deterministic: sorted clips, no HashMap, fixed float formatting.
- The CLI ArgGroup and `requires`, negative tolerance → exit 1, and target
  miss → exit 2 all work.

## Findings

| # | Sev | Where | Finding | Disposition |
| --- | --- | --- | --- | --- |
| 1 | major | `report.rs`, CLI | No tests cover `score_clip`, `aggregate`, `any_target_failed`, `render_table`, the JSON shape, or the CLI. | Test-generation stage (U5) |
| 2 | minor | `metrics.rs:26` | Greedy by distance is not a maximum matching. Labels `[0,1000]` against predictions `[600,1500]` at tol 600 gives 1 hit; 2 is possible. Reproduced by hand. | **Fix** in refactor: a sorted two-pointer match is optimal for equal-width windows in 1-D, O(n+m). Amends DD-4. |
| 3 | minor | `metrics.rs:29,31` | `label ± tolerance` can overflow when the tolerance is huge. | **Fix**: saturating arithmetic. |
| 4 | minor | `report.rs`, `predict.rs` | The stored timeline is never checked to be sorted and disjoint, but the metrics assume it is. | **Fix**: the clip becomes `Error` if the predicted spans are not sorted, positive-length and disjoint. |
| 5 | minor | `metrics.rs:13` vs labels | Touching predicted rallies are merged, but touching labeled rallies are not, so identical inputs score imperfectly. | **Fix**: merge touching spans on both sides. |
| 6 | nit | `report.rs` targets | Targets are compared against values rounded to 4 dp (0.849951 would pass). | **Fix**: compare the raw value and round only for output. |
| 7 | nit | api-contract §4 | The example shows a flat `rally_time_iou`, but the code emits `rally_time{…}` (D-2). | **Fix** the contract example. |
| 8 | nit | CLI single-clip | A scoring error such as duration drift exits 0, but a validation error exits 1. | **Fix**: single-clip mode exits 1 when the clip is an `Error`. |
| 9 | nit | `score_clip` | Labels are validated twice. | Keep: it makes the library safe for other callers. |
