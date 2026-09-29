# Technical Specification — diary

## Interpretation
- 2026-09-29: The spec's value here is pinning the exact before/after list literal
  and the "no change" surface, so Develop cannot accidentally widen the diff.

## Tradeoff
- 2026-09-29: W3 (ordering test) is a seed, not a mandate, per AGENTS.md. The spec
  says how to verify each requirement regardless, so the stage is complete either
  way.

## Open question
- 2026-09-29: Whether an existing test file should host the ordering test, or a
  new `workspace_studio_rail_test.dart` should be created. Left to Develop; no
  test currently pumps the studio rail, so it may need provider setup.
