# Sportcut Design System

> Court-side broadcast · v1.0
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
- On footage, use the fixed overlay bed `#0A0F0C` with chalk `#F2F5F0` and a scrim between 32% and 56% opacity. The overlay never samples the frame color beneath it.
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
- Scoreboard figures use Archivo at 48–76px with a line height below 1. Never animate or count up a score.
- The minimum is 12px for anything read as a sentence and 10px for mono micro-labels, with 9px permitted only in dense chrome or overlays. If a label does not fit, shorten the words rather than shrink past that floor.

## 4. Spacing & grid

The scale is a 4px grid: 4, 8, 12, 16, 20, 24, 32, 48. Component padding uses 8/12/16; panel padding 16/20; section rhythm 40/56/72.

### Layout constants

| Surface | Value |
| --- | --- |
| Window chrome height | 52px |
| Video rail width | 264px |
| Feature rail width | 320px |
| Rail gutter | 12px |
| Panel padding | 16px / 20px |
| List row height | 56px (compact), 64px (rich) |
| Dialog width | 420px (confirm), 520px (settings) |
| Minimum window | 1100 × 720px |

### Shape and depth

- Radii: 6px for thumbnails and inputs, 10px for buttons and rows, 14px for panels and dialogs, pill for chips and status.
- Three elevation levels only: flat, ring (1px border-like shadow), raised (a 1–2px contact shadow plus one soft ambient shadow). No inner shadows, glass, or neon glows.
- Focus is a 2px surface-colored gap plus a 2px solid accent ring, visible on both themes. Never remove the outline without an equivalent replacement.

## 5. Layout & composition

### Three-pane studio

The workspace is the app's spine: videos on the left, one shared preview in the center, and the pipeline as a vertical rail on the right. The center takes all remaining width; the rails keep their fixed 264px and 320px widths.

- One primary action per pane. Import lives in the video rail, Export in the feature rail, playback in the preview. Do not duplicate a primary action across panes.
- The preview is never narrower than 480px at the minimum window. If the window cannot honor that, collapse the rails before shrinking the preview.
- Rails collapse below 980px of available width: the studio stacks preview first, then videos, then pipeline. Floating panels over footage are not allowed.
- A selected rail item uses `--surface` plus a ring. It does not use a colored left bar or a filled accent block.
- Keep 24px from the window edge for chrome and essential controls. Video overlays keep critical text 5% inside the frame.

### Review and export

- Review is a two-column composition: footage and its transport on the left, scoreboard and last rallies on the right, with the rally timeline spanning both underneath.
- Export is a settings column plus a summary column. The summary states exactly what will be produced: clip count, runtime, overlays, and audio.
- Dialogs are 420–520px wide, left-aligned, with actions right-aligned. Destructive actions sit apart from the confirming action and always name the object.

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

- **Match row:** 64×36 thumbnail, one-line title with ellipsis, metadata, and a tabular score. A missing recording shows an alert icon plus "Recording missing" and a Locate action; it does not look like a normal row.
- **Video rail item:** thumbnail, title, duration, and score. Selected state is a ring, not an accent fill.
- **Empty state:** one factual sentence and one action. "No videos in this workspace." plus Import video.

### Timeline and score

- **Scoreboard:** L and R labels, 48–76px tabular figures, serving marker, and the last three rallies. The serving side carries a 2px accent underline under its label.
- **Rally scrubber:** rally segments in a 22% accent tint, rest periods in `--surface-warm`, playhead in `--fg`. Segment boundaries are draggable with a minimum 20px hit target. Timecodes sit above the track in mono.
- **Clip row:** in/out timecodes, duration, score context, and keep/dismiss actions. Kept clips use a check and a surface ring; dismissed clips lower opacity but remain recoverable until export.
- **Transport:** play/pause, ±5s, volume, and a tabular timecode. Controls are 32–36px and never overlap the frame's critical content.

### Overlays

