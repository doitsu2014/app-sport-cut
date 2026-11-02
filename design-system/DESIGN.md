# Sportcut Design System

> Court-side broadcast · v1.1 · 2026-11-02
> A low-glare, video-first interface system for Sportcut, the offline badminton match analyzer for macOS.

## 1. Visual theme & atmosphere

Sportcut is a working tool, not a highlight reel. The interface sits around a match recording for a long time, so the system is built to disappear: quiet surfaces, one signal color, and typography that reads at a glance from across a desk.

The direction is **court-side broadcast**: the precision of a scorekeeper's ledger and the legibility of a broadcast score bug, without the noise of a sports broadcast. Hairline rules replace heavy cards. Numbers are tabular and steady. Chrome stays matte while footage carries the color.

- **Footage first.** The video frame is the brightest, largest surface. No panel, button, or badge competes with it.
- **One signal.** Court green means action, selection, progress, or the serving side. It is never decoration.
- **Labels before color.** Every state carries a word or an icon. Color reinforces, never carries meaning alone.
- **Precise over decorative.** Court-line geometry, aligned numerals, and honest dividers. No ornamental gradients or floating glass.
- **Two rooms.** Light is the scorekeeper's desk: library, import, setup, export review. Dark is the editing booth: long review sessions over footage.

The atmosphere is dry and confident. Surfaces are cool chalk and graphite, not cream or beige. There are no glows, no purple washes, and no celebratory effects.

## 2. Color

### Ground and ink

| Role | Token | Light | Dark |
| --- | --- | --- | --- |
| Page ground | `--bg` | `#F1F3EF` | `#0B100D` |
| Raised surface | `--surface` | `#FFFFFF` | `#121814` |
| Recessed surface | `--surface-warm` | `#E8ECE7` | `#182019` |
| Primary text | `--fg` | `#101713` | `#EDF2EC` |
| Secondary text | `--fg-2` | `#39443D` | `#BCC6BE` |
| Supporting text | `--muted` | `#5C6860` | `#8B978F` |
| Strong meta | `--meta` | `#4A554E` | `#A7B3AA` |
| Divider / border | `--border` | `#C7D0C8` | `#2B342E` |
| Hairline | `--border-soft` | `#DFE5DF` | `#1E2721` |

### Signal and state

| Role | Token | Light | Dark |
| --- | --- | --- | --- |
| Signal | `--accent` | `#0E6E45` | `#46D08D` |
| On signal | `--accent-on` | `#FFFFFF` | `#04140C` |
| Signal hover | `--accent-hover` | darken 8% | lighten 10% |
| Signal active | `--accent-active` | darken 14% | lighten 18% |
| Success | `--success` | `#157347` | `#57C98F` |
| Warning | `--warn` | `#8A5A00` | `#E3B24E` |
| Danger | `--danger` | `#B42318` | `#F27B70` |

### Rules

- Reserve `--accent` for the primary action, the selected item, the serving side, progress fill, and the active pipeline stage. If two elements in one pane are green, one of them is wrong.
- Pair every semantic state with a label or icon: `READY`, `ANALYZING`, `DONE`, `BLOCKED` — not a colored dot alone.
- Scores use **L** and **R** labels. Accent marks who is serving. Losing a rally is not an error state, so it is never red.
- Body text must reach 4.5:1 against its surface; large text, icons, and essential graphics 3:1. Audit dark mode independently rather than assuming the light ratios carry over.
- On footage, use the fixed stage bed `#050806` (ADR-0003 D16 supersedes the earlier `#0A0F0C` value) with chalk `#F2F5F0` and a scrim between 32% and 56% opacity. The overlay never samples the frame color beneath it.
- Semantic text (`--success`, `--warn`, `--danger`) stays on `--surface` or `--bg`; on tinted fills, use `--fg` or `--accent-on`.

## 3. Typography

| Role | Family | Weights | Used for |
| --- | --- | --- | --- |
| Display | Archivo | 600, 700, 800 | Scoreboard figures, screen titles, section headings |
| Body | IBM Plex Sans | 400, 500, 600 | Labels, paragraphs, lists, controls |
| Mono | IBM Plex Mono | 400, 500, 600 | Timecodes, rally numbers, token names, micro-labels |

### Scale

