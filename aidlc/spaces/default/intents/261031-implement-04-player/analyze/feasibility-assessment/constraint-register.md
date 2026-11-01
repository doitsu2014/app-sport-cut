# Constraint Register — Player Tracking (Feature 04)

Intent: `261031-implement-04-player`
Date: 2026-10-31

Status: Active / Deferred. Every constraint below is **Active** unless stated.

| ID | Constraint | Type | Source | Effect on this intent |
| --- | --- | --- | --- | --- |
| C-01 | Offline only: no network, telemetry, or online API in product paths; detection reads local files only. | Hard — product | CLAUDE.md guardrails; BRD 04 FR-TRK-27, NFR-TRK-01; BRD 00 NFR-1 | No network crate or import in `sportcut-vision`, `sportcut-api`, or the service. Verify by dependency scan and an offline run. |
| C-02 | No dependency, model, weight, or dataset ships without a licensing-register row and a shippable verdict. | Hard — licensing | CLAUDE.md; BRD 00 NFR-10, §11.2; `models/efficientdet-lite0-task-int8/MODEL.md` | The EfficientDet verdict is contradictory today (MODEL.md “unresolved” vs register “reconciled”, and the cited `docs/external-dependencies.md` is missing). Verify by the register row plus the SHA-256 checks in `tools/fetch-inference-assets.sh`. `tools/preflight.sh --strict-license` only covers GPL media builds, not model redistribution. |
| C-03 | Clean-architecture dependency rule: source dependencies point inward; a use case may not depend on the gateway implementing its port; entities stay pure. | Hard — architecture | CLAUDE.md; `docs/architecture/layering.md`; ADR-0002 | Verify with `tools/check-layering.sh`; no filesystem, process, environment, or network calls in entities. |
| C-04 | The service owns the TFLite runtime and person model; the protocol never accepts client-supplied `runtimePath`/`modelPath`. | Hard — security | CLAUDE.md; BRD 04 FR-TRK-05; ADR-0001 | The service rejects both fields; the app sends config only. The acceptance test calls the library directly and passes paths, so it does not exercise this boundary (see C-16). |
| C-05 | The detector uses only the pinned trial runtime and footprinted EfficientDet-Lite0 weights; any other model fails. | Hard — contract | BRD 04 FR-TRK-05, NFR-TRK-08; MODEL.md | `TRIAL_MODEL_FINGERPRINT` gate and fetch-script SHA-256 constants; model files stay gitignored. |
| C-06 | No new client-owned durable state; the service owns tracks, catalog, and custody. | Hard — migration | CLAUDE.md; ADR-0001 | No sqflite/path_provider under the tracking feature; `tools/check-no-rust-in-app.sh` stays green. |
| C-07 | Deterministic output: identical detections, calibration, duration, and config produce identical track decisions/IDs and the same spans. | Hard — quality | BRD 04 NFR-TRK-06; RQ-10; BRD 05 FR-RAL-04 | Output ordering derives from frame order; no HashMap iteration in output construction. Add the rerun test (S3). |
| C-08 | Full reference analysis (import + tracking + rally) completes within 300 s on the development Mac. | Hard — performance | RQ-09 | Measure per-stage wall time in the real-footage test; enforce in an optimized build or behind an explicit env. |
| C-09 | FR-TRK-08 is inviolable: an ambiguous association MUST leave the track ID unset; ambiguity may not be hidden, overridden, or tie-broken to manufacture continuity. | Hard — contract | BRD 04 FR-TRK-08; intent success criterion 2 | Keep `association_ambiguous` unset-ID behaviour; add the ambiguity unit test (S3); reject approach changes that resolve ambiguity to raise continuity. |
| C-10 | No Rust, `dart:ffi`, generated bindings, or dylib in the Flutter app; the client uses the service protocol only. | Hard — security/architecture | CLAUDE.md; ADR-0001; BRD 00 NFR-9 | `tools/check-no-rust-in-app.sh` must pass. |
| C-11 | One heavy job at a time and one job per match; cooperative cancellation; a cancelled/failed run publishes no final artifact; publication is atomic. | Hard — reliability | CLAUDE.md; BRD 04 NFR-TRK-03/05, FR-TRK-20; ADR-0001 | Existing admission, lease, and temp-plus-rename tests stay green. |
| C-12 | Unix socket only: no TCP listener, 0700/0600 permissions, peer-UID check, 103-byte `sun_path` guard. | Hard — security | CLAUDE.md; `service/src/security.rs`, `server.rs` | No transport change in this intent. |
| C-13 | Preserve the artifact contract: tracks schema 1, provenance, stale-input rejection, and derived artifacts regenerable without modifying user-authored rallies, scores, or clips. | Hard — contract | RQ-07; BRD 04 FR-TRK-13/14/28; BRD 05 FR-RAL-05..07 | Existing facade tests; `TrackProvenance::validate`. |
| C-14 | The default engine build builds, lints, and tests without the macOS TFLite runtime and without the Flutter/Xcode toolchain; detection stays behind the `PersonDetector` port. | Hard — build | BRD 04 NFR-TRK-07; CLAUDE.md | `cargo build/clippy/test` with default features; `macos-tflite-eval` stays optional. |
| C-15 | Artifact and protocol compatibility for additive fields: new `TrackingConfig` fields carry serde defaults; existing `player_tracks.json` still deserializes; client DTO additions are a documented protocol minor bump and tracks schema stays 1. | Hard — contract | C-13; RQ-07; `docs/architecture/protocol.md` §14 | Verify with an old-artifact deserialization test and a protocol note. |
| C-16 | The opt-in acceptance test exercises the library pipeline, not the service's asset-resolution path; service asset ownership remains covered only by the service rejection test. | Known limitation, recorded | C-04; BRD 04 §8 | Record the scope explicitly; do not treat the acceptance run as proof of the service asset path. |
| C-17 | NFR-TRK-09 (automated tests for classification, association, gaps, count, staleness and client review) is mapped to RQ-12, including the staleness case. | Hard — quality | BRD 04 NFR-TRK-09; RQ-12 | Add the staleness/gap tests; map them in the traceability table. |
| C-18 | The 35-rally baseline is unlabelled; a count match is not an accuracy proof. | Constraint, deferred | BRD 05 RAL-R1; RQ-05 | Record the spot-check or downgrade RQ-05 to count-fit only (S4). |
| C-19 | FR-TRK-08 ambiguity is decided from a ranking-independent plausibility measure over every gate-passing track; freshness, staleness and tentative status may only order assignment, never decide ambiguity. | Hard — contract | C-09; architecture security review; `tracking.rs:248-253` | Fresh-vs-stale unit test asserts `association_ambiguous` and `track_id: None`; any change that lets ranking resolve ambiguity is rejected. |
| C-20 | The RQ-01 denominator has a classifier-independent floor and the numerator a shape check: raw/OnCourt detection floors, a per-frame band, both sides represented in the top four, no single ID over 40% of the top-four observations, and count quality not below the before value. | Hard — measurement | RQ-01; architecture security review | The acceptance test asserts each floor and prints the values; the broad share is the only gate, the compact share is printed only. |
| C-21 | Licensing is an automated embed/release guard: the build must fail when `MODEL.md` and the register disagree or the verdict is not `shippable`. | Hard — licensing | C-02; architecture security review; `tools/embed-inference-assets.sh` | Guard added in S2; no Done claim while unresolved. |
| C-22 | Acceptance-critical floors are service-owned: `min_count_fraction` below 0.60 and `min_track_observations` below 3 are rejected. | Hard — quality | K-05; architecture security review | Facade/service validation plus a test; effective values remain in provenance. |

