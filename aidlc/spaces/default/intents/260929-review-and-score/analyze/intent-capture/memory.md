# Intent Capture — diary

## Interpretation
- 2026-09-29: "Review and Score Feature on Menu Studio to Analysis Menu" read as
  a UI regroup: move the `PipelineStage.score` ("Review & score") item from the
  rail's **Studio** section to its **Analysis** section. Confirmed against
  `_FeatureRail` in `workspace_studio_screen.dart`, where `_analysis` and
  `_studio` are the two static lists, and against `docs/architecture.md`, which
  names the groups explicitly.
- 2026-09-29: The "move" is presentation-only. `PipelineStage`, `resolveStageStates`,
  routes, and `ScoreView` are left alone; only the two list memberships and the
  doc sentence change.

## Tradeoff
- 2026-09-29: Placed "Review & score" last in **Analysis** (after Player
  analysis) rather than first, so the rail follows the pipeline order
  analyze → track → score.

## Open question
- 2026-09-29: None material. Whether the section labels themselves should be
  renamed ("Analysis" → something else) is out of scope for this intent.
