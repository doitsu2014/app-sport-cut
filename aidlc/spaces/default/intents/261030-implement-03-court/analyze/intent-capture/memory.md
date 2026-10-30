# Intent Capture — Stage Diary

## Interpretation

- 2026-10-30: Selected BRD feature 3 (`03-court-calibration.md`, area `CAL`) as
  the next intent after feature 2 (`02-import-and-media-preparation.md`)
  completed and merged in PR #7. Feature order follows the product BRD's
  feature catalog.
- 2026-10-30: Read the BRD's "Done at baseline / Partial on design" claim as a
  hypothesis, not evidence. A 62-row HEAD audit (five independent dimensions,
  each adversarially re-verified) replaced it with the actual state: functional
  core mostly satisfied, one central functional defect (the engine's geometry is
  never rendered), and a design-gap list that is partly stale.
- 2026-10-30: Scoped the intent to the client-renderable gaps plus documentation
  reconciliation. The audit's verdict that every implementable gap is
  client-track / design / docs work is the basis for excluding engine changes.

## Tradeoff

- 2026-10-30: Kept the client-owned v5 catalog and the current artifact
  transport rather than coupling this feature intent to ADR-0001 Phase 3-4
  service custody, matching features 1 and 2.
- 2026-10-30: Left the release-service `matchDir` rejection as a recorded
  migration limitation instead of widening this intent into custody work. The
  cost is that calibration remains development-transport-only until Phase 3/6.

## Open question

- 2026-10-30: `STATE:Cancellation` is a documentation disagreement, not a code
  defect: the BRD says no cancel action exists, but `CalibrationPanel` renders a
  Cancel control that leaves with the unsaved session parked. The intent
  resolves it by documenting the real control; the alternative (removing Cancel)
  is a product decision and remains open.
- 2026-10-30: The two screen tests that look up `FilledButton` throw at HEAD and
  are not caused by this change. They stay untouched under the `CLAUDE.md`
  working agreement; repairing them needs an explicit user request.
