# Test Plan — Workspace and Library gaps

Status: Launch / Test Plan
Intent: `261029-implement-brd-feature`
Consumes: `requirements.md`, `technical-spec.md`, `source-changes.md`

## 1. Posture

The project working agreement (and this intent's Q3-A) says: implementation
first, no new test files or test cases, and do not run the suites during
ordinary work. This plan therefore records the **verification** for each gap —
static analysis plus a manual script — not an automated test suite. It also
records the automated tests that *would* be written if the policy changes.

## 2. Verification matrix

| Gap | Requirement | Automated (current) | Manual check | Pass condition |
| --- | --- | --- | --- | --- |
| G1 | FR-LIB-20 / FR-SHL-14 | `flutter analyze` | Open a workspace, select each stage. | The status bar's right side reads `· Play`, `· Court`, `· Analysis`, `· Tracking`, `· Score`, `· Clips`, and Export opens the sheet. |
| G2 | FR-LIB-05 | `flutter analyze` | Open the app with a cold catalog; observe before the list resolves. | A progress indicator is visible; "No workspaces yet." never appears while loading. |
| G3 | FR-LIB-06 | `flutter analyze` | Force a catalog read failure (rename or lock the database in a debug build). | The card reads "The workspaces could not be read." plus the reason, and Retry re-reads. |
| G4 | FR-LIB-24 | `flutter analyze` | Import three videos; select the middle; delete it. Repeat for the last and the only video. | Middle delete selects the third; last delete selects the second; only-video delete shows the empty studio. |
| Guard | NFR-9 | `tools/check-no-rust-in-app.sh` | — | OK. |

## 3. Regression checks (read-only)

- `stage_strip.dart` renders the same short labels as before (the map and the
  helper carry identical values).
- `StudioStatusBar` still shows the local-only promise, counts, score, and
  readiness.
- Deleting an unselected video leaves the selection untouched.

## 4. Automated tests if the policy changes

| Test | Type | Covers |
| --- | --- | --- |
| `StudioStatusBar` render with `stageLabel` | Widget | G1 |
| `WorkspaceScreen` loading state | Widget | G2 |
| `WorkspaceScreen` error state shows the reason | Widget | G3 |
| Delete-selection rule with a fake library | Widget | G4 |
| `shortStageLabel` mapping | Unit | G1 vocabulary |

These are recorded, not written (Q3-A).

## 5. Known gaps in existing tests

`app/test/library_screen_test.dart` and `app/test/app_shell_test.dart` still
assert the removed "No matches yet" screen. They are not repaired under Q3-A;
the project working agreement allows touching a test only when a change stops
it compiling.
