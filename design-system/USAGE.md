# Sportcut Design System — Usage

Package guide for applying the system in Open Design artifacts and in the Sportcut Flutter client.

## Read order

1. `DESIGN.md` — intent, palette, type, layout, component behavior, voice, anti-patterns.
2. `tokens.css` — the only source of color, type, spacing, radius, elevation, and motion values.
3. `studio.html` — the macOS app prototype. Open this to review the product design: library, preview, inspector, timeline, and export.
4. `index.html` — the visual system reference: foundations, components, and static studio compositions. It links to the live prototype.

## Applying the tokens

Paste the `:root` block from `tokens.css` into the artifact's first `<style>` block, before any component CSS. Dark mode is the same token names under `:root[data-theme="dark"]`.

```html
<html data-theme="dark">        <!-- explicit dark -->
<html data-theme="light">       <!-- explicit light -->
<html>                          <!-- light by default -->
```

The reference page stores the choice in `localStorage` and otherwise follows `prefers-color-scheme`. In Flutter, use `ThemeMode.system` unless the user has chosen otherwise.

Rules:

- No raw hex outside `tokens.css` and the fixed footage overlay bed (`#0A0F0C` / `#F2F5F0`).
- No component-local color that duplicates a token. If a new semantic role is needed, add it here first and document it.
- Use `color-mix(in oklab, …)` for tints and scrims rather than new hex values.

## Studio prototype

`studio.html` is the app design layer: a floating macOS window with a library, preview, inspector, timeline, and export sheet. `index.html` links to it.

- **Works:** selecting a video, play/pause, seeking from the transport or the timeline, scoring L/R, keeping or dismissing the selected clip, searching the library, focus mode, toggling the rails, locating a missing recording, importing a local file, and the full export flow (validation, progress, success).
- **Appearance:** the window follows the system light/dark appearance. The preview stays dark because it is footage. There is no in-app theme switch, viewport selector, or demo panel.
- **State:** data is in memory. Reloading resets scores, clips, and imports. Import and Locate open the local file picker and simulate the result; no video is decoded or written.
- **Keyboard:** Space (play/pause), ←/→ (±5s), L/R (winner), F (focus), E (export), ⌘K (search), Esc (exit focus or close the sheet).
- **Responsive:** rails narrow at 1200/1040px, the command field leaves at 900px, and the window stacks below 860px. The page does not scroll horizontally.
- **Scope:** this page is the design source. The Flutter client now applies the palette, type scale, component themes, and studio chrome in `app/lib/src/app/theme.dart` and `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart`. The reference's global timeline dock still lives inside the Score and Highlights feature views in the client.

## Flutter mapping

The client now builds both themes from `SportcutPalette` and `SportcutTokens` in `app/lib/src/app/theme.dart`. The table is the contract used by that file; the code block below is a compact reference rather than the implementation.

| Token | Flutter target | Note |
| --- | --- | --- |
| `--bg` | `scaffoldBackgroundColor` | Cool chalk, not the default M3 surface tint |
| `--surface` | `ColorScheme.surface` | Panels, rails, dialogs |
| `--surface-warm` | `ColorScheme.surfaceContainer` | Recessed rails, input wells, tracks |
| `--fg` | `ColorScheme.onSurface` | Primary text |
| `--fg-2` | `ColorScheme.onSurfaceVariant` | Secondary text |
| `--muted` | `ColorScheme.onSurfaceVariant` with `SportcutTokens.muted` | Keep a separate token for metadata |
| `--border` | `ColorScheme.outlineVariant` | 1px dividers |
| `--accent` | `ColorScheme.primary` | Only for action and selection |
| `--accent-on` | `ColorScheme.onPrimary` | White on light, near-black on dark |
| `--danger` | `ColorScheme.error` | Errors only; a lost rally is not an error |
| `--success`, `--warn` | `ThemeExtension<SportcutTokens>` | Material has no semantic success/warn roles |
| `--space-*`, `--radius-*` | `ThemeExtension<SportcutTokens>` | Material has no spacing scale |
| `--text-*` | `TextTheme` | Map display sizes to `displaySmall`/`headlineMedium`; keep body at 16 |
| `--motion-fast` / `--motion-base` | `AnimationStyle` or local constants | 120ms / 180ms, ease-out |
| `--focus-ring` | `WidgetStateProperty` on buttons, inputs, rows | 2px gap + 2px accent, not a glow |

