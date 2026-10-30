# Intent Capture — Stage Diary

## Interpretation

- 2026-10-29: Read "implement feature 1" as BRD feature 1, Workspace and Library
  (`LIB`), because the BRD index numbers it first and the request names the BRD.
- 2026-10-29: Read the request as gap-closing, not greenfield. HEAD has shipped
  most of the surface since the baseline the BRD status table cites; the audit
  is the deliverable that decides what is left.
- 2026-10-29: Treated `FR-LIB-15` (Locate state) as satisfied by ADR-0003 D8's
  "no fake relocate action", pending the audit. The BRD row and the ADR disagree
  only if the audit finds a missing state the ADR does not cover.

## Deviation

- 2026-10-29: The first `orchestrate next` call used the `my-aidlc` binary on
  `PATH`, which is a different engine (native AWS AI-DLC 2.11.0) from the repo's
  `.claude/tools/my-aidlc.mjs` (5-phase). It rewrote `aidlc/state.json` and
  dropped the previous intent's stage history. Reverted `aidlc/state.json` and
  `aidlc/audit.log`, removed the stray intent and space-scope files, and reran
  against the repo engine. Candidate learning.

## Tradeoff

- 2026-10-29: Kept the client-owned v5 catalog rather than migrating to the
  service. Cost: the ADR-0001 target stays unmade and feature 1's custody
  requirements are audited against the interim architecture, not the target.

## Open question

- 2026-10-29: Q-8 (workspace rename/reorder, cross-workspace library) stays
  open. The audit will mark those requirements out of scope, not implement them.
