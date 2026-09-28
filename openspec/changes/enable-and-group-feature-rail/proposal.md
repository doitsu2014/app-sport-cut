## Why

The studio's right rail presents features as a strict pipeline: every stage after
the current step is rendered "blocked" and cannot be opened — tapping one only
shows a "finish the earlier steps first" snackbar. The rail therefore reads as a
mostly-disabled list and hides most of the app, and it gives no sense of which
features analyze the match versus which build the video. Now that prepare
analysis is a first-class rail item and the stage facts refresh after an action,
the menu can be made both complete and legible.

## What Changes

- **Split the right rail into two labelled sections.** *Analysis* holds the
  features that read the match — Mark court, Prepare analysis, Player analysis.
  *Studio* holds the features that produce the highlight — Review & score,
  Highlights, Export. Play stays pinned above both sections as the shared
  preview.
- **Enable every feature.** Drop the hard `blocked` gate: every feature row is
  selectable at any time. The rail keeps a trailing `done` check and a `next`
  highlight as guidance, but a feature is never disabled and never refuses to
  open.
- **Guide instead of block.** When a feature is opened before its prerequisites
  exist, the feature view shows an inline explanation with a one-tap action to
  run the missing step (starting with Player analysis offering "Prepare
  analysis"), replacing the current raw engine error.
- **Retire the duplicate entry point.** The app-bar "Prepare analysis" shortcut
  is removed; the sectioned rail is the single way to reach the feature. The
  app-bar import (`+`) and delete actions stay.
- **Simplify the rail's emphasis.** Only the selected feature is emphasised
  (secondary-container tint, bold). Drop the trailing done check glyph and the
  persistent primary-bold "next" cue; a done stage stays a plain muted row.

## Capabilities

### New Capabilities
<!-- None: this changes the behaviour of capabilities already introduced by
     add-workspace and add-workspace-studio, both of which are not yet archived. -->

### Modified Capabilities
- `workspace-studio`: the right rail is a grouped, always-enabled feature menu —
  only the selected feature is emphasised, and selecting any feature shows it.
- `workspace`: the per-video pipeline toolbar becomes a two-section feature menu
  in which every stage is present and selectable.
- `ui-design-system`: rail emphasis is selection-only — no done check glyph and
  no primary-colour next stage.

## Impact

- **Workspace presentation** (`app/lib/src/features/workspace/`): the feature
  rail gains section headers and loses its blocked/disabled styling; the stage
  model distinguishes done/next/idle rather than done/ready/blocked; stage
  selection always navigates.
- **Feature views** (`tracking`, `analysis`, `score`, `highlights`, `export`):
  each already degrades when its input is missing, but Player analysis needs an
  inline "prepare first" action instead of surfacing the engine's
  "analysis proxy is unavailable" error.
- **Engine**: none. No bridge, DTO, or Rust change.
