# Technical Specification — Court Calibration (Feature 3)

Status: Ideate / Technical Specification
Intent: `261030-implement-03-court`
Date: 2026-10-30
Inputs: `architecture-doc.md`, `design-decisions.md`, `api-contract.md`,
`requirements.md`.

## 1. Requirement → component → verification

| Requirement | Component(s) | Interface | Verification |
| --- | --- | --- | --- |
| R-CAL-01 outline | `ScCalibrationOverlay` (`_CourtOutlinePainter`), host | `geometry.outline` | source; manual |
| R-CAL-02 net + orientation | `ScCalibrationOverlay` (`_NetPainter`), host | `geometry.net` | source; manual |
| R-CAL-03 no net before projection | `ScCalibrationOverlay`, `CalibrationPanel` | `geometry == null` | source; manual |
| R-CAL-04 clear on rejection | `ScCalibrationOverlay`, controller | `geometry == null` after catch | source; manual |
| R-CAL-05 one instruction line | overlay + panel + handle semantics | `instruction` string; panel children | source; manual |
| R-CAL-06 bed/scrim/contrast | overlay, `SportcutTokens` | `overlayBed`, scrim tokens | source; manual calculation |
| R-CAL-07 accent isolation | `ScTransport`, `VideoPreview`, `PreviewPane`, legacy view | `accent` flag | source; manual |
| R-CAL-08 ease + metrics | `SportcutTokens`, `ScMetrics`, `ScMotion` | `easeStandard`, `hairline`, `handleBorder` | source; analyze |
| R-CAL-09 motion | overlay, `ScMotion` | `ScMotion.duration` + curve | source; manual |
| R-CAL-10 Cancel doc | BRD §4 | — | source |
| R-CAL-11 BRD reconciliation | BRD 03, BRD 00 | — | source; diff review |
| R-CAL-12 protocol docs | `protocol.md`, BRD §8 refs | — | source |
| NR-CAL-01…06 | — | — | analyze, guard, source |

## 2. Component specifications

### 2.1 `ScCalibrationOverlay` — `app/lib/src/app/design/components/sc_calibration_overlay.dart`

- **Responsibility.** Paint the fixed bed and scrim, the engine outline, the
  engine net, four handles, and one instruction line over the aspect-fit box.
- **Inputs.** `box`, `corners`, `activeIndex`, `onSelect`, `onDrag`,
  `ScCourtGeometry? geometry`, `String instruction`.
- **New types.**
  ```dart
  class ScCourtGeometry {
    const ScCourtGeometry({required this.outline, required this.net});
    final List<Offset> outline; // 4 normalized points
    final List<Offset> net;     // 2 normalized points
    bool get isValid => outline.length == 4 && net.length == 2 &&
        outline.every(_finite01) && net.every(_finite01);
  }
  ```
- **State.** None at the component level (props only). Handles keep their own
  pressed/hovered/focused state.
- **Paint order.** Bed → scrim → outline (`CustomPaint` with a closed polygon,
  chalk stroke) → dashed net (chalk, existing dash geometry) → handles →
  instruction.
- **Guard.** If `geometry == null` or `!geometry.isValid`, paint no outline and
  no net. Drop non-finite points. `_NetPainter` clamps its endpoints and caps
  the dash loop at `4 * box.longestSide` logical pixels of travel.
- **Instruction.** A plain `Text` (no `DecoratedBox`, no border) positioned at
  `space2` from the top, `xs12` or larger, `palette`-safe on the fixed bed, one
  line. Copy: `Drag a handle; the dashed line is the net the engine projects.`
- **Animation.** Handle fill/border and net opacity changes run
  `ScMotion.duration(context, tokens.motionFast)` with
  `SportcutTokens.easeStandard`; when reduced motion is on, duration is zero.
- **Errors.** Never throws for bad geometry; renders nothing.
- **Dependencies.** `SportcutPalette`, `SportcutTokens`, `SportcutTypography`,
  `ScMetrics`, `ScMotion`, `ScIcons`.

### 2.2 `CalibrationOverlayHost` — `app/lib/src/features/calibration/presentation/calibration_overlay_host.dart`

- **Responsibility.** Own interaction state and translate `CourtGeometryDto`
  into `ScCourtGeometry`.
- **Inputs.** `MatchRecord match`.
- **Outputs.** `ScCalibrationOverlay` with geometry and the single instruction.
- **Conversion.**
  ```dart
  ScCourtGeometry? _geometry(CourtGeometryDto? dto) {
    if (dto == null) return null;
    final outline = [for (final c in dto.corners) Offset(c.x, c.y)];
    final net = [for (final c in dto.net) Offset(c.x, c.y)];
    final geometry = ScCourtGeometry(outline: outline, net: net);
    return geometry.isValid ? geometry : null;
  }
  ```
  The host does not clamp silently before validity: an invalid payload yields
  null. (Clamping for valid-but-slightly-out values happens in the painter.)
- **State.** `_activeIndex`, `_dragging` (unchanged). Drag uses controller state
  for the corner offset; release requests one projection.

### 2.3 `CalibrationPanel` — `app/lib/src/features/calibration/presentation/calibration_panel.dart`

- **Responsibility.** Inspector controls: orientation, Save, Cancel, problem
  banner, supporting line.
- **Removed.** The instruction paragraph (`:112-116`) and `_cornerHints`
  (`:19-24`, `:125-132`).
