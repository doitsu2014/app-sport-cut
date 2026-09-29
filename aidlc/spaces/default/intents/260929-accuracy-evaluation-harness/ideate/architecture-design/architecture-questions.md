# Architecture Questions

Mode: yolo — recommended answers auto-selected.

### Q1: Where does scoring live?

A. New pure library crate `core/crates/eval` (`sportcut-eval`); `cli` does all
   file I/O and formatting. *(Recommended)*
B. Module in `sportcut-rally` plus one in `sportcut-vision`.
C. A standalone script outside the workspace.

[Answer]: A (auto-selected). B mixes test tooling into production crates and
splits one report across two crates. C loses type sharing with the engine.

### Q2: How is `player_tracks.json` read?

A. Minimal serde view in `sportcut-eval` (`TrackView{schema_version, input,
   review}`), unknown fields ignored. *(Recommended)*
B. Depend on `sportcut-api` for `TrackArtifact`.

[Answer]: A (auto-selected). B pulls `api` (export, jobs, bridge glue) into
the CLI. The view uses the real `SegmentationInput`/`TrackingResult` types, so
the shape can't drift silently.

### Q3: Who owns report formatting?

A. `sportcut-eval` returns a serde `EvalReport`; `sportcut-eval::render_table`
   produces the text table so formatting is unit-testable and deterministic;
   the CLI only prints. *(Recommended)*
B. CLI formats the table.

[Answer]: A (auto-selected)
