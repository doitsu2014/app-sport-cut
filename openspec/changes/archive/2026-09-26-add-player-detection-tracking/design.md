## Context

The proposal completes the two remaining Wave 2 player features on macOS, the shipping target. `sportcut-vision` currently defines borrowed `FrameView`, person-box, and detector traits but has no backend. The media pipeline writes upright, timestamped JPEGs under `frames/` at a configurable rate (default 1 fps). Calibration maps normalized displayed-frame points into a unit court, and `CalibrationSegment::side_of` divides that court at the net. Rally segmentation already reads a provisional schema-1 `tracks/player_tracks.json` containing duration, calibration identity, coverage intervals, and timestamped `(track_id, u, v)` positions. It rejects missing, non-final, stale, or unsupported tracks. The engine must still build without Flutter or the Xcode client toolchain, use no hand-written `unsafe`, and keep media on-device. No representative evaluation footage, approved inference runtime, or distributable weights are currently present. macOS is the product's shipping target.

## Goals / Non-Goals

**Goals:**

- Produce reviewable person detections, an evidence-based two/four/unknown count, and court-aware tracks for fixed-camera singles and doubles footage.
- Supply the existing rally consumer with a final track artifact only when calibration and tracking evidence are usable.
- Preserve progress, cancellation, artifact freshness, and manual review when analysis is unavailable or uncertain.
- Make runtime, weight, dataset, size, latency, and distribution decisions explicit before shipping.
- Complete local inference and review on macOS, the shipping target.

**Non-Goals:**

- Pose estimation, shuttlecock tracking, player names, winner inference, score changes, or metric speed.
- Automatic recalibration after camera movement or cuts; those intervals remain unobserved until the user supplies a matching calibration.
- Treating a one-frame person count or a guessed side as an authoritative match format or score side.
- Mobile (iOS/Android) runtime packaging; macOS is the only target.

## Decisions

### D1. Resolve the inference gate with a repeatable footage and packaging trial

Start with an on-device LiteRT/TFLite person detector as the candidate, using Google's EfficientDet-Lite0 as the first model to benchmark. Its object detector supports person filtering and is offered in several quantizations; this does not establish that a particular weight file may be redistributed. Compare candidate runtime and weight combinations on the macOS development target using the available consented fixed-camera doubles clip (off-angle, with distant players, spectators, and slight occlusion); singles footage, the second court orientation, and rotation-tagged recordings are deferred. Record source, exact version/hash, model and training-data terms, app size, detection/count quality, latency, memory, and battery. Choose and pin one combination only after the legal and measured gates pass. Bundle approved weights so analysis works with networking disabled. If none passes, leave analysis explicitly unavailable rather than ship an unreviewed fallback. Mobile targets are out of scope.

Keep the selected backend behind `PersonDetector`. Its build integration must preserve a host-buildable Rust workspace, with target-specific native packaging isolated from shared engine crates. A safe Rust adapter or an equivalent bridge-owned native adapter is acceptable only if detection still reaches the Rust vision pipeline through a typed boundary and product code remains offline. Record the selected packaging path before implementing it. A platform-channel pipeline that moves tracking ownership into Dart would conflict with the existing single-engine design.

Use the optional `tflite-c-rs` 0.0.1 wrapper over a TFLite C library loaded from an explicit local path. Its small dependency set and Rust 1.70 minimum preserve the workspace's Rust 1.80 host build; the wrapper itself still needs review before distribution. The trial model is Google's EfficientDet-Lite0 Task Library variant, whose `DetectionPostProcess` op exposes boxes, classes, scores, and a count; the MediaPipe model download exposes raw anchors and needs a separate postprocessor. Keep both runtime and weights outside the checkout during evaluation. This trial does not select shipping assets or close the footage and license gates.

Alternative: choose a runtime or a model solely from published latency or an open-source runtime license. That cannot establish accuracy on badminton footage or the separate redistribution rights for model bytes.

### D2. Separate detections, court-player selection, and player-count inference

Decode sampled JPEGs to the backend's declared pixel layout and retain their original-timeline timestamps and displayed orientation. Run the detector over the full frame, then keep candidates whose estimated ground-contact point lies inside the calibrated court with a small, footage-tuned margin. Use the bottom-center of the box initially; do not project its center, which usually falls above the floor. Retain raw boxes and scores for review, including rejected candidates and the reason, so spectators and officials can be diagnosed. Do not hard-cap detections at two or four before filtering.

Infer a count across an interval of adequately observed frames: one stable track on each side supports singles, two on each side supports doubles. Return `unknown` when one side is repeatedly occluded, tracks are unstable, calibration is absent, or evidence does not consistently support either layout. Record count quality and the evidence window. The count describes observed on-court participants, not an immutable match property.

Alternative: infer two/four from a single high-confidence frame or the maximum number of boxes. This is brittle under occlusion and includes off-court people.

### D3. Track in image space, then project observed ground positions onto the court

