# Sportcut — Import and Media Preparation — Business Requirements Document

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-002 |
| Version | 1.0 |
| Status | Draft — for approval |
| Date | 2026-10-29 |
| Feature | Import and Media Preparation (area ID `IMP`) |
| Owner | Product owner |
| Contributors | Design lead, Engineering lead, QA lead, Security/privacy |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.0 |
| Shared contract | [00-product-context.md](00-product-context.md) |

## Related documents

- [Product BRD and shared contract](00-product-context.md) — objectives, BR, DS,
  NFR, risks, open questions. This document cites it and does not restate it.
  [BRD suite index](README.md).
- [DESIGN.md](../../design-system/DESIGN.md) §6 status and progress components,
  §8 voice, §10 studio shell; [USAGE.md](../../design-system/USAGE.md) status
  mapping and accessibility checklist;
  [tokens.css](../../design-system/tokens.css).
- Code: [`app/lib/src/features/library/`](../../app/lib/src/features/library/),
  [`app/lib/src/features/analysis/`](../../app/lib/src/features/analysis/),
  [`core/crates/media/`](../../core/crates/media/),
  [`core/crates/jobs/`](../../core/crates/jobs/),
  [`core/crates/storage/`](../../core/crates/storage/),
  [`core/crates/api/src/facade.rs`](../../core/crates/api/src/facade.rs).
- Prior verification at baseline `1541c64`, cited for provenance (not part of
  the working tree): `docs/verification/media-pipeline.md`,
  `docs/verification/video-import.md`,
  `docs/verification/processing-jobs.md`,
  `docs/architecture.md` (Analysis pipeline),
  `docs/data-storage-models.md` (Import custody, artifacts).

## Transport and ownership note (ADR-0001)

