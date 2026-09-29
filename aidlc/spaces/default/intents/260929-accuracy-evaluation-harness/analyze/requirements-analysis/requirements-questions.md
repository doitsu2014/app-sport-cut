# Requirements Questions

Intent: `260929-accuracy-evaluation-harness`
Mode: yolo — recommended answers auto-selected and recorded below.

### Q1: What does the scorer read as prediction input?

A. Existing match-directory artifacts: `tracks/player_tracks.json`
   (`review.count` = recording-level `ObservedCount`; `input` =
   `SegmentationInput`) and `tracks/rally_suggestions.json` (`timeline` =
   full rally/rest/unknown partition, `inputs.config`). No inference re-run.
   *(Recommended)*
B. Raw video — run detection, tracking, segmentation inside the harness.
X. Other

[Answer]: A (auto-selected). Verified: both types are serde and carry these
fields (`crates/api/src/track_artifact.rs:107`,
`crates/storage/src/rally_suggestions.rs:70`).

### Q2: Should the harness also replay segmentation with different thresholds?

A. Yes, optionally: `--rally-config <json>` re-runs `sportcut_rally::segment`
   on the stored `input` and scores that instead of the stored timeline. This
   is what makes the harness useful for tuning; it is pure and fast.
   *(Recommended)*
B. No, score stored suggestions only.

[Answer]: A (auto-selected)

### Q3: What granularity is player count scored at?

A. Per recording, matching the engine: label `players: 2 | 4`, compared with
   `review.count.count`. `unknown` counts as wrong. *(Recommended)*
B. Per frame.

[Answer]: A (auto-selected). The engine has no per-frame count concept.

### Q4: How is a boundary "hit" defined?

A. Each labeled rally contributes a start and an end boundary. A labeled
   boundary is hit if a predicted boundary of the same kind (start/end) lies
   within ±tolerance (default 2000 ms), with one-to-one greedy matching by
   smallest distance, ties broken by earlier time. *(Recommended)*

[Answer]: A (auto-selected)

### Q5: How is "confidently wrong" defined?

A. Rate = (spurious predicted rallies + missed labeled rallies) / (predicted
   rallies + labeled rallies). Spurious: predicted rally overlapping no labeled
   rally. Missed: labeled rally overlapping no predicted rally. `unknown` spans
   are never "confident", so they count toward neither. *(Recommended)*

[Answer]: A (auto-selected)

### Q6: Label format and where labels live?

A. One JSON per clip, `schema_version: 1`, fields `clip_id`, `duration_ms`,
   `players`, `clean`, `rallies: [{start_ms, end_ms}]`, optional `notes`. A
   manifest JSON lists `{clip_id, labels, match_dir}` entries with paths
   relative to the manifest. Real labels live beside footage outside the repo;
   only a synthetic fixture is committed. *(Recommended)*

[Answer]: A (auto-selected)

### Q7: Where does the code live?

A. New pure crate `crates/eval` (`sportcut-eval`) depending on `common`,
   `vision`, `rally`; the CLI owns file I/O and gains an `eval` subcommand.
   *(Recommended)*
B. Inside `crates/rally`.

[Answer]: A (auto-selected). Scoring spans vision and rally, so it belongs to
neither; `core/AGENTS.md` names the CLI as the headless benchmarking harness.

### Q8: Tests, given `core/AGENTS.md` "no tests unless the user asks"?

A. The user asked for an accuracy harness; unit tests of the scorer and one
   synthetic fixture are part of that request. No other crates gain tests.
   *(Recommended)*

[Answer]: A (auto-selected)

## Contradiction check

- Intent assumption "artifacts suffice" — confirmed (Q1).
- No conflict with offline-only / macOS-only / no-footage-in-git constraints.
