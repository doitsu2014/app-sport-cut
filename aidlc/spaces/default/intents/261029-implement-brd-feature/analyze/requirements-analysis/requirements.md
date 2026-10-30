# Requirements — Workspace and Library (Feature 1)

Status: Analyze / Requirements Analysis
Intent: `261029-implement-brd-feature`
Consumes: `../intent-capture/intent-statement.md`
Sources: `docs/brd/01-workspace-and-library.md` (§2, §3),
`docs/brd/00-product-context.md`, `docs/adr/0003-studio-shell-refactor.md`,
HEAD `c8beacf`.

## 1. Method

Every `FR-LIB` requirement in BRD-01 §3 was checked against the HEAD source,
not against the BRD's baseline status table (which cites `1541c64`). Each row
records the verdict, the evidence, and — where unmet — whether the gap is in
scope for this intent.

Verdicts: **Satisfied**, **Gap**, **Superseded** (an ADR or a later BRD decision
replaces the requirement), **Deferred** (in scope in principle, explicitly
pushed to ADR-0001 Phase 4 by this intent's Q2 answer), **Out of scope** (BRD-01
§2.2 or open question Q-8).

## 2. Requirement audit

### 2.1 Workspace home

| ID | Pri | Verdict | Evidence / gap |
| --- | --- | --- | --- |
| FR-LIB-01 | Must | Satisfied | `MatchCatalog.listWorkspaces` orders `created_at ASC, title ASC`; `WorkspaceScreen._list` renders one row per workspace with its title. |
| FR-LIB-02 | Must | Satisfied | `WorkspaceScreen._createWorkspace` → `showNewWorkspaceDialog` → `createWorkspace` → `_openWorkspace`. |
| FR-LIB-03 | Must | Satisfied | A null dialog result returns before any write (`workspace_screen.dart:211`). |
| FR-LIB-04 | Should | Satisfied | `MatchRepository._workspaceTitleFor` returns `Untitled workspace` for blank input. |
| FR-LIB-05 | Must | **Gap (G2)** | `WorkspaceScreen._body` loading branch paints `ScEmptyState(message: 'Reading workspaces…', icon: running)`; no progress indicator. |
| FR-LIB-06 | Must | **Gap (G3)** | `WorkspaceScreen._body` error branch names the failure and offers Retry, but omits the reason the acceptance criterion requires. |
| FR-LIB-07 | Must | Satisfied | Empty home offers New workspace; `MatchRepository._ensureWorkspaceId` creates a workspace when an import has no home, so Import on an empty home works. |
| FR-LIB-08 | Must | Satisfied | `showDeleteWorkspaceDialog` names the workspace; `deleteWorkspace` deletes matches then the row; originals are never touched. |
| FR-LIB-09 | Should | Out of scope | BRD-01 §2.2 and open question Q-8 exclude rename/reorder from v1. |
| FR-LIB-10 | Must | Satisfied | `VideoRail` filters by title, shows `ScSectionLabel(count: visible.length)`, and renders a search-empty state with Clear search. |

### 2.2 Studio entry, video rail, and pipeline rail

| ID | Pri | Verdict | Evidence / gap |
| --- | --- | --- | --- |
| FR-LIB-11 | Must | Satisfied | `MatchCatalog.listMatches` orders `created_at DESC`; `ScVideoRow` shows title, `resolution · duration`, score; header shows the count. |
| FR-LIB-12 | Must | Satisfied | `_selectVideo` loads `match.videoPath` into the shared controller and calls `selectStage(null)`. |
| FR-LIB-13 | Should | Satisfied | `_ensureSelection` selects the first entry after the first frame. |
| FR-LIB-14 | Must | Satisfied | `ScVideoRow(missing: …)` words the absence; `StudioStatusBar` counts missing. |
| FR-LIB-15 | Must | Superseded | ADR-0003 D8: an honest missing state with no relocate action. `VideoPreview` paints `ScMissingRecording` and the transport is absent. |
| FR-LIB-16 | Must | Satisfied | `VideoRail._body` empty branch offers Import video into the workspace. |
| FR-LIB-17 | Must | Satisfied | `VideoRail._body` error branch names the reason and offers Try again. |
| FR-LIB-18 | Must | Satisfied | `StageStrip` marks done/ready/blocked (idle guidance) and keeps every tab selectable. |
| FR-LIB-19 | Should | Superseded | The persistent pipeline rail was replaced by the 40 px stage strip (ADR-0003 D2/D14); a completed/total count no longer has a rail header to live in. Recorded as a question, not silently dropped. |
| FR-LIB-20 | Must | **Gap (G1)** | `StudioStatusBar` shows the on-device promise, video count, missing count, score, and readiness, but not the selected stage. |

### 2.3 Deleting a match

| ID | Pri | Verdict | Evidence / gap |
| --- | --- | --- | --- |
| FR-LIB-21 | Must | Satisfied | `DeleteMatchDialog` names the action and the video; cancel returns null and writes nothing. |
| FR-LIB-22 | Must | Satisfied | Both options render unchecked by default and are passed through independently. |
| FR-LIB-23 | Must | Satisfied | `deleteMatch` removes catalog rows, optional artifacts, and optional app-owned copy; `original_path` is never used for deletion. (`deletedWithErrors` is a service-protocol field; the client path has no service yet.) |
| FR-LIB-24 | Should | **Gap (G4)** | After deleting the selected match, `_ensureSelection` falls back to the first entry, not the next remaining video the criterion names. |

