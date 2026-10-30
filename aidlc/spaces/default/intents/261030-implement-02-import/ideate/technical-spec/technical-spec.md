# Technical Specification — Import and Media Preparation (Feature 2)

Status: Ideate / Technical Specification
Intent: `261030-implement-02-import`
Consumes: `../architecture-design/architecture-doc.md`,
`../design-patterns/design-decisions.md`, `../api-contract/api-contract.md`,
`../../analyze/requirements-analysis/requirements.md`
Baseline: HEAD `d33d123`. The working tree carries one unrelated fix in
`app/lib/src/bridge/protocol_client.dart` (removal of `tcpNoDelay` on the
AF_UNIX socket, which macOS rejects with EOPNOTSUPP). It is **out of scope**
for this feature and must land as its own separate commit before U1, keeping
this feature's diff limited to U1–U5.

## 0. Scope summary

All four gaps are **client-track (`app/`) and documentation (`docs/brd/`)**
work. No Rust crate, no wire-protocol method, no manifest change, and no new
dependency is introduced:

- The service already returns `MediaMetadataDto.sizeBytes` from `engine.probe`
  and `ArtifactManifestDto.notRebuildableKinds` from `engine.manifest`.
- `ScProgressJob`, `StudioShell`, and `VideoRail` already accept a nullable
  `fraction` / `importFraction`; nothing supplies them today.

Therefore `tools/check-layering.sh` and `tools/verify-engine.sh` are
unaffected by construction (no manifest or crate-surface change). The
applicable verification per unit is `flutter analyze` in `app/` **plus
`tools/check-no-rust-in-app.sh`** (required by the intent's success criterion 3
and constraint C-7). Per the working agreement no new tests are written; this
waives NFR-7's "ships with tests" clause for this intent, and U5 must not
claim NFR-7 is satisfied — only that the clause was waived by the project
working agreement.

## 1. Traceability: requirement → component → interface → verification

Satisfied requirements keep their existing components (evidence: requirements
audit §2); they are listed so every Must appears. Verification for all rows is
`flutter analyze` plus code review unless noted.

