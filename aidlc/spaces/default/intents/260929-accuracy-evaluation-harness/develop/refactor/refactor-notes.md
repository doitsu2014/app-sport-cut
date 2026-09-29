# Refactor Notes

These are the review-record findings, applied.

| # | Change | Files |
| --- | --- | --- |
| 2 | `match_boundaries` now uses a sorted two-pointer maximum matching: each label takes the earliest unused prediction in its window. The reviewer's counter-example `[0,1000]` vs `[600,1500]` at tol 600 now gives 2 and is a unit test. DD-4 amended. | `metrics.rs`, `design-decisions.md` |
| 3 | Window bounds use `saturating_sub` / `saturating_add`. A test covers `i64::MAX` tolerance. | `metrics.rs` |
| 4 | New `is_sorted_disjoint`. `score_clip` returns an `Error` clip when the predicted spans are unsorted, empty or overlapping. | `metrics.rs`, `report.rs` |
| 5 | New `merge_touching`, applied to labels and predictions alike. `rally_spans` uses it. | `metrics.rs`, `report.rs` |
| 6 | Targets are judged on raw ratios (`raw_ratio`, unrounded confidently-wrong); the report shows rounded values. | `report.rs` |
| 7 | Contract §4 example shows `rally_time{intersection_ms, union_ms, iou}` and aggregate `rally_time_iou`. | `api-contract.md` |
| 8 | Single-clip mode exits 1 when the clip scores as `Error`. | `cli/src/main.rs` |

Behaviour is otherwise unchanged. No change to the public types.

Verification: `cargo fmt --all`; `cargo clippy -p sportcut-eval -p sportcut-cli --all-targets -- -D warnings` (clean); `cargo test -p sportcut-eval` (11 passed).
