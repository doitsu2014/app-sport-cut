# Requirements — Court Calibration (Feature 3)

Status: Analyze / Requirements Analysis
Intent: `261030-implement-03-court`
Date: 2026-10-30
Input: `analyze/intent-capture/intent-statement.md`
Method: 62-row HEAD audit, each gap adversarially re-verified against source
(see the intent statement for the evidence).

## 1. How these requirements were derived

The feature BRD owns the requirement identifiers (`FR-CAL`, `NFR-CAL`); this
document does not restate them. It records, for each BRD row, whether HEAD
satisfies it, and turns the unsatisfied rows into implementable requirements
with one observable acceptance criterion. A satisfied row is retained as
regression scope only: the change must not break it.

Priority is inherited from the BRD (MoSCoW). Verification method is one of
`source` (read the cited code), `analyze` (`flutter analyze`), `guard`
(`tools/check-no-rust-in-app.sh`), or `manual` (run the app and observe).

## 2. Functional requirements for this intent

### R-CAL-01 — Render the engine's court outline (Must)

- **Source:** FR-CAL-06; intent criterion 2.
- **Statement:** The overlay paints the court outline returned by the engine,
  not a client-side construction. `CalibrationOverlayHost` passes
  `CalibrationState.geometry` into `ScCalibrationOverlay`; the component paints
  `geometry.corners` as a closed quadrilateral in normalized box coordinates.
- **Acceptance:** With a fake engine returning a known four-corner geometry, the
  painted outline's four points equal `geometry.corners` mapped by the aspect-fit
  box; no outline is painted while `geometry` is null. The client contains no
  code path that derives an outline from corner arithmetic. Malformed payloads —
  fewer or more than four corners, non-finite values, points outside 0..1 — paint
  nothing and do not throw (security S-1).
- **Verification:** source; manual.

### R-CAL-02 — Draw the engine's net, including orientation (Must)

- **Source:** FR-CAL-07, FR-CAL-10; intent criteria 2.
- **Statement:** The dashed net is painted between `geometry.net[0]` and
  `geometry.net[1]`. The client-side `_netEndpoints` midpoint derivation is
  deleted. Changing orientation re-requests projection and the drawn net changes
  accordingly.