| Token | Size | Line | Use |
| --- | --- | --- | --- |
| `--text-xs` | 12px | 1.35 | Captions, chips, micro-labels |
| `--text-sm` | 14px | 1.45 | Rail metadata, secondary controls |
| `--text-base` | 16px | 1.55 | Body copy, form values, list titles |
| `--text-lg` | 18px | 1.5 | Lead paragraphs, dialog body |
| `--text-xl` | 24px | 1.2 | Panel titles, clip headings |
| `--text-2xl` | 32px | 1.12 | Screen titles |
| `--text-3xl` | 44px | 1.06 | Hero headings |
| `--text-4xl` | 64px | 1.0 | Reference page display only |

### Rules

- Body copy is 16px minimum with 1.55 line height and 65–75 characters per line on desktop.
- Display type is set tight (`-0.025em`); body and UI text stay at normal tracking.
- Scores, durations, and timecodes always use tabular numerals (`font-variant-numeric: tabular-nums`), so digits do not shift as the score changes.
- Micro-labels are 10–12px mono in the system, uppercase, with 0.08–0.12em tracking. Dense macOS chrome and footage overlays may use 9px; never below. They label; they never carry a sentence.
- Scoreboard figures use Archivo at 48–76px with a line height below 1. The preview score bug uses the same family at 28–36px. Never animate or count up a score.
- The minimum is 12px for anything read as a sentence and 10px for mono micro-labels, with 9px permitted only in dense chrome or overlays. If a label does not fit, shorten the words rather than shrink past that floor.

## 4. Spacing & grid

The scale is a 4px grid: 4, 8, 12, 16, 20, 24, 32, 48. Component padding uses 8/12/16; panel padding 16/20; section rhythm 40/56/72.

### Layout constants

| Surface | Value |
| --- | --- |
| Window chrome height | 52px |
| Stage strip height | 40px |
| Video rail width | 264px at ≥1200px; 240px from 1100–1199px (the 1100px minimum makes the 1040px tier unreachable) |
| Inspector width | 320px at ≥1200px; 292px from 1100–1199px (the 270px tier is unreachable below the minimum) |
| Rail column border | 1px `--border`, no gutter (ADR-0003 D15) |
| Preview floor | 480px |
| Rails collapse below | 980px of available width |
| Panel padding | 16px / 20px |
| List row height | 44px (compact), 56px (rich) |
| Field height | 34px |
| Chip height | 20px |
| Toolbar icon | 18px |
| Thumbnail | 52 × 30px |
| Transport max width | 640px |
| Timeline dock height | 176px |
| Status bar height | 30px |
| Dialog width | 420px (confirm), 520px (settings) |
| Export sheet width | 440px |
| Reference window | 1440 × 900px |
| Minimum window | 1100 × 720px |

These constants follow `ScMetrics`. The row heights replace the earlier 56/64 pairing, and the 12px rail gutter is retired by ADR-0003 D15.

### Shape and depth

- Radii: 6px for thumbnails and inputs, 10px for buttons and rows, 14px for panels and dialogs, pill for chips and status.
- Three elevation levels only: flat, ring (1px border-like shadow), raised (a 1–2px contact shadow plus one soft ambient shadow). No inner shadows, glass, or neon glows.
- Focus is a 2px surface-colored gap plus a 2px solid accent ring, visible on both themes. Never remove the outline without an equivalent replacement.

## 5. Layout & composition

### Shared review surface

Sportcut's studio is one review surface, not three screens. Play, Review & score, and Highlights are review lenses of a single shell: the same 52px toolbar, 40px stage strip, responsive video rail and inspector (264/320px at ≥1200px, 240/292px from 1100–1199px), one preview and one transport, 176px timeline dock, and 30px status bar. Geometry, controls, playback, the editing session, and the data never fork (FR-SHL-46).

The stage strip is the primary and only persistent stage navigation. Its seven entries are fixed: Play, Mark court, Prepare analysis, Player analysis, Review & score, Highlights, Export. Five are pipeline work stages (Mark court, Prepare analysis, Player analysis, Review & score, Highlights); Play is the first entry and a review lens with no pipeline output; Export is a stage-strip action that opens the 440px sheet and never changes the selected stage. The inspector's collapsed pipeline summary is a secondary locator, not a second rail. No lens may add another navigation strip.

