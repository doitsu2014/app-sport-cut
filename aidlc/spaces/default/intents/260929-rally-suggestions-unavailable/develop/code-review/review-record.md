# Review Record

The diff (`core/crates/api/src/facade.rs`, +31/−6) was read in full.

**Verdict: no blockers.**

## Call sites of `read_track_artifact` after the change

| Caller | Missing manifest, before | Missing manifest, after |
| --- | --- | --- |
| `match_rally_suggestions` | raw I/O error | `Ok(None)` ✅ |
| `match_player_tracks` | raw I/O error | `Ok(None)` ✅ |
| `start_rally_segmentation` | raw I/O error | "player tracks are unavailable; run player tracking before rally analysis" ✅ |
| `run_rally_segmentation` via `load_track_input` | raw I/O error | the same actionable error ✅ |

## Checks

- A corrupt manifest still goes through `ArtifactManifest::load` and returns
  `Err` (BR-5).
- The `is_file` check followed by a load is a benign race. If the file
  disappears in between, the old I/O error comes back and nothing worse
  happens. This matches `load_rally_suggestions` and `calibration.rs`.
- Tracks that exist but have calibration problems still error on purpose.
  That state needs the user to act and stays visible.
- There is no public API or DTO change, and the Dart contract is unchanged.

## Findings

| # | Sev | Finding | Disposition |
| --- | --- | --- | --- |
| 1 | nit | Other facade readers (`start_regenerate_match_media`, rally-review save at :675) also fail on a missing manifest. | Keep. Those actions require an imported match, so an error there is correct. Out of scope. |
