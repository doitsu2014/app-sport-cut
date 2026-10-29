# Sportcut Studio Refactor — Final Plan

Read-only research pass: no files were edited, created, or deleted; no builds or tests were run; `design-system/Sportcut-Design-System.zip` was not opened. All paths are under the repository root `/Users/ductranhuu/workspaces/doitsu-technology/app-sport-cut`.

## Why this backbone

Two plans were evaluated against fidelity, risk, time-to-visible-value, reviewability, and constraint compliance.

| Criterion | Foundation-first | Shell-first strangler |
| --- | --- | --- |
| Design-system fidelity | Strongest token/component detail; but invents a 40px stage strip and delays the actual studio surface | Targets `studio.html` directly; the studio chrome and geometry arrive early; pipeline navigation is initially undefined |
| Risk | Small phases, but feature migration is late and the 1,417-line monolith is decomposed only in step 4 | Higher first shell PR, but a behaviour-preserving decomposition plus a temporary legacy slot keeps the app working throughout |
| Time-to-visible-value | Low: nothing looks like the studio until Phase 3 | High: the studio shell is visible at PR 3 |
| Reviewability | Very small PRs, but ten decisions and eight phases create long ceremony | Region-sized PRs with clear vertical slices; each PR is independently reviewable |
| Constraint compliance | Full | Full |

**Chosen backbone: shell-first strangler.** It gets a realistic studio on screen quickly, isolates the monolith behind a behaviour-preserving move, and lets each feature migrate into its studio home one PR at a time. The foundation-first plan is the better reference for token completeness, decision discipline, and accessibility rigor, so those are grafted in wholesale, along with its stage-strip solution for pipeline navigation.

The resulting sequence is: **contract lock → foundation → small component PRs → behaviour-preserving decomposition → visible studio shell → preview/timeline → inspector → feature migration → macOS chrome → accessibility**.

---

## 1. Context & goal

### 1.1 Verified baseline

| Area | Current state | Consequence |
| --- | --- | --- |
| `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart` | 1,417 lines, about 25 private widgets; 52px toolbar, 264px video rail, 320px pipeline rail, 30px status bar; 1px dividers; center is a feature takeover | Highest-risk edit. Decompose behaviour-preserving before restyling. |
| `app/lib/src/app/design/sportcut_tokens.dart` | 364 lines. `SportcutPalette` has all 16 CSS colours exactly. `SportcutTokens` has space, radii, motion, overlay colours, 264/320/52/30, and duplicated success/warn. | Extend, do not rewrite. Add palette extension, typography, elevation, focus, easing, and `ScMetrics`. |
| `app/lib/src/app/theme.dart` | 373 lines. Full light/dark `ThemeData`, bundled Archivo/IBM Plex, tabular figures, themed buttons/inputs/dialogs. Focus is a 30-alpha tint; icon buttons are 32×32; `materialTapTargetSize: shrinkWrap`. | Keep the foundation; fix focus rings, target sizes, and register new extensions. |
| Feature views | Material-default forms and lists. Four transports, four black video surfaces, three playback-error blocks, five progress panels, five empty states, duplicate delete dialogs. Only the studio screen reads `SportcutTokens`. | The `Sc*` library must exist before migration. |
| Routing | Plain `AppRoutes` table in `app/lib/src/app/router.dart`; studio pushed imperatively with `MaterialPageRoute`; duplicate `*_screen.dart` wrappers; `PlaceholderScreen` is dead. | Add a named `/studio` route; keep legacy wrappers compiling until the final cleanup. |
| macOS runner | Standard `NSWindow`; 1100×720 minimum; 1180×760 default; native title bar above the Flutter 52px toolbar | Double chrome. Dedicated PR for `fullSizeContentView` with native traffic lights. |
| Fonts | Archivo, IBM Plex Sans, IBM Plex Mono bundled with OFL files; register row exists in `docs/brd/00-product-context.md` §11.2. | No new font asset needed. |
| Icons | Built-in Material icons used ad hoc. `studio.html` loads Material Symbols Rounded from Google Fonts. | Use `Icons.*_rounded` through `ScIcons`; never port the network font load. |
| Tests | 18 files; `app_shell_test.dart` is stale. Per CLAUDE.md, do not add tests; touch an existing test only when a compile break requires it. | Verification is `flutter analyze` plus a manual visual checklist. |
| Service boundary | App reaches the engine only through `app/lib/src/bridge/sportcut_engine.dart`; no FFI, no network, no Rust in the app. | Preserve unchanged. |

### 1.2 Goal

Make `app/` look and behave like the `design-system/studio.html` product surface: a realistic macOS video-editing studio with a 52px unified toolbar, a 264px video library, a flexible preview, a 320px Rally/Clip inspector, a 176px shared timeline dock, a 30px status bar, focus mode, command search, keyboard transport, and an export sheet.

### 1.3 Hard constraints

- Features stay under `app/lib/src/features/<feature>/{domain,data,presentation}`.
- Riverpod is the only state and DI mechanism.
- The router table lives in `app/lib/src/app/router.dart`.
- Engine access only through `app/lib/src/bridge/sportcut_engine.dart`; no sockets, protocol methods, or engine calls in widgets.
- No new durable client-owned state, schema migration, network, FFI/Rust, or Flutter dependency.
- Fonts remain the three bundled OFL families. No `google_fonts`; no network font.
- New dependency, model, font, or icon asset needs a licensing-register row in `docs/brd/00-product-context.md` before the change is complete.
- Verify with `cd app && flutter analyze`; do not add tests unless explicitly requested.
- Product remains semi-automatic: the app proposes rally spans and suggestions; the user confirms winners. No copy or behaviour may claim automatic officiating.

### 1.4 Non-goals

- Do not port `index.html` documentation chrome (topbar, TOC, hero, gallery).
- Do not implement the generic 360–1920px web viewport matrix; macOS minimum is 1100×720.
- Do not add drag-to-resize rails, drag-to-trim rally handles, volume control, a settings screen, or an in-app theme switch in this refactor.
- Do not draw fake macOS traffic lights.
- Do not fake a "Locate recording" recovery path that the repository and protocol do not support.

### 1.5 Design contract decisions

These are locked in PR 0 and recorded in `docs/adr/0003-studio-shell-refactor.md`.

| ID | Decision | Rationale |
| --- | --- | --- |
| D1 | `studio.html` is the product target, not `index.html`. | The manifest marks `index.html` launcher-overview only; DESIGN.md and USAGE.md call `studio.html` the macOS prototype. |
| D2 | Add a 40px `StageStrip` under the toolbar: Play, Mark court, Prepare analysis, Player analysis, Review & score, Highlights, Export. | The app needs stage navigation that `studio.html` does not model. A horizontal page strip keeps the DS three-pane geometry and gives `ScPipelineRow` a home. **Needs sign-off; it is an app-specific extension, not a DS chrome token.** |
| D3 | The 176px shared timeline dock is in scope. | DESIGN.md §10 and `studio.html` require it; the user explicitly asked for a realistic studio. BRD 09 §2.2 currently excludes it and must be amended. |
| D4 | Export is the single primary toolbar action; Import moves to the video-rail footer. | DESIGN.md §10 and BRD Q-SHL-02; the current toolbar makes Import primary. |
| D5 | Selected rail row = `--surface-warm` fill + 1px `--border` ring + explicit check. No accent bar. | `studio.html:499-502`; DESIGN.md says surface + ring, never accent. |
| D6 | Keep native macOS traffic lights; adopt `fullSizeContentView` + transparent title bar + leading inset. Never draw fake lights. | DESIGN.md: traffic lights are system chrome, not controls. Removes the current double chrome. |
| D7 | Use Flutter's built-in Material Icons mapped to `Icons.*_rounded`. Bundle Material Symbols Rounded only with a license-register row and an offline asset. | Avoids a new asset and avoids the network font in `studio.html`. |
| D8 | Missing recording: show an honest missing state; no fake Locate until `MatchRepository` or the protocol exposes a relocation path. Importing a replacement creates a new match, and the copy must say so. | `match_repository.dart:149` exposes only `isRecordingAvailable`. Do not invent recovery. |
| D9 | Freeze the existing accent hover/active hexes and document them as Oklab-mix approximations. Do not recompute mid-refactor. | They already ship and are visually within a few units of the CSS `color-mix`. |
| D10 | No new durable client state. Search, focus mode, rail visibility, inspector tab, selected rally, timeline window, export-sheet visibility, and toasts live in an in-memory Riverpod controller only. | CLAUDE.md; metadata migration is Phase 4. |
| D11 | Export reuses `ExportSettings` (title, music, gain, lead-in/out). Do not add a persisted filename field; `ExportRequestDto` has no filename. "Include score overlays" is sheet-local and ephemeral. | Avoids a protocol change and durable state. Show `ExportedReel.fileName` on success. |
| D12 | Defer volume control and drag-to-trim rally boundaries. | `PlaybackController` has no volume API; no repository method updates a rally span. |
| D13 | Follow `ThemeMode.system`; no in-app theme switch. The preview bed is always dark because it is footage. | DESIGN.md §10; USAGE.md. |
| D14 | The inspector is stage-aware: Rally/Clip tabs for Play, Review & score, and Highlights; contextual panels for Mark court, Prepare analysis, Player analysis, and Export. There is no second persistent pipeline rail. | Preserves the DS inspector while giving calibration, analysis, and tracking a 320px work surface. |