| Requirement | Status | Component(s) | Interface(s) | Verification |
| --- | --- | --- | --- | --- |
| FR-IMP-01 | Satisfied | `SystemVideoFilePicker` | `pickVideo()` | Unchanged; evidence: requirements audit §2.1 |
| FR-IMP-02 | Satisfied | `ImportController` | `start()` → `ImportDeclined` | Unchanged |
| FR-IMP-03 | Satisfied | `SystemVideoFilePicker` | `MatchImportKind.pickerFailed` | Unchanged |
| FR-IMP-04 | Satisfied | `MatchRepository` | `_ensureReadable` | Unchanged |
| FR-IMP-05 | Satisfied | `sportcut_media::probe` (service) | `engine.probe` → `MediaMetadataDto` | Existing engine suite (`core/use-cases/media/tests/media_pipeline.rs`); not re-run per working agreement |
| FR-IMP-06 | Satisfied | `sportcut_media::probe` (service) | `SportcutError::Probe { path, reason }` rejections (empty, non-regular, video-less, zero-duration, invalid fps) | Existing engine suite; not re-run |
| FR-IMP-07 | Satisfied | `MatchRepository.importVideo` | order: readable → probe → custody | Unchanged |
| FR-IMP-08 | Satisfied | `RecordingStore.takeCustody` | `.part` → atomic rename | `app/test/match_repository_test.dart` (red at baseline for unrelated reasons — see §3 Compatibility) |
| FR-IMP-09 | Satisfied | `RecordingStore._copy` | per-chunk cancel check, `remove(matchId)` | Unchanged; cleanup broadened per §2.1 |
| FR-IMP-10 | Satisfied | `MatchRepository.importVideo` | catalog-failure cleanup | Unchanged |
| FR-IMP-11 | Satisfied | `RecordingStore.isOutOfSpace` | ENOSPC(28)/112 detection | Unchanged |
| FR-IMP-12 | Satisfied | `MatchRecord` | `originalPath`, `sourceBytes` | Unchanged |
| FR-IMP-13 | Satisfied | `ImportController.start` | `state.isRunning` single-flight | Unchanged |
| FR-IMP-14 | Satisfied | `ImportState.description`, screens | disabled Import + `ScProgressJob` | Unchanged |
| **FR-IMP-15 (G1)** | **Gap** | `RecordingStore`, `MatchRepository`, `ImportController`, `WorkspaceScreen`, `WorkspaceStudioScreen` | `takeCustody(expectedBytes, onProgress)`, `importVideo(onProgress)`, `ImportState.fraction` | §2.1–§2.4; `flutter analyze` + `tools/check-no-rust-in-app.sh` + code review; acceptance: `0%`–`100%` shown with stage label + Cancel in both surfaces |
| FR-IMP-16 | Satisfied | `sportcut_media::proxy` (service) | ≤540p `mpeg4` proxy | Existing engine suite; not re-run |
| FR-IMP-17 | Satisfied | `sportcut_media::audio` (service) | 16 kHz mono AAC → `audio/analysis.m4a` | Existing engine suite; not re-run |
| FR-IMP-18 | Satisfied | `pipeline.rs` (service) | skips audio when `!has_audio` | Existing engine suite; not re-run |
| FR-IMP-19 | Satisfied | `sportcut_media::frames` (service) | JPEG sampling, original timestamps | Existing engine suite; not re-run |
| FR-IMP-20 | Satisfied | `FrameSamplingOptions::validate` (service) | rate `> 0` and `≤ 30` | Existing engine suite; not re-run |
| FR-IMP-21 | Satisfied | `pipeline.rs` (service) | manifest records path/size/`Final` | Existing engine suite; not re-run |
| FR-IMP-22 | Satisfied | `pipeline.rs` (service) | interrupted stages → `NonFinal` | Existing engine suite; not re-run |
| FR-IMP-23 | Satisfied | `CheckpointStore` (service) | `checkpoints.json` resume | Existing engine suite; not re-run |
| FR-IMP-24 | Satisfied | `JobRegistry` (service) | one heavy job, one per match | Existing engine suite (`job_lifecycle.rs`); not re-run |
| FR-IMP-25 | Satisfied | `AnalysisController`, `WorkspaceStudioScreen` | stage strip + snackbar | Unchanged |
| FR-IMP-26 | Satisfied | `ArtifactManifest::record_artifact` (`core/entities/common/src/artifact.rs:191`, service) | downstream invalidation on record | Existing engine suite; not re-run |
| FR-IMP-27 | Satisfied | `AnalysisController.cancel` | `jobCancel` | Unchanged |
| FR-IMP-28 | Satisfied | `pipeline::regenerate_missing` (service) | rebuilds proxy/audio/frames only | Existing engine suite; not re-run |
| **FR-IMP-29 (G2)** | **Gap** | `AnalysisState`, `AnalysisPanel` | `rebuildableMissing`, `notRebuildableMissing`, guidance note | §2.5–§2.6; `flutter analyze` + code review; acceptance: Rebuild counts only rebuildable; note names each non-rebuildable artifact + producing stage |
| **FR-IMP-30 (G3)** | **Gap** | `ArtifactRows` / `_ArtifactRow` | local `READY`/`PARTIAL`/`MISSING` badge | §2.7; `flutter analyze` + code review; acceptance: word + icon + semantic colour per row, decimal size, path kept |
| FR-IMP-31 | Satisfied | `AnalysisPanel` | unprepared branch | Unchanged |
| FR-IMP-32 | Satisfied | `AnalysisController.open` | `problem` → `ScBanner` | Unchanged |
| FR-IMP-33 | Satisfied | `AnalysisPanel` | `busyElsewhere` disables | Unchanged |
| FR-IMP-34 | Satisfied | `AnalysisController._runJob` | failure → `problem`/`lastOutcome` | Unchanged |
| FR-IMP-35 | Satisfied | `core/use-cases/media` | local ffmpeg only | Existing `offline.rs`; not re-run |
| NFR-2 (determinate progress) | Gap (partially closed by G1) | as FR-IMP-15 | fraction `0.0..1.0` | Determinate bar lands. The BRD's "at least once per second" cadence is **not guaranteed** by percentage stepping (a copy slower than ~100 s can emit less often); a time-based heartbeat would contradict approved DD-1 (no timers), so the cadence and the large-file timing benchmark both remain open NFR-2 gaps and U5 keeps the BRD rows Partial |
| DS-6 (state words mono/uppercase, colour+icon) | Gap (with G3) | `_ArtifactRow` badge | chrome9 uppercase | §2.7 |
| DS-10 (plain-language guidance) | Gap (with G2) | `AnalysisPanel` note | xs12 muted text | §2.6 |
| **G4** BRD reconciliation | Gap | `docs/brd/02-...md`, `docs/brd/00-product-context.md` | status/evidence tables | §2.8, document diff review |

