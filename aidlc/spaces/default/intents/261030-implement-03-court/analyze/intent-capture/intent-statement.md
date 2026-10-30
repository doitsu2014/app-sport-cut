# Intent Statement — Court Calibration (Feature 3)

Status: Analyze / Intent Capture
Intent: `261030-implement-03-court`
Date: 2026-10-30
Sources: `docs/brd/03-court-calibration.md`, `docs/brd/00-product-context.md`,
`docs/adr/0001-rust-background-service.md`, `docs/adr/0002-clean-architecture-engine.md`,
`docs/architecture/protocol.md`, `design-system/DESIGN.md`,
`design-system/tokens.css`, `CLAUDE.md`.

## Problem

Sportcut's third feature (`CAL`) owns the step that tells the engine where the
court is: mark four corners over one frame, state which way the court runs,
derive a homography and the net, persist the result with the match, and
invalidate derived tracks when the court changes. Tracking, rally review, score,
and highlight boundaries all depend on it.

A HEAD audit of 62 requirement rows shows the functional core is largely
shipped — corner marking and clamping, save/update, validation by name, track
invalidation, catalog persistence, and track-session retention all hold — but
the feature's central acceptance criterion fails. The engine returns a
`CourtGeometryDto` with the court outline and the net, and the controller stores
it, yet nothing renders it:

- `CalibrationOverlayHost.build` passes only the corners to
  `ScCalibrationOverlay` (calibration_overlay_host.dart:109-135).
- `ScCalibrationOverlay` has no geometry input. It computes the net from the
  midpoints of corners 0-3 and 1-2 (`_netEndpoints`,
  sc_calibration_overlay.dart:395-403), draws no court outline, and ignores
  orientation, so **Across the view** changes nothing on screen.
- An uncalibrated match draws a "projected" net that was never projected
  (STATE:Default), and an engine rejection leaves the stale net on screen
  because `clearGeometry` only flips a flag (FR-CAL-13).

The BRD's design-gap list is also stale. The 40 px amber handles, solid 3 px
net, raw hex colours, and floating `PROJECTED NET` chip it records are already
fixed; handles are 24 px visual / 44 px hit, the net is dashed, and the palette
tokens are adopted. The genuinely open design work is the instruction surface
(one micro10 text line inside a filled pill, duplicated by an inspector
paragraph plus four corner hints), the overlay bed (no fixed `#0A0F0C` bed and
no 32-56 % scrim; `overlayBed` is `#050806`), motion (no calibration transition
and no `cubic-bezier(0.2,0,0,1)` token), the competing accent from the shared
transport during a drag (DS-3), and contrast of the net and handles over
arbitrary footage.

Two named screen tests also throw at HEAD: they look up `FilledButton` while
the panel renders `ScButton` (calibration_screen_test.dart:72,172). The §7
verification record they cite, `docs/verification/court-calibration.md`, is not
in the working tree.

## Users

- **Club coach / competitive player / parent** marking their own recording:
  they need the drawn net and outline to be the engine's projection, to follow
  the orientation they chose, to disappear when the court is rejected, and to
  read clearly over footage in either theme.
- **Product owner / QA lead** gating v1 on the BRD: they need the §5 design
  contract and §7 evidence to describe HEAD truthfully, including the defects
  that no longer exist.

## Success criteria (observable)

1. **Requirements ledger.** All 24 `FR-CAL` requirements, all eleven §5 design
   rows, the six `NFR-CAL` requirements, and the seven §4 state rows are
   recorded against HEAD as Satisfied, Partial, or Missing with exact file and
   symbol references (the Analyze audit is the input).
2. **The projection drives the overlay.** `CalibrationState.geometry` is passed
   into `ScCalibrationOverlay`; the court outline is painted from
   `geometry.corners` and the dashed net from `geometry.net`; the client-side
   `_netEndpoints` derivation is deleted. An uncalibrated default draws no net
   until the first projection. Changing orientation changes the drawn net. An
   engine rejection clears the outline and net while keeping the corners
   editable.
3. **One instruction line.** The overlay keeps exactly one instruction line,
   rendered as plain text (no filled pill), at 12 px or larger, whose copy names
   the dashed line as the projected net. The inspector's duplicate instruction
   paragraph and four corner-order hints are removed or demoted to
   non-instruction labels; corner order stays on the numbered handles and their
   semantics.
