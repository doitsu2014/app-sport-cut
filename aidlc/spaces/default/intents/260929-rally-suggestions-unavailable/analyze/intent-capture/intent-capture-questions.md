# Intent Capture Questions

Mode: yolo — recommended answers auto-selected.

### Q1: Fix in the engine or the app?

A. Engine. A missing manifest means "no tracks yet", which matches the other
   readers. Every client benefits, and `match_player_tracks` is fixed as
   well. *(Recommended)*
B. App: catch the error string in Dart.
C. App: skip the suggestion load until the manifest exists.

[Answer]: A (auto-selected). Matching on error strings (B) is brittle. C
duplicates engine knowledge in the client.

### Q2: Should "no tracks" also stop being an error for suggestions?

A. Yes. `match_rally_suggestions` returns `Option`, and "no tracks" means
   "no suggestions". The actionable error stays on `start_rally_segmentation`,
   where the user asked for analysis. *(Recommended)*
B. No, only fix the missing manifest.

[Answer]: A (auto-selected). Otherwise the next state (manifest but no tracks)
shows the same kind of raw error in the panel.
