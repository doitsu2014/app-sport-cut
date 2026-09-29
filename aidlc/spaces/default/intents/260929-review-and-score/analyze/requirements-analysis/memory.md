# Requirements Analysis — diary

## Interpretation
- 2026-09-29: Treated the grouping change as the sole functional requirement set.
  Because the rail is built from two private static lists, the acceptance check
  is an ordering assertion, not a behavioural one.

## Tradeoff
- 2026-09-29: Added RS-5 (stage state / busy spinner preserved) as an explicit
  requirement rather than assuming it, since `_item(stage)` is shared and the
  move must not bypass it with a bespoke tile.

## Open question
- 2026-09-29: Whether to add the ordering widget test is left to the Develop
  track; AGENTS.md makes tests optional, but the requirement is otherwise only
  code-reviewable. Noted in the questions file (Q2).
