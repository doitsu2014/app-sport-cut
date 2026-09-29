# Refactor Notes

No refactor performed. I reviewed the diff and the surrounding `_FeatureRail`
against the review record's findings.

## Debt considered

- **The two private `const` lists (`_analysis`, `_studio`).** These are the only
  structural smell nearby: the grouping is hard-coded. The architecture stage
  explicitly considered a data-driven section model (Option B) and rejected it as
  YAGNI for two groups (`design-decisions.md` DD-1). Refactoring to it now would
  reintroduce a rejected option with no named benefit and no user-visible effect,
  so it is declined. Revisit if a third group appears.
- **Review finding 1 (comment wording).** Cosmetic; changing the `_analysis`
  comment is churn with no correctness value. Declined.
- **Review finding 2 (no regression test).** This is a test-coverage gap, not
  structural debt. `AGENTS.md` makes new tests opt-in; tracked as the optional
  U3 follow-up rather than a refactor.

## Safety net

Not applicable — no code shape changed. `flutter analyze` remains clean.

## What moved / changed shape / stayed the same

Nothing moved in this stage. The code-generation change (one element relocated
between two compile-time lists) is already minimal and behaviour-preserving, so
there is no smaller mechanical step to take.
