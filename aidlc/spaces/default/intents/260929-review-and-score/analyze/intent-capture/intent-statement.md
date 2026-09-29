# Intent Statement — Move Review & score from the Studio menu to the Analysis menu

## Problem

In the workspace studio, the right-hand feature rail is divided into three
groups: **Play**, then **Analysis** (Mark court, Prepare analysis, Player
analysis) and **Studio** (Review & score, Highlights, Export). The groups are
declared as the `_analysis` and `_studio` lists in `_FeatureRail`
(`app/lib/src/features/workspace/presentation/workspace_studio_screen.dart`).

**Review & score** is a review-and-confirm step on the analysed video: it reads
the artist-independent track artifact and lets the user confirm rally winners
and the score. It currently sits under **Studio**, grouped with the
highlight-shaping actions (Highlights, Export), even though it logically belongs
with the analysis steps that produce and verify the data. A user looking for the
scoring step in the analysis flow does not find it there.

## Users

Anyone reviewing a recorded match in the workspace studio and confirming the
score before building highlights.

## Success criteria

1. The feature rail lists **Review & score** under the **Analysis** section
   header, not under **Studio**.
2. The **Analysis** order is: Mark court, Prepare analysis, Player analysis,
   Review & score.
3. The **Studio** section contains only Highlights and Export.
4. Selecting **Review & score** still opens `ScoreView` for the selected match
   with the shared controller; its route, stage state (`done` / `ready` /
   `idle`), busy spinner, and behaviour are unchanged.
5. `docs/architecture.md` describes the rail as
   "**Analysis** (calibrate, analyze, track, score) and **Studio** (highlight,
   export)".
6. `flutter analyze` in `app/` is clean and the existing test suite still
   passes.

## In scope

- Moving `PipelineStage.score` from the `_studio` static list to the `_analysis`
  static list in `_FeatureRail`.
- Updating the rail-group sentence in `docs/architecture.md`.

## Out of scope

- Renaming the "Review & score" label or the `PipelineStage.score` enum value.
- Changing `resolveStageStates` prerequisites or the `PipelineStage` declaration
  order.
- Changing `ScoreView`, `ScoreScreen`, the `/match/score` route, or any engine
  or persistence behaviour.
- Adding, removing, or restyling any rail item, icon, or section header.

## Constraints

- Client track only (Flutter/Dart). No engine or bridge change.
- No new dependencies.
- The move is presentation-only: the stage graph, route table, and persistence
  are not touched.

## Assumptions

- "Menu Studio" is the **Studio** section header of the feature rail, and
  "Analysis Menu" is the **Analysis** section header.
- The `Analysis` / `Studio` grouping is a UI concern only; nothing else keys off
  those two private lists.

## Cost of doing nothing

The scoring step stays visually grouped with highlight output, which is mildly
misleading but not blocking. The change is small and low-risk; leaving it makes
the rail steadily less intuitive as more features are added.
