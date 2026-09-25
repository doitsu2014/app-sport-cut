# Player Detection and Tracking Evaluation

This is the measurement plan for OpenSpec change `add-player-detection-tracking`.
The first development target is the local MacBook Pro (Mac16,6, Apple M4 Max,
36 GB RAM). The product's mobile distribution target remains a separate
packaging and device-verification decision. No representative recordings or
approved model weights are present in the checkout yet. Keep evaluation footage
outside the repository and record its provenance before use.

## Footage register

For each consented clip, record a local path outside the checkout, who granted
use for local evaluation, date, duration, resolution, orientation/rotation tag,
camera position, singles/doubles ground truth, and whether it includes distant
players, occlusion, spectators, or a camera change. Do not put player names or
footage in this document. Keep a separate local annotation file if needed.

Use fixed-camera clips from both court orientations. Label a stratified set of
frames from each clip, including quiet periods and difficult frames, with every
visible on-court player's box and side. Label several continuous intervals for
track IDs, gaps, and count. Reserve some clips from threshold tuning for a
held-out check.

## Measurements and provisional acceptance thresholds

| Measure | Method | First-pass threshold |
| --- | --- | --- |
| Clean-video player count | Compare the sustained two/four assessment with the known match format for each clean held-out video | At least 85% correct, matching `docs/README.md` Phase 0 |
| Uncertain-video count | On occluded or inconsistent intervals, count confidently wrong assessments and unknown results separately | No more than 5% confidently wrong; unknown is allowed and reported |
| On-court person detection | Match detections to visible labeled players at box IoU ≥ 0.5; report recall and precision by near/far side | At least 90% recall and 90% precision on clean labeled frames |
| Track continuity | Compare IDs across labeled continuous intervals; report ID switches per player-minute and observed-position coverage | At most 1 ID switch per player-minute; at least 80% coverage of visible player time |
| Side assignment | Compare assigned first/second side with labeled court half; report unknown separately | At least 95% correct among assigned sides on clean frames |
| End-to-end processing time | Analyze a 20-minute 720p clip, including frame decode and artifact writing, three runs on the development Mac | Median at most 20 minutes; report all three runs |
| Peak memory | Record peak resident memory for the analysis process during the same runs | At most 2 GiB incremental RSS |
| Derived storage | Measure sampled frames plus track artifact for the 20-minute clip | At most 500 MiB; report components separately |
| App size | Compare packaged macOS app size before and after adding runtime plus weights | Increase at most 100 MiB; report exact component sizes |
| Energy | On battery at 40–80% charge, compare three 20-minute analysis runs with three idle runs under the same display and power settings | Median additional drain at most 10 percentage points; report all six readings |

These thresholds guide the first candidate comparison; they do not certify a
model or its redistribution terms. Break out failures for distant players,
occlusion, spectators, orientation, and camera position. A result marked
`unknown` is not counted as a correct two/four prediction. Record the runtime,
model checksum, quantization, sampling rate, thresholds, hardware, OS, and
analysis configuration with every result. If battery readings are too coarse
for a reliable comparison, record that limitation and keep the energy gate open.

## Decision record

Compare the initial EfficientDet-Lite0 candidate with a second candidate only
if the first misses the accuracy, size, or performance targets. Before choosing
weights for the product, verify their license separately from the runtime and
the training dataset, then update `docs/legal/dependency-register.md`. Confirm
local inference with networking disabled. A Mac result establishes development
feasibility; mobile packaging and device cost need their own measurements before
a mobile release.
