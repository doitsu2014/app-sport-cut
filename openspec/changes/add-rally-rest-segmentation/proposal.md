## Why

Reviewers currently mark every rally boundary by hand. Wave 3 begins by using the existing analysis media and the planned player tracks to propose rally and rest spans, while keeping the user in control of the match timeline. The prerequisite tracking capability and its licensed on-device inputs are not yet available, so this proposal records the integration contract and the gate before implementation.

## What Changes

- Analyze time-stamped player motion and, when present, analysis audio to produce bounded, non-overlapping rally candidates and intervening rest spans on the recording timeline.
- Run analysis as a cancellable, stage-labelled local job. Store versioned suggestions as a regenerable engine artifact, separate from the user-authored SQLite review records.
- Show suggestions in the existing review screen. The user can accept, adjust, or dismiss each candidate; only an accepted candidate becomes a stored rally. Manual marking remains available.
- Preserve confirmed winners, score events, kept clips, trims, and clip order when analysis is rerun or calibration changes. Stale suggestions are invalidated and can be regenerated; accepted user edits are not silently overwritten.
- Leave winner inference and highlight ranking to later Wave 3 changes. Segmentation makes no claim that a candidate is a point or that either side won it.

## Capabilities

### New Capabilities

- `rally-segmentation`: local motion and optional audio analysis, suggestion lifecycle, rest spans, progress and cancellation, and invalidation when inputs change.

### Modified Capabilities

- `match-editing`: review can display and accept proposed rallies while keeping manual and confirmed records authoritative.

## Impact

- **Prerequisite:** Wave 2 person detection and player tracking must provide timestamped court-aware tracks. The project still lacks test footage, an approved inference runtime, and distributable model weights; those gates must be resolved before an end-to-end implementation can be verified.
- **Engine:** implement `sportcut-rally` over a tracking data contract and optional analysis audio, add a versioned artifact kind under the existing match directory, and expose an analysis job plus read-only suggestion DTOs through `sportcut-api`.
- **Client:** extend the typed bridge wrapper and the existing score/review flow; keep SQLite as the owner of accepted rallies and scores. A catalog migration is only needed if review decisions require durable suggestion identity beyond the engine artifact.
- **Compatibility and licensing:** regenerate bridge bindings through the supported script; preserve older match manifests and catalog rows. Any new inference, audio, or codec dependency needs a dependency-register verdict before it is introduced. Product processing remains offline.
