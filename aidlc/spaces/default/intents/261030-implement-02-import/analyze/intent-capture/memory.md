# Intent Capture — Stage Diary

## Interpretation

- 2026-10-30: Selected BRD feature 2 (`02-import-and-media-preparation.md`, area
  `IMP`) as the next intent after feature 1 (`01-workspace-and-library.md`)
  completed and merged in PR #5.
- 2026-10-30: Scoped the intent to auditing all 35 `FR-IMP` requirements against
  HEAD, implementing the verified client-side gaps (`FR-IMP-15` determinate
  import progress and `FR-IMP-29` excluding `notRebuildableKinds` from rebuild
  counts while naming the stage that produces them), and reconciling the BRD
  status tables.

## Tradeoff

- 2026-10-30: Kept recording custody in `RecordingStore` (client-owned v5
  catalog interim) rather than coupling this feature intent to ADR-0001 Phase
  3–4 service custody migration.

## Open question

- 2026-10-30: Resolved `Q-IMP-4` in favor of byte-accurate progress during the
  streamed recording copy, since `RecordingStore._copy` already processes byte
  chunks and `metadata.sizeBytes` (or `source.length()`) gives the exact total.
