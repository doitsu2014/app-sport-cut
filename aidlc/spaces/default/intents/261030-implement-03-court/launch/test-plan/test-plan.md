# Test Plan — Court Calibration (Feature 3)

Status: Launch / Test Plan
Intent: `261030-implement-03-court`
Date: 2026-10-30
Inputs: `requirements.md`, `technical-spec.md`, `source-changes.md`,
`code-review/review-record.md`.

## 1. Risk ranking

Impact × likelihood, highest first. The test effort follows this order.

| Rank | Area | Requirement | Why it is risky | Depth |
| --- | --- | --- | --- | --- |
| 1 | Engine geometry rendered, not invented | R-CAL-01, R-CAL-02, R-CAL-03, R-CAL-04 (FR-CAL-06/07/10/13) | A wrong or stale court silently corrupts tracking, rally, and score geometry; the previous defect was exactly this | Source review + controller tests + visual screenshot (default vs projected) + rejection path |
| 2 | Geometry payload safety | NR-CAL-01, security S-1/S-2 | Paint path now consumes service data; a malformed point must not draw a wrong court or stall the UI | Source review of the guard; controller `_isDrawable`; bounded dash loop |
| 3 | Save/update and invalidation unchanged | R-CAL regression set (FR-CAL-14/15/18/20/22) | The change touches the save surface indirectly; a regression here loses user data | Existing controller tests + facade tests + source review |
| 4 | One instruction line and no duplicate chrome | R-CAL-05 (FR-CAL-08/09) | The prior defect was a duplicated instruction block | Source review + screenshot |
| 5 | Design contract: bed, scrim, accent, motion, contrast | R-CAL-06, R-CAL-07, R-CAL-08, R-CAL-09 | Visual regressions are easy to ship unnoticed | Source review + contrast calculation + screenshots; no automated assertion |
| 6 | Documentation truthfulness | R-CAL-10, R-CAL-11, R-CAL-12 | A stale BRD is a false release gate | Source-vs-doc review; diff review |
| 7 | Ownership/release limitations | C-15, C-17 | Deferred, not exercised | Recorded; not tested here |

## 2. Strategy

### Levels used

| Level | What it covers | Tool |
| --- | --- | --- |
| Unit (existing) | Controller state: default court, drag offset, clamp, orientation, projection, rejection, save failure, reload | `app/test/calibration_controller_test.dart` |
| Widget (existing) | Handles, drag, orientation, rejection, incomplete save | `app/test/calibration_screen_test.dart` (2 stale rows) |
| Visual capture (existing) | Calibration default and projected surfaces at the reference window | `app/test/screenshots/media_screens_test.dart` + `tools/capture-app-screenshots.sh` |
| Engine (existing) | Validation, homography, net, side assignment | `cargo test -p sportcut-court` (20 tests) |
| Facade (existing) | Artifact write/read, missing calibration, idempotent save | `core/adapters/api/tests/facade.rs` |
| Static analysis | Dart correctness and lints | `flutter analyze` |
| Guard | No Rust/FFI in the app | `tools/check-no-rust-in-app.sh` |
| Manual/visual | The screenshot inspection by the developer | `calibration_default.png`, `calibration_projected.png` |

### Happy-path floor

Every changed component has at least one existing test or a source-verified
manual check: the controller (12 tests), the screen (4 of 6 pass; 2 stale), the
overlay (screenshots), the transport (screenshot + source), the tokens/metrics
(analyze + source).

### Deliberately not tested

- **No new test files or cases.** `CLAUDE.md` waives new tests absent an
  explicit request; the intent's Q4-A records this.
- **No repair of the two stale `FilledButton` screen tests.** They predate the
  change; repairing them needs a user request. They are recorded in BRD §7.
- **No real-footage accuracy run.** No labeled recording exists; S7-18 and
  R-CAL-2 stay open.
- **No golden-image/design-conformance assertion.** The screenshot suite
  captures the two states but compares nothing; recorded as a follow-up.
- **No service-owned catalog or release-transport test.** ADR-0001 Phase 3-4 is
  deferred.

## 3. Environments and data

| Item | Detail |
| --- | --- |
| Dart/widget runtime | Flutter SDK on `PATH` or `SPORTCUT_FLUTTER_BIN`; headless widget tests |
| Screenshot harness | `tools/capture-app-screenshots.sh` renders at the studio reference window and writes PNGs under `app/build/screenshots` (build output, not committed) |
| Engine | Rust workspace; `cargo test -p sportcut-court`, `cargo build --workspace` |
| Service | Development transport via `tools/run-macos.sh` for any live check; not required for the gates above |
| Fixtures | Synthetic geometry (`TRAPEZOID`), fake playback and fake engine in `app/test/support/fakes.dart`, generated media; no real footage, no production data |
| Network | None; all checks are offline |

## 4. Exit criteria

| Criterion | Threshold | Result |
| --- | --- | --- |
| `flutter analyze` | Zero issues | Pass |
| `tools/check-no-rust-in-app.sh` | OK | Pass |
| Controller tests | 12/12 | Pass |
| Screen tests | No new failure caused by this change; the 2 pre-existing stale lookups allowed | Pass (4 pass, 2 pre-existing failures) |
| Screenshot suite | All capture tests pass | Pass (21/21) |
| Visual check | Default shows no net; projected shows the engine outline and dashed net; transport bright; one plain instruction | Pass |
| Rust diff | Empty | Pass |
| Documentation | BRD 03/00 and protocol match the implementation; every Satisfied row has a source or recorded calculation | Pass |

Known-acceptable gaps: the two stale screen tests, the absent verification
record, the edge-clipped handle hit area, no golden-image assertion, and no
real-footage accuracy measurement. Each is recorded in BRD §7 and the review
record; none blocks this feature's scoped acceptance.

## 5. Recommendation

The plan is satisfied by existing tests plus the static, guard, screenshot, and
visual checks. Do not generate a new suite for this intent: the working
agreement waives it, and the riskiest path (engine geometry rendering) is
covered by the controller tests, the screenshots, and an adversarial code
review. Record the deferred test work as follow-ups for a dedicated quality
intent.
