# Intent Statement — Accuracy evaluation harness

## Problem

The roadmap sets accuracy targets for player count (Phase 0) and rally/rest
boundaries (Phase 2), but none are measured. `docs/verification/rally-rest-segmentation.md`
records that the segmentation thresholds were tuned on a single clip (`c1`)
from the motion distribution, and that the ±2 s boundary target is
"unverified". Nothing measures player-count accuracy at all. Any change to
vision or rally code is judged by eye.

## Users

Developers and coding agents who change `core/crates/vision` or
`core/crates/rally`, and later whoever tunes highlight weights (Phase 4).

## Success criteria

1. A single offline CLI command takes a labeled clip set and prints per-clip
   and aggregate metrics:
   - player-count accuracy (target ≥85% of clips flagged clean);
   - boundary hit rate: share of labeled rally boundaries matched by a
     predicted boundary within ±2 s (target ≥85%);
   - confidently-wrong rate (target ≤5%);
   - plus rally-time IoU, and counts of missed and spurious rallies.
2. The same inputs produce byte-identical output (deterministic, sorted).
3. Scoring can run from existing artifacts (`player_tracks.json`,
   `rally_suggestions.json`) without re-running inference.
4. A small synthetic fixture with committed labels exercises the scorer in
   `cargo test`; no real footage is committed.
5. A written label format lets a person label a clip with a text editor.

## In scope

- A versioned ground-truth label format (JSON).
- A pure scoring module (no I/O beyond reading artifacts and labels).
- A `sportcut` CLI subcommand that scores one clip or a manifest of clips.
- Human-readable table plus machine-readable JSON output.
- A verification record with the first real numbers from `c1` once labeled.

## Out of scope

Flutter UI, a labeling tool, automatic threshold search, new models,
shuttle/shot detection, running on real footage in CI, committing footage.

## Constraints

- Offline-only and macOS-only principles unchanged; footage never leaves the
  machine and never enters git.
- Reuse existing engine types and artifacts; no schema change to shipped
  artifacts.
- Project's own `cargo` build/lint/test commands are authoritative.

## Assumptions

- `player_tracks.json` and `rally_suggestions.json` carry enough information
  (per-bin classification, timestamps, track counts) to score without
  re-running the pipeline. To be confirmed in requirements.
- Labeling 5–10 clips by hand is feasible for the owner.
