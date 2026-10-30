# Code Generation — Stage Diary

## Interpretation

- 2026-10-30: Treated the engine payload as the single source of truth and
  deleted the client derivation rather than keeping it as a fallback. The
  fallback was the defect, not a safety net.
- 2026-10-30: Read "32-56 % scrim" as a calibration-surface scrim over the
  footage, not an opaque bed that would hide the frame; the fixed bed colour
  and the scrim compose in one overlay layer.

## Deviation

- 2026-10-30: Updated one expectation in the screenshot suite because the
  intent changed the supporting copy; no case was added. Recorded as D1.
- 2026-10-30: Used a calibration-specific scrim getter (52 %) instead of the
  new token (44 %) because the static overlay palette cannot read a theme
  extension; 52 % is the value that holds 3:1 over white footage. Recorded as
  D2.
- 2026-10-30: The court change is a 180 ms cross-fade, not endpoint
  interpolation. Recorded as D3.

## Tradeoff

- 2026-10-30: Correcting the shared `overlayBed`/`ScOverlayColors.bed` to
  `#0A0F0C` shifts seven other surfaces by a near-black step. The consumer scan
  found no exact-value dependency; the change keeps one bed colour across the
  system instead of adding a second near-black.

## Open question

- 2026-10-30: Whether a real recording's painted lines align with the drawn
  outline at other camera angles is still unmeasured; the synthetic fixtures
  prove the pipeline, not the calibration accuracy (S7-18).
