# AGENTS.md — native engine (`core/`)

Applies to everything under `core/`. The repository-root `AGENTS.md` applies
too; this file adds engine-specific detail. If the two disagree, this file wins
inside `core/`.

## Ground rules

- The engine builds, lints, and tests **without** the Flutter/Xcode client
  toolchain. It must stay that way: never add a dependency that needs Flutter,
  Xcode, or a JDK to a crate reachable from the pipeline.
- `unsafe` is denied workspace-wide. The only exception is the generated FFI
  module in `sportcut-api`, which is not committed.
- `clippy::dbg_macro` and `clippy::todo` are denied. Warnings fail the lint run.
- Format with `core/rustfmt.toml`: 100 columns, Unix newlines.

## Commands

```bash
cd core
cargo fmt --all                                  # format
cargo clippy --workspace --all-targets -- -D warnings
cargo build --workspace                          # fastest correctness check

cd .. && tools/verify-engine.sh                  # fmt --check + clippy + test
```

## Crate layout

| Crate | Path | Responsibility |
| --- | --- | --- |
| `sportcut-common` | `crates/common` | Shared error type, progress and cancellation primitives. |
| `sportcut-media` | `crates/media` | Probe, proxy generation, analysis audio, frame sampling behind `MediaToolchain`. |
| `sportcut-storage` | `crates/storage` | Match artifact directory, manifest, checkpoint persistence. |
| `sportcut-jobs` | `crates/jobs` | Job lifecycle, stage-labelled progress, cancellation, resume, concurrency. |
| `sportcut-export` | `crates/export` | The edit decision list and the highlight-video renderer. |
| `sportcut-api` | `crates/api` | FFI facade: DTOs, job handles — the only surface across the bridge. |
| `sportcut-court`, `-vision`, `-rally`, `-score`, `-highlight` | `crates/*` | Pipeline-stage placeholders that later phases fill in. |
| `sportcut-cli` | `cli` | Headless harness for developing and benchmarking the pipeline. |

Put new capability in the crate that owns the stage instead of widening an
unrelated one. Only `sportcut-api` is exposed across the language boundary.

## Storage contract

The engine owns artifact files; the Flutter app owns the SQLite catalog. Inside
a match directory the engine writes `manifest.json`, `checkpoints.json`, and the
`proxy/`, `audio/`, `frames/`, `calibration/`, `tracks/`, and `export/`
subdirectories. Keep that layout stable, and never copy or modify the original
recording.

## Working agreement

Implement first. Do not add or run tests unless the user explicitly asks; verify
with `cargo build` or
`cargo clippy --workspace --all-targets -- -D warnings`. Run
`tools/verify-engine.sh` only when the user asks to verify, close, or archive an
OpenSpec change.
