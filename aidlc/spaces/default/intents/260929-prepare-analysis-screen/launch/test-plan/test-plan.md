# Test Plan

These are widget tests in `app/test/analysis_screen_test.dart`. They use
`FakeMediaEngine` and need no engine binary.

| ID | Req | Case |
| --- | --- | --- |
| T-1 | PR-2 | With an empty manifest, the view shows an enabled **Start preparing analysis** button and has made no `startArtifacts` call. |
| T-2 | PR-3, PR-8 | Tapping Start calls `startArtifacts` once with the match id and dir. When the job completes, the manifest is read again and the table lists the new files. |
| T-3 | PR-4 | While the job reports `running` / `proxy`, the view shows "Making the proxy…", a `LinearProgressIndicator`, the background note and **Cancel**. |
| T-4 | PR-5 | Cancel calls `jobCancel` once, and the view returns to the Start button. |
| T-5 | PR-6 | While match A's job runs, the view for match B shows "Another video is being prepared (A)" and a disabled Start button. |
| T-6 | PR-10 | The existing 7 rebuild tests still pass. |

PR-1, PR-7 and PR-9 are the studio wiring (`workspace_studio_screen.dart`,
which has no widget test today). They are checked by code review and a manual
run of the app. The PR-8 snackbar is checked the same way.
