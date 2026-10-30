# API Contract Design — Stage Diary

## Interpretation

- 2026-10-29: Read "API contract" as the widget contracts, because the change
  makes no service-protocol call. Recorded the non-contracts explicitly so a
  reader does not infer a protocol change.

## Tradeoff

- 2026-10-29: The `stageLabel` parameter is source-breaking for
  `StudioStatusBar` call sites. Accepted: all call sites are in-repo and are
  updated in the same change.