### 1.6 Target geometry

| Region | Value |
| --- | --- |
| Toolbar | 52px |
| Stage strip | 40px (app extension) |
| Workspace | flexible |
| Video library | 264px |
| Preview | flexible, minimum 480px |
| Inspector | 320px |
| Rail gutter | 12px |
| Timeline dock | 176px (34px header + 112px label gutter + 24/44/32px tracks) |
| Status bar | 30px |
| Minimum window | 1100×720 |
| Reference window | 1440×900 |
| Narrow rails | 240/292 at 1200px; 222/270 at 1040px |
| Collapse | below 980px available width |

At 1100px: `1100 − 264 − 320 − 24 = 492px` preview, which satisfies the 480px floor.

---

## 2. Design-system → Flutter token mapping

### 2.1 Color

`SportcutPalette` becomes a `ThemeExtension<SportcutPalette>` with `copyWith`, `lerp`, and `SportcutPalette.of(context)`. Register it in `ThemeData.extensions`. Keep the existing values; they match `tokens.css` exactly.

| CSS token | Flutter symbol | Light / dark | Notes |
| --- | --- | --- | --- |
| `--bg` | `palette.bg`, `scaffoldBackgroundColor`, `scheme.surfaceContainerLowest` | `#f1f3ef` / `#0b100d` | |
| `--surface` | `palette.surface`, `scheme.surface` | `#ffffff` / `#121814` | |
| `--surface-warm` | `palette.surfaceWarm`, `scheme.surfaceContainer` | `#e8ece7` / `#182019` | |
| `--fg` | `palette.fg`, `scheme.onSurface` | `#101713` / `#edf2ec` | |
| `--fg-2` | `palette.fg2`, `scheme.onSurfaceVariant` | `#39443d` / `#bcc6be` | |
| `--muted` | `palette.muted` | `#5c6860` / `#8b978f` | Not in `ColorScheme`; palette extension required. |
| `--meta` | `palette.meta` | `#4a554e` / `#a7b3aa` | |
| `--border` | `palette.border`, `scheme.outline` | `#c7d0c8` / `#2b342e` | USAGE.md maps this to `outlineVariant`; the theme's `outline=border` / `outlineVariant=borderSoft` is semantically correct. Record the doc correction in ADR 0003; do not edit the design system. |
| `--border-soft` | `palette.borderSoft`, `scheme.outlineVariant` | `#dfe5df` / `#1e2721` | |
| `--accent` | `palette.accent`, `scheme.primary` | `#0e6e45` / `#46d08d` | |
| `--accent-on` | `palette.accentOn`, `scheme.onPrimary` | `#ffffff` / `#04140c` | |
| `--accent-hover` | `palette.accentHover` | `#0b603b` / `#63dea4` | Frozen per D9; document Oklab provenance. |
| `--accent-active` | `palette.accentActive` | `#095433` / `#7be6b2` | Frozen per D9. |
| `--success` | `palette.success` | `#157347` / `#57c98f` | Remove duplicate from `SportcutTokens`. |
| `--warn` | `palette.warn` | `#8a5a00` / `#e3b24e` | Remove duplicate from `SportcutTokens`. |
| `--danger` | `palette.danger`, `scheme.error` | `#b42318` / `#f27b70` | Errors only; a lost rally is not an error. |
| overlay bed | `ScOverlayColors.bed`, `SportcutTokens.overlayBed` | `#0a0f0c` both | Fixed footage value; permitted raw hex. |
| overlay chalk | `ScOverlayColors.ink`, `SportcutTokens.overlayInk` | `#f2f5f0` both | |
| overlay signal | `ScOverlayColors.signal`, `SportcutTokens.overlaySignal` | `#46d08d` both | |
| scrim 32–56% | `ScOverlayColors.scrim` | bed at 44% | Derived constant; stage gradient uses 55%/62%. |
| rally tint 22% | `ScTints.rally(accent, surface)` | `Color.alphaBlend(accent.withValues(alpha: .22), surface)` | DESIGN.md:153. |
| kept tint 32% / hover 42% | `ScTints.kept`, `ScTints.keptHover` | Derived | `studio.html:1610`. |
| pressed toolbar tool 12% | `ScTints.pressedTool` | Derived | `studio.html` tool-button pressed state. |
| selected rally outline | 2px `palette.fg` border | | |
| playhead | 1px `palette.accent` | | Use accent per `studio.html`; DESIGN.md says `--fg`, so document the choice. |

### 2.2 Typography

Create `SportcutTypography` as a `ThemeExtension` registered in `theme.dart`, plus a mapped `TextTheme`. Sizes below 12px exist only in dense chrome and overlays. Every score, duration, and timecode uses `FontFeature.tabularFigures()`.

| Role | Family | Size / height / weight / tracking | Use |
| --- | --- | --- | --- |
| `display64` | Archivo | 64 / 1.0 / 700 / -0.035em | Reference only |
| `display44` | Archivo | 44 / 1.06 / 700 / -0.03em | Hero |
| `display32` | Archivo | 32 / 1.12 / 700 / -0.025em | Screen title |
| `title24` | Archivo | 24 / 1.2 / 600 / -0.02em | Panel titles |
| `title20` | Archivo | 20 / 1.2 / 700 / -0.02em | Clip heading |
| `lead18` | IBM Plex Sans | 18 / 1.5 / 400 | Lead paragraph |
| `body16` | IBM Plex Sans | 16 / 1.55 / 400 | Body floor |
| `sm14` | IBM Plex Sans | 14 / 1.45 / 400–600 | Controls and rail metadata |
| `xs12` | IBM Plex Sans | 12 / 1.35 / 500 | Captions and chips |
| `micro10` | IBM Plex Mono | 10 / 1.35 / 600 / 0.08em uppercase | Micro-labels |
| `chrome9` | IBM Plex Mono | 9 / 1.35 / 600 / 0.10em uppercase | Dense chrome and overlays only |
| `score48/52/64/76` | Archivo | width × / ≤0.86 / 700 / -0.04em, tabular | Scoreboard and score bug |
| `timecode11` | IBM Plex Mono | 10–11 / 1.35 / 500, tabular | Timecodes |

Font weights and per-size line heights are prose-only in DESIGN.md; encode them here and propose matching upstream `--leading-*` and weight tokens in a future design-system release.

### 2.3 Space, radius, elevation, motion

| CSS group | Flutter destination | Notes |
| --- | --- | --- |
| `--space-1..6,8,12` | `SportcutTokens.space1..space12` | Keep values 4/8/12/16/20/24/32/48. |
| `--radius-sm/md/lg/pill` | `SportcutTokens.radiusSm/Md/Lg/Pill` | 6/10/14/9999. |
| `--elev-flat` | `ScElevation.flat` | No shadow. |
| `--elev-ring` | `ScElevation.ring(palette.border)` | `BoxShadow(color: border, spreadRadius: 1)`. |
| `--elev-raised` light | `ScElevation.raisedLight` | Black 8% blur 2 offset (0,1) + black 6% blur 40 offset (0,16). |
| `--elev-raised` dark | `ScElevation.raisedDark` | Black 50% blur 2 + black 45% blur 44 offset (0,18). |
| `--focus-ring` | `ScFocusRing.decoration(palette)` | `0 0 0 2px surface, 0 0 0 4px accent`; apply via `WidgetStateProperty`. |
| `--motion-fast/base` | `SportcutTokens.motionFast/motionBase` | 120ms / 180ms. |
| `--ease-standard` | `ScMotion.easeStandard` | `Cubic(0.2, 0, 0, 1)`. |
| exit ~70% | `ScMotion.exitFast/exitBase` | 84ms / 126ms. |
| list stagger 30ms | `ScMotion.stagger` | 30ms. |
| section rhythm 72/56/40 | `ScMetrics.sectionYDesktop/Tablet/Phone` | |
| container 1240 / gutters 40/28/20 | `ScMetrics.containerMax/GutterDesktop/Tablet/Phone` | |

### 2.4 Layout metrics

These are plain `static const double` values in `ScMetrics`, not theme colours and not a `ThemeExtension`.

