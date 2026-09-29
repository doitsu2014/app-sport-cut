# Feasibility Assessment

No research report was produced for this intent (`research-synthesis` is skipped
by the `feature` scope), and none is needed: the whole change is a two-list
membership swap in one widget plus one documentation sentence.

## Technical feasibility

| Req | Verdict | Basis |
| --- | --- | --- |
| RS-1, RS-2, RS-3 rail grouping | Feasible, trivial | The rail is built from two private static `const` lists, `_analysis` and `_studio`, in `_FeatureRail` (`app/lib/src/features/workspace/presentation/workspace_studio_screen.dart:448-456`). Both are iterated with the same `_item(stage)` factory, so moving `PipelineStage.score` between them changes group and order with no other edit. |
| RS-4, RS-5, RS-6 behaviour, state, spinner | Feasible, automatic | `_item` reads `states[stage]` and `busyStages.contains(stage)`; `onSelectStage` and the `score → ScoreView` mapping in `_buildCenter` are keyed on the enum, not the list. Moving the list membership cannot change them. `PlayerTrackingView.onOpenScore` still sets `PipelineStage.score`. |
| RS-7 no wider change | Feasible, verified | `PipelineStage` (`pipeline_stage.dart`), `resolveStageStates`, and `router.dart` are not touched. The lists are private to `_FeatureRail`, so no caller keys off the grouping. |
| RS-8 doc update | Feasible | One sentence in `docs/architecture.md:115-116` names the groups explicitly; update it. |
| RS-9, RS-10 analyze + tests | Feasible | Pure Dart, existing `flutter analyze` / `flutter test` gates. No test currently references the rail (`grep` across `app/test` for `FeatureRail`/`workspace_studio`/`Review & score` returns nothing), so nothing breaks; an optional ordering test is the only new verification. |
| RS-11 no dependency / engine change | Feasible | No import or pubspec change; `core/` untouched. |

No spikes needed.

## Cost and schedule

Under an hour of engineering: the two-line list move (~5 min), the doc sentence
(~5 min), optional focused ordering widget test (~20 min), and `flutter analyze`
/ `flutter test` (~15 min). No design pass is required beyond this stage.

## Risks

See `constraint-register.md` (R-1..R-3). All are low.

## Recommendation

**Proceed.** The change is presentation-only, reversible, and fully covered by
the existing client gates. Its only real risk is documentation drift, mitigated
by RS-8.
