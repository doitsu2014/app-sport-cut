# Sportcut — Studio Shell, Jobs, and Settings

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-009 |
| Version | 1.2 |
| Status | Draft — for approval |
| Date | 2026-11-02 |
| Product | Sportcut — offline macOS badminton match analyzer |
| Owner | Product owner |
| Source baseline | Commit `1541c64` (2026-10-29), evidence baseline; design system v1.1 |
| Parent contract | [00-product-context.md](00-product-context.md) |

Areas: `SHL` (studio shell) and `JOB` (job lifecycle and settings surface).
Shared BO, BR, DS, NFR, risk, and question IDs live in
[00-product-context.md](00-product-context.md); this document cites them and
never redefines them.

## Related documents
- [00-product-context.md](00-product-context.md), [README.md](README.md).
- [DESIGN.md](../../design-system/DESIGN.md) §4–§11; [tokens.css](../../design-system/tokens.css); [USAGE.md](../../design-system/USAGE.md). Export settings owner: `08-export.md`.
- Baseline at `1541c64`, cited by path for provenance (not part of the working
  tree):
  `docs/architecture.md`, `docs/features-roadmap.md`,
  `docs/verification/processing-jobs.md`, `docs/verification/client-track.md`.

## Transport and ownership note (ADR-0001)

