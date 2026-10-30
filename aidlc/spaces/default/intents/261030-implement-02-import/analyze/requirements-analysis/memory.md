# Requirements Analysis — Stage Diary

## Interpretation

- 2026-10-30: Audited all 35 `FR-IMP` requirements against `HEAD` (`d33d123`).
  Engine requirements (`FR-IMP-05`, `06`, `16`–`24`, `26`, `28`, `35`) are fully
  implemented and tested in `core/use-cases/media`, `core/use-cases/jobs`,
  `core/gateways/storage`, and `core/adapters/api`.
- 2026-10-30: Identified three concrete code gaps in `app/`:
  1. **G1 (`FR-IMP-15`)**: `RecordingStore.takeCustody` and `ImportController`
     do not track or expose byte-copy progress (`fraction`), leaving the
     progress bar indeterminate in `WorkspaceScreen` and `VideoRail`.
  2. **G2 (`FR-IMP-29`)**: `AnalysisState.missing` ignores
     `manifest.notRebuildableKinds`, causing `AnalysisPanel` to count
     non-rebuildable artifacts (`calibration`, `tracks`, `rally_suggestions`,
     `export`) in the Rebuild button and omit the message naming which stage
     produces them.
  3. **G3 (`FR-IMP-30`)**: `ArtifactRows` maps `ArtifactStateDto` to
     `ScStatus.done` (check icon only, no `READY` label), `ScStatus.needsReview`
     (`NEEDS REVIEW` instead of `PARTIAL`), and `ScStatus.blocked` (`BLOCKED`
     instead of `MISSING`), whereas `FR-IMP-30` requires the states to be
     labelled `READY`, `PARTIAL`, or `MISSING`.
