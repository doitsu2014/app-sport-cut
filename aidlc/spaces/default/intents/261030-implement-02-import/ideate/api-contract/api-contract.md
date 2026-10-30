# API Contract — Import and Media Preparation (Feature 2)

Status: Ideate / API Contract Design
Intent: `261030-implement-02-import`
Consumes: `../architecture-design/architecture-doc.md`, `../../analyze/requirements-analysis/requirements.md`

## 1. Service protocol contract (`core/gateways/protocol`)

No wire changes are introduced. The client continues to consume the existing
Sportcut Service Protocol v1 (`engine.probe`, `engine.import.start`,
`engine.manifest`, `engine.regenerate.start`, `job.status`, `job.cancel`).

### 1.1 `engine.manifest` response schema (existing, consumed for G2 & G3)

```json
{
  "matchId": "match-1",
  "originalPath": "/path/to/recording.mp4",
  "artifacts": [
    {
      "kind": "proxy",
      "relativePath": "proxy/proxy.mp4",
      "state": "final",
      "sizeBytes": 1048576
    },
    {
      "kind": "calibration",
      "relativePath": "calibration/court.json",
      "state": "missing",
      "sizeBytes": null
    }
  ],
  "missingKinds": ["calibration"],
  "notRebuildableKinds": ["calibration"],
  "originalPresent": true
}
```

## 2. Internal Dart interfaces (`app/lib/src/`)

### 2.1 `RecordingStore.takeCustody` (`recording_store.dart`)

```dart
Future<CustodiedRecording> takeCustody({
  required String matchId,
  required PickedVideo video,
  ImportCancelToken? cancelToken,
  int? expectedBytes,
  void Function(double fraction)? onProgress,
});
```

- **Inputs**:
  - `matchId`: target match identifier.
  - `video`: `PickedVideo` selected by the user.
  - `cancelToken`: cooperative cancellation token checked before each chunk.
  - `expectedBytes`: optional known byte size from `MediaMetadataDto.sizeBytes`
    (falls back to `source.lengthSync()` when null or `<= 0`).
  - `onProgress`: optional callback receiving a clamped fraction in `0.0..1.0`.
    Called with `0.0` before the first chunk, whenever `(fraction * 100).round()`
    increases during chunk streaming, and `1.0` after `sink.flush()`.
- **Output**: `CustodiedRecording(path, name, bytes)`.
- **Errors**: `MatchImportException` (`cancelled`, `noSpace`, `storage`), after
  removing the match's recording directory.

### 2.2 `MatchLibrary.importVideo` / `MatchRepository.importVideo`

```dart
Future<MatchRecord> importVideo(
  PickedVideo video, {
  String? title,
  String? workspaceId,
  ImportCancelToken? cancelToken,
  void Function(double fraction)? onProgress,
});
```

- **Compatibility**: `onProgress` is an optional named parameter defaulting to
  `null`, so all existing callers (`match_repository_test.dart`, etc.) remain
  source-compatible.

### 2.3 `ImportState` (`import_controller.dart`)

```dart
class ImportState {
  const ImportState({
    this.phase = ImportPhase.idle,
    this.fraction,
    this.problem,
  });

  final ImportPhase phase;
  final double? fraction;
  final MatchImportException? problem;
}
```

- **Lifecycle**:
  - `ImportPhase.idle`: `fraction == null`.
  - `ImportPhase.picking`: `fraction == null`.
  - `ImportPhase.importing`: starts at `fraction: 0.0`, updates in `0.0..1.0` via
    `onProgress`.

### 2.4 `AnalysisState` (`analysis_providers.dart`)

```dart
/// Missing artifacts that the media pipeline can rebuild (`proxy`,
/// `analysis_audio`, `frames`).
List<ArtifactDto> get rebuildableMissing {
  final Set<String> notRebuildable =
      (manifest?.notRebuildableKinds ?? const <String>[]).toSet();
  return <ArtifactDto>[
    for (final ArtifactDto artifact in missing)
      if (!notRebuildable.contains(artifact.kind)) artifact,
  ];
}

/// Missing artifacts that require another studio stage (`calibration`,
/// `tracks`, `rally_suggestions`, `export`).
List<ArtifactDto> get notRebuildableMissing {
  final Set<String> notRebuildable =
      (manifest?.notRebuildableKinds ?? const <String>[]).toSet();
  return <ArtifactDto>[
    for (final ArtifactDto artifact in missing)
      if (notRebuildable.contains(artifact.kind)) artifact,
  ];
}
```

- **Compatibility**: `AnalysisState.missing` is preserved alongside
  `rebuildableMissing` and `notRebuildableMissing`.
