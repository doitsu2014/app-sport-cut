# Technical Specification — Player Tracking (Feature 04)

> **Revision 2026-11-01 — U3 reverted.** The continuity-aware association
> design (prediction, capped gate, plausibility/ranking split, tentative
> tracks) and its three configuration fields were implemented and reverted
> after the full-reference checkpoint failed. Sections 2.1 (association
> rewrite) and the U3 parts of 2.3/2.4 do not ship; the metric (2.2), client
> (2.5), acceptance hardening (2.6), unit tests (2.7), and validation floors
> remain in force.

Status: Ideate / Technical Specification
Intent: `261031-implement-04-player`
Date: 2026-10-31
Inputs: `architecture-doc.md`, `design-decisions.md`, `api-contract.md`,
`requirements.md`.

## 1. Requirement traceability

| Requirement | Component(s) | Interface(s) | Test approach |
| --- | --- | --- | --- |
| RQ-01 top-four ≥ 60% | `tracking.rs` association + summary | `FragmentationSummary`; artifact `review.fragmentation` | Unit definition test; continuity test; ambiguity-denominator test; real-footage gate with floors |
| RQ-02 count floor 60% | `tracking.rs::assess_count`; `dto.rs`; `tracking_panel.dart` | `PlayerTracksDto.countSupportingFrames` | Count-floor unit tests; client label test; artifact assertion |
| RQ-03 spectator rejection | `court_candidates.rs`; `track_artifact.rs` | Artifact review/input | Artifact scan (no non-OnCourt IDs; positions in margin) |
| RQ-04 compact filter | `track_artifact.rs` | `input.positions` | Artifact unit test; real-footage scan |
| RQ-05 rally yield | `sportcut-rally` (unchanged); `real_footage.rs` | `engine.rally.start/suggestions` | Acceptance assertions 30–40 / 10–30% / min duration |
| RQ-06 automation | `real_footage.rs` | — | Unset skips; set-but-missing fails |
| RQ-07 artifact contract | `track_artifact.rs`; `dto.rs`; protocol note | Schema 1; optional fields | Old-artifact fixture; existing facade tests |
| RQ-08 offline/ownership | All | — | Layering, no-Rust guard, dependency scan |
| RQ-09 300 s | `real_footage.rs` | — | Per-stage timing; env/optimized assertion |
| RQ-10 determinism | `tracking.rs`; `rally/src/lib.rs` | Pure functions | Two-run strict equality |
| RQ-11 bounded grid | `rally/src/lib.rs` | — | Grid-cap unit test (boundary included) |
| RQ-12 unit tests | vision/rally/track-artifact | — | Named cases below |

## 2. Component specifications

### 2.1 Association engine (`core/use-cases/vision/src/tracking.rs`)

**State**

```rust
struct ActiveTrack {
    id: u64,
    last_ms: i64,
    ground: CourtPoint,          // or ImagePoint ground, per existing type
    velocity: Option<(f64, f64)>, // per second, from the last two observations
    bbox: BoundingBox,
    side: Option<CourtSide>,
    observations: usize,
    missing_since: Option<i64>,
}
```

**Per-frame algorithm** (deterministic; no HashMap order in output)

1. Resolve the calibration; on a calibration-start change, clear active tracks
   and start a new coverage segment.
2. Classify detections (`OnCourt` only can be tracked; `Borderline`/`OffCourt`/
   `LowConfidence`/`MissingCalibration`/`ProjectionFailed`/`InvalidBox` keep no
   ID).
3. For each `OnCourt` person, consider only tracks whose residual passes the
   gate: `residual <= min(max_ground_speed_per_second * elapsed_s,
   max_association_radius)`, where `residual` is the distance to the predicted
   point when `prediction_enabled` and `elapsed <= max_frame_gap_ms`, otherwise
   to the last ground point.
4. Compute `plausibility = residual / max_ground_speed_per_second +
   side_penalty + overlap_penalty`.
5. **Ambiguity:** if at least two gate-passing tracks exist and
   `second_best_plausibility - best_plausibility <= ambiguity_margin`, mark the
   person `association_ambiguous = true`, assign no ID, and spawn no track. The
   person still counts in the fragmentation denominator.
6. **Assignment:** build edges for non-ambiguous people; sort by
   `(tier, assignment_cost, track_id)` where tier is fresh-confirmed (0),
   lost-confirmed (1), tentative (2); `assignment_cost = plausibility +
   stale_track_penalty_per_second * elapsed_s`. Assign greedily, one person per
   track and one track per person.
7. A resume within `max_track_gap_ms` closes exactly one gap and keeps the ID;
   an absence beyond it evicts the track and the next sighting creates one new
   ID. A track is tentative while `observations < min_track_observations`.
8. After all frames: compute coverage, count, and the fragmentation summary.

**Invariants**

- An ambiguous detection always has `track_id == None` and spawns no track
  (FR-TRK-08). Ranking terms never feed the ambiguity comparison.
- Only `OnCourt` detections receive IDs.
- One gap record per absence; calibration changes never carry IDs.
- Output order derives from frame order; the top-four selection sorts
  deterministically.

**Configuration** (all optional, serde-defaulted):
`max_association_radius` (0.25, `0 < r <= 0.5`),
`stale_track_penalty_per_second` (0.5, finite `>= 0`),
`prediction_enabled` (true).

**Errors:** none new. Invalid configuration remains `InvalidInput`; the
boundary rejects below-floor values as `invalid_params`.

**Performance:** `O(people × active_tracks)` per frame; the active set is bounded
by `max_track_gap_ms`; no new allocation per frame beyond the edge list.

