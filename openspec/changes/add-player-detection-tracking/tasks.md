## 1. Resolve the footage, runtime, and licensing gates

- [ ] 1.1 Obtain consented local fixed-camera singles and doubles clips covering both court orientations, distant players, occlusions, spectators, and a rotation-tagged recording; document clip provenance without committing footage
- [x] 1.2 Define the count, detection, track-continuity, coverage, runtime, memory, battery, and app-size measurements and acceptance thresholds for the macOS development target
- [ ] 1.3 Benchmark an on-device LiteRT/TFLite person-detector candidate, starting with EfficientDet-Lite0, against the footage and compare any alternative needed to meet those thresholds
- [ ] 1.4 Select and pin the exact macOS runtime packaging path and model weight bytes, and record separate runtime, weights, and training-dataset license and redistribution verdicts in `docs/legal/dependency-register.md`; keep unresolved components off the shipping path
- [ ] 1.5 Record the selected model's source, version, checksum, input/output format, and intended use under `models/`, and confirm inference can run without network access

## 2. Decode frames and detect on-court people

- [x] 2.1 Add a decoded-frame adapter that converts sampled JPEGs into the selected backend's pixel layout while preserving displayed orientation, dimensions, and original-timeline timestamps
- [ ] 2.2 Implement the approved `PersonDetector` backend behind the existing vision trait, with target-specific packaging isolated so `core/` remains host-buildable and hand-written Rust remains free of `unsafe`
- [x] 2.3 Add explicit errors for missing frames, runtime, or weights; do not publish a final result when inference is unavailable
- [x] 2.4 Select likely on-court people using calibrated ground-contact points and retain raw boxes, confidence, and rejection reasons for review
- [x] 2.5 Derive two, four, or unknown observed players from sustained per-side evidence, including an evidence interval and quality indication

## 3. Build court-aware player tracks

- [x] 3.1 Associate ordered on-court detections into generation-local player IDs, with bounded occlusion handling and explicit gaps for ambiguous matches
- [x] 3.2 Normalize observed ground points into the displayed-frame space, apply the timestamp-valid court mapping, and emit normalized court positions only when projection is reliable
- [x] 3.3 Assign `CourtSide::First` or `Second` from the calibrated net with an unknown state near the net or outside reliable court coverage; keep side changes from rewriting player IDs
- [x] 3.4 Record ordered attempted and usable coverage intervals and mark observations without valid calibration or reliable player positions as unusable
- [ ] 3.5 Tune the tracking sampling rate and association/side thresholds on the consented clips and record measured accuracy and device cost

## 4. Publish and consume a fresh track artifact

- [x] 4.1 Define the versioned `tracks/player_tracks.json` producer envelope with the existing schema-1 rally `input` fields plus detector, count, observation, side, quality, and configuration provenance
- [x] 4.2 Write the track artifact atomically and mark `ArtifactKind::Tracks` final only after successful completion; leave cancelled or interrupted output non-final
- [x] 4.3 Include calibration, sampled-frame/proxy, model/runtime, and configuration identities in freshness checks, invalidating tracks and rally suggestions when their inputs change
- [x] 4.4 Confirm the current rally segmenter accepts the produced `input` and that older matches with no tracks continue to load and use manual review
- [x] 4.5 Keep track output in the engine match directory and preserve accepted rallies, scores, and kept clips across reruns

## 5. Expose analysis through the engine and client

- [x] 5.1 Add stage-labelled, cancellable detection/tracking jobs and read-only count, coverage, track, side, and unavailable-result DTOs to the `sportcut-api` facade
- [x] 5.2 Regenerate the bridge with `tools/generate-bridge.sh` and add hand-written typed wrappers in `app/lib/src/bridge/`; leave generated files uncommitted
- [x] 5.3 Add a focused Flutter review surface for count, tracks, side overlays, gaps, uncertainty, progress, and actionable unavailable reasons without writing winners or score events
- [ ] 5.4 Check engine formatting and clippy, run `flutter analyze` for the client, and manually inspect result overlays and offline behavior on macOS using the evaluation clips
