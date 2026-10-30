# Code Review — Stage Diary

## Interpretation

- 2026-10-30: Ran two independent adversarial passes rather than one: the first
  judged the change, the second judged the fixes. A fix can introduce its own
  defect, so the second pass had to look at the same surface again.
- 2026-10-30: Treated the first pass's changes-required verdict as binding. The
  three majors (transport dimming, instruction contrast, accent on click) were
  real contract regressions, not preferences.

## Deviation

- 2026-10-30: The review changed the implementation (scrim moved to an underlay,
  opaque instruction band, drag-gated accent, ADR bed reverted). This is the
  expected fix loop, not scope creep; each change traces to a confirmed finding.
- 2026-10-30: Updated DESIGN.md §2 and BRD 00 DS-1 to the ADR-0003 D16 bed value
  so the design contract and the binding ADR agree. This is a documentation
  correction, not a design change.

## Tradeoff

- 2026-10-30: Accepted the duplicated geometry predicate between the controller
  and the design value model rather than coupling the design layer to the bridge
  DTO. The cost is two validators that must agree; the benefit is a clean layer
  boundary, and the host reuses the design one.
- 2026-10-30: Accepted the pre-existing edge-clipped hit area instead of
  refactoring handle geometry; it is recorded as a follow-up with a BRD note.

## Open question

- 2026-10-30: Whether a golden-image assertion for the calibration overlay is
  worth the maintenance cost is unresolved; the screenshot suite captures the
  two states today but compares nothing.
