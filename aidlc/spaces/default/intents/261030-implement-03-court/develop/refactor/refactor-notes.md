# Refactor Notes — Court Calibration (Feature 3)

Status: Develop / Refactoring
Intent: `261030-implement-03-court`
Date: 2026-10-30
Inputs: `code-review/review-record.md`, `code-generation/source-changes.md`.

## 1. Justification

The review found no blocking structural debt. Two candidates were considered:

| Candidate | Benefit | Decision |
| --- | --- | --- |
| Deduplicate the instruction copy | The host repeated the component's default sentence verbatim; one source is enough. | **Done** (see §2). |
| Unify the geometry validator (controller DTO vs design model) | One predicate instead of two. | **Rejected for now.** The two validators sit on opposite sides of the bridge/design boundary; merging them would couple the design layer to `CourtGeometryDto` (recorded as review finding F14). Revisit if a third consumer appears. |
| Split `ScCalibrationOverlay` into scrim/court/handles widgets | Smaller units. | **Rejected.** The scrim is already a separate widget; splitting the court and handles would scatter the shared box mapping for no current benefit. |

No refactor was justified beyond the deduplication: the change is small, the
review accepted the remaining shape, and a wider restructure would raise risk
without a named benefit.

## 2. What changed

- `calibration_overlay_host.dart` no longer passes `instruction`; the single
  sentence lives in `ScCalibrationOverlay`'s default. Behaviour is identical.

## 3. What stayed the same

- The widget/controller boundaries, the geometry guard, the paint order
  (band → court → handles), the scrim underlay, the transport accent flag, and
  every acceptance criterion.

## 4. Safety net

- `flutter analyze` → no issues.
- `flutter test test/calibration_controller_test.dart` → 12/12 passed.
- The full screenshot suite passed after the code-review fixes; the refactor
  changes no rendered output (same string), so no new visual evidence is
  required.

## 5. Outcome

One mechanical deduplication; no behaviour change. The remaining accepted debt
is recorded in the review record and the code-generation notes.