4. **Design residuals closed.** A fixed `#0A0F0C` bed with a 32-56 % scrim or
   chalk `#F2F5F0` markings under the handles and net; the shared transport is
   de-accented while the calibrate stage is active; a Dart `ease-standard`
   `Cubic(0.2, 0, 0, 1)` token and named hairline/border metrics replace the raw
   constants; handle and net changes animate at the 120/180 ms motion tokens
   with reduced-motion collapse; the contrast outcome is recorded.
5. **Documentation matches HEAD.** BRD 03 §1, §2.3, §4 (Cancellation describes
   the real Cancel control), §5 baseline/status cells, §7 evidence, and §10, and
   BRD 00 §3.3 row 3 are corrected. `protocol.md`'s claim that
   `engine.calibration.save` also writes the catalog copy is corrected to the
   one-step implementation, and the §6.3/§6.2 cross-references point at §8.3 and
   §7.2.
6. **Quality gates.** `flutter analyze` is clean for `app/`;
   `tools/check-no-rust-in-app.sh` passes; the change introduces no raw hex, no
   new dependency, no FFI, and no new durable client-owned state.
7. **Out-of-scope items remain untouched.**

## In scope

- Rendering the engine's outline and net from `CourtGeometryDto` in
  `app/lib/src/app/design/components/sc_calibration_overlay.dart` and passing
  geometry through `app/lib/src/features/calibration/presentation/calibration_overlay_host.dart`.
- The instruction surface in the overlay and
  `calibration_panel.dart` (FR-CAL-08, FR-CAL-09, design Instruction).
- The overlay bed, scrim, contrast, accent isolation, motion, and token
  clean-up (design Overlay bed, Handle colour, Tokens, Motion, Contrast).
- `STATE:Default` (no net before projection) and FR-CAL-13 (rejection clears).
- Reconciliation of BRD 03, BRD 00 §3.3, and the `protocol.md` cross-references
  and one-step-save wording.
- Recording the stale `FilledButton` assertions and the absent
  `docs/verification/court-calibration.md` as known acceptance-evidence gaps.

## Out of scope

- The ADR-0001 Phase 3-4 service-owned catalog (`catalog.sqlite` v6 adopting
  v5), `library.calibration.save/get` handlers, and recording custody.
- The release-service `matchDir` rejection; recorded as a migration-phase
  limitation (Q3-A), not fixed here.
- Real-footage calibration accuracy (R-CAL-2, Q-CAL-4): no labeled recording
  exists.
- Moved-camera / multi-segment editor (R-CAL-3, Q-CAL-2), metric dimensions,
  automatic court detection, and marking the net as two points (Q-CAL-1).
- Side-name copy Left/Right vs First/Second (Q-CAL-3).
- New test files or new test cases, and repairing the two stale screen-test
  lookups (Q4-A; `CLAUDE.md` working agreement).
- Any engine change: the homography, validation, and net derivation are
  already correct.

## Constraints

- Client track (`app/`) and documentation (`docs/brd/`, `docs/architecture/`).
  The engine build and lint must stay clean without the Flutter toolchain.
- Design-system contract: `DESIGN.md` §6/§2/§7/§4 and `tokens.css`; no raw hex;
  any local change may tighten the rules, not relax them.
- Offline only: no network, telemetry, or online API.
- No FFI, no Rust linked into the app, and no new durable client-owned state.

## Assumptions

- `CourtGeometryDto.corners` and `.net` are normalized image coordinates
  (verified: `core/entities/court/src/lib.rs:260-270`,
  `core/adapters/api/src/dto.rs:528-544`), and the overlay's aspect-fit box uses
  the same normalized space as the marked corners, so the returned points can
  be painted without conversion.
- The controller already requests a projection on open and on gesture release
  (`calibration_controller.dart:119-131,172-184`), so no engine or controller
  protocol work is needed.
- The release-service defect is a Phase 3/6 migration issue: the client always
  sends `matchDir` (`sportcut_engine.dart:426-431`) and a release service
  rejects it (`engine.rs:477-494`).

## Cost of doing nothing

The user marks four corners and sees a net the engine did not produce: it does
not follow the orientation control, it appears before any projection, and it
stays after the engine rejects the court. Calibration accuracy claims rest on a
picture that is not the homography's output, and the BRD keeps asserting defects
that no longer exist while the open ones stay under-recorded, so the feature
cannot honestly be called done.
