# Release Validation — diary

## Interpretation
- 2026-09-29: "Re-run the full verification" is reconciled with the repo's
  testing posture by running the cheapest complete gate (`flutter analyze`) plus
  the focused regression test, and stating plainly that the full suite was not
  run.

## Tradeoff
- 2026-09-29: Recommended go-with-known-issues rather than a clean go, because
  two caveats (deferred ordering test, pending manual check) are real even though
  low-impact. Recording them is more honest than a bare go.

## Open question
- 2026-09-29: None. Human owns the release.
