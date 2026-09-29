# Code Generation Notes

Branch: `feat/accuracy-evaluation-harness`. Nothing has been committed yet; the
changes wait for human review, per org memory.

## Verification run

Commands were run from `core/`:

```text
cargo fmt --all                                                        ok
cargo clippy -p sportcut-eval -p sportcut-cli --all-targets -- -D warnings   ok (0 warnings)
cargo test -p sportcut-eval                                            10 passed, 0 failed
cargo run -q -p sportcut-cli -- eval --help                            shows the contract flags
```

The full `tools/verify-engine.sh` runs in the test-generation / release-validation
stages.

## Deviations from the technical spec

| # | Spec | Implemented | Why |
| --- | --- | --- | --- |
| D-1 | `Rate(Option<f64>)` newtype with a rounding serialiser. | Rates are plain `f64`/`Option<f64>` fields, rounded to 4 dp when the struct is built (`ratio`, `round`). | Simpler. Same deterministic output. |
| D-2 | `rally_time_iou(..) -> f64`. | `rally_time_overlap(..) -> (intersection_ms, union_ms)`. The report carries `rally_time {intersection_ms, union_ms, iou}`. | Aggregate IoU has to be micro-averaged from raw times, not by averaging per-clip ratios (DD-5). |
| D-3 | Aggregate `rally_time_iou` not in the contract. | Added `aggregate.rally_time_iou`. | Consistent with the per-clip field. |
| D-4 | clap `conflicts_with` / `requires`. | `ArgGroup` "source" (required, exactly one of `--manifest` / `--labels`), plus `requires` between `--labels` and `--match-dir`. | clap then rejects both a missing source and a double source. |
| D-5 | CLI depends on `sportcut-vision`. | Not needed. `TrackView` is exposed by `sportcut-eval`. | Fewer direct deps. |
| D-6 | — | Single-clip mode validates labels before scoring and exits 1 on invalid labels. Manifest mode turns the same error into an `error` clip. | Matches the FR-8 / DD-3 split. |

`rally_suggestions.json` is read through serde directly, not through
`load_rally_suggestions`. That function needs the expected `SuggestionInputs`
fingerprint, and the harness has no reason to recompute it.
