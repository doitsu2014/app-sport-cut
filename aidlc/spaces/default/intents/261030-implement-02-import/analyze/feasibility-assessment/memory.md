# Feasibility Assessment — Stage Diary

## Interpretation

- 2026-10-30: Confirmed that `StudioShell` and `VideoRail` already declare an
  optional `importFraction` parameter (`studio_shell.dart:65`,
  `video_rail.dart:36`) that was wired to `ScProgressJob(fraction: importFraction)`
  during the studio shell refactor, waiting only for `ImportController` and
  `WorkspaceStudioScreen` to supply it.
- 2026-10-30: Confirmed that `ArtifactManifestDto.notRebuildableKinds` is
  already populated by `core/adapters/api/src/dto.rs` (`from_manifest`) and
  decoded by `app/lib/src/bridge/models.dart`.

## Tradeoff

- 2026-10-30: Chose percentage-point throttling (updating `ImportState.fraction`
  when `(fraction * 100).round()` advances, plus `0.0` and `1.0`) rather than a
  timer-based throttle, keeping the implementation deterministic in tests and
  capped at 101 state updates per import regardless of file size.
