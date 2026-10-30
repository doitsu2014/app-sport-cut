# Requirements — Import and Media Preparation (Feature 2)

Status: Analyze / Requirements Analysis
Intent: `261030-implement-02-import`
Consumes: `../intent-capture/intent-statement.md`
Sources: `docs/brd/02-import-and-media-preparation.md` (§2, §3, §5, §6),
`docs/brd/00-product-context.md`, `HEAD` (`d33d123`).

## 1. Method

Every `FR-IMP` requirement (`FR-IMP-01` through `FR-IMP-35`) in BRD-02 §3 was
audited against the `HEAD` source (`d33d123`), covering `core/use-cases/media/`,
`core/use-cases/jobs/`, `core/gateways/storage/`, `core/adapters/api/`,
`app/lib/src/features/library/`, `app/lib/src/features/analysis/`, and
`app/lib/src/features/workspace/`.

Verdicts: **Satisfied**, **Gap**, **Deferred** (service custody deferred to
ADR-0001 Phase 3–4 per Intent Capture Q2-A).

## 2. Requirement audit

### 2.1 Picking and import entry (`FR-IMP-01` – `FR-IMP-15`)

| ID | Pri | Verdict | Evidence / gap |
| --- | --- | --- | --- |
| FR-IMP-01 | Must | Satisfied | `SystemVideoFilePicker.pickVideo` (`video_file_picker.dart:30`) calls `FilePicker.pickFiles(type: FileType.video)` and returns the first `PickedVideo(path, displayName)`. |
| FR-IMP-02 | Must | Satisfied | `ImportController.start` (`import_controller.dart:100`) returns `ImportDeclined` when `picked == null` or cancelled, writing nothing and showing no message. |
| FR-IMP-03 | Must | Satisfied | `SystemVideoFilePicker.pickVideo` wraps `PlatformException` in `MatchImportException(kind: MatchImportKind.pickerFailed)`; callers show the message. |
| FR-IMP-04 | Must | Satisfied | `MatchRepository._ensureReadable` (`match_repository.dart:322`) checks existence and opens a 1-byte read stream before probing; throws `MatchImportException` naming the file and reason. |
| FR-IMP-05 | Must | Satisfied | `sportcut_media::probe` (`core/use-cases/media/src/probe.rs`) reads duration, frame rate, width, height, rotation degrees, derived orientation, `has_audio`, and `size_bytes` via `ffprobe` without modifying the file. |
| FR-IMP-06 | Must | Satisfied | `sportcut_media::probe` rejects empty, non-regular, video-less, zero-duration, and invalid-fps inputs with specific `SportcutError::InvalidMedia` messages before `takeCustody` runs. |
| FR-IMP-07 | Must | Satisfied | `MatchRepository.importVideo` (`match_repository.dart:106-116`) runs `_ensureReadable` and `_probe` before `_recordings.takeCustody`. |
| FR-IMP-08 | Must | Satisfied | `RecordingStore.takeCustody` (`recording_store.dart:54-67`) streams chunks to `${destination.path}.part` and renames to `destination.path` only after flush and close. |
| FR-IMP-09 | Must | Satisfied | `RecordingStore._copy` checks `cancelToken?.isCancelled` between chunks, throws `MatchImportKind.cancelled`, and the `catch` block calls `remove(matchId)` to delete the recording directory before any catalog insert. |
| FR-IMP-10 | Must | Satisfied | `MatchRepository.importVideo` (`match_repository.dart:134-143`) catches catalog insert failure, calls `_recordings.remove(id)`, and throws `MatchImportKind.catalog`. |
| FR-IMP-11 | Must | Satisfied | `RecordingStore.isOutOfSpace` (`recording_store.dart:154`) detects `ENOSPC` (28) and `ERROR_DISK_FULL` (112), removes the directory, and reports not enough free space for the named file. |
| FR-IMP-12 | Must | Satisfied | `MatchRecord` stores `originalPath: video.path` and `sourceBytes: stored.bytes`; playback and analysis read `match.videoPath` (the stored copy). |
| FR-IMP-13 | Must | Satisfied | `ImportController.start` (`import_controller.dart:91`) returns `ImportDeclined` immediately when `state.isRunning` is true. |
| FR-IMP-14 | Must | Satisfied | `ImportState.description` reports phase labels; `VideoRail` and `WorkspaceScreen` disable the Import button while `import.isRunning` and render `ScProgressJob` with `onCancel`. |
| FR-IMP-15 | Must | **Gap (G1)** | `RecordingStore._copy` reports no byte progress, `ImportState` has no `fraction` field, and both `WorkspaceScreen` (`workspace_screen.dart:76`) and `WorkspaceStudioScreen` / `StudioShell` (`studio_shell.dart:65`, `video_rail.dart:238`) pass `null` for `importFraction`. |