### 2.2 Fragmentation summary

Computed once at the end of `track_detections`:

- `raw_detections` = detections with confidence `>= min_confidence`, before the
  court decision.
- `on_court_detections` = people with `decision == OnCourt`, including
  `track_id: None`.
- `distinct_tracks` = unique non-null IDs.
- `top_four_observations` = sum of the four largest per-ID observation counts,
  sorted by count desc then ID asc.
- `top_four_share` = `top_four_observations / on_court_detections`, or `0.0`
  when the denominator is zero or fewer than four IDs exist.

Stored as `Option<FragmentationSummary>` on `TrackingResult` with a serde
default; the artifact embeds it in `review`.

### 2.3 Artifact adapter (`core/adapters/api/src/track_artifact.rs`)

- Keep the short-fragment filter (`observations < min_track_observations` →
  excluded from `input.positions`, retained in `review`).
- Carry `review.fragmentation` through unchanged.
- Keep schema 1 and the atomic publish sequence (non-final → temp → rename →
  final).
- Old artifacts without `fragmentation` or the new config fields deserialize
  with defaults.

### 2.4 DTO and boundary validation (`dto.rs`, `convert.rs`, facade)

- Add optional `track_quality` and `count_supporting_frames` to
  `PlayerTracksDto`; copy from the embedded review.
- Add the three config fields with serde defaults.
- Reject `min_count_fraction < 0.60` and `min_track_observations < 3` with
  `invalid_params` and the contract messages; reject the new config bounds.
- Record effective values in provenance (already automatic).

### 2.5 Client (`tracking_panel.dart`, `models.dart`, `player_tracking_providers.dart`)

- Rename “Coverage” to “Count quality”; render `Unknown` with quality,
  supporting frames, and evidence interval.
- Parse optional DTO fields; older responses omit them.
- Remove the dead `InferenceAssets` resolve/pass of `runtimePath`/`modelPath`.
- Update the screenshot test's expected label.

### 2.6 Acceptance test (`core/adapters/api/tests/real_footage.rs`)

- Unset `SPORTCUT_TEST_VIDEO` → skip. Set but not a file, or set but runtime/
  model missing → fail with the fetch instruction, never skip.
- Read the published artifact and `match_player_tracks`.
- Recompute the broad top-four share from `review.frames`; assert it equals the
  engine summary; assert `>= 0.60`.
- Assert denominator floors: `on_court_detections >= 20_000` and per-frame mean
  in 5–9; numerator shape: both sides in the top four, no ID over 40% of the
  top-four observations; count quality not below 4.2%.
- Assert RQ-02, RQ-03, RQ-04; RQ-05: 30–40 candidates, 10–30% active, every
  candidate `>= min_rally_ms` on the full reference.
- Print per-stage and total elapsed; assert `<= 300 s` only with
  `SPORTCUT_TEST_ENFORCE_BUDGET=1` or an optimized build.
- A trimmed development run asserts only the active fraction and minimum
  duration, not the 30–40 count.

### 2.7 Unit tests (S3)

Vision: ambiguity unset-ID (fresh vs stale), continuity across frames,
ground-speed rejection, one gap + one resume, calibration reset, coverage
interval gaps, count floor/Unknown, quality definition, config validation,
determinism. Rally: short-rest join, short-rally discard, coverage error,
candidate-per-span, hysteresis, gap skip, unknown bins, grid cap, generation ID,
validation, determinism. Track artifact: short-fragment filter with review
retention. Client: count-quality label and Unknown evidence.

### 2.8 Licensing guard (S2)

`tools/embed-inference-assets.sh` (and/or `preflight.sh`) fails when
`models/efficientdet-lite0-task-int8/MODEL.md` and the register in
`docs/brd/00-product-context.md §11.2` disagree or the verdict is not
`shippable`. Fix the missing `docs/external-dependencies.md` reference.

## 3. Cross-cutting concerns

- **Security:** offline only; no new dependency; no FFI/Rust in the app; no new
  client durable state; the service keeps asset ownership and rejects client
  paths; the Unix socket boundary is unchanged.
- **Observability:** the fragmentation summary and count evidence are the
  measurement surface; the acceptance test prints them. No telemetry.
- **Performance:** tracking remains `O(people × tracks)`; the full reference run
  stays under the 300 s budget on the development Mac.
- **Data lifecycle:** the track artifact is regenerable; user-authored rallies,
  scores, and clips are never touched; stale inputs are rejected.

## 4. Work breakdown seeds (dependency order)

| Unit | Scope | Depends on | Estimate |
| --- | --- | --- | --- |
| U1 | Fragmentation summary + artifact/DTO plumbing + metric definition tests | — | 1 day |
| U2 | Association: prediction, gate, plausibility, ranking, tentative lifecycle | U1 | 2 days |
| U3 | Boundary validation (floors + new bounds) + client label/cleanup | U1 | 0.5–1 day |
| U4 | Acceptance test hardening (fail-not-skip, RQ-01..RQ-05, floors, timing) | U1, U2 | 1 day |
| U5 | Unit tests (vision, rally, artifact, client) | U2, U3 | 1–2 days |
| U6 | Licensing guard + reference fixes (S2) | — | 0.5 day |
| U7 | BRD/protocol evidence updates, commit the test and records | U4, U6 | 0.5 day |

Re-measurement checkpoint after U2/U4: if the broad share is below 60%, stop and
record the shortfall; do not move the denominator or add stitching.

## 5. Gate decisions

- Approve the specification, including the unit ordering and the stop condition.
- Confirm that the acceptance test runs the full reference (not a trimmed clip)
  for the 30–40 / 10–30% assertions.
