## Context

The design system (`design/sportcut-design-system.html`) and eight mockups
(`design/screens/*.html`) are the written visual contract. They were read from
the source at v0.1.0, so the app's theme (seed `#157A4A`, `ColorScheme.fromSeed`,
both brightnesses), routing, and pipeline state model already conform. The
remaining gaps are component-level details discovered by reading each mockup
against its view.

Where the design-system prose and a mockup disagree, the mockup and shared CSS
(`_sportcut.css`) win — they are the concrete rendering. The one known conflict
is the studio's stage rail: the design-system §10 says "toolbar above the
centre", but the CSS (`.rail-stages { width:180px }`) and the mockup both show
the right rail, which is what the app already builds.

## Goals / Non-Goals

**Goals:**

- Every screen conforms to the mockup it maps to.
- The stage toolbar tells done from blocked by a glyph, not lightness alone.
- Score/duration/timecode numerals are tabular.
- The artifact list is a table with state chips.

**Non-Goals:**

- Redesigning any screen's structure or flow (the architecture already matches).
- The export form's ~720px column: the mockup explicitly flags this as an open
  issue and "flagged rather than fixed" — leave it out of scope.
- Motion, charting, or the burned-in export typography (out of the design
  system's own scope).

## Decisions

### 1. Done stages carry a check glyph

Each `done` stage in the feature rail gains a trailing `primary` check icon
(`.ok-mark` in the mockup). Blocked stays muted; a `ready` stage is styled in
the `primary` colour with a bold label (§9.1 "styled with the primary colour"),
and the selected stage sits on `secondaryContainer`. This is the single
highest-value edit.

### 2. Tabular numerals are a font feature, not a font

The design system is explicit that Sportcut ships no font asset. Numerals are
made tabular with `FontFeature.tabularFigures()` on the score, duration,
timecode, and clip texts, centralised in one helper style rather than repeated
per row. The mockups' monospace numerals are documentation typography and do not
carry into the app.

### 3. Artifact ledger becomes a table

`_ArtifactTile` (a `ListTile`) is replaced by a `DataTable` with columns Kind ·
Path · State · Size, and the state cell renders a chip: `ready` = primary chip,
`partial` = neutral chip, `missing` = warn chip. The design system §7 specifies
this table so the app does not invent a fourth list shape.

### 4. Winner button states

`_WinnerButton` becomes 44×36, radius 4, with a tabular/mono-styled label. The
picked side uses a 2px `primary` border plus a 10% `primary` tint; a suggested
side uses a dashed border and a `•` prefix. This replaces the current solid
border + bullet with the mockup's two distinct states.

### 5. Scoreboard serving highlight

The serving side's score numeral renders in `primary`; the non-serving side
stays `onSurface`. The tennis icon already sits on the serving side and keeps
its colour.

### 6. Legend colour-coding and coverage chips

The tracking legend tints the words "Blue"/"Orange" with the two track colours
at a darkened lightness that holds contrast on a light surface, per the mockup's
note that `#40C4FF`/`#FFAB40` fail 4.5:1 raw. A chip strip adds coverage, gap,
and timecode chips.

### 7. Hover-reveal and selected tint in the studio rail

The video rail's delete button appears on hover (opacity 0→1) and the selected
row uses `secondaryContainer` instead of the Material 3 default selected colour.

## Risks / Trade-offs

- **[Scope sprawl]** seventeen deltas across eight views could drift → the task
  list groups them by surface and each is independently verifiable.
- **[Colour literals]** adding the two darkened legend colours risks violating
  the "no literal colours" rule → they are the same track colours the painter
  already uses, documented as derived shades, not new palette entries.
- **[DataTable inside a scroll view]** the analysis view already scrolls a
  `ListView`; nesting a `DataTable` is fine because it is a leaf, but column
  widths must be fixed so it does not fight the scroll view.

## Open Questions

- Whether to centralise tabular numerals in `theme.dart` as a text theme, or add
  a small shared style helper. Default: a small helper constant used by the
  affected rows.
- Whether the "Projected net" chip and handle "armed" state (calibration) are
  worth the drag-interaction plumbing, or should be deferred. Default: implement
  both; they are small.
