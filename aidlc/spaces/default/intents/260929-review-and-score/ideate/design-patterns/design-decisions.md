# Design Decisions

| ID | Force | Decision | Rejected | Consequence |
| --- | --- | --- | --- | --- |
| DD-1 | Consistency with the existing rail; smallest reversible diff | **Keep the two private static `const` lists** (`_analysis`, `_studio`) in `_FeatureRail` and move `PipelineStage.score` between them. | A data-driven section model (list of `(header, stages)`); a flattened list with derived headers | Two-line diff, no new type; grouping stays hard-coded, which is the current idiom. Reversible if a third group ever appears. |
| DD-2 | A rail row must have exactly one home | **One-list-per-stage invariant**: each `PipelineStage` appears in exactly one group list. | Listing `score` under both groups | Selected state and busy spinner stay unambiguous. |
| DD-3 | Predictable reading order | **Order the Analysis group by pipeline order**: Mark court, Prepare analysis, Player analysis, Review & score. | Alphabetical; putting score first | The rail reads in the order the user performs the steps. |
| DD-4 | Grouping is otherwise invisible to code | **Presentation-only, no state or routing change**: reuse the shared `_item(stage)` factory so `states[stage]` and `busyStages` still drive styling; leave `_buildCenter`, `PipelineStage`, `resolveStageStates`, and the route table alone. | A bespoke tile or a new stage mapping for score | Behaviour, prerequisites, and routes are provably unchanged. |
| DD-5 | Documentation must not drift | **`docs/architecture.md` is part of the change**, not a follow-up. | Doc update as a separate ticket | The design record stays authoritative. |
| DD-6 | "Tests are optional" in this repo, but the requirement is presentational | **Add one focused ordering widget test if the Develop track can do it cheaply**; otherwise code review is the floor. | Blocking the change on a test | Risk R-1 is cheaply mitigated without violating the repo's testing posture. |

## Technologies

None selected. The change adds no library, framework, tool, or dependency; it is
plain Flutter/Dart using the widgets already in the file.

## Alignment with existing patterns

- Private `const` lists inside the widget that renders them — the current
  pattern, kept.
- A single `_item` factory for every rail row — kept, so no stage gets special
  rendering.
- Section labels come from `_SectionHeader`, unchanged.