- **Acceptance:** The endpoints passed to `_NetPainter` are exactly
  `geometry.net` after validation (exactly two finite points clamped to 0..1);
  switching **Away from you** ↔ **Across the view** produces a different drawn
  line for the same corners (verified against the engine's returned net). No call
  site computes net endpoints from corners. The dash loop is bounded so a
  pathological endpoint cannot freeze the UI thread (security S-2).
- **Verification:** source; manual.

### R-CAL-03 — Draw no net before a successful projection (Must)

- **Source:** FR-CAL-05, FR-CAL-21, STATE:Default; intent criterion 2.
- **Statement:** An uncalibrated match shows the four in-frame default corners,
  four numbered handles, orientation **Away from you**, and an enabled
  **Save court** — with no net and no outline until the engine returns geometry.
  The inspector's non-projected label is a prompt, not "Marking the court…".
- **Acceptance:** On first open of an uncalibrated match, `geometry` is null and
  no net or outline is painted; the supporting line invites the user to drag a
  handle. After the first release, the net appears. A match with no stored
  calibration still reports none and no court is written.
- **Verification:** source; manual.

### R-CAL-04 — Clear the drawn geometry on an engine rejection (Must)

- **Source:** FR-CAL-13; intent criterion 2.
- **Statement:** When the engine rejects a court, the engine message is shown,
  the outline and net are removed, and the marked corners remain editable.
- **Acceptance:** With a fake engine that rejects the projection, after the
  failed attempt no outline or net is painted, the four corners keep their
  positions, and the danger message names the engine's problem. A subsequent
  valid projection paints again.
- **Verification:** source; manual.

### R-CAL-05 — Keep one plain instruction line (Must)

- **Source:** FR-CAL-08, FR-CAL-09; DESIGN.md §6 and §9; intent criterion 3.
- **Statement:** The overlay shows exactly one instruction line. It is plain
  text — no surface-filled pill, border, or chip over the action area — at 12 px
  or larger, and its copy identifies the dashed line as the projected net. The
  inspector removes its duplicate instruction paragraph and the four
  corner-order hints; corner order is carried by the numbered handles and their
  `Semantics` labels.
- **Acceptance:** The calibration surface contains one instruction sentence; no
  `DecoratedBox`/`ScPanel` wraps it; its text style is at least `xs12`; the copy
  names the net. The inspector has no second instruction paragraph or hint list.
  Each handle's semantics still names its corner (e.g. "Corner 1, nearest left").
- **Verification:** source; manual.

### R-CAL-06 — Give the overlay the design bed and scrim (Must)

- **Source:** design Overlay bed, Contrast; DESIGN.md §2; intent criterion 4.
- **Statement:** The calibration markings sit on the fixed `#0A0F0C` bed with a
  32-56 % scrim and chalk `#F2F5F0` for essential lines, so the net and handles
  hold 3:1 contrast over arbitrary footage in both themes. The shared
  `overlayBed`/`ScOverlayColors.bed` values are corrected from `#050806` to
  `#0A0F0C` unless that would regress another consuming surface.
- **Acceptance:** The overlay paints the fixed bed and scrim beneath the
  markings; the net and handle outline use chalk or an equivalently contrast-
  checked colour; a recorded contrast calculation shows at least 3:1 for
  essential graphics and 4.5:1 for text in both themes.
- **Verification:** source; manual contrast calculation.

### R-CAL-07 — Isolate the accent signal during calibration (Must)

- **Source:** design Handle colour; DS-3; intent criterion 4.
- **Statement:** While the calibrate stage is active, only the dragged handle
  carries the accent. The shared transport's accent play control and signal-green
  scrub fill/thumb are de-accented, hidden, or otherwise removed as a second
  signal source in the same pane. Accent is tied to a confirmed drag, not a bare
  pointer-down.
- **Acceptance:** A drag shows exactly one accent element in the calibration
  pane; the transport's accent is suppressed while the stage is active; the
  accent state starts on drag confirmation.
- **Verification:** source; manual.

### R-CAL-08 — Add the standard ease token and named metrics (Must)

- **Source:** design Tokens; DESIGN.md §7; DS-1, DS-11; intent criterion 4.
- **Statement:** The app gains an `easeStandard = Cubic(0.2, 0.0, 0.0, 1.0)`
  motion token used by shared transitions, and the raw `_hairline = 1` and
  `_handleBorderWidth = 2` constants move into named `ScMetrics` entries.
- **Acceptance:** No Dart transition uses `Curves.easeOut` where the design
  contract calls for the standard curve; calibration contains no raw pixel
  constants outside the metrics/token layer; `flutter analyze` is clean.
- **Verification:** source; analyze.

### R-CAL-09 — Animate handle and net changes with reduced-motion collapse (Must)

- **Source:** design Motion; DESIGN.md §7; DS-11; intent criterion 4.
- **Statement:** Handle colour and net changes animate at 120/180 ms with
  `easeStandard`, and collapse to no transition when the platform requests
  reduced motion. Nothing loops.
- **Acceptance:** A colour or net state change runs a 120/180 ms transition; with
  reduced motion enabled the change is instant; no repeating animation exists.
- **Verification:** source; manual.

### R-CAL-10 — Document the real cancellation behaviour (Should)

- **Source:** STATE:Cancellation; BRD §4; intent criterion 5.
- **Statement:** BRD §4 describes what the code does: a **Cancel** control leaves
  the Mark court stage without saving, and the unsaved session stays parked for
  that match. The alternative (removing Cancel) is a product decision and is not
  taken here.
- **Acceptance:** BRD §4 Cancellation matches the rendered control and its
  wiring; no code change is required.
- **Verification:** source (doc vs code).

### R-CAL-11 — Reconcile the BRD status tables with HEAD (Must)

- **Source:** intent criteria 1 and 5; audit rows X-03, X-04, X-05, S7-16.
- **Statement:** BRD 03 §1/§2.3/§5/§7/§10 and BRD 00 §3.3 row 3 record the
  verified HEAD state: the 40 px amber handles, solid net, raw colours, and
  `PROJECTED NET` chip are fixed; the instruction surface, bed/scrim, motion,
  and contrast are the open design work; the missing verification record and the
  two stale screen-test rows are recorded as evidence gaps; the area stays
  Partial, not Done.
- **Acceptance:** Every status cell names a HEAD-verifiable defect or evidence
  gap; no cell repeats a defect already fixed at HEAD; the evidence table's
  counts and file references are accurate.
- **Verification:** source; `git diff` review.

### R-CAL-12 — Correct the protocol documentation (Should)

- **Source:** ARCH:engine-save-writes-catalog-copy, ARCH:doc-crossrefs.
- **Statement:** `docs/architecture/protocol.md` stops claiming
  `engine.calibration.save` writes the catalog copy (it writes the artifact and
  manifest; the application writes its own catalog row), the `service.hello`
  example stops carrying a token-shaped value (replace it with
  `<per-launch-token>`; security S-4), and the BRD's §6.3 / §6.2
  cross-references point at §8.3 and §7.2.
- **Acceptance:** No protocol text describes the documented two-step save as
  one step; the example contains no 32-hex token-shaped literal; no BRD
  cross-reference names a non-existent section.
- **Verification:** source.

## 3. Requirements retained as satisfied (regression only)

These rows are satisfied at HEAD and must not regress: FR-CAL-01, 02, 03, 04,
05, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24; design rows Handle size
and hit target, Net line (dash geometry), Floating chrome (no chip), Focus,
Layout; NFR-CAL-01, 02, 03, 06; STATE:Loading, Empty, Error, Success, Disabled.
Evidence is recorded in the intent statement and the audit ledger.

## 4. Non-functional requirements for this intent

| ID | Statement | Acceptance | Verification |
| --- | --- | --- | --- |
| NR-CAL-01 | No engine change. The homography, validation, and net derivation stay in `sportcut-court`. | `git diff` touches no Rust file; `tools/check-layering.sh` remains green. | source |
| NR-CAL-02 | No new dependency, package, or raw hex colour. | `app/pubspec.yaml` unchanged except no additions; no `Color(0x…` in touched calibration/design files; the licence register needs no new row. | source |
| NR-CAL-03 | Offline only. | The change adds no network call, telemetry, or online API. | source |
| NR-CAL-04 | No FFI, no Rust in the app, no new durable client-owned state. | `tools/check-no-rust-in-app.sh` passes; no persistence is added. | guard |
| NR-CAL-05 | Client static analysis is clean. | `flutter analyze` (or `SPORTCUT_FLUTTER_BIN`-resolved equivalent) reports no issues. | analyze |
| NR-CAL-06 | The change does not break the existing controller/screen tests. | The suites compile; the two pre-existing `FilledButton` lookup failures are recorded, not introduced by this change. | source |

## 5. Constraints and assumptions

- **C1.** The client renders; the service stores. Geometry rules stay in the
  engine.
- **C2.** Corners are normalized displayed-frame coordinates; the overlay box
  and `CourtGeometryDto` share that space.
- **C3.** `DESIGN.md` §6 geometry (24 px visual / 44 px hit, dashed net, one
  instruction line) and §2 bed/scrim are a contract; local changes may tighten,
  not relax.
- **C4.** `CLAUDE.md`: no new tests, no test-suite runs, no new test files;
  repair an existing test only if the change stops it compiling or the user asks.
- **A1.** No engine change is needed because `court_geometry` already returns
  the outline and net (`facade.rs:264-267`, `dto.rs:528-544`).
- **A2.** The release-service `matchDir` rejection is a Phase 3/6 migration
  limitation and does not block the client-track work here.
- **A3.** `docs/verification/court-calibration.md` remains absent; the intent
  records that rather than creating it from synthetic evidence.

## 6. Traceability matrix

| BRD row | HEAD status | Intent requirement | Verification |
| --- | --- | --- | --- |
| FR-CAL-01 | Satisfied | regression | source |
| FR-CAL-02 | Satisfied | regression | source |
| FR-CAL-03 | Satisfied | regression | source |
| FR-CAL-04 | Satisfied | regression | source |
| FR-CAL-05 | Satisfied | R-CAL-03 (no-net half) | source |
| FR-CAL-06 | Partial | R-CAL-01, R-CAL-02 | source, manual |
| FR-CAL-07 | Partial | R-CAL-02 | source, manual |
| FR-CAL-08 | Partial | R-CAL-05 | source, manual |
| FR-CAL-09 | Partial | R-CAL-05 | source, manual |
| FR-CAL-10 | Partial | R-CAL-02 | source, manual |
| FR-CAL-11 | Satisfied | regression | source |
| FR-CAL-12 | Satisfied | regression | source |
| FR-CAL-13 | Partial | R-CAL-04 | source, manual |
| FR-CAL-14 | Satisfied | regression | source |
| FR-CAL-15 | Satisfied | regression | source |
| FR-CAL-16 | Satisfied | regression | source |
| FR-CAL-17 | Satisfied | regression | source |
| FR-CAL-18 | Satisfied | regression | source |
| FR-CAL-19 | Satisfied | regression | source |
| FR-CAL-20 | Satisfied | regression | source |
| FR-CAL-21 | Satisfied | R-CAL-03 | source |
| FR-CAL-22 | Satisfied (client catalog) | regression; NFR-CAL-04 deferred | source |
| FR-CAL-23 | Satisfied | regression | source |
| FR-CAL-24 | Satisfied | regression | source |
| Handle size and hit target | Satisfied | regression | source |
| Handle colour | Partial | R-CAL-07 | source, manual |
| Net line | Satisfied (dash) | R-CAL-02 | source |
| Instruction | Partial | R-CAL-05 | source, manual |
| Overlay bed | Partial | R-CAL-06 | source, manual |
| Floating chrome | Satisfied | R-CAL-05 (keep it) | source |
| Tokens | Partial | R-CAL-08 | source, analyze |
| Motion | Partial | R-CAL-09 | source, manual |
| Focus | Satisfied | regression | source |
| Contrast | Partial | R-CAL-06 | manual calculation |
| Layout | Satisfied | regression | source |
| NFR-CAL-01 | Satisfied | regression | source |
| NFR-CAL-02 | Satisfied | regression | source |
| NFR-CAL-03 | Satisfied | regression | source |
| NFR-CAL-04 | Partial — deferred | out of scope (ADR-0001) | — |
| NFR-CAL-05 | Partial — stale lookups | recorded, not repaired (Q4-A) | source |
| NFR-CAL-06 | Satisfied | regression | source |
| STATE:Default | Partial | R-CAL-03 | source, manual |
| STATE:Loading | Satisfied | regression | source |
| STATE:Empty | Satisfied | regression | source |
| STATE:Error | Satisfied | R-CAL-04 (clearing half) | source |
| STATE:Success | Satisfied | regression | source |
| STATE:Disabled | Satisfied | regression | source |
| STATE:Cancellation | Partial (doc) | R-CAL-10 | source |
| §7 evidence rows | S7-01, 04, 15, 17 partial; S7-16, 18 missing | R-CAL-11 records them | source |
| ARCH ownership rows | Missing/partial — deferred | out of scope (ADR-0001) | — |

Every requirement above traces to a BRD row and to an intent criterion. No
orphan requirement is introduced. Every requirement has at least one observable
acceptance criterion.

## 7. Explicitly out of scope

- Real-footage accuracy measurement (S7-18, R-CAL-2, Q-CAL-4).
- ADR-0001 Phase 3-4 service catalog and `library.calibration.save/get`.
- Release-service match-path resolution.
- Moved-camera/multi-segment editor, metric dimensions, automatic detection,
  net-as-two-points (Q-CAL-1), side naming (Q-CAL-3).
- New tests and repair of the two stale `FilledButton` lookups.
