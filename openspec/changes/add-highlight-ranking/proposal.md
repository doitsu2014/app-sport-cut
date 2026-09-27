## Why

The highlight reel is the product's payoff, but today the user builds it by
hand: every rally is equally suggested and the user decides what to keep with
no ranking to guide them. Phase 4 ("Highlight intelligence") is not started, and
the `sportcut-highlight` crate and the `Rally.highlightScore` / `HighlightClip.rank`
fields already exist waiting for it. A deterministic ranking of rallies by what
the app already knows — duration, movement, and score context — lets the app
surface the best candidates first and cuts the work of picking a reel.

## What Changes

- The `sportcut-highlight` crate stops being a placeholder and gains a pure,
  deterministic `rank` function that scores rallies from duration, optional
  motion quality, and score context, returning a `0..1` score and a `1`-based rank.
- The bridge gains a `rank_highlights` call: the app sends its rally list (with
  the signals it already holds) and receives a score and rank per rally.
- Accepting a rally suggestion records that suggestion's motion quality on the
  rally (as its `confidence`), so accepted rallies carry a real motion signal
  rather than a neutral one.
- The highlights screen ranks rallies and surfaces the best candidates first,
  with a one-tap "keep the best N" action. The user still keeps, removes, and
  orders clips; the ranking only proposes.

## Capabilities

### New Capabilities
- `highlight-ranking`: scoring rallies into a suggested highlight order from
  duration, motion, and score context, surfaced in the highlights screen.

### Modified Capabilities
<!-- none -->

## Impact

- Engine: `core/crates/highlight` (new `rank`), `core/crates/api` (DTOs +
  `rank_highlights` facade), regenerated bridge bindings.
- Client: `app/lib/src/bridge/sportcut_engine.dart` (typed wrapper),
  `app/lib/src/features/editing` (thread suggestion quality into accepted
  rallies), `app/lib/src/features/highlights` (ranked suggestions UI).
- No new dependencies, no network access, no model assets. All signals come
  from data the application already holds.
