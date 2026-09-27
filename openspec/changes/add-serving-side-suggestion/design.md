## Context

The engine already tracks which side won each confirmed rally (the application
stores `winner_side`), and the application derives the score from those winners.
Badminton's rally-point rule is local: the winner of a rally serves the next
one. That rule is exactly the "serving-side heuristic" Phase 3 named, and it
belongs in `sportcut-score`, the crate designated for score logic.

The engine never reads the application's catalog, so — like highlight ranking —
the application sends the rally outcomes it already holds and receives the
serving sides back.

## Goals / Non-Goals

**Goals:**
- Deterministic, engine-owned serving-side computation for an ordered rally list.
- The score screen proposes the server as the tentative winner on unscored
  rallies and shows who serves next on the scoreboard.

**Non-Goals:**
- No serve-court parity (which service box the server stands in): the scoreboard
  shows the serving side, not the box.
- No game/match structure (deuce, sets): out of scope until scoring needs it.
- No winner confidence or motion-based guessing: this is the serving-side
  heuristic only, and it is deliberately a weak, explainable prior.

## Decisions

### Serving side = winner of the previous rally
The rule is local (`server[N] = winner[N-1]`), so a suggestion for a rally only
needs the immediately previous rally to be confirmed — no chain from the start
of the match. The first rally has no previous winner and therefore no
suggestion.

### Suggested winner = server
The server is proposed as the tentative winner. It is a weak prior, not a
prediction: the user confirms with one tap or flips with one tap. This is the
literal reading of the roadmap's "serving-side heuristic" and keeps the
suggestion explainable ("suggested because this side serves").

### Pure synchronous call
No files, no job, no progress: the function is arithmetic over the rally list
the caller supplies, matching `rank_highlights` and `court_geometry`.

### No persistence
Serving sides are derived from the confirmed winners already stored, so nothing
new is written. The serve indicator is the winner of the last confirmed rally.

## Risks / Trade-offs

- [The prior is weak (roughly a coin flip with momentum)] → it is framed as a
  default to confirm, never as an automatic result; a wrong suggestion costs
  the same tap a manual choice already did.
- [The first rally has no suggestion] → acceptable: one manual tap seeds the
  rest of the match.
- [An unscored rally in the middle hides the next rally's suggestion] → the
  rule is local, so only the immediately following rally is affected; it clears
  as soon as the user confirms that rally.