Sketch — a starting point, not a drop-in theme:

```dart
const courtGreen = Color(0xFF0E6E45);
const chalk = Color(0xFFF1F3EF);
const ink = Color(0xFF101713);

final light = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: chalk,
  colorScheme: ColorScheme.fromSeed(
    seedColor: courtGreen,
    brightness: Brightness.light,
  ).copyWith(
    primary: courtGreen,
    onPrimary: Colors.white,
    surface: const Color(0xFFFFFFFF),
    onSurface: ink,
    outline: const Color(0xFFC7D0C8),
    outlineVariant: const Color(0xFFDFE5DF),
    error: const Color(0xFFB42318),
  ),
);
```

Flutter specifics:

- Bundle Archivo, IBM Plex Sans, and IBM Plex Mono and declare them under `flutter: fonts:`; this package ships no font binaries.
- Set tabular figures on score and timecode styles: `fontFeatures: [FontFeature.tabularFigures()]`.
- Define a `SportcutTokens` `ThemeExtension` for spacing, radii, success, warn, and the fixed overlay colors so widgets do not hard-code values.
- Keep the three-pane widths (264 / 320, 52 chrome) as layout constants, not theme colors.
- Give the studio a minimum window of 1100 × 720 and collapse rails below 980px of available width.

## Status mapping

| App state | Visual | Label |
| --- | --- | --- |
| Ready | accent dot | `READY` |
| Running | warning dot + percentage | `ANALYZING 42%` |
| Done | success check | `DONE` |
| Blocked | danger icon | `BLOCKED` |
| Needs review | muted dot | `NEEDS REVIEW` |

## Accessibility checklist

- [ ] Body text reaches 4.5:1 on its surface; large text, icons, and score digits reach 3:1 — in light and dark separately.
- [ ] Scores carry L/R text labels; color never distinguishes the sides or the winner.
- [ ] Every interactive element has a visible focus state and an accessible name.
- [ ] Icon-only controls have a tooltip and `semanticLabel`.
- [ ] Overlay handles have at least a 44px hit target even when drawn at 24px.
- [ ] The score bug, scrubber, and transport expose readable semantics, not just visual bars.
- [ ] Layout survives 200% text scaling without clipping; avoid fixed heights around text.
- [ ] `prefers-reduced-motion` / `MediaQuery.disableAnimations` removes non-essential transitions.
- [ ] Toasts are not the only route to recovery; a persistent banner or inline error accompanies failures.
- [ ] Nothing important sits under macOS window chrome, the notch area, or platform overlays.

## Do

- Keep the video frame the brightest surface in the studio.
- Use one primary action per pane and verb-first labels.
- Use the 4px spacing scale and hairline rules instead of nested cards.
- Use tabular numerals for every score, duration, and timecode.
- State the object in destructive confirmations (“Delete workspace”, not “Delete”).
- Let empty states and errors name the next action.

## Avoid

- Avoid gradients, glows, glass panels, and celebratory animation.
- Avoid cream, beige, and warm-orange grounds; the neutral is cool chalk.
- Avoid a second accent-colored element in the same pane.
- Avoid red for a lost rally; reserve danger for failures.
- Avoid icon-per-heading and card-with-left-border callouts.
- Avoid invented metrics, filler copy, and fake screenshots.

## What is not included

- No exported screenshots or PDF. The reference is live HTML.
- The manifest is written for the Open Design design-system project format; importing it into the app's catalog is a separate step.

The Flutter client applies the tokens and studio chrome. The reference page still loads Archivo and IBM Plex from Google Fonts; the client bundles the same families under `app/assets/fonts` so product paths stay offline.