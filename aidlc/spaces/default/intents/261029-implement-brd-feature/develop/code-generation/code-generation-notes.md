# Code Generation Notes — Workspace and Library gaps

Intent: `261029-implement-brd-feature`

## Deviations from the technical spec

1. **G2 uses a labelled `CircularProgressIndicator`, not `ScProgressJob`.**
   `ScProgressJob` with a null `fraction` renders a determinate track at 0% with
   no percentage, which reads as stalled rather than loading. The studio's video
   rail already uses `CircularProgressIndicator` for an unresolved list read, so
   the home mirrors that idiom. The indicator carries
   `Semantics(label: 'Reading workspaces')`.

2. **G4 computes the next selection from the pre-delete list.**
   `_refresh()` invalidates providers asynchronously, so reading the provider
   immediately after it would still return the old value. The implementation
   derives the remaining list from the list read before the delete, which is
   deterministic and race-free.

## Notes

- `shortStageLabel` lives in the domain file so the stage strip and the status
  bar share one vocabulary. `PipelineStageInfo.label` remains the full,
  accessible name.
- The status bar shows the stage only when a video is selected; with no video
  there is no selected stage to report.
- The delete path now disposes the shared playback controller when the last
  video is removed, so a stale controller cannot outlive its recording.
- `flutter analyze` surfaced one const error during the first pass
  (`Semantics` is not a const constructor in this SDK); fixed before the
  verification run.
