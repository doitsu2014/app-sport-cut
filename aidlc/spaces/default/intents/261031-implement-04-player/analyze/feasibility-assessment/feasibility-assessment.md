# Feasibility Assessment — Player Tracking (Feature 04)

Status: Analyze / Feasibility Assessment
Intent: `261031-implement-04-player`
Date: 2026-10-31
Inputs: `intent-statement.md`, `requirements.md` (RQ-01…RQ-12), the
real-footage measurement on `IMG_1308.MOV`.

## 1. Technical feasibility by requirement

| Requirement | Feasibility | Basis and unknowns |
| --- | --- | --- |
| RQ-01 Top-four share ≥ 60% | **Medium, spike-blocked** | The cause is identifiable: `association_cost` divides distance by `allowed = speed × elapsed` (`tracking.rs:374-397`), so an old track gets a larger capture radius and can outrank a fresh one. Unmatched tracks are retained for 1,200 ms (`tracking.rs:208-219`) and every leftover box spawns a track (`tracking.rs:300-311`), producing 613 identities. A freshness-aware cost plus prediction and fresh-first matching is feasible inside the current design. The 60% effect is unproven, and the metric's denominator is not pinned (see S1). |
| RQ-02 Count floor 60% | **High, with contract caveats** | `assess_count` already computes `supporting_frames / frames` and `Four` requires `min_count_fraction` (0.7 in the shipped config, stricter than the 60% floor). `PlayerTracksDto` omits `supporting_frames`, so RQ-02's evidence is only in the raw artifact; the review panel labels count quality “Coverage” (`tracking_panel.dart:140`), which collides with the coverage intervals and FR-TRK-16. |
| RQ-03 Spectator rejection | **High, met by construction** | `classify_detections` assigns `OnCourt` only when both court coordinates are in `0..=1` (`court_candidates.rs:130-139`), and `from_tracking` emits only `OnCourt`, non-ambiguous positions with a court point (`track_artifact.rs:140-179`). The requirement has no assertion today; add one. Approach C must never reclassify a plausible player to raise the share. |
| RQ-04 Compact-input filter | **Done in the working tree** | `TrackArtifact::from_tracking` now counts observations over `review.frames` and retains only positions whose track has at least `min_track_observations` (`track_artifact.rs:160-184`). The review evidence is untouched. Add the artifact assertion (short ID present in review, absent from compact input). |
| RQ-05 Rally yield 30–40 / 10–30% | **Medium** | The retuned thresholds produce 35 candidates, 112 s (15%), 100% coverage on the reference. But the only oracle is a count range on one unlabelled clip; a stable but wrong partition passes. Label a representative subset or record a documented spot-check; otherwise label RQ-05 “count-fit only”. |
| RQ-06 Real-footage automation | **Medium** | `real_footage.rs` exists and passes, but its bounds (`rallies_per_minute ≥ 0.5`, `active_fraction 0.02..=0.6`) also pass the pre-change result (15 rallies, 6%), and it returns green if the video is set but the model/runtime is missing (`real_footage.rs:200-207`). Harden it (S1). |
| RQ-07 Artifact contract | **High, with an additive-change guard** | Schema 1, provenance, atomic publication, stale-input rejection and cancellation are tested. New `TrackingConfig` fields are serialized into `TrackProvenance`; they must be optional with serde defaults so existing `player_tracks.json` still deserializes, and any client DTO addition is a protocol minor bump. |
| RQ-08 Offline / ownership | **High** | No network crate in the vision/API/service paths; the service owns assets and rejects client `runtimePath`/`modelPath`; no new client durable state is needed. |
| RQ-09 300 s budget | **Medium** | The acceptance run took ~90 s in-test and ~4 min with shell orchestration, but the test never measures or asserts elapsed time; its 1,800 s deadline is a hang guard, not a budget. Assert in an optimized build or behind an explicit env, and print per-stage timings. |
| RQ-10 Determinism | **Medium** | Pure functions are deterministic; end-to-end TFLite output may vary across hardware/thread counts. Assert strict equality at the `track_detections`/`segment` level and spans/IDs end-to-end on a fixed profile. `generation_id` hashes inputs, not output, so it is not a determinism oracle. |
| RQ-11 Bounded grid | **High** | The 1,000,000-bin cap already exists (`rally/src/lib.rs`); add the unit test. |
| RQ-12 Focused unit tests | **Medium, unmet** | Neither `sportcut-vision` nor `sportcut-rally` has a `#[cfg(test)]` module. The tests to add are listed in §3 (S3), including the FR-TRK-08 ambiguity case and staleness/gap behaviour that the association change rewrites. |