| Design value | Flutter symbol |
| --- | --- |
| 52px toolbar | `ScMetrics.toolbarHeight` |
| 40px stage strip | `ScMetrics.stageStripHeight` |
| 264px library | `ScMetrics.libraryWidth` |
| 320px inspector | `ScMetrics.inspectorWidth` |
| 240/292 and 222/270 narrow rails | `ScMetrics.libraryWidthNarrow1/2`, `inspectorWidthNarrow1/2` |
| 12px rail gutter | `ScMetrics.railGutter` |
| 480px preview floor | `ScMetrics.previewMinWidth` |
| 980px collapse | `ScMetrics.collapseBreakpoint` |
| 1200/1040px narrow breakpoints | `ScMetrics.narrowBreakpoint1/2` |
| 176px dock | `ScMetrics.timelineHeight` |
| 34px dock header | `ScMetrics.timelineHeaderHeight` |
| 112px label gutter | `ScMetrics.timelineGutter` |
| 24/44/32px track rows | `ScMetrics.timelineRuler/Rally/Score` |
| 600s working window | `ScMetrics.timelineWindowSeconds` |
| 14px minimum segment width | `ScMetrics.rallySegmentMinWidth` |
| 20px segment hit target | `ScMetrics.rallySegmentHitTarget` |
| 30px status bar | `ScMetrics.statusHeight` |
| 56/64px rows | `ScMetrics.rowCompact/rowRich` |
| 420/520px dialogs | `ScMetrics.dialogConfirm/dialogSettings` |
| 440px export sheet | `ScMetrics.exportSheetWidth` |
| 1100×720 min / 1440×900 reference | `ScMetrics.minWindow*/reference*` |
| 36px icon button, 30px toolbar tool, 40px button, 32px compact, 26px tab, 24px chip, 40px field | `ScMetrics.iconButton/toolButton/button/buttonCompact/tab/chip/field` |
| 24px visual / 44px hit handle | `ScMetrics.courtHandleVisual/courtHandleHit` |

### 2.5 Token rules

- No raw hex outside `sportcut_tokens.dart` and `sc_overlay_colors.dart`.
- No component-local colour that duplicates a token. Add a semantic role to the design layer first.
- Use `Color.alphaBlend` for tints and scrims rather than new hex values.
- Do not freeze `--elev-ring` or `--focus-ring`; both resolve through theme variables and must adapt to dark mode.
- No raw spacing, radius, or font size in feature/widget code; use `SportcutTokens`, `ScMetrics`, and `SportcutTypography`.
- The palette and typography are theme extensions; layout geometry is `ScMetrics`.

---

## 3. Studio information architecture

### 3.1 Window layout

```text
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●   Sportcut   Workspace / Match          [⌘K  Search videos          ]  ▣ ◫ ⤢  Export │ 52px
├──────────────────────────────────────────────────────────────────────────────────────┤
│ Play  │  Mark court  │  Prepare analysis  │  Player analysis  │  Review & score  │  Highlights  │  Export │ 40px stage strip
├────────────────┬───────────────────────────────────────────────┬─────────────────────┤
│ LIBRARY  264px │ PREVIEW  flexible, minimum 480px               │ INSPECTOR  320px    │
│                │                                               │                     │
│ Club session   │ ┌───────────────────────────────────────────┐ │ [ Rally | Clip ]    │
│ 3 videos · 1 M │ │                                           │ │                     │
│                │ │  video stage / overlay bed                │ │ Rally:              │
│ VIDEO ROWS     │ │                                           │ │  scoreboard         │
│ 64×36 thumb    │ │  score bug: rally, L/R, serve, timecode   │ │  L won / R won      │
│ title · meta   │ │                                           │ │  last three rallies │
│ score · check  │ │                                           │ │                     │
│ missing state  │ │        floating transport (bottom 14)     │ │ Clip:               │
│                │ └───────────────────────────────────────────┘ │  details, keep, trim│
│ Import video   │  calibration / tracking overlays live here     │  reel summary foot  │
├────────────────┴───────────────────────────────────────────────┴─────────────────────┤
│ TIMELINE DOCK  176px                                                                 │
│ Timeline   37:17 – 47:17   10 min view   4 rallies                                   │
│ ┌─ 112px ─┬───────────────────────────────────────────────────────────────────────┐  │
│ │ Time    │  37:17      39:47      42:17      44:47      47:17                    │  │ 24px
│ │ Rallies │  [ 7 ][ 8 ][ 9 ][ 10 ][ 11 ][ 12 ][ 13 ][ 14 ]                       │  │ 44px
│ │ Score   │       [18-15] [18-16] [17-16] [18-16] ...                               │  │ 32px
│ └─────────┴───────────────────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ ● On-device · No cloud    3 videos · 1 missing    Rally 14/32 · 18–16    READY TO EXPORT │ 30px
└──────────────────────────────────────────────────────────────────────────────────────┘
```

The 12px gutters separate the rails from the preview. Focus mode hides both rails, keeps the stage strip, timeline dock, transport, and Export. A second persistent pipeline rail does not exist; the `StageStrip` replaces it and the inspector remains a work surface.

### 3.2 Feature → panel/mode map

| Existing view or state | Studio home | Reused logic | Removed or replaced |
| --- | --- | --- | --- |
| `WorkspaceScreen` | Home (`/`) restyled in the studio family | `workspaceListProvider`, `importControllerProvider` | Material `Card` and `ListTile` |
| `WorkspaceStudioScreen` | `StudioShell` composition root | provider watches, controller lifecycle, listeners, delete flows | 1,417-line monolith and private chrome widgets |
| `PlayerView` | Preview Play mode | `PlaybackController`, `PlaybackState` | Black box and docked transport |
| `CalibrationView` | Preview calibration overlay + Inspector Mark court panel | `calibrationControllerProvider`, court painter | Full-screen takeover, amber handles, solid net |
| `AnalysisView` | Inspector Prepare analysis panel; preview stays on playback | `analysisControllerProvider` | `DataTable`, center takeover |
| `PlayerTrackingView` | Preview tracking overlay + Inspector Player analysis panel | `playerTrackingControllerProvider` | 230px bottom panel, raw colours |
| `ScoreView` | Preview score bug + Inspector Rally tab + timeline dock | `editingControllerProvider`, `rallyReviewControllerProvider`, `servingSidesProvider` | Center scoreboard takeover, list-only rallies |
| `HighlightsView` | Inspector Clip tab + reel footer; preview the selected clip | `editingControllerProvider`, `highlightRankingProvider` | Center reel takeover, `MaterialBanner`, `ActionChip` |
| `ExportView` | `ExportSheet` modal from the toolbar or stage strip | `exportControllerProvider`, `ExportSettings` | Center `Card` form |
| Rally suggestions | Inspector Rally tab | `rallyReviewControllerProvider` | `ExpansionTile` and fixed 220px list |
| Editing session | Shell-owned | `editingControllerProvider` | Per-view `open()` calls in studio paths |
| Route wrappers | Thin route hosts composing the same panels | Existing constructors | Duplicated playback lifecycle in four files |

### 3.3 State ownership

| State | Provider / owner | Lifetime |
| --- | --- | --- |
| Selected video, stage, search query, focus mode, rail visibility, inspector tab, selected rally, timeline window, export-sheet visibility, toast | `StudioController` (`NotifierProvider.autoDispose.family<StudioController, StudioState, String>` keyed by workspace id) | In-memory; disposed with the studio |
| Editing session | `editingControllerProvider`; shell calls `ensureOpen(match)` once per selected video | One session at a time |
| Rally review/suggestions | `rallyReviewControllerProvider`; opened by `ScoreSession` when the Rally tab mounts | Stage-scoped |
| Playback | One `PlaybackController` per selected video, created and disposed by the shell | Per selected video |
| Workspace videos and stage facts | `workspaceVideosProvider`, `workspaceVideoFactsProvider` | Riverpod cache |
| Analysis job | `analysisControllerProvider` | App-wide; survives navigation |
| Export | `exportControllerProvider` | App-wide |
| Import | `importControllerProvider` | App-wide, one import at a time |

No durable client state is added. Export settings remain the existing `ExportSettings`; the score-overlay toggle is sheet-local.

### 3.4 Interaction and keyboard

| Input | Action |
| --- | --- |
| `Space` | Play/pause when focus is not in a text field or on a button that handles space |
| `←` / `→` | Seek −5s / +5s |
| `L` / `R` | Score the selected unscored rally; if none, toast `Select a rally on the timeline.` |
| `F` | Toggle focus mode |
| `E` | Open the export sheet |
| `⌘K` | Focus and select the search field |
| `Esc` | Close export sheet → exit focus mode → clear search |

Shortcuts are centralized in `studio_shortcuts.dart` using `Shortcuts`/`Actions` plus a `Focus` guard. No shortcut fires while an `EditableText` has focus. The inspector tab control supports left/right arrows when focused.

Scoring remains semi-automatic: the app offers rally suggestions; the user accepts, adjusts, or dismisses them, and confirms the winner with L/R. Copy never says the app determined a winner.

### 3.5 Responsive and collapse

- At or above 1200px: 264/320 rails.
- 1040–1199px: 240/292 rails.
- 980–1039px: 222/270 rails.
- Below 980px: stack preview, then videos, then inspector; no horizontal scroll. This is unreachable at the 1100px macOS minimum with both rails open, but implement it for correctness and document that rail toggles provide the practical collapse.
- Below 900px: hide the command field; below 860px: full-bleed vertical layout (implemented for completeness, not reachable on macOS).
- Focus mode: both rails hidden; preview fills the workspace; stage strip, dock, transport, and Export remain.
- Rail toggles are explicit 30×30 toolbar buttons with pressed state and accessible names.

---

## 4. Component inventory

### 4.1 Design-system surface → Flutter widget

