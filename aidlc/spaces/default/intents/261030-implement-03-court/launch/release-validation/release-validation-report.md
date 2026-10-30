# Release Validation Report — Court Calibration (Feature 3)

Status: Launch / Release Validation
Intent: `261030-implement-03-court`
Date: 2026-10-30
Release candidate: working tree on base commit `025634b`, 18 changed/added paths
under `app/`, `docs/`, and `design-system/` plus the intent record. Not committed.

## 1. Full verification re-run

| Check | Command | Result |
| --- | --- | --- |
| Engine format, lint, tests | `tools/verify-engine.sh` | **Passed** (cargo fmt --check, clippy, workspace tests) |
| Client static analysis | `cd app && flutter analyze` | **No issues found** |
| No-Rust guard | `tools/check-no-rust-in-app.sh` | **OK** |
| Controller tests | `flutter test test/calibration_controller_test.dart` | **12/12 passed** |
| Screen tests | `flutter test test/calibration_screen_test.dart` | 4 passed; 2 **pre-existing** failures (`FilledButton` lookups) |
| Screenshot suite | `tools/capture-app-screenshots.sh` | **21/21 passed**, 40 PNGs |
| Visual inspection | `calibration_default.png`, `calibration_projected.png` | Default: no net, plain band, neutral transport. Projected: engine outline + dashed net, bright transport |
| Rust diff | `git diff -- core` | **Empty** |

## 2. Requirement coverage

| Requirement | Status | Evidence |
| --- | --- | --- |
| R-CAL-01 engine outline | Covered | Source review; screenshot `calibration_projected`; review F2 verified paint order |
| R-CAL-02 engine net + orientation | Covered | Source review (`geometry.net`); controller test `changing the orientation re-projects`; screenshot |
| R-CAL-03 no net before projection | Covered | Screenshot `calibration_default`; controller test `an uncalibrated match opens with the starting court` |
| R-CAL-04 clear on rejection | Covered | Controller test `a court the engine rejects is reported and nothing is drawn`; source review |
| R-CAL-05 one plain instruction | Covered | Source review (band, no pill, no panel paragraph/hints); screenshot |
| R-CAL-06 bed/scrim/contrast | Covered | Recorded calculation (≈3.7:1 graphics, ≈18:1 band); source review; screenshot |
| R-CAL-07 accent isolation | Covered | Source review (`accent` flag; drag-gated signal); screenshot (neutral transport) |
| R-CAL-08 ease token + metrics | Covered | `flutter analyze`; source review |
| R-CAL-09 motion + reduced motion | Covered | Source review (`ScMotion`, `easeStandard`, 70 % exit); no looping animation |
| R-CAL-10 Cancel documented | Covered | BRD §4 matches the rendered control and wiring |
| R-CAL-11 BRD reconciliation | Covered | Diff review; docs-vs-code review pass |
| R-CAL-12 protocol docs | Covered | Diff review; one-step save wording and token example corrected |
| NR-CAL-01 no engine change | Covered | `git diff -- core` empty; `verify-engine.sh` passes |
| NR-CAL-02 no dependency/raw hex | Covered | No `pubspec.yaml` change; no raw hex in touched calibration files |
| NR-CAL-03 offline | Covered | Source review; no new I/O |
| NR-CAL-04 no FFI/Rust/durable state | Covered | `check-no-rust-in-app.sh` OK |
| NR-CAL-05 analyze clean | Covered | No issues |
| NR-CAL-06 existing tests not broken | Covered | Controller 12/12; the two screen failures predate the change |

No must-have requirement is uncovered. Out-of-scope rows (NFR-CAL-04, ARCH:*
ownership, real-footage accuracy) remain deferred and recorded.

## 3. Operational readiness

- **Rollback:** revert the merge commit; no data migration, the artifact schema
  and the v5 catalog column are unchanged. Rollback not exercised (no staging).
- **Health/readiness:** the runbook defines ready/healthy/not-ready signals.
- **On-call watch:** none (local desktop app, no service deployment). The first
  thing to watch after merge is the packaged-service path: it is blocked on
  ADR-0001 Phase 3/4 because a release service rejects `matchDir`.

## 4. Known issues and accepted gaps

1. **Packaged-service path blocked.** A release service rejects the client's
   `matchDir`; calibration works only over the development transport until
   ADR-0001 Phase 3/4 (C-15). This is the main release caveat.
2. **Two stale screen tests** (`FilledButton` lookups) fail on HEAD; recorded,
   not repaired under the working agreement.
3. **No golden-image/design assertion**; the screenshot suite captures without
   comparing.
4. **No real-footage accuracy measurement** (S7-18 / R-CAL-2 open).
5. **Edge-clipped handle hit area** at a frame edge; pre-existing, recorded.
6. **Absolute path/status details:** the BRD area stays **Partial**; this
   feature closes its scoped functional and design rows but does not claim the
   area is Done.

## 5. Recommendation

**Go with known issues**, scoped to merging the client feature into `main`. The
must-have requirements are covered, the engine gate is green, the client gates
are green, and the remaining issues are recorded with owners. Do **not** treat
this as release approval for a packaged macOS build: item 1 blocks the packaged
path, and item 4 leaves accuracy unmeasured.

## 6. Human release gate

The release decision belongs to the human. Awaiting an explicit decision:

- **Go** — merge the client feature, keep the listed issues open.
- **Go with conditions** — name the conditions (for example, unblock Phase 3
  before packaging).
- **No-go** — return to Develop with the reason.
