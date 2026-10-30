# API Contract — Court Calibration (Feature 3)

Status: Ideate / API Contract Design
Intent: `261030-implement-03-court`
Date: 2026-10-30
Inputs: `architecture-doc.md`, `requirements.md`.

## 1. Interfaces

| Interface | Kind | Changes in this intent |
| --- | --- | --- |
| `engine.court.geometry` (protocol v1) | Wire | None. Consumed as today. |
| `engine.calibration.save` (protocol v1) | Wire | None. Consumed as today. |
| `engine.calibration.get` (protocol v1) | Wire | None. Consumed as today. |
| `CalibrationController` | Internal Dart | No signature change; behaviour tightened (geometry-driven). |
| `CalibrationState` | Internal Dart | No field change; `geometry` is now rendered. |
| `ScCalibrationOverlay` | Internal widget contract | **Changed**: takes the engine geometry to paint. |
| `ScCourtHandle` | Internal widget contract | Unchanged constructor; semantics label enriched. |
| `CalibrationPanel` | Internal widget contract | Unchanged constructor; renders fewer children. |
| `ScTransport` (shared) | Internal widget contract | **Added** an optional neutral/accent-suppressing flag. |
| `SportcutTokens` / `ScMetrics` | Internal design API | **Added** `easeStandard`, hairline and border metrics; `overlayBed` corrected. |

The service protocol is unchanged: no method, framing, error code, or capability
change. The app still reaches the engine only through
`app/lib/src/bridge/sportcut_engine.dart`.

## 2. Wire contracts (unchanged, documented for traceability)

### 2.1 `engine.court.geometry`

- **Request:** `{ "segment": CalibrationSegmentDto }`
  where `CalibrationSegmentDto` carries `fromMs`, four `corners` with
  `{x, y}` in normalized image coordinates, and `orientation`
  (`"away"` | `"across"`).
- **Response:** `CourtGeometryDto`
  `{ imageToCourt: [9], courtToImage: [9], corners: [{x,y}]×4, net: [{x,y}]×2 }`,
  all coordinates normalized image space.
- **Errors:** invalid input (repeated corner, straight line, out-of-frame,
  reversed winding, near-zero area, net projecting outside the mapping). The
  message names the problem.
- **Idempotency:** pure; no write.
- **Auth:** the local service token handshake (unchanged).

Example:

```json
// request
{"segment":{"fromMs":0,
  "corners":[{"x":0.18,"y":0.22},{"x":0.82,"y":0.22},
             {"x":0.93,"y":0.88},{"x":0.07,"y":0.88}],
  "orientation":"away"}}
// response
{"imageToCourt":[1.34,0.0,-0.18, 0.0,2.11,-0.46, 0.0,0.0,1.0],
 "courtToImage":[...9 values...],
 "corners":[{"x":0.18,"y":0.22},{"x":0.82,"y":0.22},
            {"x":0.93,"y":0.88},{"x":0.07,"y":0.88}],
 "net":[{"x":0.5,"y":0.21},{"x":0.5,"y":0.89}]}
```

Error example:

```json
{"code":"invalid_input",
 "message":"court calibration: segment from 0ms: the corners cross (winding is not near-left, near-right, far-right, far-left)"}
```

### 2.2 `engine.calibration.save`

- **Request:** `{ matchId, matchDir, calibration: CourtCalibrationDto }`.
- **Response:** `CalibrationSaveDto` — the stored calibration plus the list of
  invalidated derived artifacts (`tracks`, …) when the court changed.
- **Side effects:** writes `calibration/calibration.json` (schema_version 1) and
  the manifest `Final` entry; the application writes the catalog row (unchanged
  one-step engine behaviour, documented in R-CAL-12).
- **Errors:** invalid geometry, save failure. The previous calibration is kept.

### 2.3 `engine.calibration.get`

- **Request:** `{ matchId, matchDir }`.
- **Response:** `CourtCalibrationDto | null`.
- **Note:** returns null when the artifact is absent; the client catalog is the
  source of truth for reopening (FR-CAL-22, current client-owned phase).

