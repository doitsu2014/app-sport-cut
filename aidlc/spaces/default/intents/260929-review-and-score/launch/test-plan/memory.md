# Test Plan — diary

## Interpretation
- 2026-09-29: The risk here is regression of a cosmetic grouping, not failure of
  behaviour. The plan therefore aims effort at a single ordering assertion and
  keeps everything else at manual/static level.

## Tradeoff
- 2026-09-29: The plan recommends one widget test but explicitly gates it on the
  repo's "no new test files unless asked" rule, so Test Generation is not put in
  conflict with `AGENTS.md`.

## Open question
- 2026-09-29: Whether the rail can be pumped at a small boundary or needs the
  full `WorkspaceStudioScreen` with providers. Left to Test Generation.
