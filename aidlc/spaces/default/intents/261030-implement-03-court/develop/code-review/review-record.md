# Code Review Record — Court Calibration (Feature 3)

Status: Develop / Code Review
Intent: `261030-implement-03-court`
Date: 2026-10-30
Reviewers: independent review workflow (correctness, security, design contract,
documentation), each finding adversarially re-verified; lead synthesis.

## 1. Scope reviewed

The full uncommitted diff: 11 client files, one screenshot-test expectation, and
three documentation files. Read in full, against
`analyze/requirements-analysis/requirements.md`,
`ideate/technical-spec/technical-spec.md`,
`ideate/architecture-design/architecture-doc.md`,
`ideate/architecture-design/security-review.md`, and
`develop/code-generation/source-changes.md`.

## 2. First pass — changes-required

Verdict: **changes-required** (3 major, 8 minor, 1 nit after adversarial
verification).

| ID | Severity | Finding | Disposition |
| --- | --- | --- | --- |
| R1 | Major | The calibration scrim was painted above the still-enabled transport, dimming its timecodes and scrubber below the contrast floors. | **Fixed:** `ScCalibrationScrim` is a separate widget passed through `VideoPreview.underlay`, below the transport and above the footage. |
| R2 | Major | The 12 px instruction on the 52 % scrim measured ≈3.5:1 over bright footage, below the 4.5:1 body-text floor. | **Fixed:** the instruction sits on a flat, full-width opaque bed band (≈18:1), not a pill or card. |
| R3 | Major | The handle accent started on a bare pointer-down instead of a confirmed drag. | **Fixed:** accent is driven by `_dragging` (`onPanStart` → `onPanEnd`/`onPanCancel`); a click no longer flashes the signal. |
| R4 | Minor | The semantics name lookup indexed a fixed four-entry list (RangeError on a malformed five-corner segment). | **Fixed:** bounds-guarded, with a fallback label. |
| R5 | Minor | `isProjected` was true for any non-null geometry while the overlay silently dropped invalid payloads. | **Fixed:** `CalibrationController._isDrawable` rejects malformed payloads with a message; the panel and overlay share the gate. |
| R6 | Minor | Keyboard/semantics activation armed a drag and a later spurious projection. | **Fixed:** `_select` no longer arms dragging; only a pan does; `_release` clears active and projects only after a drag. |
| R7 | Minor | Changing the shared stage bed to `#0A0F0C` contradicted ADR-0003 D16. | **Fixed:** the bed stays `#050806`; the calibration scrim is a local 52 % composite. |
| R8 | Minor | The 44 px hit target is clipped at a frame edge. | **Accepted, recorded:** pre-existing edge case; BRD §5/§7 and BR-9 now qualify it. |
| R9 | Minor | The new scrim token was unused and disagreed with the shipped value. | **Fixed:** the token was removed; `ScOverlayColors.calibrationScrim` is the single value. |
| R10 | Major (docs) | The BRD transport note still said the service writes the catalog copy. | **Fixed:** the note now describes the artifact + app-owned catalog row until Phase 4. |
| R11 | Major (docs) | The projection evidence row cited a nonexistent controller test. | **Fixed:** cites `a complete calibration is projected through the engine`. |
| R12 | Major (docs) | The Contrast row claimed Satisfied on a nonexistent record and an inaccurate ratio. | **Fixed:** the row records the actual ≈3.7:1 graphics / opaque-band instruction result. |
| R13 | Major (docs) | The Handle colour row said "while pressed" while the accent was not drag-gated. | **Fixed:** code is drag-gated and the row says so. |
| R14 | Minor (docs) | §2.3 Partial vs §5/§10 Satisfied read inconsistently; baseline header stale. | **Fixed:** §2.3 states the rows are satisfied and the area is Partial for evidence gaps; header re-based to 2026-10-30. |
| R15 | Minor (record) | The consumer-scan note overstated alpha compositing; the contrast arithmetic and file count were wrong. | **Fixed:** note, arithmetic, and count corrected. |

## 3. Second pass — approve-with-fixes

Verdict: **approve-with-fixes** (0 blocking, 0 major, 12 minor, 3 nit). All
majors from the first pass were confirmed fixed; the new pass looked for defects
introduced by the fixes.

