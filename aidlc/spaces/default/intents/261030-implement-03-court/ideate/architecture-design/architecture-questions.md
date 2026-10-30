# Architecture Questions

Intent: `261030-implement-03-court`
Mode: yolo (`aidlc/config.json`) — recommended answers auto-selected and
recorded below.

## Q1: Where does geometry rendering live?

A. Inside `ScCalibrationOverlay`: add an optional `CourtGeometryDto` (or a
   small view model) and paint the outline and net there, next to the handles.
B. A separate painter layer in `CalibrationOverlayHost`, stacked over
   `ScCalibrationOverlay`.
C. In `CalibrationController`, which would compute box coordinates and expose
   ready-to-paint points.
X. Other (describe)

[Answer]: A. Inside `ScCalibrationOverlay`. The component already owns the box
mapping, the handles, the instruction, and the net painter; a second layer would
duplicate the box and risk drift.

## Q2: Where does the fixed bed/scrim live?

A. In `ScCalibrationOverlay` beneath the net and handles, using the corrected
   shared `overlayBed`/`ScOverlayColors.bed` token (`#0A0F0C`).
B. In the studio's preview pane, so every stage gets the bed.
C. A calibration-local constant, leaving the shared token at `#050806`.
X. Other (describe)

[Answer]: A. In the overlay, with the shared token corrected after a consumer
scan. The contract names one bed; keeping it in the component keeps the marking
surface self-contained.

## Q3: How is the transport's accent isolated during calibration?

A. Suppress the transport's accent (play button, scrub fill/thumb) while
   `PipelineStage.calibrate` is active, leaving its controls functional but
   neutral.
B. Hide the transport while the calibrate stage is active.
C. Retint the transport into the calibration surface's neutral palette.
X. Other (describe)

[Answer]: A. Suppress the accent, keep the controls. FR-CAL-24 requires play and
seek to remain available.

## Q4: What is the scope of the motion/ease change?

A. Apply `easeStandard` to the calibration handle/net changes and to the named
   shared transitions the design contract already calls standard; leave other
   controls on their current curve.
B. Apply `easeStandard` to every animation in the app.
C. Animate only the calibration overlay and add no shared token.
X. Other (describe)

[Answer]: A. Calibration plus the named shared transitions; a global curve
change would exceed this intent and risk unrelated regressions.

## Contradiction analysis

- Q1-A versus Q2-A: consistent. Both keep the marking surface inside
  `ScCalibrationOverlay`, so the bed, outline, net, and handles share one box.
- Q1-A versus Q3-A: consistent. The transport is outside the overlay; the host
  can pass a neutral flag without moving rendering responsibility.
- Q2-A versus the constraint register C-06: consistent. Correcting the shared
  token to `#0A0F0C` is the contract value; the consumer scan is the guard.
- Q4-A versus C-07: consistent. The standard curve is applied where the design
  contract names it, not globally.
- No open contradictions.
