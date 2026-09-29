# Design Pattern Selection — diary

## Interpretation
- 2026-09-29: Most of the usual "forces" (persistence, messaging, resilience,
  concurrency) are absent. The only genuine design force is *where the grouping
  is declared*, so DD-1 carries the decision and the rest pin behaviour that must
  not change.

## Tradeoff
- 2026-09-29: DD-6 deliberately leaves the test as optional to respect
  AGENTS.md's "implement first, tests optional" rule, while naming the risk it
  would mitigate.

## Deviation
- 2026-09-29: No ADR needed for a one-row regroup beyond this table; the stage
  artifact is the ADR.

## Open question
- 2026-09-29: None.