| Design-system surface | Flutter widget | File | Required states and notes |
| --- | --- | --- | --- |
| Primary / secondary / ghost / destructive button | `ScButton`, `ScButtonVariant` | `app/lib/src/app/design/components/sc_actions.dart` | Default, hover, focus, active, disabled (45%, no pointer), loading (spinner replaces leading icon, width preserved); 40px, compact 32px |
| Icon button / toolbar tool / keycap | `ScIconButton`, `ScToolbarButton`, `ScKeycap` | `sc_actions.dart` | 36×36 icon button, 30×30 toolbar tool, pressed accent 12%; tooltip and semantic label required |
| Pressable state wrapper | `ScPressable` | `sc_pressable.dart` | Hover tint, focus-visible, pressed, disabled; no splash |
| Focus ring | `ScFocusRing` | `sc_focus_ring.dart` | 2px surface gap + 2px accent ring; theme-aware |
| Status chip | `ScStatusChip`, `ScStatus` | `sc_status_chip.dart`, `sc_status.dart` | Ready, analyzing with %, done, blocked, needs review; icon/dot plus word, never colour alone |
| Pipeline row | `ScPipelineRow` | `sc_pipeline_row.dart` | Number, name, state label, optional action; done check, running %, blocked name |
| Progress job | `ScProgressJob` | `sc_progress_job.dart` | Stage label, determinate bar, percentage, cancel; never bare indeterminate over 3s |
| Banner | `ScBanner` | `sc_banner.dart` | Persistent, danger-tinted border/background, action at right |
| Toast | `ScToastHost`, `ScToast` | `sc_toast.dart` | 4s, one line, semantic status; never the only recovery route |
| Library row / thumbnail / empty state / section label | `ScVideoRow`, `ScVideoThumb`, `ScEmptyState`, `ScSectionLabel` | `sc_library.dart` | 64×36 thumbnail, title ellipsis, meta, tabular score, selected ring + check, missing state |
| Scoreboard / winner buttons | `ScScoreboard`, `ScScoreSide`, `ScWinnerButtons` | `sc_scoreboard.dart` | L/R labels, 48–76px tabular, serving accent underline, last three rallies; 44px winner target |
| Score bug | `ScScoreBug` | `sc_score_bug.dart` | Fixed overlay bed/ink, top 20%, rally index, L/R, serving pill, timecode, 2px live dot |
| Transport | `ScTransport` | `sc_transport.dart` | Play/pause, ±5s, seek, tabular timecodes, disabled until ready; no volume |
| Timeline primitives | `ScRuler`, `ScRallySegment`, `ScScoreChip`, `ScPlayhead` | `sc_timeline.dart` | 22% rally tint, kept 32% / hover 42%, selected 2px outline, 20px hit, 1px accent playhead |
| Timeline dock | `TimelineDock` | `app/lib/src/features/workspace/presentation/studio/timeline_dock.dart` | 176px, 34px header, 112px gutter, 24/44/32 tracks, empty and missing states, click-to-seek |
| Clip row | `ScClipRow` | `sc_clip_row.dart` | In/out, duration, score context, keep/dismiss, kept ring, dismissed opacity but recoverable |
| Video stage | `ScVideoStage` | `sc_overlay.dart` | Overlay bed, aspect-fit via `PlaybackState.aspectRatio`, error slot, no fake video |
| Calibration overlay | `ScCalibrationOverlay`, `ScCourtHandle` | `sc_overlay.dart` | 24px visual / 44px hit, dashed net, one instruction, accent only while dragging |
| Missing recording | `ScMissingRecording` | `sc_overlay.dart` | Bed scrim, danger icon, heading, factual copy, Import action per D8 |
| Dialog / confirm | `ScDialog`, `ScConfirmDialog` | `sc_dialog.dart` | 420/520px, left-aligned, actions right-aligned, destructive action names the object |
| Segmented tabs | `ScSegmentedTabs` | `sc_segmented_tabs.dart` | 26px, pressed surface + elev-ring + filled icon |
| Switch | `ScSwitch` | `sc_switch.dart` | 34×19 or 36×20 track, focus ring, checked accent |
| Fields / checkbox / select | `ScTextField`, `ScCheckboxRow`, `ScSelect` | `sc_fields.dart` | 40px, focus ring, error border + icon + message, hint/helper |
| Search field | `ScSearchField` | `sc_search_field.dart` | 30px, ⌘K keycap, focus-within accent border + ring, clear action |
| Panel / rail header / section header / divider | `ScPanel`, `ScRailHeader`, `ScSectionHeader`, `ScDivider` | `sc_panel.dart` | Uppercase mono micro-label, trailing count, hairline |
| Icons | `ScIcons` | `sc_icons.dart` | `Icons.*_rounded`; 20px controls, 24px toolbar; outlined default, filled selected |

### 4.2 New and changed file tree

```text
app/lib/src/app/
  app.dart                         # themeMode: ThemeMode.system
  router.dart                      # add /studio route; keep legacy routes
  theme.dart                       # register palette, tokens, typography; focus ring; targets
  design/
    sportcut_tokens.dart           # SportcutPalette extension + SportcutTokens
    sc_metrics.dart                # layout constants
    sc_typography.dart             # SportcutTypography extension
    sc_elevation.dart              # flat / ring / raised / focus
    sc_tints.dart                  # derived tints and scrims
    sc_status.dart                 # ScStatus enum
    sc_icons.dart                  # Icons.*_rounded map
    sc_overlay_colors.dart         # fixed footage colours
    components/
      sc_pressable.dart
      sc_focus_ring.dart
      sc_actions.dart
      sc_status_chip.dart
      sc_pipeline_row.dart
      sc_progress_job.dart
      sc_banner.dart
      sc_toast.dart
      sc_library.dart
      sc_scoreboard.dart
      sc_score_bug.dart
      sc_transport.dart
      sc_timeline.dart
      sc_clip_row.dart
      sc_overlay.dart
      sc_dialog.dart
      sc_segmented_tabs.dart
      sc_switch.dart
      sc_fields.dart
      sc_search_field.dart
      sc_panel.dart

app/lib/src/features/workspace/presentation/studio/
  studio_shell.dart                # window rows and regions
  studio_controller.dart           # ephemeral StudioState + StudioController
  studio_toolbar.dart              # wordmark, breadcrumb, search, toggles, Export
  stage_strip.dart                 # 40px pipeline navigation (D2)
  studio_workspace.dart            # rails, gutters, responsive collapse, focus mode
  video_rail.dart                  # library head, rows, import footer
  preview_pane.dart                # header, stage, score bug, transport, overlays
  inspector_pane.dart              # Rally/Clip tabs and stage-aware panels
  timeline_dock.dart               # 176px dock
  studio_status_bar.dart
  studio_shortcuts.dart
  export_sheet.dart

app/lib/src/features/library/presentation/
  playback_host.dart               # shared load/dispose lifecycle
  player_view.dart                 # preview stage + transport

app/lib/src/features/score/presentation/
  score_session.dart               # ensures editing + rally review sessions
  rally_scoreboard_panel.dart
  rally_mark_controls.dart
  last_rallies_panel.dart
  rally_suggestions_panel.dart

app/lib/src/features/highlights/presentation/
  clip_inspector_panel.dart
  reel_panel.dart

app/lib/src/features/calibration/presentation/
  court_calibration_overlay.dart
  calibration_panel.dart

app/lib/src/features/analysis/presentation/
  analysis_panel.dart
  artifact_rows.dart

app/lib/src/features/tracking/presentation/
  tracking_overlay.dart
  tracking_panel.dart

app/lib/src/features/export/presentation/
  export_form.dart
  export_progress.dart
  export_success.dart
  export_summary.dart
```

`workspace_studio_screen.dart` shrinks to a composition root under roughly 150 lines that resolves the workspace and renders `StudioShell`.

### 4.3 Shared helpers

`ScStatus`, `ScTints`, `ScElevation`, `ScFocusRing`, `ScOverlayColors`, `ScIcons`, and `ScMetrics` are the shared vocabulary. Components take tokens only, are data-in/callback-out, and own no providers. The shell and feature panels own provider access.

---

## 5. Phased steps

Every PR branches from `main`, keeps `cd app && flutter analyze` at zero issues, and is one coherent surface. Do not add tests. Manual visual checks use `tools/run-macos.sh` at 1100×720 and 1440×900. If Flutter is not on `PATH`, use `$SPORTCUT_FLUTTER_BIN/flutter analyze`.

### Phase 0 — Contract lock (PR 0)

**Scope.** Freeze D1–D14 before touching Dart; resolve the two open BRD questions; record the licensing row for built-in icons.

**Files.**

- `docs/adr/0003-studio-shell-refactor.md` (new)
- `docs/brd/09-studio-shell-jobs-and-settings.md` (timeline dock in scope; Export primary; stage strip and inspector model; new FRs for dock, score bug, stage strip, export sheet)
- `docs/brd/00-product-context.md` (§11.2 row for Material Icons)

**Acceptance.**

- ADR records every decision, including the stage-strip deviation and the missing-recording limitation.
- BRD 09 §2.2 no longer excludes the shared timeline dock; Q-SHL-01 and Q-SHL-02 are resolved and traceable.
- Material Icons row is recorded as Apache-2.0, shippable, bundled with Flutter, no new asset.
- No Dart change.