## 2. Component specifications

### 2.1 `RecordingStore` (G1) — `app/lib/src/features/library/data/recording_store.dart`

- **Responsibility**: unchanged (stream copy to `.part`, atomic rename,
  directory cleanup) **plus** determinate byte-progress reporting.
- **Interface** (matches API contract §2.1 exactly):

  ```dart
  Future<CustodiedRecording> takeCustody({
    required String matchId,
    required PickedVideo video,
    ImportCancelToken? cancelToken,
    int? expectedBytes,
    void Function(double fraction)? onProgress,
  });
  ```

- **`_copy` progress algorithm** (implements DD-1):
  1. Resolve `totalBytes`: use `expectedBytes` when non-null and `> 0`;
     otherwise `source.lengthSync()`.
  2. Before the first chunk: if `onProgress != null`, call `onProgress(0.0)`
     and set `lastPercent = 0`.
  3. Per chunk (dart:io default ~64 KiB from `source.openRead()`): keep the
     existing cancel check **before** `sink.add(chunk)`; then
     `copiedBytes += chunk.length`. When `totalBytes > 0`, compute
     `final double fraction = (copiedBytes / totalBytes).clamp(0.0, 1.0);`
     and `final int percent = (fraction * 100).round();` — call
     `onProgress(fraction)` only when `percent > lastPercent && percent < 100`,
     then set `lastPercent = percent`. The emitted value is the exact clamped
     ratio; the whole percent only gates emission. The `< 100` gate exists
     because the rounded percent reaches 100 at ratio ≈ 0.995 — without it the
     terminal `1.0` below would be suppressed on any multi-chunk copy (code
     review finding F1).
  4. Degenerate `totalBytes <= 0`: no division; only the `0.0` at start and
     `1.0` after flush are reported.
  5. After the loop and `sink.flush()`: call `onProgress(1.0)` whenever a
     callback was given — the in-loop gate guarantees this value is never a
     duplicate. The cap is `1 + ≤99 + 1 = 101` invocations per import
     (DD-1) and the terminal value is always exactly `1.0`.
- **State**: none added (local counters only).
- **Dependencies / configuration**: `MatchPaths` (recording directory),
  `PickedVideo`, `ImportCancelToken`, dart:io. No configuration is introduced.
- **Error handling**: the cancel path (`MatchImportException(kind:
  cancelled)`), the `FileSystemException` path (`_describe`, incl.
  `isOutOfSpace`), and `remove(matchId)` cleanup are unchanged **except** that
  cleanup is broadened: `onProgress` is caller-supplied code invoked inside
  the copy loop, so it is a new throw source (e.g. a Riverpod state set after
  disposal). `takeCustody` must therefore catch **`on Object`** around the
  copy/rename, `await remove(matchId)`, and rethrow (existing
  `MatchImportException` rethrow and `FileSystemException` → `_describe`
  mapping preserved as specializations of that cleanup). No exception may
  leave the match recording directory or a `.part` file behind
  (FR-IMP-09/BR-2 invariant). After a cancel, no further `onProgress` fires
  (the loop exits by throw before the flush/`1.0` step); early fractions
  **may** have fired before cancellation — callers must not assume
  `onProgress` is never called on the cancelled path.
- **Clamping**: the fraction is always clamped to `0.0..1.0`; the source file
  may grow/shrink between probe and copy, and the test fake reports
  `sizeBytes: 1024` for a 4 MiB fixture — clamping makes both harmless.
- **Callers**: exactly one (`MatchRepository.importVideo`).

### 2.2 `MatchLibrary` / `MatchRepository` (G1)

- `MatchLibrary.importVideo` (`domain/match_library.dart`) gains the optional
  named parameter `void Function(double fraction)? onProgress` (API contract
  §2.2). Optional ⇒ all existing call sites in `app/test/match_repository_test.dart`
  (12 sites) stay source-compatible.
