# Feasibility Assessment — Court Calibration (Feature 3)

Status: Analyze / Feasibility Assessment
Intent: `261030-implement-03-court`
Date: 2026-10-30
Inputs: `intent-statement.md`, `requirements.md` (R-CAL-01…12, NR-CAL-01…06).

## 1. Technical feasibility by requirement

| Requirement | Feasibility | Basis and unknowns |
| --- | --- | --- |
| R-CAL-01 Render engine outline | High | The engine already returns `CourtGeometryDto.corners` (`dto.rs:528-544`); the overlay is a `CustomPaint`/`Stack` that already maps normalized points into its box. Passing geometry and adding one `_OutlinePainter` is mechanical. No unknown. |
| R-CAL-02 Engine net + orientation | High | `.net` is returned in the same normalized space (`court/src/lib.rs:260-270`); `_NetPainter` already draws a dashed segment — only its endpoints change and `_netEndpoints` is deleted. Orientation re-projection already fires (`calibration_controller.dart:157-163`). |
| R-CAL-03 No net before projection | High | `CalibrationState.geometry` is already null until `project()`/`open()` returns; the overlay simply paints from geometry and nothing when null. Supporting copy is a string change. |
| R-CAL-04 Clear on rejection | High | `clearGeometry` already sets geometry null (`calibration_controller.dart:177-183`); once painting is geometry-driven the clearing is automatic. |
| R-CAL-05 One plain instruction line | High | Removing the panel paragraph/hints and the overlay pill is a widget removal; the sentence stays a `Text` at `xs12` or larger. Corner order moves into the existing `Semantics` label. |
| R-CAL-06 Bed, scrim, contrast | Medium | The scrim/bed values must be applied over arbitrary footage and contrast-checked. The only real unknown is whether correcting the shared `overlayBed` token (`#050806` → `#0A0F0C`) regresses another surface; a consumer scan settles it. |
| R-CAL-07 Accent isolation | Medium | The shared transport's accent is driven by its own props; the calibration surface must suppress or de-accent it during the calibrate stage. The mechanism depends on `ScTransport`'s current API, which is small and local. |
| R-CAL-08 Ease token + metrics | High | Add one `Cubic` constant and move two doubles into `ScMetrics`; both token and metrics layers exist. |
| R-CAL-09 Motion + reduced motion | Medium | Reduced-motion collapse already exists in the export sheet's transitions; the pattern can be reused. Risk is scope creep into unrelated shared controls if the curve changes globally; limit the curve change to the calibration and shared transitions named in the design contract. |
| R-CAL-10 Document Cancel | High | Documentation only; the control and its wiring exist (`calibration_panel.dart:171-177`, `inspector_pane.dart:324`). |
| R-CAL-11 BRD reconciliation | High | The audit ledger supplies exact HEAD evidence; the work is editing status/evidence tables. |
| R-CAL-12 Protocol doc correction | High | Two paragraphs and two cross-references; the implemented behaviour is already verified. |
| NR-CAL-01…06 | High | No engine, dependency, network, FFI, persistence, or test-suite work is required. `flutter analyze` and the no-Rust guard are existing entry points. |

No requirement needs a research spike or a new library. The only medium items
are visual (bed/scrim/contrast, accent isolation, motion) and are verified by
running the app, which is the supported `tools/run-macos.sh` path.

## 2. Cost, schedule, and effort

| Area | Ballpark |
| --- | --- |
| Geometry-driven rendering (R-CAL-01…04) | 0.5-1 day |
| Instruction surface (R-CAL-05) | 0.25 day |
| Bed/scrim/contrast + accent isolation (R-CAL-06, R-CAL-07) | 0.5 day |
| Tokens + motion (R-CAL-08, R-CAL-09) | 0.25-0.5 day |
| Documentation reconciliation (R-CAL-10…12) | 0.25-0.5 day |
| Verification (analyze, guard, manual run) | 0.25 day |
| **Total** | **~2-3 developer-days**, one client-track engineer |

Cost is internal effort only: no licence purchase, no infrastructure, no cloud
spend. Schedule is one short iteration; no external dependency gates the work.

## 3. Risks

| ID | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| FR-01 | Correcting the shared `overlayBed` token regresses another surface | Medium | Low | Scan consumers first; if one depends on `#050806`, use a calibration-local token and record the deviation. |
| FR-02 | Contrast still fails over bright footage even with the bed/scrim | Medium | Medium | Use chalk `#F2F5F0` for essential lines and record the ratio calculation; the scrim range permits tuning. |
| FR-03 | Changing the shared ease curve alters unrelated transitions | Low | Medium | Use the standard curve only where the design contract calls for it; leave other controls on their current curve and record the decision. |
| FR-04 | Geometry painting drifts from the aspect-fit box used for dragging | Low | High | Reuse the same normalized box the host already computes; a visual check with a rotated/tagged fixture confirms alignment. |
| FR-05 | Removing the panel hints loses corner-order affordance | Low | Low | Move corner names into each handle's `Semantics` label and verify the numbered handles. |
| FR-06 | The two stale screen tests make "tests pass" unavailable as evidence | Known | Low | Record the pre-existing failure; rely on `flutter analyze`, source review, and a manual run per Q4-A. |

## 4. Hard constraints

Recorded in `constraint-register.md`. The binding ones are: no engine change,
no new dependency or raw hex, no FFI/Rust in the app, no new durable client
state, offline only, design-system contract, and the `CLAUDE.md` test posture.

## 5. Recommendation

**Proceed.** Every requirement is implementable in the Flutter client and the
design layer with the existing stack; the engine side is already correct and
needs no change. There is no spike, no external decision, and no licensing
cost. The work is small, reversible, and verified by `flutter analyze`, the
no-Rust guard, and a manual run. The only items to watch are the shared-token
and accent/motion changes, handled by the mitigations above.
