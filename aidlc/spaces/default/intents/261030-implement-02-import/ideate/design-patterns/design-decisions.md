# Design Decisions — Import and Media Preparation (Feature 2)

Status: Ideate / Design Pattern Selection
Intent: `261030-implement-02-import`
Consumes: `../architecture-design/architecture-doc.md`, `../../analyze/requirements-analysis/requirements.md`

## 1. Forces to patterns mapping

| Force | Pattern chosen | Existing precedent in codebase |
| --- | --- | --- |
| High-frequency chunk I/O vs. Riverpod UI rebuilds | Percentage-stepped progress callback (`onProgress`) | `ScProgressJob` displays whole percentages `(fraction * 100).round()`; stepping on integer percentage changes caps state emissions to ≤101 per import. |
| Derived state over immutable DTOs | Computed getters on immutable state class (`AnalysisState`) | `AnalysisState.missing` and `AnalysisState.unprepared` in `analysis_providers.dart`. |
| Presentational widgets free of provider dependencies | Data-in / callback-out stateless widgets | `StudioShell`, `VideoRail`, `WorkspaceScreen`, `ArtifactRows`. |
| Domain-specific status vocabulary (`READY` / `PARTIAL` / `MISSING`) | Local presentation mapping in `ArtifactRows` using `SportcutPalette` + `ScIcons` | `StageStrip` and `ScVideoRow` map domain states to tokens without altering shared `ScStatus` labels. |

## 2. ADR-style decision table

| ID | Context | Decision | Alternatives considered | Consequences | Status |
| --- | --- | --- | --- | --- | --- |
| DD-1 | `RecordingStore._copy` streams 64 KB chunks from `source.openRead()`. Calling `state = ImportState(...)` on every chunk of a 4 GB file would emit ~65,000 Riverpod state updates. | Track `lastPercent` inside `RecordingStore._copy` and invoke `onProgress(fraction)` only when `(fraction * 100).round()` advances within 1..99, plus `0.0` before the first chunk and always `1.0` after flush (the in-loop 100% step is skipped because the rounded percent reaches 100 at ratio ≈ 0.995, which would otherwise suppress the exact terminal value — code review F1). | Timer-based throttling (introduces async timer lifecycle and non-deterministic test timing); unthrottled callbacks; emitting the in-loop 100% step (terminal value lands at ≈ 0.995, breaking the "finishing at 1.0" contract). | At most 101 UI updates per import (1 + ≤99 + 1); deterministic behavior in tests; smooth 0%–100% progress bar whose terminal callback is exactly `1.0`. | Approved (refined by code review F1, 2026-10-30) |
| DD-2 | `AnalysisPanel` needs to distinguish missing media artifacts it can rebuild (`proxy`, `analysis_audio`, `frames`) from missing downstream artifacts (`calibration`, `tracks`, `rally_suggestions`, `export`). | Add `rebuildableMissing` and `notRebuildableMissing` getters to `AnalysisState` using `manifest.notRebuildableKinds`, and add a static helper in `AnalysisPanel` mapping each non-rebuildable kind to its producing stage name (`calibration` → `Mark court`, `tracks` → `Player analysis`, `rally_suggestions` → `Review & score`, `export` → `Export`). | Hard-coding rebuildable kinds in the Dart widget (`proxy`, `analysis_audio`, `frames`) and ignoring `manifest.notRebuildableKinds`. | Respects the engine's authoritative `notRebuildableKinds` list (`FR-IMP-29`) and names the exact stage the user needs to run next (`DS-10`). | Approved |
| DD-3 | `FR-IMP-30` requires `ArtifactRows` to show each artifact's state as `READY`, `PARTIAL`, or `MISSING`, while `ScPipelineRow` is shared with the studio pipeline panel where `DONE`, `NEEDS REVIEW`, and `BLOCKED` are required by `BRD-09`. | Render the `READY`, `PARTIAL`, or `MISSING` state badge (icon + uppercase mono `chrome9` word in semantic colour) alongside the byte size in `_ArtifactRow`, while keeping the numbered row layout and path subtitle. | Changing `ScStatus` enum labels globally (breaks `BRD-09` pipeline status words). | `ArtifactRows` satisfies `FR-IMP-30` and `DS-6` (`READY`, `PARTIAL`, `MISSING` in mono uppercase with colour + icon) without affecting `ScPipelineRow` in the studio pipeline panel. | Approved |

## 3. Deviations from codebase conventions

None. All three decisions follow existing Riverpod `Notifier` and `sc_*` design
component conventions.
