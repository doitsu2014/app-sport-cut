# Deployment — Stage Diary

## Interpretation

- 2026-10-30: Read "deployment" for a local macOS app as the build/embed/verify
  runbook and rollback, not a server rollout. There is no environment to
  provision and no data migration.

## Tradeoff

- 2026-10-30: Documented the release-service `matchDir` rejection as a blocking
  limitation on packaged end-to-end verification rather than hiding it behind a
  green development run. The cost is an explicit "not ready for packaging"
  signal; the benefit is an honest release gate.

## Open question

- 2026-10-30: Whether release packaging can be unblocked before ADR-0001 Phase 3
  by making the client stop sending `matchDir` in release builds is a Phase 3
  decision, not this intent's.