- `MatchRepository.importVideo` threads it into custody:
  `_recordings.takeCustody(matchId: id, video: video, cancelToken: cancelToken,
  expectedBytes: metadata.sizeBytes, onProgress: onProgress)`.
  `metadata.sizeBytes` (from the pre-copy `_probe`) is the denominator;
  `MatchRecord.sourceBytes` continues to come from `CustodiedRecording.bytes`
  (post-copy `lengthSync()`) — unchanged coupling.
- **Both implementors must add the parameter**: `MatchRepository` and
  `FakeMatchLibrary` (`app/test/support/fake_match_library.dart:96`). The fake
  accepts and ignores `onProgress` (minimal change; existing widget tests keep
  their current expectations).
- All other repository behavior (readability check, probe, workspace
  resolution, cancel check, catalog-failure cleanup) is unchanged.
- **Dependencies / configuration**: `MediaEngine.probe` (service),
  `RecordingStore`, `MatchCatalog` (SQLite v5). No configuration introduced.

### 2.3 `ImportController` / `ImportState` (G1) — `presentation/import_controller.dart`

- `ImportState` gains `final double? fraction;` with constructor
  `const ImportState({this.phase = ImportPhase.idle, this.fraction, this.problem});`
  (API contract §2.3). No `copyWith` exists; construct instances directly.
- **Invariant**: `fraction != null` only while `phase == ImportPhase.importing`;
  `idle` and `picking` always carry `fraction: null`.
- `ImportController.start` changes:
  - On entering importing: `state = const ImportState(phase: ImportPhase.importing, fraction: 0.0);`
  - Pass `onProgress` to `repository.importVideo`; in the callback, only while
    `identical(_token, token)` and `state.phase == ImportPhase.importing`, set
    `state = ImportState(phase: ImportPhase.importing, fraction: f);`.
  - Failure path unchanged (`state = ImportState(problem: error)` — fraction
    resets to null). Cancellation stays silent.
  - The existing `finally` reset `state = ImportState(problem: state.problem)`
    already drops `fraction` back to null — a finished import never leaves a
    stale percentage. Do not "preserve" fraction there.
- Single-flight guard, `cancel()`, and provider shape unchanged.
- **Dependencies / configuration**: `videoFilePickerProvider`,
  `matchRepositoryProvider`, `ImportCancelToken`. No configuration introduced.

### 2.4 Progress UI wiring (G1) — no design-system changes

- `WorkspaceScreen` (`workspace_screen.dart:77`, inside the `ScProgressJob`
  call at lines 75-81): change hard-coded `fraction: null` to
  `fraction: import.fraction`. During `picking` this is null ⇒ empty track +
  stage label, identical to today.
- `WorkspaceStudioScreen` (`workspace_studio_screen.dart:186-193`): add
  `importFraction: import.fraction` to the `StudioShell` constructor call —
  the only missing link; `StudioShell.importFraction` →
  `VideoRail.importFraction` → `ScProgressJob.fraction` is already wired.
- `ScProgressJob`, `StudioShell`, `VideoRail`, `HomeToolbar`: **no changes**
  (`ScProgressJob` already clamps, renders `N%`, and respects reduced motion).

### 2.5 `AnalysisState` (G2) — `analysis_providers.dart`

- Add exactly the two computed getters from API contract §2.4:
  `rebuildableMissing` and `notRebuildableMissing`, partitioning `missing` by
  membership of `artifact.kind` in `manifest?.notRebuildableKinds ?? const []`
  (as a `Set`). Null-manifest safe ⇒ both return `const <ArtifactDto>[]`.
- `missing` is preserved unchanged (union). **No new fields** ⇒ `copyWith`,
  `_finish`, and the three construction sites are untouched.
- The engine is the source of truth for rebuildability
  (`REBUILDABLE_KINDS = proxy, analysis_audio, frames`); the client must not
  duplicate that list.
- **Dependencies / configuration**: `ArtifactManifestDto` / `ArtifactDto`
  (`bridge/models.dart`). Pure computed getters; no configuration introduced.

### 2.6 `AnalysisPanel` (G2) — `analysis_panel.dart`

