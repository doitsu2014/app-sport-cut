# Intent Statement — Workspace and Library (Feature 1)

Status: Analyze / Intent Capture
Intent: `261029-implement-brd-feature`
Date: 2026-10-29
Sources: `docs/brd/01-workspace-and-library.md`, `docs/brd/00-product-context.md`,
`docs/adr/0001-rust-background-service.md`, `docs/adr/0003-*.md` (studio
decisions), `CLAUDE.md`.

## Problem

Sportcut's first surface is where a player keeps and opens badminton matches:
the workspace home and the three-pane studio. The BRD records feature 1 as
**Partial** at baseline `1541c64`, but the studio refactor has since shipped most
of the surface (search, focus mode, keyboard shortcuts, status bar, timeline
dock, missing-recording state). The BRD status table has drifted from the code,
so nobody can say which `FR-LIB` requirements are genuinely unmet. Without that
answer, later phases either rebuild shipped behavior or ship a real gap.

## Users

- **The player/analyst** importing a local recording and reopening it to review
  and score rallies. They need to find the right match fast and trust that a
  missing file is named, not silently skipped.
- **The product owner** gating v1 on the BRD's Must requirements, who needs the
  status table to match HEAD before sign-off.

## Success criteria (observable)

1. Each of the 37 `FR-LIB` requirements is audited against HEAD and recorded as
   Satisfied, Partial, or Missing, with the file and symbol that proves it.
2. Every requirement the audit marks Missing or genuinely Partial and that is
   **in scope** (see below) is implemented.
3. `flutter analyze` is clean for `app/`; `tools/check-no-rust-in-app.sh` passes.
4. The BRD §2.3 status table is reconciled with the implemented state, so the
   next reader does not repeat this audit.
5. No requirement marked out of scope is implemented silently.

## In scope

- The audit itself and the reconciled status.
- Workspace home: list, create, open, delete, loading, empty, and error states.
- Studio entry and video rail: selection, search/filter, pipeline state, status
  bar, missing-recording state.
- Match and workspace deletion, including the "never touch the user's original
  file" rule.
- Local playback of the app-owned recording copy.
- Only gaps the audit confirms, and only within the client-owned v5 catalog.

## Out of scope

- Workspace rename, reorder, or archival (BRD §2.2; open question Q-8).
- A cross-workspace or all-matches library view (BRD §2.2).
- Tags, favourites, ratings, custom sort, saved filters, thumbnails.
- Folder/playlist/multi-file import; touching the user's original file.
- Cloud sync or any remote library.
- Moving the catalog or recording custody into the Rust service (ADR-0001
  Phase 4) — explicitly deferred by the human answer to Q2.
- New test files or new test cases (project working agreement; Q3-A).

## Constraints

- Client track only: Dart/Flutter, Riverpod, `flutter analyze` as the verification.
- The app reaches the engine only through `app/lib/src/bridge/sportcut_engine.dart`.
- No new durable client-owned state; existing v5 catalog and app-owned copy stay.
- No network, telemetry, or online API.
- Design-system tokens are the single source of colour, type, spacing, radius,
  elevation, and motion; no raw hex outside the token file.
- The semi-automatic rule holds: the engine proposes, the user confirms.

## Assumptions

- The BRD status table is stale relative to HEAD, not wrong about intent.
- `FR-LIB-15` ("Locate state") is satisfied by ADR-0003 D8's deliberate
  "name the fact, offer no fake relocate action" design; the audit will confirm
  or reject this reading.
- The Flutter toolchain may be absent on this machine (BRD risk R-7); if
  `flutter analyze` cannot run, the gap is reported rather than hidden.

## Cost of doing nothing

The BRD keeps reporting Partial with stale evidence. The next phase either
re-implements shipped screens or ships a requirement gap while the status table
says otherwise. Both waste a release cycle and erode trust in the BRD as the
requirements source.