### 2.4 Catalog and recording custody

| ID | Pri | Verdict | Evidence / gap |
| --- | --- | --- | --- |
| FR-LIB-25 | Must | Deferred | Client catalog is at schema 5 with ordered migrations; v6 is ADR-0001 Phase 4 (Q2-A). |
| FR-LIB-26 | Must | Satisfied | Migration 5 creates `default` / "My videos" only when matches exist and assigns every row. |
| FR-LIB-27 | Should | Satisfied | Migration 5 creates no workspace on an empty database. |
| FR-LIB-28 | Should | Satisfied | `ConflictAlgorithm.abort` on match and workspace insert. |
| FR-LIB-29 | Must | Satisfied | `MatchCatalog.deleteMatch` deletes decisions, clips, score events, rallies, export settings, and the match in one transaction. |
| FR-LIB-30 | Must | Deferred | The app-owned copy is stored and the picked path kept only as `original_path`; service ownership is ADR-0001 Phase 4. |
| FR-LIB-31 | Must | Satisfied | `RecordingStore.takeCustody` streams to `.part` and renames on completion. |
| FR-LIB-32 | Must | Satisfied | `_nameFor` strips separators and `..`, bounds the base at 80 chars, keeps a plausible extension, and falls back to `recording.mp4`. |
| FR-LIB-33 | Must | Satisfied | `RecordingStore.isAvailable` is one stat; false for absent, non-file, or zero-length. |

### 2.5 Local playback

| ID | Pri | Verdict | Evidence / gap |
| --- | --- | --- | --- |
| FR-LIB-34 | Must | Satisfied | `PlaybackController` play/pause/seek; `formatPosition` renders `m:ss` with tabular figures. |
| FR-LIB-35 | Must | Satisfied | `PlayerView` shows `_PlaybackProblem` and disables Play and the seek control when `error != null`. |
| FR-LIB-36 | Should | Superseded / satisfied | `ScTransport` offers play/pause, ±5 s, a scrubber, and tabular timecodes with named icon-only controls. Volume is deferred by ADR-0003 D12 (no volume API). |
| FR-LIB-37 | Must | Satisfied | Playback loads `match.videoPath` (the app-owned copy); `original_path` is never opened. |

## 3. In-scope gaps to implement

| Gap | Requirements | Priority | Statement | Acceptance criterion | Verification |
| --- | --- | --- | --- | --- | --- |
| G1 | FR-LIB-20 (and FR-SHL-14) | Must | The studio status bar reports the selected stage beside the ready label. | Selecting a stage changes the status bar's stage text to that stage's label; Play reads as Play. | `flutter analyze`; visual check in the studio. |
| G2 | FR-LIB-05 | Must | The home loading state shows a progress indicator and no empty message. | While the workspace list is unresolved, a progress indicator is visible and no "No workspaces yet." text appears. | `flutter analyze`; visual check. |
| G3 | FR-LIB-06 | Must | The home read error names the reason as well as the failure. | A failing read shows "The workspaces could not be read.", the underlying reason, and Retry. | `flutter analyze`; code review. |
| G4 | FR-LIB-24 | Should | Deleting the selected video selects the next remaining video. | With A, B, C listed and B selected, deleting B selects C; deleting the last remaining video shows the empty studio. | `flutter analyze`; code review. |

## 4. Out of scope for this intent

- FR-LIB-09 rename/reorder — BRD-01 §2.2, Q-8 open.
- Cross-workspace/all-matches library — BRD-01 §2.2.
- FR-LIB-25/30 service-owned v6 catalog and custody — ADR-0001 Phase 4 (Q2-A).
- FR-LIB-15 relocate — ADR-0003 D8.
- Volume control — ADR-0003 D12.
- New tests — project working agreement (Q3-A).

## 5. Traceability

| Intent success criterion | Requirements |
| --- | --- |
| 1. Every FR-LIB audited | §2, all 37 rows |
| 2. In-scope gaps implemented | §3, G1–G4 |
| 3. `flutter analyze` clean; no Rust in app | G1–G4 verification |
| 4. BRD status reconciled | §6 |
| 5. No silent out-of-scope work | §4 |

## 6. BRD status reconciliation (to apply on completion)

Replace the BRD-01 §2.3 rows with the HEAD evidence:

- Workspace home: list, create, open — Done.
- Studio video rail, selection, pipeline rail, status bar — Done (status bar
  stage label lands with G1).
- Missing-recording row — Done, superseded by ADR-0003 D8 (no locate action).
- Delete match and workspace — Done.
- Library search and filter — Done.
- Catalog schema v5 and migrations — Done (v6 deferred to ADR-0001 Phase 4).
- Recording copy — Done (service custody deferred).
- Local playback — Done.
- Automated tests — unchanged: stale tests are not repaired under Q3-A.
