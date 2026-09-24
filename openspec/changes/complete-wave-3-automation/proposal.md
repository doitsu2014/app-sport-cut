## Why

The Wave 3 roadmap promises a shorter review loop: rally boundaries, a suggested side for each point, and a ranked set of highlights. The existing `add-rally-rest-segmentation` change defines the boundary proposal step; this change completes the wave with score suggestions and highlight ranking while preserving explicit user confirmation.

## What Changes

- For each reviewed rally with sufficient local evidence, propose a left or right winner with a visible confidence and reason; abstain when evidence is weak. The user can confirm, choose the other side, or skip. Only that action changes the stored winner and score timeline.
- Rank eligible rallies using duration, normalized player movement, audio intensity when present, and the context of confirmed score events. Show the reasons for a recommendation and degrade gracefully when a signal is missing.
- Present ranked candidates separately from the user's selected highlight reel. Keeping a candidate is explicit; reranking never changes kept clips, their trims, or their order.
- Recompute stale suggestions when boundaries, tracks, calibration, audio, or confirmed score context change. Preserve all user-authored decisions and keep the product fully offline.
- Treat `add-rally-rest-segmentation` and Wave 2 player tracking as prerequisites. This change does not duplicate segmentation, choose an inference runtime, ship model weights, or claim automatic officiating.

## Capabilities

### New Capabilities

- `score-suggestion`: optional, explainable side suggestions per rally, abstention, confidence, and invalidation without automatic score writes.
- `highlight-ranking`: reproducible rally recommendations from available local signals, with explicit user selection and stable reel ownership.

### Modified Capabilities

- `match-editing`: winner review can display a suggested side while preserving one-tap confirmation and the confirmed-only score contract.

## Impact

- **Dependencies:** `add-rally-rest-segmentation` supplies reviewed boundaries and candidate identity; Wave 2 tracking supplies court-aware motion. Representative consented footage, a licensed inference path and model weights, and a usable tracking artifact remain gates for the full pipeline.
- **Engine:** `sportcut-score` and `sportcut-highlight` become local analysis stages; `sportcut-api` exposes typed suggestions through the existing job/read pattern. Derived outputs are versioned and invalidated with their inputs.
- **Client:** score and highlights screens show suggestions and reasons. The existing SQLite catalog remains authoritative for confirmed winners, score events, and kept clips; bridge bindings are regenerated, never edited or committed.
- **Licensing and release:** any new dependency or asset receives a dependency-register verdict. No network service or automatic score write enters the product path. This change does not resolve the separate mobile export backend and codec distribution gates.