**Verification.** `git diff --check`; human review of the ADR and BRD.

**Risk.** Decision churn. Mitigation: lock the decisions in one PR and do not reopen them during implementation.

### Phase 1 — Token and theme foundation (PR 1)

**Scope.** Give every design-system value a named Dart home; make focus and state treatments real; prepare the shell geometry.

**Files.**

- `app/lib/src/app/design/sportcut_tokens.dart`
- `app/lib/src/app/design/sc_metrics.dart` (new)
- `app/lib/src/app/design/sc_typography.dart` (new)
- `app/lib/src/app/design/sc_elevation.dart` (new)
- `app/lib/src/app/design/sc_tints.dart` (new)
- `app/lib/src/app/design/sc_status.dart` (new)
- `app/lib/src/app/design/sc_icons.dart` (new)
- `app/lib/src/app/design/sc_overlay_colors.dart` (new)
- `app/lib/src/app/theme.dart`
- `app/lib/src/app/app.dart`
- `app/lib/src/features/library/presentation/formatters.dart` (add `formatClock` for `HH:MM:SS` and `formatRallyTime`; keep `formatDuration` for compact metadata)

**Steps.**

1. Make `SportcutPalette` a `ThemeExtension` with `copyWith`, `lerp`, and `of(context)`; register it.
2. Remove duplicated `success`/`warn` from `SportcutTokens`; components read the palette.
3. Move all fixed layout constants into `ScMetrics`; keep spacing, radii, motion, and overlay values in `SportcutTokens`.
4. Add `SportcutTypography` with the full scale and tabular helpers; map `TextTheme` from it.
5. Add `ScElevation`, `ScTints`, `ScStatus`, `ScIcons`, and `ScOverlayColors`.
6. In `theme.dart`: register extensions; replace `focusColor` with a `WidgetStateProperty` focus ring; raise icon buttons to 36×36 and buttons to 40px; set `materialTapTargetSize: padded`; add switch, segmented, banner, dialog, and progress themes.
7. In `app.dart`, set `themeMode: ThemeMode.system` explicitly.
8. Update the nine `SportcutTokens.of` call sites in `workspace_studio_screen.dart` to the moved members.

**Acceptance.**

- Every row of §2 exists in code; no raw hex outside the design layer.
- Both themes render; focus rings are visible in both.
- The current studio looks unchanged except focus rings and target sizes.
- No new dependency.

**Verification.** `cd app && flutter analyze`; manual light/dark smoke test.

**Risk.** Moving geometry breaks the studio file; update call sites in the same PR. Palette `lerp` must return correct values or theme transitions flicker.

### Phase 2 — Component library (PRs 2a–2e)

Adds public widgets only; no existing screen changes. `flutter analyze` stays clean because public unused classes are allowed. Do not commit a component gallery route.

#### PR 2a — Primitives

**Scope.** `ScPressable`, `ScFocusRing`, `ScButton`, `ScIconButton`, `ScToolbarButton`, `ScKeycap`, `ScStatusChip`, `ScPipelineRow`, `ScSegmentedTabs`, `ScSwitch`, `ScPanel`, `ScRailHeader`, `ScSectionHeader`, `ScDivider`.

**Files.** `sc_pressable.dart`, `sc_focus_ring.dart`, `sc_actions.dart`, `sc_status_chip.dart`, `sc_pipeline_row.dart`, `sc_segmented_tabs.dart`, `sc_switch.dart`, `sc_panel.dart`.

**Acceptance.** Every state in §4.1 exists; 36px icon targets; focus ring visible in both themes; icon-only controls have tooltip and semantic label.

**Risk.** Over-generalising props. Keep widgets data-in/callback-out.

#### PR 2b — Feedback, fields, dialogs

**Scope.** `ScProgressJob`, `ScBanner`, `ScToastHost`/`ScToast`, `ScDialog`/`ScConfirmDialog`, `ScTextField`, `ScCheckboxRow`, `ScSelect`, `ScSearchField`, `ScEmptyState`.

**Files.** `sc_progress_job.dart`, `sc_banner.dart`, `sc_toast.dart`, `sc_dialog.dart`, `sc_fields.dart`, `sc_search_field.dart`, `sc_library.dart` (empty state only).

**Acceptance.** Determinate progress always labelled; toast 4s and dismissible; dialogs 420/520 with object-named destructive action; fields 40px with focus ring and error treatment.

**Risk.** Banner versus toast semantics. A toast never holds the only recovery path.

#### PR 2c — Rows and library

**Scope.** `ScVideoThumb`, `ScVideoRow`, `ScClipRow`, `ScRallyRow` (or a shared row shell), `ScSectionLabel`.

**Files.** `sc_library.dart`, `sc_clip_row.dart`.

**Acceptance.** Selected row is surface-warm + 1px ring + check; score and timecode are tabular; missing row shows an alert icon and the words "Recording missing"; thumbnail is a custom court painter, not a fake screenshot.

**Risk.** Row density at 1100px. Keep 56/64px minimum heights and ellipsize one-line titles.

#### PR 2d — Studio media components

**Scope.** `ScVideoStage`, `ScScoreboard`, `ScScoreSide`, `ScWinnerButtons`, `ScScoreBug`, `ScTransport`.

**Files.** `sc_overlay.dart`, `sc_scoreboard.dart`, `sc_score_bug.dart`, `sc_transport.dart`.

**Acceptance.** Stage uses `overlayBed`, not `Colors.black`; score bug sits in the top 20%; transport has ±5s, play/pause, seek, tabular timecodes; winner buttons are 44px; no volume control.

**Risk.** Overlay legibility on bright footage. Use the fixed bed and scrim; never sample the frame.

#### PR 2e — Overlay and timeline primitives

**Scope.** `ScCalibrationOverlay`, `ScCourtHandle`, `ScMissingRecording`, `ScRuler`, `ScRallySegment`, `ScScoreChip`, `ScPlayhead`.

**Files.** `sc_overlay.dart`, `sc_timeline.dart`.

**Acceptance.** Handles are 24px visual / 44px hit; accent only while dragging; segments have a 20px hit target and 14px minimum width; playhead is 1px accent.

**Risk.** Coordinate math. Keep all overlay coordinates in the same aspect-fit box.

### Phase 3 — Studio shell (PRs 3a–3d)

#### PR 3a — Behaviour-preserving decomposition

**Scope.** Split `workspace_studio_screen.dart` into `studio_shell.dart`, `studio_toolbar.dart`, `video_rail.dart`, `preview_pane.dart`, `inspector_pane.dart`, and `studio_status_bar.dart`. Keep the current markup and private widgets initially. No functional change.

**Files.** New files under `app/lib/src/features/workspace/presentation/studio/`; `workspace_studio_screen.dart` becomes a composition root.

**Acceptance.** The studio behaves identically; the same providers, stage switching, delete dialogs, and analysis listeners are used; `workspace_studio_screen.dart` is under roughly 150 lines.

**Risk.** Highest-risk move. Keep it pure: no restyle, no provider changes, no renaming of behaviour.

#### PR 3b — Visible studio frame

**Scope.** macOS full-size content view; 52px toolbar contents; 264px library with workspace head and Import footer; 12px gutters; 320px inspector shell; 40px stage strip; 176px dock placeholder; 30px status bar; explicit 480px preview floor; 1200/1040 narrowing.

**Files.** `studio_shell.dart`, `studio_toolbar.dart`, `stage_strip.dart`, `studio_workspace.dart`, `video_rail.dart`, `inspector_pane.dart`, `studio_status_bar.dart`, `studio_metrics.dart`; `app/macos/Runner/MainFlutterWindow.swift`.

**Acceptance.** One chrome band; traffic lights sit over the Flutter toolbar without collision; toolbar has exactly one primary action (Export) and no Import; stage strip renders the pipeline order with state labels; library rows use the new row component; 12px gutters; preview ≥480px; rails narrow at 1200/1040; existing feature views remain reachable through the center.

**Verification.** `cd app && flutter analyze`; `tools/run-macos.sh` at 1100×720 and 1440×900; light/dark.

**Risk.** Traffic-light geometry varies by macOS version; tune the leading inset. Toolbar density at 1100px; hide the breadcrumb before the search.

#### PR 3c — Ephemeral state and interactions

**Scope.** Add `StudioController`/`StudioState`; library search with ⌘K and Esc; rail toggles; focus mode F/Esc; keyboard map; toast host; Esc precedence; text-field suppression.

**Files.** `studio_controller.dart`, `studio_shortcuts.dart`, `studio_toolbar.dart`, `video_rail.dart`, `studio_shell.dart`.

**Acceptance.** Search filters in memory with no engine call and a search-empty state; every shortcut in §3.4 works; Esc order is export sheet → focus mode → clear search; typing L/R/Space in a field does nothing.

**Risk.** Focus handling on macOS. Test with search focused, a dialog open, and a button focused.

#### PR 3d — Responsive and focus-mode polish

**Scope.** Full rail collapse below 980px; focus mode hides rails and keeps preview, stage strip, dock, transport, and Export; rail toggle pressed states; status bar vocabulary.

