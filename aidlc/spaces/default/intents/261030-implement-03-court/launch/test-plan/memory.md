# Test Plan — Stage Diary

## Interpretation

- 2026-10-30: Read "test plan" as the risk-based strategy and exit criteria, not
  a mandate to author tests. The project working agreement waives new tests, so
  the plan maps risk to existing evidence and names the gaps.
- 2026-10-30: Ranked engine-geometry rendering first: it is the defect this
  feature fixes and the one with the highest downstream impact.

## Tradeoff

- 2026-10-30: Relied on the screenshot suite plus a human visual check for the
  design contract instead of golden images. The cost is no automated visual
  regression; the benefit is no new test scaffolding against the agreement.

## Open question

- 2026-10-30: A golden-image assertion for the two calibration states is the
  obvious next quality investment; it is recorded as a follow-up, not started.
