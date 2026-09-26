## Why

Court calibration is complete, but the engine cannot yet locate players or produce the court-aware tracks needed by rally segmentation and later highlight ranking. This change fills that Wave 2 gap on macOS while keeping uncertain detections and player counts visible as uncertain evidence rather than presenting them as facts.

## What Changes

- Add an offline person-detection backend for sampled, upright analysis frames, with a selected and distribution-reviewed runtime and model weights.
- Identify likely on-court players and report whether sustained observations support two players, four players, or an unknown count. Missing or occluded people must not silently change the match format.
- Link detections across sampled frames into timestamped player tracks with explicit coverage and gaps. Map a representative ground-contact point through the saved calibration and assign a court side when the evidence supports one.
- Publish a versioned, regenerable `tracks/player_tracks.json` artifact that the existing rally segmenter can consume. Keep track identity local to one artifact generation and invalidate derived suggestions when its inputs change.
- Expose analysis status and read-only results through the existing job and typed bridge surfaces so the client can show evidence and actionable unavailable states. Keep every media and inference operation on-device.
- Deliver and evaluate the full working path on macOS, the product's shipping target.

## Capabilities

### New Capabilities

- `person-detection`: Offline detection of likely on-court people in sampled frames and a quality-aware two/four/unknown player-count assessment.
- `player-tracking`: Time-stamped player identity, calibrated court positions, side assignments, coverage, and a versioned artifact for downstream analysis.

### Modified Capabilities

None. Existing media sampling, calibration, processing jobs, and rally review contracts are reused.

## Impact

- **Engine:** `sportcut-vision` gains inference and tracking stages; `sportcut-api` gains job/read calls; the existing media, court, storage, and rally crates provide frames, geometry, artifacts, and a downstream consumer.
- **Client and bridge:** generated bindings are regenerated, while hand-written Dart wrappers and a focused macOS analysis/review surface present count, tracks, progress, and uncertainty.
- **Assets and distribution:** representative consented singles and doubles footage, a pinned on-device runtime, and individually licensed model weights are prerequisites. Record runtime, weights, and any relevant training dataset in `docs/legal/dependency-register.md` before they ship; no GPL component or network dependency enters the product path.
- **Compatibility:** preserve old match directories and user-authored rallies, scores, and clips. Reanalysis replaces only derived evidence and proposals.
