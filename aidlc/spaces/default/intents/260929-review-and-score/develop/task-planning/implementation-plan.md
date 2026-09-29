# Implementation Plan

## Approach

A single presentation-only diff. Move `PipelineStage.score` from the `_studio`
const list to the `_analysis` const list in `_FeatureRail`, append it last, and
update the one sentence in `docs/architecture.md` that names the groups. Nothing
else changes: the render loop, `_item`, `_FeatureItem`, `_buildCenter`,
`PipelineStage`, `resolveStageStates`, and the route table are untouched.

## Conventions to follow

- Feature folder layout and existing patterns (`app/AGENTS.md`): the change stays
  inside `features/workspace/presentation/`.
- Keep `flutter analyze` clean; lints from `package:flutter_lints/flutter.yaml`.
- No new dependency, no generated file, no engine/bridge change (HC-2..HC-4).
- Keep the diff scoped to the unit; no drive-by edits (developer-agent principle 2).
- Commit message explains why (the grouping reads more naturally), root
  `AGENTS.md`.

## Commands

```bash
cd app && flutter analyze
cd app && flutter test          # only when U3 is taken, or at the verification step
```

`SPORTCUT_FLUTTER_BIN` must be set if `flutter` is not on `PATH` (root `AGENTS.md`).

## Review strategy

- One review-sized diff containing U1 + U2.
- Reviewer checks: exactly one occurrence of `PipelineStage.score` in the rail
  group lists; Analysis ends with score; Studio has two entries; the doc sentence
  matches; no diff outside the two files.
- U3 is reviewed separately if taken.

## Deviations to watch for

- If a third rail group is ever needed, revisit `design-decisions.md` DD-1
  (data-driven section model) rather than adding a third list ad hoc.
- If U3 proves expensive to build, record that as a deviation and rely on code
  review, per DD-6.