**Files.** `studio_workspace.dart`, `studio_shell.dart`, `studio_status_bar.dart`, `studio_controller.dart`.

**Acceptance.** At 979px the studio stacks preview → videos → inspector with no horizontal scroll; focus mode restores the previous rail state on Esc; status bar uses `READY`/`ANALYZING %`/`DONE`/`BLOCKED`/`NEEDS REVIEW` vocabulary.

**Risk.** The 980px path is unreachable at the macOS minimum; verify with a test harness or a temporary debug width.

### Phase 4 — Preview, score bug, transport, overlays (PRs 4a–4c)

#### PR 4a — Stage, transport, shared playback host

**Scope.** `ScVideoStage` and `ScTransport` into `PreviewPane`; `PlayerView` becomes a thin composition; add `PlaybackHost` to own load/dispose.

**Files.** `preview_pane.dart`, `player_view.dart`, `playback_host.dart`, `sc_overlay.dart`, `sc_transport.dart`.

**Acceptance.** Playback, seeking, and errors behave as before; ±5s works; timecodes are tabular; controls never overlap the score bug; transport hides when the recording is missing; one controller per selected video.

**Risk.** `aspectRatio` edge cases; fall back to 16:9 when unknown.

#### PR 4b — Score bug, missing state, session ownership

**Scope.** Render `ScScoreBug` from `MatchEdit`; derive rally index/total, score at time, serving side, and timecode; add `ScMissingRecording`; shell calls `editingControllerProvider.ensureOpen(match)` once per selected video.

**Files.** `preview_pane.dart`, `sc_score_bug.dart`, `sc_overlay.dart`, `editing_providers.dart`, `formatters.dart`.

**Acceptance.** Bug stays in the top 20%; shows `Rally N/M`, L/R, serving, score, and `HH:MM:SS`; score never animates; missing recording shows an honest state and disables scoring and transport; no per-view `open()` reload in studio paths.

**Risk.** Duplicate editing-session opens. Add `ensureOpen` and remove the studio-path calls from `ScoreView`, `HighlightsView`, and `ExportView`; keep the legacy route wrappers self-owned.

#### PR 4c — Calibration and tracking overlays

**Scope.** Move calibration onto the preview with `ScCalibrationOverlay`; move orientation/save/hint into `CalibrationPanel`. Move tracking boxes onto the stage; move quality/legend/gaps into `TrackingPanel`.

**Files.** `sc_overlay.dart`, `preview_pane.dart`, `court_calibration_overlay.dart`, `calibration_panel.dart`, `calibration_view.dart`, `tracking_overlay.dart`, `tracking_panel.dart`, `player_tracking_view.dart`, `inspector_pane.dart`.

**Acceptance.** Calibration still saves; tracking still loads its 5s windows; handles meet 24/44; no raw amber/lightBlue/orange outside a documented `TrackingSideColors` local palette; legend carries labels plus colour.

**Risk.** Normalised corner math after moving the stage. Keep coordinates tied to the same aspect-fit box.

### Phase 5 — Shared timeline dock (PRs 5a–5b)

#### PR 5a — Dock

**Scope.** 176px dock: 34px header, 112px gutter, 24/44/32 tracks, 10-minute window, ruler, rally segments, score chips, playhead, empty and missing states.

**Files.** `timeline_dock.dart`, `sc_timeline.dart`, `studio_shell.dart`, `studio_controller.dart`.

**Acceptance.** Dock measures 176px; five ruler labels; segments use 22% tint, kept 32%, selected 2px outline; playhead tracks playback; clicking the ruler or track seeks; no horizontal overflow at 1100px.

**Risk.** Segment positioning with dense rallies. Use `Stack`/`Positioned`, clamp minimum width, and recenter the window only on seek or selection, not every playback tick.

#### PR 5b — Dock wiring

**Scope.** Wire `MatchEdit` to the dock; selecting a segment selects the rally, switches the inspector to Clip, and seeks; window centers on the playhead and clamps to 60–600s.

**Files.** `timeline_dock.dart`, `studio_controller.dart`, `inspector_pane.dart`.

**Acceptance.** Dock reflects rallies and scores; no rallies shows `No rallies in this window.`; missing recording shows `No recording. Locate the file to restore the timeline.` and disables seek.

**Risk.** Window jitter and selection drift. Keep one derived selector for the visible window.

### Phase 6 — Inspector Rally/Clip (PRs 6a–6b)

#### PR 6a — Rally inspector

**Scope.** `ScSegmentedTabs` `Rally | Clip`; scoreboard at 52px; serving line; L/R winner buttons; last three rallies; suggestion accept/adjust/dismiss; empty copy.

**Files.** `inspector_pane.dart`, `rally_scoreboard_panel.dart`, `rally_mark_controls.dart`, `last_rallies_panel.dart`, `rally_suggestions_panel.dart`, `score_session.dart`, `score_view.dart`.

**Acceptance.** L/R updates score, serving side, and timeline; focus returns to the same button after re-render; suggestions never auto-apply; one accent signal per pane (serving underline); no red for a lost rally.

**Risk.** `ScoreView` is 788 lines. Extract mechanically before styling; keep one editing session.

#### PR 6b — Clip inspector and reel footer

**Scope.** Clip heading, duration, in/out, winner, score after, type, tags, `ScSwitch` keep, help copy, trim dialog, reel summary footer and mini Export.

**Files.** `inspector_pane.dart`, `clip_inspector_panel.dart`, `reel_panel.dart`, `highlights_view.dart`, `sc_clip_row.dart`, `sc_switch.dart`, `sc_dialog.dart`.

**Acceptance.** Keep/dismiss updates reel count and export readiness; dismissed clips remain recoverable; trim works through `ScDialog`; one keep switch.

**Risk.** Moving `HighlightsView` actions while preserving reorder and trim behaviour.

### Phase 7 — Remaining feature panels and export (PRs 7a–7c)

#### PR 7a — Analysis panel

**Scope.** Prepare/rebuild/cancel, `ScProgressJob`, artifact rows using `ScPipelineRow`/`ScStatusChip` instead of `DataTable`, busy-elsewhere copy.

**Files.** `analysis_panel.dart`, `artifact_rows.dart`, `analysis_view.dart`, `inspector_pane.dart`.

**Acceptance.** Progress always has a stage label; artifacts show kind/path/state/size; no `DataTable`; preview stays mounted.

**Risk.** Background job state is app-wide; do not duplicate it.

#### PR 7b — Export sheet

**Scope.** Modal `ExportSheet` (440px) with form, progress, and success; summary strip; title card; music; lead-in/out; Include score overlays (ephemeral); Remove rest periods checked and disabled with helper; zero-clip and missing-recording blocks; cancel; success with real file name, clip count, runtime, and existing share action.

**Files.** `export_sheet.dart`, `export_form.dart`, `export_progress.dart`, `export_success.dart`, `export_summary.dart`, `export_view.dart`, `export_providers.dart`, `studio_shell.dart`, `studio_toolbar.dart`.

**Acceptance.** Export is the single toolbar primary action; sheet is 440px; zero clips blocks with `Keep at least one clip before exporting.`; missing recording blocks with `Locate the recording first.`; progress is determinate and cancellable; success shows the engine-produced file name; no persisted filename or new durable setting.

**Risk.** `ExportController.render` signature changes for the score-overlay toggle. Keep the default `true`; when false, write clips with `overlayPath: null`. Cancel must not present cancelled output as final.

#### PR 7c — Remove legacy center takeover

**Scope.** Every stage uses `PreviewPane` plus the inspector; `*_view.dart` compose the same panels for legacy routes; adopt `PlaybackHost` in the four wrappers; delete dead widget classes.

**Files.** `workspace_studio_screen.dart`, `studio_shell.dart`, `player_screen.dart`, `calibration_screen.dart`, `score_screen.dart`, `player_tracking_screen.dart`, `player_view.dart`, `calibration_view.dart`, `score_view.dart`, `highlights_view.dart`, `export_view.dart`, `analysis_view.dart`, `player_tracking_view.dart`.

**Acceptance.** Every pipeline stage is usable without a full-screen takeover; preview stays mounted and keeps playback state; legacy routes still compile; no duplicated playback lifecycle.

**Risk.** Route wrappers and tests. Keep public class names and constructors stable; touch tests only for compile breaks.

### Phase 8 — Home, routing, accessibility, cleanup (PRs 8a–8c)

#### PR 8a — Studio home and route

**Scope.** Restyle `WorkspaceScreen` in the studio family: 52px toolbar, `ScPanel`/`ScVideoRow`/`ScEmptyState`/`ScConfirmDialog`; add `/studio` with `StudioRouteArgs(workspace)`; keep legacy route constants.

**Files.** `workspace_screen.dart`, `router.dart`, `workspace_studio_screen.dart`.

**Acceptance.** Home has no Material `Card`/`ListTile` defaults; empty and error copy names the next action; selecting a workspace opens `/studio`; legacy routes compile.

**Risk.** `app_shell_test.dart` is already stale; do not treat it as a safety net.

#### PR 8b — Accessibility, motion, scaling

**Scope.** Focus traversal; semantic labels for every icon-only control; 44px overlay hits; 200% text scaling with minimum heights; reduced motion; contrast audit in both themes; readable semantics for score bug, scrubber, and transport.

