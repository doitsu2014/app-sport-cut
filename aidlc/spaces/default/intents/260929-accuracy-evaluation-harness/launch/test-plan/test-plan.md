# Test Plan

Scope: `sportcut-eval` plus the `eval` CLI path (C-4). No real footage. All
tests are offline and need no ffmpeg or model.

| ID | Level | Covers | Case | Status |
| --- | --- | --- | --- | --- |
| T-1 | unit `labels` | FR-1 | Valid touching rallies accepted; each invalid field rejected by name; unknown field rejected | exists |
| T-2 | unit `labels` | FR-2 | Manifest duplicate / empty rejected | exists |
| T-3 | unit `metrics` | FR-4 | Tolerance inclusive; one-to-one; maximum matching counter-example; `i64::MAX` tolerance | exists |
| T-4 | unit `metrics` | FR-5, FR-6 | Missed/spurious with touching≠overlap; empty sets; IoU partial overlaps | exists |
| T-5 | unit `metrics` | review #4, #5 | `is_sorted_disjoint`, `merge_touching` | exists |
| T-6 | integration `tests/fixture.rs` | FR-3..FR-7 | Synthetic `TrackView` (four players) + stored timeline vs committed `synthetic.labels.json`: exact hits, missed, spurious, IoU, player correct | new |
| T-7 | integration | FR-3 | `review: None` → predicted `null`, incorrect; `unknown` → incorrect | new |
| T-8 | integration | FR-10, review #4 | Duration drift > 1 s → error clip; overlapping stored timeline → error clip | new |
| T-9 | integration | FR-7 | `aggregate` mixing scored, error, clean and non-clean: micro-averaged sums, clean-only count accuracy, `error_clips` listed, clips sorted | new |
| T-10 | integration | FR-7, review #6 | Target statuses: pass, fail, no_data; `any_target_failed` false for no_data only, true with zero scored clips | new |
| T-11 | integration | api-contract §4 | JSON shape: `status` tag flattened, `prediction_source` `"stored"` / `{"replay":…}`, rates rounded | new |
| T-12 | integration | NFR-1 | Two `aggregate` + `serde_json` + `render_table` runs are byte-identical | new |
| T-13 | integration | FR-9 | Replay with an invalid config → error clip; replay on synthetic positions produces a timeline | new |
| T-14 | CLI smoke (manual, recorded) | FR-8 | `--help`; missing source → clap error; manifest with one missing clip → exit 0 with error row; `--fail-on-target` → exit 2 | new |

Exit criteria: `tools/verify-engine.sh` exits 0, and T-14 is recorded in
release validation.
