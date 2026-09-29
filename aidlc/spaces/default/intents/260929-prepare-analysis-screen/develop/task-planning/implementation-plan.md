# Implementation Plan

1. **U1 `analysis_providers.dart`**
   - Add `AnalysisJobKind { prepare, rebuild }` to `AnalysisState`.
   - Add `runningMatchId` / `runningTitle` for the job and `matchId` for the
     manifest being shown.
   - Add `prepare(match)`, which calls `startArtifacts`.
   - Factor a shared `_runJob` out of `repair`.
   - Re-read the manifest after a job only if the view still shows that match.
   - Add `lastOutcome` so the studio can announce a completion exactly once.
2. **U2 `analysis_view.dart`**
   - Primary action: **Start preparing analysis** when there are no files;
     otherwise the rebuild button.
   - Running block: progress bar, a step label per kind, the background note,
     and Cancel.
   - A busy note when another video's job is running.
   - Match-scoped: re-open the manifest when `widget.match` changes
     (`didUpdateWidget`).
3. **U3 `workspace_studio_screen.dart`**
   - The `analyze` stage renders `AnalysisView`.
   - Selecting it no longer starts the job.
   - Remove `_generateArtifacts` / `_preparingAnalysis`.
   - Player analysis's `onPrepare` switches to the stage and calls `prepare`.
   - `ref.listen` on the controller's outcome → snackbar + `_refresh()`.
   - Spinners on the feature-rail item and the video-rail row.
4. **U4 tests** in `analysis_screen_test.dart`: Start button, the start call,
   the running block, cancel, and the other-video busy state.

Units: U1 → U2 → U3 → U4, all in one short-lived branch.