**Files.** All components and studio files; `theme.dart`.

**Acceptance.** USAGE.md checklist passes in both themes; nothing clips at 200% text; `MediaQuery.disableAnimations` collapses non-essential transitions; score, scrubber, and frame never animate.

**Risk.** Dense 52/30/176 chrome is the hardest place for 200% scaling. Prefer minimum heights and shorter labels over shrinking below the type floor.

#### PR 8c — Cleanup and documentation

**Scope.** Delete `app/lib/src/app/placeholder_screen.dart` if unreferenced; delete dead private widgets; grep gates for raw colours and spacing; update BRD 09 §2.3 and §7; final manual matrix.

**Files.** `placeholder_screen.dart`, studio and feature files, `docs/brd/09-studio-shell-jobs-and-settings.md`.

**Acceptance.** No `Color(0x` outside the design layer; no `Colors.black` video bed; no raw padding literals in the studio folder; `flutter analyze` clean; `tools/check-no-rust-in-app.sh` passes; BRD reflects the delivered shell.

**Risk.** Test compile breakage from route or constructor changes. Keep public surfaces stable.

### Sequencing

```text
PR0 contract
 └─ PR1 foundation
     ├─ PR2a primitives → PR2b feedback/fields → PR2c rows/library → PR2d media → PR2e overlay/timeline
     └─ PR3a decomposition → PR3b shell frame → PR3c interactions → PR3d responsive/focus
                                                        │
                          PR4a stage/transport ─────────┤
                          PR4b score bug/missing ───────┤
                          PR4c calibration/tracking ────┤
                          PR5a dock ────────────────────┤
                          PR5b dock wiring ─────────────┤
                          PR6a rally inspector ─────────┤
                          PR6b clip inspector ──────────┤
                          PR7a analysis panel ──────────┤
                          PR7b export sheet ────────────┤
                          PR7c legacy cleanup ──────────┘
                                        │
                                PR8a home/route
                                        │
                                PR8b a11y/scaling
                                        │
                                PR8c cleanup/docs
```

Recommended linear order for one implementer: 0 → 1 → 2a → 2b → 2c → 2d → 2e → 3a → 3b → 3c → 3d → 4a → 4b → 4c → 5a → 5b → 6a → 6b → 7a → 7b → 7c → 8a → 8b → 8c.

### Per-PR definition of done

- `cd app && flutter analyze` reports no issues.
- The diff is one coherent surface; no unrelated formatting churn.
- No new dependency; if one is unavoidable, add a licensing-register row first.
- No raw hex, spacing, radius, or font size in feature/widget code outside the design layer.
- No engine access outside `app/lib/src/bridge/sportcut_engine.dart`; no network; no FFI.
- No new durable client state; shell state is in-memory Riverpod.
- Both light and dark themes checked; missing and empty states checked.
- The product is still semi-automatic: every scoring action is a user confirmation; no automatic-officiating copy.
- Existing tests are touched only when a change stops them compiling; no new tests.

### Top risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Decomposing the 1,417-line studio file breaks subtle behaviour | High | High | PR 3a is a pure move with no restyle; verify before/after manually; land it before component swaps. |
| `editingControllerProvider` opens twice or loses the session | Medium | High | Shell owns one session; add `ensureOpen`; remove per-view `open()` in studio paths. |
| Timeline dock conflicts with BRD 09 §2.2 | High | Medium | Resolve Q-SHL-01 in PR 0 and amend the BRD before building the dock. |
| Stage-strip decision churns the layout | Medium | High | Lock D2 in PR 0; keep `ScMetrics.stageStripHeight` so the strip can be removed cleanly. |
| macOS full-size content view regresses window behaviour | Medium | Medium | Isolated PR; manual resize, zoom, full-screen, and focus-mode matrix; fall back to native chrome. |
| Overlay coordinate math breaks after moving the stage | Medium | High | Keep normalised coordinates tied to the same aspect-fit box; verify calibration and tracking on a real recording. |
| Focus and keyboard handling on macOS | Medium | Medium | Centralize in `studio_shortcuts.dart`; test search focus, dialog open, and field focus; define Esc precedence. |
| Missing-recording Locate has no backend | High | Low | Implement the honest state only; document the limitation and keep Import as the recovery path. |
| 200% text scaling clips dense chrome | Medium | Medium | Use minimum heights; test `MediaQuery.textScaler` at 2.0 in PR 8b. |
| Token drift from `tokens.css` | Medium | Medium | Document provenance; keep all new values in the design layer; consider a future token-check script. |

---

## 6. Licensing items

| Item | Status | Action |
| --- | --- | --- |
| Archivo | Already bundled under `app/assets/fonts/Archivo-Variable.ttf`; OFL-1.1; register row in `docs/brd/00-product-context.md` §11.2 | No action. |
| IBM Plex Sans | Already bundled; OFL-1.1; register row exists | No action. |
| IBM Plex Mono | Already bundled (400/500); OFL-1.1; register row exists | No action. |
| Material Icons (Flutter built-in icon font) | Ships with the Flutter SDK; Apache-2.0; no asset added | Add an explicit row in §11.2 before Phase 2: "Material Icons (Flutter SDK built-in icon font) — studio, toolbar, and transport icons via `Icons.*_rounded` — Apache-2.0; shippable; no new asset." |
| Material Symbols Rounded | Not used. `studio.html` loads it from Google Fonts, which violates the offline guardrail | Do not port. If exact glyphs become mandatory, bundle the font as a local asset and add a licensing row in a separate change. |
| Google Fonts / `google_fonts` package | Not used | Do not add; it is a network dependency. |
| Custom court and thumbnail painters | Project code | No third-party asset; no row. If a third-party SVG or icon set is introduced later, add a row first. |
| Flutter packages | Existing Riverpod, file_picker, video_player, share_plus, path_provider, sqflite | No new packages; no new rows. |

---

## 7. Open questions for the user

1. **Stage navigation (D2):** is the 40px `StageStrip` acceptable as an app-specific extension, or should pipeline navigation become a third inspector tab (`Pipeline | Rally | Clip`)? The strip is recommended because it keeps the inspector pure and gives `ScPipelineRow` a home.
2. **Timeline dock (D3):** confirm the 176px shared dock enters v1 scope and BRD 09 §2.2 is amended.
3. **Export filename:** `ExportRequestDto` has no filename field. Confirm that the sheet uses the title card plus the engine-produced file name on success, rather than adding a protocol field.
4. **Score overlays:** implement the "Include score overlays" checkbox as an ephemeral sheet option, or show it checked and disabled with an explanatory helper?
5. **Missing recording (D8):** is a real relocate path planned? Until it exists, the state will say the file is no longer at its original path and offer Import as the recovery action, which creates a new match.
6. **Volume and drag-to-trim (D12):** confirm both are deferred; volume needs a `PlaybackController` API change, and trim needs a repository method to update a rally span.
7. **Icons (D7):** built-in rounded Material Icons are the default. Is exact Material Symbols Rounded fidelity required? If so, approve the bundled asset and licensing row.
8. **Home screen:** the design system has no workspace-list reference. Confirm the home may be restyled in the studio family without a separate design file.
9. **Theme:** confirm `ThemeMode.system` remains the only appearance control, with no in-app switch.
10. **Legacy routes:** keep the `*_screen.dart` route wrappers after `/studio` lands, or schedule a separate routing cleanup once the studio is the only path?

---

## 8. Completeness review — corrections to fold in before PR 0

**Design-system components, screens, and states not covered**
- `design-system/index.html` screens 11 "Review & score" (line 4633) and 12 "Export settings + summary" (line 4776), and `DESIGN.md` §5's two-column review/export compositions, are replaced by a 320px inspector and a 440px sheet. D1 picks `studio.html` but never records that these DS compositions are superseded; add that to ADR 0003 or implement them.
- The inspector control is a `role="tablist"` (`.inspector-tabs`), not the DS `.segmented` filter control. `ScSegmentedTabs` conflates them, while `index.html`/`USAGE.md` say segmented controls filter and do not navigate. Add `ScTabs` for the inspector and keep `ScSegmentedControl` separate.
- Missing shared components: toolbar court-mark/brand mark, `ScTag`/tag row, `ScMetaList`, `ScServingLine`, `ScPreviewHeader`, `ScReelSummary`, `ScInspectorEmptyState` ("No clip selected" / "Choose a rally on the timeline"), track labels, and the rally/rest/playhead legend.
- Missing states: inspector empty/no-clip, "No rallies yet", ranking-unavailable labelled state (BRD 07 FR-HLT-09), export filename validation ("Name the file before exporting."), "Add a rally counter" from the index export dialog, and export audio/overlay summary states.
- Typography and radius gaps: `studio.html` uses 11px, 13px, and 17px text and 4/5/7/8/9px radii; the planned scale only covers 9/10/12/14/16/18/20/24/32/44/64 and 6/10/14/pill. Either extend `SportcutTypography`/`ScMetrics` or the "no raw size/radius" rule is unsatisfiable.
- Geometry drift from `studio.html`: the prototype uses ~43px video rows, 52px-wide thumbnails, 1px column borders (no 12px gutter), 34px fields, 20/18px chips, and 18px toolbar icons. `ScMetrics` plans 56/64px rows, 64×36 thumbnails, a 12px gutter, 40px fields, 24px chips, and 24px toolbar icons. Decide whether DESIGN.md or `studio.html` wins and record the visible deltas.
- Overlay conflicts: the plan uses `#0A0F0C` for the stage bed while `studio.html` uses `--stage: #050806`; the plan puts the score bug in the top 20% with a 2px live dot, while `studio.html` spreads it across the frame with a 6px dot. The plan also gives unkept rally segments a 22% tint, while `studio.html` renders them as `surface`.
- Responsive coverage omits `studio.html`'s 560px and 400px rules (transport compression, icon-only Export, hidden status items). The 980px collapse comes from DESIGN.md, not `studio.html`; state that provenance.
- Surface mixes used by the prototype have no token: toolbar `surface 94% + bg`, sidebar `96% + bg`, rallies track `surface-warm transparent 35%`.
- `ScPipelineRow` is described as a vertical 24px-number pipeline row, but D2 says the 40px horizontal `StageStrip` "gives `ScPipelineRow` a home." Those are different components; add a `ScStageTab`/stage-strip component or drop the reuse claim.