## 2. Approaches and trade-offs

### A. Continuity-aware association (recommended first)

Four additive changes in `tracking.rs`: score on a fixed speed scale instead of
`distance / allowed`; add constant-velocity prediction and a staleness penalty;
match detections to freshly seen tracks before recently lost ones; make new
tracks tentative so a one-frame fragment cannot compete. The per-person
ambiguity rule and `ambiguity_margin` stay untouched (FR-TRK-08). Effort M,
reversible. Expected to be the dominant lever for RQ-01/RQ-02; the 60% effect
is unproven until S1 measures it. Risks: crossings and partner swaps can still
switch IDs; a too-permissive fixed scale can create false joins; count and rally
thresholds must be re-measured because the ID stream changes.

### B. Retrospective trajectory stitching (only if A falls short)

A deterministic post-pass links disjoint-in-time fragments when the gap is
within a new limit, the endpoints are within a speed budget, the side agrees,
and no other detection was observed between them. Track IDs and ambiguity
evidence stay untouched; positions may carry a `trajectory_id`. Effort M,
reversible, but **requires product sign-off** and a stricter gate: the
no-third-track rule must consider every `OnCourt` detection in `review.frames`,
including `track_id: None` and `association_ambiguous`, or a merge can span an
interval where a real ambiguous player was present and manufacture continuity
across exactly the case FR-TRK-08 leaves unresolved.

### C. Detection gating (complement only)

Shape/aspect and duplicate suppression in `court_candidates.rs` protect the
association stage but cannot lengthen an identity. It must be limited to
demonstrably duplicate or non-person boxes; reclassifying a plausible player to
shrink the RQ-01 denominator is metric gaming and risks far-side recall and the
count.

### D. Larger detector / re-ID (rejected)

Replacing or retraining EfficientDet-Lite0, or adding appearance re-ID, is a
one-way door: new weights need licensing rows, a new runtime, and out-of-scope
work. Recorded and rejected for this intent.

## 3. Spikes required before implementation

**S1 — Blocking: pin the metric and harden the acceptance test.**
Add fragmentation counters and define the RQ-01 numerator/denominator once.
Recompute the before value under exactly that definition. Harden
`real_footage.rs`: assert RQ-01, RQ-02, RQ-03, RQ-04 and RQ-05; fail (do not
skip) when `SPORTCUT_TEST_VIDEO` is set but the runtime/model is absent; measure
and print import/tracking/rally elapsed time. Commit the test and its evidence.
The 8.7% baseline uses the compact input (17,387 post-filter positions) while
the verification check proposed a broader denominator (all `OnCourt`
detections, including `track_id: None`); those are not comparable and the gate
must not flip on definition alone.

**S2 — Licensing: reconcile the EfficientDet verdict.**
`MODEL.md` says the redistribution verdict is unresolved and cites
`docs/external-dependencies.md`, which does not exist; the register in
`docs/brd/00-product-context.md §11.2` says “reconciled”. Legal/licensing must
record one shippable verdict and correct the references before any Done or
release claim. `tools/preflight.sh --strict-license` checks GPL media builds; it
does not verify model redistribution.

**S3 — Verification: unit tests and determinism.**
Add the `sportcut-vision` tests for FR-TRK-08 ambiguity (ID unset), continuity,
ground-speed rejection, one gap + one resume, calibration boundaries, count
floor, coverage intervals and config validation; add the `sportcut-rally` tests
for FR-RAL-09/10/11/12, hysteresis, grid cap, unknown bins, suggestion identity
and determinism; add the `track_artifact` filter test and a client test for the
count/quality label. Map RQ-12 to NFR-TRK-09 and include the staleness case.

