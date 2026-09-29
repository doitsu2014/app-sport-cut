# API Contract — Move Review & score to the Analysis menu

## Interfaces

This intent exposes and consumes **no** public API, service contract, event,
CLI, or data schema. It is a compile-time regrouping of UI rows inside one
private widget; there is no wire format, no persistence, and no cross-process
boundary. The stage's contract is therefore recorded as the internal widget
invariant it preserves, not as a versioned interface.

## Internal invariant (the only contract that matters)

`_FeatureRail` (`app/lib/src/features/workspace/presentation/workspace_studio_screen.dart`)
renders groups from two private static lists. Each `PipelineStage` appears in
**exactly one** list. This change moves `PipelineStage.score` from `_studio` to
`_analysis`; it does not add it twice.

| Group | Header | Members (after) |
| --- | --- | --- |
| Analysis | `_SectionHeader('Analysis')` | calibrate, analyze, track, **score** |
| Studio | `_SectionHeader('Studio')` | highlight, export |

Unchanged behaviour this contract pins:

- Row selection still calls `onSelectStage(PipelineStage.score)`.
- `_buildCenter` still maps `PipelineStage.score` to
  `ScoreView(match: entry.match, controller: controller)`.
- Styling and the busy spinner still come from `states[stage]` and
  `busyStages.contains(stage)` via `_item`.
- `PlayerTrackingView.onOpenScore` still selects `PipelineStage.score`.

## Compatibility

- No versioning applies: there is no serialized contract.
- The change is source-compatible and reversible. `PipelineStage` values, the
  `'Review & score'` label, `resolveStageStates`, the route table, and
  `/match/score` are untouched, so nothing downstream can observe the move
  except the rendered rail order.

## Examples

Not applicable — there is no request/response or error model. The observable
"response" is the rail order, covered by requirements RS-1..RS-3 and their
acceptance criteria.
