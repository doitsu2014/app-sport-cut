# Feasibility Assessment — Import and Media Preparation (Feature 2)

Status: Analyze / Feasibility Assessment
Intent: `261030-implement-02-import`
Consumes: `../intent-capture/intent-statement.md`, `../requirements-analysis/requirements.md`

## 1. Technical feasibility per gap

| Gap | Requirements | Assessment | Reasoning |
| --- | --- | --- | --- |
| G1 | FR-IMP-15, NFR-2 | **Feasible — low complexity** | `MatchRepository.importVideo` already receives `metadata.sizeBytes` from `probe(video.path)` before calling `RecordingStore.takeCustody`, and `File(video.path).lengthSync()` is also available. `RecordingStore._copy` already streams chunks (`source.openRead()`). Adding an optional `void Function(double fraction)? onProgress` callback to `takeCustody` and `importVideo`, updating `ImportState(fraction: ...)` (throttled to avoid rebuilding on every 64 KB chunk), and passing `import.fraction` to `StudioShell.importFraction` (which already exists on `StudioShell` and `VideoRail`) and `WorkspaceScreen`'s `ScProgressJob` requires no new dependencies or protocol changes. |
| G2 | FR-IMP-29 | **Feasible — low complexity** | The Rust engine (`core/adapters/api/src/dto.rs`) and Dart bridge (`ArtifactManifestDto.notRebuildableKinds` in `app/lib/src/bridge/models.dart`) already serialize and decode `notRebuildableKinds` (`calibration`, `tracks`, `rally_suggestions`, `export`). `AnalysisState` only needs to partition `missing` into `rebuildableMissing` and `notRebuildableMissing`, and `AnalysisPanel` can use `rebuildableMissing` for the button count/enabled state while rendering a plain-language summary of `notRebuildableMissing` naming the stage that produces each one. |
| G3 | FR-IMP-30, DS-6 | **Feasible — low complexity** | `ArtifactRows` (`app/lib/src/features/analysis/presentation/artifact_rows.dart`) already renders each artifact on an `ScPipelineRow`. Supplying explicit state labels (`READY`, `PARTIAL`, `MISSING`) or rendering the state label in `ArtifactRows` satisfies `FR-IMP-30` while preserving `ScPipelineRow`'s visual contract and all existing widget tests in `app/test/analysis_screen_test.dart`. |
| G4 | BRD-00, BRD-02 | **Feasible — documentation only** | Updating `docs/brd/02-import-and-media-preparation.md` and `docs/brd/00-product-context.md` requires only Markdown edits. |

## 2. Effort, cost, and schedule

- **Scope**: 6 Dart files in `app/lib/src/` + 1 test fake (`app/test/support/fakes.dart` if `MatchLibrary.importVideo` signature adds an optional named parameter) + 2 BRD Markdown files.
- **Spikes needed**: None. All engine data (`metadata.sizeBytes`, `manifest.notRebuildableKinds`) and UI props (`StudioShell.importFraction`, `VideoRail.importFraction`, `ScProgressJob.fraction`) already exist in the codebase.
- **Dependencies**: Zero new third-party dependencies; no licensing register update needed.

## 3. Recommendation

**Proceed.** All requirements are directly achievable within the existing
Flutter client and bridge contracts, with no Rust changes, no protocol changes,
and no external dependencies.