**Optional S4 — RQ-05 oracle.** Label rally spans for a representative subset
of the reference recording and record precision/recall, or record a documented
spot-check of the 35 candidates. Without it, RQ-05 is count-fit only.

## 4. Cost, schedule, and effort

| Area | Ballpark |
| --- | --- |
| S1 metric pinning + hardened acceptance test | 0.5–1 day |
| A continuity-aware association + re-measure count/rally | 2–3 days |
| B stitching (only if A falls short) | 1–2 days |
| C detection gating (complement) | 0.5 day |
| S3 unit tests + determinism | 1–2 days |
| S2 licensing reconciliation (legal) | external, 1 day of review |
| Documentation and BRD evidence update | 0.5 day |
| **Total engineering** | **~5–8 developer-days** |

Internal effort only; no licence purchase or infrastructure. S2 gates a release
claim, not the code work.

## 5. Risks

| ID | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| K-01 | The acceptance test does not encode RQ-01…RQ-05; a regression to 25 or 45 rallies still passes. | High | High | S1: assert each threshold and print the measured values. |
| K-02 | RQ-09's 300 s budget is unenforced. | Medium | Medium | Measure per-stage time; assert in an optimized build or behind an env. |
| K-03 | EfficientDet licensing verdict is contradictory and `docs/external-dependencies.md` is missing. | Medium | High | S2; no Done/release claim while unresolved. |
| K-04 | Continuity work pressures the ambiguity rule (FR-TRK-08). | Medium | High | Keep the ambiguous branch; add the unset-ID test; reject any tie-break that manufactures continuity. |
| K-05 | Acceptance-critical floors are client-supplied config (`min_count_fraction`, `min_track_observations`). | Medium | Medium | Record config in provenance (done); consider service-side defaults for acceptance floors. |
| K-06 | The real-footage test passes green when the video is set but assets are missing. | Medium | High | S1: fail, do not skip, in that case. |
| K-07 | Acceptance evidence is untracked. | Medium | Medium | Commit `real_footage.rs` and the intent records before completion. |
| K-08 | Track adapter imports `sportcut_storage`; a future crate move would make a use case depend on its gateway. | Low | Medium | Keep format logic entity-side and I/O behind a port if `sportcut-api` moves. |
| K-09 | Determinism is required but never exercised. | Low | High | S3: rerun comparison at pure-function level. |
| K-10 | The client still resolves `InferenceAssets` and passes ignored runtime/model paths. | Low | Medium | Remove the dead call sites after the service cutover; keep the service rejection authoritative. |

## 6. Recommendation

**Proceed with spikes.** No requirement is infeasible and no approach violates
FR-TRK-08. The implementation order is **S1 → A → re-measure → S3**, with B only
if A leaves the pinned share short and with explicit product sign-off, and C as
a complement. S2 is a hard precondition to any Done or release claim. The two
decisions the human owns are the RQ-01 metric definition and whether
trajectory stitching is allowed; both are recorded in the constraint register
and the gate.

## 7. Decisions (approved 2026-10-31)

- **RQ-01 denominator:** every `OnCourt` detection in `review.frames`, including
  ambiguous detections with `track_id: None`. The numerator is the sum of the
  four largest per-ID observation counts. S1 recomputes the before value under
  exactly this definition; both denominators may be reported, but only the
  broad one gates.
- **Trajectory stitching:** not in the initial implementation. Continuity comes
  from association first; stitching is revisited only if the pinned share still
  falls short, and then only with product sign-off and a gate that covers every
  `OnCourt` detection (including ambiguous ones) in the gap.
- **Licensing:** reconciliation (S2) is a hard precondition to Done. The code
  spikes proceed in parallel; no Done or release claim while the verdict is
  unresolved.
- **Overall:** proceed with spikes, in the order S1 → A → re-measure → S3.

## 8. Resolved open questions

- RQ-01 definition: broad denominator (above).
- Stitching: deferred to a conditional follow-up with sign-off.
- Count label: correct “Coverage” to count quality in this intent (FR-TRK-16).
- Licensing: in scope as a Done precondition.