### 2.2 Preparation job (`FR-IMP-16` – `FR-IMP-27`)

| ID | Pri | Verdict | Evidence / gap |
| --- | --- | --- | --- |
| FR-IMP-16 | Must | Satisfied | `sportcut_media::proxy` (`core/use-cases/media/src/proxy.rs`) produces a ≤540p `mpeg4` proxy preserving aspect ratio, used as the frame sampling input. |
| FR-IMP-17 | Must | Satisfied | `sportcut_media::audio` (`core/use-cases/media/src/audio.rs`) extracts 16 kHz mono AAC at 64 kbit/s to `audio/analysis.m4a`. |
| FR-IMP-18 | Must | Satisfied | `pipeline.rs` skips audio extraction when `!metadata.has_audio`, records no `analysis_audio` artifact, and completes cleanly. |
| FR-IMP-19 | Must | Satisfied | `sportcut_media::frames` (`core/use-cases/media/src/frames.rs`) samples JPEGs at the requested rate (default 1 fps, max 30 fps) with original timeline timestamps. |
| FR-IMP-20 | Must | Satisfied | `FrameSamplingOptions::validate` rejects non-finite, `<= 0`, or `> 30` sampling rates before running stages. |
| FR-IMP-21 | Must | Satisfied | `pipeline.rs` records `proxy`, `analysis_audio`, and `frames` in `manifest.json` with relative path, byte size, and `ArtifactState::Final` upon stage completion. |
| FR-IMP-22 | Must | Satisfied | On cancellation or interruption, `pipeline.rs` marks artifacts `ArtifactState::NonFinal`, and consumers ignore non-final entries. |
| FR-IMP-23 | Must | Satisfied | `CheckpointStore` (`core/use-cases/jobs/src/checkpoint.rs`) persists completed stages in `checkpoints.json`; `execute_admitted` skips completed stages on resume. |
| FR-IMP-24 | Must | Satisfied | `JobRegistry` (`core/use-cases/jobs/src/registry.rs`) enforces one heavy job and one job per match, naming the conflicting job and releasing the lease on drop. |
| FR-IMP-25 | Must | Satisfied | `AnalysisController` (`analysis_providers.dart`) is app-wide; `WorkspaceStudioScreen` shows stage progress on the stage strip/inspector and announces completion/failure via snackbar and in-panel `ScBanner`. |
| FR-IMP-26 | Must | Satisfied | `ArtifactManifest::record_final` (`core/entities/common/src/artifact.rs`) invalidates downstream artifacts (`Proxy` → forgets `Frames`, `Tracks`, `RallySuggestions`; `Frames` → forgets `Tracks`, `RallySuggestions`; `Tracks`/`AnalysisAudio` → forgets `RallySuggestions`). |
| FR-IMP-27 | Must | Satisfied | `AnalysisController.cancel` calls `mediaEngine.jobCancel(jobId)`; cancelled jobs end in `JobStateDto.cancelled` with no error banner. |

### 2.3 Regeneration, inspection, and errors (`FR-IMP-28` – `FR-IMP-35`)

| ID | Pri | Verdict | Evidence / gap |
| --- | --- | --- | --- |
| FR-IMP-28 | Must | Satisfied | `pipeline::regenerate_missing` (`core/use-cases/media/src/pipeline.rs`) rebuilds only missing `Proxy`, `AnalysisAudio`, and `Frames` from the recorded `original.path`, leaving present artifacts untouched. |
| FR-IMP-29 | Must | **Gap (G2)** | `ArtifactManifestDto` exposes `notRebuildableKinds`, but `AnalysisState.missing` (`analysis_providers.dart:103`) includes every artifact with `ArtifactStateDto.missing`. `AnalysisPanel` counts non-rebuildable artifacts in the "Rebuild N missing files" button and never reports which stage produces them. |
| FR-IMP-30 | Must | **Gap (G3)** | `ArtifactRows` (`artifact_rows.dart`) lists each artifact's kind, relative path, and decimal size using `ScPipelineRow`, but maps `ArtifactStateDto.final_` → `ScStatus.done` (an icon without the word `READY`), `nonFinal` → `NEEDS REVIEW` (instead of `PARTIAL`), and `missing` → `BLOCKED` (instead of `MISSING`). `FR-IMP-30` requires state labelled as `READY`, `PARTIAL`, or `MISSING`. |
| FR-IMP-31 | Must | Satisfied | `AnalysisPanel` (`analysis_panel.dart:78-112`) shows the explanation sentence and the `Start preparing analysis` button when `state.unprepared` is true. |
| FR-IMP-32 | Must | Satisfied | `AnalysisController.open` (`analysis_providers.dart:187-194`) catches manifest read errors and sets `state.problem`, which `AnalysisPanel` renders in `ScBanner` while keeping the studio usable. |
| FR-IMP-33 | Must | Satisfied | `AnalysisPanel` disables `Start preparing analysis` (`_BusyElsewhere`) and `Rebuild` when `busyElsewhere` is true, naming `state.runningTitle`. |
| FR-IMP-34 | Must | Satisfied | `AnalysisController._runJob` records the engine failure reason in `state.problem` (`ScBanner` in `AnalysisPanel`) and `lastOutcome`. |
| FR-IMP-35 | Must | Satisfied | `core/use-cases/media` invokes only local `ffmpeg`/`ffprobe` binaries on local paths; verified by `core/use-cases/media/tests/offline.rs`. |

