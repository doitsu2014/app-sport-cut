# Code Generation Notes — Court Calibration (Feature 3)

Status: Develop / Code Generation
Intent: `261030-implement-03-court`
Date: 2026-10-30

## Approach followed

Implemented U1 → U2 → U3/U4/U6 → U5 → U7 → U8 in the planned order. U2 was the
walking skeleton: after it, the engine's outline and net were on screen and the
client derivation was gone. The visual units then tightened the surface, and
documentation was reconciled last against the implemented result.

## Key decisions during implementation

1. **`ScCourtGeometry` lives in the design component.** The host converts
   `CourtGeometryDto`; the painter stays transport-agnostic. This keeps the
   design layer free of bridge types and gives the guard a single invariant
   (`isValid`).
2. **Invalid payload means "no court".** The host returns null for wrong shape
   or out-of-frame points rather than clamping silently; the painter also clamps
   and rejects non-finite values. A wrong court is never drawn as a plausible
   one.
3. **Scrim at 52 %, below the transport.** 44 % (the palette's existing scrim)
   gives ≈2.8:1 for chalk over pure white footage, below the 3:1 floor; 52 %
   gives ≈3.7:1 and is inside the contract's 32-56 % range. The scrim is a
   separate widget in the stage's `underlay` slot so the transport keeps its
   own contrast; the instruction gets an opaque band because a 12 px line needs
   4.5:1.
4. **Cross-fade rather than endpoint tween.** `AnimatedSwitcher` keyed on
   `ScCourtGeometry` value equality animates appearance, replacement, and
   clearing at `motionBase` with `easeStandard`. Per-endpoint tweening would add
   a controller and interpolation state for a change that already reads clearly
   as a fade.
5. **Accent isolation as a boolean, not a theme.** `ScTransport.accent` is
   plumbed through `VideoPreview.transportAccent`; only the calibration branch
   turns it off. The score route keeps the accent.
6. **Semantics carry corner order.** Removing the inspector hints would lose the
   order affordance, so each handle's label became
   `Corner n: nearest left | nearest right | farthest right | farthest left`.
   The numbered handle still carries the order visually.

## Deviation log

| # | Deviation | Reason | Approved by |
| --- | --- | --- | --- |
| D1 | Updated one expectation in `app/test/screenshots/media_screens_test.dart` (`Marking the court…` → `Drag a handle to project the net.`) | Our copy change made the existing screenshot assertion fail. The test is not new coverage; it is kept aligned with the UI. | Recorded here for the gate; the working agreement allows touching a test when the change breaks it. |
| D2 | Calibration scrim is a separate `ScCalibrationScrim` widget passed through `VideoPreview.underlay`, not a layer inside `ScCalibrationOverlay` | The scrim must sit below the floating transport to preserve its contrast, while the markings stay above it. | Recorded here. |
| D3 | Court change animates as a cross-fade, not point-by-point interpolation | Satisfies the motion contract with less state; documented in DD-CAL-04/05 context. | Recorded here. |
| D4 | The stage bed stays `#050806`; the calibration scrim is a 52 % composite of it | ADR-0003 D16 binds the stage bed and supersedes the `#0A0F0C` wording in the earlier design/BRD text. The darker bed only improves contrast. | Recorded here. |
| D5 | The instruction sits on an opaque full-width band, not bare text on the scrim | Chalk on a 52 % scrim is ≈3.7:1, enough for graphics but below the 4.5:1 body-text floor for a 12 px line. The band is flat, not a pill or card. | Recorded here. |

## Review fixes applied in this stage

The first review pass returned changes-required. The confirmed findings were
fixed here rather than deferred:

- The scrim moved to `VideoPreview.underlay`, below the transport, so the
  timecodes and scrubber keep their contrast.
- The instruction sits on an opaque bed band (4.5:1), not bare text on the
  scrim.
- The handle accent is driven by a confirmed drag (`onPanStart`), not a bare
  pointer-down; a click no longer flashes the signal.
- The semantics name lookup is bounds-guarded.
- A malformed engine projection is rejected in the controller with a message, so
  `isProjected`, the panel, and the overlay share one gate.
- Keyboard activation no longer arms a drag or a spurious projection.
- The stage bed stays `#050806` per ADR-0003 D16; the unused scrim token was
  removed.
- The BRD transport note, evidence test name, contrast row, handle-colour
  wording, and status consistency were corrected.

The one accepted limitation is the pre-existing edge-clipped handle hit area
when a corner sits on the frame edge; it is recorded in BRD §7 as a follow-up.

## Verification actually run

- `cd app && flutter analyze` → **No issues found!**
- `tools/check-no-rust-in-app.sh` → **OK**.
- `flutter test test/calibration_controller_test.dart` → **12/12 passed**.
- `flutter test test/calibration_screen_test.dart` → 4 passed, 2 failed on the
  documented pre-existing `FilledButton` lookups (unchanged by this intent).
- `tools/capture-app-screenshots.sh` → **21/21 passed**, 40 PNGs; the
  calibration default and projected images were inspected.
- `git diff -- core` → empty.

The test suites were not run as a gate for ordinary work; the controller and
screen runs were used as targeted evidence for this feature's acceptance rows,
and the screenshot suite was the visual verification path.

## What was deliberately not done

- No engine change: `court_geometry` already returns the outline and net.
- No catalog/custody migration: ADR-0001 Phase 3-4 remains deferred.
- No repair of the two stale screen tests (needs a user request).
- No new dependency, permissions, entitlements, or telemetry.
- No `unsafe`, no Rust in the app.

## Follow-ups carried forward

1. Repair the two `FilledButton` screen-test lookups.
2. Add an automated design-conformance/golden test for handle size, dash, bed,
   and accent-on-drag.
3. Record real-footage accuracy against a labeled clip.
4. ADR-0001 Phase 3-4: service-owned catalog, `library.calibration.save/get`,
   and release-service match resolution.
