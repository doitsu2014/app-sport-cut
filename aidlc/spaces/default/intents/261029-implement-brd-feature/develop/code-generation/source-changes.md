# Source Changes — Workspace and Library gaps

Status: Develop / Code Generation
Intent: `261029-implement-brd-feature`
Consumes: `implementation-plan.md`, `unit-breakdown.md`, `technical-spec.md`

## Files changed

| File | Unit | Change |
| --- | --- | --- |
| `app/lib/src/features/workspace/domain/pipeline_stage.dart` | U1 | Added `shortStageLabel(PipelineStage?)`. |
| `app/lib/src/features/workspace/presentation/studio/stage_strip.dart` | U1 | Removed the private `_shortStageLabels` map; the strip reads the shared helper. |
| `app/lib/src/features/workspace/presentation/studio/studio_status_bar.dart` | U1 | Added the required `stageLabel` and renders `· <stage>` after readiness. |
| `app/lib/src/features/workspace/presentation/studio/studio_shell.dart` | U1 | Passes `shortStageLabel(selectedStage)` to the status bar. |
| `app/lib/src/features/workspace/presentation/workspace_screen.dart` | U2/U3 | Loading branch is a labelled progress indicator; error branch names the reason. |
| `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart` | U4 | Delete records the removed index and selects the next remaining video, or clears the selection when none remain. |
| `docs/brd/01-workspace-and-library.md` | U5 | §2.3 status rows reconciled with HEAD. |
| `docs/brd/00-product-context.md` | U5 | §3.3 row 1 reconciled; status stays Partial with the deferred items named. |

## Not changed

- `app/lib/src/bridge/`, `core/`, the service protocol, the catalog schema, and
  `app/pubspec.yaml`.
- No test file was added or modified.

## Verification

- `flutter analyze`: no errors, no warnings introduced. Four pre-existing
  `prefer_const_constructors` infos remain in test files that this change does
  not touch.
- `tools/check-no-rust-in-app.sh`: OK.
- Manual checks were not run against a launched app in this session.
