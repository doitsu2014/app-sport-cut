# Code Generation Notes

## Changes

| Unit | File | Change | Reqs |
| --- | --- | --- | --- |
| U1 | `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart` | Moved `PipelineStage.score` out of `_FeatureRail._studio` and appended it to `_FeatureRail._analysis`. The shared `_item(stage)` loop, `_FeatureItem` styling, `_buildCenter` score→`ScoreView` mapping, and `onSelectStage` are untouched, so grouping is the only observable change. | RS-1, RS-2, RS-3, RS-4, RS-5, RS-6, RS-7 |
| U2 | `docs/architecture.md` | Updated the Navigation sentence to "**Analysis** (calibrate, analyze, track, score) and **Studio** (highlight, export)". | RS-8 |

## Verification

- `tools/generate-bridge.sh` — the generated bridge files were absent from the
  checkout (they are never committed), which produced 326 pre-existing analyzer
  errors unrelated to this change. Regenerated them.
- `cd app && flutter analyze` — **No issues found!** (ran in 1.7s). RS-9 ✓.
- The full `flutter test` suite was **not** run: root `AGENTS.md` says not to run
  test suites as part of ordinary work, and the cheapest applicable check for a
  two-line presentation change is `flutter analyze`. No test references the rail
  groups (`grep` across `app/test` for `FeatureRail` / `workspace_studio` /
  `Review & score` returns nothing), so no existing test can regress from this
  diff. RS-10 is deferred to the verification step.
- Diff is scoped: `git diff --stat` shows only the two files above.

## Deviations

- U3 (optional ordering widget test from the plan) was **not** implemented,
  because `AGENTS.md` forbids adding new test files unless the user explicitly
  asks. Recorded as a follow-up, not a defect: the grouping is covered by code
  review against `docs/architecture.md`, and the optional test remains available
  if the team wants the regression guard later. This matches `design-decisions.md`
  DD-6 and the plan's "optional" marking.
- No deviation from the technical spec; the diff matches the specified
  before/after literals exactly.
