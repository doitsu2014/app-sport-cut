# Sportcut — Workspace and Library — Business Requirements Document

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-001 |
| Version | 1.0 |
| Status | Draft — for approval |
| Date | 2026-10-29 |
| Feature | Workspace and Library (area ID `LIB`) |
| Owner | Product owner |
| Contributors | Design lead, Engineering lead, QA lead |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.0 |
| Shared contract | [00-product-context.md](00-product-context.md) |

## Related documents

- [Product BRD and shared contract](00-product-context.md) — objectives, BR, DS,
  NFR, risks, open questions. This document cites it and does not restate it.
  [BRD suite index](README.md).
- [DESIGN.md](../../design-system/DESIGN.md) §5, §6, §8, §10;
  [USAGE.md](../../design-system/USAGE.md) status mapping and accessibility
  checklist; [tokens.css](../../design-system/tokens.css).
- Code: [`app/lib/src/features/workspace/`](../../app/lib/src/features/workspace/),
  [`app/lib/src/features/library/`](../../app/lib/src/features/library/),
  [`app/lib/src/app/router.dart`](../../app/lib/src/app/router.dart),
  [`core/gateways/storage/`](../../core/gateways/storage/).
- Prior verification at baseline `1541c64`, cited for provenance (not part of
  the working tree): `docs/verification/video-import.md`,
  `docs/verification/client-track.md`, `docs/architecture.md`,
  `docs/data-storage-models.md`, `docs/features-roadmap.md`.

## Transport and ownership note (ADR-0001)

[ADR-0001](../adr/0001-rust-background-service.md) moves the catalog and
recording custody into the Rust background service. The Flutter client reaches
them only over the [Sportcut Service Protocol v1](../architecture/protocol.md)
and holds only an in-memory cache. This note supersedes the ownership and
transport wording below: "app-owned" recording or catalog language means
**service-owned**, and "local SQLite read" means one protocol read to the
service. The user-facing workflow, acceptance outcomes, and design contract are
unchanged.

