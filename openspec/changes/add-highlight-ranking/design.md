## Context

The pipeline already produces everything a ranking needs: the rally crate
scores each proposed rally with a `quality` (motion) signal, and the editing
catalog holds each rally's boundaries, winner, and derived score. The highlight
crate is an empty placeholder, and the app's `Rally.highlightScore` and
`HighlightClip.rank` fields exist but are never written.

The engine never reads the application's catalog. Like export (which renders
from an explicit edit decision list), ranking must be a pure function the app
feeds with the rally list it already holds.

## Goals / Non-Goals

**Goals:**
- Deterministic, engine-owned ranking of rallies into a `0..1` highlight score
  and a `1`-based rank.
- App surfaces the ranking so the best candidates come first.
- Accepted suggestions carry their motion quality so the signal is real.

**Non-Goals:**
- No audio-intensity ranking yet: accepted rallies do not record audio
  availability, so there is nothing to feed the signal. Leave for a later phase.
- No persistence of the computed score: it is cheap and deterministic, so it is
  recomputed on demand rather than stored and re-synced.
- No automatic reel: ranking proposes, the user still keeps/removes/orders.

## Decisions

### Ranking is a pure engine function, not a job
No files, no progress, no cancellation: ranking a few hundred rallies is
microseconds of arithmetic. A synchronous `rank_highlights` call matches
`court_geometry` and `probe_media`, which are also pure sync calls.

### The app sends the signals it already holds
`HighlightRallyDto` carries `start_seconds`, `end_seconds`, optional `motion`,
and `score_context`. The app derives `score_context` from the score timeline
(`1 / (1 + score gap)` for a confirmed rally, `0` for an unscored one). The
engine stays pure and does not need the catalog.

### Motion quality rides on the existing `confidence` field
`Rally.confidence` is documented as "confidence of an automatic suggestion,
always null for a manual rally". Accepting a suggestion already knows the
candidate's `quality`; storing it there makes the motion signal available at
ranking time with no schema change and no new field.

### Weighted blend, fixed weights for now
`score = 0.40·duration + 0.30·motion + 0.30·score_context`, where
`duration = (seconds / 30).clamp(0, 1)`, `motion` falls back to a neutral `0.5`
when unknown, and `score_context` is already `0..1`. Ties break by earlier
start time. Weights are a documented ceiling to tune once ranked footage
exists.

### One request DTO, list response
Follow the facade's existing convention of a single request struct parameter
(`rank_highlights(request) -> Vec<HighlightRankDto>`), so the bridge contract
is a stable object rather than a bare list.

## Risks / Trade-offs

- [Fixed weights may rank poorly on real footage] → `ponytail:` comment names
  the ceiling and the tuning path; the user still decides what to keep.
- [Unscored and manual rallies have no motion signal] → neutral fallback keeps
  them rankable by duration and score context rather than dropped.
- [Score context uses a crude gap formula] → deterministic and explainable;
  refined when real scoring data exists.
