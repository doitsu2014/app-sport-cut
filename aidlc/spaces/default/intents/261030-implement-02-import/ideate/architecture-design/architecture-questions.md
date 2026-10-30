# Architecture Questions — Import and Media Preparation (Feature 2)

Intent: `261030-implement-02-import`
Stage: `architecture-design`

## Q1: How should byte-progress flow from `RecordingStore` to the UI (`FR-IMP-15`)?

A. Pass an optional `void Function(double fraction)? onProgress` callback through
   `MatchLibrary.importVideo` → `MatchRepository.importVideo` →
   `RecordingStore.takeCustody`, using `metadata.sizeBytes` (or `source.length()`)
   as the denominator and throttling notifications in `RecordingStore` to
   whole-percentage steps (`0%..100%`). `ImportController` updates
   `ImportState.fraction` and `WorkspaceStudioScreen` / `WorkspaceScreen` pass it
   to `ScProgressJob`.
B. Introduce a separate Riverpod `StreamProvider<double>` for copy progress.
C. Poll the destination `.part` file size on a timer from `ImportController`.
X. Other (describe)

[Answer]: A. Pass an optional `void Function(double fraction)? onProgress`
callback through `MatchLibrary.importVideo` → `MatchRepository.importVideo` →
`RecordingStore.takeCustody`, using `metadata.sizeBytes` (or `source.length()`)
as the denominator and throttling notifications in `RecordingStore` to
whole-percentage steps (`0%..100%`). `ImportController` updates
`ImportState.fraction` and `WorkspaceStudioScreen` / `WorkspaceScreen` pass it to
`ScProgressJob`.

## Q2: Where should rebuildable vs. non-rebuildable missing artifact partitioning (`FR-IMP-29`) live?

A. On `AnalysisState` in `analysis_providers.dart` via computed getters
   `rebuildableMissing` and `notRebuildableMissing` derived from
   `manifest.artifacts` and `manifest.notRebuildableKinds`, with `AnalysisPanel`
   rendering the Rebuild button count from `rebuildableMissing` and a descriptive
   summary for `notRebuildableMissing`.
B. Inside `AnalysisPanel.build` directly without updating `AnalysisState`.
C. In the Rust engine by changing `ArtifactManifestDto` wire fields.
X. Other (describe)

[Answer]: A. On `AnalysisState` in `analysis_providers.dart` via computed getters
`rebuildableMissing` and `notRebuildableMissing` derived from
`manifest.artifacts` and `manifest.notRebuildableKinds`, with `AnalysisPanel`
rendering the Rebuild button count from `rebuildableMissing` and a descriptive
summary for `notRebuildableMissing`.

## Q3: How should `ArtifactRows` render `READY`, `PARTIAL`, and `MISSING` (`FR-IMP-30`) without breaking `ScPipelineRow`'s contract for pipeline stages?

A. Render the explicit state badge (`READY` / `PARTIAL` / `MISSING`) in
   `_ArtifactRow` with the matching semantic colour (`palette.success`,
   `palette.warn`, `palette.danger`) and icon (`ScIcons.check`,
   `ScIcons.review`, `ScIcons.blocked`) alongside the mono decimal byte size and
   relative path, keeping `ScPipelineRow` unchanged for pipeline stages.
B. Change `ScStatus.done.label` globally from `'Done'` to `'Ready'` and
   `ScStatus.blocked.label` from `'Blocked'` to `'Missing'`.
X. Other (describe)

[Answer]: A. Render the explicit state badge (`READY` / `PARTIAL` / `MISSING`) in
`_ArtifactRow` with the matching semantic colour (`palette.success`,
`palette.warn`, `palette.danger`) and icon (`ScIcons.check`, `ScIcons.review`,
`ScIcons.blocked`) alongside the mono decimal byte size and relative path,
keeping `ScPipelineRow` unchanged for pipeline stages.

## Contradiction analysis

- Q1-A avoids filesystem polling (C) and avoids extra providers (B), reusing the
  existing `ImportState` and `StudioShell.importFraction` prop.
- Q2-A keeps `AnalysisState.missing` intact for any existing callers while adding
  `rebuildableMissing` and `notRebuildableMissing` on the state model.
- Q3-A avoids mutating `ScStatus` (which is shared with the studio stage strip
  and pipeline rows where `DONE`, `NEEDS REVIEW`, and `BLOCKED` are required by
  `09-studio-shell-jobs-and-settings.md`).
- No open contradictions.
