# Review Record — Workspace and Library gaps

Status: Develop / Code Review
Intent: `261029-implement-brd-feature`
Reviewers: code-reviewer-agent (lead), security-agent (support), inline
Verdict: **Approve after fixes** (fixes applied in this stage)

## Scope reviewed

`git diff` across the six client files plus the two BRD docs. Tests were read
only to confirm no call site of `StudioStatusBar` was missed; `flutter analyze`
covers compilation of the test tree.

## Findings

| # | Severity | File | Finding | Disposition |
| --- | --- | --- | --- | --- |
| R1 | Medium | `workspace_studio_screen.dart` | If the deleted match was not found in the pre-delete list (`removedIndex == -1`), the selection fell through to the last entry. | **Fixed**: `-1` now selects index 0. |
| R2 | Low | `studio_status_bar.dart` | The new stage text had no width bound; at large text scale the 30 px bar's Row could overflow (FR-SHL-35). | **Fixed**: the stage text is `Flexible` with `maxLines: 1` and ellipsis. |
| R3 | Low | `workspace_screen.dart` | `'$error'` can render a multi-line platform message in a compact card. | Accepted: NFR-13 wants the reason named; the card wraps, and the app is offline. |
| R4 | Info | `workspace_studio_screen.dart` | Deleting the last video disposes the shared controller and nulls it. | Correct: the build path already tolerates a null controller. |
| R5 | Info | `studio_status_bar.dart` | The status bar is a data-in widget; the new parameter preserves that. | No action. |

## Correctness checks

- G1: every `StudioStatusBar` call site updated (one). `shortStageLabel` values
  match the old private map exactly, so the stage strip renders unchanged.
- G2: the loading branch renders no empty-state copy; the indicator is labelled
  for assistive technology.
- G3: Retry still invalidates both providers; the reason is appended, not
  substituted.
- G4: `_selectVideo` sets the new id synchronously, so `_ensureSelection` does
  not override it on the next build. The empty case is left null, and
  `_ensureSelection` is guarded by `entries.isNotEmpty`.

## Security

- No new input crosses a trust boundary; no SQL, network, process, or file
  write is added.
- No secret, token, or machine-specific path is introduced.
- The error message now rendered may include a local path; accepted per
  NFR-13 and the offline guarantee (nothing leaves the device).

## Verification after fixes

- `flutter analyze`: 0 errors, 0 warnings; 4 pre-existing
  `prefer_const_constructors` infos in untouched test files.
- `tools/check-no-rust-in-app.sh`: OK.
