# API Contract — Stage Diary

## Interpretation

- 2026-10-30: Read "API contract" for this intent as the internal Dart widget
  and value contracts plus the unchanged wire contract. The feature adds no
  protocol surface, so the wire section documents what is consumed rather than
  what changes.
- 2026-10-30: Introduced `ScCourtGeometry` as the validated view model rather
  than passing `CourtGeometryDto` into the design component, so the design layer
  does not depend on the bridge DTO.

## Tradeoff

- 2026-10-30: Kept the new `ScCalibrationOverlay.geometry` parameter optional so
  existing callers and tests stay source-compatible; the cost is that a caller
  can forget to pass it. The host is the single production caller and the spec
  names it.
- 2026-10-30: The geometry invariant is validated twice (host and component),
  a small duplication accepted as defence in depth per the security review.

## Open question

- 2026-10-30: `ScTransport`'s exact neutral flag name is left to implementation
  after reading its current API; the contract fixes the behaviour (accent
  suppressed, controls functional), not the identifier.