- Rebuild button (lines ~113-126) switches from `state.missing` to
  `state.rebuildableMissing` for label, `enabled`, and `onPressed`:
  - Label: `'Nothing to rebuild'` when empty, else
    `'Rebuild ${n} missing ${n == 1 ? 'file' : 'files'}'`.
  - `enabled: rebuildable.isNotEmpty && !busyElsewhere`; `onPressed` null on
    the same condition, else `controller.repair(match)`.
  - Behavior compatibility: the test fakes report empty `notRebuildableKinds`,
    so `rebuildableMissing ≡ missing` under them and the literal strings
    `'Rebuild 2 missing files'` / `'Nothing to rebuild'` still render as
    before (see §3 Compatibility for the state of those test files).
- **Guidance note** for `notRebuildableMissing`, rendered inside the same
  idle/loaded/viewing `else` branch, after the Rebuild button (and after the
  `busyElsewhere` note when both apply): `SizedBox(height: tokens.space2)` +
  `Text(..., style: typography.xs12.copyWith(color: palette.muted))` — the
  established note pattern in this panel. It renders whenever
  `notRebuildableMissing.isNotEmpty`, **including when
  `rebuildableMissing.isEmpty`** (no contradictory "Nothing to rebuild"
  without explanation). Not rendered in the `running` / `unprepared` branches.
- Static kind → (display name, producing stage) mapping, with a safe fallback
  for unknown kinds (the engine's list may grow):

  | kind | display | producing stage |
  | --- | --- | --- |
  | `calibration` | court calibration | Mark court |
  | `tracks` | player tracks | Player analysis |
  | `rally_suggestions` | rally suggestions | Review & score |
  | `export` | export video | Export |
  | unknown | the kind string | "the stage that produces it" (generic wording, no stage named) |

- Note copy (plain language, DS-10), one sentence listing the items, e.g.:
  `Still missing, made by another stage: court calibration (Mark court), player tracks (Player analysis).`
  Implementation may polish wording within the FR-IMP-29 acceptance criterion.
- **Dependencies / configuration**: `analysisControllerProvider`,
  `AnalysisState` getters, `ScButton`, `ScBanner`, `SportcutTokens`/
  `SportcutTypography`/`SportcutPalette`. No configuration introduced.

### 2.7 `ArtifactRows` / `_ArtifactRow` (G3) — `artifact_rows.dart`

- Public `ArtifactRows({required List<ArtifactDto> artifacts})` is unchanged;
  `_ArtifactRow` stops delegating its status to `ScPipelineRow` and renders a
  **local status badge** (DD-3: local presentation mapping, precedent
  `StageStrip` / `ScVideoRow`; `ScStatus` and `ScPipelineRow` stay untouched
  for the studio pipeline rows). The row keeps the numbered layout and the
  path subtitle.
- Badge vocabulary and tokens (DS-6):

  | `ArtifactStateDto` | Word | Icon | Colour |
  | --- | --- | --- | --- |
  | `final_` | `READY` | `ScIcons.checkCircle` | `palette.success` |
  | `nonFinal` | `PARTIAL` | `ScIcons.warning` | `palette.warn` |
  | `missing` | `MISSING` | `ScIcons.blocked` | `palette.danger` |

  Word in `typography.chrome9`, uppercase, semantic colour; icon + word +
  colour together (never colour-only). `MISSING` keeps the current
  danger-coloured kind-name treatment for visual continuity.
- Row keeps: 24-px zero-padded mono number, ellipsized kind name, trailing
  decimal size via `formatBytes` (`timecode11`, muted; `'—'` when
  `sizeBytes == null`), one-line ellipsized `relativePath` (`micro10`, muted,
  indent `ScMetrics.courtHandleVisual + tokens.space3`), `ScMetrics.rowCompact`
  minimum height, `ScDivider` separators between rows (unchanged in
  `ArtifactRows`).
- The exhaustive `_status` → `ScStatus` switch is removed with the delegation,
  and the then-unused `sc_status.dart` / `sc_pipeline_row.dart` imports are
  removed from `artifact_rows.dart` so `flutter analyze` stays clean.
- **Dependencies / configuration**: `ArtifactDto`/`ArtifactStateDto`,
  `SportcutPalette`/`SportcutTokens`/`SportcutTypography`, `ScIcons`,
  `ScMetrics`, `ScDivider`, `formatBytes`
  (`features/library/presentation/formatters.dart`). No configuration
  introduced.

### 2.8 BRD reconciliation (G4) — `docs/brd/02-import-and-media-preparation.md`, `docs/brd/00-product-context.md`

Documentation-only, executed **after** G1–G3 land so evidence wording matches
reality. Both documents get a revision bump (Version 1.1, current date, source
baseline = the implementation commit). Must acceptance-criterion text is
**never edited** — a change to a Must row would trigger BRD-02 §10 change
control (recorded approval + quality-checklist re-run), which this intent does
not seek; all updates below are status/evidence/explanation cells only.

02 updates:
- §2.3: "Import progress percentage" → Done (fraction implemented; cite the
  files); "Rebuild count excludes artifacts the engine cannot rebuild" → Done;
  "Analysis view against the design components" → replace the stale
  Material-cards/DataTable/chip claim (components already conform since
  `757c748`; the FR-IMP-30 label vocabulary was the residue, now landed);
  "Progress on the UI isolate" stays **Partial** (no isolate move, no timing
  evidence, and the NFR-2 once-per-second cadence is not guaranteed by
  percentage stepping — §1 NFR-2 row); "App-owned copy" stays Done but
  explicitly interim per the ADR-0001 transport note.
- §3.1 FR-IMP-15 / §3.3 FR-IMP-29: drop the trailing "Not implemented at
  baseline" markers; **no other change to either acceptance cell** (the
  FR-IMP-29 example list stays as written; the authoritative kind → stage
  mapping including `rally_suggestions` is recorded in §2.6 of this spec and
  in the §4 state-coverage explanation text, not in the Must row).
