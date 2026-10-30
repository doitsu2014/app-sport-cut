# Code Generation — Stage Diary

## Interpretation

- 2026-10-29: Read FR-LIB-20's "selected stage" as the compact stage label, not
  the full stage name. 30 px at 200% text scale leaves room only for the short
  vocabulary.

## Deviation

- 2026-10-29: Swapped `ScProgressJob` for a labelled `CircularProgressIndicator`
  in the home loading state. `ScProgressJob` at a null fraction draws a 0%
  determinate track, which looks stalled; the rail already uses a spinner for
  the same situation.
- 2026-10-29: Derived the post-delete selection from the pre-delete list rather
  than re-reading the invalidated provider, which would return stale data.

## Tradeoff

- 2026-10-29: Kept `StudioStatusBar` provider-free by widening its constructor
  instead of letting it read the studio controller. Cost: one more parameter
  through `StudioShell`.

## Open question

- 2026-10-29: Visual confirmation at 200% text scaling was not run; the stage
  label is short by design but the bar's total width is unverified in a live
  window.
