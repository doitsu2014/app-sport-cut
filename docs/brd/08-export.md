# Sportcut — Export Business Requirements Document

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-008 |
| Version | 1.0 |
| Status | Draft — for approval |
| Date | 2026-10-29 |
| Product | Sportcut — offline macOS badminton match analyzer |
| Owner | Product owner |
| Contributors | Product, Design, Engineering, QA, Legal/Licensing |
| Feature area | EXP (Export) |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.0 |
| Product BRD | [00-product-context.md](00-product-context.md) |

This document refines the product BRD for Export. Shared requirements, design
requirements, risks, and questions live in
[00-product-context.md](00-product-context.md) and are cited by ID. Requirement
IDs use `FR-EXP-nn`; feature-local risks and questions use `R-EXP-n` and
`Q-EXP-n`, which cannot collide with the shared sets.

## Transport and ownership note (ADR-0001)

[ADR-0001](../adr/0001-rust-background-service.md) moves the engine, catalog,
and export into the Rust background service. The Flutter client collects
settings and sends them over the
[Sportcut Service Protocol v1](../architecture/protocol.md); the service owns
the settings row, the render, and the artifact. This note supersedes "settings
stay in the app catalog" and "crosses the bridge" wording below. The user-facing
export workflow, progress, cancellation, and success state are unchanged. See
[protocol.md §5](../architecture/protocol.md#5-method-table-engine-facade) and
[§6.2](../architecture/protocol.md#62-editing-records).

## 1. Purpose, users, and relationship to the product BRD

Export turns the highlight reel into one video file. It collects the choices
that shape the result — title card, music, padding — states what will be
produced, renders the kept clips, and hands over the file. It is the only
feature that writes new media, and it carries the release gate
([BR-10](00-product-context.md)).

Users are the product BRD §4.1 personas: a coach reviewing with players, a
parent sharing a clip, a club administrator proving nothing left the device.
The outcome is one click, one reel ([BR-6](00-product-context.md)) with zero
network calls ([BR-1](00-product-context.md)). Highlights owns the reel's
contents; this document does not restate clip selection. It adopts
[BR-6](00-product-context.md), [BR-10](00-product-context.md),
[BR-11](00-product-context.md), [NFR-3](00-product-context.md),
[NFR-10](00-product-context.md), and [DS-10](00-product-context.md).

## 2. Scope

### 2.1 In scope for v1

- Export settings per match: title card, local music, gain, lead-in, lead-out.
- A summary stating clip count, runtime, overlays, and audio.
- Export blocked when the reel has no clips.
- One render of the kept clips in the user's order, with trims, concatenation,
  per-clip score overlays, an optional title card, and mixed music.
- A background job with stage-labelled progress and cancellation.
- A success state with the file name, clip count, runtime, play, render again,
  and save or share, plus a stable path recorded as a manifest artifact.
- Release gating on the media toolchain's license.

### 2.2 Out of scope for v1

Each item requires a change request.

- Uploading, publishing, or hosted sharing; a second output format, resolution
  ladder, bitrate control, or user-exposed codec.
- Non-destructive multi-version history; one reel per match is replaced.
- Bundled or downloaded music; v1 mixes only a user-chosen local file (shared Q-6).
- Direct export to a user-chosen folder; the share sheet is the hand-off at
  baseline (shared Q-5). Burned-in captions, transitions, watermarks, speed
  changes.
- A platform-native renderer; required for release, not yet built ([R-2](00-product-context.md), [Q-2](00-product-context.md)).

### 2.3 Delivery status at baseline

Status follows the product BRD §3.3, where Export is **Blocked**.

| Area | Status | Evidence and gap |
| --- | --- | --- |
| Edit decision list and validation | Done | `core/crates/export/src/edit_list.rs` (13 unit tests). |
| Renderer (development path) | Done | `core/crates/export/src/render.rs`; `core/crates/export/tests/render.rs` (6 tests). |
| Shippable render backend | Blocked | The backend is the workstation `ffmpeg`, configured GPL and `not-shippable`; no platform-native renderer exists (baseline `docs/external-dependencies.md`). |
| Export settings | Partial | Title, music path, gain, and padding are stored (`export_settings.dart`, `editing_store.dart`). Gap: gain has no control; no test covers lead-in or lead-out through the screen. |
| Output summary | Partial | Clip count and runtime are shown; a score statement replaces an explicit overlay list and audio line (DESIGN.md §5). |
| Empty-reel blocking | Done | The render button is disabled and the engine rejects an empty list (`export_screen_test.dart`; `edit_list.rs`). |
| Progress and cancellation | Done | `export_providers.dart`; `export_screen_test.dart`, `a running render shows its stage and can be cancelled`; `render.rs`, `a_cancelled_export_leaves_no_partial_reel`. |
| Success state and share | Partial | The file name, clip count, runtime, play, render again, and save-or-share are offered. Gaps: no output path is shown; the share sheet is manual-only; a failed or cancelled render clears the prior success state. |
| Overlay design | Partial | Scoreboard and title are drawn by the app (`overlay_renderer.dart`). Gaps: no L/R labels, off-token colours, default typeface. |
| Codec and patent gate | Blocked | H.264/AAC patent decision is unresolved ([R-4](00-product-context.md), [Q-3](00-product-context.md)). |
| Feature tests | Partial | Nine widget tests, two overlay tests, 13 edit-list tests, six render tests. No test covers the summary's overlay/audio lines, the runtime against the file, a gain control, or a failed re-render. |

## 3. Functional requirements

### 3.1 Settings

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-EXP-01 | Store title-card text per match, and remove the card when the text is blanked. | Must | A non-empty title persists across a reopen; clearing the field stores no title and the render request carries no title card. |
| FR-EXP-02 | Choose background music from a local file, and leave the setting unchanged when the picker is cancelled. | Must | Cancelling the picker writes nothing; choosing a file stores its absolute path and shows its file name. |
| FR-EXP-03 | Remove a chosen music track, returning the reel to match audio only. | Must | After removal the picker reads `No music` and the next render request carries no music path. |
| FR-EXP-04 | Refuse to render when the chosen music file no longer exists, naming the path. | Must | The screen states the music is no longer on the device and no export request reaches the engine. |
| FR-EXP-05 | Store a music gain in `0..1`, default `0.25`, and pass it to the renderer. | Must | The stored gain is the request's gain; a value outside `0..1` is rejected by the engine. |
| FR-EXP-06 | Let the user adjust the music gain. | Should | A control changes the gain within `0..1` and the change survives a reopen. |
| FR-EXP-07 | Set lead-in and lead-out padding in `0..5` s at `0.5` s steps, defaulting to `1.0` s each, and clamp them to the recording at render. | Must | The stored values are the request's values; a clip at the recording's start or end is padded only as far as the recording allows. |
| FR-EXP-08 | Keep settings per match and treat them as choices, not as a record of a render. | Must | Settings survive a reopen; rendering again does not rewrite them; the rendered file is recorded in the manifest, not in the settings row. |

### 3.2 Output summary and blocking

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-EXP-09 | State clip count and runtime before rendering, using the same runtime definition as the success state. | Must | The summary reads `N clips · m:ss` with the reel's clip count, and its runtime agrees with the success state's value for the same reel. |
| FR-EXP-10 | State whether a scoreboard will be burned in, and from which score. | Must | With no confirmed score the summary says no scoreboard is burned in; with a score it states the final `L–R` score. |
| FR-EXP-11 | State the audio the reel will carry. | Must | The summary names match audio, chosen music, or both; `No music` is stated when none is chosen. |
| FR-EXP-12 | Block export when the reel holds no clips, in the screen and in the engine. | Must | The render control is disabled with a plain explanation, and a direct engine call with no clips is refused before any file is written. |
| FR-EXP-13 | Report the runtime of the produced file, including the title card and padding. | Must | The runtime shown after a successful render equals the file's duration within one second. |

### 3.3 Render

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-EXP-14 | Render the kept clips at their effective boundaries, in the user's reel order, into one file. | Must | The rendered reel's clip order and padded boundaries match the edit list; a two-clip fixture renders both, in order, at the requested spans. |
| FR-EXP-15 | Prepend a silent title card when one is set, for a short fixed duration. | Must | A title card renders before the first clip, for 2.5 s, with silence underneath when no music is mixed. |
| FR-EXP-16 | Composite a score overlay on each clip from the score at the clip's effective start, with no invented names. | Must | Each clip's overlay uses the score at its own start; side names are drawn only when the user supplied them. |
| FR-EXP-17 | Mix chosen music under the match audio at the stored gain, covering the whole reel and fading out at its end. | Must | Music shorter than the reel still plays to the end; the music is audible under the clips and fades out over the last 1.5 s. |
| FR-EXP-18 | Keep match audio in step with the picture, and render video only when the recording has no audio. | Must | Match audio starts with the first clip, after any silent title card; a recording without audio produces a video-only file. |
| FR-EXP-19 | Read the source recording without modifying it. | Must | The source file's content hash is unchanged after a render. |
| FR-EXP-20 | Write the reel to one stable path inside the match directory and record it as final only on success. | Must | The reel is `export/highlight.mp4`; the manifest lists it as a final artifact after success; a re-render replaces it without leaving orphans. |
| FR-EXP-21 | Run the render as a background job with one heavy job at a time, and name the blocker when a start is refused. | Must | The UI stays responsive; a second heavy job is refused by name and the slot is released on completion. |
| FR-EXP-22 | Reject an invalid edit list before encoding anything. | Must | Empty clips, a non-finite or non-positive span, a span outside the recording, negative padding, a gain outside `0..1`, and an unreadable overlay, title, or music file are each refused with a message naming the item. |

### 3.4 Progress, cancellation, and completion

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-EXP-23 | Show determinate, stage-labelled progress with a cancel action. | Must | The screen names `prepare`, `render`, or `finalize`; the bar never shows an indeterminate state without a stage label for more than three seconds. |
| FR-EXP-24 | Make cancellation cooperative and leave nothing behind. | Must | Cancelling stops the job, leaves no `.part` file, leaves a previously rendered reel byte-identical, and returns the screen to a renderable state. |
| FR-EXP-25 | Report a failed render with the engine's reason and keep the previously rendered reel available. | Must | A failure shows the reason and the render control; a reel rendered earlier in the session is still offered. At baseline the success state is discarded on failure. |
| FR-EXP-26 | On success, name the file, clip count, and runtime, and offer play, render again, and save or share. | Must | The card shows `Reel ready · <file name>` and `N clips · m:ss`; the pane offers play, render again, and save or share as completion actions. |
| FR-EXP-27 | Hand the finished file to the macOS share sheet, with no fake Finder action. | Must | Save or share opens the system sheet for the rendered file; no control claims to reveal the file in Finder unless it does. |

### 3.5 Overlay and release constraints

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-EXP-28 | Draw overlays at the recording's pixel size, transparent outside the scoreboard. | Must | A 1920×1080 recording produces 1920×1080 overlay images; the scoreboard is transparent outside its chips. |
| FR-EXP-29 | Label the burned-in score `L` and `R`, so the scoreboard is not colour- or position-only. | Must | Both sides carry a side label in the overlay image. |
| FR-EXP-30 | Use the fixed overlay bed and chalk values and the display typeface for burned-in text. | Must | Overlay text uses the `#0A0F0C` bed, `#F2F5F0` chalk, and Archivo; the current renderer uses `#101010`, `#FFFFFF`, and the platform default face. |
| FR-EXP-31 | Keep a render backend that can be replaced without changing the client or catalog. | Must | The renderer consumes an edit list and holds no catalog handle; swapping the backend changes no client or catalog code. |
| FR-EXP-32 | Ship only a license-clean render path. | Must | A release build fails `tools/preflight.sh --strict-license` while the GPL build is the backend; no GPL encoder is linked or invoked in a release build ([NFR-10](00-product-context.md)). |

## 4. State coverage

| State | Expected behaviour | Requirement |
| --- | --- | --- |
| Default | Settings form, summary, and an enabled render control when the reel has clips. | FR-EXP-01…FR-EXP-10 |
| Loading | Settings load behind a progress indicator; a failed load shows its message. | FR-EXP-08 |
| Empty | Summary reads `0 clips · 0:00`; render disabled with a plain explanation; status bar reads `Needs a clip`. | FR-EXP-12 |
| Error | Engine reason shown in place, in the design's danger role; no success card claims a file. | FR-EXP-25 |
| Running | Stage label, determinate bar, cancel action; settings remain readable. | FR-EXP-23 |
| Cancellation | Job reports cancelled; screen returns to renderable; no partial file; previous reel intact. | FR-EXP-24 |
| Success | `Reel ready · <file>`, `N clips · m:ss`, play, render again, save or share. | FR-EXP-26 |
| Disabled | Render disabled with zero clips; controls keep their labels and lower opacity. | FR-EXP-12 |

## 5. Design-contract specifics

Values come from [tokens.css](../../design-system/tokens.css); behaviour from
[DESIGN.md](../../design-system/DESIGN.md).

| Requirement | Design source | Acceptance criterion |
| --- | --- | --- |
| Export is a settings column plus a summary column; the summary states exactly what will be produced: clip count, runtime, overlays, audio. | DESIGN.md §5 Review and export | All four facts are present in one summary region before render. |
| One primary action per pane: `Render reel` is the single accent-filled control; secondary actions use surface fill; Save or share is secondary. | DESIGN.md §5, §6 Actions; tokens `--accent` `#0E6E45` light / `#46D08D` dark | At most one accent-filled button in the pane; disabled render keeps its label at 45% opacity. |
| The progress job shows stage name, determinate bar, percentage, and cancel; no indeterminate bar over three seconds without a stage label. | DESIGN.md §6 Status | A running render shows all four, or the stage label within three seconds. |
| Success is a state with the file name, clip count, and runtime; no fake Finder action. | DESIGN.md §10 Interaction and states | The success card names the file and counts; no Finder-reveal control exists. |
| Numeric copy uses tabular numerals and the `N clips · m:ss` form; voice is short, factual, verb-first. | DESIGN.md §3, §8; [DS-5](00-product-context.md), [DS-10](00-product-context.md), [NFR-11](00-product-context.md) | `12 clips · 4:38`, en dash in scores, no exclamation mark; singular `1 clip`. |
| Motion: stage and progress changes use `--motion-fast` 120 ms; dialogs use `--motion-base` 180 ms and `cubic-bezier(0.2,0,0,1)`; a progress bar does not loop decoratively and reduced motion removes non-essential transitions. | DESIGN.md §7; tokens `--motion-fast: 120ms`, `--motion-base: 180ms` | Under `prefers-reduced-motion` progress and success still update; no looping animation is added. |
| Status is labelled before it is coloured; error and success carry words and icons, not colour alone. | DESIGN.md §2, §6; [DS-4](00-product-context.md) | The error text names what happened; the success card carries a check and the word "ready". |
| Burned-in score overlays use the fixed overlay bed and chalk and sit within the frame's safe margin. | DESIGN.md §2, §6 Overlays | `#0A0F0C` bed, `#F2F5F0` chalk, a 32–56% scrim, and text 5% inside the frame. |

Known drift at baseline, recorded rather than waived:

- The overlay renderer uses `0xFF101010`, `0xFFFFFFFF`, `0x8C000000`, and no font family; DESIGN.md §2 names `#0A0F0C` and `#F2F5F0`, and §3 names Archivo.
- The burned-in scoreboard carries no `L`/`R` labels, which DESIGN.md §6 and [DS-4](00-product-context.md) require.
- The success state draws an accent-bordered card and an accent check in one pane; one accent per pane is the rule, so this needs an audit.
- The summary states audio in a separate card and the scoreboard as a sentence, not as one summary of overlays and audio.
- Progress is polled every 300 ms and shows no percentage text beside the bar.

## 6. Feature non-functional requirements

Shared requirements are cited, not restated.

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| NFR-EXP-1 | Reject an invalid edit list and produce no file. | Must | Every rejection case names the offending item and leaves the output directory unchanged. |
| NFR-EXP-2 | Write atomically: encode into a partial file and rename only on success. | Must | A cancelled or failed render leaves no `.part` file and a prior reel byte-identical ([NFR-3](00-product-context.md)). |
| NFR-EXP-3 | Run entirely offline with local files and the local toolchain. | Must | No network call exists on the path; only the recording, overlays, music, and the local `ffmpeg`/`ffprobe` are read ([BR-1](00-product-context.md), [NFR-1](00-product-context.md)). |
| NFR-EXP-4 | Report progress monotonically within a stage and never decrease it. | Must | Reported fractions per stage are non-decreasing ([NFR-2](00-product-context.md)). |
| NFR-EXP-5 | Keep the renderer and edit list testable without Flutter or Xcode. | Must | The engine tests run with the Rust toolchain and skip cleanly when `ffmpeg` is absent ([NFR-7](00-product-context.md), [NFR-8](00-product-context.md)). |
| NFR-EXP-6 | Gate release on a recorded license verdict for the toolchain and codecs. | Must | No release build ships with the GPL build or an unresolved codec row ([NFR-10](00-product-context.md)). |

## 7. Acceptance and verification evidence

### 7.1 Evidence available at baseline

| Requirement group | Evidence | Status |
| --- | --- | --- |
| Edit-list validation | `core/crates/export/src/edit_list.rs` (13 tests: empty list, span order, non-finite, out of recording, boundary tolerance, negative padding, gain, title duration, unreadable overlay/title/music, padding clamp) | Passes |
| Render order, padding, title | `core/crates/export/tests/render.rs`, `a_rendered_reel_holds_the_clips_in_order_with_padding_and_a_title` | Passes (fixture, skips without ffmpeg) |
| Baseline fixture record | Baseline `docs/verification/manual-editing-and-export.md`: 10.5 s, 2 clips, 618 740 bytes, `mpeg4` video, `aac` audio, 320×240 at 10 fps | Recorded |
| Overlay and title images | `render.rs`, `the_overlay_is_composited_into_the_encoded_frames`; `export_screen_test.dart`, `a title the user typed becomes a title card`; `app/test/overlay_renderer_test.dart` | Passes |
| Match audio, silent source, music | `render.rs`, `the_reel_carries_the_match_audio`, `a_recording_without_an_audio_track_renders_video_only`, `music_shorter_than_the_reel_plays_under_it_to_the_end` | Passes |
| Cancelled export | `render.rs`, `a_cancelled_export_leaves_no_partial_reel` | Passes |
| Request built from the reel | `app/test/export_screen_test.dart`, `rendering asks the engine for the reel the user built` | Passes |
| Empty reel blocked | `export_screen_test.dart`, `an empty reel cannot be rendered` | Passes |
| Progress and cancel | `export_screen_test.dart`, `a running render shows its stage and can be cancelled` | Passes |
| Failure surfaced | `export_screen_test.dart`, `a failure is reported instead of being swallowed` | Passes |
| Finished reel offered | `export_screen_test.dart`, `a finished reel is offered to the user` | Passes |
| Music pick and missing file | `export_screen_test.dart`, two music tests | Passes |
| Reel through the bridge (baseline; retired by ADR-0001) | `app/test/bridge_test.dart`, `a reel renders through the bridge and is recorded as an artifact` | Passes at baseline; the equivalent evidence is protocol conformance for `engine.export.start` and the manifest |
| Summary overlays and audio | None | Gap |
| Displayed runtime against the file | None | Gap |
| Gain control | None | Gap |
| Failed or cancelled re-render keeps the prior reel | None; the state is replaced with the error or an empty state | Gap |

### 7.2 Gaps in evidence

- No release backend exists; the render path runs only against the development `ffmpeg`, so export on a packaged app is manual-only, and no second backend proves the edit list's independence.
- Opening the share sheet is manual-only: `share_plus` hands the file to the operating system with no seam a test can assert through.
- The register says `mpeg4` "is never used for the exported highlight video", while `render.rs` sets `VIDEO_CODEC = "mpeg4"` for export. Documents and code disagree; the code is the stronger signal and the row needs correcting.
- Baseline `docs/verification/manual-editing-and-export.md` records that cancelling a job marks every artifact of the match non-final, including a previous reel. The files are untouched; their recorded state changes.

## 8. Dependencies, constraints, risks, and open questions

### 8.1 Assumptions

- A license-clean renderer (LGPL FFmpeg or a platform encoder) can be adopted behind the edit-list seam without changing the client or catalog.
- The H.264/AAC distribution question is resolved before a store build.
- Users supply their own music; no track is bundled. The match directory remains writable for a render.

### 8.2 Constraints

- Development FFmpeg is GPL-configured and not shippable; the renderer selects `mpeg4` and `aac`, both built into FFmpeg, so no GPL encoder is invoked, while the codec patent question stays separate from the library license.
- One reel per match at a stable path; a re-render replaces it. The reel is an engine manifest artifact; settings are stored in the service catalog.
- Only protocol messages cross the process boundary; the service owns both the engine and the catalog, and the client constructs no engine or catalog paths.

### 8.3 Dependencies

| Dependency | What the feature needs | Owner |
| --- | --- | --- |
| `sportcut-export` | Edit list, validation, render plan, progress, cancellation | Engineering lead |
| `sportcut-api` facade | `export_highlight`, job handle, manifest record | Engineering lead |
| Job registry | One heavy job, cancel, monitorable progress | Engineering lead |
| Media toolchain | Local `ffmpeg`/`ffprobe`, license-clean at release | Engineering lead |
| Client render inputs (`OverlayRenderer`, `share_plus`) | Overlay images at the recording's size; macOS save-and-share hand-off | Engineering lead |
| Design system v1.0 | Summary, states, overlay, voice | Design lead |
| Legal/licensing | FFmpeg configuration, codec patent decision | Legal/licensing |

### 8.4 Risks

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-EXP-1 | The only renderer is a GPL dev build, so export cannot ship. | High | High | Adopt an LGPL configuration or a platform-native renderer behind the edit-list seam; keep the strict-license gate ([R-2](00-product-context.md)). | Engineering lead |
| R-EXP-2 | H.264/AAC patent terms block a store build. | Medium | High | Legal review before the store build; record the decision in the register ([R-4](00-product-context.md)). | Legal/licensing |
| R-EXP-3 | The runtime shown after export omits the title card and padding, so the stated runtime disagrees with the file. | High | Medium | Report the rendered file's duration; test the displayed value against the file. | Engineering lead |
| R-EXP-4 | A failed or cancelled re-render hides the reel the user already had, although the file is intact. | Medium | Medium | Keep the last success state across failure and cancellation; add a test. | Engineering lead |
| R-EXP-5 | The burned-in scoreboard omits L/R labels and uses off-token colours and typeface, weakening accessibility and brand fidelity. | High | Medium | Draw labels, use the fixed overlay bed and chalk, and set the display face; audit the images ([R-6](00-product-context.md)). | Design lead |
| R-EXP-6 | Cancelling one export marks every artifact in the match non-final. | Medium | Medium | Narrow invalidation to the job's own outputs ([R-8](00-product-context.md)). | Engineering lead |

### 8.5 Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-EXP-1 | Is the music gain a user control in v1, or a fixed mix level? | Decides whether FR-EXP-06 is Must or deferred. | Product owner |
| Q-EXP-2 | Does the success state show the output path, offer a save-to-folder dialog, or rely on the share sheet alone? | Shapes the success state's actions with shared Q-5. | Product owner |
| Q-EXP-3 | Should the pre-render summary show clip-only runtime, or the total including the title card and padding? | The summary and success state must agree on one definition. | Product owner |

## 9. Traceability

| Business requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| [BR-6](00-product-context.md) One click produces one reel | FR-EXP-01…FR-EXP-28 | DESIGN.md §5, §6, §8, §10 | `app/lib/src/features/export/`; `core/crates/export/`; `facade.rs` (`export_highlight`) | `app/test/export_screen_test.dart`; `core/crates/export/tests/render.rs`; `app/test/bridge_test.dart` |
| [BR-1](00-product-context.md) Offline and private | FR-EXP-02, FR-EXP-04, NFR-EXP-3 | DESIGN.md §10 status bar | `audio_file_picker.dart`; render reads local files only | Baseline offline suite; no network in the path |
| [BR-10](00-product-context.md) / [NFR-10](00-product-context.md) Licensing gate | FR-EXP-31, FR-EXP-32, NFR-EXP-6 | — | `core/crates/export/src/lib.rs` backend seam; `render.rs` codec choice | `tools/preflight.sh --strict-license`; register rows — open |
| [BR-11](00-product-context.md) / [NFR-3](00-product-context.md) Recoverable jobs | FR-EXP-21, FR-EXP-23, FR-EXP-24, NFR-EXP-2 | DESIGN.md §6 Status | `export_providers.dart`; `render.rs` `PartialFile` | `render.rs`, cancelled-export test; `export_screen_test.dart` |
| [BR-8](00-product-context.md) / [BR-9](00-product-context.md) Design and accessibility | Section 5 rows; FR-EXP-28, FR-EXP-29, FR-EXP-30 | DESIGN.md §2, §3, §5, §6, §7, §10 | `export_view.dart`; `overlay_renderer.dart` | No design or accessibility audit recorded |

Code index: `export_view.dart`, `export_providers.dart`, `export_exception.dart`,
`audio_file_picker.dart`, `overlay_renderer.dart`, `export_settings.dart`,
`core/crates/export/src/{edit_list,render,lib}.rs`, `facade.rs`, `dto.rs`. Prior
evidence: `docs/verification/manual-editing-and-export.md`, `docs/architecture.md`,
`docs/data-storage-models.md`, `docs/external-dependencies.md`.

## 10. Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |
| Legal/licensing |  | Approve / revise |  |

**Change control.** A change to scope, a Must requirement, or the design
contract requires a version bump and a recorded approval. A new dependency
updates the register before the implementing change is complete. This document
inherits the version and baseline of
[00-product-context.md](00-product-context.md).