Specifically superseded: FR-LIB-09 (now `library.workspace.update`), FR-LIB-12,
FR-LIB-15 (now `library.recording.relocate`), FR-LIB-23, FR-LIB-25, FR-LIB-30
to FR-LIB-37, the §6 catalog/availability NFR rows, the §8.2 constraint that
"the catalog is the app's", and Q-LIB-1. The service rules are in
[background-service.md §6](../architecture/background-service.md#7-data-ownership)
and [protocol.md §6](../architecture/protocol.md#8-method-table-catalog-and-recording-custody).

## 1. Purpose, users, and relationship to the product BRD

This document fixes what a user can do with workspaces, the match library, the
service-owned recording copy, and local playback. A workspace is a named, loose
group of recordings; it owns no artifacts of its own, and each video runs the
one-video pipeline
([`workspace.dart`](../../app/lib/src/features/workspace/domain/workspace.dart)).

Users are the personas in [00 §4.1](00-product-context.md#41-user-personas). They
need to open one workspace, find a recording quickly, see how far it has been
processed, and never lose the footage they recorded.

This feature refines BR-2 (recording custody), BR-7 (workspaces), BR-8 and BR-9
(design and accessibility), and BR-12 (macOS only) from
[00 §6](00-product-context.md#6-shared-business-requirements). Import mechanics
are owned by [02](02-import-and-media-preparation.md); shell chrome, keyboard,
focus mode, jobs, and settings by
[09](09-studio-shell-jobs-and-settings.md). This document owns the library
surfaces inside that shell. The autonomy level is inherited: the library shows
facts about files the user chose, and never infers, edits, or renames footage.

## 2. Scope

### 2.1 In scope

- The workspace home: list, create, open, delete, loading, empty, and error
  states.
- Entering a workspace into the three-pane studio: video rail, selection, the
  shared preview handoff, and the pipeline stage rail with done, ready, and
  idle states.
- The missing-recording state in the rail and what the preview does about it.
- Deleting one match or a whole workspace, with explicit artifact and recording
  choices, and never deleting the user's original file.
- Library search and filter, including its empty state.
- The service-owned SQLite catalog: schema version 6 adopting v5, ordered
  migrations, workspace membership, listing order, and cascade deletion.
- The service-owned recording copy: the recording store, non-destructive
  custody, sanitized names, and availability checks.
- Local playback of the service-owned copy: load, play, pause, seek, timecode,
  and the unplayable state.

### 2.2 Out of scope

Each item below requires a change request. None may enter silently.

- Workspace rename, reorder, or archival. Open question Q-8 in
  [00 §16](00-product-context.md#16-open-questions) decides whether this is v1.
- A cross-workspace or all-matches library view. The catalog query accepts a
  null workspace filter, but no screen offers it.
- Tags, favourites, ratings, custom sort order, or saved filters.
- Thumbnails rendered from the recording. The rail draws a static film icon in a
  fixed footage bed, not a decoded frame.
- Import of a folder, a playlist, or several files at once. Moving, renaming, or
  repairing the user's original file.
- Cloud sync, sharing, or any remote library (BR-1, BR-12).
- Import and preparation internals; see [02](02-import-and-media-preparation.md).

### 2.3 Current state at baseline

Status uses Done / Partial / Not started. Partial work is not rounded up.

| Capability | Status | Evidence and remaining gap |
| --- | --- | --- |
| Workspace home: list, create, open | Done | [`workspace_screen.dart`](../../app/lib/src/features/workspace/presentation/workspace_screen.dart), [`workspace_providers.dart`](../../app/lib/src/features/workspace/presentation/workspace_providers.dart) |
| Studio video rail, selection, stage strip, status bar | Done | [`workspace_studio_screen.dart`](../../app/lib/src/features/workspace/presentation/workspace_studio_screen.dart), [`stage_strip.dart`](../../app/lib/src/features/workspace/presentation/studio/stage_strip.dart), [`studio_status_bar.dart`](../../app/lib/src/features/workspace/presentation/studio/studio_status_bar.dart) — the status bar names the selected stage (FR-LIB-20) |
| Missing-recording row | Done | The rail shows the danger icon and "Recording missing", and the preview paints `ScMissingRecording`. ADR-0003 D8 deliberately offers no Locate action, superseding FR-LIB-15 |
| Delete match and workspace | Done | Delete dialogs and `MatchRepository.deleteMatch` / `deleteWorkspace`; deleting the selected video selects the next remaining one (FR-LIB-24) |
| Library search and filter | Done | [`video_rail.dart`](../../app/lib/src/features/workspace/presentation/studio/video_rail.dart) filters by title, counts matches, and offers Clear search on an empty result |
| Catalog schema v5 and migrations (baseline) | Done | [`match_catalog.dart`](../../app/lib/src/features/library/data/match_catalog.dart), `app/test/match_catalog_test.dart`; ADR-0001 target is service-owned v6 adopting v5 |
| Recording copy (baseline) | Done | [`recording_store.dart`](../../app/lib/src/features/library/data/recording_store.dart), `app/test/match_repository_test.dart`; ADR-0001 moves custody to the service |
| Local playback | Done | [`player_view.dart`](../../app/lib/src/features/library/presentation/player_view.dart), `app/test/player_screen_test.dart` |
| Automated tests for home and studio | Blocked | `app/test/library_screen_test.dart` and `app_shell_test.dart` assert the removed "No matches yet" screen; no widget test covers `WorkspaceScreen` or `WorkspaceStudioScreen`. The suites were not re-run on 2026-10-29 because no Flutter toolchain is installed on this machine (risk R-7) |

## 3. Functional requirements

Priority is MoSCoW; a Must is a release blocker. Each row is one behavior with
one observable acceptance criterion.

### 3.1 Workspace home

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-LIB-01 | List every workspace, oldest first, with its title | Must | Opening the app shows one row per stored workspace, ordered by creation time then title, and every row reads its stored title |
| FR-LIB-02 | Create a workspace from the home screen | Must | Choosing New workspace, typing a title, and confirming stores the workspace and opens its studio |
| FR-LIB-03 | Cancel workspace creation without side effects | Must | Cancelling the dialog stores no workspace and leaves the home list unchanged |
| FR-LIB-04 | Name an untitled workspace | Should | Confirming an empty or whitespace title stores the workspace as "Untitled workspace" and opens it |
| FR-LIB-05 | Show a loading state while workspaces load | Must | While the list is unresolved the home shows a progress indicator and no empty message |
| FR-LIB-06 | Report a failed workspace read with a retry | Must | A failing list read shows "The workspaces could not be read", the reason, and a Try again action that re-reads the list |
| FR-LIB-07 | Empty home names the next action | Must | With no workspaces the home shows one factual sentence and at least one action; New workspace creates one and Import a video imports into a newly created workspace |
| FR-LIB-08 | Delete a workspace with confirmation | Must | Deleting from the studio names the workspace in the dialog, removes its matches and its catalog row, returns to the home list, and never deletes the user's original files |
| FR-LIB-09 | Rename a workspace | Should | A rename action changes the title in place and the new title survives a restart. Served by `library.workspace.update` under ADR-0001. Not implemented at baseline |
| FR-LIB-10 | Search and filter the library | Must | Typing in the library search narrows the visible videos to matching titles, shows a count of matches, and shows an empty state with a clear action when nothing matches. Not implemented at baseline (DESIGN.md §10) |

### 3.2 Studio entry, video rail, and pipeline rail

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-LIB-11 | Show the workspace's videos in the left rail | Must | The rail lists every match in the workspace newest first, each row with title, duration or score, and resolution, and the header shows the count |
| FR-LIB-12 | Select a video and load it into the preview | Must | Selecting a rail row moves the selection to it, loads its service-owned recording (path from `library.recording.path`) into the shared preview, and resets the feature rail to Play |
| FR-LIB-13 | Select a first video automatically | Should | Opening a workspace with at least one video shows a video already selected and playing-ready without a user action |
| FR-LIB-14 | Mark a missing recording distinctly in the rail | Must | A match whose stored recording is absent or empty shows the alert icon and the words "Recording missing", not a duration, and the status bar counts it as missing |
| FR-LIB-15 | Replace the preview with a Locate state for a missing recording | Must | Selecting a match with a missing recording replaces the preview, disables transport and scoring, and offers one Locate action that re-adopts a chosen file after the user confirms. Served by the `library.recording.relocate` job under ADR-0001. Not implemented at baseline (DESIGN.md §10) |
| FR-LIB-16 | Empty studio offers import | Must | A workspace with no videos shows one sentence and one Import video action, and the action imports into that workspace |
| FR-LIB-17 | Report a failed video read with a retry | Must | A failing rail read shows "The videos could not be read", the reason, and Try again, which re-reads the rail |
| FR-LIB-18 | Report each pipeline stage as done, ready, or idle | Must | The feature rail shows a check for a stage whose output exists, a ready marker when its prerequisite is satisfied, and no marker otherwise; a stage stays selectable in every state and explains its own prerequisite |
| FR-LIB-19 | Report progress in the rail header | Should | The rail header shows the number of completed stages over the stage total, and the number changes after a stage output appears or disappears |
| FR-LIB-20 | State the local-only promise and export readiness | Must | The status bar states "On-device · No cloud", the video count, the missing count when non-zero, the selected score when one exists, the selected stage, and one readiness label among Checking, Needs a clip, Ready to export |

### 3.3 Deleting a match

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-LIB-21 | Confirm match deletion and name the object | Must | The dialog title names the action, the body names the video, and cancelling leaves the match, its artifacts, and its recording untouched |
| FR-LIB-22 | Offer artifact and recording deletion separately | Must | The dialog offers "Also delete analysis files" and "Also delete the stored recording copy", both unchecked by default, and each is honored independently |
| FR-LIB-23 | Keep the user's original file on any deletion | Must | Deleting a match with both options checked removes the catalog rows, the artifact directory, and the service-owned recording copy, and leaves the file at the recorded original path byte-identical. The service reports any file it could not remove in `deletedWithErrors` |
| FR-LIB-24 | Repair the selection after a deletion | Should | Deleting the selected video selects the next remaining video, and deleting the last one shows the empty studio state |

### 3.4 Catalog and recording custody

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-LIB-25 | Version the catalog schema | Must | The service-owned catalog opens at schema version 6 after adopting a v5 database, and a database at any older version reaches 6 by replaying every migration it missed in ascending order. The service reports the version in `service.hello` and `library.catalog.status` |
| FR-LIB-26 | Migrate existing matches into a workspace | Must | Opening a version-4 catalog that contains matches creates the workspace `default` titled "My videos" and assigns every match to it, preserving every row and column |
| FR-LIB-27 | Start a fresh install with no workspace | Should | A fresh install with no matches shows the new-workspace empty state rather than an empty default workspace |
| FR-LIB-28 | Fail loudly on a duplicate identifier | Should | Inserting a match or workspace whose identifier already exists raises an error and leaves the stored row unchanged |
| FR-LIB-29 | Delete a match's dependent records in one transaction | Must | Deleting a match removes its rallies, score events, clips, export settings, and suggestion decisions, or nothing at all |
| FR-LIB-30 | Store the service-owned copy, not the picked path | Must | A stored match's recorded video path points inside the service-owned recordings root, and the picked path is retained only as origin metadata. The service writes the path; the client never constructs it |
| FR-LIB-31 | Write the copy atomically | Must | The copy is streamed to a `.part` file and renamed only when complete; an interrupted copy never appears as a recording |
| FR-LIB-32 | Sanitize the stored file name | Must | The stored name contains no path separator or `..`, is bounded in length, and keeps a plausible extension; an unusable name falls back to `recording.mp4` |
| FR-LIB-33 | Report availability without failing later | Must | Availability is one stat per match, reported false for an absent, non-file, or zero-length recording, and the library lists such a match instead of failing the screen |

### 3.5 Local playback

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-LIB-34 | Play the service-owned recording locally | Must | Play starts playback, Pause stops it, seeking moves the playhead, and the position and duration read as `m:ss` with tabular numerals |
| FR-LIB-35 | Disable transport when playback cannot start | Must | An unplayable container or codec shows one message naming the cause, keeps the match in the library, and leaves Play and the seek control disabled |
| FR-LIB-36 | Offer the full transport set | Should | The transport offers play or pause, ±5 s, volume, and a tabular timecode, with icon-only controls named for assistive technology. ±5 s and volume are not implemented at baseline (DESIGN.md §6) |
| FR-LIB-37 | Read only the service-owned copy during playback | Must | Playback opens the stored video path returned by `library.recording.path`; changing or removing the original file after import does not affect playback |

## 4. State coverage

| Surface | Default | Loading | Empty | Error | Success | Disabled | Cancellation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Workspace home | List of workspaces | Progress indicator | "No workspaces yet" plus actions | Message with the reason and Try again | New workspace opens its studio | Create needs a dialog; Cancel closes it | Cancel creates nothing |
| Studio video rail | Rows newest first, first selected | Progress indicator | "No videos in this workspace" plus Import video | "The videos could not be read" plus Try again | Imported video appears and is selected | Import shows a busy label and is not tappable | A cancelled import changes nothing |
| Missing recording | Rail row with alert icon and "Recording missing" | — | — | Missing count in the status bar | — | Transport and scoring disabled (not implemented) | Locate cancel keeps the match as it was (not implemented) |
| Pipeline rail | Seven stages with markers | Busy spinner on a running stage | Header reads 0 of the total with no video | Stage opens and explains its own prerequisite | Check appears when the output exists | — | Cancelled job returns the stage to ready |
| Playback | Frame with transport | Loading surface until ready | Black frame before load | Cause message, transport disabled | Play, pause, seek | Play and seek disabled until ready | — |

## 5. Design-contract specifics

The design system is a contract. These points bind this feature; the shared
requirements are DS-1 to DS-15 ([00 §7](00-product-context.md#7-shared-design-system-requirements)).

| Point | Source | Binding requirement for this feature |
| --- | --- | --- |
| Three-pane geometry | DESIGN.md §5, §10; tokens.css `--space-*`, 264/320 widths | The video rail is 264 px and the feature rail 320 px, mapped as `SportcutTokens.videoRailWidth` and `featureRailWidth`; the preview never drops below 480 px, and rails collapse below 980 px of available width |
| Window chrome | DESIGN.md §10; tokens.css | The toolbar is 52 px and the status bar 30 px, mapped as `chromeHeight` and `statusHeight`; no in-app theme switch |
| Selection | DESIGN.md §5, §10 | A selected rail item uses the raised surface plus a ring and an explicit check or label; it never uses an accent left bar or a filled accent block |
| Signal discipline | DESIGN.md §2; DS-3 | At most one accent-coloured element per pane. At baseline the feature rail can show an accent ready dot on several rows, and the empty home shows an accent icon beside an accent primary button; both need reconciling |
| Match row | DESIGN.md §6 | 64×36 thumbnail, one-line title with ellipsis, metadata, and a tabular score. At baseline the rail thumb is 52×30 and the score is not set in tabular figures |
| Empty state | DESIGN.md §6 | One factual sentence and one action. At baseline the home offers two actions and the studio copy is close to the contract |
| Destructive actions | DESIGN.md §5, §9; USAGE.md Do list | Destructive actions name the object and sit apart from the confirming action. At baseline the dialog names the video in the body and the button reads Delete |
| Banner versus toast | DESIGN.md §6; USAGE.md checklist | A toast is transient and is never the only route to recovery. Import and delete results currently reach the user only through a snack bar |
| Voice | DESIGN.md §8; DS-10 | Short, factual, verb-first; the missing state reads "Recording missing"; counts read `12 clips · 4:38`, scores `18–16` |
| Type floors | DESIGN.md §3; DS-6 | Body ≥16 px, sentence text ≥12 px, mono micro-labels ≥10 px, 9 px only in dense chrome. Status and chip labels at baseline use 9–11 px |
| Tokens | tokens.css | Ground `#F1F3EF` light / `#0B100D` dark; surface `#FFFFFF` / `#121814`; recessed `#E8ECE7` / `#182019`; hairline `#DFE5DF` / `#1E2721`; signal `#0E6E45` / `#46D08D`; danger `#B42318` / `#F27B70`; radii 6/10/14/pill |
| Accessibility | USAGE.md checklist; DS-15 | Every icon-only control has a tooltip and a semantic label; focus is a 2 px surface gap plus a 2 px accent ring; rows and dialogs survive 200% text scaling |

## 6. Feature non-functional requirements

| Requirement | Shared ID | Acceptance criterion |
| --- | --- | --- |
| Catalog reads stay local | NFR-1, NFR-4 | Every library query is one protocol read to the service and one SQLite read inside it; no network call exists on any library path |
| The rail does not block on engine work | NFR-2 | The video rail resolves from the catalog and an availability stat alone; pipeline facts load separately and never delay the first rail paint |
| Per-video engine reads are bounded | NFR-2 | Pipeline facts read one manifest per match per invalidation, not per rebuild; a workspace of N videos costs N manifest reads and one invalidation per completed stage |
| Stored data survives upgrade | NFR-4 | Service migration from any earlier schema to v6 preserves matches, rallies, scores, clips, export settings, and decisions; v5 adoption is a cancellable, resumable job |
| File deletion is ordered and reported | NFR-3 | Deleting a match removes catalog rows in one transaction and then removes files; a file failure is reported in `deletedWithErrors` and the catalog never keeps a row pointing at a file the caller asked to delete |
| Client errors are actionable | NFR-13 | Every library error names the video or workspace and the reason, and stays on the device |
| Engine independence | NFR-8 | The library path builds and tests with the engine crates alone; catalog and recording-store tests need no Flutter or Xcode. Availability costs one stat per match, and no frame is decoded to draw a rail row |

## 7. Acceptance and verification evidence

Evidence is read at baseline `1541c64`. No suite was re-run on 2026-10-29: no
Flutter or Dart toolchain is installed here.

| Requirement group | Evidence | Result recorded |
| --- | --- | --- |
| Catalog schema, migrations, cascade | `app/test/match_catalog_test.dart`: `the initial schema contains the product data model`, `a schema change is applied as a migration and existing matches survive`, `an install written before the editing records migrates in place`, `deleting a match removes its dependent records` | Passing at the `video-import` baseline |
| Workspace migration v5 | Schema and migration code in [`match_catalog.dart`](../../app/lib/src/features/library/data/match_catalog.dart); no test asserts the v5 default workspace | Gap: migration v5 is unverified by a test |
| Custody, availability, deletion | `app/test/match_repository_test.dart`: `import takes custody of the picked recording`, `the app-owned copy outlives the file the picker returned`, `a match whose recording has gone is reported unavailable`, `deleting a match keeps what it owns unless asked to remove it` | Passing at the `video-import` baseline |
| Playback | `app/test/player_screen_test.dart`: `loads the recording and shows transport controls`, `play and pause go through the controller`, `scrubbing the slider seeks and updates the position display`, `an unplayable recording is reported and controls are disabled` | Passing at the `client-track` baseline |
| Formatting | `app/test/formatters_test.dart`: duration, date, position, size, summary cases | Passing at the `client-track` baseline |
| Home and studio widgets | `app/test/library_screen_test.dart` (14 cases) and `app_shell_test.dart` assert "No matches yet", which `WorkspaceScreen` no longer renders | Stale: the assertions target a removed screen, so they cannot pass against current code |
| Search, Locate, rename, ±5 s and volume | No test and no implementation | Not verified |

Acceptance for this document means: the Must rows above have a named automated
test or a recorded manual run, and the stale home and shell tests are either
repaired against the workspace home or deleted with their replacement test
recorded.

## 8. Dependencies, constraints, risks, and open questions

### 8.1 Dependencies

| Dependency | What this feature needs | Owner |
| --- | --- | --- |
| Service catalog via the protocol (`library.*`) | Listing, workspace create/rename/delete, match update/delete, availability, recording path/relocate | Engineering lead |
| Service protocol client (`app/lib/src/protocol/`) | Request/response, notifications, reconnect, in-memory cache invalidation | Engineering lead |
| Engine facade `engine.manifest` | Pipeline stage facts per video | Engineering lead |
| Playback backend (`video_player`) | Local file playback and aspect ratio | Engineering lead |
| [02 Import](02-import-and-media-preparation.md) | The copy that custody records | Engineering lead |

### 8.2 Constraints

- macOS only; minimum window 1100×720; rails collapse before the preview
  (BR-12, DS-14).
- The catalog and recording store are the service's; the client holds an
  in-memory cache and owns no artifact files. Schema versions are stable
  history and migrations are additive (NFR-4,
  [00 §10](00-product-context.md#10-constraints)).
- The user's original file is never modified, moved, renamed, or deleted; the
  service copies it into its recording store (BR-2).

### 8.3 Risks

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-LIB-1 | Stale home and shell tests hide regressions in the workspace home | High | Medium | Rewrite the tests against the workspace home; add widget tests for the studio | QA lead |
| R-LIB-2 | Deleting a match removes catalog rows before files, so a file failure leaves orphaned artifacts | Medium | Medium | Return `deletedWithErrors` with every orphan path and reason, sweep orphans on a later pass, and test the disk-error path | Engineering lead |
| R-LIB-3 | Pipeline facts cost one manifest read per video per invalidation and grow with workspace size | Medium | Medium | Read facts lazily per selected video, or batch the manifest read across a workspace | Engineering lead |
| R-LIB-4 | Missing-recording handling stops at a label, so a user cannot recover a moved file | High | High | Implement the Locate state, re-adopt the file, and disable dependent stages until then | Product owner |
| R-LIB-5 | Accent overuse and off-contract row metrics drift from the tokens | Medium | Medium | Token and state review before release; reconcile the ready dot, empty-state icon, thumbnail size, and tabular scores | Design lead |
| R-LIB-6 | No search makes a large workspace unusable, contrary to DESIGN.md §10 | Medium | High | Implement search with an empty state and a count | Product owner |

### 8.4 Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-LIB-1 | Does Locate copy the chosen file again, or re-point the stored path to the user's file? | Decides whether custody stays service-owned after a repair. ADR-0001 makes the service the owner, so the default is a fresh service-owned copy through `library.recording.relocate`; a re-point would make the user's file load-bearing again | Engineering lead |
| Q-LIB-2 | Does search match titles only, or titles plus metadata such as score and date? | Shapes the query and the result copy | Product owner |
| Q-LIB-3 | Is workspace rename in v1? | Inherited from Q-8; affects FR-LIB-09 | Product owner |

## 9. Traceability

| Business requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| BR-2 Recording custody | FR-LIB-30 to FR-LIB-33, FR-LIB-37 | DESIGN.md §6 | [`recording_store.dart`](../../app/lib/src/features/library/data/recording_store.dart), [`match_repository.dart`](../../app/lib/src/features/library/data/match_repository.dart) | `match_repository_test.dart` |
| BR-7 Workspaces | FR-LIB-01 to FR-LIB-04, FR-LIB-08, FR-LIB-25 to FR-LIB-27 | DESIGN.md §5, §10 | [`workspace_screen.dart`](../../app/lib/src/features/workspace/presentation/workspace_screen.dart), [`match_catalog.dart`](../../app/lib/src/features/library/data/match_catalog.dart) | `match_catalog_test.dart` |
| BR-8 Design fidelity | FR-LIB-11 to FR-LIB-20 | DESIGN.md §2, §5, §6, §10 | [`workspace_studio_screen.dart`](../../app/lib/src/features/workspace/presentation/workspace_studio_screen.dart) | Gap: no studio widget test |
| BR-9 Accessibility | FR-LIB-20, FR-LIB-36 | USAGE.md checklist | Playback and rail controls | Gap: no accessibility audit recorded |
| BR-12 macOS focus | All | DESIGN.md §10 | [`router.dart`](../../app/lib/src/app/router.dart) | `app_shell_test.dart` route cases |
| NFR-4 Data integrity | FR-LIB-25 to FR-LIB-29 | — | [`match_catalog.dart`](../../app/lib/src/features/library/data/match_catalog.dart) | `match_catalog_test.dart` |

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
