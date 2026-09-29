# Technical Specification — Move Review & score to the Analysis menu

## Requirement → component map

| Req | Component | Interface | Test approach |
| --- | --- | --- | --- |
| RS-1, RS-2, RS-3 | `_FeatureRail._analysis`, `_FeatureRail._studio` | private `const List<PipelineStage>` | Optional ordering widget test; else code review |
| RS-4 | `_FeatureRail._item` → `onSelectStage`; `_buildCenter` `case PipelineStage.score` | `void Function(PipelineStage)`, `Widget` | Existing score widget test (`app/test/score_screen_test.dart`) + manual |
| RS-5 | `_FeatureItem` via `_item` (`states[stage]`, `busyStages`) | widget props | Code review |
| RS-6 | `PlayerTrackingView.onOpenScore` | `VoidCallback` | Code review |
| RS-7 | `PipelineStage`, `resolveStageStates`, `AppRouter` | — | Diff review (no change) |
| RS-8 | `docs/architecture.md` Navigation section | prose | Doc review |
| RS-9, RS-10 | `app/` toolchain | `flutter analyze`, `flutter test` | Local |
| RS-11 | `pubspec.yaml`, `core/` | — | Diff review (no change) |

Every must-have (RS-1..RS-11) is mapped. RS-E1..RS-E3 are covered by RS-1..RS-5
plus the existing widget rendering path.

## Component specification

### `_FeatureRail` — `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart`

- **Responsibility:** render the ordered feature lens list, grouped under
  **Analysis** and **Studio**, in front of the **Play** row.
- **Inputs:** `states: Map<PipelineStage, StageState>`, `selectedStage:
  PipelineStage?`, `busyStages: Set<PipelineStage>`, `onSelectPlay`,
  `onSelectStage`.
- **Outputs:** the rail widget tree.
- **State:** none; both group lists are compile-time `const`.
- **Dependencies:** none beyond Flutter and the surrounding widget.
- **Error handling:** none; a stage rendered without a state defaults through
  `states[stage] == StageState.done` being false, as today.
- **Configuration:** none.

**Change:**

```dart
// before
static const List<PipelineStage> _analysis = <PipelineStage>[
  PipelineStage.calibrate,
  PipelineStage.analyze,
  PipelineStage.track,
];

static const List<PipelineStage> _studio = <PipelineStage>[
  PipelineStage.score,
  PipelineStage.highlight,
  PipelineStage.export,
];

// after
static const List<PipelineStage> _analysis = <PipelineStage>[
  PipelineStage.calibrate,
  PipelineStage.analyze,
  PipelineStage.track,
  PipelineStage.score,
];

static const List<PipelineStage> _studio = <PipelineStage>[
  PipelineStage.highlight,
  PipelineStage.export,
];
```

The render loop (`_item(stage)` for each list) is untouched, so ordering within
each list is the order rendered. `_SectionHeader` labels are untouched.

### `ScoreView` / `PipelineStage` / `resolveStageStates` / `AppRouter`

No change. They stay the contract the move relies on: selecting
`PipelineStage.score` still shows `ScoreView`, and the stage's `ready`/`done`
state still derives from `tracksReady` / `hasScore`.

### `docs/architecture.md`

Update the Navigation sentence from:

> a right feature rail — **Play**, then **Analysis** (calibrate, analyze, track)
> and **Studio** (score, highlight, export).

to:

> a right feature rail — **Play**, then **Analysis** (calibrate, analyze, track,
> score) and **Studio** (highlight, export).

## Cross-cutting concerns

- **Security:** none. No input, I/O, network, secrets, or dependency change.
- **Observability:** none added. No logging or telemetry.
- **Performance budget:** unchanged — one extra `_FeatureItem` moves between two
  already-rendered lists; the same number of rows is built.
- **Data lifecycle:** unchanged — no data is read or written.
- **Accessibility:** unchanged — the same `ListTile` with the same label, icon,
  tooltip, and selection semantics; only its position in the list differs.

## Work breakdown seeds (dependency order)

1. **W1 — Regroup the rail.** Move `PipelineStage.score` to `_analysis` and out
   of `_studio`. Verify with `flutter analyze`. (Depends on nothing.)
2. **W2 — Update the design record.** Fix the `docs/architecture.md` sentence.
   (Independent of W1; both land in one diff.)
3. **W3 — Guard the grouping (optional).** Add a single focused widget test
   asserting the Analysis order and that Studio is Highlight/Export only; run
   `flutter test`. (Depends on W1.)

Develop owns the final unit breakdown; these are seeds only.
