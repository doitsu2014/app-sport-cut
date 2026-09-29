# Requirements — Prepare analysis screen

| ID | Requirement | Type | Pri | Acceptance criteria | Verify |
| --- | --- | --- | --- | --- | --- |
| PR-1 | Selecting **Prepare analysis** shows `AnalysisView` for the selected video in the centre pane and starts no job. | F | M | After tapping the rail item: `startArtifacts` call count is 0 and the "Start preparing analysis" button is visible. | Widget test |
| PR-2 | With no analysis files, the view shows an enabled **Start preparing analysis** button. | F | M | Button present and enabled when the manifest is empty. | Widget test |
| PR-3 | Pressing Start calls `startArtifacts(matchId, videoPath, matchDir, samplingRate 1)` and follows the job. | F | M | The fake engine records one call with the match's ids and paths. | Widget test |
| PR-4 | While running: `LinearProgressIndicator`, a step label per engine stage (`probe`, `proxy`, `audio`, `frames`), the note "keeps running in the background", and an enabled **Cancel**. | F | M | Shown while the fake job reports `running`, stage `proxy` → "Making the proxy…". | Widget test |
| PR-5 | Cancel calls `jobCancel`, and the view returns to the Start button. | F | M | `jobCancelCalls == 1`. | Widget test |
| PR-6 | The job state lives in the app-wide `AnalysisController`, keyed by match id. Leaving and re-entering the view, or opening another video, neither restarts nor loses it. Another video's view shows the job as busy with Start disabled. | F | M | View for match B while match A runs shows "Another video is being prepared" and Start disabled. | Widget test |
| PR-7 | Running indicators: the feature-rail **Prepare analysis** item and the running video's row in the video rail show a `CircularProgressIndicator`. | F | M | Visible in the studio while running. | Manual / code review |
| PR-8 | When the job completes the studio refreshes stage facts and shows a snackbar: "Analysis files ready for <title>" on success, or the engine's reason on failure. The file table re-reads the manifest. | F | M | Artifact table updates after completion. | Widget test (table) + manual (snackbar) |
| PR-9 | Player analysis's **Prepare analysis** action switches to the Prepare screen and starts the job. | F | S | `onPrepare` selects the stage and calls `prepare`. | Code review |
| PR-10 | Rebuild-missing still works: existing `analysis_screen_test.dart` cases pass unchanged. | F | M | Existing tests green. | Widget test |
| PR-11 | `flutter analyze` is clean and `flutter test` passes. | NFR | M | exit 0 | Local |

Traceability: SC-1 → PR-1/PR-2; SC-2 → PR-3/PR-4/PR-5; SC-3 → PR-6/PR-7;
SC-4 → PR-8; SC-5 → PR-9; SC-6 → PR-10.
