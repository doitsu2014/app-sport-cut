# Source Changes — Court Calibration (Feature 3)

Status: Develop / Code Generation
Intent: `261030-implement-03-court`
Date: 2026-10-30

## Summary

15 files changed: eleven client files, one screenshot-test expectation, and
three documentation files. No Rust, no protocol method, no persistence, and no
dependency changed. `git diff -- core` is empty.

## Units as implemented

### U1 — Tokens and metrics

- `app/lib/src/app/design/sportcut_tokens.dart`: added
  `easeStandard = Cubic(0.2, 0.0, 0.0, 1.0)`. The overlay bed is **not**
  changed: ADR-0003 D16 fixes it at `#050806` and supersedes the `#0A0F0C`
  wording in the earlier design/BRD text.
- `app/lib/src/app/design/sc_overlay_colors.dart`: `bed` stays `#050806`; added
  `calibrationScrim` at 52 % (inside the contract's 32-56 % range).
- `app/lib/src/app/design/sc_metrics.dart`: added `handleBorder = 2`,
  `courtOutline = 2`, `hairline = 1`.
- Consumer scan: the bed is read by the transport, score bug, overlay bed,
  studio barrier, player view, tracking overlay, and export renderer, some
  opaquely. Because ADR-0003 D16 binds the value, no consumer changes; the
  calibration scrim is a local 52 % composite of the same bed.

### U2 — Geometry-driven outline and net (walking skeleton)

- `app/lib/src/app/design/components/sc_calibration_overlay.dart`:
  - Added `ScCourtGeometry` (4 outline points + 2 net points, all finite and in
    0..1; value equality via `listEquals`).
  - `ScCalibrationOverlay` takes `geometry`; paints a new `_CourtPainter` that
    draws the closed outline and the dashed net from the engine payload.
  - Deleted `_netEndpoints` and `_NetPainter`; no client-side geometry remains.
  - `geometry == null` or invalid paints no outline/net.
  - `_CourtPainter` clamps points, rejects non-finite values, and bounds the dash
    loop at `4 × size.longestSide` (security S-1/S-2).
- `app/lib/src/features/calibration/presentation/calibration_overlay_host.dart`:
  added `_geometry(CourtGeometryDto?)`, which converts the DTO and returns null
  unless the payload is valid; passes it and the new instruction copy.
- `app/lib/src/features/calibration/presentation/calibration_controller.dart`:
  `_isDrawable` rejects a malformed payload (shape, non-finite, grossly
  out-of-frame) with a problem message, so `isProjected`, the panel, and the
  overlay share one gate. A tiny edge overshoot (e.g. `1.0000000000000002`) is
  accepted and clamped at the draw boundary.

### U3 — One plain instruction line

- Overlay: the filled pill, border, icon, and `micro10` style are gone; a plain
  `xs12` chalk line names the projected net.
- `calibration_panel.dart`: removed the duplicate instruction paragraph and
  `_cornerHints`; the non-projected progress copy is now
  `Drag a handle to project the net.`
- `ScCourtHandle`: semantics label is `Corner n: <name>` using the four contract
  names; the 24/44 metrics and Enter/Space activation are unchanged.

### U4 — Bed, scrim, and contrast

- `ScCalibrationScrim` is a separate widget painted through the stage's new
  `underlay` slot, **below** the floating transport, so the transport's
  timecodes and scrubber keep their contrast. The overlay paints the markings
  above it.
- The instruction sits on a flat, full-width opaque `#050806` band (not a pill
  or card), so the 12 px line keeps body-text contrast over any footage.
- Markings use chalk `#F2F5F0`.
- Contrast calculation (sRGB, alpha-composited over pure white footage):
  `0.52 × #050806 + 0.48 × #FFFFFF` ≈ `#7E807E` (linear luminance ≈ 0.21);
  chalk (≈ 0.90) gives ≈ 3.7:1, above the 3:1 essential-graphics floor. At the
  44 % system scrim the same computation gives ≈ 2.8:1, which is why the
  calibration surface uses 52 %. The 12 px instruction is not an essential
  graphic: on the opaque band it measures ≈ 18:1. Text pairs were already
  ≥ 4.5:1.

### U5 — Accent isolation

- `sc_transport.dart`: added `accent` (default true); the play control and the
  scrub fill/thumb render neutral when false, while staying enabled.
- `video_preview.dart`: added `transportAccent` (default true) and threaded it
  through `_StageFrame`, `_StageOverlay`, and `_StageTransport`.
- `preview_pane.dart` and the legacy `calibration_view.dart` pass false for the
  calibrate surface.

### U6 — Motion

- Handle fill/border: `AnimatedContainer` at `motionFast` with `easeStandard`.
- Court appearance/replacement/rejection: `AnimatedSwitcher` at `motionBase`
  with `easeStandard`; `ScMotion.duration` collapses it to zero under reduced
  motion. Nothing loops.

### U7 — Documentation

- `docs/brd/03-court-calibration.md`: §1 status, §2.3 rewritten to HEAD, §4
  Cancellation describes the Cancel control, §5 implementation/status cells
  updated, §7 evidence corrected (stale tests, absent record, counts), §10
  traceability updated.
- `docs/brd/00-product-context.md` §3.3 row 3 rewritten.
- `docs/architecture/protocol.md`: `engine.calibration.save` one-step behaviour,
  §8.3 composite wording, and the token-shaped example replaced with
  `<per-launch-token>`.

### U8 — Verification

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `cd app && flutter analyze` | No issues found |
| No-Rust guard | `tools/check-no-rust-in-app.sh` | OK |
| Controller tests | `flutter test test/calibration_controller_test.dart` | 12/12 passed |
| Screen tests | `flutter test test/calibration_screen_test.dart` | 4 pass, 2 pre-existing failures (`FilledButton` lookups) |
| Screenshot suite | `tools/capture-app-screenshots.sh` | 21/21 passed, 40 PNGs |
| Visual check | `calibration_default.png`, `calibration_projected.png` | No net before projection; engine outline + dashed net after; plain instruction; neutral transport |
| Rust diff | `git diff -- core` | Empty |

## Deviations

1. `app/test/screenshots/media_screens_test.dart:134` asserted the old
   supporting copy `Marking the court…`. The intent replaced that copy with
   `Drag a handle to project the net.`, so the single expectation was updated to
   keep the existing screenshot suite green. No new test case was added.
2. `ScCalibrationScrim` is a separate widget rather than a layer inside
   `ScCalibrationOverlay`, because the stage must place the scrim below the
   transport while keeping the markings above it. Both production call sites
   pass it through `VideoPreview.underlay`.
3. The `AnimatedSwitcher` cross-fades the whole court on geometry change rather
   than interpolating endpoints point by point. This satisfies "explain the
   change at 180 ms with the standard curve" without adding a per-frame tween
   state machine; it is recorded as an implementation choice.

## Unchanged, by design

- No engine or protocol change; no new dependency; no new durable state; no
  network. The geometry source, validation, and net derivation stay in
  `sportcut-court`.
- The two stale screen-test lookups remain; repairing them needs an explicit
  user request under `CLAUDE.md`.
- The release-service `matchDir` limitation and the ADR-0001 Phase 3-4 catalog
  migration remain deferred and recorded.
