# Code Generation Notes

## Changes

| File | Change | Reqs |
| --- | --- | --- |
| `app/lib/src/features/analysis/presentation/analysis_providers.dart` | New `AnalysisJobKind` and `AnalysisOutcome`. The state tracks the viewed `matchId` separately from the job's `runningMatchId` / `runningTitle`. New `prepare()` (`startArtifacts`, sampling rate 1). `repair()` and `prepare()` share `_runJob`. `lastOutcome` is announced once. `open()` ignores a stale read when the user has moved to another match. | PR-3, PR-5, PR-6, PR-8 |
| `app/lib/src/features/analysis/presentation/analysis_view.dart` | New `_PrepareAction` (explanation plus **Start preparing analysis**) for a match with no files. New `_RunningJob` (progress bar, indeterminate until the engine reports progress; step label; background note; Cancel). New `_BusyElsewhere` for when another video holds the engine. `didUpdateWidget` re-opens when the studio switches videos. Step labels depend on the job kind ("Making…" or "Rebuilding…"). | PR-2, PR-4, PR-6, PR-10 |
| `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart` | The `analyze` stage renders `AnalysisView`, and selecting it no longer starts the job. Removed `_generateArtifacts`/`_preparingAnalysis`. `_startPreparing` is used by Player analysis's Prepare button. `ref.listen` turns an outcome into a snackbar plus a refresh. `_BusySpinner` sits on the feature-rail item and the busy video's row. | PR-1, PR-7, PR-8, PR-9 |

## Verification

- `flutter analyze`: no issues.
- `flutter test test/analysis_screen_test.dart`: 7/7 pass, the existing
  rebuild cases unchanged (PR-10).
- `flutter test` (full): **18 failures, identical to the baseline.** I stashed
  `app/lib` and diffed the failing test names; there are no new failures. They
  are in `library_screen_test` (14), `highlights_screen_test` (2),
  `app_shell_test` (1) and `match_catalog_test` (1). These screens and files
  are ones this change doesn't touch.

## Deviations

- `dart format` also reformatted two untouched files and two dialog blocks.
  Those were reverted to keep the diff to this change.
- `MatchRepository.generateArtifacts` is no longer called from the studio; the
  controller calls the engine directly so it can report progress. The method
  stays on the repository interface: no other `lib/` code calls it, but its
  repository and library tests do. Removing it is left for a separate cleanup.
