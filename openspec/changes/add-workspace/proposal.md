## Why

Every Sportcut feature already exists, but the home screen hides them behind a
per-match "⋮" popup menu as an unordered verb list. The pipeline is real — import,
calibrate, analyze, track, score, highlight, export — yet the app never shows it
as a journey, so features feel isolated and the UI gives the user no sense of
what to do next. Grouping recordings into a workspace and surfacing the pipeline
as a visible, stateful toolbar turns a flat list of actions into a guided flow.

## What Changes

- Introduce a **workspace**: a named group that holds multiple imported videos.
  The workspace screen becomes the home screen.
- Import targets a workspace, so a user gathers the recordings of a session in
  one place instead of a flat library.
- Each video in a workspace shows a **pipeline toolbar** — the seven existing
  stages in order (import → mark court → prepare analysis → player analysis →
  review & score → highlights → export), each rendered with a `done` / `ready` /
  `blocked` state and the next actionable stage highlighted.
- The toolbar **reuses every existing feature screen unchanged**; it only
  replaces the hidden popup menu as the way those screens are reached.
- The flat match library is replaced by workspace browsing; a video still runs
  the existing one-video pipeline, and the Rust engine is unchanged.

## Capabilities

### New Capabilities
- `workspace`: grouping imported recordings into named workspaces, browsing
  workspaces, and the per-video pipeline toolbar that surfaces existing stages
  with done/ready/blocked state and highlights the next step.

### Modified Capabilities
- `match-library`: a match now belongs to a workspace; import places a recording
  into a workspace; the home surface is the workspace screen rather than a flat
  match list.

## Impact

- **App data**: new `workspaces` table plus a `workspace_id` association on
  `matches`, added through a versioned SQLite migration in
  `app/lib/src/features/library/data/match_catalog.dart`.
- **App navigation**: new workspace home route and screen; the existing flat
  library screen is retired or repurposed. Router in `app/lib/src/app/router.dart`.
- **App presentation**: new workspace feature folder
  (`app/lib/src/features/workspace/`) and a pipeline toolbar widget; existing
  feature screens (calibration, analysis, tracking, score, highlights, export)
  are reused unchanged.
- **Engine**: none. No bridge, DTO, or Rust change.
