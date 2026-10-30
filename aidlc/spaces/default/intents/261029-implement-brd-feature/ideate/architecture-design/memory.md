# Architecture Design — Stage Diary

## Interpretation

- 2026-10-29: Read "selected stage in the status bar" as a derived UI value, not
  a stored fact. It belongs to the ephemeral studio controller (ADR-0003 D10),
  so it is mapped to copy at the shell edge.
- 2026-10-29: Chose `ScProgressJob` for the home loading state because the
  studio already uses that vocabulary for long reads; a bare spinner would
  introduce a second progress idiom.

## Deviation

- 2026-10-29: Ran the security review inline against the architecture document
  instead of dispatching a separate agent, because the change adds no trust
  boundary and the review is advisory.

## Tradeoff

- 2026-10-29: Adding a constructor parameter to `StudioStatusBar` touches every
  call site, but keeps the widget provider-free and directly testable.

## Open question

- 2026-10-29: None.