[ADR-0001](../adr/0001-rust-background-service.md) moves the job registry,
catalog, recording custody, and engine into the Rust background service. The
Flutter shell is a client: it launches and supervises the service, talks only
over the [Sportcut Service Protocol v1](../architecture/protocol.md), and holds
an in-memory cache. This note supersedes "pinned bridge", "sportcut-api facade",
and client-owned settings wording below. The shell geometry, job lifecycle,
progress, cancellation, and settings behavior are unchanged. See
[background-service.md §4](../architecture/background-service.md#5-process-lifecycle-and-supervision)
and [protocol.md §4](../architecture/protocol.md#6-method-table-service-lifecycle).

## 1. Purpose, users, and relationship to the product BRD
The studio shell is the product surface: every feature in BRDs 01–08 is a view
inside it or a route reached from it. It fixes where the video sits, how the user
moves between stages, what the status bar claims, and how long work is announced.
The job model backs that promise, because import, preparation, tracking, and
export outlive a screen and can outlive a foreground session. This refines BR-1,
BR-8, BR-9, BR-11, and BR-12; it adds no product capability and does not score,
rank, or render.

The studio is one review surface, not three screens. Play, Review & score, and
Highlights are review lenses of a single shell: the same 52 px toolbar, 40 px
stage strip, responsive video rail and inspector (264/320 px at ≥1200 px,
240/292 px from 1100–1199 px), one preview and one transport, 176 px timeline
dock, and 30 px status bar. A lens
changes exactly three things: the read-only overlay drawn over the footage, the
inspector's default tab and scroll anchor, and the timeline's emphasis.
Geometry, controls, playback, the editing session, and the data never fork. Each
lens is therefore a small, testable delta from one contract instead of a
separate composition that drifts.

Terminology used from here on:

- **Pipeline stage** — one of the five work stages: Mark court, Prepare analysis,
  Player analysis, Review & score, Highlights. Export is a stage-strip action,
  not a work stage: it opens the sheet without changing the selected entry.
- **Production stage** — Mark court, Prepare analysis, or Player analysis; a
  pipeline stage that produces artifacts or annotations rather than reviewing
  the result.
- **Stage-strip entry** — any of the seven entries in the strip, including Play.
- **Review lens (mode)** — Play, Review & score, or Highlights; a way of reading
  the same surface. Play is a lens with no pipeline output and no prerequisite.
- **Review surface** — the one studio shell that renders every stage and lens.
- **Tab** — only the Rally|Clip control in the inspector. The stage strip is
  navigation, never a tab.
- **Panel** — the scrolling body inside the inspector, or a stage's contextual
  panel.
- **Rail** — the video rail or the inspector; their widths follow the responsive token set. No third rail exists.
- **Pane** — the video rail, preview, or inspector region; a layout term only.
- **Overlay slot** — one named layer inside the preview frame, painted in the
  order defined in §5.1.
- **Emphasis** — per-lens weighting of existing inspector or timeline content;
  it never moves, hides, or rebuilds a control.

`Feature view`, `feature rail`, `review pane`, `score view`, and `Playback` as a
stage name are retired. Use stage, lens, inspector, and preview as defined here.

| Persona | Primary need | Success looks like |
| --- | --- | --- |
| Club coach | Move between stages without losing the video or the running job | One preview, one running job, no repeated wait |
| Club administrator | A visible, true statement that nothing leaves the device | Status bar states on-device operation on every studio screen |
| Competitive player | Keyboard and transport control | Space, arrows, L/R, E work as documented |

## 2. Scope
### 2.1 In scope
- Geometry: 52 px toolbar, 40 px stage strip, responsive video rail and
  inspector (264/320 px at ≥1200 px, 240/292 px from 1100–1199 px), flexible
  preview, 176 px shared timeline dock, 30 px status bar, 1 px rail column
  borders, 1100×720 minimum window.
- Navigation: workspace list to studio, the stage strip, per-video stage state,
  back to the workspace list.
- Shared review surface: Play, Review & score, and Highlights are three lenses
  of one surface with invariant geometry, one preview, one transport, one
  timeline dock, and one Rally|Clip inspector. A lens changes only its overlay
  set, the inspector's default tab and scroll anchor, and timeline emphasis
  (FR-SHL-46..48).
- Preview overlay: one named stacking order inside one shared preview frame —
  the Review & score score bug, the Highlights clip slate, the calibration and
  tracking annotation, the floating transport, and the blocking state — plus
  the export sheet in the shell transient layer (ADR-0003 D2, D3, D14;
  FR-SHL-47).
- One surface state matrix with the precedence blocking shell state > lens
  content state > job state; BRDs 05, 06, and 07 contribute content states only
  (FR-SHL-46..48).
- Status bar content, including the local-only promise and export readiness.
- Focus mode, library search, the DESIGN.md §10 keyboard map, and transport.
- System-appearance theming with no in-app switch; shell accessibility
  (contrast, focus, names, hit targets, scaling, reduced motion).
- Jobs: admission, one heavy job at a time, one job per match, stage-labelled
  progress, cancellation, checkpoints and resume, error voice. Settings:
  appearance follows the system; export settings belong to 08.

### 2.2 Out of scope
Each item needs a change request; none may enter silently.

- A settings screen, preference file, or in-app theme switch; shortcut rebinding.
- Multi-window, window-level or document tabs, job queuing, cross-device
  scheduling, or concurrent heavy jobs.
- A per-lens review layout, a second persistent pipeline rail, a second
  preview, transport, or timeline, or a full-screen stage takeover. Play,
  Review & score, and Highlights share the one review surface (FR-SHL-46..48).
- Drag-to-resize rails, drag-to-trim rally boundaries, and playback volume.
  Volume needs a controller API change; trim needs a repository method that
  rewrites a rally span (ADR-0003 D12). Rally boundary handles are optional:
  they appear only when FR-RAL-33 is implemented, and no lens requires them.
- Telemetry, crash reporting, or any remote diagnostics.
- Mobile or web transports; v1 is one macOS window (BR-12).

### 2.3 Current delivery status
Status uses Done / Partial / Blocked / Not started / Deferred, never rounded up.
"Verified" means a test in the tree at `1541c64`; no test was run for this
document because Flutter is not installed here.

| Area | Status | Evidence and gap |
| --- | --- | --- |
| Geometry and minimum window | Done | `studio_shell.dart` reads the rails at 264/320 px (240/292 px from 1100–1199 px), 1 px column borders, the 980 px collapse, and the 480 px preview floor from `ScMetrics`; `workspace_studio_screen.dart` owns the studio route; `MainFlutterWindow.swift` keeps 1100×720. |
| Toolbar, status bar, pipeline navigation | Partial | `studio_toolbar.dart` (52 px min), `stage_strip.dart` (40 px min), `studio_status_bar.dart` (30 px min, sentence-case readiness), the stage-aware inspector, and Import in the video-rail footer. Gap: the evidence baseline `1541c64` predates the stage strip, so FR-SHL-08/40/44 correctly read Absent there while this row describes a later tree. The strip and inspector exist, but the shared review surface and its per-lens overlay, inspector-emphasis, and timeline-emphasis behaviour (FR-SHL-46..48) are not implemented or tested. |
| Focus mode, search, keyboard, settings | Partial | `studio_shortcuts.dart` binds Space, ←/→, L/R, F, E, ⌘K, and one Esc order in the later tree; settings stay system-only by design (§2.2). Gap: the evidence baseline marks FR-SHL-16..24 Absent and no keyboard widget test exists, so this row is not rounded up to Done. |
| Transport | Partial | The shared `ScTransport` provides play/pause, ±5 s, and the scrubber with named semantics. Gap: volume is still absent and deferred (FR-SHL-28, ADR-0003 D12). |
| Themes and accessibility | Partial | `theme.dart` (`ScFocusRing` in `sc_elevation.dart`), `sc_motion.dart`, and the component set ship both themes, control-contrast borders, focus rings, semantic names, 200% scaling, and reduced motion. Evidence: `flutter analyze` and `flutter build macos --debug`. Gap: no automated accessibility test, so the manual checklist is the only record. |
| Job model and client surface | Partial | `core/use-cases/jobs/` (7 tests), `core/adapters/api/tests/facade.rs`, `analysis_providers.dart`. Gap: checkpoints are not atomic; outcomes use a transient SnackBar; no widget test. |

## 3. Functional requirements
Priorities are Must, Should, Could. Each row is one testable behaviour; baseline
is Present, Partial, or Absent at `1541c64`.

### 3.1 Studio shell (`FR-SHL`)

| ID | Requirement | Priority | Acceptance criterion | Baseline |
| --- | --- | --- | --- | --- |
| FR-SHL-01 | Enforce a 1100×720 minimum studio window. | Must | The window cannot be resized below 1100×720; the studio lays out at that size with both rails open. | Present |
| FR-SHL-02 | Keep the rails at their token widths for the current window, with the preview taking the remainder. | Must | At ≥1200 px the video rail is 264 px and the inspector 320 px; from 1100–1199 px they are 240 px and 292 px; the preview fills the rest; the workspace order is preview, video rail, inspector when collapsed and video rail, preview, inspector when open; no pane overflows. | Present |
| FR-SHL-03 | Bind toolbar and status heights to the 52 px and 30 px tokens. | Must | Both heights come from `SportcutTokens`; no literal height appears for these two bars in the studio widget. | Present |
| FR-SHL-04 | Separate the video rail and the inspector from the preview with the design system's hairline column border. | Should | The video rail and inspector each end in a 1 px `--border` column border and no gutter, matching `studio.html` (ADR-0003 D15); the border comes from the border token, not a literal. | Absent |
| FR-SHL-05 | Never render the preview narrower than 480 px while the video rail or inspector is open. | Must | At the minimum window the preview is at least 480 px wide; if it cannot be, the rails collapse first. | Absent |
| FR-SHL-06 | Collapse both rails below 980 px of available width, stacking preview, video rail, then inspector. | Must | At 979 px available width the studio stacks preview, video rail, and inspector in that order, the preview keeps its 480 px floor, and the studio does not scroll horizontally. | Absent |
| FR-SHL-07 | Open the studio when the user selects a workspace. | Must | Selecting a workspace on the home screen shows the studio for that workspace. | Present |
| FR-SHL-08 | Order the stage strip: Play, Mark court, Prepare analysis, Player analysis, Review & score, Highlights, Export. | Must | The 40 px strip renders those entries in that order under the toolbar and is the primary and only persistent stage navigation; the inspector's collapsed pipeline summary is a secondary locator inside the inspector, not a second rail (ADR-0003 D2, D14). | Absent |
| FR-SHL-09 | Show each pipeline work stage's state for the selected video, labelled in words or a distinct icon. | Must | Done shows a check, ready shows an accent dot plus the word READY, blocked shows a danger icon plus BLOCKED; no state is colour alone. Play carries no pipeline marker; Export shows only its readiness or blocked state. | Partial |
| FR-SHL-10 | Share one playback controller across every stage and review lens in the studio. | Must | Switching stages, lenses, or video-rail items keeps the same loaded recording, position, and play state; no reload occurs. | Present |
| FR-SHL-11 | Keep every stage selectable; `idle` is guidance, not a gate. | Must | Selecting a stage whose prerequisite is missing opens its lens or panel and states what is missing; the app does not block the tap. | Present |
| FR-SHL-12 | Return to the workspace list from the studio toolbar. | Must | The back control pops the studio and the workspace list is shown unchanged. | Present |
| FR-SHL-13 | State the local-only promise in the status bar on every studio screen. | Must | The status bar reads "On-device · No cloud" as words at all window sizes and the claim matches behaviour. | Present |
| FR-SHL-14 | Show video count, missing count, score, short entry label, and export readiness in the status bar. | Must | Each value is present or omitted when unknown; the entry label reads Play, Score, or Clips and is the only status-bar value that changes with the lens; readiness reads Needs a clip, Ready to export, or Checking, in sentence case. The uppercase READY/ANALYZING/DONE/BLOCKED vocabulary belongs to the stage strip's state chips, not to the readiness field. | Present |
| FR-SHL-15 | Report a missing recording as a named count in the status bar and in the affected rail row. | Must | A missing recording shows "N missing" in danger with the word and "Recording missing" in the row; the row does not look normal. | Present |
| FR-SHL-16 | Toggle focus mode with F and leave it with Esc. | Must | F hides both rails with a visible indicator; Esc restores the previous rail state. | Absent |
| FR-SHL-38 | Keep the preview, transport, and Export reachable in focus mode. | Must | In focus mode the preview fills the workspace, transport works, and Export can still be opened. | Absent |
| FR-SHL-17 | Filter the video rail by title with a library search field. | Must | Typing a query shows only matching rows; an empty result shows one factual sentence plus a clear action. | Absent |
| FR-SHL-18 | Focus search with ⌘K and clear it with Esc. | Must | ⌘K moves focus to the field; Esc clears the query. | Absent |
| FR-SHL-39 | Keep search free of engine work and file reads. | Must | Typing a query makes no engine call and reads no recording file; it filters the in-memory match cache (or one `library.match.list` read). | Absent |
| FR-SHL-19 | Bind Space to play and pause. | Must | Space toggles playback when focus is not in a text field. | Absent |
| FR-SHL-20 | Bind Left and Right to seek back and forward 5 seconds. | Must | Each press moves the playhead 5 s within the duration bounds. | Absent |
| FR-SHL-21 | Bind L and R to record the rally winner. | Must | With a rally selected on any review lens, L records left and R records right; the score is re-derived by 06, the lens does not change, and no text field has focus. | Absent |
| FR-SHL-22 | Bind E to open export. | Must | E opens the 440 px export sheet from any studio stage or lens; it selects no stage and changes no lens. | Absent |
| FR-SHL-23 | Give Esc one defined order: close the export sheet, exit focus, then clear search. | Must | With several of those open, one Esc closes the topmost; nothing else is dismissed. | Absent |
| FR-SHL-24 | Suppress shell shortcuts while a text field has focus. | Must | Typing L, R, E, or Space in a field enters the character and starts no action. | Absent |
| FR-SHL-25 | Provide play/pause with a visible state and an accessible name. | Must | The control shows Play or Pause, exposes that as tooltip and semantic label, and is disabled until the recording is ready. | Present |
| FR-SHL-26 | Provide a scrubber that seeks, with tabular timecodes at both ends. | Must | Dragging the scrubber seeks the recording; position and duration read `m:ss` with tabular figures and never animate. | Present |
| FR-SHL-27 | Provide ±5 second transport buttons. | Should | Two buttons seek by 5 s and are disabled when the recording is not ready. | Absent |
| FR-SHL-28 | Provide a volume control for the preview. | Could | Volume changes affect playback only and cost no engine work; the control is named. | Absent |
| FR-SHL-29 | Explain an unplayable recording and disable the transport. | Must | An unreadable file shows a message naming the file and reason; play and scrub are disabled; the match stays listed. | Partial |
| FR-SHL-30 | Follow the system appearance; offer no in-app theme switch. | Must | Changing macOS appearance changes the app theme with no restart; no theme control exists in any screen. | Present |
| FR-SHL-31 | Keep the preview bed dark in both themes. | Must | The preview and its overlays use the fixed `#050806` bed, `#F2F5F0` chalk, and `#46D08D` signal regardless of theme (ADR-0003 D16 supersedes `#0A0F0C`). | Present |
| FR-SHL-32 | Meet the contrast floors in both themes. | Must | Body text ≥ 4.5:1, large text, icons, and score digits ≥ 3:1, audited separately for light and dark. | Absent |
| FR-SHL-33 | Show a visible focus ring on every interactive shell element. | Must | Keyboard focus draws a 2 px surface gap plus a 2 px accent ring, not a fill tint. | Absent |
| FR-SHL-34 | Name every icon-only control with a tooltip and semantic label. | Must | Back, delete video, delete workspace, import, and every transport icon expose a name; none is icon-only and unnamed. | Present |
| FR-SHL-35 | Keep shell layout readable at 200% text scaling. | Must | At 200% text size no label is clipped; rails widen or labels shorten before text shrinks below the type floor. | Absent |
| FR-SHL-36 | Honour reduced motion. | Must | With reduce motion active, non-essential transitions collapse to near zero; selection, progress, and feedback still work. | Absent |
| FR-SHL-37 | Keep the shell path free of network access and telemetry. | Must | No network client, analytics, or remote call exists in the shell path; the status promise stays true after a failure. | Present |

### 3.1a Studio surfaces added by ADR-0003

| ID | Requirement | Priority | Acceptance criterion | Baseline |
| --- | --- | --- | --- | --- |
| FR-SHL-40 | Provide a 40 px stage strip as the primary stage navigation. | Must | Seven entries render in order; selecting Play, Mark court, Prepare analysis, Player analysis, Review & score, or Highlights changes the preview overlay and the inspector content without reloading the recording; Export opens its sheet and does not change the selected entry; the strip's height comes from one token; no second persistent rail exists, and the inspector's collapsed pipeline summary is a secondary locator only. | Absent |
| FR-SHL-41 | Provide one shell-owned 176 px timeline dock with ruler, rally, and score tracks. | Must | The dock measures 176 px, shows a 10-minute window, seeks on click, and reflects rallies and scores from the current edit; every stage and lens renders the same dock, tracks, and geometry, and a lens changes emphasis only; it shows one factual sentence when no rallies are in the window and never becomes a second scrubber. | Absent |
| FR-SHL-42 | Draw a read-only score bug over the shared preview on the Review & score lens only. | Must | The bug shows rally index and total, L/R score, serving side, and `HH:MM:SS` as a compact 28–36 px broadcast readout inside the top 20% of the frame; it uses the fixed stage tokens, is pointer-transparent, never animates the score, and never appears on Play or Highlights. | Absent |
| FR-SHL-43 | Present export as a 440 px sheet from the toolbar or the stage strip. | Must | The sheet holds the existing `ExportSettings` plus an ephemeral score-overlay option, blocks on zero kept clips, and shows the engine-produced file name on success. It adds no persisted setting and never changes the selected stage. | Absent |
| FR-SHL-44 | Make the inspector stage-aware with Rally and Clip tabs plus contextual panels. | Must | Play, Review & score, and Highlights show the same Rally\|Clip tablist in the same order with the same panel order; Mark court, Prepare analysis, and Player analysis replace the tab body with their contextual panel; Export opens its sheet and has no inspector panel. The tab control reports as a tablist, not a filter. | Absent |
| FR-SHL-45 | Keep one preview, one editing session, and one rally-review session across every stage and review lens. | Must | Switching stages or lenses keeps the playback position, play state, selected rally, open editing session, and timeline window; the shell opens the sessions once per selected video and never mounts a second preview or route. | Absent |
| FR-SHL-46 | Present Play, Review & score, and Highlights as three review lenses of one shared review surface. | Must | All three render the same 52 px toolbar, 40 px stage strip, video rail and inspector at the token widths for the current window (264/320 px at ≥1200 px, 240/292 px from 1100–1199 px), preview of at least 480 px, 176 px timeline dock, and 30 px status bar; they mount one preview, one transport, one timeline dock, and one Rally\|Clip inspector in the same order; selecting a lens changes only the composition's overlay set (FR-SHL-47), inspector default tab and scroll anchor (FR-SHL-48), and timeline emphasis, while the same controls and shortcuts stay available; it does not change the shell grid, reload the recording, or open a second route or full-screen takeover. | Absent |
| FR-SHL-47 | Define exactly one overlay set and one stacking order per review lens. | Must | Play = transport only (L0/L3); Review & score = transport plus scrim and read-only score bug (L0/L1/L2/L3); Highlights = transport plus scrim and read-only clip slate (L0/L1/L2/L3); Mark court and Player analysis add only their own annotation, and Prepare analysis adds none; when FR-RAL-33 is implemented, Review & score adds rally boundary handles at L4. Paint order is L0 footage, L1 underlay, L2 read-only data, L3 transport, L4 stage annotation, L5 blocking state, L6 shell transient. Data is pointer-transparent, annotation hit-tests only its own targets, and blocking owns all input; data stays inside the top 20% of the frame at the 480 px floor, uses `#050806`/`#F2F5F0`/`#46D08D`, never covers the court action area except for L4 annotation handles (corner handles 24 px visual / 44 px hit; rally boundaries 20 px minimum within the 44 px track), and never animates the score. | Absent |
| FR-SHL-48 | Change inspector and timeline emphasis per lens without changing their layout. | Must | The inspector keeps the same regions and order in all three lenses (collapsed pipeline summary, Rally\|Clip tablist, scrolling tab body, reel summary) and the lens sets only the default tab and scroll anchor: Play → Rally tab at the rally list and last rallies; Review & score → Rally tab at the scoreboard/winner block and pending suggestions; Highlights → Clip tab at the selected clip and reel summary. The timeline keeps the same 176 px dock and tracks and the lens sets emphasis only: Play → playhead and selected rally; Review & score → score chips and scored rallies; Highlights → kept/left-out segments and selected clip. No control moves or disappears, every tab and action stays reachable without changing lens, and FR-SHL-45's position, play state, and edit session survive. | Absent |

ADR-0003 D14 lists Export among the contextual inspector panels. This document
refines that decision: Export's contextual surface is the 440 px sheet, and the
inspector keeps the previous stage or lens state while the sheet is open.

### 3.2 Job lifecycle (`FR-JOB`)

| ID | Requirement | Priority | Acceptance criterion | Baseline |
| --- | --- | --- | --- | --- |
| FR-JOB-01 | Return a job handle as soon as the job is admitted, with work off the UI thread. | Must | A start call returns a job identifier before the work finishes, and the UI remains responsive while it runs. | Present |
| FR-JOB-02 | Admit one heavy job at a time process-wide. | Must | A second heavy job is rejected with a reason naming the running job; it is not queued. | Present |
| FR-JOB-03 | Admit one job per match. | Must | A second job for the same match is rejected with a reason naming the existing job. | Present |
| FR-JOB-04 | Reject before any work starts, with no handle for work that will not run. | Must | A rejected start returns an error and creates no session, no partial artifact, and no progress record. | Present |
| FR-JOB-05 | Expose pending, running, completed, cancelled, failed, with a terminal test. | Must | Status reports exactly one state; completed, cancelled, and failed are terminal and accept no further stage. | Present |
| FR-JOB-06 | Label progress with its stage, using user-facing words rather than engine keys. | Must | Every progress snapshot names a stage as a sentence such as "Making the proxy"; no value lacks a label and no raw key reaches the user. | Present |
| FR-JOB-07 | Never decrease progress within a stage, and reset the scale on stage change. | Must | Reports of 0.2, 0.6, 0.3, 0.6, 0.9 read back as 0.2, 0.6, 0.6, 0.6, 0.9; the next stage starts at its own value. | Present |
| FR-JOB-08 | Show a determinate bar when progress is known, and an indeterminate bar only with a stage label. | Must | An indeterminate bar never appears without a stage label and never persists past three seconds without one. | Partial |
| FR-JOB-09 | Cancel cooperatively and report the status after the request. | Must | A cancel request stops work at the next check; the returned status may still read running and never claims success. | Present |
| FR-JOB-10 | Never present cancelled output as final. | Must | After cancellation the manifest's artifacts for that job are non-final and the summary reports nothing complete. | Present |
| FR-JOB-11 | Limit cancellation fallout to the job's own outputs. | Must | Cancelling one job leaves artifacts from earlier completed jobs final; only outputs this job rewrote become non-final. | Absent |
| FR-JOB-12 | Record a completed stage in `checkpoints.json` with a schema version. | Must | Each successful stage is written before the next starts; the file carries `schema_version` and the last state. | Present |
| FR-JOB-13 | Resume from the last completed stage after failure or restart. | Must | A new run skips checkpointed stages, retries the failed stage, and reports executed and skipped stages. | Present |
| FR-JOB-14 | Keep checkpoints across an application restart. | Must | A fresh store pointed at the same match directory reads the file and skips the same stages. | Present |
| FR-JOB-15 | Write checkpoint files atomically. | Must | A crash during a checkpoint write leaves the previous readable file; no truncated JSON is left at the final path. | Absent |
| FR-JOB-16 | Report an unknown job identifier by name. | Must | Status or cancel for an identifier the process does not know returns an error naming it; it never reports success. | Present |
| FR-JOB-17 | Name the failing stage and the reason. | Must | A failed job reports the stage and a reason naming the file or condition; the client shows it. | Present |
| FR-JOB-18 | Keep a background job running while the user switches stage, lens, or video, and announce the outcome once. | Must | Switching stages, lenses, or videos does not cancel the job; the studio announces the outcome once, for the right match. | Present |
| FR-JOB-19 | Run export and artifact repair without reading or writing pipeline checkpoints. | Must | An export or regenerate plan executes every listed stage, records no checkpoint stage, and cannot report itself as resuming. | Present |

## 4. State coverage
State precedence is blocking shell state, then lens content state, then job
state. A blocking shell state (no video, loading, missing, unplayable) owns the
preview frame and suppresses every lens overlay. A lens content state (no score,
no clips, edit busy, edit error) renders inside its own inspector panel and
never replaces the shell grid or the stage strip. Job state is announced by the
strip's chip and the inspector's collapsed pipeline summary. This section owns
shell and job state; DESIGN.md §5.7 owns the shared surface state matrix. BRDs
05, 06, and 07 contribute content states only.

| State | Shell behaviour | Job behaviour |
| --- | --- | --- |
| Default | Preview on Play, first video auto-selected, rail state from manifests; the Play lens shows transport only. | Pending until the first stage reports. |
| Loading | Video list shows a centred progress indicator; facts may read Checking. | Running with a stage label; bar determinate once a value arrives. |
| Empty | "No videos in this workspace" plus Import video; search has its own empty state. | Not applicable; a job needs a match. |
| Error | "The videos could not be read" plus Try again; a missing recording is labelled. | Failed with stage and reason; rejection names the blocker. |
| Success | Import, delete, and analysis outcomes announced; rail and facts refreshed. | Completed at 1.0; checkpoint state completed. |
| Disabled | Import disabled while importing; transport disabled until ready; zero clips block Export. | A second heavy or same-match start is refused before it exists. |
| Cancellation | No cancelled copy or record; the import bar offers Cancel. | Cooperative cancel; artifacts non-final; checkpoint state cancelled. |

## 5. Design contract
Values come from [tokens.css](../../design-system/tokens.css) and
[DESIGN.md](../../design-system/DESIGN.md); `tokens.css` has no layout scale, so
the client mirrors the DESIGN.md constants in `SportcutTokens`.

| Element | Value | Source | Shared requirement |
| --- | --- | --- | --- |
| Window chrome / stage strip / status bar | 52 px / 40 px / 30 px | DESIGN.md §4, §10; ADR-0003 D2 | DS-7, DS-13 |
| Video rail / inspector / separation | 264/320 px at ≥1200 px; 240/292 px from 1100–1199 px; 1 px `--border` column border | studio.html `.sidebar`, `.inspector`; ADR-0003 D15 | DS-7, DS-13 |
| Review surface | 52 px toolbar → 40 px stage strip → workspace (video rail and inspector at the responsive token widths, preview ≥ 480 px) → 176 px timeline dock → 30 px status bar | FR-SHL-46; DESIGN.md §5.1, §10 | DS-7, DS-13, DS-14 |
| Overlay stacking | L0 footage, L1 underlay, L2 read-only data, L3 floating transport, L4 stage annotation, L5 blocking state, L6 shell transient | FR-SHL-47; DESIGN.md §5.3 | DS-1, DS-2, DS-12 |
| Per-lens overlays | Play = transport only; Review & score = transport + scrim + read-only score bug (rally boundary handles only when FR-RAL-33 is enabled); Highlights = transport + scrim + read-only clip slate | FR-SHL-47; DESIGN.md §5.2 | DS-1, DS-2, DS-4 |
| Inspector emphasis | Play → Rally tab at rally list and last rallies; Review & score → Rally tab at scoreboard/winner and pending suggestions; Highlights → Clip tab at selected clip and reel summary | FR-SHL-48; DESIGN.md §5.5 | DS-4, DS-7 |
| Timeline emphasis | Play → playhead and selected rally; Review & score → score chips and scored rallies; Highlights → kept/left-out segments and selected clip | FR-SHL-48; DESIGN.md §5.6 | DS-2, DS-8 |
| Timeline dock | 176 px: 34 px header, 112 px label gutter, 24/44/32 px tracks | studio.html `--timeline-h`; ADR-0003 D3 | DS-7, DS-13 |
| Floating transport | Bottom 14 px, 20 px horizontal inset, max width 640 px; play/pause, ±5 s, scrubber, tabular position/duration; volume deferred | FR-SHL-25..28; DESIGN.md §6 | DS-4, DS-7 |
| Minimum window | 1100 × 720 | DESIGN.md §4, §10 | DS-7, DS-14 |
| Preview floor / collapse | 480 px / below 980 px | DESIGN.md §5 | DS-14 |
| Radii / spacing / type | 6, 10, 14, pill / 4–48 / 16 px body, 10 px mono | tokens.css `--radius-*`, `--space-*`, `--text-*` | DS-6, DS-7 |
| Motion / focus ring | 120 ms, 180 ms, `cubic-bezier(0.2,0,0,1)`; 2 px gap + 2 px accent | tokens.css `--motion-*`, `--focus-ring` | DS-9, DS-11 |
| Signal / ground | `#0E6E45` / `#46D08D`; `#F1F3EF` / `#0B100D` | tokens.css `--accent`, `--bg` | DS-2, DS-3 |
| State colours | success `#157347`/`#57C98F`, warn `#8A5A00`/`#E3B24E`, danger `#B42318`/`#F27B70` | tokens.css | DS-2, DS-4 |
| Footage bed | `#050806` with `#F2F5F0` chalk and `#46D08D` signal | studio.html `--stage*`; ADR-0003 D16 (supersedes `#0A0F0C`) | DS-1, DS-2 |
| Status vocabulary | Stage chips: READY, ANALYZING 42%, DONE, BLOCKED, NEEDS REVIEW. Export readiness: Checking, Ready to export, Needs a clip | USAGE.md status mapping; ADR-0003 D19 | DS-4, DS-8 |

Local design rules: the stage strip is the primary and only persistent stage
navigation; the inspector's collapsed pipeline summary is a secondary locator
inside the inspector shell, not a rail, and it never repeats the strip's
controls. The status bar carries one accent mark and one word for the local-only
promise, with no second accent element (DS-3), and a chip is a word in uppercase
mono, never a dot alone (DS-4). One primary action per pane: Import in the video
rail, Export in the toolbar, playback in the preview; the current toolbar makes
Import the filled button, which conflicts with DESIGN.md §10 and is recorded as
a gap. Error copy names what happened and the next action, with no exclamation
marks (DS-10, DESIGN.md §8); no gradient, glass, glow, count-up, confetti, or
invented metric appears in the shell (DS-12).

### 5.1 Overlay matrix

One named stack is painted bottom to top inside the preview frame. A lens uses
exactly the layers in its row; no other overlay may be added.

| Layer | Contents | Hit-testing | Used by |
| --- | --- | --- | --- |
| L0 Footage | The decoded video frame on the `#050806` bed | None; playback only responds through L3 | Every stage and lens |
| L1 Underlay | Stage scrim between 32% and 56% opacity | Pointer-inert | Every stage and lens except Play |
| L2 Read-only data | Score bug or clip slate in the top safe band | Pointer-transparent; never captures a click | Review & score, Highlights |
| L3 Floating transport | Play/pause, ±5 s, scrubber, tabular position/duration | Interactive; reachable whenever L5 is clear | Every stage and lens |
| L4 Stage annotation | Calibration handles and net, tracking boxes; rally boundary handles only when FR-RAL-33 is implemented | Hit-tests only its own targets; never blocks the transport | Mark court, Player analysis; Review & score when FR-RAL-33 is enabled |
| L5 Blocking state | Missing, unplayable, or loading message | Owns all input while active; no lens overlay is painted beneath it | Any stage when blocking |
| L6 Shell transient | Toast, export sheet, dialogs | Owns input while open; lives outside the frame | Shell |

| Review lens | Overlay set | Inspector default | Timeline emphasis |
| --- | --- | --- | --- |
| Play | Transport only; no score bug and no clip slate | Rally tab, scrolled to the rally list and last rallies | Playhead and selected rally |
| Review & score | Transport plus read-only score bug (rally index/total, L/R, serving side, timecode) | Rally tab, scrolled to the scoreboard/winner block and pending suggestions | Score chips and scored rallies |
| Highlights | Transport plus read-only clip slate (rank, clip index/total, kept/left-out, in-out) | Clip tab, scrolled to the selected clip detail and reel summary | Kept/left-out segments and selected clip |

Read-only data stays inside the top 20% of the frame at the 480 px floor, uses
`#050806`/`#F2F5F0`/`#46D08D`, never covers the court action area, and never
animates. The inspector is the only editable score ledger; the score bug is a
broadcast readout, not a second editor.

## 6. Non-functional requirements
These rows bind shared NFR IDs to this feature; the shared text is authoritative.

| Shared NFR | What this feature must demonstrate | Acceptance criterion here | Baseline |
| --- | --- | --- | --- |
| NFR-1 Offline operation | No shell or settings path needs the network. | The studio, jobs, and settings complete with networking disabled; no client library performs network I/O. | Present |
| NFR-2 UI responsiveness | Long work stays off the UI thread and one heavy job runs. | Progress polls do not block frames; a second heavy job is refused, not queued. | Present |
| NFR-3 Crash safety and resume | Atomic writes, surviving checkpoints, non-final cancelled output. | Checkpoint and manifest writes leave a readable file after an interrupted write; resume skips completed stages. | Partial |
| NFR-5 Security and least privilege | No secrets, no unsandboxed release configuration. | The shell reads only files the user selected or paths the service returns for playback, render inputs, and diagnostics; no credential or token appears in code or logs. | Present |
| NFR-6 Accessibility | Shell meets DS-15 in both themes. | The USAGE.md checklist passes in light and dark, including scaling and reduced motion. | Absent |
| NFR-7 Testability | Each Must shell and job behaviour has observable evidence. | A studio widget test, a keyboard test, and an accessibility test exist and run in CI. | Absent |
| NFR-13 Local diagnostics | Errors are actionable and stay on the device. | A failure names the file and reason; no diagnostic leaves the device. | Partial |

NFR-4 (data integrity) applies through FR-JOB-12. NFR-9 is the service
boundary and protocol versioning requirement: the shell launches a separate
signed service, negotiates a protocol major, and contains no Rust, FFI, or
dylib. It is not a pinned bridge.

## 7. Acceptance and verification evidence

| Requirement group | Evidence at `1541c64` | Gap |
| --- | --- | --- |
| FR-JOB-01..07, 09, 10, 12..14, 16 | `core/use-cases/jobs/tests/job_lifecycle.rs` (7 tests) | None for engine semantics. |
| FR-JOB-02, 04, 09, 10, 16, 17 | `core/adapters/api/tests/facade.rs`: conflicting job refused, unknown handle named, cancelled import leaves nothing final | No client test of the same messages. |
| FR-JOB-08, 18 | `analysis_providers.dart`, `analysis_view.dart`, `export_view.dart` | No widget test of bar type, stage labels, or the single announcement. |
| FR-JOB-11, 15 | None | Requirements the code does not meet. |
| FR-SHL-01..03, 07, 10, 11, 12 | `workspace_studio_screen.dart`, `MainFlutterWindow.swift`; `app_shell_test.dart` covers routes and themes | No studio widget test; no rail-order, window, or controller-sharing test. |
| FR-SHL-25, 26, 29..31, 34, 37 | `player_screen_test.dart`, `theme.dart`, `sportcut_tokens.dart`, `player_view.dart` | No ±5 s, volume, contrast, naming, or network test. |
| FR-SHL-04..06, 08..09, 13..24, 27..28, 32..36, 38..39 | None | Absent behaviours; see §2.3. |
| FR-SHL-40..45 | `stage_strip.dart`, `inspector_pane.dart`, `timeline_dock.dart`, `sc_score_bug.dart`, `sc_timeline.dart` exist in a tree later than `1541c64` | No per-lens test; the baseline predates the stage strip, and the shared-surface behaviour is not verified. |
| FR-SHL-46..48 | None | The three review lenses still mount separate legacy views; no overlay-set, inspector-emphasis, or timeline-emphasis test exists. |

```bash
tools/verify-engine.sh          # engine fmt, clippy, tests, including jobs
cd app && flutter analyze
cd app && flutter test          # 127 tests at baseline per client-track.md
```

Disagreements recorded. `app_shell_test.dart` expects "No matches yet" while
`workspace_screen.dart` shows "No workspaces yet", so the test is stale and
counts for R-7, not proof of the shell; it also omits the `playerTracking`
route that `router.dart` declares. `docs/verification/processing-jobs.md`
reports 7 job tests and none for FR-JOB-11 or FR-JOB-15, which no test
contradicts.

## 8. Dependencies, constraints, risks, and open questions
### 8.1 Dependencies

| Dependency | What this feature needs | Owner |
| --- | --- | --- |
| Design system v1.1 | Geometry, tokens, overlay slots, status vocabulary, voice, accessibility | Design lead |
| `sportcut-jobs` crate (inside the service) | Admission, session, stages, checkpoints, resume | Engineering lead |
| Service protocol client (`app/lib/src/protocol/`) | `engine.job.status`, `engine.job.cancel`, start calls, DTOs, reconnect | Engineering lead |
| Client shell | `workspace_studio_screen.dart`, `theme.dart`, providers | Engineering lead |
| Playback backend | `video_player` through `PlaybackController`; shippable per BR-10 | Engineering lead |
| Export settings | Per-match settings owned by `08-export.md` | Feature 08 writer |

macOS `NSWindow` supplies the minimum size. The client reaches the backend only
through the Dart protocol client (`app/lib/src/protocol/`) or, in the XPC
variant, the Swift `SportcutServiceChannel`; `flutter_rust_bridge` is retired,
not pinned (NFR-9).

### 8.2 Constraints
- One macOS window, minimum 1100×720, no in-app theme switch (DESIGN.md §10).
- Rails hold fixed token widths; the preview absorbs the remainder; `tokens.css`
  is the only value source and layout constants live in DESIGN.md §4/§10.
- The facade is frozen; no network, telemetry, or remote diagnostics in any
  shell path (BR-1, NFR-13).

### 8.3 Risks
Shared risk IDs only; this document mints no new risk identifier.

| Shared risk | Manifestation here | Mitigation | Owner |
| --- | --- | --- | --- |
| R-6 Design drift | 1 px dividers instead of the 12 px gutter; Import as toolbar primary action; ready state as a colour dot. | Reconcile against DESIGN.md §4, §6, §10; add a token check in review. | Design lead |
| R-7 Test gaps | No studio, keyboard, search, focus, or accessibility test; a stale assertion. | Add the tests named in §7 and fix the stale expectation. | QA lead |
| R-8 Job-model race | Cancellation marks every manifest artifact non-final; admission and session state use separate locks. | Narrow invalidation to the job's outputs; document or fix the admission race. | Engineering lead |
| R-9 Retired documentation references | README and external links may still point at retired docs. | Update references to `docs/brd`; keep baseline copies as provenance only. | Engineering lead |

### 8.4 Open questions
Local identifiers; they do not replace the shared Q-1..Q-10.

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-SHL-01 | **Resolved 2026-10-29.** The 176 px shared timeline dock is in v1 scope (ADR-0003 D3, FR-SHL-41); §2.2 no longer excludes it. | Changes the shell layout and the 176 px dock constant. | Design lead |
| Q-SHL-02 | **Resolved 2026-10-29.** Export is the single toolbar primary action and Import moves to the video-rail footer (ADR-0003 D4). | Resolves the one-primary-action conflict. | Design lead |
| Q-SHL-03 | Does v1 include a settings screen, or only system-following appearance? | Determines whether any preferences are persisted; shared Q-7 governs the viewport matrix. | Product owner |
| Q-SHL-04 | Should a failed background job raise a persistent banner instead of a SnackBar? | Affects whether a failure keeps its only recovery path. | Product owner |

## 9. Traceability

| Shared requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| BR-1 Offline and private | FR-SHL-13, 37 | DESIGN.md §10; USAGE.md | `workspace_studio_screen.dart` | Manual read; no network test |
| BR-8 Design fidelity | FR-SHL-02..06, 09, 30, 31, 46..48 | DS-1, 3, 4, 7, 12, 13, 14; DESIGN.md §5.1–5.9 | `sportcut_tokens.dart`, `theme.dart`, `studio_shell.dart`, `stage_strip.dart`, `inspector_pane.dart`, `timeline_dock.dart` | `app_shell_test.dart` (theme only); none for the shared surface |
| BR-9 Accessibility | FR-SHL-32..36, 47, 48 | DS-1, 4, 9, 15; DESIGN.md §5.3, §5.9; USAGE.md | `theme.dart`, `player_view.dart`, `sc_score_bug.dart`, `timeline_dock.dart` | None |
| BR-11 Recoverable jobs | FR-JOB-01..19 | DESIGN.md §6 | `core/use-cases/jobs/`, `core/adapters/api/src/jobs.rs`, `analysis_providers.dart` | `job_lifecycle.rs`, `facade.rs` |
| BR-12 macOS focus | FR-SHL-01, 30 | DESIGN.md §10 | `MainFlutterWindow.swift`, `app.dart` | Code read |
| NFR-3 Crash safety | FR-JOB-10, 12..15 | — | `checkpoint.rs`, `runner.rs` | `job_lifecycle.rs` (partial) |

## 10. Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |

Version 1.2 (2026-11-02) adopts the shared review surface: FR-SHL-46..48 and the
overlay matrix in §5.1 make Play, Review & score, and Highlights three lenses of
one shell and retire the separate feature-view composition. The pipeline stage
order, prerequisites, and job model are unchanged. Approvals remain open until
recorded above.

**Change control.** This document inherits the change control of
[00-product-context.md §18](00-product-context.md#18-approval). A change to
scope, a Must requirement, or the design contract needs a version bump and a
recorded approval. A change that introduces a dependency updates the dependency
register before the implementing change is complete. This BRD claims no release
readiness while R-2, R-4, or the shell Must requirements above remain open.
