# Technical Specification — Workspace and Library gaps (G1–G4)

Status: Ideate / Technical Specification
Intent: `261029-implement-brd-feature`
Consumes: `architecture-doc.md`, `design-decisions.md`, `api-contract.md`,
`requirements.md`

## 1. Change surface

Client only: `app/lib/src/features/workspace/`. No bridge, protocol, service,
catalog schema, or dependency change.

| File | Change |
| --- | --- |
| `app/lib/src/features/workspace/domain/pipeline_stage.dart` | Add `shortStageLabel(PipelineStage?)`. |
| `app/lib/src/features/workspace/presentation/studio/stage_strip.dart` | Use the shared helper instead of the private `_shortStageLabels` map. |
| `app/lib/src/features/workspace/presentation/studio/studio_shell.dart` | Pass `stageLabel` to `StudioStatusBar`. |
| `app/lib/src/features/workspace/presentation/studio/studio_status_bar.dart` | Add `required String stageLabel`; render it in the right cluster. |
| `app/lib/src/features/workspace/presentation/workspace_screen.dart` | G2 loading branch; G3 error copy. |
| `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart` | G4 index-preserving selection after delete. |

## 2. G1 — status-bar stage label

### 2.1 `pipeline_stage.dart`

```dart
/// A compact label for tight chrome: the stage strip and the status bar.
///
/// `null` is the Play stage, the shared preview.
String shortStageLabel(PipelineStage? stage) => switch (stage) {
      null => 'Play',
      PipelineStage.import => 'Import',
      PipelineStage.calibrate => 'Court',
      PipelineStage.analyze => 'Analysis',
      PipelineStage.track => 'Tracking',
      PipelineStage.score => 'Score',
      PipelineStage.highlight => 'Clips',
      PipelineStage.export => 'Export',
    };
```

### 2.2 `stage_strip.dart`

Delete `_shortStageLabels` and replace its uses with `shortStageLabel(stage)`.
No visible change: the map's values and the helper's values are identical.

### 2.3 `studio_status_bar.dart`

- Add `required this.stageLabel` and `final String stageLabel;`.
- In the right cluster, after the readiness text, append:

```dart
Text(' · $stageLabel', style: style.copyWith(color: palette.fg2)),
```

The stage label is tabular-neutral text; it uses `micro10` like the rest of the
bar, so no new token is needed.

### 2.4 `studio_shell.dart`

```dart
StudioStatusBar(
  videoCount: videos?.length ?? 0,
  missingCount: missing,
  entry: selected,
  facts: selected == null ? null : facts?[selected.match.id],
  stageLabel: shortStageLabel(selectedStage),
),
```

## 3. G2 — home loading state

`workspace_screen.dart` `_body` loading branch:

```dart
loading: () => _centred(
  const ScProgressJob(stageLabel: 'Reading workspaces'),
),
```

`ScProgressJob`'s existing shape is `stageLabel` + optional `fraction` +
optional `detail` + optional `onCancel`; without `fraction` it renders the
indeterminate bar, which is the honest state while a SQLite read is in flight.

No empty-state copy is rendered in the loading branch, satisfying FR-LIB-05.

## 4. G3 — error reason

`workspace_screen.dart` `_body` error branch:

```dart
error: (Object error, StackTrace stackTrace) => _centred(
  ScEmptyState(
    message: 'The workspaces could not be read. $error',
    actionLabel: 'Retry',
    onAction: () {
      ref.invalidate(workspaceListProvider);
      ref.invalidate(matchRepositoryProvider);
    },
    icon: ScIcons.error,
  ),
),
```

Guard: `$error` on a platform exception renders its `toString()`, which is the
reason. No stack trace is shown.

## 5. G4 — select the next remaining video after delete

In `_confirmDeleteMatch`:

1. Read the current entries:
   `final before = ref.read(workspaceVideosProvider(widget.workspace.id)).value ?? const <MatchListEntry>[];`
2. Compute `final index = before.indexWhere((e) => e.match.id == match.id);`
3. After `deleteMatch` and `_refresh()`:
   - If the deleted match was not selected (`_selectedVideoId != match.id`),
     leave the selection untouched.
   - Else read the fresh entries, pick
     `fresh.isEmpty ? null : fresh[min(index, fresh.length - 1)]`, and call
     `_selectVideo(chosen.match)`; when null, `setState(() => _selectedVideoId = null)`
     and dispose the controller.
4. `_ensureSelection` already skips an empty list (`entries.isNotEmpty` guard in
   `build`), so the empty case is not overridden.

Ordering: run the selection update after `_refresh()` so the provider has
re-read the list; `_selectVideo` is guarded by `mounted`.

## 6. Verification

- `flutter analyze` in `app/` (or `SPORTCUT_FLUTTER_BIN`).
- `tools/check-no-rust-in-app.sh` (unchanged surface; guards regressions).
- Manual: select each stage and confirm the status-bar label; delete the middle
  of three videos and confirm the next one is selected; simulate a failing
  catalog read and confirm the reason renders.
- No test files are added or modified (Q3-A).

## 7. Rollback

Each gap is independent. Reverting one file restores that behavior; no state,
schema, or user data is involved.
