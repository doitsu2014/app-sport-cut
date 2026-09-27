## Why

Scoring a match is the most tedious part of the product: the user taps left or
right for every rally with no guidance. Phase 3's last deliverable — the
"serving-side heuristic" — is still missing, and `sportcut-score` is the last
empty placeholder crate. Badminton's serving rule gives a deterministic,
explainable default for free: the winner of a rally serves the next one, so the
side that just won is the side to propose next.

## What Changes

- The `sportcut-score` crate stops being a placeholder and gains a pure,
  deterministic `serving_sides` function: given rallies in order with their
  confirmed winners, it returns who served each rally.
- The bridge gains a `serving_sides` call, so the application does not
  re-implement the badminton rule itself.
- The score screen uses the result two ways: it proposes the server as the
  tentative winner on unscored rallies (one tap confirms, one tap flips), and
  it shows a serve indicator on the scoreboard so the user sees who serves next.

## Capabilities

### New Capabilities
- `serving-side-suggestion`: deriving who served each rally from the confirmed
  winners, proposing the server as the tentative winner, and showing the
  serving side on the scoreboard.

### Modified Capabilities
<!-- none -->

## Impact

- Engine: `core/crates/score` (new `serving_sides`), `core/crates/api` (DTOs +
  `serving_sides` facade), regenerated bridge bindings.
- Client: `app/lib/src/bridge/sportcut_engine.dart` (typed wrapper),
  `app/lib/src/features/score/presentation/score_screen.dart` (suggested
  winner + serve indicator).
- No new dependencies, no persistence, no network access. Everything is
  derived from the rally winners the application already records.
