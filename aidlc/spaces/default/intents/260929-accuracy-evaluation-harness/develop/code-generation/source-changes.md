# Source Changes

| File | Change | Unit | Reqs |
| --- | --- | --- | --- |
| `core/Cargo.toml` | Register `sportcut-eval` in `[workspace.dependencies]`. | U1 | — |
| `core/crates/eval/Cargo.toml` | New pure crate. Deps: common, rally, vision, serde. Dev-dep: serde_json. | U1 | NFR-2 |
| `core/crates/eval/src/lib.rs` | Module docs, `forbid(unsafe_code)`, re-exports. | U1 | — |
| `core/crates/eval/src/labels.rs` | `ClipLabels`, `LabeledRally`, `Manifest`, `ManifestEntry`, strict serde, `validate()`, plus unit tests. | U1 | FR-1, FR-2 |
| `core/crates/eval/src/predict.rs` | `TrackView`, `Prediction::{Stored, Replay}`, `predicted_count`, `predicted_timeline`. | U2 | FR-3, FR-9 |
| `core/crates/eval/src/metrics.rs` | `rally_spans`, `match_boundaries` (greedy one-to-one), `overlap_counts`, `confidently_wrong_rate`, `rally_time_overlap`, plus unit tests. | U2 | FR-4..FR-6 |
| `core/crates/eval/src/report.rs` | Report types, `score_clip`, `aggregate` (micro-averaged), targets, `render_table`. | U3 | FR-7, FR-10, NFR-1 |
| `core/cli/Cargo.toml` | Add `sportcut-eval` and `sportcut-rally` deps. | U4 | — |
| `core/cli/src/main.rs` | `eval` subcommand: manifest and single-clip modes, `--tolerance-ms`, `--rally-config`, `--json`, `--fail-on-target`, exit code 2. | U4 | FR-8 |
| `core/Cargo.lock` | New crate entry. No new third-party packages. | — | HC-5 |
