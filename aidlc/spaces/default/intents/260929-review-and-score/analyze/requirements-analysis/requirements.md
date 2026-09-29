# Requirements — Move Review & score to the Analysis menu

## Functional

| ID | Requirement | Type | Pri | Source | Acceptance criteria | Verify |
| --- | --- | --- | --- | --- | --- | --- |
| RS-1 | The feature rail renders **Review & score** under the **Analysis** section header. | F | M | SC-1 | In the built rail, the "Review & score" tile appears after the "Analysis" header and before the "Studio" header. | Widget test |
| RS-2 | The **Analysis** group order is Mark court, Prepare analysis, Player analysis, Review & score. | F | M | SC-2 | The four labels appear in that order within the Analysis group. | Widget test |
| RS-3 | The **Studio** group contains only Highlights and Export. | F | M | SC-3 | No "Review & score" tile appears after the "Studio" header; Highlights and Export do. | Widget test |
| RS-4 | Selecting **Review & score** still selects `PipelineStage.score` and shows `ScoreView` for the selected match on the shared controller. | F | M | SC-4 | Tapping "Review & score" builds `ScoreView(match: selected, controller: shared)`; `_selectedStage == PipelineStage.score`. | Widget test / code review |
| RS-5 | The item keeps its stage state and busy spinner: `states[PipelineStage.score]` drives the done styling and `busyStages` drives the spinner, exactly as for every other rail item. | F | M | SC-4 | A done score fact renders the muted/done style; a busy score stage renders the spinner. | Code review |
| RS-6 | Player analysis's **Review rallies / score** action still switches the centre pane to `PipelineStage.score`. | F | S | SC-4 | `onOpenScore` still sets the selected stage to score. | Code review |
| RS-7 | `PipelineStage` values, the "Review & score" label, `resolveStageStates`, and the route table are unchanged. | F | M | SC-1/SC-4 | `pipeline_stage.dart` and `router.dart` have no diff. | Code review |

## Non-functional and constraints

| ID | Requirement | Type | Pri | Source | Acceptance criteria | Verify |
| --- | --- | --- | --- | --- | --- | --- |
| RS-8 | `docs/architecture.md` describes the rail as "**Analysis** (calibrate, analyze, track, score) and **Studio** (highlight, export)". | Constraint | M | SC-5 | The sentence in the Navigation section matches the new grouping. | Doc review |
| RS-9 | `flutter analyze` in `app/` is clean. | NFR | M | SC-6 | `flutter analyze` exits 0. | Local |
| RS-10 | The existing test suite passes unchanged. | NFR | M | SC-6 | `flutter test` exits 0. | Local |
| RS-11 | No new dependency and no engine/bridge change. | Constraint | M | Intent | `pubspec.yaml` and `core/` have no diff. | Diff review |

## Edge cases

| ID | Case | Expected |
| --- | --- | --- |
| RS-E1 | No video selected (empty states map). | The rail still renders both headers; the new order holds; no throw. |
| RS-E2 | Score stage `done` / `ready` / `idle`. | Styling follows the same `states[stage]` path as before the move. |
| RS-E3 | Narrow rail width. | Labels keep their existing `maxLines: 1` / ellipsis behaviour; no new wrapping. |

## Traceability

SC-1 → RS-1; SC-2 → RS-2; SC-3 → RS-3; SC-4 → RS-4/RS-5/RS-6/RS-7;
SC-5 → RS-8; SC-6 → RS-9/RS-10; intent scope → RS-11.

No orphan requirements. Every requirement traces to a success criterion or the
intent's scope and constraints, and every row has a testable acceptance
criterion.
