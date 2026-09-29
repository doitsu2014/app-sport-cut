# Source Changes

| File | Change | Reqs |
| --- | --- | --- |
| `core/crates/api/src/facade.rs` `read_track_artifact` | Returns `Ok(None)` when `manifest.json` is absent. An existing manifest is loaded as before, so a corrupt one is still an error. | BR-1, BR-3, BR-5 |
| `core/crates/api/src/facade.rs` `find_track_input` (new) | Option-returning core of `load_track_input`. | BR-2 |
| `core/crates/api/src/facade.rs` `load_track_input` | Now wraps `find_track_input`, with the same actionable error as before (used by the segmentation job). | BR-4 |
| `core/crates/api/src/facade.rs` `match_rally_suggestions` | Uses `find_track_input` and returns `Ok(None)` when there are no tracks. The doc comment explains why. | BR-1, BR-2 |

No Dart, bridge signature or DTO change (BR-6). `start_rally_segmentation`
keeps its own `ok_or_else` "player tracks are unavailable…" error. It now
reaches that error for a manifest-less match too, instead of the raw I/O error.
