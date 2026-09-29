# Requirements Analysis Questions

Mode: yolo — recommended answers auto-selected.

### Q1: Is the move a membership swap inside `_FeatureRail`, or a wider rail redesign?

A. A membership swap: `PipelineStage.score` leaves the `_studio` list and joins
   the `_analysis` list. The section headers, item rendering, icons, and stage
   facts are untouched. *(Recommended)*
B. A rail redesign with new sections.

[Answer]: A (auto-selected). The intent statement scopes the change to two list
memberships plus one doc sentence.

### Q2: Do we need a widget test for the rail order?

A. Yes — one focused test asserting the two group orders, because the grouping is
   the whole requirement and a later refactor could silently swap them back.
   *(Recommended)*
B. No test; code review is enough.

[Answer]: A (auto-selected). AGENTS.md says new tests are optional, but the
requirement is purely presentational and otherwise unverifiable; a single
ordering assertion is the cheapest acceptance check. Flagged for the Develop
track to decide when writing code — not a blocker here.

### Q3: Does the pipeline order or `resolveStageStates` change?

A. No. Score keeps prerequisite `available && tracksReady`, and the enum order
   stays `... track, score, highlight, export`. *(Recommended)*
B. Yes, reorder the enum.

[Answer]: A (auto-selected).

### Q4: Is the `ScoreScreen` full-screen route affected?

A. No. `/match/score` and `ScoreScreen` keep working exactly as they do now; only
   the rail grouping changes. *(Recommended)*
B. Yes.

[Answer]: A (auto-selected).
