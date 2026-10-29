# Sportcut — Player Tracking — Business Requirements Document

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-TRK-004 |
| Version | 1.0 |
| Status | Draft — for approval |
| Date | 2026-10-29 |
| Product | Sportcut — offline macOS badminton match analyzer |
| Feature | Player tracking (area TRK) |
| Owner | Product owner |
| Contributors | Product, Design, Engineering, QA, Security/Privacy, Legal/Licensing |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.0 |
| Product contract | [00-product-context.md](00-product-context.md) |

This document is one of nine feature BRDs. It cites the shared identifiers,
objectives, requirements, risks, and milestones in
[00-product-context.md](00-product-context.md) and does not restate them. All
`FR-TRK-nn` identifiers are owned here; `BO`, `BR`, `DS`, `NFR`, `R`, `Q`, and
`M` identifiers are owned by the product BRD.

## 1. Purpose and users

Player tracking finds the people on the court in each sampled frame, links them
into timestamped tracks, records where a track is unseen, and assigns each
on-court position to a geometric side of the net. It also reports whether the
recording shows two or four players, or neither with confidence. Rally
segmentation consumes the resulting court positions; the review screen lets a
coach or player check that the engine followed the right people before trusting
the rally suggestions.

The feature serves the personas in [00 §4.1](00-product-context.md#41-user-personas).
Its success is that the engine proposes a count and tracks, shows its evidence,
and never turns an uncertain observation into a confident result.

Relationship to the product BRD: tracking is in scope for v1
([00 §3.1](00-product-context.md#31-in-scope-for-v1)), delivers the shared
semi-automatic requirement for proposals (BR-3), and supplies the rally
segmentation input. The product BRD records the area as Partial at baseline
([00 §3.3](00-product-context.md#33-current-delivery-status)): the pipeline
exists, but there are no vision tests, no client tests, and no measured count
accuracy.

## 2. Scope

### 2.1 In scope

- Run local person detection over sampled frames, offline.
- Select likely on-court players and reject spectators and off-court boxes.
- Link detections into timestamped tracks with stable generation-local IDs.
- Record explicit gaps when a track is unseen.
- Assign a geometric side: First, Second, or unknown near the net.
- Assess the recording-level player count as two, four, or unknown, with
  supporting quality and evidence interval.
- Review tracks, count, quality, coverage, and gaps beside the video.
- Run one heavy job at a time and one job per match; show progress and cancel.
- Publish a versioned, regenerable tracks artifact with provenance.
- Bundle and verify the pinned runtime and model assets; fail clearly when they
  are absent or changed.

### 2.2 Out of scope

Each item requires a change request; none may enter silently.

- Player identity, names, face recognition, or re-identification across matches.
- Pose estimation, shuttlecock, racket, shot classification, or speed.
- Manual editing of track IDs, sides, count, or gaps in the review UI.
- Correcting tracks by dragging boxes or splitting or merging tracks.
- Live tracking during a match; tracking from a second camera.
- Tracking in builds without the macOS trial runtime.
- Treating the count or side as an official result; both remain proposals.

### 2.3 Current delivery and explicit gaps

Status is **Partial**. The engine path, job, artifact, and review screen exist.
Gaps: `sportcut-vision` has no unit tests (re-run 2026-10-29 returns 0 tests);
the client has no tracking test; no player-count accuracy has been measured; the
design contract is partly unmet (§5); and the weight-licensing record conflicts
between [MODEL.md](../../models/efficientdet-lite0-task-int8/MODEL.md) and the
baseline dependency register. Details are in §7 and §9.

## 3. Functional requirements

Every row has one observable acceptance criterion. Priorities are MoSCoW.

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-TRK-01 | Open player analysis from the studio | Must | Selecting **Player analysis** in the feature rail shows the video, transport, progress area, and review panel for the selected match. |
| FR-TRK-02 | Require a marked court | Must | When the match is not calibrated, the view shows `Player analysis needs the court marked first.` with a **Mark court** action, and **Analyze players** is disabled. |
| FR-TRK-03 | Require prepared analysis media | Must | When the proxy or frames are missing, the view shows `Player analysis needs the analysis files prepared first.` with a **Prepare analysis** action, and **Analyze players** is disabled. |
| FR-TRK-04 | Start one local analysis job | Must | **Analyze players** starts a job that samples frames, detects people locally, tracks them, and publishes tracks; the start call returns a job identifier. |
| FR-TRK-05 | Use the pinned detector and runtime | Must | Detection loads the supplied local TFLite runtime and EfficientDet-Lite0 weights; only class 0 (person) boxes at or above the minimum score become detections, and a missing file fails with a message naming the file. |
| FR-TRK-06 | Keep on-court people and reject spectators | Must | Each box's bottom-centre ground point is projected through the calibration: inside the court is `OnCourt`, inside the margin is `Borderline`, beyond it is `OffCourt`; low confidence, invalid box, missing calibration, and projection failure are separate named decisions; only `OnCourt` becomes a track. |
| FR-TRK-07 | Assign a geometric side | Must | An on-court position clear of the net by the net margin is `First` or `Second`; a position within the margin is `Unknown`. |
| FR-TRK-08 | Link detections into tracks | Must | Only on-court detections within the ground-speed limit and gap limit can join or keep a track; a track ID is set only when association is unambiguous, and an ambiguous match leaves the ID unset. |
| FR-TRK-09 | Record explicit gaps | Must | A track unseen beyond the maximum track gap records an interval from its last sighting to the current frame; a resumed track closes the interval; gaps appear in the artifact and the review panel. |
| FR-TRK-10 | Assess the player count | Must | The artifact reports `Two` or `Four` only when the per-side layout holds for at least the minimum supporting frames and fraction of sampled frames; otherwise it reports `Unknown`. |
| FR-TRK-11 | Report count quality | Must | Quality is the fraction of sampled frames supporting the reported per-side layout; the review panel shows the count and that percentage together. |
| FR-TRK-12 | Report coverage intervals | Must | The artifact records intervals where calibrated frames attempted observation and intervals where a player was observed on both sides. |
| FR-TRK-13 | Publish a versioned artifact | Must | A successful run writes `tracks/player_tracks.json` schema 1 with compact segmentation input, review evidence, and provenance; the manifest marks it final only after the write completes. |
| FR-TRK-14 | Reject or refresh stale tracks | Must | Reading tracks validates the calibration, proxy, and sampled-frame identities; a changed input rejects the generation with a message naming the changed input. |
| FR-TRK-15 | Show tracks on the video | Must | At a sampled timestamp within 0.3 s of the playhead, draw each person box; on-court boxes draw at full strength, rejected boxes dimmed, and boxes with a track ID carry that ID. |
| FR-TRK-16 | Review count, quality, and gaps | Must | The panel shows the count label, quality percentage, and up to the first three gaps with track ID and start/end time; any coverage figure shown is computed from the coverage intervals, not from count quality. |
| FR-TRK-17 | Warn on an unknown count | Must | When the count is `Unknown`, the panel states that the count is uncertain and tells the user to check the video before confirming match details. |
| FR-TRK-18 | Read tracks in bounded windows | Must | The client requests a five-second window around the playhead and refreshes when playback leaves the loaded window; it never requests or holds the whole artifact in the frame. |
| FR-TRK-19 | Show progress with stage labels | Must | While running, show a determinate bar, a stage label for frames, detection, tracking, or publish, a percentage, and a **Cancel** action; progress never decreases within a stage. |
| FR-TRK-20 | Cancel a running analysis | Must | **Cancel** requests job cancellation; a cancelled job clears running and progress, publishes no final tracks, and leaves any previous final tracks readable on reopen. |
| FR-TRK-21 | Reject a second heavy job by name | Must | Starting analysis while another heavy job runs, or while a job runs for the same match, is rejected with a message naming the running job and the wait-or-cancel action. |
| FR-TRK-22 | Keep manual review available | Must | **Review rallies manually** opens the score feature whether tracks exist, analysis failed, or analysis was cancelled. |
| FR-TRK-23 | Keep review read-only | Must | The review UI creates no tracks and changes no track ID, side, count, or gap. |
| FR-TRK-24 | State the empty case | Must | With no tracks, the panel shows one factual sentence and offers **Analyze players** and **Review rallies manually**. |
| FR-TRK-25 | State the failure case | Must | A read or analysis failure shows what failed and the next action; a failed rerun does not present partial output as final. |
| FR-TRK-26 | Report an unsupported build | Must | A build without the macOS trial runtime returns a message that player detection is unavailable in this build; it does not crash or silently do nothing. |
| FR-TRK-27 | Keep detection offline | Must | Detection reads only local files supplied by the app bundle or configured paths; no network call exists in the product path. |
| FR-TRK-28 | Leave user-authored data untouched | Must | Regenerating or invalidating tracks never changes user-authored rallies, confirmed scores, or kept clips. |

## 4. State coverage

| State | Observable behaviour | Requirement |
| --- | --- | --- |
| Default | The panel reads `Reading player tracks…`, then either shows a summary and the overlay or the empty sentence. | FR-TRK-01, FR-TRK-24 |
| Loading | Before the first window: `Reading player tracks…`. Later window reads set an internal loading flag with no dedicated visible indicator. | FR-TRK-18; gap in §9 |
| Empty | `No player tracks are available yet. You can still review rallies manually.` with analysis and manual-review actions. | FR-TRK-24 |
| Error | Read or analysis failure shows a message; the player error overlays the frame. | FR-TRK-25, FR-TRK-26 |
| Success | Count label, quality, side legend, coverage, gaps, and boxes over the video; the pipeline stage refreshes after a run. | FR-TRK-15–17, FR-TRK-13 |
| Disabled | **Analyze players** is disabled when a prerequisite is missing; while running it becomes **Cancel**; transport is disabled until the player is ready. | FR-TRK-02, FR-TRK-03, FR-TRK-19, FR-TRK-20 |
| Cancellation | **Cancel** is available only while running; a cancelled job returns to idle with progress 0 and no final publish. | FR-TRK-20 |
| Running | Determinate progress bar, stage label, percentage, and **Cancel**; one heavy job globally. | FR-TRK-19, FR-TRK-21 |

## 5. Design-contract specifics

Shared design requirements are cited from
[00 §7](00-product-context.md#7-shared-design-system-requirements). This table
applies them to tracking and records the baseline implementation.

| Point | Contract | Baseline implementation | Status |
| --- | --- | --- | --- |
| Label before colour | Every state carries a word or icon; colour never carries meaning alone (DS-4); no colour-only scoring (DESIGN.md §9) | Boxes are coloured blue, orange, or grey and labelled with `#id` only; a prose legend maps colours to court halves | Gap |
| Side vocabulary | Sides are `First` and `Second` in the engine; the score screen uses L/R (DESIGN.md §2, §6) | Panel reads `court half 1` and `court half 2`; no L/R or First/Second label on a box | Partial |
| Token source | Values come from [tokens.css](../../design-system/tokens.css); no raw values (DS-1) | Raw `Colors.lightBlueAccent`, `Colors.orangeAccent`, `Colors.white70` in [player_tracking_view.dart](../../app/lib/src/features/tracking/presentation/player_tracking_view.dart) | Gap |
| One signal per pane | At most one accent element per pane (DS-3) | Two saturated side hues plus a legend; the side encoding is functional but undocumented in the palette | Partial |
| Progress job | Stage name, determinate bar, percentage, cancel; no bar longer than three seconds without a stage label (DESIGN.md §6) | Determinate `LinearProgressIndicator`, stage label, **Cancel**; no percentage text | Partial |
| Progress copy | Scorekeeper voice; example `Rally detection 42%` (DESIGN.md §8, DS-10) | Ellipsis labels such as `Sampling frames…`; no number beside the label | Partial |
| Metrics naming | No invented metrics; a number names what it measures (DESIGN.md §9) | `countQuality` is shown as both `quality` and `coverage`; `coverage` is not the same measure | Gap |
| Tabular numerals | Every score, duration, and timecode uses tabular figures (DS-5) | Readout chips use `tabularFigures`; summary and gap text use default figures | Partial |
| Chips | Pill radius for chips; `--radius-pill` = 9999 px (DESIGN.md §4) | Chip radius is a raw 8 px; the border uses the theme outline rather than a radius token | Gap |
| Empty state | One factual sentence and one action (DESIGN.md §6, §8) | Sentence is factual; the actions sit above in the same panel | Partial |
| Accessibility | 44 px targets, named icon controls, readable progress semantics, no clipping at 200 % (DS-15) | Buttons and the 48 px icon button are named; progress has no explicit percentage semantics | Unverified |
| Overlay restraint | No floating chrome over the court action area (DESIGN.md §9) | Boxes and ID labels sit on the footage; no panels float over it | Conforms |

Any local change may tighten these rules, not relax them.

## 6. Feature non-functional requirements

Shared requirements are not restated; each row adds the tracking-specific
acceptance criterion.

| ID | Requirement | Priority | Acceptance criterion | Shared |
| --- | --- | --- | --- | --- |
| NFR-TRK-01 | Detection runs offline | Must | The detector opens local runtime and model paths only; the product path performs no network call. | NFR-1, BR-1 |
| NFR-TRK-02 | The client reads bounded data | Must | Playback reads five-second windows; the whole 10 MB-class artifact is never loaded into the frame. The baseline record measures ~10.5 MB for a 9 min 4 s clip at 5 fps. | NFR-2 |
| NFR-TRK-03 | Publish is atomic and cancellable | Must | The artifact is written to a temporary file, renamed, and only then marked final; a cancel at any checkpoint leaves no final tracks. | NFR-3, BR-11 |
| NFR-TRK-04 | Track inputs are versioned and fingerprinted | Must | Provenance records frames, proxy, calibration, runtime, model, sampling rate, and tracking config; a changed input rejects the generation. | NFR-4 |
| NFR-TRK-05 | One heavy job at a time | Must | The registry admits one heavy job and one job per match; a second request is rejected with a named reason, never queued silently. | NFR-2 |
| NFR-TRK-06 | Association is deterministic | Must | The same detections, calibrations, duration, and config produce byte-identical track decisions and IDs. | NFR-7 |
| NFR-TRK-07 | The default engine build needs no inference runtime | Must | `sportcut-vision` and the workspace build, lint, and test without `macos-tflite-eval`; detection is an optional macOS feature. | NFR-8 |
| NFR-TRK-08 | No unverified asset ships | Must | The runtime and weights enter a release only with a shippable register verdict and a verified checksum; a build with an unverified model is blocked. | NFR-10, BR-10 |
| NFR-TRK-09 | Tracking logic is tested | Must | Detection classification, association, gaps, count assessment, and staleness each have automated tests; client review states have widget tests. At baseline this is not met (§7). | NFR-7 |

## 7. Acceptance and verification evidence

Evidence at baseline `1541c64`. Records that name code paths are current. Test
counts are quoted from the evidence record where they exist and re-checked where
noted.

| Scenario | Evidence | Result |
| --- | --- | --- |
| Unanalysed match reports no tracks | [unanalysed_match.rs](../../core/crates/api/tests/unanalysed_match.rs), `a_match_without_a_manifest_has_no_suggestions_or_tracks` | Pass at baseline |
| Starting segmentation without tracks names the gap | Same file, `analysing_a_match_without_tracks_says_what_is_missing` | Pass at baseline |
| A changed court invalidates tracks | [facade.rs](../../core/crates/api/tests/facade.rs), a calibration change drops `tracks/tracks.json` and names `tracks` in `invalidated_kinds`; an unchanged court keeps them | Pass at baseline |
| Job lifecycle and admission | `core/crates/jobs/` (7 tests at baseline); [registry.rs](../../core/crates/jobs/src/registry.rs) rejects a second heavy job and a second job per match with a reason | Pass at baseline |
| Detection, classification, association, gaps, count | [vision crate](../../core/crates/vision/src/lib.rs); `cargo test -p sportcut-vision` returns 0 tests, 0 failed; re-run 2026-10-29 | Gap |
| End-to-end local run on one clips | `docs/verification/rally-rest-segmentation.md` at `1541c64`: import → calibrate → player analysis on clip `c1` produced `tracks/player_tracks.json` schema 1, 5 fps, 4 track IDs, ~10.5 MB | Recorded manual run |
| Player-count metric | `docs/verification/accuracy-evaluation.md` at `1541c64` defines the metric and the ≥85 % clean-clip target; the Results table is empty | Unmeasured |
| Client tracking states | No tracking widget or controller test exists in `app/test/` | Gap |
| Design conformance (labelled sides, token colours, percentage) | No automated design or visual test exists | Gap |
| Pinned assets | [fetch-inference-assets.sh](../../tools/fetch-inference-assets.sh) verifies SHA-256 at build time; the job compares the model's FNV-1a fingerprint with `fnv1a64:0a4c9e64faa2dae8` and records the runtime fingerprint for change detection | Partial: runtime has no pinned constant in code |

No accuracy number is claimed. The shared BO-5 targets (≥85 % player count,
≥85 % boundary hit, ≤5 % confidently wrong) remain unmeasured, and the shared
Results table is empty.

## 8. Dependencies and constraints

| Type | Dependency or constraint | What this feature needs |
| --- | --- | --- |
| Internal | [sportcut-vision](../../core/crates/vision/src/lib.rs) | Decode, classification, association, gaps, count, detector trait |
| Internal | [sportcut-court](../../core/crates/court/src/lib.rs) | Homography and side assignment per segment |
| Internal | `sportcut-media` | Sampled upright JPEG frames and timestamps |
| Internal | [sportcut-jobs](../../core/crates/jobs/src/registry.rs) | Admission, lease, checkpoints, cancellation |
| Internal | [sportcut-api](../../core/crates/api/src/player_tracking_job.rs) | Job wiring, artifact adapter, windowed reads |
| Internal | [InferenceAssets](../../app/lib/src/features/tracking/data/inference_assets.dart) | Bundle paths for runtime and model |
| Internal | Eval harness (`sportcut-cli eval`) | Player-count scoring against labels |
| External | TensorFlow Lite C runtime | Local inference; Apache-2.0 runtime, checksum recorded |
| External | EfficientDet-Lite0 Task Library int8 weights | Person detection; SHA-256 `2e04c5…4e0b` recorded |
| Constraint | macOS and feature `macos-tflite-eval` | Detection is unavailable in other builds |
| Constraint | One heavy job at a time and one per match | Admission rejects rather than queues |
| Constraint | Sampling rate 5 fps from the client config | Count quality is a fraction of sampled frames |
| Constraint | Bottom-centre box as ground point | Side and court selection inherit the approximation |
| Constraint | One supported trial model fingerprint | A different weight file fails the run |
| Constraint | Tracks are derived, not user data | They may be invalidated and regenerated |

## 9. Risks and open questions

Feature risks. Shared risks are cited, not repeated.

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-TRK-1 | Player-count accuracy is unmeasured; `unknown` is not distinguishable from a confident wrong count in daily use | High | High | Score a labeled clip with the eval harness; report count accuracy and the unknown rate before claiming Done | QA lead |
| R-TRK-2 | All detection, classification, association, gap, and count logic is untested | High | High | Add vision unit tests for each decision and association branch; add client review tests | Engineering lead |
| R-TRK-3 | Model weight verdict conflicts: the register says shippable, [models/README.md](../../models/README.md) and [MODEL.md](../../models/efficientdet-lite0-task-int8/MODEL.md) say unresolved | Medium | High | Reconcile to one verdict and record it in the register before release (shared R-3) | Legal/licensing |
| R-TRK-4 | The panel shows `countQuality` as both quality and coverage, so the user reads a number under the wrong name | High | Medium | Label the count measure once and expose true coverage separately | Design lead |
| R-TRK-5 | Side colours are raw literals and colour-only, so sides are hard to read and drift from tokens | Medium | Medium | Tokenise the side encoding and add a text side label to each box | Design lead |
| R-TRK-6 | A failed or cancelled rerun clears the visible tracks and shows no next action beyond rerunning | Medium | Medium | Reload the last final tracks after failure and name the next action | Engineering lead |
| R-TRK-7 | A long match produces a large artifact and many windows; repeated reads may lag playback | Medium | Medium | Keep window reads bounded and generation-guarded; measure on a long clip | Engineering lead |
| R-TRK-8 | A wrong court calibration yields confident but wrong sides and count | Medium | High | Show the calibration stage as done only from stored corners; keep count unknown when evidence is weak; test against a marked real clip | QA lead |

Shared risks that apply: R-1 accuracy, R-3 model licensing, R-4 codec patents
(indirect through export), R-7 client test gaps, R-8 job races, R-9 retired
documentation references. Shared objectives that gate this feature: BO-3 and BO-5.

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-TRK-1 | Which labeled clips seed the player-count baseline, and who labels them? | R-TRK-1 cannot close without labels (shared Q-1) | QA lead |
| Q-TRK-2 | Who owns tuning the provisional tracking and count thresholds? | The client ships fixed values with no replay path | Engineering lead |
| Q-TRK-3 | Must the reviewer be able to correct a side or count in v1? | A read-only review leaves a wrong proposal with no remedy | Product owner |
| Q-TRK-4 | Do side labels read First/Second or Left/Right in the review UI? | Affects tracking and export copy (shared Q-9) | Product owner |
| Q-TRK-5 | Is the EfficientDet weight file shippable by redistribution? | Blocks a release build (shared Q-4) | Legal/licensing |
| Q-TRK-6 | Is the runtime's pinned checksum enforced in the engine, or only at build time? | R-TRK-3 mitigation and provenance integrity | Engineering lead |

## 10. Traceability

| Business requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| BR-3 Semi-automatic, user-confirmed | FR-TRK-10, FR-TRK-17, FR-TRK-23, FR-TRK-28 | DESIGN §8 | [tracking.rs](../../core/crates/vision/src/tracking.rs) | None yet; gap |
| BR-8 Design fidelity | FR-TRK-15–19, FR-TRK-24 | DESIGN §6, §8, §9; DS-1, DS-3, DS-4, DS-5, DS-10 | [player_tracking_view.dart](../../app/lib/src/features/tracking/presentation/player_tracking_view.dart) | Gap; see §5 |
| BR-9 Accessibility | FR-TRK-15, FR-TRK-19 | DS-15 | Review panel and transport | Unverified |
| BR-10 Licensing gate | FR-TRK-05, FR-TRK-27 | — | [player_tracking_job.rs](../../core/crates/api/src/player_tracking_job.rs), [fetch-inference-assets.sh](../../tools/fetch-inference-assets.sh) | Register conflict R-TRK-3 |
| BR-11 Recoverable jobs | FR-TRK-19–21, FR-TRK-25 | DESIGN §6 Progress job | [player_tracking_providers.dart](../../app/lib/src/features/tracking/presentation/player_tracking_providers.dart), [registry.rs](../../core/crates/jobs/src/registry.rs) | Job tests; no client test |
| NFR-4 Data integrity | FR-TRK-09, FR-TRK-13, FR-TRK-14 | — | [track_artifact.rs](../../core/crates/api/src/track_artifact.rs) | Facade invalidation test |
| NFR-8 Engine independence | FR-TRK-05, FR-TRK-26 | — | `macos-tflite-eval` feature gate | Build evidence only |
| Rally input (BO-3, BO-5) | FR-TRK-06–12 | — | [track_artifact.rs](../../core/crates/api/src/track_artifact.rs), [court_candidates.rs](../../core/crates/vision/src/court_candidates.rs) | Manual c1 run; accuracy unmeasured |

Prior verification records at baseline `1541c64` (cited for provenance; not
part of the working tree): `docs/verification/rally-rest-segmentation.md`,
`docs/verification/accuracy-evaluation.md`, `docs/architecture.md`, and
`docs/data-storage-models.md` (tracks artifact). The roadmap records player
detection and tracking under Phase 0 and Phase 2.

## 11. Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |
| Legal/licensing |  | Approve / revise |  |

---

**Change control.** A change to scope, a Must requirement, or the design
contract requires a version bump, a recorded approval decision, an update to the
dependency register if an asset changes, and a re-run of the quality checklist.
Changes to shared IDs follow [00 §18](00-product-context.md#18-approval). This
draft does not claim release readiness while R-TRK-1, R-TRK-2, R-TRK-3, and the
shared accuracy gate remain open.
