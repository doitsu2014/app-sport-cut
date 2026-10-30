# Release Validation — Stage Diary

## Interpretation

- 2026-10-30: Re-ran the whole gate, including the engine suite even though the
  diff is client-only, because "keep main working" is a release condition.
- 2026-10-30: Treated "go" as scoped to merging the client feature, not to
  shipping a packaged app. The packaged-service path is blocked and is called out
  rather than averaged into a green result.

## Deviation

- 2026-10-30: Did not auto-approve the release gate, despite `mode: yolo`. The
  stage reserves this decision for a human, and the recorded recommendation is a
  recommendation, not a decision.

## Tradeoff

- 2026-10-30: Recorded the two stale screen tests and the absent verification
  record as accepted gaps rather than repairing them, honoring the working
  agreement over a fully green test run.

## Open question

- 2026-10-30: The packaged path needs a Phase 3/4 decision (stop sending
  `matchDir`, or make the release service resolve the client store). Until then,
  a packaged build cannot exercise calibration.