A lens changes exactly three things in the composition: the read-only overlay drawn over the footage, the inspector's default tab and scroll anchor, and the timeline's emphasis. The same controls, shortcuts, and components remain available; the lens only changes which action is primary. Each lens is a small, testable delta from this contract rather than a separate composition. A new stage supplies a lens-matrix row and an overlay-slot set before it is complete.

#### 5.1 Anatomy

- Toolbar: 52px, invariant.
- Stage strip: 40px, seven fixed entries in the order above. Each pipeline work-stage entry carries a label and a word or icon state marker (DONE, READY, ANALYZING n%, BLOCKED); Play carries no pipeline marker and Export shows only its readiness or blocked state. The selected entry gets a 2px accent underline.
- Workspace row: video rail 264px at ≥1200px (240px from 1100–1199px), one shared preview host (`ScVideoStage`) at flexible width with a 480px floor and aspect-fit 16:9 on `#050806`, inspector 320px at ≥1200px (292px from 1100–1199px). The rails end in a 1px `--border` column border with no gutter.
- Timeline dock: 176px, shell-owned.
- Status bar: 30px, invariant except for the short entry label (Play, Score, Clips).

Invariant: the shell grid, toolbar, stage strip, video rail, preview host, transport, inspector shell, timeline dock, status bar, one playback controller, one editing session, and one rally-review session per selected video.

Variable: the preview overlay set, the inspector's default tab and scroll anchor, and the timeline emphasis. These are the only per-lens differences in composition; the available controls and shortcuts are shared.

Selecting a video loads one recording, opens one playback controller and one editing session, and resets the lens to Play (FR-LIB-12). Switching a lens preserves playback position, play state, selected rally, and any open edit. Below 980px of available width the studio stacks preview, video rail, then inspector; the preview keeps its 480px floor. No lens has its own route, full-screen takeover, second preview, second transport, or second timeline.

#### 5.2 Review lens matrix

| Lens | Entry | Overlay | Inspector default | Scroll anchor | Timeline emphasis | Primary action | Keyboard |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Play | Default lens and first stage-strip entry; selecting a video resets here. No pipeline prerequisite or output; selectable when the recording is missing. | Floating transport only. | Rally | Rally list and last rallies. | Playhead and selected rally. | Play/pause. | Space, ←/→, L/R. |
| Review & score | Stage strip; selectable at any time, with the inspector stating what is missing when its prerequisite is absent (FR-SHL-11). Preserves the shared recording and session. Rally analysis and manual marking live in its Rally tab. | Transport plus the read-only score bug in the top band; rally boundary handles join L4 only when FR-RAL-33 is implemented. | Rally | Scoreboard/winner block and pending suggestions. | Score chips and scored rallies. | Score L/R; mark rally. | Space, ←/→, L/R. |
| Highlights | Stage strip; selectable at any time, with the inspector stating what is missing when its prerequisite is absent (FR-SHL-11). Ranking is recomputed from the current edit on entry; never a separate player. | Transport plus the read-only clip slate in the top band. | Clip | Selected clip detail and reel summary. | Kept/left-out segments and selected clip. | Keep clip; keep top N. | Space, ←/→, L/R; keep via the clip row. |

- `L/R` scores the selected rally in every review lens (FR-SHL-21, FR-SCR-26). Play produces no pipeline artifact, but it shares the same editing session, so scoring from Play is the same single write as from Review & score.

- Entry labels are canonical: Play, Review & score, Highlights. "Playback" is retired as a stage name.
- The lens never changes the selected video, reloads the recording, or forks the session. It changes only the composition: the overlay (FR-SHL-47), the inspector default tab and scroll anchor (FR-SHL-48), and the timeline emphasis (FR-SHL-48). The same controls and shortcuts stay available.
- A lens whose prerequisite is missing stays selectable; its overlay or inspector states what is missing (FR-SHL-11).
- The score bug belongs only to Review & score; the clip slate belongs only to Highlights; Play carries neither.

#### 5.3 Overlay slots and stacking

One named stack sits inside the preview frame, painted bottom to top:

- L0 Footage: the recording on the fixed `#050806` bed.
- L1 Underlay: stage scrim, pointer-inert, 32–56% opacity.
- L2 Read-only data: the score bug or the clip slate; pointer-transparent.
- L3 Floating transport: interactive, shared by every stage.
- L4 Stage annotation: calibration handles, net line, tracking boxes, and rally boundary handles (Review & score only when FR-RAL-33 is implemented); painted above the transport but hit-tests only its own targets.
- L5 Blocking state: missing, unplayable, or loading; owns all input.
- L6 Shell transient: toast, export sheet, dialogs; lives outside the frame.

- A lens uses exactly the layers in its matrix row. Play is L0/L3; Review & score is L0/L1/L2/L3, plus L4 only when FR-RAL-33 is implemented; Highlights is L0/L1/L2/L3; Mark court and Player analysis add L4 only, and Prepare analysis adds none.
- Read-only data never accepts a pointer event. Annotation never intercepts a tap outside its own targets. Blocking state takes every input until it clears.
- The top data band is outside the action area; read-only data may occupy it. L4 annotation handles may enter the court; no other interactive control may, and they are never a floating panel. No overlay exists outside this stack.
- The overlay uses the fixed bed `#050806`, chalk `#F2F5F0`, and accent `#46D08D`, with the scrim behind any text over footage.
- Stacking is structural: the shell paints the slots in order. A new z-index, scrim, or stage-bed role is added to `tokens.css` before use (DS-1).

#### 5.4 Safe areas

- Critical text keeps a 5% frame inset or 16px, whichever is larger.
- The top 20% is the data band for the score bug and clip slate. At the 480px preview floor the 16:9 frame is 270px tall, so the band is 54px; if a readout does not fit, shorten the words rather than grow the band.
- The transport sits 14px above the bottom edge with a 20px horizontal inset and a 640px maximum width.
- Reserve 56px at the bottom for the transport and segment targets.
- Corner handles are 24px visual with a 44px hit target. Rally boundary edges keep a 20px minimum horizontal hit target inside the 44px-high track; they are not corner handles, so the two sizes are not interchangeable.
- The action area is the court polygon excluding the top data band. Read-only data may enter the top band; no interactive control other than L4 annotation handles may cover the action area.

#### 5.5 Inspector grammar

The inspector keeps one order in every lens:

1. Collapsed pipeline summary, above the tabs. It is a secondary locator.
2. A 26px Rally | Clip tablist for Play, Review & score, and Highlights, or the stage's contextual panel for Mark court, Prepare analysis, and Player analysis.
3. A scrolling tab body.
4. The reel summary at the end of the body.

- Play, Review & score, and Highlights use the same Rally and Clip tabs in the same order. The lens sets only the default tab and scroll anchor from §5.2.
- Mark court, Prepare analysis, and Player analysis replace the tab body with their contextual panel; the collapsed summary stays.
- Export has no inspector panel. It opens the 440px sheet and does not change the selected stage. The sheet is a settings column plus a summary column; the summary states exactly what will be produced: clip count, runtime, overlays, and audio.
- One score hierarchy: the inspector scoreboard is the single editable ledger at 48–76px tabular figures. The preview readout is a compact broadcast readout, never a second editor.
- The body carries empty, loading, busy, and error content in place. At 200% text scaling the body scrolls; no tab, field, or action disappears.
- Every tab and action stays reachable without switching lens.

#### 5.6 Timeline grammar

- One dock is shell-owned for the whole studio, on every stage and lens. It is never per feature.
- Geometry: 176px total, 34px header, 112px label gutter, 24px ruler, 44px rally track, 32px score track, and a 10-minute working window.
- One `windowSpan` drives the header, ruler, click-to-seek, and playhead. They never disagree.
- Palette: resting track `--surface-warm`; unkept rally 22% accent; kept segment 32% accent; selected segment a 2px `--fg` outline; playhead a 1px `--accent` line. Score chips use `--surface` with accent only on the selected event.
- Segments are buttons: click seeks and selects. Rally boundary drag belongs to FR-RAL-33, inside this dock or the preview overlay, Review & score only, with a 20px hit target. Segments stay buttons for seek and select. No second scrubber appears in the inspector.
- The lens changes emphasis only: Play emphasizes the playhead and selected rally; Review & score emphasizes score chips and scored rallies; Highlights emphasizes kept/left-out segments and the selected clip. Tracks and geometry do not change.
- A missing recording disables seeking and states the fact; it offers no locate action (ADR-0003 D8). An empty window states "No rallies in this window." rather than drawing an unexplained empty track.