| ID | Severity | Finding | Disposition |
| --- | --- | --- | --- |
| F1 | Minor | A strict 0..1 gate rejected an engine-accepted near-edge coordinate (`1.0000000000000002`) instead of clamping. | **Fixed:** `_isDrawable` allows a 0.001 epsilon; the host clamps before building `ScCourtGeometry`. |
| F2 | Minor | The opaque instruction band was stacked above the court painter, hiding the top of the outline near the frame top. | **Fixed:** paint order is band → court → handles. |
| F3 | Minor | A controller comment still said a drag draws the quadrilateral from corners. | **Fixed:** comment says the last projection is kept while handles move. |
| F4 | Minor | The BRD Tokens row still claimed `overlayBed` `#0A0F0C`. | **Fixed:** the row names `#050806` per ADR-0003 D16. |
| F5 | Minor | BRD 00 DS-1 and DESIGN.md §2 still specified `#0A0F0C`, contradicting the ADR. | **Fixed:** both now state `#050806` with the ADR-0003 D16 override. |
| F6 | Minor | "No automated design or visual test exists" was contradicted by the screenshot suite. | **Fixed:** the row says no golden-image/design assertion exists; the suite captures without a reference comparison. |
| F7 | Minor | Handle-size and BR-9 rows were Satisfied unconditionally despite the edge clip. | **Fixed:** both rows qualify the edge case and point at §7. |
| F8 | Minor | The projection row called the screen test's projection assertion stale; it is the `FilledButton` lookup that fails. | **Fixed:** wording corrected. |
| F9 | Minor | The change record's file count omitted the controller (15 files, 11 client). | **Fixed.** |
| F10 | Minor | The court exit transition used the entrance curve and full duration, against DESIGN.md §7's ~70 % ease-in exit. | **Fixed:** `reverseDuration` is 70 % of `motionBase` with `Curves.easeIn`. |
| F11 | Nit | Handle comments still described accent while the pointer is down. | **Fixed:** comments and the technical spec say "confirmed drag". |
| F12 | Nit | The underlay sat above the score bug, so a future caller combining both would dim it. | **Fixed:** underlay is below the score bug as well as the transport. |
| F13 | Nit | Keyboard focus loss left the active ring. | **Fixed:** focus loss reports `onSelect(-1)`. |
| F14 | Nit | The geometry predicate is duplicated in the controller (bridge DTO) and `ScCourtGeometry` (design model). | **Accepted:** the duplication is the deliberate boundary between transport data and the design value model; both must agree, and the host reuses `isValid`. Recorded as a follow-up to unify if a third consumer appears. |
| F15 | Nit | The invalid-geometry message misdiagnosed shape/finiteness as "outside the frame". | **Fixed:** neutral message, "The engine returned a court that cannot be drawn." |

## 4. Correctness and safety checks

- **Geometry guard:** four corners and two net points, finite, within a
  `0.001` epsilon of 0..1 in the controller; the host clamps to 0..1; the
  painter re-checks `isValid`, clamps again, and rejects non-finite values.
- **Dash loop:** bounded at `4 × size.longestSide`; a clamped payload cannot
  exceed the diagonal.
- **No new surface:** no network, path, credential, deserialization, logging,
  dependency, FFI, or durable state. `git diff -- core` is empty.
- **State:** drag updates local state; one projection per release; rejection
  clears the geometry and keeps corners; keyboard activation cannot arm a
  projection; a click does not accent.
- **Design contract:** one plain instruction on an opaque band; 24/44 handles;
  accent only during a confirmed drag; fixed `#050806` bed and 52 % scrim;
  `easeStandard` on calibration transitions with reduced-motion collapse; no
  looping animation.
- **Routes:** all `VideoPreview`/`ScTransport` call sites compile and keep their
  previous behaviour; only the calibration branches suppress the accent and add
  the underlay.

## 5. Verification evidence

| Check | Result |
| --- | --- |
| `cd app && flutter analyze` | No issues found |
| `tools/check-no-rust-in-app.sh` | OK |
| `flutter test test/calibration_controller_test.dart` | 12/12 passed |
| `flutter test test/calibration_screen_test.dart` | 4 passed, 2 pre-existing `FilledButton` failures |
| `tools/capture-app-screenshots.sh` | 21/21 passed, 40 PNGs |
| Visual check | `calibration_default` (no net, band, neutral transport) and `calibration_projected` (engine outline + dashed net, bright transport) inspected |
| `git diff -- core` | Empty |

## 6. Findings still open (accepted)

1. **Edge-clipped handle hit area** (R8): pre-existing; recorded in BRD §5/§7
   and BR-9 as a follow-up.
2. **Duplicated geometry predicate** (F14): intentional boundary between the
   bridge DTO and the design model; unify if a third consumer appears.
3. **Two stale screen tests** and the absent verification record: pre-existing,
   recorded, not repaired under `CLAUDE.md`.
4. **No golden-image design assertion:** the screenshot suite captures but does
   not compare; follow-up.

## 7. Verdict

**Approve.** The change satisfies R-CAL-01…12 and NR-CAL-01…06 as scoped. All
blocking and major findings from both passes are fixed; the remaining items are
accepted nits or pre-existing gaps, recorded above and in the BRD. The
implementation is presentation-only, the engine is untouched, and the client
gates are green.
