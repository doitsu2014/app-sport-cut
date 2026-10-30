# Unit Breakdown — Import and Media Preparation (Feature 2)

Status: Develop / Task Planning
Intent: `261030-implement-02-import`
Consumes: `../../ideate/technical-spec/technical-spec.md`,
`../../analyze/requirements-analysis/requirements.md`

Sizes: S ≈ < 1 h, M ≈ half a day, all review-sized (one sitting).

## U0 — Commit the unrelated protocol client fix

- **Requirement ids**: none (pre-existing macOS bug: `tcpNoDelay` on AF_UNIX →
  EOPNOTSUPP; blocks every service connection at startup).
- **Acceptance criteria**: the working-tree change in
  `app/lib/src/bridge/protocol_client.dart` lands as its own commit with a
  message explaining why; the feature diff that follows contains no
  bridge changes.
- **Files**: `app/lib/src/bridge/protocol_client.dart`.
- **Dependencies**: none. **Size**: S.

## U1 — G1 data/domain: progress-reporting custody copy

- **Requirement ids**: FR-IMP-15, NFR-2 (partial), FR-IMP-08/09/11 preserved.
- **Acceptance criteria** (spec §2.1–§2.2):
  - `RecordingStore.takeCustody` gains optional `int? expectedBytes` and
    `void Function(double fraction)? onProgress` exactly per API contract §2.1.
  - `_copy`: `0.0` before first chunk; per-chunk cancel check unchanged;
    `copiedBytes` counted; `fraction = (copiedBytes/totalBytes).clamp(0.0,1.0)`,
    `percent = (fraction*100).round()`; emit only when `percent > lastPercent`;
    post-flush `1.0` only if `lastPercent < 100` (≤ 101 invocations);
    `totalBytes` = `expectedBytes` when `> 0` else `source.lengthSync()`;
    degenerate `totalBytes <= 0` → only `0.0`/`1.0`.
  - `takeCustody` cleanup broadened to `on Object` → `remove(matchId)` →
    rethrow (a throwing `onProgress` cannot strand the directory or `.part`).
  - `MatchLibrary.importVideo` and `MatchRepository.importVideo` gain optional
    `onProgress`; repository passes `expectedBytes: metadata.sizeBytes`.
  - `FakeMatchLibrary.importVideo` gains the parameter (accepts, ignores).
  - `flutter analyze` clean; no test file changes beyond the fake.
- **Files**: `app/lib/src/features/library/data/recording_store.dart`,
  `app/lib/src/features/library/domain/match_library.dart`,
  `app/lib/src/features/library/data/match_repository.dart`,
  `app/test/support/fake_match_library.dart`.
- **Dependencies**: U0. **Size**: M. **Risk**: highest (I/O + cancel +
  cleanup semantics) → scheduled first among feature units.

## U2 — G1 presentation: fraction in import state and both progress surfaces

- **Requirement ids**: FR-IMP-14, FR-IMP-15, NFR-2 (partial), DS (progress job).
- **Acceptance criteria** (spec §2.3–§2.4):
  - `ImportState` gains `final double? fraction`; invariant: non-null only in
    `ImportPhase.importing`; `idle`/`picking` carry null.
  - `ImportController.start` sets `fraction: 0.0` entering importing, passes
    `onProgress` (guarded by `identical(_token, token)` and
    `phase == importing`), failure/cancel paths drop fraction, existing
    `finally` reset leaves fraction null.
  - `WorkspaceScreen` passes `fraction: import.fraction` (line ~77);
    `WorkspaceStudioScreen` passes `importFraction: import.fraction` to
    `StudioShell`. No design-system component changes.
  - Both surfaces show stage label + `N%` + Cancel during import; picking
    renders exactly as today.
  - `flutter analyze` clean; existing tests still compile.
- **Files**: `app/lib/src/features/library/presentation/import_controller.dart`,
  `app/lib/src/features/workspace/presentation/workspace_screen.dart`,
  `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart`.
