## 1. Shared playback ownership

- [x] 1.1 Add an optional injected `PlaybackController? controller` to `CalibrationScreen`, `PlayerTrackingScreen`, `ScoreScreen`, and `PlayerScreen`, falling back to `playbackControllerFactoryProvider` when absent
- [x] 1.2 Add a studio-owned playback controller for the selected video, disposed when the selected video changes

## 2. Preview-native feature views (Phase 1)

- [x] 2.1 Extract `PlayerScreen`'s body into an embeddable `PlayerView` that renders transport controls over a passed-in `PlaybackController`
- [x] 2.2 Extract `CalibrationScreen`'s body into an embeddable `CalibrationView` that renders corner handles over a passed-in `PlaybackController`

## 3. Studio shell

- [x] 3.1 Add a studio screen (`WorkspaceStudioScreen`) with a three-pane layout: left video rail, center pane, right feature rail
- [x] 3.2 Left rail lists the workspace's videos and drives the selected video
- [x] 3.3 Center pane renders the selected feature's view over the shared preview
- [x] 3.4 Right rail lists the features with resolved done/ready/blocked state for the selected video, highlighting the next step (reuse `resolveStageStates`)

## 4. Feature selection and fallback

- [x] 4.1 Selecting a feature shows it in the center pane when embedded; otherwise it opens the feature's existing full-screen route
- [x] 4.2 Selecting a blocked feature shows the missing prerequisite instead of navigating
- [x] 4.3 Open a workspace straight into the studio; retire the video-card list and per-video `PipelineToolbar`

## 5. Per-match feature state

- [x] 5.1 Key in-progress feature state (e.g. calibration position, score selections) by `matchId` in Riverpod so switching videos preserves it

## 6. Phase 2 — Track and Score

- [x] 6.1 Extract `PlayerTrackingScreen`'s body into an embeddable view over the shared preview
- [x] 6.2 Extract `ScoreScreen`'s body into an embeddable view with its panel docked beside the shared preview

## 7. Phase 3 — Highlights, Analyze, Export

- [x] 7.1 Extract `HighlightsScreen`'s body into an embeddable view using the shared preview for trimming
- [x] 7.2 Extract `AnalysisScreen`'s body into an embeddable panel view
- [x] 7.3 Extract `ExportScreen`'s body into an embeddable panel view

## 8. Retire feature routes

- [x] 8.1 Keep the full-screen feature routes as standalone surfaces and test seams (the studio is the primary surface); do not delete the screen wrappers, because existing widget tests exercise them

## 9. Verify

- [x] 9.1 `flutter analyze` clean and the studio runs with Play and Calibrate sharing one preview

## 10. Fix: surface the prepare-analysis stage

The `workspace` delta already requires prepare analysis to be presented in the
feature rail, but the rail omitted it, so the stage that gates player analysis
was invisible and unreachable.

- [x] 10.1 List `Prepare analysis` in the right feature rail so the stage that gates player analysis is visible and targetable
- [x] 10.2 Prepare the artifacts when it is selected (guarded against concurrent runs) and name the missing prerequisite when a later stage is blocked
- [x] 10.3 `flutter analyze` clean and Player analysis reachable after marking the court

## 11. Fix: refresh the stage rail after an action

The rail read the manifest once and was not invalidated when an in-center action
(analyze players, render) wrote a new artifact, so done/ready states stayed stale
and the later stages remained greyed out after the work had finished.

- [x] 11.1 Refresh the studio stage facts when the player-analysis job publishes tracks
- [x] 11.2 Refresh when a rendered reel is produced, and when the first clip is kept or dropped
- [x] 11.3 `flutter analyze` clean
