# Source Changes — Player Tracking (Feature 04)

Status: Develop / Code Generation
Intent: `261031-implement-04-player`
Date: 2026-11-01

The implementation was executed unit by unit. U1, U2, U4 and U5 are complete and
verified. U3 (continuity-aware association) was implemented and measured, and
**failed its checkpoint**: the pinned RQ-01 share regressed instead of reaching
60%. At the user's direction U3 was **reverted**; its code, config fields, and
tests are no longer in the working tree. U6 and U7 are paused by the approved
stop rule.

## U1 — Fragmentation metric and plumbing (complete)

| File | Change |
| --- | --- |
| `core/use-cases/vision/src/tracking.rs` | `FragmentationSummary`; `TrackingResult.fragmentation: Option<_>` with serde default; `fragmentation_summary` computed once with a deterministic `(count desc, id asc)` top-four sort. |
| `core/use-cases/vision/src/lib.rs` | Export `FragmentationSummary`. |
| `core/adapters/api/src/dto.rs` | `TrackQualityDto`; optional `PlayerTracksDto.track_quality` and `count_supporting_frames`. |
| `core/adapters/api/src/convert.rs` | Config mapping; `TrackQualityDto` conversion; the window DTO copies the summary and supporting-frame count. |

Unit tests: denominator includes ambiguous `track_id: None` boxes; zero
denominator yields share 0; top-four ties break by ID.

## U2 — Hardened acceptance test (complete)

`core/adapters/api/tests/real_footage.rs`

- Unset `SPORTCUT_TEST_VIDEO` skips; set but missing path/runtime/model **fails**
  with the fetch instruction.
- Reads the published `TrackArtifact`; recomputes the broad RQ-01 definition and
  asserts it equals the engine summary.
- Asserts RQ-02 count evidence, RQ-03 tracked points, RQ-04 short-track
  exclusion, and RQ-05 (30–40 rallies, 10–30% active) on the full reference.
- Denominator floor, per-frame band, top-four side/dominance checks, and count
  quality non-regression.
- Prints per-stage and total timing; enforces 300 s in an optimized build or with
  `SPORTCUT_TEST_ENFORCE_BUDGET=1`.
- Diagnostic affordance: `SPORTCUT_TEST_KEEP` keeps the match directory for
  inspection after a failed measurement.

## U3 — Continuity-aware association (reverted)

The association rewrite (velocity prediction, capped gate, plausibility/ranking
split, tentative tracks) was implemented, measured, and reverted at the user's
direction after it failed the checkpoint. Its three `TrackingConfig` fields,
DTO fields, conversion, and unit tests were removed. FR-TRK-08's existing
unset-ID behaviour is unchanged. The measurement is preserved in
`code-generation-notes.md`.

**Measured result:** see `code-generation-notes.md`. The full-reference share
fell from 6.94% (baseline) to 6.30% at the corrected margin, with count quality
3.1% versus 4.2%.

## U4 — Boundary validation and client correctness (complete)

| File | Change |
| --- | --- |
| `core/use-cases/vision/src/tracking.rs` | `TrackingConfig::validate` rejects `min_track_observations < 3` and `min_count_fraction < 0.60`. |
| `app/lib/src/features/tracking/presentation/tracking_panel.dart` | “Coverage” → “Count quality”; Unknown renders supporting frames and the evidence interval. |
| `app/lib/src/bridge/models.dart` | `TrackQualityDto`; optional `countSupportingFrames` and `trackQuality` parsing/serialization. |
| `app/lib/src/features/tracking/presentation/player_tracking_providers.dart` | Removed the dead `InferenceAssets` resolve and ignored runtime/model paths. |
| `app/test/screenshots/media_screens_test.dart` | Expects “Count quality”. |

`flutter analyze` clean; the media screenshot suite passes (4 tests).

## U5 — Unit tests (complete for the implemented behaviour)

- `sportcut-vision`: 4 tests (fragmentation definition ×3, config floors).
- `sportcut-rally`: 6 tests (short-rest join, short-rally discard, partition,
  coverage error, grid cap, determinism).
- `sportcut-api`: 1 test for the short-track filter retaining review evidence;
  the all-filtered error path and old-artifact deserialization are covered by
  the review fixes.

The FR-TRK-08 fresh-vs-stale and capped-gate tests were removed with U3; a
U3-independent ambiguity regression test now asserts that two equally plausible
tracks leave `track_id` unset.

## Rally threshold retune (kept)

`app/lib/src/features/rally/presentation/rally_review_providers.dart` changes
`enterMotionPerSecond` 4.0 → 3.5 and `exitMotionPerSecond` 2.0 → 1.5. On the
reference it yields 35 rallies / 112 s (15%), matching the BRD 05 baseline.
Recorded here because it was bundled into this intent; it traces to BRD 05.

## U6 / U7 — Paused

The licensing guard (S2) and the BRD/protocol evidence updates are not started;
the stop rule fired before them. They remain required for Done.

## Not committed

All changes are in the working tree for review. No commit was made.
