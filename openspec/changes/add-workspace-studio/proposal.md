## Why

The workspace shipped in `add-workspace` is a folder of video cards, each
carrying its own horizontal pipeline strip, and every feature is still a
full-screen route that spins up its own video player. It works, but it feels
like browsing a list, not working on a match. The next step is a three-pane
**studio**: videos on the left, one persistent video preview in the center, and
the features as a vertical rail on the right — the same mental model as a video
editor's media bin, monitor, and tools. Features become lenses on one shared
preview instead of isolated screens.

## What Changes

- Introduce a three-pane workspace studio: left rail lists the workspace's
  videos, center shows a **single shared video preview**, right rail lists the
  features.
- Own one `PlaybackController` per selected video in the studio, instead of one
  per feature screen. Features receive the controller rather than creating it.
- The right rail replaces the per-video pipeline toolbar; it applies to the
  selected video and reuses the existing done/ready/blocked state per feature.
- Extract each feature screen's body into an embeddable view and host it in the
  center pane, so Play and Calibrate become overlays on the shared preview and
  the remaining features dock a panel beside it.
- Preserve per-match feature state in Riverpod providers keyed by `matchId`, so
  switching videos does not discard in-progress work.
- Ship in phases: the shell plus Play and Calibrate first; Track, Score,
  Highlights, Analyze, and Export follow. Non-migrated features keep opening
  their existing route until they land.
- No engine, bridge, DTO, or Rust change.

## Capabilities

### New Capabilities
- `workspace-studio`: the three-pane studio surface — a shared per-video player,
  a feature rail that selects a lens onto the selected video, embeddable feature
  views hosted in the center pane, and per-match feature state that survives
  switching videos.

### Modified Capabilities
- `workspace`: the per-video pipeline toolbar requirement is replaced by the
  studio's right-rail feature selector; the workspace videos surface becomes the
  three-pane studio. (This capability is introduced by `add-workspace`, which
  must be archived or synced before this delta is applied.)

## Impact

- **Workspace presentation** (`app/lib/src/features/workspace/`): the video-card
  list becomes a three-pane studio screen; the per-video `PipelineToolbar` is
  superseded by the right-rail feature selector.
- **Playback ownership** (`app/lib/src/features/library/presentation/`): the
  `PlaybackController` becomes injectable into feature screens instead of being
  created inside them, so the studio can own one instance per selected video.
- **Feature screens** (`calibration`, `tracking`, `score`, `highlights`,
  `export`, `analysis`): each screen's body is extracted into an embeddable view
  consumed by the center pane; the existing full-screen routes remain until each
  feature is migrated.
- **Engine**: none.