## Waivers

None.

## Deferred constraints

- **C-18** is deferred to a later accuracy pass unless the optional S4 labels or
  a documented spot-check land in this intent.
- **C-16** is a recorded scope limitation, not a release blocker; the service
  rejection test remains authoritative for C-04.

## Delivery risks

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| K-01 | Acceptance test does not encode RQ-01…RQ-05. | High | High | S1 assertions. | Engineering / QA |
| K-02 | 300 s budget unenforced. | Medium | Medium | Per-stage timing and an optimized-build assertion. | Engineering |
| K-03 | EfficientDet licensing verdict contradictory; missing external-dependencies file. | Medium | High | S2; no Done/release claim while unresolved. | Legal / licensing |
| K-04 | Continuity work pressures FR-TRK-08 ambiguity. | Medium | High | Keep the unset-ID branch; ambiguity test; reject tie-breaks. | Engineering |
| K-05 | Acceptance floors are client-supplied config. | Medium | Medium | Provenance records config; consider service-side defaults. | Engineering |
| K-06 | Real-footage test passes green when assets are missing. | Medium | High | Fail, do not skip, when the video is set. | QA |
| K-07 | Acceptance evidence untracked. | Medium | Medium | Commit the test and intent records. | Engineering |
| K-08 | Track adapter imports `sportcut_storage`. | Low | Medium | Keep format logic entity-side; split if the crate moves. | Engineering |
| K-09 | Determinism required but untested. | Low | High | Rerun comparison in S3. | Engineering |
| K-10 | Client resolves `InferenceAssets` and passes ignored paths. | Low | Medium | Remove dead call sites; keep the service gate. | Engineering |
