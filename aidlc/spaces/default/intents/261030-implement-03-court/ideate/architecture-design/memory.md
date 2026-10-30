# Architecture Design — Stage Diary

## Interpretation

- 2026-10-30: Treated the feature as a presentation change, not a storage or
  transport change. The service already returns the outline and net; the
  architecture question was where to draw them, not how to compute them.
- 2026-10-30: Read the design contract's "no floating chrome" as aimed at cards,
  chips, and tooltips over the action area, not at the single instruction line
  the same section requires. The pill is the defect, not the text.

## Tradeoff

- 2026-10-30: Chose to paint the bed/scrim inside `ScCalibrationOverlay` rather
  than the studio preview pane. The cost is that only the calibration surface
  gets the bed; the benefit is that every stage does not inherit a dimming layer
  it was not designed for.
- 2026-10-30: Limited the standard-curve change to calibration and named shared
  transitions instead of the whole app, trading visual consistency for a smaller
  regression surface.

## Deviation

- 2026-10-30: The architecture doc's security section was written before the
  reviewer returned and is completed from its findings; this keeps the gate
  evidence in one place without pre-empting the review.
- 2026-10-30: The security reviewer's S-3 finding corrected the draft's claim
  that no new input crosses a boundary. The overlay now consumes engine-returned
  geometry, so §7 names that flow and the client-side validation requirement
  (S-1/S-2). The correction is folded into §3.1, §6, §7, and R-CAL-01/02 rather
  than left as review commentary.

## Open question

- 2026-10-30: The shared `overlayBed` consumer scan is pending; the choice
  between correcting the token and adding a local one is deferred to
  implementation, with the deviation rule recorded.
