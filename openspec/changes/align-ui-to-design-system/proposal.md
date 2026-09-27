## Why

Sportcut has a written visual contract — the UI design system and its eight
screen mockups — but the shipped screens do not all obey it. The contract was
read from the source, so the architecture already matches; what is missing is a
set of component-level details: the stage toolbar tells done from blocked by
lightness alone (which the contract forbids), the serving side's score does not
turn green, the artifact list is rows instead of a table, and numerals are not
tabular. This change brings every screen into conformance.

## What Changes

- The workspace studio's stage rail marks done stages with a check glyph, uses
  `secondaryContainer` for the selected video row, and reveals the delete action
  on hover instead of showing it always.
- The score screen turns the serving side's score numeral `primary`, restyles
  winner buttons (44×36, mono, radius 4; picked = primary border + tint,
  suggested = dashed border), renders rally numerals tabular, and colours the
  kept-in-reel star `primary`.
- The prepare-analysis screen presents artifacts as a table (kind, path, state,
  size) with ready/partial/missing state chips.
- The player-analysis screen colour-codes its legend and adds a coverage chip
  strip.
- Court calibration gains a "Projected net" stage chip and an armed drag state
  on handles.
- Highlights and export numerals become tabular; the reel-ready card gains a
  primary border and icon.
- Playback's missing-recording state keeps its disabled transport and copy.

## Capabilities

### New Capabilities
- `ui-design-system`: the cross-screen visual contract — theme-role discipline,
  stage-state rendering, tabular numerals, the artifact ledger table, and the
  score/tracking/calibration component states — so a screen that deviates from
  the design system is a testable defect rather than an opinion.

### Modified Capabilities
<!-- none: no existing capability's functional requirements change -->

## Impact

- **Views** (`app/lib/src/features/*/presentation/`): the concrete edits touch
  `_FeatureItem`/`_VideoRail` (workspace studio), `_Side`/`_WinnerButton`/
  `_RallyTile` (score), `_ArtifactTile` (analysis), `_PlayerTrackingView`
  (tracking), `_CornerHandle`/`CalibrationView` (calibration), `_ClipTile`/
  `_LeftOut` (highlights), `_Render` (export), and `_PlaybackProblem` (playback).
- **Theme** (`app/lib/src/app/theme.dart`): optionally centralise the tabular
  numeral style so score/duration/timecode share it.
- **Engine**: none. No bridge, DTO, or Rust change.