- §4: "Import in flight" loading cell → determinate bar with whole-number
  percentage + stage label + Cancel; "Rebuild" row → N means *rebuildable*
  missing files, plus the non-rebuildable guidance state; "Analysis view" →
  artifact rows (not "Artifact table").
- §5: "Status labels" → state that artifact rows use a separate local
  `READY`/`PARTIAL`/`MISSING` vocabulary while the studio keeps
  `READY`/`ANALYZING n%`/`DONE`/`BLOCKED`/`NEEDS REVIEW` (BRD-09 untouched);
  "Type" → replace the stale 11-px-chip sentence with the actual badge style
  (chrome9 mono uppercase, colour + icon); "Banner versus toast" → split:
  analysis failures use `ScBanner` (already true), import failures use snack
  bars.
- §7: rows "Import progress percentage" and "Rebuild excludes non-rebuildable
  kinds" → implementation landed; verification recorded honestly as
  `flutter analyze` + `tools/check-no-rust-in-app.sh` + code review (no suite
  run per working agreement), status remains Not verified **or** cites a
  recorded manual run — never "Passed" without one; record that
  `analysis_screen_test.dart` and `library_screen_test.dart` already fail at
  baseline for unrelated UI-drift reasons (§3 Compatibility) so they cannot
  serve as regression evidence for this feature; state that NFR-7's test
  clause is waived by the working agreement; rewrite the closing paragraph to
  name the remaining evidence gaps (large-file timing, the once-per-second
  cadence, an analysis-suite repair/run) instead of "the two Not verified
  rows"; preamble baseline/date refreshed.
- §8.3: R-IMP-2 → mitigated by G2; R-IMP-1 → partially mitigated (determinate
  bar; timing half stays open). §8.4: close Q-IMP-4 as answered (byte-accurate
  counter); keep Q-IMP-1/2/3 open.
- §9: BR-8 owning-code pointer → `analysis_panel.dart` / `artifact_rows.dart`;
  BR-9 accessibility-audit gap kept (G3 changes visible labels).

00 updates:
- §3.3 row 2: remove the three closed gaps (indeterminate import progress,
  rebuild count ignoring `not_rebuildable_kinds`, Material analysis
  components); keep "no timing evidence for large copies"; overall status
  stays **Partial** (deferred service custody per ADR-0001 Phase 3–4, timing
  evidence). Keep all deferred-item text the survey flagged (transport note,
  §8.2 constraints, BR-2 traceability, 00 §15.1 rows, sqflite row).

## 3. Cross-cutting concerns