#### 5.7 State and disabled matrix

One matrix lives in the shell. Feature BRDs contribute content states only.

| State | Where it lives | Copy | Behavior |
| --- | --- | --- | --- |
| No video selected | Preview blocking layer | "Select a video to preview." | Timeline, scoring, and export disabled; the video rail keeps the Import action. |
| Loading | Preview blocking layer | "Loading the recording." | Transport disabled; no second preview; the shell keeps the selected lens. |
| Missing recording | Preview blocking layer; video rail row | "Recording missing" / "The recording is no longer at its original path." / "Importing a replacement creates a new match." | No Locate action. Scoring, seeking, and export disabled; the row stays visibly missing. |
| Unplayable recording | Preview blocking layer | "This recording cannot be played on this device." plus the file name and reason | Play and scrub disabled; the match stays listed. |
| No score | Rally tab body | "No rallies yet. Scrub to a point, mark its start and end, and say who won it." | Marking and L/R stay available when a rally span is selected. |
| No clips | Clip tab / reel summary | "No clips in the reel yet. Add a rally from the left-out list, or mark one on the score timeline." | Export blocked; the reel summary reads zero. |
| Job running | Stage strip marker | "ANALYZING n%" | One heavy job at a time; other navigation stays reachable; the dock stays readable. |
| Edit busy | Tab body or inline control | "Saving the edit." | Controls disabled while busy; position and selection are retained. |
| Edit error | Inspector banner | "That change could not be saved." | The in-memory edit is kept; the user can retry. |
| Export blocked | Export sheet banner | "Keep at least one clip before exporting." or "Import the recording again before exporting." | The render action is disabled; no file is produced. |

Precedence: blocking shell state, then lens content state, then job state. Status-bar readiness stays sentence case (Needs a clip, Ready to export, Checking); uppercase READY/ANALYZING/DONE/BLOCKED belongs to the stage strip.

#### 5.8 Lens-change motion

- A lens change moves no geometry. The shell crossfades the overlay and the inspector emphasis over `--motion-fast` (120ms); the timeline changes emphasis without a transition.
- No slide, scale, page transition, or route animation. The preview never reloads, so the frame does not flash.
- Under `prefers-reduced-motion`, the change is instant; the new overlay and emphasis are present on the first frame.

#### 5.9 Accessibility

- Focus order (expanded): toolbar, stage strip, video rail, preview and transport, inspector, timeline, status bar.
- Focus order (collapsed below 980px): toolbar, stage strip, preview and transport, video rail, inspector, timeline, status bar, matching the visual stack.
- The score bug and clip slate expose one semantic summary each; their individual figures are not separately focusable. The transport and dock keep named controls.
- 44px handles, 20px segment targets, and a visible 2px accent focus ring on every interactive element.
- Contrast is audited against `#050806` and the worst-case frame, not the design backdrop; text over footage uses the scrim.
- At 200% text the stage strip shortens labels before the type floor, the inspector body scrolls, and nothing clips.
- No critical text sits under macOS window chrome or platform overlays.

## 6. Components

### Actions

- **Primary button:** one per pane, verb-first label ("Import video", "Export reel"). 40px tall, 10px radius, accent fill, `--accent-on` text. Compact variant is 32px.
- **Secondary:** surface fill with a 1px border. **Ghost:** no fill until hover. **Destructive:** danger text and border, never a filled red button unless the action is irreversible and confirmed.
- Disabled controls keep their size and label; they lower opacity and remove the pointer. A loading button keeps its width and swaps the icon for a spinner.
- Icon buttons are 36×36 with a tooltip and an accessible name. Do not use an icon alone for a destructive action.

### Status

- **Chip:** dot or icon plus an uppercase mono label. States: ready (accent), analyzing (warning plus progress), done (success check), blocked (danger), needs review (muted).
- **Pipeline row:** 24px number, stage name, state label, optional action. Completed rows show a check; running rows show the stage and percentage; blocked rows name the blocker.
- **Progress job:** stage name, determinate bar, percentage, cancel. Never show an indeterminate bar for longer than three seconds without a stage label.
- **Banner vs toast:** a banner sits in the layout and persists until resolved; a toast is transient (4s), one line, and never holds the only path to recovery.

