# Test Suite

New tests in `app/test/analysis_screen_test.dart`:

| Test | Plan |
| --- | --- |
| `a match with no files offers to start preparing` | T-1 |
| `starting preparation runs the job and lists the new files` | T-2 |
| `a running preparation shows its step and can be cancelled` | T-3, T-4 |
| `another video waits while one is being prepared` | T-5 (a shared `ProviderContainer` across two views) |

## Results

- `flutter test test/analysis_screen_test.dart`: **11/11 pass** (7 existing
  and 4 new).
- `flutter analyze`: no issues.
- Full `flutter test`: the same 18 failures as the baseline (with `app/lib`
  stashed), plus a flaky `bridge_test` import case.

## Pre-existing problems (not caused by this change; recorded for follow-up)

| Problem | Evidence |
| --- | --- |
| 18 tests in library, highlights, app-shell and catalog fail | They fail identically with this change stashed. The log shows `table matches has no column named workspace_id`, which points to a catalog migration or test-fixture mismatch after the workspace feature. |
| `bridge_test: importing a recording through the bridge…` is flaky | It failed 1 of 3 isolated runs with `checkpoints.json is not a readable checkpoint: EOF while parsing`, which suggests an engine checkpoint write/read race. It uses the real engine and none of the Dart touched here. |