- **Security**: no new trust boundary. `onProgress` is a local Dart callback;
  because it is caller-supplied code running inside the copy loop, §2.1
  broadens `takeCustody` cleanup to `on Object` so a throwing callback cannot
  strand the recording directory or `.part` file. `expectedBytes` derives from
  the peer-UID-verified local service's probe with a `lengthSync()` fallback.
  `notRebuildableKinds` is consumed from the same local service; unknown kinds
  fall back safely (§2.6). Path sanitization (`_nameFor`), atomic `.part`
  handling, offline-only operation, and the never-touch-the-original
  guarantee are untouched (BR-1, BR-2, NFR-5). No new dependency ⇒ licensing
  register unchanged.
- **Performance budget**: ≤ 101 `onProgress` invocations per import (initial
  `0.0` + at most 99 in-loop steps for percents 1–99 + the terminal
  post-flush `1.0`) — matching the DD-1 cap — each an O(1) Riverpod state set
  (identity equality; no `==` needed).
  Per-chunk cost added to the copy: one integer addition and (at most) one
  division/round — no measurable throughput change; no timers, no isolates,
  no extra filesystem stats. Known limit: updates are emitted per percentage
  point, not per second (see §1 NFR-2 row).
- **Observability**: progress is user-visible only; no logging or telemetry
  is added (guardrail).
- **Data lifecycle**: `fraction` is transient in-memory UI state; no new
  durable client-owned state (ADR-0001 migration rule); service-owned state
  and the match-directory layout untouched.
- **Compatibility / test impact**: every signature change is an optional
  named parameter. Required companion edit: `FakeMatchLibrary.importVideo`
  (keeps implementing the interface). Behavior compatibility: the fakes report
  empty `notRebuildableKinds` (so `rebuildableMissing ≡ missing` and the
  rebuild-label strings are unchanged) and `fraction` stays null during
  `picking` (so the picking UI renders as today).
  **Baseline test health**: `app/test/analysis_screen_test.dart` (4 cases) and
  `app/test/library_screen_test.dart` (several cases) **already fail at HEAD
  `d33d123`** for reasons unrelated to this feature — `ScSectionHeader`
  uppercases labels ("Artifacts" vs "ARTIFACTS"), `ScButton` is not a
  `FilledButton`, and the "No matches yet" home screen was removed in
  `757c748`. They are therefore not cited as green regression evidence, and
  per the working agreement this intent does not repair their stale
  expectations; it only guarantees they still **compile** (no assertion or
  fixture in them references `ImportState.fraction`, `takeCustody`, or the
  artifact status words). If any existing test breaks at compile time it is
  fixed minimally; no new tests are written.

## 4. Work-breakdown seeds (Develop refines these)

| Unit | Content | Files | Depends on |
| --- | --- | --- | --- |
| U0 — hygiene | Commit the unrelated `protocol_client.dart` AF_UNIX fix separately, before feature work | `app/lib/src/bridge/protocol_client.dart` | — |
| U1 — G1 data/domain | `expectedBytes` + `onProgress` in custody (incl. `on Object` cleanup); interface threading; fake companion edit | `recording_store.dart`, `match_library.dart`, `match_repository.dart`, `app/test/support/fake_match_library.dart` | U0 |
| U2 — G1 presentation | `ImportState.fraction`, controller wiring, two screen call sites | `import_controller.dart`, `workspace_screen.dart`, `workspace_studio_screen.dart` | U1 |
| U3 — G2 | `rebuildableMissing` / `notRebuildableMissing` getters; Rebuild button source; guidance note + kind→stage map | `analysis_providers.dart`, `analysis_panel.dart` | — |
| U4 — G3 | local `READY`/`PARTIAL`/`MISSING` badge in `_ArtifactRow`; drop unused `sc_status.dart`/`sc_pipeline_row.dart` imports | `artifact_rows.dart` | — |
| U5 — G4 | BRD reconciliation + revision bumps (status/evidence only; Must rows untouched) | `docs/brd/02-import-and-media-preparation.md`, `docs/brd/00-product-context.md` | U1–U4 (evidence wording follows the landed code) |
| V — verification | `flutter analyze` in `app/` **and** `tools/check-no-rust-in-app.sh` | — | each unit as it lands |

U1→U2 is the only hard ordering among the feature units; U3 and U4 are
independent of everything and of each other; U5 is last.
