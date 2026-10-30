# Technical Specification — Stage Diary

## Interpretation

- 2026-10-29: Put `shortStageLabel` in the domain file rather than exporting a
  presentation map, so the stage strip and the status bar share one vocabulary
  without depending on each other.

## Tradeoff

- 2026-10-29: The status-bar label uses the short vocabulary ("Score"), not the
  full stage label ("Review & score"), to fit 30 px at 200% text scale. The full
  name remains in the stage strip's accessible name.

## Open question

- 2026-10-29: Whether `ScProgressJob` renders acceptably in the home's centred
  card at 200% scale is unverified; it is the same component the studio uses.
