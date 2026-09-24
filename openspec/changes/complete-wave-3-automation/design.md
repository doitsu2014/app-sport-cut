## Context

The first Wave 3 change, `add-rally-rest-segmentation`, defines editable rally proposals and a separate user-owned review record. The existing client already derives the score timeline solely from confirmed `Rally.winnerSide` values and stores a user-ordered highlight reel. `sportcut-score` and `sportcut-highlight` are empty crates; `Rally.confidence`, `Rally.highlightScore`, and `HighlightClip.rank` are reserved but do not currently express their provenance or freshness. This change follows segmentation without altering its artifact or acceptance contract.

The engine may read local media artifacts but not the Flutter SQLite catalog. The client must pass the current accepted rally boundaries, confirmed score events, and available user choices as a typed snapshot. Court calibration and future tracking provide normalized positions, not metric speed or a reliable view of shuttle landing. The project still lacks representative labeled footage, model weights, and an approved inference runtime.

## Goals / Non-Goals

**Goals:**

- Offer a side suggestion only when local evidence can support one, and otherwise abstain with a clear reason.
- Keep the score timeline a pure consequence of explicit winner confirmation, including corrections and skips.
- Rank eligible rallies transparently from duration, normalized movement, optional audio, and confirmed score context.
- Make reruns and input changes safe for user-authored rallies, scores, kept clips, trims, and reel order.

**Non-Goals:**

- Automatic officiating, shuttle landing detection, or a guaranteed side suggestion for every rally.
- Reimplementing tracking or segmentation, selecting model/runtime assets, or collecting footage without consent.
- Creating, removing, trimming, or reordering kept clips automatically; changing export decisions or rendering.
- Claiming movement speed in metres from the current unit-square court calibration.

## Decisions

### D1: Use a snapshot boundary between SQLite and the engine

The client submits accepted rally IDs and boundaries, confirmed winners/score context, and optional user ratings with an analysis request. The engine joins these with local track and audio artifacts and returns immutable score suggestions and ranked recommendations. Each result includes a fingerprint of the exact rally snapshot and artifact generations plus an algorithm version. The client shows a result only when those identities still match the current match state.

This preserves the established ownership boundary. Letting the engine write SQLite would introduce two authorities for scores and clips; storing a suggestion directly in `Rally.winnerSide` would make an unconfirmed guess appear as a point.

### D2: Winner suggestion is a conservative, abstaining stage

`sportcut-score` accepts an explicit `SideEvidence` record for a rally, with source, temporal coverage, and a calibrated confidence. It may use a validated next-serve cue or another reviewed local cue once representative labeled footage demonstrates that it actually distinguishes the rally winner. The implementation must not infer a winner solely from rally duration, movement amount, which side moved more, or the last confirmed winner. If no validated cue is available, or evidence is contradictory/low quality, it returns `no_suggestion` with a reason. It never edits a winner or score event.

The concrete cue and confidence threshold are a release gate, not an invented promise: player bounding boxes and court halves alone do not identify a landing or error. A naive always-left/right heuristic would satisfy an API shape while making review worse.

### D3: Score review shows a proposal beside independent actions

The existing score screen displays the proposed side, confidence band, and short source explanation when one exists. Left, right, and skip remain equally available. Confirming either side calls the existing winner update path, which recomputes subsequent score events. Skipping leaves the rally unscored. A prior confirmation is never overwritten by a new or changed suggestion; a corrected winner stays authoritative.

This avoids a confirmation control that implicitly accepts the model's choice. The user can make a one-tap decision without the model becoming the source of truth.

### D4: Rank reviewed rallies, never mutate the reel

`sportcut-highlight` calculates a bounded score per accepted rally. Duration and normalized court movement are primary features; audio intensity and confirmed score context contribute when available. Normalization is per match with bounded/clipped values so a single outlier does not dominate. Missing features are omitted and remaining weights renormalized; every recommendation carries its available feature contributions and an uncertainty/coverage indicator. Ties break by recording time, so results are reproducible. Very short or incomplete rallies receive a documented penalty, but are still visible.

The highlights screen shows a ranked suggestion list for rallies not yet kept. A deliberate keep action creates a clip through the current repository path. The selected reel continues to use `orderIndex`, user trims, and user removal; reranking changes only the suggestion list. The reserved `highlightScore` and `rank` fields can be populated only if their generation is tracked; otherwise the read-only result DTO is preferable to a stale catalog value.

### D5: Share derived features and invalidate by input identity

The two stages can share a versioned per-rally feature summary derived from tracks and audio, but neither stage requires a new model dependency. An optional engine cache under the existing `tracks/` artifact directory is keyed by calibration, track and audio artifact identities, accepted rally boundaries, confirmed score snapshot, and algorithm version. Publish only complete results. Recalibration, retracking, boundary edits, or score corrections make a cached result stale; the client can request a rerun. No invalidation path deletes user-authored catalog records.

Computing once per screen without a cache is acceptable initially if latency is small. The cache is a performance choice, not a second durable source of truth.

## Risks / Trade-offs

- **Winner evidence may never reach a useful accuracy threshold on ordinary phone footage.** → Measure on consented labeled footage before showing side suggestions; keep abstention and manual one-tap confirmation as the shipping fallback.
- **Score context can change after one correction.** → Fingerprint the confirmed timeline and recompute rankings; never use unconfirmed suggestions as score context.
- **Audio or tracks can be absent or noisy.** → Omit missing feature contributions, expose coverage, and avoid presenting a precise score as certainty.
- **A ranking can bias users toward mediocre clips.** → Show contributing reasons and keep all candidate rallies accessible; the user retains the reel controls.
- **Long analysis can contend with import/export jobs.** → Reuse the existing single-heavy-job registry for work that reads full track/audio artifacts and support cancellation.
- **Older clients cannot parse new bridge DTOs or manifest kinds.** → Keep the API additive and version any persisted artifact; read older match data without requiring the new outputs.

## Migration Plan

Additive bridge and client changes load existing matches with no suggestions or ranks. No migration of `rallies`, `score_events`, or `highlight_clips` is required if insights remain derived read-only data. If caching or user ratings need durable fields, add a separate versioned migration without backfilling guessed values. Rollback ignores derived insights and leaves manual scoring and the existing reel intact.

## Open Questions

- Which local side cue, if any, can be validated on representative singles and doubles footage, and what minimum precision/abstention trade-off is acceptable before it is shown?
- Whether user favorites/manual ratings should be part of this wave's ranking input or a later editing enhancement; the roadmap's required four signals do not depend on them.
- Whether on-device performance warrants a persisted shared feature cache; measure before adding a new manifest kind.
