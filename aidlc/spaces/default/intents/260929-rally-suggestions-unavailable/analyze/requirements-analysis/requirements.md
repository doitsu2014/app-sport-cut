# Requirements — Rally suggestions on a not-yet-analysed match

| ID | Requirement | Type | Pri | Acceptance criteria | Verify |
| --- | --- | --- | --- | --- | --- |
| BR-1 | `match_rally_suggestions` returns `Ok(None)` when the match directory has no `manifest.json`. | functional | M | An empty temp dir gives `Ok(None)`. | Regression test |
| BR-2 | `match_rally_suggestions` returns `Ok(None)` when the manifest has no tracks entry. | functional | M | A manifest written without tracks gives `Ok(None)`. | Regression test |
| BR-3 | `match_player_tracks` returns `Ok(None)` for a directory without a manifest. | functional | M | An empty temp dir gives `Ok(None)`. | Regression test |
| BR-4 | `start_rally_segmentation` still refuses with "player tracks are unavailable…" for a match without a manifest. | functional | M | The error message contains "player tracks are unavailable". | Regression test |
| BR-5 | An existing but unreadable manifest is still an error. | constraint | M | `manifest.json` containing `not json` makes `match_rally_suggestions` return `Err`. | Regression test |
| BR-6 | No change to Dart code, the bridge surface, or artifact schemas. | constraint | M | `git diff app/` is empty; no DTO or signature change. | Review |
| BR-7 | `tools/verify-engine.sh` passes. | NFR | M | exit 0 | Local |

Traceability: BR-1 and BR-3 come from intent SC-1 (missing manifest); BR-2
from SC-1 (no tracks); BR-4 from SC-2; BR-5 from SC-3; BR-6 and BR-7 from the
out-of-scope list and team tooling.

Regression tests don't need ffmpeg, so they run everywhere. This bugfix
request counts as asking for them, given the `core/AGENTS.md`
"tests only when asked" rule.
