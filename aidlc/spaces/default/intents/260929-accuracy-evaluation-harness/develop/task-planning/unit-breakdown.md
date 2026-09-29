# Unit Breakdown

| Unit | Scope | Reqs | Files | Depends | Done when |
| --- | --- | --- | --- | --- | --- |
| U1 | Crate skeleton; label + manifest types and validation | FR-1, FR-2, FR-10 | `core/Cargo.toml`, `core/crates/eval/{Cargo.toml,src/lib.rs,src/labels.rs}` | — | `cargo build -p sportcut-eval` |
| U2 | TrackView, prediction, metrics | FR-3..FR-6, FR-9 | `src/predict.rs`, `src/metrics.rs` | U1 | builds; unit tests in U5 pass |
| U3 | Clip report, aggregate, targets, table | FR-7, NFR-1 | `src/report.rs` | U2 | builds |
| U4 | CLI `eval` subcommand | FR-8 | `core/cli/{Cargo.toml,src/main.rs}` | U3 | `sportcut eval --help` shows the contract |
| U5 | Unit tests + synthetic fixture | all FR, NFR-1 | `src/*` `#[cfg(test)]`, `crates/eval/tests/fixture.rs`, `crates/eval/tests/fixtures/*` | U3 | `cargo test -p sportcut-eval` green |
| U6 | Docs | IS-5 | `docs/verification/accuracy-evaluation.md`, `docs/features-roadmap.md`, `core/README.md` | U4 | label guide + run instructions present |

Riskiest first: U2 (metric semantics). U4 also exercises clap
`requires`/`conflicts_with` with `Option<PathBuf>`.