### Library

- **Match row:** 52×30 thumbnail, one-line title with ellipsis, metadata, and a tabular score. A missing recording shows an alert icon plus "Recording missing"; it does not look like a normal row, and it offers no Locate action (ADR-0003 D8).
- **Video rail item:** thumbnail, title, duration, and score. Selected state is a ring, not an accent fill.
- **Empty state:** one factual sentence and one action. "No videos in this workspace." plus Import video.

### Timeline and score

- **Scoreboard:** the inspector's single editable ledger, with L and R labels, 48–76px tabular figures, a serving marker, and the last three rallies. The serving side carries a 2px accent underline under its label. It is never duplicated at hero size in the preview.
- **Timeline dock:** one shell-owned 176px dock on every stage and lens. A 34px header, a 112px label gutter, and 24px ruler, 44px rally, and 32px score tracks over a 10-minute window. Resting track is `--surface-warm`; an unkept rally takes a 22% accent tint, a kept segment 32% accent, the selected segment a 2px `--fg` outline, and the playhead a 1px `--accent` line. Segments are buttons with a 20px hit target; the lens changes emphasis only.
- **Clip row:** in/out timecodes, duration, score context, and keep/remove actions. Kept clips use a check and a surface ring; left-out clips lower opacity but remain recoverable until export. Use the same keep/remove vocabulary on every lens.
- **Transport:** play/pause, ±5s, a scrubber, and tabular position and duration. Controls are 28/32px, the floating bar is at most 640px wide and sits 14px above the frame's bottom edge, and it never overlaps the frame's critical content. Volume is deferred (ADR-0003 D12), so the transport carries no volume control.

### Overlays

