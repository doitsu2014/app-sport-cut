# API Contract Design — diary

## Interpretation
- 2026-09-29: The stage's condition is "always executes when the system exposes
  or consumes an interface". This change exposes none. I still produced the
  artifact (the stage is ALWAYS in the `feature` workflow) but recorded the only
  real contract — the one-list-per-stage invariant — instead of inventing an
  endpoint.

## Tradeoff
- 2026-09-29: Kept the document short rather than padding it with a fake error
  model. The stage remains auditable: the "no interface" decision and the
  invariant it preserves are explicit.

## Open question
- 2026-09-29: None.
