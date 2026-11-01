# Test Suite — Player Tracking (Feature 04)

Status: Launch / Test Generation
Intent: `261031-implement-04-player`
Date: 2026-11-01
Inputs: `test-plan.md`, `source-changes.md`.

The plan's remaining cases were added in this stage: count-floor coverage and
`track_detections` determinism. The suite now records 18 unit tests plus the
opt-in acceptance harness.

## 1. Requirement → test → result

### `sportcut-vision` (9 tests)

| Requirement | Test | Result |
| --- | --- | --- |
| RQ-01 | `fragmentation_denominator_includes_unassociated_on_court_boxes` | Pass |
| RQ-01 | `fragmentation_share_is_zero_without_on_court_detections` | Pass |
| RQ-01 | `fragmentation_top_four_sums_the_four_largest_counts` | Pass |
| RQ-02 | `four_requires_supporting_frames_and_fraction` | Pass |
| RQ-02 | `four_is_unknown_when_the_support_floor_is_not_met` | Pass |
| RQ-10 | `track_detections_is_deterministic` | Pass |
| RQ-12 / FR-TRK-08 | `ambiguous_association_leaves_the_track_id_unset` | Pass |
| RQ-12 | `coverage_skips_a_gap_wider_than_the_frame_limit` | Pass |
| RQ-04 | `config_rejects_floors_and_bounds_below_policy` | Pass |

### `sportcut-rally` (6 tests, public `segment()`)

| Requirement | Test | Result |
| --- | --- | --- |
| RQ-12 / FR-RAL-11 | `short_rest_between_rallies_is_joined` | Pass |
| RQ-12 / FR-RAL-12 | `short_rally_is_demoted_to_rest` | Pass |
| RQ-12 | `spans_partition_the_recording_without_gaps` | Pass |
| RQ-12 / FR-RAL-10 | `insufficient_coverage_is_an_error_not_an_empty_result` | Pass |
| RQ-11 | `grid_over_the_limit_is_rejected_before_allocation` | Pass |
| RQ-10 | `segmentation_is_deterministic_for_identical_input` | Pass |

### `sportcut-api` (3 tests)

| Requirement | Test | Result |
| --- | --- | --- |
| RQ-04 | `short_lived_tracks_are_excluded_from_the_compact_input` | Pass |
| RQ-04 | `a_generation_with_only_short_tracks_is_rejected` | Pass |
| RQ-07 | `a_review_without_fragmentation_still_deserializes` | Pass |

### Client

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test test/screenshots/media_screens_test.dart` (4 tests) | Pass |
| Full client suite | 40 pre-existing failures, out of scope and recorded |

### Acceptance (opt-in, full reference)

| Requirement | Evidence | Result |
| --- | --- | --- |
| RQ-01 | Broad share 1,504/21,672 = 6.94% (613 identities) | **Fail** (60% gate) |
| RQ-02 | Unknown, 4.2% (156 supporting frames), evidence interval | Pass |
| RQ-03 | Artifact scan: no non-OnCourt IDs; positions inside the margin | Pass |
| RQ-04 | Every compact ID has ≥3 observations; short IDs retained in review | Pass |
| RQ-05 | 35 rallies, 112 s (15%), every candidate ≥1.5 s | Pass by count-fit |
| RQ-06 | Unset skips; set-but-missing assets fail | Pass |
| RQ-09 | Import 17.8 + tracking 64.8 + rally 1.5 = 84.1 s | Pass |
| RQ-07 | Old-artifact/response compatibility | Pass |

## 2. Commands

```bash
tools/verify-engine.sh
cd core && cargo clippy -p sportcut-api --features macos-tflite-eval \
  --all-targets -- -D warnings
cd app && flutter analyze
cd app && flutter test test/screenshots/media_screens_test.dart
SPORTCUT_TEST_VIDEO=/path/to/IMG_1308.MOV \
SPORTCUT_TEST_VIDEO_CORNERS='[[0.1802,0.9981],[0.8094,0.9981],[0.6938,0.3704],[0.4031,0.3704]]' \
cargo test -p sportcut-api --features macos-tflite-eval \
  --test real_footage -- --nocapture
```

## 3. Remaining gaps (recorded, not hidden)

- **RQ-01** fails the 60% gate; the shortfall is the central open item.
- **RQ-05** has no ground-truth labels; the 30–40 / 10–30% assertion is
  count-fit only.
- **RQ-12** still lacks a gap/resume unit case and a classification edge suite;
  the acceptance covers the happy path.
- **RQ-09** is enforced only in an optimized build or with
  `SPORTCUT_TEST_ENFORCE_BUDGET=1`; debug runs record the time.
- Cross-hardware TFLite determinism is not asserted; strict equality is at the
  pure-function level.
- The service asset path (C-16), the licensing guard (U6), and the BRD evidence
  update (U7) are outside this suite.
- The client's 40 pre-existing failures are unrelated and untriaged here.

## 4. Stability

No timing, randomness, network, or ordering dependence in the unit tests; the
acceptance harness uses fixed corners and a pinned model/runtime. The only
environment-sensitive result is the detector's cross-hardware output, recorded
as a measurement rather than a deterministic claim.
