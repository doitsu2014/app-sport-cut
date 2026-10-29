# Sportcut — Court Calibration — Business Requirements Document

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-CAL-003 |
| Version | 1.0 |
| Status | Draft — for approval |
| Date | 2026-10-29 |
| Product | Sportcut — offline macOS badminton match analyzer |
| Feature | Court calibration (area CAL) |
| Owner | Product owner |
| Contributors | Product, Design, Engineering, QA, Security/Privacy, Legal/Licensing |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.0 |
| Product contract | [00-product-context.md](00-product-context.md) |

This document is one of nine feature BRDs. It cites the shared identifiers,
objectives, requirements, risks, and milestones in
[00-product-context.md](00-product-context.md) and does not restate them. All
`FR-CAL-nn` identifiers are owned here; `BO`, `BR`, `DS`, `NFR`, `R`, `Q`, and
`M` identifiers are owned by the product BRD.

## Transport and ownership note (ADR-0001)

[ADR-0001](../adr/0001-rust-background-service.md) moves the catalog, recording
custody, and engine into the Rust background service. The Flutter client draws
the marks and sends them over the
[Sportcut Service Protocol v1](../architecture/protocol.md); the service
validates, writes the calibration artifact, and writes the catalog copy. This
note supersedes "the client stores" and "SQLite in the client" wording below.
The marking workflow, validation rules, and acceptance outcomes are unchanged.
See [protocol.md §6.3](../architecture/protocol.md#83-calibration-composite)
and [background-service.md §6.2](../architecture/background-service.md#72-catalog).

## 1. Purpose and users

Calibration tells the engine where the court is in the recording. The user marks
four court corners over one video frame and states which way the court runs
relative to the camera. The engine derives a normalized top-down court mapping
(a homography) and the net line, and stores the result with the match so later
stages can reject spectators, assign players to sides, and measure motion on the
court plane.

The feature serves the personas in [00 §4.1](00-product-context.md#41-user-personas):
the club coach, competitive player, and parent who each record a match from a
fixed camera. Its success is that marking takes one pass over one frame, needs no
metric measurement, and never invents a court the user did not mark.

Relationship to the product BRD: calibration is in scope for v1
([00 §3.1](00-product-context.md#31-in-scope-for-v1)), delivers the shared
business requirement for user-confirmed setup (BR-3), and is the prerequisite
for player tracking. The product BRD records the area as Done at baseline
([00 §3.3](00-product-context.md#33-current-delivery-status)); this document
separates that functional status from the design-contract gaps recorded in §6.

## 2. Scope

### 2.1 In scope

- Mark four court corners over the video frame, in a fixed walk order.
- Drag each corner handle; clamp corners to the frame.
- State court orientation: away from the camera or across the view.
- Derive and draw the court outline and the projected net.
- Validate geometry and report why an invalid court cannot be used.
- Persist the calibration with the match, in the catalog and in the match
  directory.
- Reopen, edit, and replace a stored calibration.
- Invalidate derived tracks when the court changes.
- Keep the calibration readable when the artifact is missing.

### 2.2 Out of scope

Each item requires a change request; none may enter silently.

- Automatic court detection from the video.
- Metric court dimensions, distance in metres, serve position, and speed.
- Marking the net as two further points; orientation stays a user choice.
- A visible multi-segment editor for a camera that moves mid-recording. The
  stored model supports segments; the client writes one segment starting at
  0 ms.
- Per-segment timeline editing or automatic re-calibration across a cut.
- Calibrating from a frame other than the currently displayed playback frame.

### 2.3 Current delivery and explicit gaps

Functional status is **Done** at baseline, supported by the records in §8.
Design-contract conformance is **Partial**: the overlay draws a solid amber net
line, 40 px corner handles, and raw colours instead of the tokens and geometry
in [DESIGN.md](../../design-system/DESIGN.md) §6 and §2. These gaps are stated in
§6 and traced to risks in §9. No real-footage accuracy measurement exists; the
Phase 0 test-footage gate remains open.

## 3. Functional requirements

Every row has one observable acceptance criterion. Priorities are MoSCoW.

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-CAL-01 | Open court marking from the studio | Must | Selecting **Mark court** in the feature rail shows the calibration surface over the selected match's video, with four numbered handles, orientation control, and the save control. |
| FR-CAL-02 | Mark corners in a fixed order | Must | Handles are numbered 1–4 and labelled nearest-left, nearest-right, farthest-right, farthest-left; dragging handle 1 changes only corner 1. |
| FR-CAL-03 | Drag a corner | Must | A drag moves only the grabbed corner by the gesture's normalized offset; the other three corners keep their stored values. |
| FR-CAL-04 | Clamp corners to the frame | Must | Dragging a handle past an edge leaves that corner on the edge (`x` or `y` = 0 or 1), and the corner remains inside the frame. |
| FR-CAL-05 | Start from a visible default court | Must | An uncalibrated match opens with four in-frame default corners, reads **Save court**, and reports no stored calibration. |
| FR-CAL-06 | Project after the gesture ends | Must | Releasing a handle requests one engine projection for the current corners; the outline and net update from the returned geometry. |
| FR-CAL-07 | Draw the net as a dashed line | Must | The projected net renders as a dashed line between the engine's two net endpoints, as DESIGN.md §6 specifies. |
| FR-CAL-08 | Show one instruction line | Must | The overlay shows one instruction line; corner order is carried by the numbered handles, not by a second instruction block, per DESIGN.md §6. |
| FR-CAL-09 | Keep chrome off the court area | Must | No floating chip, card, or tooltip sits over the court action area; the instruction line identifies the projected net, per DESIGN.md §9. |
| FR-CAL-10 | Record court orientation | Must | Two labelled options, **Away from you** and **Across the view**, set the orientation; changing it re-projects the net. |
| FR-CAL-11 | Refuse an incomplete calibration | Must | Save is disabled while fewer than four corners exist or any corner is outside the frame; no write occurs. |
| FR-CAL-12 | Reject invalid geometry by name | Must | A repeated corner, three corners in a straight line, an out-of-frame corner, wrong winding, or near-zero area produces a message naming the problem; the projected net is cleared and nothing is written. |
| FR-CAL-13 | Show a projection failure | Must | An engine rejection shows the engine message, clears the projected outline, and leaves the marked corners in place for correction. |
| FR-CAL-14 | Save the court with the match | Must | **Save** writes the corners and orientation to the catalog and to `calibration/calibration.json` marked final, and returns the updated match to the caller. |
| FR-CAL-15 | Report a save failure | Must | A failed save keeps the previous stored calibration, re-enables Save, and shows a message naming the failure without discarding the corners. |
| FR-CAL-16 | Confirm a successful save | Must | A successful save shows `Court marked for <title>` and the studio's **Mark court** stage resolves to done. |
| FR-CAL-17 | Reload a stored court for editing | Must | Opening a calibrated match restores its corners and orientation, reads **Update court**, and re-projects the net. |
| FR-CAL-18 | Replace a stored court | Must | Saving over a stored court writes the new corners and orientation as one segment starting at 0 ms. |
| FR-CAL-19 | Keep unsaved corners across video switches | Should | Switching to another video and back restores the first match's unsaved corners and orientation. |
| FR-CAL-20 | Invalidate tracks derived from a changed court | Must | Changing a saved court marks the `tracks` artifact invalid and names it in the invalidation result; saving an unchanged court invalidates nothing. |
| FR-CAL-21 | Never invent a calibration | Must | A match with no stored calibration reports none; a repair rebuilds regenerable media without writing a court. |
| FR-CAL-22 | Survive restarts and artifact loss | Must | The catalog column is the source of truth: reopening the app, or deleting `calibration/calibration.json`, still returns the stored corners. |
| FR-CAL-23 | Store normalized displayed coordinates | Must | Corners are stored in `0.0..=1.0` displayed-frame space and describe the same court point for the preview, the rotation-applied proxy, and sampled frames. |
| FR-CAL-24 | Scrub before marking | Should | Play/pause and seek are available on the calibration surface; both are disabled while the player is not ready. |

## 4. State coverage

| State | Observable behaviour | Requirement |
| --- | --- | --- |
| Default | Starting four-corner court, four numbered handles, orientation **Away from you**, net not yet drawn, **Save court** enabled because the default court is complete. | FR-CAL-05, FR-CAL-06 |
| Loading | Playback reports ready/loading through the shared controller. A stored calibration is read synchronously from the match record, so there is no separate calibration loading state. | FR-CAL-17, FR-CAL-24 |
| Empty | No stored calibration. The match reports none and the surface shows the starting court; this is not an error. | FR-CAL-05, FR-CAL-21 |
| Error | Player error overlays the frame; a projection or save error appears as text and keeps the corners editable. | FR-CAL-13, FR-CAL-15 |
| Success | Snackbar names the match; the stored flag flips and the button reads **Update court**. | FR-CAL-14, FR-CAL-16 |
| Disabled | Save is disabled when incomplete or while saving; scrubber and play are disabled when playback is not ready. | FR-CAL-11, FR-CAL-24 |
| Cancellation | No cancel or discard action exists. Leaving the calibration view disposes a route-owned player and keeps the unsaved session for that match. | FR-CAL-19; gap recorded in §9 |

## 5. Design-contract specifics

The design system is a contract. Shared requirements are cited from
[00 §7](00-product-context.md#7-shared-design-system-requirements); this table
applies them to calibration and states what the code does at baseline.

| Point | Contract | Baseline implementation | Status |
| --- | --- | --- | --- |
| Handle size and hit target | 24 px visual handle, 44 px hit target (DESIGN.md §6); 44 px hit targets (DS-15) | `_handleRadius = 20` gives a 40 px box and a 40 px hit area in [calibration_view.dart](../../app/lib/src/features/calibration/presentation/calibration_view.dart) | Gap |
| Handle colour | Accent only while a handle is dragged (DESIGN.md §6); one signal per pane (DS-3) | Handles are always amber `Color(0xFFFFC107)`; no accent-on-drag state | Gap |
| Net line | Dashed net line (DESIGN.md §6) | Solid amber line, 3 px stroke | Gap |
| Instruction | One instruction line (DESIGN.md §6); scorekeeper voice (DS-10) | One instruction sentence, four corner hints, and a separate orientation question | Partial |
| Overlay bed | Fixed `#0A0F0C` bed, chalk `#F2F5F0`, 32–56 % scrim (DESIGN.md §2) | Black frame with white outline and amber net; no fixed bed or scrim | Partial |
| Floating chrome | No floating cards, tooltips, or chrome over the court action area (DESIGN.md §9) | A `PROJECTED NET` chip floats above the net midpoint in [calibration_view.dart](../../app/lib/src/features/calibration/presentation/calibration_view.dart) | Gap |
| Tokens | `--accent` `#0E6E45` light and `#46D08D` dark; `--space-3` 12 px, `--space-4` 16 px; `--radius-sm` 6 px; `--motion-fast` 120 ms, `--motion-base` 180 ms ([tokens.css](../../design-system/tokens.css)); no raw values (DS-1) | Raw `Colors.black`, `Colors.white70`, `Color(0xFFFFC107)`; controls use 12/16 px padding | Gap |
| Motion | Explain change at 120/180 ms with `cubic-bezier(0.2,0,0,1)`; reduced motion collapses transitions (DESIGN.md §7, DS-11) | No animation on handle drag or net change; nothing loops | Not implemented |
| Focus | 2 px surface gap plus 2 px accent ring in both themes (DESIGN.md §4, DS-9) | Material button and segmented-control defaults; no calibration-specific focus treatment | Unverified |
| Contrast | Body text 4.5:1, large text and essential graphics 3:1, both themes (DESIGN.md §2, DS-15) | White and amber on footage; no contrast audit recorded | Unverified |
| Layout | Preview never narrower than 480 px; rails collapse before the preview (DESIGN.md §5, DS-14) | Calibration shares the studio's centre pane; no calibration-specific width rule | Inherited from shell |

Any local change may tighten these rules, not relax them.

## 6. Feature non-functional requirements

Shared requirements are not restated; each row adds the calibration-specific
acceptance criterion.

| ID | Requirement | Priority | Acceptance criterion | Shared |
| --- | --- | --- | --- | --- |
| NFR-CAL-01 | Marking stays responsive during a drag | Must | During a drag the handles update from local state; the engine is asked once when the gesture ends, never once per pointer event. | NFR-2 |
| NFR-CAL-02 | Calibration works offline | Must | Marking, projection, and saving make no network call; only the local service (engine and its SQLite catalog) is touched. | NFR-1, BR-1 |
| NFR-CAL-03 | Saves are atomic and versioned | Must | The artifact reaches final only after a successful write; `schema_version` 1 is written; a newer schema is rejected rather than guessed. | NFR-3, NFR-4 |
| NFR-CAL-04 | Geometry rules live in the engine | Must | The client renders; the service stores. The engine owns validation and the homography, and the same rules apply to any caller. | NFR-7, NFR-8 |
| NFR-CAL-05 | Client behaviour is testable without a device | Must | Controller and widget tests run with fake playback and fake engine; 12 controller tests and 6 screen tests exist at baseline. | NFR-7 |
| NFR-CAL-06 | Calibration adds no third-party package | Should | The feature uses `sportcut-court`, `sportcut-storage`, the facade, and Flutter standard widgets only; no new dependency row is needed. | NFR-10 |

## 7. Acceptance and verification evidence

Evidence at baseline `1541c64`. Records that name code paths are current; test
counts are as reported by the baseline verification record and re-confirmed where
noted.

| Scenario | Evidence | Result |
| --- | --- | --- |
| Four corners marked and projected | [calibration_screen_test.dart](../../app/test/calibration_screen_test.dart), `the four corners are marked and the court is projected` | Pass at baseline |
| Drag one corner | Same file, `dragging a handle moves that corner`; `a handle dragged past the edge of the frame stops at the edge` | Pass at baseline |
| Orientation choice saved | Same file, `the way the court runs is the user choice, and is saved` | Pass at baseline |
| Incomplete court cannot be saved | Same file, `an incomplete court cannot be saved`; [calibration_controller_test.dart](../../app/test/calibration_controller_test.dart), `an incomplete calibration is not saved` | Pass at baseline |
| Save failure is reported | Controller file, `a save that fails is reported rather than silently dropped` | Pass at baseline |
| Stored court reloads | Controller file, `opening a calibrated match loads the court the user marked` | Pass at baseline |
| Engine rejection is shown | Controller file, `a court the engine rejects is reported and nothing is drawn`; screen file, `a court the engine rejects is reported to the user` | Pass at baseline |
| Geometry properties, not fixtures | [court/src/lib.rs](../../core/entities/court/src/lib.rs) and [homography.rs](../../core/entities/court/src/homography.rs): `cargo test -p sportcut-court` returns 20 passed, 0 failed; re-run 2026-10-29 | Pass |
| Mapping round-trips and centre invariant | `mapping_a_projected_court_round_trips`; `the_court_centre_is_where_the_marked_quadrilaterals_diagonals_cross` | Pass |
| Invalid geometry rejected by name | Five rejection tests in `court/src/lib.rs`: repeated corner, straight line, outside frame, wrong winding, near-zero area | Pass |
| Net and side follow orientation | `the_net_falls_on_the_courts_long_axis`; `a_position_is_assigned_the_half_of_the_net_it_falls_in` | Pass |
| Artifact written and read back | [facade.rs](../../core/adapters/api/tests/facade.rs), `saving_a_calibration_writes_the_artifact_and_reads_back`; `saving_the_same_calibration_again_discards_nothing` | Pass at baseline |
| Missing calibration is not invented | Same file, `a_match_reports_no_calibration_until_one_is_saved`; `a_missing_calibration_is_reported_as_needing_the_user` | Pass at baseline |
| Catalog persistence | [match_catalog_test.dart](../../app/test/match_catalog_test.dart), `a court calibration is stored on the match and read back` | Pass at baseline |
| Transport round trip (FFI baseline; retired) | The FFI bridge test that exercised `a calibration crosses the bridge, is stored, and reads back` was deleted with the FFI path | Superseded: the equivalent evidence is protocol conformance for `engine.calibration.save` and `engine.calibration.get` |
| Rotation-normalized space | Rotation-tagged fixture check in `docs/verification/court-calibration.md` at `1541c64`: proxy and frames carry rotation; stored pixels do not | Recorded manual check |
| Design conformance (dashed net, handle 24/44, accent-on-drag) | No automated design or visual test exists | Gap |
| Real-footage calibration accuracy | Every fixture is synthetic; no labeled real recording has been marked and checked | Gap |

The verification record also carries forward three known limits: the court is
normalized rather than metric; the user states orientation; a baseline-behind
camera reads as near/far while the score screen says left/right.

## 8. Dependencies and constraints

| Type | Dependency or constraint | What this feature needs |
| --- | --- | --- |
| Internal | [sportcut-court](../../core/entities/court/src/lib.rs) | Validation, homography, net derivation, side assignment |
| Internal | `sportcut-storage` | Match directory, manifest, calibration artifact persistence |
| Internal | [sportcut-api facade](../../core/adapters/api/src/facade.rs) | `court_geometry`, `save_match_calibration`, `match_calibration` |
| Internal | Flutter playback controller | Frame surface and aspect ratio for the handle box |
| Internal | Catalog v1 column `court_calibration` | Source of truth across restarts |
| Internal | [workspace studio](../../app/lib/src/features/workspace/presentation/workspace_studio_screen.dart) | Hosts the view and refreshes the pipeline stage |
| External | Design system v1.0 | Overlay geometry, tokens, motion, focus, accessibility |
| Constraint | Normalized coordinates | One calibration serves preview, proxy, and sampled frames |
| Constraint | Corner walk order | Near-left, near-right, far-right, far-left; engine rejects other winding |
| Constraint | Orientation is user input | Corners alone are ambiguous up to reflection |
| Constraint | Schema version 1 | A newer schema is rejected, not migrated or guessed |
| Constraint | One segment from the client | The multi-segment model is not surfaced in v1 |

## 9. Risks and open questions

Feature risks. Shared risks are cited, not repeated.

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-CAL-1 | Design drift in the overlay: solid net, amber handles, 40 px targets, raw hex | High | Medium | Apply DESIGN.md §6 geometry and tokens; add a widget test for handle size and net dash | Design lead |
| R-CAL-2 | No real-footage accuracy evidence; a plausible but wrong court passes every synthetic test | Medium | High | Mark one labeled real clip and compare the projected net to the painted lines; record the result | QA lead |
| R-CAL-3 | Multi-segment calibration exists in the model but not the UI, so a moved camera is unaddressed | Medium | Medium | Keep the v1 claim to one fixed camera; add the segment editor by change request | Product owner |
| R-CAL-4 | Unsaved corners survive a video switch with no discard or "unsaved" indication | Low | Medium | Label the in-progress state and offer discard when the segment editor is added | Design lead |
| R-CAL-5 | Players or score screens call the sides left/right while calibration says First/Second | Medium | Low | Resolve shared Q-9 before export copy is final | Product owner |

Shared risks that apply: R-6 design drift, R-7 client test gaps, R-9 retired
documentation references. Shared objectives that gate this feature: BO-5 and BO-6.

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-CAL-1 | Does v1 keep the corner walk order, or mark the net as two points and derive order? | Removing the orientation question changes the record shape | Product owner |
| Q-CAL-2 | Is a moved-camera segment editor a v1 requirement? | Affects whether the UI must expose segments | Product owner |
| Q-CAL-3 | Are the side names First/Second acceptable in user-facing copy, or must they read Left/Right? | Affects tracking and export labels | Product owner |
| Q-CAL-4 | What is the acceptance method for "the projected net sits on the real net"? | R-CAL-2 needs an observable check | QA lead |

## 10. Traceability

| Business requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| BR-3 Semi-automatic, user-confirmed | FR-CAL-01–18, FR-CAL-21 | §6 Overlays | [calibration_view.dart](../../app/lib/src/features/calibration/presentation/calibration_view.dart), [calibration_controller.dart](../../app/lib/src/features/calibration/presentation/calibration_controller.dart) | `calibration_*_test.dart` |
| BR-8 Design fidelity | FR-CAL-07–09 | DESIGN §6, §7; DS-1, DS-3, DS-9, DS-11 | Same view | Gap; see §5 |
| BR-9 Accessibility | FR-CAL-02, FR-CAL-04 | DS-15; DESIGN §6 | Handle hit area | Gap at 40 px |
| BR-11 Recoverable jobs | FR-CAL-15, FR-CAL-20 | — | [facade.rs](../../core/adapters/api/tests/facade.rs) | Facade tests |
| NFR-4 Data integrity | FR-CAL-14, FR-CAL-18, FR-CAL-22 | — | [court_calibration.dart](../../app/lib/src/features/calibration/domain/court_calibration.dart), storage | `match_catalog_test.dart`, facade tests |
| Mapping correctness (BO-5 input) | FR-CAL-06, FR-CAL-23 | — | [court/src/lib.rs](../../core/entities/court/src/lib.rs), [homography.rs](../../core/entities/court/src/homography.rs) | 20 court tests |
| Pipeline placement | FR-CAL-01, FR-CAL-16 | DESIGN §6 Pipeline row | [pipeline_stage.dart](../../app/lib/src/features/workspace/domain/pipeline_stage.dart) | Indirect screen tests |

Prior verification record: `docs/verification/court-calibration.md` at baseline
`1541c64` (cited for provenance; not part of the working tree). Architecture
references: `docs/architecture.md` (calibration stage) and
`docs/data-storage-models.md` (calibration artifact) at the same baseline.

## 11. Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |
| Legal/licensing |  | Approve / revise |  |

---

**Change control.** A change to scope, a Must requirement, or the design
contract requires a version bump, a recorded approval decision, and a re-run of
the quality checklist. Changes to shared IDs follow
[00 §18](00-product-context.md#18-approval). This draft does not claim release
readiness while R-CAL-1, R-CAL-2, and the shared open gates remain open.
