## Context

The manual score screen already stores rallies, confirmed winners, score events, and clips in SQLite. `sportcut-rally` is empty. The media pipeline supplies timestamped frames and optional analysis audio; court calibration is available, but person tracking is not. The roadmap makes tracking a prerequisite for segmentation, and the project has no approved inference runtime, model weights, or evaluation footage yet. This design defines the consumer side of that future track contract without selecting a model or adding a shipping dependency.

The engine owns regenerable analysis artifacts in the match directory. The app owns user decisions in SQLite. Existing job handles provide progress and cancellation; only `sportcut-api` crosses the Flutter boundary. This split is especially important here because rerunning analysis must not rewrite a user's score or reel.

## Goals / Non-Goals

**Goals:**

- Propose rally boundaries and the rest intervals between them from court-aware player motion, with audio as an optional corroborating signal.
- Give each proposal a reproducible identity and an explicit quality indicator so the UI can distinguish a suggestion from a user decision.
- Let users accept, adjust, and dismiss proposals while retaining manual editing.
- Keep analysis cancellable, offline, and regenerable without touching confirmed review data.

**Non-Goals:**

- Person detection or tracking implementation, model/runtime selection, or shipment of weights.
- Winner inference, official scoring, automatic highlight ranking, shuttlecock detection, or metric movement speed.
- Automatic removal of inactive video from a user's reel or export.

## Decisions

### D1: Require usable tracks; treat missing audio as normal

The segmenter consumes monotonically timestamped per-player positions in normalized displayed-frame or calibrated court coordinates, an explicit track coverage interval, and a calibration/input version. It estimates activity from displacement and participation across sampled times. Audio intensity can support an activity transition but cannot create a rally on its own. If tracks, calibration, or usable coverage are missing, the job returns an actionable unavailable result; it does not claim that the recording has zero rallies. If audio is absent, motion-only analysis proceeds and records that limitation in the output.

This follows the roadmap's dependency on tracking. Audio-only segmentation would be easy to scaffold today, but background voices, music, and hall noise can produce plausible false rallies without any visual support.

### D2: Use a bounded state machine, not point-by-point labels

`sportcut-rally` converts irregular track samples into a fixed-time activity series, smooths short gaps, applies separate enter/exit thresholds, then merges or rejects spans using configurable minimum rally and rest durations. It emits ordered, non-overlapping half-open intervals `[start, end)` within the original recording duration. The complement is labeled rest or unknown where track coverage is insufficient; unknown is never silently treated as rest. A candidate carries a bounded confidence/quality value and the signal-availability flags used to derive it. Thresholds and algorithm version are recorded so a result can be reproduced and tuned against consented footage.

This deterministic first pass gives users inspectable boundaries without binding the engine to a training dataset. A learned temporal classifier can later replace the scoring stage while preserving the artifact and review contract.

### D3: Keep suggestions in an engine artifact and decisions in SQLite

Write `tracks/rally_suggestions.json` as a versioned `RallySuggestions` manifest artifact. It contains the input fingerprint, algorithm version, candidate IDs, rally intervals, rest/unknown intervals, quality values, and signal provenance. Compute the fingerprint from the consumed track artifact, calibration version, available audio artifact, and algorithm parameters; candidate IDs are deterministic within that fingerprint. Write through a temporary file and publish the final manifest entry only after success. A cancelled or interrupted job leaves no final suggestion set.

The app adds a small `rally_suggestion_decisions` table keyed by match and candidate ID for accepted/dismissed choices. Acceptance creates an ordinary unscored rally with the candidate's boundaries in the existing `rallies` table and records the link in one SQLite transaction. Dismissal records only the decision. No suggestion row becomes a winner, score event, or clip by itself. A repeated run with the same fingerprint keeps decisions; a changed input creates a new generation, and the UI suppresses new candidates that overlap accepted/manual rallies until the user explicitly reviews a conflict. Previously dismissed candidates from an old generation are not assumed equivalent to new ones.

An alternative is to copy every candidate directly into `rallies` and add a status such as `suggested`. That would make existing score and reel code handle machine output everywhere and complicate deletion. Separating the two keeps the current catalog's meaning intact.

### D4: Integrate with the existing review and job surfaces

`sportcut-api` exposes start/read calls for the analysis job and its suggestion result, with job status and cancellation reused. The Dart bridge wrapper maps DTOs into feature models. The score screen shows suggestions beside existing rallies with accept, boundary-adjust-and-accept, and dismiss actions; a reviewer can still mark spans manually. Analysis progress and input errors are visible without blocking manual review. The client never imports generated bindings from feature code.

### D5: Invalidate derived proposals, preserve user decisions

A change to calibration or track inputs invalidates `RallySuggestions` and its manifest entry. Audio regeneration or an algorithm-parameter change invalidates it through the input fingerprint on read, even if the old file remains. The app does not delete accepted rallies, winner confirmations, score events, or clips when this happens. Orphaned decision rows can be retained for a matching generation or cleaned during a later catalog migration; they are not displayed against a different fingerprint.

The alternative of clearing the whole review on recalibration would erase user work. Keeping stale suggestions visible would present boundaries computed from the wrong court or track data.

## Risks / Trade-offs

- **Tracking is not available yet.** → Build the pure segmentation contract and UI only against a documented track schema; do not call the feature ready until the Wave 2 tracking change and licensed inputs exist.
- **False or missed boundaries on noisy footage.** → Mark results as suggestions, expose quality/coverage, allow manual adjustment and marking, and evaluate thresholds on consented representative recordings before rollout.
- **Sparse or interrupted tracks can look like rest.** → Represent unknown coverage separately and reject a confident result when coverage is inadequate.
- **Candidate IDs change when inputs change.** → Persist decisions per generation; preserve accepted rallies; require review of new overlapping candidates.
- **Manifest compatibility changes when a new artifact kind is added.** → Bump the manifest schema with an explicit older-engine error and keep older manifests readable by the new engine.
- **The local workstation FFmpeg is development-only and GPL.** → Do not add it to a shipping path; use only the existing local analysis interface until a licensable mobile media path is available.

## Migration Plan

Add the suggestion-decision table through the next catalog migration; existing matches load with no decisions. Add the new artifact kind with a manifest schema bump and migration/read compatibility for existing match directories. Rollout can leave the analysis action unavailable until tracks exist, while manual review continues. Rollback must preserve the existing rallies and score data even if a build ignores suggestions.

## Open Questions

- What exact track schema and coverage quality will the Wave 2 tracking change commit to? The segmenter adapter must be finalized against that change before implementation.
- What representative, consented footage can be used to choose thresholds and measure boundary error for singles, doubles, fixed baseline views, and silent recordings?
- Whether the first UI should show an explicit rest lane, or only shaded gaps between rally candidates. The artifact records rest and unknown either way.
