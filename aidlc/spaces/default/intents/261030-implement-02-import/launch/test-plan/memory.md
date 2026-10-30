# Test Plan — Stage Diary

## Interpretation

- 2026-10-30: Drafted a risk-ranked plan that respects the working
  agreement: records verification already done (analyze, guard, 24-agent
  adversarial review), defines five manual validation runs (MV-1..MV-5) as
  the BRD §7 evidence path, and catalogs ten requirement-named automated
  tests for a future explicit test request without writing them now.
- Exit criteria distinguish what is met, what BRD-02 §7 requires before
  "Done again", and the named go-with-known-issues gaps (cadence, timing,
  R-IMP-7, red baseline suites, accessibility audit).

## Adversarial verification (2 lenses: QA coverage, compliance/accuracy)

- 2026-10-30: panel found 2 blocking + 4 major + minors; revision 2 folds
  them all in. Headlines: MV-4 as first written was unreachable (a
  prepared-only match has no calibration manifest entry — recorded only by
  `save_calibration`; file deletion can never produce PARTIAL — NonFinal
  comes from cancelled jobs; `regenerate_missing` rebuilds proxy AND
  re-records frames); exit criteria missed the studio surface (MV-3 now
  required) and the single-flight guard; the working agreement's exception
  REQUIRES the existing-suite re-run in this evidence workflow
  (`flutter test test/match_repository_test.dart` + BRD §7 row update);
  MV-5's DONE/NEEDS REVIEW wording isn't observable (`ScPipelineRow`
  renders done as icon-only; needsReview has no studio caller); catalog
  item 1's stale-size fixture couldn't exercise the F1 gate (split into
  exact-length gating + separate clamp test); MV-1 must use ffmpeg-
  generated fixture footage, not a real user recording; commit range
  corrected to `d33d123..34754d7` (7 commits); store roots named
  (`~/Documents/SportcutRecordings|SportcutMatches`); "recorded" defined
  as a transcript at `docs/verification/import-progress.md`.
