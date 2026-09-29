# Implementation Plan

Branch: `feat/accuracy-evaluation-harness` (short-lived, trunk-based).

1. **U1** Register `sportcut-eval` in the workspace deps. Create the crate with
   `labels.rs`, following technical-spec §labels.
2. **U2** Write `predict.rs` (TrackView, predicted count and timeline, replay)
   and `metrics.rs` (rally spans, boundary matching, overlap counts, IoU).
3. **U3** Write `report.rs`: the report types and the `Rate` serialiser, plus
   `score_clip`, `aggregate`, targets and `render_table`.
4. **U4** Add the CLI `Eval` args and handler (manifest and single-clip modes,
   exit codes 0/1/2).
5. **U5** Unit tests next to each module. The integration test
   `tests/fixture.rs` builds a synthetic `TrackView` and timeline in code, plus
   a committed `tests/fixtures/synthetic.labels.json`. It asserts exact counts
   and that the JSON output is byte-identical across two runs.
6. **U6** Write `docs/verification/accuracy-evaluation.md`, link it from the
   roadmap's Phase 0/2 rows, and add a CLI usage line to `core/README.md`.

Verification: `tools/verify-engine.sh` (fmt, clippy `-D warnings`, workspace
tests).

Commit per unit group, with a message that explains why before what.
