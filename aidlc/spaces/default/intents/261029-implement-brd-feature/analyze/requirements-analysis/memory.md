# Requirements Analysis — Stage Diary

## Interpretation

- 2026-10-29: Counted FR-LIB-15 as Superseded, not a Gap. ADR-0003 D8 names the
  missing recording honestly and deliberately offers no relocate action; the
  BRD row predates that decision.
- 2026-10-29: Counted FR-LIB-19 as Superseded. ADR-0003 D2/D14 removed the
  persistent pipeline rail, so the "rail header" the criterion names no longer
  exists; the stage strip carries per-stage state instead.
- 2026-10-29: Kept FR-LIB-25 and FR-LIB-30 as Deferred rather than Satisfied.
  The client copy works, but the requirement's acceptance text names the
  service-owned v6 catalog; the Q2 answer defers that.

## Deviation

- 2026-10-29: Audited against HEAD `c8beacf` and the ADRs, not against the BRD
  §2.3 status table. The table's baseline is `1541c64`, which predates the
  studio refactor; trusting it would have re-implemented shipped behavior.

## Tradeoff

- 2026-10-29: Limited the implementation set to four gaps (G1–G4) and left the
  stale tests untouched. Cost: the test suite still references the removed
  "No matches yet" screen. Accepted under the project working agreement.

## Open question

- 2026-10-29: Q-8 (rename/reorder, cross-workspace library) is still undecided.
  This intent treats both as out of scope, matching BRD-01 §2.2.
