# Design Decisions — Player Tracking (Feature 04)

Status: Ideate / Design Pattern Selection
Intent: `261031-implement-04-player`
Date: 2026-10-31
Inputs: `architecture-doc.md`, `api-contract.md`, `requirements.md`.

Every decision below is **Accepted** unless marked otherwise. The codebase
already uses deterministic greedy association, serde DTOs with additive fields,
ports for inference/media, and Riverpod providers for client state; deviations
are called out.

## D-01 Association: separate plausibility from ranking

| | |
| --- | --- |
| Context | FR-TRK-08 requires an ambiguous association to leave the track ID unset. The current `association_cost` is used for both the ambiguity test and assignment order, so adding a staleness penalty can silently resolve a genuine tie. |
| Decision | Two pure functions in `tracking.rs`: `plausibility(track, person)` = gate residual / speed + side + overlap (evidence only), and `assignment_cost(...)` = plausibility + staleness × elapsed. Ambiguity compares plausibility; assignment orders by freshness tier, then `assignment_cost`. |
| Alternatives | (a) one cost with a smaller penalty — still lets ranking decide ambiguity; (b) compare on track ID or distance only — ignores side/overlap evidence; (c) a policy trait — no second implementation exists. |
| Consequences | FR-TRK-08 becomes structurally enforced rather than a comment. Two small functions instead of one; unit tests must cover the fresh-vs-stale tie. Reversible by reverting the split. |
| Status | Accepted |

## D-02 Tentative track lifecycle

| | |
| --- | --- |
| Context | One-frame fragments spawn tracks immediately and then compete for later detections, inflating the active set and ambiguity. |
| Decision | Add a state machine on `ActiveTrack`: tentative (observations < `min_track_observations`) → confirmed → lost (missing, within `max_track_gap_ms`) → evicted. Tentative tracks cannot outrank confirmed tracks; a tentatively matched detection still gets a track ID (it is not ambiguous), it simply ranks last. Reuse the existing `min_track_observations` rather than adding a second threshold. |
| Alternatives | A separate `tentative_min_observations` field (more tuning surface); never spawn until two observations (drops real one-frame appearances); post-hoc filtering only (already present, but does not stop competition). |
| Consequences | Fewer fragments compete, which should reduce ambiguity without weakening FR-TRK-08. No wire change: the state is internal and the review evidence keeps every detection. |
| Status | Accepted |

## D-03 Artifact evolution: optional additive fields

| | |
| --- | --- |
| Context | The track artifact is a stable schema-1 contract consumed by rally and the client. The new config fields are serialized inside `provenance.tracking`. |
| Decision | Every addition is `Option` or `#[serde(default)]`; no schema bump; old artifacts deserialize with the tuned defaults; the compact `SegmentationInput` is unchanged. |
| Alternatives | Schema 2 with a migration (unnecessary for optional data); a versioned association-config sub-object (more structure, no benefit); a new artifact file (duplicates custody and identity). |
| Consequences | Backward and forward compatible; the cost is that old artifacts report no fragmentation summary, which the UI treats as absent. |
| Status | Accepted |

## D-04 Fragmentation summary as a value object

| | |
| --- | --- |
| Context | RQ-01 needs one pinned definition, and the acceptance test needs an independent recomputation to avoid definition drift. |
| Decision | `FragmentationSummary` is an immutable value object computed once at the end of `track_detections`. The top-four selection sorts deterministically (count desc, ID asc); no HashMap iteration reaches output. The engine records it; the test recomputes it from `review.frames`. |
| Alternatives | Compute only in the test (no production evidence); compute only in the engine (no independent oracle); compute per window (expensive and inconsistent). |
| Consequences | One definition, two implementations (engine and test) cross-checked. Denominator/numerator floors in the test prevent classifier gaming. |
| Status | Accepted |

## D-05 Boundary validation for acceptance floors

| | |
| --- | --- |
| Context | `PlayerTrackingConfigDto` is client-supplied; a payload could set `minCountFraction` near 0 or `minTrackObservations` to 2 and weaken RQ-02/RQ-04. |
| Decision | Validate at the API boundary (`convert.rs` / facade): reject `minCountFraction < 0.60` and `minTrackObservations < 3` with `invalid_params`; do not clamp. Record the effective values in provenance. |
| Alternatives | Clamp silently (hides misconfiguration); validate in the client only (untrusted); add a new tightening rule in `TrackingConfig` only (the boundary gives a better message). |
| Consequences | A bad client cannot lower the product floor. The DTO stays additive; older clients that omit the fields are unaffected. |
| Status | Accepted |

## D-06 Verification layering

| | |
| --- | --- |
| Context | The BRD requires automated tests, and the acceptance measurement needs real footage while unit tests must stay fast and deterministic. |
| Decision | Three layers: (1) pure-function unit tests in `sportcut-vision`/`sportcut-rally` for association, ambiguity, gaps, coverage, count and segmentation edges; (2) an artifact/deserialization test for RQ-04 and compatibility; (3) an opt-in real-footage acceptance test that fails when the video is set but assets are missing. No new test framework or dependency. |
| Alternatives | Only the real-footage test (slow, non-isolating, can skip); only synthetic fixtures (no accuracy evidence); a new property-testing dependency (licensing and scope cost). |
| Consequences | Fast regressions and one honest end-to-end measurement. The acceptance test remains hardware-dependent by nature and is documented as such. |
| Status | Accepted |

## D-07 Licensing as a scripted release guard

| | |
| --- | --- |
| Context | The EfficientDet redistribution verdict is contradictory; `--strict-license` only covers GPL media builds. |
| Decision | S2 adds a guard to `tools/embed-inference-assets.sh` (and/or `preflight.sh`) that fails when `MODEL.md` and the licensing register disagree or the verdict is not `shippable`. No model or runtime change. |
| Alternatives | A checklist item only (can be skipped); a runtime check (too late, asset already bundled); blocking all macOS builds (over-broad). |
| Consequences | An unresolved verdict cannot reach a bundle. The guard is small, scriptable, and reversible. |
| Status | Accepted |

## D-08 Client presentation and state

| | |
| --- | --- |
| Context | The panel mislabels count quality as “Coverage” (FR-TRK-16), and the client still resolves `InferenceAssets` and passes ignored runtime/model paths. |
| Decision | Rename the label to “Count quality”, render Unknown with quality/supporting frames/evidence, parse the optional DTO fields, and remove the dead asset-path passing. Keep the existing Riverpod provider and in-memory window cache; no new durable state. |
| Alternatives | A new controller/provider (duplicates state); client-side computation of the summary (contradicts data ownership); leaving the label (violates FR-TRK-16). |
| Consequences | A small presentation change; no protocol or persistence change. |
| Status | Accepted |

## Rejected patterns

| Pattern | Why rejected |
| --- | --- |
| Retrospective trajectory stitching | Deferred by the approved decision; a second identity concept and a product sign-off outside this intent. |
| Appearance re-ID / tracking-by-detection redesign | One-way door: new weights, licensing, runtime, and schedule. |
| Event sourcing for track generations | The artifact is already a versioned generation; no event history is required. |
| Generic repository/aggregate abstraction for tracks | The existing artifact store and ports are sufficient; an abstraction would add indirection without a second implementation. |
| Client-side geometry or tracking computation | Violates ADR-0001 and the service-owned artifact contract. |
