# Intent Capture Questions

Mode: yolo — recommended answers auto-selected.

### Q1: Does "Menu Studio" mean the **Studio** section of the feature rail?

A. Yes. The workspace studio's right rail is split into **Play**, **Analysis**
   (calibrate, analyze, track) and **Studio** (score, highlight, export).
   "Review & score" is the `PipelineStage.score` item, currently the first row
   under **Studio**. *(Recommended)*
B. No — a separate screen or menu not shown in the studio rail.

[Answer]: A (auto-selected). The section headers `Analysis` and `Studio` are
defined in `_FeatureRail` in `workspace_studio_screen.dart`, and
`PipelineStage.score` (`'Review & score'`) is the item to move.

### Q2: Is this a presentation-only move, or does the pipeline order change?

A. Presentation only. Move `PipelineStage.score` from the `_studio` list to the
   `_analysis` list. `PipelineStage` values, `resolveStageStates`, the routes,
   and `ScoreView` are untouched. *(Recommended)*
B. Also reorder the `PipelineStage` enum and its prerequisites.

[Answer]: A (auto-selected). The request is about which menu the feature appears
under, not about the underlying stage graph.

### Q3: Where should "Review & score" sit inside **Analysis**?

A. Last, after Player analysis: Mark court, Prepare analysis, Player analysis,
   Review & score — matching the pipeline order (analyze → track → score).
   *(Recommended)*
B. First, before Mark court.

[Answer]: A (auto-selected). It keeps the rail in the order the user performs
the steps.

### Q4: Should the architecture doc be updated in the same change?

A. Yes. `docs/architecture.md` names the rail groups explicitly
   ("**Analysis** (calibrate, analyze, track) and **Studio** (score, highlight,
   export)"); update that sentence to match. *(Recommended)*
B. No, leave the doc.

[Answer]: A (auto-selected). AGENTS.md keeps the docs authoritative and this
sentence would otherwise be wrong.
