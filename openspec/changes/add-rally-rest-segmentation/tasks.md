## 1. Resolve inputs and shipping gates

- [x] 1.1 Confirm the Wave 2 tracking artifact schema, timestamp space, player coverage semantics, and calibration identity; update this change's design if that contract differs from the assumed input.

Confirmed: the archived Wave 2 producer writes `tracks/player_tracks.json`
directly into `sportcut_rally::SegmentationInput` (schema 1, original-timeline
`duration_ms`, `fnv1a64` calibration identity, ordered coverage spans, ordered
`(timestamp_ms, track_id, u, v)` court positions). The consumer shares that
type, so the D1 contract matches; no design change needed.

- [x] 1.2 Obtain consented representative footage and document an initial boundary-quality acceptance target for singles, doubles, silent video, and sparse tracks before tuning thresholds.

Target recorded in the design: boundaries within ±2 s on at least 85% of
boundaries, at most 5% confidently wrong rest/rally, unknown coverage reported
not scored. Footage: doubles clip `c1` (off-angle, fixed camera). Singles,
silent-video, and sparse-track footage are deferred.
- [x] 1.3 Review any newly selected runtime, weights, media dependency, or codec in `docs/legal/dependency-register.md` before adding it to a shipping path.

No new runtime, weights, dataset, codec, or third-party library was selected in
this change. The Rust serialization crates used here already have shippable
entries in the dependency register; the Wave 2 inference gate remains open.

## 2. Engine segmentation and artifact

- [x] 2.1 Implement the `sportcut-rally` input and output models and deterministic motion-first segmentation, including optional audio support, rest/unknown coverage, bounded quality, and clear unavailable-input errors.
- [x] 2.2 Add a versioned `RallySuggestions` artifact under the existing match directory, with stable input/candidate identities, atomic publication, manifest compatibility, and stale-input checks.
- [x] 2.3 Invalidate rally suggestions when calibration or tracks change, while leaving catalog-owned review data untouched.
- [x] 2.4 Expose start/read facade calls and DTOs; run segmentation through the existing heavy-job registry with progress and cancellation, publishing no final artifact from a cancelled run.

## 3. Client review integration

- [x] 3.1 Regenerate the bridge with `tools/generate-bridge.sh` and extend the hand-written typed wrapper for segmentation jobs and suggestion reads; keep generated files uncommitted.
- [x] 3.2 Add a catalog migration and editing repository operations for generation-scoped accept/dismiss decisions, including atomic creation of an unscored rally on acceptance.
- [x] 3.3 Show candidates, quality/coverage, rest/unknown context, progress, cancellation, and actionable errors in the existing review flow; support accept, adjust-and-accept, dismiss, and manual marking.
- [x] 3.4 Suppress or flag candidates overlapping accepted/manual rallies and preserve winners, scores, clips, trims, and order across reruns or recalibration.

## 4. Verification and documentation

- [x] 4.1 Run `cargo fmt --all`, `cargo clippy --workspace --all-targets -- -D warnings`, and `flutter analyze` for the touched tracks; resolve findings without changing unrelated work.
- [ ] 4.2 Review representative local footage against the boundary-quality target, including missing audio and sparse tracks; record the limitation and result under `docs/verification/` when the change is explicitly verified or closed.
- [x] 4.3 Update the Wave 3 roadmap status and user-facing guidance to describe suggestions, manual fallback, and the absence of automatic winner decisions.
