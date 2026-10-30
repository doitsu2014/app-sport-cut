# Task Planning — Stage Diary

## Interpretation

- 2026-10-30: Split the visual work (U4 bed/scrim, U6 motion) from the rendering
  skeleton (U2). They share a file, but separating the acceptance criteria keeps
  the review honest: U2 proves correctness, U4/U6 prove conformance.
- 2026-10-30: Kept U5 (transport accent) independent after U1 so it can run in
  parallel with the overlay work without touching the same files.

## Tradeoff

- 2026-10-30: Eight small units instead of three larger ones. More commit
  overhead, but each unit is independently reviewable and the walking skeleton
  is clearly isolated.

## Open question

- 2026-10-30: None blocking. The `overlayBed` consumer scan and the box
  alignment check remain the two implementation-time unknowns, both placed in
  the first two units.
