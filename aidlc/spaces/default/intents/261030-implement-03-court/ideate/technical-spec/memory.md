# Technical Specification — Stage Diary

## Interpretation

- 2026-10-30: Specified `ScCourtGeometry` as a strict invariant (4 + 2 finite
  points) rather than a permissive type, so "valid geometry" is a single
  predicate the host and painter can share.
- 2026-10-30: Kept the instruction copy on the host (the production caller) and
  the component default in sync; the spec names the exact sentence so review can
  check the "names the projected net" criterion.

## Tradeoff

- 2026-10-30: Specified a consumer scan for `overlayBed` instead of deciding the
  shared-vs-local question now. The cost is one implementation decision; the
  benefit is that the result is based on actual consumers.
- 2026-10-30: Left the `ScTransport` flag as a boolean `accent` rather than a
  richer theme variant, keeping the change reversible and local.

## Open question

- 2026-10-30: The scrubber's current signal usage was not fully read; the spec
  states the required outcome (neutral fill/thumb when `accent` is false) and
  leaves the exact property names to implementation.
