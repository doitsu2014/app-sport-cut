# Test Suite

## Generated tests

**None generated.** The test plan's only new test is the single ordering
assertion for RS-1/RS-2/RS-3, and root `AGENTS.md` forbids adding new test files
or cases unless the user explicitly asks for tests. This workflow's request was
to move the feature, not to add tests, so the ordering test is **deferred** and
the manual + static floor from the test plan applies. The test is fully specified
(in `test-plan.md`, Strategy row 1) and can be added on request.

## Traceability

| Req | Planned test | Status | Evidence |
| --- | --- | --- | --- |
| RS-1, RS-2, RS-3 | Ordering widget test: Analysis order and Studio membership | Deferred (policy) | Code review (`review-record.md`) + planned manual check |
| RS-4 | Existing `ScoreView` tests | **Pass** | `flutter test test/score_screen_test.dart` → 5/5 pass |
| RS-5 | Review of the shared `_item` path | Verified | `review-record.md` RS-5 row |
| RS-6 | Review of `PlayerTrackingView.onOpenScore` | Verified | `review-record.md` RS-6 row |
| RS-7 | Diff review | Verified | `git diff --stat`: two files only |
| RS-8 | Doc review | Verified | `docs/architecture.md` diff |
| RS-9 | `flutter analyze` | **Pass** | No issues found (after `tools/generate-bridge.sh`) |
| RS-10 | Existing tests | Partial | Focused `score_screen_test` run green; full suite not run per repo policy |
| RS-11 | Diff review | Verified | No `pubspec.yaml` / `core/` change |

## Results

- `cd app && flutter analyze` — **No issues found!** (1.7s).
- `cd app && flutter test test/score_screen_test.dart` — **5/5 pass**, confirming
  `ScoreView` (shown by the moved rail item) is unaffected.
- Full `flutter test` not run: `AGENTS.md` reserves the suite for explicit
  verification requests and the cheapest applicable check for a two-line
  presentation change is `flutter analyze` plus the focused score test.

## Exit criteria status

| Criterion | Status |
| --- | --- |
| `flutter analyze` exits 0 | Met |
| Ordering test passes (if generated) | N/A — deferred by policy |
| `score_screen_test.dart` passes | Met |
| Manual studio check | Outstanding — requires running `tools/run-macos.sh`; the grouping is visible in the diff |

## Follow-up

Add the single ordering widget test (as specified in `test-plan.md`) when the
team next touches `workspace_studio_screen.dart` or explicitly asks for it.