**Existing app screens or flows not placed**
- Import progress: `_ImportProgress` and the `ImportState.picking/importing` states plus Cancel are absent from the shell plan; only the Import footer button is placed.
- Workspace/video loading and error states (`_StudioError`, provider `loading`, retry) are not placed.
- Delete video/workspace dialogs carry two checkbox options; `ScConfirmDialog` as specified (420px, one confirming action) cannot host them. Create-workspace dialog is also unplaced. Define an option-bearing destructive dialog variant.
- `ScoreView` flows not placed by PR6a: manual Mark start/Mark end/Cancel, per-rally keep/remove, and the dismissible failure banner. The file tree mentions `rally_mark_controls.dart`, but the scope/acceptance do not.
- `HighlightsView` flows not placed by PR6b: `ReorderableListView` reorder (BRD 07 FR-HLT-18), the left-out rail, suggested rank/`#n`, Keep top 10, ranking-failure label, and the `MaterialBanner` failure state. `highlightRankingProvider` is listed as reused but has no home without these.
- Export flows not placed: music gain control (BRD 08 FR-EXP-06), failed render keeping the previously rendered reel (FR-EXP-25), actual produced-file runtime (FR-EXP-13), audio and overlay summary lines (FR-EXP-10/11), and the distinct "unplayable recording" state from missing recording (FR-SHL-29).
- Analysis "Review player analysis" navigation, tracking readouts (coverage/gaps/current time), "Review rallies manually", and legacy route app-bar actions are not placed.
- Studio empty/error/loading/search states are named only generically; add concrete copy and retry/clear actions.

**Wrong file paths or claims that contradict the source**
- PR3b lists `studio_metrics.dart`, which does not exist in the plan's file tree; use `/Users/ductranhuu/workspaces/doitsu-technology/app-sport-cut/app/lib/src/app/design/sc_metrics.dart`.
- "18 test files" is wrong: there are 15 `*_test.dart` files, 19 files including `app/test/support`.
- `studio.html:1610` does not contain the kept tint; it is at lines 1664–1671. (The `DESIGN.md:153` rally-tint citation is correct.)
- "About 25 private widgets" is 22 private classes in `workspace_studio_screen.dart`.
- `ThemeData.focusColor` is a `Color`, not a `WidgetStateProperty`; the focus ring must be applied through component `ButtonStyle`/`WidgetStateProperty<BoxDecoration?>` or a wrapper, not by replacing `focusColor`.
- "Only the studio screen reads `SportcutTokens`" is true, but the plan then says the current studio looks unchanged after PR1; raising icon buttons to 36px, setting `materialTapTargetSize: padded`, and changing focus treatments will visibly change it. State expected diffs.
- `ScIcons` 24px toolbar icons conflict with `studio.html`'s 18px `.tool-btn` icons and 16px Export icon.
- PR5b's missing-state copy says "Locate the file to restore the timeline", but D8 deliberately has no Locate path. Change the copy or provide the action.
- PR3d's status-bar vocabulary (`READY`/`ANALYZING`/`DONE`/`BLOCKED`/`NEEDS REVIEW`) contradicts BRD 09 FR-SHL-14 and current code, where export readiness reads `Checking` / `Ready to export` / `Needs a clip`.
- `StageState` in `/Users/ductranhuu/workspaces/doitsu-technology/app-sport-cut/app/lib/src/features/workspace/domain/pipeline_stage.dart` only has `done/ready/idle`; `ScPipelineRow`/`ScStatusChip` acceptance requires blocked/running/needs-review. Define a derived mapping or extend the state model.

**Steps too big to review**
- PR3b bundles the macOS `fullSizeContentView` change with toolbar, library, gutters, inspector shell, stage strip, dock placeholder, status bar, preview floor, and responsive narrowing. It also contradicts §1.1's "dedicated PR for fullSizeContentView." Split it.
- PR6a extracts the 788-line `ScoreView` and adds five new panels plus `ScoreSession` in one PR.
- PR7c touches fourteen files, changes all route wrappers, and deletes dead widgets; split wrapper migration from deletion.
- PR8b is a whole-app accessibility, scaling, reduced-motion, contrast, and focus-traversal pass across every component and the theme; at minimum split the audit from mechanical fixes.
- PR2a introduces fourteen widgets in one PR; split primitives from structural components.

**CLAUDE.md constraint violations**
- None outright. The plan respects Riverpod-only state, the router table, the engine bridge, no FFI, no network, no new durable client state, and no new dependencies.
- The plan's own stricter raw-token DoD is not satisfiable as written: `theme.dart:8` has `sportcutSeedColor`, `app/lib/src/features/export/data/overlay_renderer.dart` uses `#101010`, `#FFFFFF`, and `0x8C000000`, and tracking/calibration use raw colours. PR8c's grep would fail unless these are migrated or explicitly exempted.

**Missing licensing rows**
- The Material Icons row is correctly included. The gap is IBM Plex Mono: `app/pubspec.yaml` bundles only 400 and 500, while the plan and `studio.html` use mono 600 for micro-labels. Either add `IBMPlexMono-SemiBold.ttf` and note the family row, or cap mono at 500; "no new font asset needed" contradicts §6's own "(400/500)".
- `overlay_renderer.dart` still burns off-token colours and the default typeface; BRD 08 FR-EXP-29/30 require `#0A0F0C`, `#F2F5F0`, Archivo, and L/R labels. No PR currently fixes this.

**Sequencing hazards**
- PR3b needs `StudioController` for selected stage, rail visibility, and search, but `StudioController` arrives in PR3c. Move minimal shell state into PR3b or reorder.
- PR4b introduces `ensureOpen(match)` while `ScoreView`, `HighlightsView`, and `ExportView` still call `open()` and remain the center until PR7c; the same widgets also serve legacy routes, so "remove studio-path calls" is not implementable without an ownership flag or session host.
- PR4a says `PlaybackHost` owns load/dispose, while §3.3 says the shell creates and disposes the controller. Name one owner.
- PR5b switches the inspector to Clip before PR6b builds the Clip panel; selecting a timeline segment would land on an absent panel.
- PR5a says recenter "only on seek or selection", PR5b says "window centers on the playhead", and `studio.html` recenters when the playhead leaves the window. Resolve the three.
- PR0 claims D1–D14 are locked but leaves ten open questions, and it does not schedule amendments for FR-SHL-08 (grouped pipeline rail), FR-SHL-22 (E selects Export stage), FR-SHL-14 (readiness copy), or BRD 08's summary FRs.
- PR6b cannot "reuse `highlightRankingProvider`" without a defined home for the left-out/reorder UI; sequence that panel with PR6b.
- PR7b changes `ExportController.render` while `ExportView` still exists; keep both call sites compiling or migrate `ExportView` in the same PR.
---

## 9. Delivered

The studio refactor landed through PR 8c. The shipped surface is the
three-pane studio with one shared preview, transport, score bug, 40 px stage
strip, 176 px timeline dock, stage-aware inspector, export sheet, and the
studio-family home screen.

- **Landed:** PR 0–3d (contract, tokens, primitives, decomposition, shell,
  interactions, responsive/focus), PR 4a–4c (stage and transport, score bug,
  court calibration and player-tracking overlays), PR 5a–5b (timeline dock and
  wiring), PR 6a–6b (Rally and Clip inspectors), PR 7a–7c (analysis and export
  panels, legacy takeover removal), PR 8a (home and `/studio` route), PR 8b
  (semantics, focus traversal, 200% scaling, reduced motion, contrast, hit
  targets), and PR 8c (dead-code and token cleanup, BRD status).
- **Deferred, unchanged by this delivery:** playback volume (FR-SHL-28,
  ADR-0003 D12) and drag-to-trim of rally boundaries (D12). Both need an API
  change outside the presentation layer.
- **Not automated:** the accessibility checklist is verified manually in both
  themes; there is no widget-level a11y test in the tree.