- **Progress line.**
  - not complete → `Place all four corners to see the projected net.`
  - complete, not projected → `Drag a handle to project the net.`
  - projected → `The dashed line is the net the engine projects from your corners.`
- **State.** Unchanged (reads the controller).
- **Errors.** Problem banner unchanged.

### 2.4 `ScCourtHandle`

- Add `label`/`hint` semantics: `Corner 1: nearest left` … `Corner 4: farthest
  left`, hint `Drag to the court boundary`.
- Keep 24 px visual / 44 px hit (`ScMetrics.courtHandleVisual/Hit`).
- Accent fill only while a confirmed drag is under way (`onPanStart` to
  `onPanEnd`/`onPanCancel`); use `easeStandard` at
  `motionFast` for the fill/border change, collapsed by `ScMotion`.
- Border width reads `ScMetrics.handleBorder`.

### 2.5 `ScTransport` and its call sites

- **`sc_transport.dart`.** Add `final bool accent;` (default `true`) to the
  constructor. Pass it to the play `_StageIconButton` and to `_Scrubber`; when
  false, the play button renders neutral (ink background, no signal fill) and
  the scrub fill/thumb use ink/muted rather than signal. All controls stay
  enabled.
- **`video_preview.dart`.** Add `final bool transportAccent;` (default true) to
  `VideoPreview` and `_StageShell`; pass it to `_StageTransport` → `ScTransport`.
- **`preview_pane.dart`.** Pass `transportAccent: stage != PipelineStage.calibrate`
  (or the equivalent stage comparison) at the calibration branch (`:105-109`).
- **`calibration_view.dart`.** The legacy route passes `transportAccent: false`.

### 2.6 Tokens and metrics

> **Amended in code generation:** ADR-0003 D16 binds the stage bed at
> `#050806` and supersedes the earlier `#0A0F0C` wording. The shared
> `overlayBed`/`ScOverlayColors.bed` values are therefore unchanged, and the
> calibration scrim is a local 52 % composite of that bed.

- **`sportcut_tokens.dart`.**
  - `overlayBed`: `Color(0xFF050806)` → `Color(0xFF0A0F0C)` in `light` (and so
    `dark`).
  - Add `static const Cubic easeStandard = Cubic(0.2, 0.0, 0.0, 1.0);` and
    include it in the extension surface (a plain static on `SportcutTokens` is
    acceptable because it is theme-invariant, matching `ScMetrics`' style).
  - Add `scrimMin = 0.32`, `scrimMax = 0.56` (or a single scrim colour/alpha
    pair) for the overlay.
- **`sc_metrics.dart`.** Add `hairline = 1` and `handleBorder = 2` doc'd as
  design-contract dimensions.
- **`sc_overlay_colors.dart`.** `bed` `#050806` → `#0A0F0C`; keep `ink`
  `#F2F5F0`.
- **Consumer scan.** Before changing `overlayBed`, grep `overlayBed` and
  `ScOverlayColors.bed`; if a consumer's appearance depends on `#050806`, use a
  calibration-local `_calibrationBed` constant and record the deviation in the
  code-generation notes.

## 3. Cross-cutting concerns

### 3.1 Security

- Geometry is untrusted data from the local service: validate counts,
  finiteness, and 0..1 range before painting; bound the dash loop. No new
  network, path, credential, or deserialization surface (see `security-review.md`,
  S-1/S-2/S-3).
- `protocol.md`'s example token becomes `<per-launch-token>` (S-4).

### 3.2 Performance

- Drag updates local state only; the engine is called once on release
  (NFR-CAL-01, already true).
- Painting is four points, two endpoints, four handles, and one text line per
  frame; no layout thrash. Animation is 120/180 ms and stops.
- The dash loop is bounded so no payload can stall the UI thread.

### 3.3 Accessibility and motion

- Handles keep a 44 px hit target and keyboard activation (Enter/Space) and gain
  descriptive semantics labels.
- Contrast: text pairs are already 4.5:1+; essential graphics get the fixed bed,
  scrim, and chalk, with the calculation recorded.
- Reduced motion collapses all new transitions to zero via `ScMotion`.

### 3.4 Observability and data lifecycle

- No new logging, no telemetry, no new persisted data. The feature stays
  offline. The only writes are the existing artifact and catalog row on Save.

## 4. Work breakdown seeds (dependency order)

| Unit | Scope | Depends on |
| --- | --- | --- |
| U1 | Tokens/metrics: `easeStandard`, `overlayBed` correction + consumer scan, `hairline`/`handleBorder`, scrim values | — |
| U2 | `ScCourtGeometry` + geometry-driven outline/net painting + guard + bounded dash + bed/scrim + plain instruction + motion in `ScCalibrationOverlay` | U1 |
| U3 | Host conversion and single instruction copy; pass geometry | U2 |
| U4 | Panel cleanup and progress copy | U2 |
| U5 | `ScTransport.accent` + `VideoPreview.transportAccent` + `PreviewPane`/legacy wiring | U1 |
| U6 | Documentation reconciliation: BRD 03, BRD 00 §3.3, `protocol.md` (save claim, cross-refs, token example) | U1-U5 |
| U7 | Verification: `flutter analyze`, `tools/check-no-rust-in-app.sh`, manual run, contrast calculation | U1-U6 |

Develop refines these; the order above is the intended dependency chain. U2 and
U5 are independent after U1 and may proceed in parallel.
