# Constraint Register — Court Calibration (Feature 3)

Intent: `261030-implement-03-court`
Date: 2026-10-30

Status: Active / Superseded / Waived. Every constraint below is **Active**
unless stated.

| ID | Constraint | Type | Source | Effect on this intent |
| --- | --- | --- | --- | --- |
| C-01 | The client renders; the service stores. Geometry validation and the homography live in `sportcut-court`. | Hard — architecture | ADR-0002, CLAUDE.md, NFR-CAL-04 | No Rust change. The client consumes `CourtGeometryDto`; it never re-derives geometry. |
| C-02 | No Rust, FFI, `dart:ffi`, generated bindings, or bundled Rust library in the app. | Hard — security/architecture | CLAUDE.md, ADR-0001 | `tools/check-no-rust-in-app.sh` must pass. |
| C-03 | No new dependency or third-party package; no new licence-register row. | Hard — licensing | NFR-CAL-06, product BRD licensing gate | Use Flutter widgets and existing design tokens only. |
| C-04 | No raw colour values or ad-hoc pixel constants outside the token/metrics layer. | Hard — design | DS-1, DESIGN.md §6 | Use `SportcutPalette`/`SportcutTokens`/`ScMetrics`; raw `_hairline`/`_handleBorderWidth` move into metrics. |
| C-05 | Overlay geometry: 24 px visual handle, 44 px hit target, dashed net, one instruction line. | Hard — design | DESIGN.md §6, DS-15 | Already satisfied; preserve it. |
| C-06 | Overlay bed `#0A0F0C`, chalk `#F2F5F0`, 32-56 % scrim; accent `#0E6E45` light / `#46D08D` dark. | Hard — design | DESIGN.md §2, tokens.css | R-CAL-06/07 must land on these values. |
| C-07 | Motion 120/180 ms with `cubic-bezier(0.2,0,0,1)`; reduced motion collapses transitions. | Hard — design | DESIGN.md §7, DS-11 | R-CAL-08/09; calibrate transitions only. |
| C-08 | Offline only; no network, telemetry, or online API in product paths. | Hard — product | CLAUDE.md, NFR-1 | No new I/O of any kind. |
| C-09 | No new durable client-owned state. | Hard — migration | CLAUDE.md | The change is presentation-only; the existing controller state is not persisted. |
| C-10 | No new test files or cases; test suites do not gate ordinary work; existing tests are repaired only if the change stops them compiling or the user asks. | Hard — process | CLAUDE.md | No tests added; the two stale lookups are recorded, not repaired. |
| C-11 | Keep `main` buildable and linted without the Flutter/Xcode toolchain. | Hard — process | CLAUDE.md | No engine manifest or shared-crate change. |
| C-12 | `flutter analyze` stays clean. | Hard — quality | CLAUDE.md | Run at the end of the code stage. |
| C-13 | The service protocol stays stable; no method, framing, or error-code change. | Hard — contract | ADR-0001, CLAUDE.md | The intent sends no new protocol call. |
| C-14 | Normalized displayed-frame coordinates only; one calibration serves preview, proxy, and frames. | Hard — data | FR-CAL-23 | Paint `geometry.corners`/`.net` in the same normalized box. |
| C-15 | The release service rejects `matchDir`; calibration works only over the development transport. | Known limitation, deferred | ARCH:match-path-resolution | Recorded; not fixed here (Q3-A). |
| C-16 | Real-footage accuracy cannot be measured without a labeled clip. | Constraint, deferred | R-CAL-2, Q-CAL-4 | Out of scope; recorded in the BRD evidence table. |
| C-17 | Service-owned catalog v6 and `library.calibration.save/get` are ADR-0001 Phase 3-4 work. | Constraint, deferred | ADR-0001 | Out of scope (Q2-A). |
| C-18 | The design contract may be tightened locally, never relaxed. | Hard — design | DESIGN.md, BRD §5 | Any deviation is recorded as a tightening, not a waiver. |

## Waivers

None. No constraint is waived for this intent.

## Deferred constraints

C-15, C-16, C-17 are deferred with the reasons above. They do not block any
R-CAL requirement; they are recorded so the release gate does not mistake the
development-transport result for shipped behaviour.
