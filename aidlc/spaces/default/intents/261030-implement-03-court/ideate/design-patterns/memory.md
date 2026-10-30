# Design Pattern Selection — Stage Diary

## Interpretation

- 2026-10-30: Treated the geometry value model as a presentation boundary, not
  a domain entity: the engine owns geometry, the host validates the payload, and
  the design component paints. This is why `ScCourtGeometry` sits at the host,
  not in the domain folder.

## Tradeoff

- 2026-10-30: Chose duplicate validation (host + painter) over a single guard,
  trading a few lines for defence in depth after the security review's S-1.

## Open question

- 2026-10-30: Whether the shared `overlayBed` correction is safe is a consumer
  question, not a pattern question; it remains the implementation's check.
