# Requirements — Implement 04 Player Tracking

Source of truth for the shared identifiers is
[`docs/brd/04-player-tracking.md`](../../../../../../../docs/brd/04-player-tracking.md).
These requirements narrow that BRD to the gaps this intent closes; they do not
replace it.

## Reference measurement (before)

Full `IMG_1308.MOV`, 739.7 s, courts marked with the approved corners, tracking
at 5 fps, rally thresholds 4.0 / 2.0:

| Measure | Before |
| --- | --- |
| Distinct track IDs | 613 |
| Top four tracks' share of observations | 8.7% |
| Count / quality | Unknown / 4.2% |
| On-court detections per frame | 5–9 |
| Rally candidates | 15 (46 s, 6%) |

## Functional requirements

| ID | Requirement | Priority | Source | Acceptance criterion | Verification |
| --- | --- | --- | --- | --- | --- |
| RQ-01 | Track continuity: the four longest tracks account for a majority of on-court observations on the reference recording. | Must | Intent §1, §2; BRD 04 FR-TRK-08 | Top-four share is at least 60% of positions (before: 8.7%), and the real-footage test records the share. | Track artifact + real-footage test |
| RQ-02 | Count confidence: `Four` is reported only when at least 60% of sampled frames support the per-side layout. | Must | Approved intent decision; BRD 04 FR-TRK-10, FR-TRK-11 | The artifact reports `Four` with quality ≥ 60%, or `Unknown` with its quality, supporting frames, and evidence interval. No unqualified count. | Track artifact + review panel |
| RQ-03 | Spectator rejection: no tracked position falls outside the marked court plus the configured margin. | Must | BRD 04 FR-TRK-06 | Zero tracked positions with `u` or `v` outside `[-court_margin, 1 + court_margin]`; off-court and borderline detections remain in review evidence only. | Artifact scan + real-footage test |
| RQ-04 | Compact-input noise filter: positions from tracks seen fewer than `min_track_observations` times never enter the rally input. | Must | Approved intent decision | Every `input.positions` track ID has at least 3 observations; `review.frames` still carries every detection and decision. | `track_artifact` test + artifact check |
| RQ-05 | Rally yield follows from the cleaner tracks: the reference recording yields 30–40 rallies covering 10–30% of its duration. | Must | BRD 05 FR-RAL-09..12; intent §1 | Real-footage test reports 30–40 candidates, 10–30% active time, every candidate ≥ `min_rally_ms`. | Real-footage test |
| RQ-06 | Real-footage automation: one opt-in test runs import → calibration → tracking → rally on a supplied recording and asserts RQ-01..RQ-05. | Must | User request; intent §2 | With `SPORTCUT_TEST_VIDEO` set the test runs and passes; without it, it skips and the default suite is unchanged. | `cargo test -p sportcut-api --features macos-tflite-eval --test real_footage` |
| RQ-07 | Preserve the existing artifact contract: schema version 1, atomic publication, stale-input rejection, cancellation. | Must | BRD 04 FR-TRK-13, FR-TRK-14, FR-TRK-20; BRD 05 FR-RAL-05..07, FR-RAL-13 | Existing tests stay green; a rerun with identical inputs produces the same `generation_id` and spans. | `tools/verify-engine.sh` |
| RQ-08 | No new offline or ownership violation. | Must | BRD 04 FR-TRK-27, FR-TRK-28; CLAUDE.md guardrails | No network call, no new dependency, no Rust in the app, no new durable client state. | `tools/check-layering.sh`, `tools/check-no-rust-in-app.sh`, review |
| RQ-12 | Focused unit tests cover association continuity, coverage intervals, and segmentation edges. | Must | Approved requirements decision; BRD 04 §2.3, BRD 05 §3.3 | Tests exist in `sportcut-vision` and `sportcut-rally` and pass in `tools/verify-engine.sh`; each named edge has a case. | `tools/verify-engine.sh` |

## Non-functional requirements

| ID | Requirement | Priority | Acceptance criterion | Verification |
| --- | --- | --- | --- | --- |
| RQ-09 | Full reference analysis completes within 5 minutes on the development Mac. | Should | Import + tracking + rally wall time ≤ 300 s (before: 90 s in-test, 4 min with shell orchestration). | Test timing |
| RQ-10 | Deterministic output for identical inputs and configuration. | Must | Same tracks + config produce the same `generation_id` and candidate spans. | Rerun comparison |
| RQ-11 | Bounded analysis work. | Must | Segmentation rejects more than 1,000,000 bins before allocating. | `sportcut-rally` unit test |

## Constraints and assumptions

- The approved reference recording and corners are fixed for acceptance; other
  footage must supply its own corners.
- FR-TRK-08's ambiguity rule stays: an ambiguous association leaves the track ID
  unset. Continuity is improved by making associations less ambiguous, not by
  hiding ambiguity.
- The detector and runtime stay pinned; no model retraining. The detector
  confidence floor stays at 0.2 for this intent and is re-measured only after
  the association-continuity change lands.
- Focused unit tests for association, coverage, and segmentation are in scope
  (RQ-12); the real-footage test remains the acceptance measurement.
- Rally thresholds remain explicit configuration recorded with each generation.

## Traceability

| Intent criterion | Requirements |
| --- | --- |
| 1 (count floor) | RQ-02 |
| 2 (track identity stability) | RQ-01 |
| 3 (spectator rejection) | RQ-03 |
| 4 (compact input filter) | RQ-04 |
| 5 (rally yield) | RQ-05 |
| 6 (automation test) | RQ-06, RQ-09 |
| Constraints | RQ-07, RQ-08, RQ-10, RQ-11 |