## 3. In-scope gaps to implement

| Gap | Requirement | Type | Priority | Statement | Acceptance criterion | Verification |
| --- | --- | --- | --- | --- | --- | --- |
| G1 | FR-IMP-15, NFR-2 | Functional / NFR | Must | Import reports determinate byte-copy progress (`0.0..1.0`) with a stage label and percentage in both the studio video rail and workspace home. | When importing a recording, `ImportState.phase == ImportPhase.importing` starts with `fraction: 0.0`, updates `fraction` as chunks are written (`copiedBytes / totalBytes`), and `ScProgressJob` in `WorkspaceScreen` and `VideoRail` displays the percentage (`0%`–`100%`) alongside the stage label and Cancel action. | `flutter analyze`; code review of `recording_store.dart`, `match_repository.dart`, `import_controller.dart`, `workspace_screen.dart`, `workspace_studio_screen.dart`. |
| G2 | FR-IMP-29 | Functional | Must | The rebuild action counts only rebuildable missing media artifacts (`proxy`, `analysis_audio`, `frames`), and reports non-rebuildable missing artifacts (`calibration`, `tracks`, `rally_suggestions`, `export`) with the stage that produces each one. | When a manifest has missing artifacts, `AnalysisState.rebuildableMissing` excludes any kind listed in `manifest.notRebuildableKinds`. The Rebuild button label and enabled state use `rebuildableMissing.length` ("Nothing to rebuild" when 0). When `AnalysisState.notRebuildableMissing` is non-empty, `AnalysisPanel` displays a plain-language note naming each non-rebuildable artifact kind and the stage that produces it. | `flutter analyze`; code review of `analysis_providers.dart` and `analysis_panel.dart`. |
| G3 | FR-IMP-30 | Functional / DS | Must | Each row in `ArtifactRows` labels the artifact's state as `READY`, `PARTIAL`, or `MISSING` alongside its kind, relative path, and decimal byte size. | `ArtifactRows` renders `READY` for `ArtifactStateDto.final_`, `PARTIAL` for `ArtifactStateDto.nonFinal`, and `MISSING` for `ArtifactStateDto.missing` using tabular/mono chrome typography alongside the status icon/colour and decimal byte size. | `flutter analyze`; code review of `artifact_rows.dart`. |
| G4 | BRD-00 / BRD-02 | Documentation | Must | Reconcile `docs/brd/02-import-and-media-preparation.md` (§2.3, §3.1 FR-IMP-15, §3.3 FR-IMP-29, §7) and `docs/brd/00-product-context.md` (§3.3 row 2) with the implemented state on HEAD. | The BRD status tables accurately reflect that `FR-IMP-15`, `FR-IMP-29`, `FR-IMP-30`, and the design-system `AnalysisPanel` are implemented, while noting remaining deferred items (service custody in ADR-0001 Phase 3–4, large-file timing benchmark). | Document diff review. |

## 4. Traceability matrix

| Intent success criterion | Requirement IDs | Gap IDs | Target files |
| --- | --- | --- | --- |
| 1. All 35 `FR-IMP` requirements audited against HEAD | `FR-IMP-01` .. `FR-IMP-35` | — | `requirements.md` §2 |
| 2. Determinate import progress implemented | `FR-IMP-14`, `FR-IMP-15`, `NFR-2` | G1 | `recording_store.dart`, `match_library.dart`, `match_repository.dart`, `import_controller.dart`, `workspace_screen.dart`, `workspace_studio_screen.dart` |
| 2. Rebuild excludes `notRebuildableKinds` & names producing stage | `FR-IMP-28`, `FR-IMP-29` | G2 | `analysis_providers.dart`, `analysis_panel.dart` |
| 2. Artifact rows show `READY`, `PARTIAL`, `MISSING` state labels | `FR-IMP-30`, `DS-6` | G3 | `artifact_rows.dart` |
| 3. `flutter analyze` & `check-no-rust-in-app.sh` clean | `NFR-7`, `NFR-8` | G1–G3 | `app/`, `tools/check-no-rust-in-app.sh` |
| 4. BRD status tables reconciled | — | G4 | `docs/brd/02-import-and-media-preparation.md`, `docs/brd/00-product-context.md` |
