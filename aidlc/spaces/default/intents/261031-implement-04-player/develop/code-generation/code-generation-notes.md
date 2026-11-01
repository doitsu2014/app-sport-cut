# Code Generation Notes — Player Tracking (Feature 04)

Status: Develop / Code Generation
Intent: `261031-implement-04-player`
Date: 2026-11-01

## Commands and results

| Command | Result |
| --- | --- |
| `cargo fmt --all` | Clean. |
| `cargo clippy -p sportcut-vision --all-targets -- -D warnings` | No issues. |
| `cargo clippy -p sportcut-api --features macos-tflite-eval --all-targets -- -D warnings` | No issues. |
| `cargo test -p sportcut-vision` | 4 passed (after the U3 revert). |
| `cargo test -p sportcut-rally` | 6 passed. |
| `cargo test -p sportcut-api track_artifact` | 1 passed. |
| `cd app && flutter analyze` | No issues. |
| `flutter test test/screenshots/media_screens_test.dart` | 4 passed. |
| `tools/verify-engine.sh` | Passed: layering, fmt, clippy, and the default test suites. |
| `tools/check-layering.sh` | Clean. |

## Acceptance measurements (full IMG_1308.MOV, 739.7 s)

Pinned definition: numerator = sum of the four largest per-ID observation
counts; denominator = every `OnCourt` detection, including ambiguous
`track_id: None` boxes.

| Run | Top-four | Share | Identities | Count quality | Notes |
| --- | --- | --- | --- | --- | --- |
| Baseline (before U3) | 1,504 / 21,672 | **6.94%** | 613 | 4.2% (156 frames) | Approved before value. |
| Baseline restored (after revert) | 1,504 / 21,672 | **6.94%** | 613 | 4.2% (156) | 35 rallies, 112 s (15%), 120.6 s total; fails only the 60% gate. |
| U3 attempt, margin 0.10 | 1,164 / 21,672 | 5.37% | 805 | 3.6% (133) | Regressed; margin was on the old cost scale. |
| U3 attempt, margin 0.03 | 1,366 / 21,672 | 6.30% | 659 | 3.1% (114) | Scale-corrected; still below baseline. |
| Trimmed 120 s, margin 0.03 | 1,020 / 3,816 | 26.7% | 96 | 1.3% (8) | Not representative of the full reference. |

The full-reference test fails at the count-quality non-regression guard
(3.1% < 4.2%) before reaching the 60% share gate; the recorded share would also
fail (6.30% < 60%). The 60% target is **unmet**.

## Decision (2026-11-01)

The user chose to **revert U3 and keep the rest**. The association rewrite,
its three configuration fields, DTO/conversion mappings, and its two unit tests
were removed. U1 (metric), U2 (hardened test), U4 (validation/client), and U5
(remaining unit tests) stay. The acceptance test now records the restored
baseline (6.94%, 613 identities, 4.2% count quality, 35 rallies / 15% active,
120.6 s) and still fails the RQ-01 60% gate; that failure is the recorded
shortfall, not a regression.

**Chosen gate option:** option 1 (revert U3; keep the measurement, hardened
test, validation, client correctness, and unit tests). RQ-01 remains unmet and
needs a follow-up (calibration accuracy, detection gating, or trajectory
stitching with sign-off).

## Interpretation

- The association hypothesis is falsified on the full recording under the pinned
  metric. The cap/prediction/freshness ordering did not consolidate the four
  players; it slightly increased identity count and reduced the count evidence.
- The trimmed window's 26.7% shows the approach can help locally, but it does not
  generalize across the full match, so it is not evidence for keeping it.
- The venue's extra on-court detections (5.86 per frame) put a hard ceiling on a
  four-identity share: four flawless identities can cover at most roughly 68% of
  the denominator. Reaching 60% requires near-complete association of the real
  players and near-zero ID switching.
- Possible causes not retired: the hand-measured corners include boundary people;
  the detector confidence floor (0.2) admits background boxes; the association
  gate/penalty defaults are placeholders. Each is a separate follow-up, not a
  reason to keep the regressing change.

## Deviations from the specification

1. `ambiguity_margin` was re-scaled from 0.10 to 0.03 for the diagnostic run
   because the evidence measure's units changed. Both the field and the
   measure were removed with the U3 revert.
2. The diagnostic association overrides were removed with U3. The only
   remaining test affordance is `SPORTCUT_TEST_KEEP`.
3. The count-quality non-regression guard fired before the share gate; the early
   fragmentation print was added and the track gates were moved after the rally
   measurement so a failing share still produces the full evidence line.
4. U6 (licensing guard) and U7 (docs/evidence) are paused by the stop rule.
5. U3 was reverted after the failed checkpoint. The approved architecture,
   API-contract, and technical-spec records carry a dated revision note, and
   the source-changes rows were corrected. The raw-detection floor, count-frame
   guard, optional audio map, and missing unit cases were added in the review
   pass.

## Decision required at the gate

1. **Revert the U3 behaviour** (recommended): remove the prediction/freshness/
   tentative association path and the new defaults, keep U1 (metric), U2
   (hardened test), U4 (validation/client), and U5 (tests for the remaining
   behaviour). Record RQ-01 as unmet with the 6.94% baseline.
2. **Keep U3 with a revised target**: accept 6.30% and change RQ-01, which needs a
   BRD/requirements change and does not justify the count-quality regression.
3. **Follow-up intent**: calibration accuracy, detector gating, or trajectory
   stitching as a separate feature. Stitching still needs product sign-off and
   the full-OnCourt gap gate.

No option reaches 60% within this intent without new evidence.