- **Dependencies**: U1. **Size**: S–M.
- **Walking skeleton**: U1+U2 together are the thinnest end-to-end slice
  (pick → probe → percent-stepped copy → visible `0%`–`100%` bar), proving
  the callback architecture without protocol or engine changes.

## U3 — G2: rebuildable partition + guidance note

- **Requirement ids**: FR-IMP-28, FR-IMP-29, DS-10.
- **Acceptance criteria** (spec §2.5–§2.6):
  - `AnalysisState.rebuildableMissing` / `.notRebuildableMissing` computed
    getters partition `missing` by `manifest?.notRebuildableKinds` (Set);
    null-manifest safe; `missing` preserved; no new fields (copyWith/_finish
    untouched).
  - Rebuild button label/`enabled`/`onPressed` switch to
    `rebuildableMissing`; strings unchanged for the existing fake data.
  - Guidance note renders whenever `notRebuildableMissing.isNotEmpty`
    (including when `rebuildableMissing.isEmpty`), inside the idle/loaded/
    viewing branch after the button (and after the busyElsewhere note), using
    the `SizedBox(space2)` + `xs12` muted Text pattern; static kind →
    (display, stage) map with safe unknown-kind fallback.
  - `flutter analyze` clean.
- **Files**: `app/lib/src/features/analysis/presentation/analysis_providers.dart`,
  `app/lib/src/features/analysis/presentation/analysis_panel.dart`.
- **Dependencies**: none. **Size**: S–M. Parallelizable with U1/U2/U4.

## U4 — G3: READY / PARTIAL / MISSING artifact badges

- **Requirement ids**: FR-IMP-30, DS-6.
- **Acceptance criteria** (spec §2.7):
  - `_ArtifactRow` renders the local badge: `final_` → `READY` +
    `ScIcons.checkCircle` + `palette.success`; `nonFinal` → `PARTIAL` +
    `ScIcons.warning` + `palette.warn`; `missing` → `MISSING` +
    `ScIcons.blocked` + `palette.danger`; word in `typography.chrome9`
    uppercase; icon + word + colour together; MISSING keeps danger-coloured
    kind name.
  - Numbered row layout, decimal size trailing (`'—'` when null), ellipsized
    path subtitle, `rowCompact` height, dividers preserved; public
    `ArtifactRows` constructor unchanged; `ScStatus`/`ScPipelineRow` untouched.
  - `_status` switch and the now-unused `sc_status.dart`/`sc_pipeline_row.dart`
    imports removed; `flutter analyze` clean.
- **Files**: `app/lib/src/features/analysis/presentation/artifact_rows.dart`.
- **Dependencies**: none. **Size**: S. Parallelizable with U1/U2/U3.

## U5 — G4: BRD reconciliation

- **Requirement ids**: G4 (BRD-00 §3.3 row 2; BRD-02 §2.3, §3 markers, §4,
  §5, §7, §8.3, §8.4, §9).
- **Acceptance criteria** (spec §2.8): status/evidence cells only — no Must
  acceptance text edited; both docs bumped to Version 1.1 with the
  implementation-commit baseline; stale claims corrected exactly as
  enumerated in spec §2.8 (including: baseline-red test files recorded, NFR-7
  waiver stated, NFR-2 cadence gap kept, R-IMP-2 mitigated, Q-IMP-4 closed,
  deferred ADR-0001/timing text preserved).
- **Files**: `docs/brd/02-import-and-media-preparation.md`,
  `docs/brd/00-product-context.md`.
- **Dependencies**: U1–U4 (evidence wording follows landed code). **Size**: M.

## Verification unit (runs per unit, not a separate slice)

- **V**: `cd app && flutter analyze` and `tools/check-no-rust-in-app.sh` after
  every code unit; document diff review for U5. No new tests (working
  agreement); existing tests must keep compiling.

## Sequencing summary

```
U0 → U1 → U2        (walking skeleton, risk-first)
        ∥ U3        (independent)
        ∥ U4        (independent)
U1..U4 → U5         (docs last)
```

Critical path: U0 → U1 → U2 → U5. U3 and U4 have no coupling to anything and
to each other — in the Code Generation stage they run as parallel agent
lanes alongside the U1→U2 chain.
