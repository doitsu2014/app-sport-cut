# Requirements — Accuracy evaluation harness

Source for every requirement: `analyze/intent-capture/intent-statement.md`
(IS-n = success criterion n) and `requirements-questions.md` (Qn).

## Functional

| ID | Requirement | Pri | Source | Acceptance criteria | Verify |
| --- | --- | --- | --- | --- | --- |
| FR-1 | Define ground-truth label format v1: `schema_version`, `clip_id`, `duration_ms`, `players` (2\|4), `clean` (bool), `rallies[{start_ms,end_ms}]`, optional `notes`. | M | IS-5, Q6 | Parsing rejects: wrong schema version, `players` ∉ {2,4}, rally with `end_ms <= start_ms`, rallies overlapping or unsorted, rally outside `[0,duration_ms]`. Each rejection names the clip and field. | Unit test |
| FR-2 | Define a manifest listing clips `{clip_id, labels, match_dir}`, paths relative to the manifest file. | M | IS-1, Q6 | Duplicate `clip_id` is rejected; missing files are reported per clip and the clip is marked `error`, other clips still score. | Unit + CLI test |
| FR-3 | Score player count per clip: predicted `review.count.count` vs label `players`. | M | IS-1, Q3 | `unknown` or missing `review` = incorrect. Aggregate reports accuracy over all clips and over `clean` clips separately, with n. | Unit test |
| FR-4 | Score rally boundaries with ±tolerance one-to-one matching per boundary kind. | M | IS-1, Q4 | Default tolerance 2000 ms, overridable (`--tolerance-ms`). Hit rate = hits / labeled boundaries. Exactly-at-tolerance counts as hit. Deterministic tie-break. | Unit test |
| FR-5 | Report confidently-wrong rate, missed and spurious rally counts. | M | IS-1, Q5 | Matches Q5 formula; `unknown` spans ignored; 0 labeled and 0 predicted rallies → rate 0, not NaN. | Unit test |
| FR-6 | Report rally-time IoU (labeled rally time ∩ predicted rally time / ∪). | S | IS-1 | Empty ∪ → IoU 1.0. | Unit test |
| FR-7 | Aggregate across clips: micro-averaged boundary hit rate and confidently-wrong rate; pass/fail per roadmap target (≥85%, ≤5%, ≥85% clean count). | M | IS-1 | Aggregate row shows each target and PASS/FAIL. Clips in `error` are excluded and listed. | Unit test |
| FR-8 | `sportcut eval --manifest <path>` and `sportcut eval --labels <json> --match-dir <dir>` subcommands. | M | IS-1 | Prints a fixed-width table by default; `--json` prints the full report. Exit 0 when scoring ran (even if targets fail); exit 1 on usage/parse errors. `--fail-on-target` exits 3 (clap reserves 2 for usage errors) when any target fails. | CLI test |
| FR-9 | Optional replay: `--rally-config <json>` re-runs `sportcut_rally::segment` on the stored `SegmentationInput` and scores the replayed timeline. | S | Q2 | Invalid config is rejected via `SegmentationConfig::validate`. Report records which config was scored (stored vs replay). | Unit + CLI test |
| FR-10 | Duration mismatch between label and artifact > 1000 ms is a per-clip error. | M | FR-1 | Clip marked `error` with both durations in the message. | Unit test |

## Non-functional

| ID | Requirement | Pri | Source | Acceptance criteria | Verify |
| --- | --- | --- | --- | --- | --- |
| NFR-1 | Deterministic output. | M | IS-2 | Two runs on identical inputs give byte-identical stdout for table and JSON (clips sorted by `clip_id`, fixed float formatting). | CLI test |
| NFR-2 | Offline, no inference, no network. | M | IS-3, constraints | `sportcut-eval` depends only on `common`, `vision`, `rally`, `serde`; no model or ffmpeg needed. | Review of `Cargo.toml` |
| NFR-3 | Scoring a 10-clip manifest of 60-minute recordings completes in < 5 s on the dev Mac (replay included). | C | intent (usability) | Measured once and recorded in verification doc. | Manual |
| NFR-4 | Passes `tools/verify-engine.sh` (fmt, clippy `-D warnings`, tests). | M | team tooling | Script exits 0. | CI/local |

## Constraints

| ID | Constraint | Source |
| --- | --- | --- |
| C-1 | No footage, frames, or real match artifacts committed; only a synthetic fixture (hand-written JSON) under `core/crates/eval/tests/fixtures/`. | intent constraints |
| C-2 | No schema changes to `player_tracks.json` or `rally_suggestions.json`. | intent constraints |
| C-3 | Pure scorer crate; the CLI owns file I/O. `forbid(unsafe_code)`, workspace deps and lints. | Q7, `core/AGENTS.md` |
| C-4 | Tests limited to the new crate and the new CLI subcommand. | Q8 |

## Assumptions

| ID | Assumption | Status |
| --- | --- | --- |
| A-1 | Stored artifacts suffice for scoring. | Confirmed (Q1) |
| A-2 | The owner can label 5–10 clips by hand; first real run uses `c1`. | Open — owner action, not blocking code |

## Traceability

| Intent criterion | Requirements |
| --- | --- |
| IS-1 metrics via one command | FR-2..FR-8 |
| IS-2 deterministic | NFR-1 |
| IS-3 no inference re-run | FR-3, FR-4, NFR-2 (FR-9 replays segmentation only) |
| IS-4 synthetic fixture in `cargo test` | C-1, FR-1..FR-7 tests |
| IS-5 hand-editable label format | FR-1 |

No orphan requirements. Every requirement has a testable acceptance criterion.