- **Calibration:** four corner handles (24px visual, 44px hit target), a dashed net line, and one instruction line. Handles use accent only when they are being dragged.
- **Score bug:** fixed dark bed, chalk text, 2px live dot, L/R labels, rally number, and timecode. It sits within the top 20% of the frame and never covers the court's action area.
- **Dialog:** title, one-paragraph body, right-aligned Cancel plus one confirming action. No stacked primary buttons.

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
- No invented metrics or filler copy. Sample data must be plausible and clearly sample data.
- No text below 9px, no body copy below 16px, and no low-contrast muted text on footage.

## 10. Studio shell (macOS)

The studio is the product surface: a floating macOS window rather than a documentation page. It uses the same tokens and type as the system, with one more layer of material and density.

### Window and chrome

- 1440 × 900 reference window, 14px radius, one soft window shadow, 1px border. The window floats on a dark court-line desktop; no gradient wallpaper.
- Rows: 52px unified toolbar, flexible workspace, 176px timeline dock, 30px status bar.
- Toolbar: traffic lights (system chrome, not controls), wordmark, workspace breadcrumb, centered command search, library/inspector toggles, focus mode, and the single primary action — Export.
- No in-app theme switch or viewport selector. The app follows the system appearance; the preview is always dark because it is footage.
- Surfaces are layered solids with color-mix; no glass panels, blur, neon glow, or decorative gradients.

### Workspace

| Region | Width | Contents |
| --- | --- | --- |
| Library sidebar | 264px | Workspace title, video rows, import |
| Preview | Flexible, min 480px | Footage, score bug, floating transport |
| Inspector | 320px | Rally and Clip tabs, score, keep, reel summary |

- The sidebar row is the selection unit: thumbnail, one-line title with ellipsis, meta, and score. Selected uses a surface shift plus a check, never an accent bar.
- The preview is the brightest content area. The score bug keeps the same fixed overlay bed and index numerals as the system; the floating transport sits above the frame's lower edge and never covers the score.
- The inspector is a work surface, not a dashboard: one scoreboard, two winner buttons, the last three rallies, and a clip panel with one keep switch.
- The timeline dock shows a 10-minute working window rather than the full match. Rally segments are buttons; kept rallies use an accent tint, the selected rally gets a 2px outline, and the playhead is a 1px accent line. Clicking the ruler or track seeks.
- The status bar states the local-only promise, video count, rally and score, and export readiness.

### Interaction and states

- Selecting a video updates the preview, inspector, timeline window, and export summary.
- Play/pause runs a simulated clock; seeking updates the playhead; scoring L/R appends a rally, updates the score and serving side, and focuses the same button after re-render.
- Keep/dismiss updates the reel count and export summary; dismissed clips remain recoverable.
- Missing recording: the preview is replaced by a Locate state; the timeline and scoring are disabled until a file is chosen.
- Zero clips: Export is blocked with a plain explanation rather than an empty file.
- Export: native dialog, progress, and a success state with the file name, clip count, and runtime. No fake Finder action.
- Search filters the library and has an empty state with a clear action.

### Keyboard

| Key | Action |
| --- | --- |
| Space | Play / pause |
| ← / → | Back / forward 5 seconds |
| L / R | Left / right won the rally |
| F | Focus mode |
| E | Open export |
| ⌘K | Focus search |
| Esc | Exit focus mode or close the export sheet |

### Responsive behavior

- At 1200px and 1040px the rails narrow; the breadcrumb and search drop before the preview does.
- Below 900px the command field leaves the toolbar; below 860px the window becomes a full-bleed vertical layout: library strip, preview, inspector, timeline. Nothing scrolls horizontally.
- Below 560px the transport compresses, the export label becomes an icon, and secondary status items hide. The score, primary actions, and export state remain.

**Client status.** The Flutter client implements the toolbar, 264/320 rails, center header, and status bar from this section. The global timeline dock is still drawn inside the Score and Highlights feature views rather than as one shared shell dock.

## 11. Adoption

`tokens.css` is the source of truth. Artifacts paste its `:root` block; the Flutter client maps the same values into `ColorScheme`, `TextTheme`, and component themes. `USAGE.md` contains the mapping table and the accessibility checklist.