[ADR-0001](../adr/0001-rust-background-service.md) moves the recording copy,
catalog, and engine into the Rust background service. The Flutter client keeps
the picker and the UI; it sends the picked file over the
[Sportcut Service Protocol v1](../architecture/protocol.md) and holds no
recording custody afterward. This note supersedes "app-owned copy" and
client-written catalog wording below: the copy is **service-owned**, and the
catalog row is written by the service (with the Phase 3 interim described in
[migration-from-ffi.md](../architecture/migration-from-ffi.md#3-phased-plan)).
The user-facing import workflow, progress, cancellation, and acceptance
outcomes are unchanged.

The file handoff is one of two proofs: a security-scoped bookmark resolved by
the helper, or a one-file inbox handoff (`<uuid>.part` → `.ready`, SHA-256
verified by the service, deleted after custody). Exactly one ships; see
[background-service.md §7.3](../architecture/background-service.md#73-sandbox-file-handoff).
The service rules are in
[background-service.md §6.3](../architecture/background-service.md#63-recording-store)
and [protocol.md §6.1](../architecture/protocol.md#61-workspaces-and-matches).

## 1. Purpose, users, and relationship to the product BRD

This document fixes what happens between a user choosing a video file and
having analysis-ready media on disk: the picker, the probe, the service-owned
copy, the proxy, the analysis audio, the sampled frames, the manifest,
cancellation, and rebuilding what later went missing.

Users are the personas in [00 §4.1](00-product-context.md#41-user-personas). They
record a match on a phone or camera and expect the app to take custody of one
file and prepare it without asking anything technical. The cheapest failure the
product can offer is a fast, specific refusal of a file it cannot use.

This feature refines BR-1 (offline), BR-2 (custody), BR-8 and BR-9 (design and
accessibility), and BR-11 (recoverable jobs) from
[00 §6](00-product-context.md#6-shared-business-requirements). The library
surface that hosts these actions is owned by
[01](01-workspace-and-library.md); the shared job and settings model by
[09](09-studio-shell-jobs-and-settings.md). This document owns the media
pipeline and its client-facing job.

The autonomy level is inherited: preparation produces analysis inputs. It never
scores, never edits footage, and never modifies the user's original file.

## 2. Scope

### 2.1 In scope

- Local file picking for one video, and its cancel and failure paths.
- Probe metadata: duration, frame rate, stored size, rotation and orientation,
  audio presence, and byte size.
- The service-owned copy and non-destructive custody.
- Proxy generation, analysis audio extraction, and frame sampling.
- The artifact manifest and its final, non-final, and missing states.
- Import progress, single-flight admission, cancellation, and regeneration of
  missing media from the recording without re-importing.
- Rejection of unsupported, empty, truncated, or unreadable input.
- Interaction with the job registry: one heavy job, one job per match, resume
  from checkpoints.

### 2.2 Out of scope

Each item below requires a change request. None may enter silently.

- Court calibration, tracking, rally segmentation, scoring, highlights, and
  export; those are [03](03-court-calibration.md) to
  [08](08-export.md).
- Transcoding or normalising the recording into a delivery format. Preparation
  produces analysis inputs only.
- Importing several files, a folder, or a playlist at one time. Editing,
  trimming, or re-encoding the user's original file.
- Downloading models, fonts, or runtimes at import time (BR-1, NFR-10).
- A user-facing choice of proxy height, audio bitrate, or sampling rate above
  one frame per second in v1 (open question Q-IMP-3).
- Background import after the app quits, and queueing more than the single
  admitted job.

### 2.3 Current state at baseline

Status uses Done / Partial / Not started. Partial work is not rounded up.

| Capability | Status | Evidence and remaining gap |
| --- | --- | --- |
| File picking, cancel, picker failure | Done | [`video_file_picker.dart`](../../app/lib/src/features/library/data/video_file_picker.dart), [`import_controller.dart`](../../app/lib/src/features/library/presentation/import_controller.dart) |
| Probe and input rejection | Done | [`probe.rs`](../../core/crates/media/src/probe.rs), `core/crates/media/tests/media_pipeline.rs` |
| App-owned copy, atomic write, cancel cleanup | Done | [`recording_store.dart`](../../app/lib/src/features/library/data/recording_store.dart), `app/test/match_repository_test.dart` |
| Proxy, analysis audio, frames, manifest | Done | [`pipeline.rs`](../../core/crates/media/src/pipeline.rs), `core/crates/media/tests/media_pipeline.rs` |
| Job admission, checkpoints, resume, cancel | Done | [`registry.rs`](../../core/crates/jobs/src/registry.rs), [`checkpoint.rs`](../../core/crates/jobs/src/checkpoint.rs), `core/crates/jobs/tests/job_lifecycle.rs` |
| Regeneration of missing artifacts | Done | `pipeline.rs::regenerate_missing`, `core/crates/api/tests/facade.rs` |
| Import progress percentage | Not started | The bar is indeterminate and the copy reports no fraction ([`workspace_studio_screen.dart`](../../app/lib/src/features/workspace/presentation/workspace_studio_screen.dart)) |
| Rebuild count excludes artifacts the engine cannot rebuild | Not started | The view counts every missing artifact; the facade exposes `not_rebuildable_kinds` but the client never reads it |
| Analysis view against the design components | Partial | The view uses Material cards, a data table, and an ad-hoc chip rather than the design's pipeline row and progress job |
| Progress on the UI isolate | Partial | The copy streams with async file I/O and no isolate; no timing evidence exists |

## 3. Functional requirements

Priority is MoSCoW; a Must blocks release. Each row is one testable behavior.

### 3.1 Picking and import entry

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-IMP-01 | Pick one local video through the system picker | Must | Import opens the platform file chooser filtered to video files and returns the first chosen file with its path and display name |
| FR-IMP-02 | Cancel picking without side effects | Must | Closing the chooser creates no copy, no catalog row, and no message |
| FR-IMP-03 | Report a picker failure as a message | Must | A chooser that fails, for example on a missing file entitlement, shows one message naming the cause and leaves the library unchanged |
| FR-IMP-04 | Reject an unopenable file before probing | Must | A missing file, and a file that cannot be opened, produce a message naming the path and the reason, with no copy and no catalog record |
| FR-IMP-05 | Read metadata from the chosen file | Must | Probe returns duration, frame rate, stored width and height, rotation in degrees with a derived orientation and display size, audio presence, and byte size, without writing to the file |
| FR-IMP-06 | Reject unusable input with a specific reason | Must | An empty file, a non-regular file, a file with no video stream, no positive duration, or no derivable frame rate is reported with the file name and the reason, and the import stops before any copy |
| FR-IMP-07 | Copy only after a successful probe | Must | A file rejected by the probe leaves no copy, so a bad input never duplicates gigabytes |
| FR-IMP-08 | Stream the copy and publish it atomically | Must | The copy is written chunk by chunk to a `.part` file and renamed to its final name only when complete |
| FR-IMP-09 | Cancel a running copy and leave nothing behind | Must | The copy checks for cancellation between chunks, removes the match's recording directory on cancel, and writes no catalog record |
| FR-IMP-10 | Remove the copy when the catalog write fails | Must | A failed catalog insert removes the stored copy and reports that the match could not be saved |
| FR-IMP-11 | Classify and report a full device | Must | A write failing with `ENOSPC` or `ERROR_DISK_FULL` is reported as not enough free space, names the file, and leaves no partial copy |
| FR-IMP-12 | Record origin and size as metadata only | Must | The stored match keeps the picked path as origin and the copy size in bytes, and neither is ever read to play or analyse the match |
| FR-IMP-13 | Run one import at a time | Must | A second import request while one is in flight is declined and starts no second picker or copy |
| FR-IMP-14 | Show the import phase and a cancel action | Must | While importing, the studio shows the current phase, an Importing label on the disabled Import button, and a Cancel action that stops the copy |
| FR-IMP-15 | Show determinate import progress | Must | The import reports a fraction of bytes copied with a stage label and a percentage, and never shows an indeterminate bar for more than three seconds without a stage label (DESIGN.md §6). Not implemented at baseline |

### 3.2 Preparation job

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-IMP-16 | Produce a reduced-resolution proxy | Must | The proxy is at most 540 px tall, keeps the source aspect ratio, and is the sampling input for frames |
| FR-IMP-17 | Extract low-bitrate analysis audio | Must | A source with audio yields one mono AAC track at 16 kHz and 64 kbit/s under `audio/` |
| FR-IMP-18 | Continue without audio when the source has none | Must | A silent source completes the pipeline, records no analysis-audio artifact, and reports the absence rather than failing |
| FR-IMP-19 | Sample frames at the requested rate | Must | Frames are written as JPEGs at the requested samples per second, default one, capped at 30, each carrying its timestamp on the original recording timeline |
| FR-IMP-20 | Reject an invalid sampling rate before work | Must | A non-finite, zero, or negative rate is refused with a plain reason and no stage runs |
| FR-IMP-21 | Record every artifact in the manifest | Must | Each of proxy, analysis audio, and frames is recorded with its kind, relative path, size, and state under one match directory; an artifact becomes final only after its stage succeeds |
| FR-IMP-22 | Never consume partial output | Must | A cancelled or interrupted run marks every finished artifact non-final, and no non-final artifact is read as a result |
| FR-IMP-23 | Resume from checkpoints | Must | A stage recorded as complete in `checkpoints.json` is not re-executed, and a resumed run continues from the first incomplete stage |
| FR-IMP-24 | Admit one heavy job and one job per match | Must | A second job for the same match, or a second heavy job, is rejected with a message naming the running job, and the slot is released when the job ends, fails, or is cancelled |
| FR-IMP-25 | Run preparation in the background and announce the outcome | Must | The job keeps running when the user switches video or feature; the studio shows a busy marker on the video and stage, and one message states success, failure with a reason, or that the run stopped |
| FR-IMP-26 | Invalidate downstream artifacts on rebuild | Must | Recording a new proxy forgets frames, tracks, and rally suggestions; recording frames forgets tracks and suggestions; recording tracks or audio forgets suggestions |
| FR-IMP-27 | Cancel a running prepare or rebuild | Must | Cancel reaches the engine job, the job ends cancelled, and no final artifact is added; a cancelled run needs no explanatory error |

### 3.3 Regeneration, inspection, and errors

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-IMP-28 | Rebuild missing media without re-importing | Must | Regeneration reads the manifest, rebuilds only missing proxy, analysis audio, and frames from the recorded path, and leaves present artifacts untouched |
| FR-IMP-29 | Report what cannot be rebuilt | Must | Artifacts the pipeline cannot produce, such as a missing calibration, tracks, or export, are reported as still missing with the stage that produces them, and are not counted as repaired. Not implemented at baseline |
| FR-IMP-30 | List artifacts with a labelled state | Must | The analysis view lists each artifact with its kind, relative path, state as READY, PARTIAL, or MISSING, and size in decimal units |
| FR-IMP-31 | Offer a start action on an unprepared match | Must | A match with no artifacts shows one sentence about what preparation produces and a Start preparing analysis action |
| FR-IMP-32 | Report an unreadable manifest | Must | A manifest that cannot be read shows one message with the reason, and the rest of the studio stays usable |
| FR-IMP-33 | Refuse a repair when another job is running | Must | With another video's job in flight, the start action is disabled and the view names the running video |
| FR-IMP-34 | Report a failed job with the engine reason | Must | A failed stage reports the reason the engine gave, names the stage it failed in, and leaves the manifest readable |
| FR-IMP-35 | Keep every media stage local | Must | Probe, proxy, audio, and frames invoke only the local `ffmpeg` and `ffprobe` against local paths; no network call exists in the media crate (BR-1, NFR-1) |

## 4. State coverage

| Surface | Default | Loading | Empty | Error | Success | Disabled | Cancellation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Picker | Import action | "Choosing a recording…" | — | Message naming the picker cause | A file is returned | Second request declined | Nothing stored, no message |
| Import in flight | — | Phase label, bar, Cancel | — | Message naming file and reason | Match appears and is selected | Import button disabled, labelled Importing | Copy removed, no record, silent |
| Prepare, first time | Explanation plus Start | Stage label and progress | No artifacts yet | Reason plus match title | Manifest lists READY artifacts | Start disabled while another job runs | Job cancelled, artifacts non-final |
| Rebuild | Rebuild N missing files | Rebuild stage progress | "Nothing to rebuild" | Reason, artifacts unchanged | Missing media present again | Disabled with another job running | Nothing final added |
| Analysis view | Artifact table | Progress indicator until the manifest loads | "This match has no analysis files yet" | Manifest message | Labelled states and sizes | Start or rebuild disabled, naming a running job | — |

## 5. Design-contract specifics

The design system is a contract. These points bind this feature; the shared
requirements are DS-1 to DS-15 ([00 §7](00-product-context.md#7-shared-design-system-requirements)).

| Point | Source | Binding requirement for this feature |
| --- | --- | --- |
| Progress job | DESIGN.md §6 | Stage name, determinate bar, percentage, cancel. An indeterminate bar is allowed only up to three seconds and only with a stage label |
| Status labels | USAGE.md status mapping; DESIGN.md §6 | Ready is an accent dot and `READY`; running is a warning dot plus percentage and `ANALYZING 42%`; done is a success check and `DONE`; blocked is a danger icon and `BLOCKED`. A label always accompanies the colour |
| Banner versus toast | DESIGN.md §6; USAGE.md checklist | A persistent banner holds a failure until resolved; a toast is one line, four seconds, and never the only route to recovery. Import and preparation failures currently reach the user only through a snack bar |
| Voice | DESIGN.md §8; DS-10 | Name the file and the next action: "The recording is no longer at its original path.", "Preparing analysis · Sampling frames 42%". No exclamation marks, no anthropomorphism |
| Numbers | DESIGN.md §3, §8; DS-5, NFR-11 | Percentages read as whole numbers, sizes in decimal units (`1.4 GB`), durations as `0:42`, and all numerals are tabular in mono |
| Type | DESIGN.md §3; DS-6 | Mono micro-labels 10–12 px, uppercase, 0.08–0.12em tracking; 9 px only in dense chrome. The analysis view's state chip is 11 px with 0.4 px tracking and is not mono |
| Semantics | tokens.css | Warning `#8A5A00` light / `#E3B24E` dark while running; success `#157347` / `#57C98F` when done; danger `#B42318` / `#F27B70` for a failure; accent `#0E6E45` / `#46D08D` for the primary action only |
| Component shape | DESIGN.md §6, §10 | Use the pipeline row and progress job rather than Material list cards and a data table; the studio inspector is a work surface, not a dashboard |
| Accessibility | USAGE.md checklist; DS-15 | Cancel is a named control, the bar exposes a semantic value, the view survives 200% text scaling, and no critical text sits under window chrome |

## 6. Feature non-functional requirements

| Requirement | Shared ID | Acceptance criterion |
| --- | --- | --- |
| Offline preparation | NFR-1 | The whole pipeline completes with the proxy variables pointed at a discard port, and the media crate contains no network dependency or socket call |
| UI responsiveness during copy | NFR-2 | The library stays interactive while a multi-gigabyte copy runs, and progress updates at least once per second. No timing evidence exists at baseline |
| One heavy job, monotonic progress | NFR-2 | At most one heavy job runs; progress within a stage never decreases and resets only when the stage label changes |
| Crash safety | NFR-3 | Manifest and checkpoint writes are temp-file plus rename; a killed process leaves no artifact marked final and no half-written manifest |
| Data integrity | NFR-4 | Manifest schema 3 and checkpoint schema 1 are versioned; a manifest from a newer engine is refused with an explicit message rather than misread |
| Least privilege | NFR-5 | The macOS build requests read-only access to user-selected files; the picked file is read and never written |
| Testability | NFR-7 | Media stages are tested without Flutter, and the client view is tested against a fake engine; new behavior ships with a test |
| Engine independence | NFR-8 | `core/crates/media` and `core/crates/jobs` build and test with default features and no client toolchain |
| Actionable diagnostics | NFR-13 | Every failure names the file or match and the reason, and no diagnostic leaves the device. Sampling is capped at 30 frames per second so a long recording cannot fill the disk without bound |

## 7. Acceptance and verification evidence

Evidence is read at baseline `1541c64`. No suite was re-run on 2026-10-29: no
Flutter or Dart toolchain and no `ffmpeg` are installed here.

| Requirement group | Evidence | Result recorded |
| --- | --- | --- |
| Probe and input rejection | `core/crates/media/tests/media_pipeline.rs`: `probe_returns_metadata_for_a_readable_file`, `probe_reports_missing_truncated_and_non_media_inputs` | Passing at the `media-pipeline` baseline |
| Proxy and non-destructive custody | Same file: `proxy_is_reduced_in_resolution_and_leaves_the_original_untouched` | Passing |
| Audio, including a silent source | Same file: `audio_is_extracted_and_a_silent_pipeline_continues_without_it` | Passing |
| Frames and rate validation | Same file: `frames_are_sampled_at_the_requested_rate_with_original_timestamps`, `unsupported_and_invalid_sampling_rates_are_rejected` | Passing |
| Manifest, regeneration, cancellation, resume | Same file: `pipeline_writes_artifacts_under_one_directory_and_records_them`, `derived_artifacts_are_regenerable_without_re_importing`, `cancellation_marks_partial_artifacts_non_final`, `a_stage_recorded_as_complete_is_not_re_executed` | Passing |
| Offline | `core/crates/media/tests/offline.rs`: `pipeline_completes_with_network_access_unavailable`, `media_crate_contains_no_network_dependency_or_call` | Passing |
| Facade import, repair, cancel, refusal | `core/crates/api/tests/facade.rs`: `importing_through_the_facade_produces_the_contract_the_client_expects`, `a_match_missing_derived_artifacts_can_be_repaired_through_the_facade`, `a_source_without_audio_imports_and_reports_no_analysis_audio`, `an_unreadable_source_surfaces_an_error_instead_of_a_partial_match`, `a_cancelled_import_stops_and_leaves_nothing_final`, `a_conflicting_job_is_refused_by_name_and_the_slot_is_released` | Passing |
| Job lifecycle | `core/crates/jobs/tests/job_lifecycle.rs`: seven cases covering progress, completion, failure, resume, cancellation, same-match rejection, and heavy-slot release | Passing |
| Client import path | `app/test/match_repository_test.dart`: custody, missing file, unreadable codec, denied access, cancelled copy, unwritable copy, full device | Passing at the `video-import` baseline |
| Client analysis view | `app/test/analysis_screen_test.dart`: eleven cases including cancel, failure reason, unprepared match, and another job running | Passing at the `client-track` baseline |
| Import progress percentage | No test and no implementation | Not verified |
| Rebuild excludes non-rebuildable kinds | No test; the client ignores `not_rebuildable_kinds` | Not verified |

Acceptance for this document means every Must row has a named automated test or
a recorded manual run, and the two Not verified rows above gain one before the
feature is called Done again.

## 8. Dependencies, constraints, risks, and open questions

### 8.1 Dependencies

| Dependency | What this feature needs | Owner |
| --- | --- | --- |
| FFmpeg and ffprobe | Probe, proxy, audio, frame extraction | Engineering lead |
| `sportcut-media`, `sportcut-storage`, `sportcut-jobs` | Pipeline, manifest, checkpoints, admission | Engineering lead |
| Facade `start_import`, `start_regenerate_match_media`, `job_status`, `job_cancel` | Job handles and the frozen DTO contract | Engineering lead |
| [01 Library](01-workspace-and-library.md) | The studio that starts and shows the job | Engineering lead |

### 8.2 Constraints

- The media toolchain is the local `ffmpeg` and `ffprobe` pair; the development
  build is GPL-configured and not shippable (R-2, NFR-10). The original
  recording is referenced in place and never modified (BR-2).
- Manifest schema 3 and checkpoint schema 1 are stable; a newer schema is
  refused explicitly.
- One heavy job at a time and one job per match, with explicit rejection rather
  than a silent queue.
- The proxy must remain encoding-clean for an LGPL build; the proxy uses the
  built-in `mpeg4` encoder for that reason.

### 8.3 Risks

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-IMP-1 | A multi-gigabyte copy runs on the UI isolate without a progress fraction, so the app can appear frozen | Medium | High | Measure the copy against a large fixture; move chunking to a worker or add a byte counter and throttle the UI; add a determinate bar | Engineering lead |
| R-IMP-2 | The rebuild action counts artifacts the pipeline cannot rebuild, so a repair appears to fail silently | High | Medium | Filter the count by rebuildable kinds and name the stage that must produce the rest | Engineering lead |
| R-IMP-3 | Analysis audio is produced but segmentation still passes `audio = None`, so the artifact earns no accuracy | Medium | Medium | Wire the artifact into segmentation or state motion-only analysis as the v1 claim (shared R-5) | Engineering lead |
| R-IMP-4 | A job failure reaches the user only as a transient toast, with the view showing no persistent record | Medium | Medium | Add a banner in the analysis view that persists until acknowledged or retried | Design lead |
| R-IMP-5 | Free space is detected only from a failed write, after part of a large copy is written | Medium | Medium | Keep the failed-write classification, remove the partial copy, and state the reason; consider a pre-check later | Engineering lead |
| R-IMP-6 | No media toolchain is present on the verification machine, so the engine media suites cannot be re-run from this tree | High | Medium | Run the suites in CI or on a machine with `ffmpeg`; record the transcript against the baseline | QA lead |

### 8.4 Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-IMP-1 | Should import pre-check free space before copying? | Dart exposes no portable query, so a pre-check needs a platform call or a dependency | Engineering lead |
| Q-IMP-2 | Should regeneration name which kinds it rebuilt, not only which remain missing? | The engine returns both; the facade currently discards the rebuilt list | Product owner |
| Q-IMP-3 | Is one frame per second fixed for v1, or user-selectable? | The client always sends 1; the engine accepts up to 30 | Product owner |
| Q-IMP-4 | Is import progress required to be byte-accurate or stage-accurate? | Decides whether FR-IMP-15 needs a byte counter or a fixed set of phases | Design lead |

## 9. Traceability

| Business requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| BR-1 Offline and private | FR-IMP-35 | — | [`pipeline.rs`](../../core/crates/media/src/pipeline.rs), [`offline.rs`](../../core/crates/media/tests/offline.rs) | `offline.rs` |
| BR-2 Recording custody | FR-IMP-04 to FR-IMP-12 | DESIGN.md §6 | [`recording_store.dart`](../../app/lib/src/features/library/data/recording_store.dart), [`match_repository.dart`](../../app/lib/src/features/library/data/match_repository.dart) | `match_repository_test.dart` |
| BR-8 Design fidelity | FR-IMP-14, FR-IMP-15, FR-IMP-30 | DESIGN.md §6, §8, §10; USAGE.md | [`analysis_view.dart`](../../app/lib/src/features/analysis/presentation/analysis_view.dart) | `analysis_screen_test.dart` covers behavior, not visual contract |
| BR-9 Accessibility | FR-IMP-14, FR-IMP-30 | USAGE.md checklist | Analysis view and studio progress panel | Gap: no accessibility audit recorded |
| BR-11 Recoverable jobs | FR-IMP-21 to FR-IMP-27 | DESIGN.md §6 | [`registry.rs`](../../core/crates/jobs/src/registry.rs), [`checkpoint.rs`](../../core/crates/jobs/src/checkpoint.rs), [`analysis_providers.dart`](../../app/lib/src/features/analysis/presentation/analysis_providers.dart) | `job_lifecycle.rs`, `analysis_screen_test.dart` |
| NFR-1 Offline | FR-IMP-35 | — | [`toolchain.rs`](../../core/crates/media/src/toolchain.rs) | `offline.rs` |
| NFR-3 Crash safety | FR-IMP-08, FR-IMP-21, FR-IMP-22 | — | [`manifest.rs`](../../core/crates/storage/src/manifest.rs), [`checkpoint.rs`](../../core/crates/jobs/src/checkpoint.rs) | `media_pipeline.rs`, `job_lifecycle.rs` |
| NFR-4 Data integrity | FR-IMP-23, FR-IMP-26 | — | Manifest and checkpoint schemas | `media_pipeline.rs` |

## 10. Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |

---

**Change control.** A change to scope, a Must requirement, or the design contract
requires a version bump, a recorded approval decision, and a re-run of the BRD
quality checklist. This document inherits the baseline and version of
[00-product-context.md](00-product-context.md).