Associate detections across ordered sampled frames using box overlap, ground-point displacement, elapsed time, and side continuity. Keep IDs stable within a generation across short occlusions, but end a track when the gap or association ambiguity exceeds footage-tuned limits. Do not invent positions in missing frames. Sampling rate is a tracking configuration, not the media pipeline's 1-fps default; begin evaluation near 5 fps and tune for continuity, accuracy, and device cost. Expose gaps and attempted/usable coverage rather than recording missing players as rest.

For each observed player point, normalize by the decoded frame dimensions, map through the calibration segment active at that timestamp, and obtain `CourtSide::First` or `Second`. A failed projection, point outside the court margin, proximity to the net, or ambiguous association yields an unknown side for that observation. Smooth side assignment over nearby observations; never change a track ID solely because its side changes. `First`/`Second` remain geometric halves; the client maps them to its existing score labels without treating camera-left as a score side.

Alternative: track only court coordinates. Image-space association retains useful continuity near a polygon boundary and makes the raw observations inspectable; projection remains the source of court positions.

### D4. Publish one regenerable artifact compatible with the existing consumer

Write a versioned `tracks/player_tracks.json` envelope atomically and mark `ArtifactKind::Tracks` final only after complete analysis. Its schema-1 `input` contains the existing rally contract: `duration_ms`, a calibration content identity, ordered non-overlapping coverage intervals, and ordered observed `TrackPosition` values with stable generation-local IDs. Add a separate producer section for detector/model/config identity, per-frame boxes, count assessment, side/quality information, and explicit gaps; keep the existing `input` fields readable by the rally consumer. Omit uncertain or out-of-court positions from the court-position stream, while retaining their observations for review. Bound artifact size through sampling and compact records rather than putting tracks in SQLite.

`sportcut-vision` owns court selection and the tracking result; `sportcut-api` owns the artifact adapter that converts that result into `sportcut-rally::SegmentationInput` and writes the envelope. This avoids making the earlier vision stage depend on the later rally stage while giving the current facade reader a typed producer contract.

The input fingerprint includes frame/proxy identity, sampling and tracking configuration, calibration identity, and exact model/runtime version. Reusing an artifact requires matching inputs. Changed calibration, frames, or model/configuration invalidates tracks and downstream rally suggestions. Reruns replace only derived artifacts; accepted rallies, confirmed scores, and kept clips stay in the client catalog. A cancelled run has no final track entry. Older matches with no tracks remain readable and can use manual review.

The macOS trial resamples and republishes on every explicit analysis run, so a changed sampling rate or tracking configuration invalidates the prior track and suggestion entries before new output becomes final. Reads check saved calibration identity; rally analysis also hashes current proxy and sampled frames. When trial runtime and model paths remain configured, reads compare their current bytes with the saved runtime/model identities. A playback-window read relies on manifest invalidation for proxy/frame rebuilds to avoid hashing the entire video on each scrub.

Alternative: store per-frame data in SQLite or silently reuse tracks after recalibration. Both violate the existing ownership/freshness split.

### D5. Use existing job and bridge surfaces for review

Run detection and tracking as stage-labelled, cancellable engine work. `sportcut-api` exposes start/read calls and typed summaries; the app accesses them only through `sportcut_engine.dart`. Show the observed count, uncertain/unknown state, track and side overlay, coverage gaps, and an actionable reason when analysis cannot run. This view offers evidence to the reviewer and never writes winners, score events, or reel selections.

## Risks / Trade-offs

- **Small distant players and body occlusion** → Evaluate on consented footage, preserve unknown count/side and coverage gaps, and retain manual review.
- **Default frame sampling is too sparse for motion** → Measure a higher tracking rate against continuity, processing time, storage, and battery before pinning a default.
- **Bounding-box bottom is not always a foot point** → Use a court margin and uncertainty band; revisit pose/keypoints only if footage shows the approximation fails.
- **Runtime package or model has incompatible redistribution terms** → Keep it off the shipping path until its exact binaries and weights have separate register verdicts.
- **Native inference threatens host-only engine builds** → Isolate target-specific packaging and check `cargo build --workspace` without the Flutter/Xcode client toolchain.
- **Camera cut or moved camera makes a saved homography stale** → Limit the first release to fixed-camera footage; require user recalibration and reanalysis when the viewpoint changes rather than claiming automatic cut detection.

## Migration Plan

Add the producer's review fields without changing the schema-1 rally `input` contract. Do not require a SQLite migration unless the UI needs a durable user choice; count and tracks remain regenerable engine data. Preserve older manifests and matches with missing tracks. Regenerate bridge files with the supported script, but commit only hand-written sources. On rollback, the client continues to load matches and manual rallies even if it ignores tracks; newer track artifacts remain derived and removable.

## Open Questions

- Which additional consented recordings (singles, second court orientation, rotation-tagged) will extend the doubles-only evaluation, and when?
- Which exact LiteRT packaging path works on macOS while preserving a host-buildable Rust engine and the single API facade?
- Does the first release need user correction of count or side, or is an explicit unknown result plus the existing manual review path sufficient?
