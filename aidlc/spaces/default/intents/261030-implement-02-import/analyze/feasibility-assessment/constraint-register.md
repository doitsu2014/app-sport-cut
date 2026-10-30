# Constraint Register — Import and Media Preparation (Feature 2)

Status: Analyze / Feasibility Assessment
Intent: `261030-implement-02-import`

## 1. Hard constraints

| ID | Category | Constraint | Source |
| --- | --- | --- | --- |
| C-1 | Privacy / Offline | Zero network calls, telemetry, or cloud APIs in any import or preparation path. | `CLAUDE.md`, `BR-1`, `NFR-1` |
| C-2 | Custody | The user's original video file is read-only and never modified, moved, renamed, or deleted. Copies write to `.part` and rename atomically. | `CLAUDE.md`, `BR-2`, `FR-IMP-08` |
| C-3 | Architecture boundary | The app links no Rust and uses no FFI (`tools/check-no-rust-in-app.sh` must pass). All engine calls go through `app/lib/src/bridge/sportcut_engine.dart`. | `CLAUDE.md`, `ADR-0001` |
| C-4 | Protocol stability | `core/gateways/protocol` wire methods, framing, and DTO shapes remain unchanged. | `CLAUDE.md`, `ADR-0001` |
| C-5 | Design system | All colours, typography, spacing, and components come from `SportcutTokens`, `SportcutPalette`, `SportcutTypography`, and `sc_*` components. Indeterminate bars may not appear without a stage label, and import must report a determinate byte fraction. | `DESIGN.md` §6, `FR-IMP-15`, `FR-IMP-30` |
| C-6 | Licensing | No new third-party dependency may be added without a row in `docs/brd/00-product-context.md`. | `CLAUDE.md` Licensing gate |
| C-7 | Working agreement | Implement first; do not add new test files or test cases unless asked. Verify with `flutter analyze` and `tools/check-no-rust-in-app.sh`. | `CLAUDE.md` Working agreement |

## 2. Risk register

| ID | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| R-IMP-1 | Emitting a Riverpod state update on every 64 KB chunk during a multi-gigabyte copy floods the UI frame scheduler. | Medium | Medium | Throttle `onProgress` updates in `ImportController` / `RecordingStore` so state updates only when the rounded percentage point (`(fraction * 100).round()`) changes or at `0.0` and `1.0`. |
| R-IMP-2 | Adding `onProgress` to `MatchLibrary.importVideo` breaks existing test fakes (`FakeMatchLibrary` in `app/test/support/fakes.dart`). | High | Low | Make `onProgress` an optional named parameter (`void Function(double fraction)? onProgress`) on `MatchLibrary.importVideo`, `MatchRepository.importVideo`, and `FakeMatchLibrary.importVideo`. |
| R-IMP-3 | Changing artifact state labels in `ArtifactRows` breaks existing widget assertions in `app/test/analysis_screen_test.dart`. | Low | Low | Check `app/test/analysis_screen_test.dart` assertions (it checks `find.text('proxy')`, `find.text('frames')`, `find.text('Artifacts')`) and ensure all existing expectations remain satisfied. |