## 3. Internal Dart contracts

### 3.1 Geometry value model

```dart
/// Engine geometry, normalized to the displayed frame.
class ScCourtGeometry {
  const ScCourtGeometry({required this.outline, required this.net});
  final List<Offset> outline; // exactly 4, each in 0..1
  final List<Offset> net;     // exactly 2, each in 0..1
}
```

`CalibrationOverlayHost` converts `CourtGeometryDto.corners`/`.net` to
`ScCourtGeometry`, rejecting a payload unless it has four finite outline points
and two finite net points; it clamps each point to 0..1. `ScCalibrationOverlay`
re-validates the invariant (defence in depth) and paints nothing for an invalid
value model.

### 3.2 `ScCalibrationOverlay`

```dart
const ScCalibrationOverlay({
  required Size box,
  required List<Offset> corners,
  required int activeIndex,
  required ValueChanged<int> onSelect,
  required void Function(int, Offset) onDrag,
  ScCourtGeometry? geometry,          // new; null => no outline, no net
  String instruction = '...',         // one plain line, xs12+, names the net
});
```

- Paints bed/scrim, then outline, then dashed net, then handles, then the
  instruction, in that order.
- `geometry == null` paints no outline and no net.
- The net painter bounds its dash loop to `4 ×` the box diagonal.
- `Clip.none` is retained only because every painted point is clamped; a
  non-finite value is dropped before painting.

### 3.3 `ScCourtHandle` semantics

The label becomes `Corner <n>: <name>` where names are
`nearest left`, `nearest right`, `farthest right`, `farthest left`. The hint
stays `Drag to the court boundary`. Constructor unchanged.

### 3.4 `CalibrationPanel`

Constructor unchanged. Removed: the instruction `Text` and the
`_cornerHints` loop. Kept: orientation control, problem banner, progress line
(non-projected wording becomes a prompt), Save, Cancel.

### 3.5 Shared transport

`ScTransport` gains an optional `accent: bool = true` (or equivalent neutral
flag). When the calibrate stage is active, `VideoPreview` passes `accent: false`
so the play control, scrub fill, and thumb render neutral while remaining
functional (FR-CAL-24).

### 3.6 Design tokens and metrics

- `SportcutTokens.motion`: add `easeStandard = Cubic(0.2, 0.0, 0.0, 1.0)`.
- `ScMetrics`: add `hairline = 1` and `handleBorder = 2`; remove the raw
  constants from the overlay.
- `SportcutTokens.overlayBed` / `ScOverlayColors.bed`: `#050806` → `#0A0F0C`
  after a consumer scan; a calibration-local value if a consumer regresses.
- Add the scrim colour and opacity range (32-56 %) to the token layer.

## 4. Compatibility

- **Wire:** backward and forward compatible; nothing changes. This intent adds
  no capability requirement.
- **Dart:** the only breaking constructor change is `ScCalibrationOverlay`'s new
  optional parameter (source-compatible because it is optional). `ScTransport`
  gains an optional flag (source-compatible). No public package API is exported
  outside `app/`.
- **Data:** no schema change; `calibration.json` remains schema_version 1.
- **Breaking-change definition:** removing or renaming a protocol method,
  changing a request/response shape, or changing an error code. None occurs.

## 5. Failure and error model

| Condition | Surfaced as | Client behaviour |
| --- | --- | --- |
| Engine rejects geometry | `SportcutEngineException` message → panel danger banner | Geometry cleared; corners kept; no outline/net |
| Malformed `CourtGeometryDto` (count/finiteness/range) | Client guard | No outline/net; no throw; corners kept |
| Save fails | Exception message → banner | Previous court kept; Save re-enabled; corners kept |
| Service unreachable | Existing connection error path | Existing behaviour; no new handling |
| Emission out of box | Clamped before paint | Nothing escapes the box |

No new protocol error codes are introduced; the client keeps the engine's
message verbatim.
