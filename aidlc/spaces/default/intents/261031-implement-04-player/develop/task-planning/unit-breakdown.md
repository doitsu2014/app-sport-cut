# Unit Breakdown — Player Tracking (Feature 04)

Each unit is a vertical, review-sized slice. Sizes: S ≤ 0.5 day, M ≤ 1.5 days,
L ≤ 3 days. Dependencies are hard prerequisites unless stated.

## U1 — Pin the fragmentation metric and plumb it through

- **Requirements:** RQ-01, RQ-07, RQ-10 (input side)
- **Size:** M
- **Depends on:** none
- **Files:** `core/use-cases/vision/src/tracking.rs`,
  `core/adapters/api/src/track_artifact.rs`, `core/adapters/api/src/dto.rs`,
  `core/adapters/api/src/convert.rs`
- **Work:** add `FragmentationSummary` (raw, on-court, distinct, top-four,
  share) with a deterministic `(count desc, id asc)` top-four sort; add
  `TrackingResult.fragmentation: Option<_>` with serde default; carry it into
  `review`; add optional `trackQuality` and `countSupportingFrames` to
  `PlayerTracksDto`; document the additive fields.
- **Acceptance:** a hand-built `TrackingResult` yields the expected summary
  including `track_id: None` in the denominator; an old artifact without
  `fragmentation` deserializes; an old `engine.tracks.window` response parses.
- **Verification:** new unit tests; `cargo test`; old-artifact fixture.

## U2 — Harden the real-footage acceptance test (S1b)

- **Requirements:** RQ-01..RQ-06, RQ-09
- **Size:** M
- **Depends on:** U1
- **Files:** `core/adapters/api/tests/real_footage.rs`
- **Work:** distinguish unset from set-but-missing; fail (not skip) when the
  video is set but the file/runtime/model is missing; read the published
  artifact; recompute the broad share and assert it equals the engine summary;
  assert the denominator floor and per-frame band, the numerator side/dominance
  check, count quality non-regression, RQ-02/RQ-03/RQ-04, and RQ-05 (full
  reference); print per-stage timing; enforce 300 s only with
  `SPORTCUT_TEST_ENFORCE_BUDGET=1` or an optimized build; support trimmed
  development windows with relaxed rally assertions.
- **Acceptance:** on the current tracks the test records the **pinned before
  value** and prints every metric; a run with the env set but assets missing
  fails; an unset env skips.
- **Verification:** run the acceptance command twice (unset, set).

## U3 — Continuity-aware association (architecture option A)

- **Requirements:** RQ-01, RQ-02, RQ-10, RQ-12
- **Size:** L
- **Depends on:** U2 (the before measurement)
- **Files:** `core/use-cases/vision/src/tracking.rs`,
  `core/adapters/api/src/dto.rs`, `core/adapters/api/src/convert.rs`
- **Work:** `ActiveTrack` velocity; prediction within `max_frame_gap_ms`; gate
  `residual <= min(speed × elapsed, max_association_radius)`; plausibility
  (ranking-independent) for ambiguity; assignment by freshness tier then
  `plausibility + stale_penalty × elapsed`; tentative tracks; one gap per
  absence; calibration reset unchanged; three optional config fields with serde
  defaults and validation.
- **Acceptance:** the fresh-vs-stale case is ambiguous (`track_id: None`); a
  continuous player keeps one ID; the broad share is measured on the full
  reference. If the share is below 60%, **stop and record** — do not move the
  denominator, reclassify detections, or add stitching.
- **Verification:** acceptance run; unit cases; `tools/verify-engine.sh`.

## U4 — Boundary validation and client correctness

- **Requirements:** RQ-02, RQ-04, FR-TRK-16
- **Size:** S
- **Depends on:** U1
- **Files:** `core/adapters/api/src/convert.rs` (or facade),
  `app/lib/src/features/tracking/presentation/tracking_panel.dart`,
  `app/lib/src/bridge/models.dart`,
  `app/lib/src/features/tracking/presentation/player_tracking_providers.dart`,
  `app/test/screenshots/media_screens_test.dart`
- **Work:** reject `minCountFraction < 0.60` and `minTrackObservations < 3`
  with `invalid_params`; validate the new config bounds; rename “Coverage” to
  “Count quality”; render Unknown with quality/supporting frames/evidence;
  parse optional DTO fields; remove the dead `InferenceAssets` path passing.
- **Acceptance:** below-floor requests fail with the contract messages; the
  panel shows the correct label and Unknown evidence; the screenshot test
  asserts the new label; `flutter analyze` is clean.
- **Verification:** facade tests; client test; `flutter analyze`.

## U5 — Unit tests (S3)

- **Requirements:** RQ-12, RQ-10, RQ-11
- **Size:** M
- **Depends on:** U3, U4
- **Files:** `core/use-cases/vision/src/tracking.rs`,
  `core/entities/rally/src/lib.rs` / `suggestions.rs`,
  `core/adapters/api/src/track_artifact.rs`,
  `app/test/` (tracking panel)
- **Work:** vision cases (ambiguity unset-ID fresh-vs-stale, continuity,
  ground-speed rejection, one gap + one resume, calibration reset, coverage,
  count floor/Unknown, quality, config validation, determinism); rally cases
  (short-rest join, short-rally discard, coverage error, candidate-per-span,
  hysteresis, gap skip, unknown bins, grid cap boundary, generation ID,
  validation, determinism); artifact filter test; client label test.
- **Acceptance:** every named case exists and passes; `tools/verify-engine.sh`
  is green; the ambiguity case proves FR-TRK-08.
- **Verification:** `tools/verify-engine.sh`, targeted `cargo test`, Flutter test.

## U6 — Licensing guard (S2)

- **Requirements:** RQ-08 (licensing gate)
- **Size:** S
- **Depends on:** none (parallel)
- **Files:** `tools/embed-inference-assets.sh` (and/or
  `tools/preflight.sh`), `models/efficientdet-lite0-task-int8/MODEL.md`,
  `docs/brd/00-product-context.md` §11.2, `docs/external-dependencies.md`
- **Work:** reconcile the EfficientDet verdict to one shippable value; fix the
  missing reference; add a guard that fails when MODEL.md and the register
  disagree or the verdict is not shippable.
- **Acceptance:** the guard fails on the current contradictory state and passes
  after reconciliation; no model bytes are committed.
- **Verification:** run the guard in both states.

## U7 — Evidence and docs

- **Requirements:** RQ-07, RQ-01..RQ-05 evidence
- **Size:** S
- **Depends on:** U2, U3, U4, U5, U6
- **Files:** `docs/brd/04-player-tracking.md`, `docs/brd/05-rally-review.md`,
  `docs/architecture/protocol.md`, intent records
- **Work:** record the pinned metric definition, before/after values, count
  outcome, rally yield, the documentation-only protocol note, and the S2
  verdict; commit `real_footage.rs` and the intent records.
- **Acceptance:** the BRD evidence tables cite the measured values and the test
  command; the working tree contains the test and records.
- **Verification:** review; `git status`.

## Critical path and checkpoints

`U1 → U2 → U3 (re-measure) → U4 → U5 → U7`, with `U6` in parallel.
The stop condition sits between U3 and U4: a broad share below 60% ends the
association work and records the shortfall.

## Deferred

- Trajectory stitching (option B) — only after U3 falls short and with product
  sign-off.
- Detector/re-ID change (option D).
- RQ-05 ground-truth labelling (S4) — a documented spot-check is the fallback.