- **Calibration:** four corner handles (24px visual, 44px hit target), a dashed net line, and one instruction line. Handles use accent only when they are being dragged. This is a stage annotation in slot L4.
- **Score bug:** a compact read-only broadcast readout in the top band, with a fixed dark bed, chalk text, a 6px live dot, L/R labels, rally index and total, serving side, and timecode. The score is 28–36px tabular, never 44–76px. It is pointer-transparent, never animates or counts up a score, and never covers the court's action area (slot L2).
- **Clip slate:** a compact read-only readout in the top band, with the suggested rank (#n), clip index and total, kept/left-out word, and in/out timecodes for the selected clip. It is pointer-transparent, shows no score bug, and is a broadcast readout rather than a second editor (slot L2).
- **Dialog:** 420–520px wide, left-aligned, with actions right-aligned. Title, one-paragraph body, Cancel plus one confirming action. Destructive actions sit apart from the confirming action and name the object. No stacked primary buttons.

### States

| State | Treatment |
| --- | --- |
| Hover | Surface tint or border shift; text never fades to gray |
| Focus-visible | 2px accent outer ring with surface gap |
| Active | 14% accent darken (light) or 18% lighten (dark) |
| Disabled | 45% opacity, no pointer, label retained |
| Loading | Preserve size, spinner replaces the leading icon |
| Selected | Surface + ring, plus an explicit check or label |
| Error | Danger border, icon, and message beneath the field |

## 7. Motion & interaction

- `--motion-fast` 120ms for hover, focus, and chip changes. `--motion-base` 180ms for dialogs, rail selection, and panel reveals. Exits run at roughly 70% of the entrance duration.
- Easing is `cubic-bezier(0.2, 0, 0, 1)`; enter with ease-out, exit with ease-in.
- Motion explains a state change, hierarchy, or causality. List items stagger 30ms; nothing loops.
- The scrubber, score digits, and video frame do not animate. Scrubbing follows the pointer immediately.
- A lens change moves no geometry: the overlay and inspector emphasis crossfade at 120ms, the timeline changes emphasis without a transition, and nothing slides, scales, or routes. Under reduced motion the change is instant (§5.8).
- Under `prefers-reduced-motion`, transitions collapse to near-zero and scroll behavior becomes instant. Layout and feedback still work without motion.

## 8. Voice & brand

Sportcut speaks like a good scorekeeper: short, factual, and specific. It names the rally, the side, the file, or the next action.

| Avoid | Write |
| --- | --- |
| "Oops! Something went wrong." | "The recording is no longer at its original path." |
| "Awesome job! You scored!" | "Left won. Score 18–16." |
| "Processing your amazing video…" | "Preparing analysis · Rally detection 42%" |
| "Click here to get started" | "Import video" |
| "0:00:42.123" | "0:42" |

- Labels are verb-first and literal. No exclamation marks, no "magic", no anthropomorphism.
- Numbers are formatted for scanning: `18–16`, `0:42`, `12 clips · 4:38`.
- Empty states and errors say what happened and what the user can do next. They never blame the user.

## 9. Anti-patterns

- No cream, beige, peach, or orange-brown page grounds. Sportcut's neutral is cool chalk.
- No purple gradients, decorative gradient washes, glassmorphism, or neon glows.
- No gradient or image-filled primary buttons. The signal color is flat.
- No rounded card with a colored left-border accent as a callout. Use a hairline, a label, or spacing.
- No icon beside every heading, and no second primary button in the same pane.
- No color-only scoring, no red-for-loss, and no green-for-win without an L/R label.
- No count-up animations, confetti, particles, or celebratory overlays.
- No floating cards, tooltips, or chrome over the court's action area.
- No second review layout, no per-lens reflow of the three-pane grid, and no full-screen stage takeover. Play, Review & score, and Highlights differ only by overlay, inspector default tab and scroll anchor, and timeline emphasis.
- No second preview, transport, or timeline, and no per-feature timeline dock. One shell owns each.
- No hero-size score in the preview while the inspector ledger is visible; the read-only bug stays at 28–36px.
- No invented metrics or filler copy. Sample data must be plausible and clearly sample data.
- No text below 9px, no body copy below 16px, and no low-contrast muted text on footage.

## 10. Studio shell (macOS)

The studio is the product surface: a floating macOS window rather than a documentation page. It uses the same tokens and type as the system, with one more layer of material and density.

### Window and chrome

- 1440 × 900 reference window, 14px radius, one soft window shadow, 1px border. The window floats on a dark court-line desktop; no gradient wallpaper.
- Rows: 52px unified toolbar, 40px stage strip, flexible workspace row, 176px shared timeline dock, 30px status bar.
- Toolbar: traffic lights (system chrome, not controls), wordmark, workspace breadcrumb, centered command search, library/inspector toggles, focus mode, and the single primary action — Export.
- Stage strip: seven fixed entries in this order — Play, Mark court, Prepare analysis, Player analysis, Review & score, Highlights, Export. Each pipeline work-stage entry carries a label and a word or icon state marker; Play carries no pipeline marker and Export shows only readiness. The selected entry gets a 2px accent underline. The strip is the primary and only persistent stage navigation. Export is a stage-strip action that opens the 440px sheet without changing the selected stage.
- No in-app theme switch or viewport selector. The app follows the system appearance; the preview is always dark because it is footage.
- Surfaces are layered solids with color-mix; no glass panels, blur, neon glow, or decorative gradients.

### Workspace

| Region | Width | Contents |
| --- | --- | --- |
| Stage strip | 40px | Seven fixed entries with a state marker; 2px accent underline on the selected entry |
| Video rail | 264px (240px from 1100–1199px) | Workspace title, video rows, Import in the footer |
| Preview | Flexible, min 480px | Footage, floating transport, lens overlay (FR-SHL-47) |
| Inspector | 320px (292px from 1100–1199px) | Rally and Clip tabs, stage emphasis, scoreboard, last three rallies, keep, reel summary |
| Timeline dock | 176px | Ruler, rally, and score tracks; shell-owned on every stage |
| Status bar | 30px | Local-only promise, counts, score, entry label, export readiness |

- The video rail row is the selection unit: thumbnail, one-line title with ellipsis, meta, and score. Selected uses a surface shift plus a check, never an accent bar. Selecting a video loads one recording and resets the lens to Play (FR-LIB-12).
- The preview is the brightest content area and one shared host for every stage. It accepts only the overlay slots and the transport, never reloads on a lens change, and never becomes a second preview. Only the named overlay slots in §5.3 may paint over footage; floating panels are not allowed.
- The inspector is a work surface, not a dashboard, and the scoreboard is the single editable ledger. The lenses set emphasis only:

| Lens | Inspector default and emphasis | Timeline emphasis |
| --- | --- | --- |
| Play | Rally tab; rally list and last rallies. | Playhead and selected rally. |
| Review & score | Rally tab; scoreboard/winner block and pending suggestions. | Score chips and scored rallies. |
| Highlights | Clip tab; selected clip detail and reel summary. | Kept/left-out segments and selected clip. |

- The preview score bug is a read-only, compact top-band readout; never two hero scores at once.
- The timeline dock is shell-owned on every stage. It shows a 10-minute working window rather than the full match; rally segments are buttons; kept segments use a 32% accent tint, unkept rallies 22%, the selected segment a 2px `--fg` outline, and the playhead a 1px accent line. Clicking the ruler or track seeks.
- The status bar states the local-only promise, video count, missing count, current score, short entry label (Play, Score, Clips), and export readiness. It is invariant by lens except for the short entry label; uppercase READY/ANALYZING belongs to the stage strip.

### Interaction and states

- Selecting a video updates the shared preview, inspector, timeline window, and export summary, and opens in Play.
- Play/pause runs the shared clock; seeking updates the playhead. Scoring L/R appends a rally on any review lens with a rally selected, updates the score and serving side, and focuses the same button after re-render. It does not change the lens.
- Switching a lens preserves position, play state, selected rally, and any open edit; nothing reloads and no route changes.
- Keep/remove updates the reel count and export summary; left-out clips remain recoverable until export.
- Missing recording: the preview shows the blocking state with "Recording missing", "The recording is no longer at its original path.", and "Importing a replacement creates a new match." There is no Locate action; the timeline, scoring, and export are disabled.
- Zero clips: Export is blocked with "Keep at least one clip before exporting." rather than producing an empty file.
- Export: sheet, progress, and a success state with the engine-produced file name, clip count, and runtime. No fake Finder action.
- Search filters the video rail and has an empty state with a clear action.
- One surface, no forks: no lens adds its own route, full-screen takeover, preview, transport, timeline, or review layout.

### Keyboard

| Key | Action |
| --- | --- |
| Space | Play / pause |
| ← / → | Back / forward 5 seconds |
| L / R | Left / right won the rally, on any review lens with a rally selected |
| F | Focus mode |
| E | Open the export sheet from any stage or lens |
| ⌘K | Focus search |
| Esc | Exit focus mode or close the export sheet |

### Responsive behavior

- The reference window is 1440×900 and the minimum is 1100×720. At the minimum both rails stay open and the preview is at least 480px wide.
- From 1100–1199px the rails narrow to video 240px and inspector 292px. The 1040px tier in `ScMetrics` is below the supported 1100px window minimum and is not reachable. The breadcrumb and search drop before the preview does.
- Below 980px of available width the studio stacks preview, video rail, then inspector. The preview keeps its 480px floor and nothing scrolls horizontally.
- At 200% text scaling the stage strip shortens labels rather than shrinking type below the floor; the inspector body scrolls.
- There is no web or mobile breakpoint in v1; the studio is one macOS window (BR-12).

**Client status.** The Flutter client implements the shared `StudioShell`: 52px toolbar, 40px stage strip, rails at 264/320px (240/292px from 1100–1199px), one preview, the shell-owned 176px timeline dock, the stage-aware inspector, and the 30px status bar. `ScoreView` and `HighlightsView` are pre-shell routes and are non-product; they must not define a second review layout.

Known drift from this section: `ScScoreBug` still renders a 64px score in a three-row stack that exceeds the top band; Highlights still opens the Rally tab instead of Clip; legacy score and highlight routes still fork the layout; the transport has no volume control (deferred, ADR-0003 D12); and `studio.html` has no stage strip and paints a full-frame bug, so it is a visual-language reference only.

## 11. Adoption

`tokens.css` is the source of truth. Artifacts paste its `:root` block; the Flutter client maps the same values into `ColorScheme`, `TextTheme`, and component themes. `USAGE.md` contains the mapping table and the accessibility checklist.

Before a new stage ships, it supplies a §5.2 lens-matrix row and a §5.3 overlay-slot set. A stage that only adds content supplies a §5.7 content state and no new geometry. The review checklist for any layout change: one preview, one transport, one timeline, one inspector order, and no new route.