# Intent Statement — Rally suggestions error on a not-yet-analysed match

## Problem

Opening **Review** for a freshly imported match shows:

> Rally suggestions are unavailable: SportcutEngineException: file system error
> at …/SportcutMatches/match-1790673937629414-1/manifest.json: No such file or
> directory (os error 2)

It reproduces on the owner's machine. The catalog row exists and
`SportcutRecordings/<id>/IMG_1194.mov` was copied at 16:25, but
`SportcutMatches/` is empty.

## Root cause

- `MatchRepository.importVideo` only takes custody of the recording and writes
  the catalog row. The engine's match directory and its `manifest.json` are
  created later by `generateArtifacts` ("Prepare").
- "Imported but not analysed" is therefore a normal state.
- The Review panel still calls `match_rally_suggestions` on it. That goes
  through `load_track_input` to `read_track_artifact`, which calls
  `ArtifactManifest::load` and fails with an I/O error when the file is absent.
- Neighbouring readers treat a missing manifest as "nothing yet":
  `load_rally_suggestions` (`storage/rally_suggestions.rs:223`) and the
  calibration reader (`storage/calibration.rs:79`).
- Even with a manifest, a match without player tracks makes
  `match_rally_suggestions` return an error. The `Option` result means it
  should return `None`.

## Users

Anyone who imports a recording and opens Review before running Prepare or
player tracking.

## Success criteria

1. For a match directory with no manifest, or a manifest without tracks,
   `match_rally_suggestions` returns `Ok(None)` and `match_player_tracks`
   returns `Ok(None)`. The panel shows "Manual marking is available" with no
   error text.
2. `start_rally_segmentation` on such a match still fails with the actionable
   "player tracks are unavailable; run player tracking before rally analysis".
3. A corrupt or unreadable manifest that *does* exist still surfaces as an
   error.

## Out of scope

Auto-running Prepare at import. Changing the app's messages. Other facade
functions that already require an imported match (regenerate, rally-review
save).
