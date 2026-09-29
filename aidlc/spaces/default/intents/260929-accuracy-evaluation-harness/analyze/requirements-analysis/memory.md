# Requirements Analysis — diary

## Interpretation
- 2026-09-29: `core/AGENTS.md` "no tests unless asked" — the accuracy-harness request is read as asking for scorer tests only (C-4).

## Tradeoff
- 2026-09-29: Player count scored per recording (engine's granularity), not per frame; cheaper and matches the Phase 0 criterion, loses temporal detail.
- 2026-09-29: Separate `sportcut-eval` crate over putting scoring in `rally`; one more crate, but vision + rally scoring stays out of production crates.
