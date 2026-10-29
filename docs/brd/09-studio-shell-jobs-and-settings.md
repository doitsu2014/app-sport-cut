# Sportcut — Studio Shell, Jobs, and Settings

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-009 |
| Version | 1.0 |
| Status | Draft — for approval |
| Date | 2026-10-29 |
| Product | Sportcut — offline macOS badminton match analyzer |
| Owner | Product owner |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.0 |
| Parent contract | [00-product-context.md](00-product-context.md) |

Areas: `SHL` (studio shell) and `JOB` (job lifecycle and settings surface).
Shared BO, BR, DS, NFR, risk, and question IDs live in
[00-product-context.md](00-product-context.md); this document cites them and
never redefines them.

## Related documents
- [00-product-context.md](00-product-context.md), [README.md](README.md).
- [DESIGN.md](../../design-system/DESIGN.md) §4, §6–§11; [tokens.css](../../design-system/tokens.css); [USAGE.md](../../design-system/USAGE.md). Export settings owner: `08-export.md`.
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
[background-service.md §4](../architecture/background-service.md#4-process-lifecycle-and-supervision)
and [protocol.md §4](../architecture/protocol.md#4-method-table-service-lifecycle).

## 1. Purpose, users, and relationship to the product BRD
The studio shell is the product surface: every feature in BRDs 01–08 is a view
inside it or a route reached from it. It fixes where the video sits, how the user
moves between stages, what the status bar claims, and how long work is announced.
The job model backs that promise, because import, preparation, tracking, and
export outlive a screen and can outlive a foreground session. This refines BR-1,
BR-8, BR-9, BR-11, and BR-12; it adds no product capability and does not score,
rank, or render.

| Persona | Primary need | Success looks like |
| --- | --- | --- |
| Club coach | Move between stages without losing the video or the running job | One preview, one running job, no repeated wait |
| Club administrator | A visible, true statement that nothing leaves the device | Status bar states on-device operation on every studio screen |
| Competitive player | Keyboard and transport control | Space, arrows, L/R, E work as documented |

## 2. Scope
### 2.1 In scope
- Geometry: 52 px toolbar, 264 px video rail, 320 px feature rail, flexible
  preview, 30 px status bar, 12 px rail gutter, 1100×720 minimum window.
- Navigation: workspace list to studio, pipeline rail and groups, per-video
  stage state, back to the workspace list.
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
- Multi-window, tabs, job queuing, cross-device scheduling, or concurrent heavy
  jobs.
- A shared global timeline dock. DESIGN.md §10 lists it; the client draws the
  timeline inside the Score and Highlights views.
- Telemetry, crash reporting, or any remote diagnostics.
- Mobile or web transports; v1 is one macOS window (BR-12).

### 2.3 Current delivery status
Status uses Done / Partial / Blocked / Not started / Deferred, never rounded up.
"Verified" means a test in the tree at `1541c64`; no test was run for this
document because Flutter is not installed here.

| Area | Status | Evidence and gap |
| --- | --- | --- |
| Geometry and minimum window | Partial | `workspace_studio_screen.dart`, `MainFlutterWindow.swift` (1100×720). Gap: 1 px dividers replace the 12 px gutter; no 980 px collapse or 480 px preview floor. |
| Toolbar, status bar, pipeline rail | Partial | Toolbar 52 px, status 30 px, local-only text, readiness chip, Play/Analysis/Studio groups. Gap: Import is the toolbar primary action; ready is a bare accent dot; vocabulary differs from USAGE.md. |
| Focus mode, search, keyboard, settings | Not started | No focus mode, search field, shortcut handling, or settings route in `app/lib/src`; the rail lists every video. |
| Playback transport | Partial | `player_view.dart`, `playback_controller.dart`; `player_screen_test.dart` covers play, pause, scrub, unplayable. Gap: no ±5 s, no volume. |
| Themes and accessibility | Partial | `theme.dart` builds light and dark with `ThemeMode.system`; tooltips and play/pause `semanticLabel`. Gap: no 2 px accent ring, 32×32 icon minimum, no scaling or reduced-motion handling, no a11y test. |
| Job model and client surface | Partial | `core/crates/jobs/` (7 tests), `core/crates/api/tests/facade.rs`, `analysis_providers.dart`. Gap: checkpoints are not atomic; outcomes use a transient SnackBar; no widget test. |

## 3. Functional requirements
Priorities are Must, Should, Could. Each row is one testable behaviour; baseline
is Present, Partial, or Absent at `1541c64`.

### 3.1 Studio shell (`FR-SHL`)

| ID | Requirement | Priority | Acceptance criterion | Baseline |
| --- | --- | --- | --- | --- |
| FR-SHL-01 | Enforce a 1100×720 minimum studio window. | Must | The window cannot be resized below 1100×720; the studio lays out at that size with both rails open. | Present |
| FR-SHL-02 | Keep the video rail at 264 px and the feature rail at 320 px, with the preview taking the remainder. | Must | At or above 1100 px, both rails measure their token width and the preview fills the rest; no pane overflows. | Present |
| FR-SHL-03 | Bind toolbar and status heights to the 52 px and 30 px tokens. | Must | Both heights come from `SportcutTokens`; no literal height appears for these two bars in the studio widget. | Present |
| FR-SHL-04 | Separate rails from the preview with the 12 px rail gutter. | Should | The gap between a rail and the preview is 12 px from `--space-3`; changing the token changes the gap. | Absent |
| FR-SHL-05 | Never render the preview narrower than 480 px while rails are open. | Must | At the minimum window the preview is at least 480 px wide; if it cannot be, rails collapse first. | Absent |
| FR-SHL-06 | Collapse both rails below 980 px of available width, stacking preview, videos, then pipeline. | Must | At 979 px available width the studio stacks in that order and does not scroll horizontally. | Absent |
| FR-SHL-07 | Open the studio when the user selects a workspace. | Must | Selecting a workspace on the home screen shows the studio for that workspace. | Present |
| FR-SHL-08 | Order the pipeline rail: Play, then Analysis (Mark court, Prepare analysis, Player analysis, Review & score), then Studio (Highlights, Export). | Must | The rail renders those labels in that order, with the two section headers. | Present |
| FR-SHL-09 | Show each stage's state for the selected video, labelled in words or a distinct icon. | Must | Done shows a check, ready shows an accent dot plus the word READY, blocked shows a danger icon plus BLOCKED; no state is colour alone. | Partial |
| FR-SHL-10 | Share one playback controller across every feature view in the studio. | Must | Switching rail items keeps the same loaded recording, position, and play state; no reload occurs. | Present |
| FR-SHL-11 | Keep every stage selectable; `idle` is guidance, not a gate. | Must | Selecting a stage whose prerequisite is missing opens its view and states what is missing; the app does not block the tap. | Present |
| FR-SHL-12 | Return to the workspace list from the studio toolbar. | Must | The back control pops the studio and the workspace list is shown unchanged. | Present |
| FR-SHL-13 | State the local-only promise in the status bar on every studio screen. | Must | The status bar reads "On-device · No cloud" as words at all window sizes and the claim matches behaviour. | Present |
| FR-SHL-14 | Show video count, missing count, score, current stage, and export readiness in the status bar. | Must | Each value is present or omitted when unknown; readiness reads Needs a clip, Ready to export, or Checking. | Present |
| FR-SHL-15 | Report a missing recording as a named count in the status bar and in the affected rail row. | Must | A missing recording shows "N missing" in danger with the word and "Recording missing" in the row; the row does not look normal. | Present |
| FR-SHL-16 | Toggle focus mode with F and leave it with Esc. | Must | F hides both rails with a visible indicator; Esc restores the previous rail state. | Absent |
| FR-SHL-38 | Keep the preview, transport, and Export reachable in focus mode. | Must | In focus mode the preview fills the workspace, transport works, and Export can still be opened. | Absent |
| FR-SHL-17 | Filter the video rail by title with a library search field. | Must | Typing a query shows only matching rows; an empty result shows one factual sentence plus a clear action. | Absent |
| FR-SHL-18 | Focus search with ⌘K and clear it with Esc. | Must | ⌘K moves focus to the field; Esc clears the query. | Absent |
| FR-SHL-39 | Keep search free of engine work and file reads. | Must | Typing a query makes no engine call and reads no recording file; it filters the in-memory match cache (or one `library.match.list` read). | Absent |
| FR-SHL-19 | Bind Space to play and pause. | Must | Space toggles playback when focus is not in a text field. | Absent |
| FR-SHL-20 | Bind Left and Right to seek back and forward 5 seconds. | Must | Each press moves the playhead 5 s within the duration bounds. | Absent |
| FR-SHL-21 | Bind L and R to record the rally winner. | Must | With a rally span open, L records left and R records right; the score is re-derived by 06. | Absent |
| FR-SHL-22 | Bind E to open export. | Must | E selects the Export stage from any studio feature. | Absent |
| FR-SHL-23 | Give Esc one defined order: close the export sheet, exit focus, then clear search. | Must | With several of those open, one Esc closes the topmost; nothing else is dismissed. | Absent |
| FR-SHL-24 | Suppress shell shortcuts while a text field has focus. | Must | Typing L, R, E, or Space in a field enters the character and starts no action. | Absent |
| FR-SHL-25 | Provide play/pause with a visible state and an accessible name. | Must | The control shows Play or Pause, exposes that as tooltip and semantic label, and is disabled until the recording is ready. | Present |
| FR-SHL-26 | Provide a scrubber that seeks, with tabular timecodes at both ends. | Must | Dragging the scrubber seeks the recording; position and duration read `m:ss` with tabular figures and never animate. | Present |
| FR-SHL-27 | Provide ±5 second transport buttons. | Should | Two buttons seek by 5 s and are disabled when the recording is not ready. | Absent |
| FR-SHL-28 | Provide a volume control for the preview. | Could | Volume changes affect playback only and cost no engine work; the control is named. | Absent |
| FR-SHL-29 | Explain an unplayable recording and disable the transport. | Must | An unreadable file shows a message naming the file and reason; play and scrub are disabled; the match stays listed. | Partial |
| FR-SHL-30 | Follow the system appearance; offer no in-app theme switch. | Must | Changing macOS appearance changes the app theme with no restart; no theme control exists in any screen. | Present |
| FR-SHL-31 | Keep the preview bed dark in both themes. | Must | The preview and its overlays use the fixed `#0A0F0C` bed and `#F2F5F0` chalk regardless of theme. | Present |
| FR-SHL-32 | Meet the contrast floors in both themes. | Must | Body text ≥ 4.5:1, large text, icons, and score digits ≥ 3:1, audited separately for light and dark. | Absent |
| FR-SHL-33 | Show a visible focus ring on every interactive shell element. | Must | Keyboard focus draws a 2 px surface gap plus a 2 px accent ring, not a fill tint. | Absent |
| FR-SHL-34 | Name every icon-only control with a tooltip and semantic label. | Must | Back, delete video, delete workspace, import, and every transport icon expose a name; none is icon-only and unnamed. | Present |
| FR-SHL-35 | Keep shell layout readable at 200% text scaling. | Must | At 200% text size no label is clipped; rails widen or labels shorten before text shrinks below the type floor. | Absent |
| FR-SHL-36 | Honour reduced motion. | Must | With reduce motion active, non-essential transitions collapse to near zero; selection, progress, and feedback still work. | Absent |
| FR-SHL-37 | Keep the shell path free of network access and telemetry. | Must | No network client, analytics, or remote call exists in the shell path; the status promise stays true after a failure. | Present |

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
| FR-JOB-18 | Keep a background job running while the user switches feature or video, and announce the outcome once. | Must | Switching stages or videos does not cancel the job; the studio announces the outcome once, for the right match. | Present |
| FR-JOB-19 | Run export and artifact repair without reading or writing pipeline checkpoints. | Must | An export or regenerate plan executes every listed stage, records no checkpoint stage, and cannot report itself as resuming. | Present |

## 4. State coverage

| State | Shell behaviour | Job behaviour |
| --- | --- | --- |
| Default | Preview on Playback, first video auto-selected, rail state from manifests. | Pending until the first stage reports. |
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
| Window chrome / status bar | 52 px / 30 px | DESIGN.md §4, §10 | DS-7, DS-13 |
| Video rail / feature rail / gutter | 264 px / 320 px / 12 px (`--space-3`) | DESIGN.md §4, §10 | DS-7, DS-13 |
| Minimum window | 1100 × 720 | DESIGN.md §4, §10 | DS-7, DS-14 |
| Preview floor / collapse | 480 px / below 980 px | DESIGN.md §5 | DS-14 |
| Radii / spacing / type | 6, 10, 14, pill / 4–48 / 16 px body, 10 px mono | tokens.css `--radius-*`, `--space-*`, `--text-*` | DS-6, DS-7 |
| Motion / focus ring | 120 ms, 180 ms, `cubic-bezier(0.2,0,0,1)`; 2 px gap + 2 px accent | tokens.css `--motion-*`, `--focus-ring` | DS-9, DS-11 |
| Signal / ground | `#0E6E45` / `#46D08D`; `#F1F3EF` / `#0B100D` | tokens.css `--accent`, `--bg` | DS-2, DS-3 |
| State colours | success `#157347`/`#57C98F`, warn `#8A5A00`/`#E3B24E`, danger `#B42318`/`#F27B70` | tokens.css | DS-2, DS-4 |
| Footage bed | `#0A0F0C` with `#F2F5F0` chalk | DESIGN.md §2, USAGE.md | DS-1, DS-2 |
| Status vocabulary | READY, ANALYZING 42%, DONE, BLOCKED, NEEDS REVIEW | USAGE.md status mapping | DS-4, DS-8 |

Local design rules: the status bar carries one accent mark and one word for the
local-only promise, with no second accent element (DS-3), and a chip is a word in
uppercase mono, never a dot alone (DS-4). One primary action per pane: Import in
the video rail, Export in the feature rail or toolbar, playback in the preview;
the current toolbar makes Import the filled button, which conflicts with
DESIGN.md §10 and is recorded as a gap. Error copy names what happened and the
next action, with no exclamation marks (DS-10, DESIGN.md §8); no gradient, glass,
glow, count-up, confetti, or invented metric appears in the shell (DS-12).

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
| FR-JOB-01..07, 09, 10, 12..14, 16 | `core/crates/jobs/tests/job_lifecycle.rs` (7 tests) | None for engine semantics. |
| FR-JOB-02, 04, 09, 10, 16, 17 | `core/crates/api/tests/facade.rs`: conflicting job refused, unknown handle named, cancelled import leaves nothing final | No client test of the same messages. |
| FR-JOB-08, 18 | `analysis_providers.dart`, `analysis_view.dart`, `export_view.dart` | No widget test of bar type, stage labels, or the single announcement. |
| FR-JOB-11, 15 | None | Requirements the code does not meet. |
| FR-SHL-01..03, 07, 08, 10, 11, 12 | `workspace_studio_screen.dart`, `MainFlutterWindow.swift`; `app_shell_test.dart` covers routes and themes | No studio widget test; no rail-order, window, or controller-sharing test. |
| FR-SHL-25, 26, 29..31, 34, 37 | `player_screen_test.dart`, `theme.dart`, `sportcut_tokens.dart`, `player_view.dart` | No ±5 s, volume, contrast, naming, or network test. |
| FR-SHL-04..06, 09, 13..24, 27..28, 32..36, 38..39 | None | Absent behaviours; see §2.3. |

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
| Design system v1.0 | Geometry, tokens, status vocabulary, voice, accessibility | Design lead |
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
| Q-SHL-01 | Is the global timeline dock in shell scope for v1, or does it stay in the feature views? | Changes the shell layout and the 176 px dock constant. | Design lead |
| Q-SHL-02 | Should the toolbar primary action be Export, with Import moving to the video rail? | Resolves the one-primary-action conflict. | Design lead |
| Q-SHL-03 | Does v1 include a settings screen, or only system-following appearance? | Determines whether any preferences are persisted; shared Q-7 governs the viewport matrix. | Product owner |
| Q-SHL-04 | Should a failed background job raise a persistent banner instead of a SnackBar? | Affects whether a failure keeps its only recovery path. | Product owner |

## 9. Traceability

| Shared requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| BR-1 Offline and private | FR-SHL-13, 37 | DESIGN.md §10; USAGE.md | `workspace_studio_screen.dart` | Manual read; no network test |
| BR-8 Design fidelity | FR-SHL-02..06, 09, 30, 31 | DS-2, 3, 4, 7, 13, 14 | `sportcut_tokens.dart`, `theme.dart` | `app_shell_test.dart` (theme only) |
| BR-9 Accessibility | FR-SHL-32..36 | DS-9, DS-15; USAGE.md | `theme.dart`, `player_view.dart` | None |
| BR-11 Recoverable jobs | FR-JOB-01..19 | DESIGN.md §6 | `core/crates/jobs/`, `core/crates/api/src/jobs.rs`, `analysis_providers.dart` | `job_lifecycle.rs`, `facade.rs` |
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

**Change control.** This document inherits the change control of
[00-product-context.md §18](00-product-context.md#18-approval). A change to
scope, a Must requirement, or the design contract needs a version bump and a
recorded approval. A change that introduces a dependency updates the dependency
register before the implementing change is complete. This BRD claims no release
readiness while R-2, R-4, or the shell Must requirements above remain open.
