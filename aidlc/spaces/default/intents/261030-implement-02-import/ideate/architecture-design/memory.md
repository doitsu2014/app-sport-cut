# Architecture Design — Stage Diary

## Interpretation

- 2026-10-30: Designed the data flow for `FR-IMP-15`, `FR-IMP-29`, and `FR-IMP-30`
  to reuse existing hooks (`StudioShell.importFraction`, `VideoRail.importFraction`,
  `ArtifactManifestDto.notRebuildableKinds`) without touching the Rust engine or
  service protocol.

## Tradeoff

- 2026-10-30: Kept `ScStatus` unchanged so studio pipeline rows continue to use
  `DONE` / `NEEDS REVIEW` / `BLOCKED` per BRD-09, while `_ArtifactRow` renders
  the artifact-specific `READY` / `PARTIAL` / `MISSING` labels required by
  `FR-IMP-30`.
