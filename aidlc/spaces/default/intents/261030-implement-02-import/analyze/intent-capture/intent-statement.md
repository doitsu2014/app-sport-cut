# Intent Statement — Import and Media Preparation (Feature 2)

Status: Analyze / Intent Capture
Intent: `261030-implement-02-import`
Date: 2026-10-30
Sources: `docs/brd/02-import-and-media-preparation.md`, `docs/brd/00-product-context.md`,
`docs/adr/0001-rust-background-service.md`, `docs/adr/0002-clean-architecture-engine.md`,
`CLAUDE.md`.

## Problem

Sportcut's second feature (`IMP`, `docs/brd/02-import-and-media-preparation.md`)
governs everything between choosing a local video file and having analysis-ready
media on disk: picking, probing, taking non-destructive custody of a copy,
generating the 540p proxy, extracting 16 kHz mono AAC analysis audio, sampling
frames, maintaining the artifact manifest, and rebuilding missing derived media.

While the studio refactor (`757c748`) replaced the legacy Material analysis
table with `AnalysisPanel` and `ArtifactRows`, `docs/brd/02-import-and-media-preparation.md`
still records baseline `1541c64` status and two Must requirements remain
unimplemented on `HEAD` (`d33d123`):
1. **`FR-IMP-15` (Show determinate import progress):** `RecordingStore` copies
   the recording chunk-by-chunk without reporting bytes copied, `ImportState`
   carries no progress fraction, and both `WorkspaceScreen` and `StudioShell` /
   `VideoRail` pass `fraction: null` to `ScProgressJob`.
2. **`FR-IMP-29` (Report what cannot be rebuilt):** `AnalysisState.missing`
   counts every missing artifact in the manifest, ignoring
   `manifest.notRebuildableKinds` (such as `court_calibration`, `player_tracks`,
   `rally_suggestions`, `highlight_export`). As a result, `AnalysisPanel` offers
   to rebuild files the media pipeline cannot produce and does not explain which
   stage produces them.

## Users

- **Club coach / competitive player / parent** importing a multi-gigabyte match
  recording and preparing analysis files locally. They need determinate progress
  during import and honest repair counts when artifacts go missing.
- **Product owner** gating v1 on the BRD's 35 `FR-IMP` Must requirements, who
  needs all in-scope gaps closed and the BRD status tables reconciled with HEAD.

## Success criteria (observable)

1. All 35 `FR-IMP` requirements (`FR-IMP-01` through `FR-IMP-35`) are audited
   against HEAD and recorded as Satisfied, Partial, or Missing with exact file
   and symbol references.
2. Every in-scope requirement marked Missing or Partial by the audit (`FR-IMP-15`,
   `FR-IMP-29`, and any related UI/state gap) is implemented in `app/`.
3. `flutter analyze` is clean for `app/`, and `tools/check-no-rust-in-app.sh`
   passes.
4. `docs/brd/02-import-and-media-preparation.md` (§2.3, §3, §7) and
   `docs/brd/00-product-context.md` (§3.3 row 2) are updated to reflect the
   verified delivery state on HEAD.
5. Out-of-scope items remain untouched.

## In scope

- Auditing `FR-IMP-01` through `FR-IMP-35` against `core/` and `app/`.
- Determinate import progress (`FR-IMP-15`): reporting byte-copy progress from
  `RecordingStore.takeCustody` through `MatchRepository.importVideo` and
  `ImportController` (`ImportState.fraction`), and wiring `importFraction` into
  `WorkspaceStudioScreen` → `StudioShell` → `VideoRail` and `WorkspaceScreen`.
- Rebuildable vs. non-rebuildable missing artifacts (`FR-IMP-29`): filtering the
  rebuild count in `AnalysisState` / `AnalysisPanel` by excluding
  `manifest.notRebuildableKinds`, and reporting non-rebuildable missing
  artifacts with the stage that produces each one.
- Reconciling the BRD status tables in `docs/brd/02-import-and-media-preparation.md`
  and `docs/brd/00-product-context.md`.

## Out of scope

- Moving recording custody or the SQLite catalog into the Rust background
  service (ADR-0001 Phase 3–4).
- Multi-file, folder, or playlist import (BRD §2.2).
- User-configurable proxy resolution, audio bitrate, or frame sampling rate in
  the UI (BRD §2.2 / Q-IMP-3; sampling rate remains fixed at 1 fps in v1).
- Pre-checking free disk space via native platform channels before copying
  (Q-IMP-1; `ENOSPC` / `ERROR_DISK_FULL` classification and cleanup remain the
  v1 mechanism).
- Wiring analysis audio into rally segmentation (`R-IMP-3`, owned by Feature 05
  Rally Review).
- Writing new test files or new test cases (per `CLAUDE.md` working agreement).

## Constraints

- Client track (`app/`) and documentation (`docs/brd/`): keep `flutter analyze`
  clean and `tools/check-no-rust-in-app.sh` passing.
- No FFI, no Rust in the app, and no new durable client-owned state.
- Offline-only operation: zero network calls, zero telemetry.
- Design-system compliance: use `SportcutTokens`, `SportcutPalette`,
  `SportcutTypography`, `ScProgressJob`, `ScBanner`, and `ScPipelineRow` with no
  raw hex values or ad-hoc Material tables.

## Assumptions

- The engine (`core/use-cases/media`, `core/use-cases/jobs`, `core/gateways/storage`,
  `core/adapters/api`) already satisfies the engine-side `FR-IMP` requirements,
  including populating `not_rebuildable_kinds` on `ArtifactManifestDto`.
- Byte-accurate progress during the recording copy (using `metadata.sizeBytes`
  or the source file length as denominator) satisfies both `FR-IMP-15` and
  `Q-IMP-4`.

## Cost of doing nothing

Large video imports continue to show an indeterminate progress bar for the
entire multi-gigabyte copy (violating `FR-IMP-15` and `DESIGN.md` §6), and a
match missing calibration, player tracks, or an export shows a misleading
"Rebuild N missing files" button that finishes without repairing those files
(violating `FR-IMP-29`).
