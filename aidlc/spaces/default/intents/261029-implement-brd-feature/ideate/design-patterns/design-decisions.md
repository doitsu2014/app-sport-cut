# Design Decisions — Workspace and Library gaps (G1–G4)

Status: Ideate / Design Pattern Selection
Intent: `261029-implement-brd-feature`

## D-1: Derived presentation state at the composition root

- **Context:** The status bar must report the selected stage, which is ephemeral
  UI state owned by the studio controller.
- **Decision:** `WorkspaceStudioScreen` maps `selectedStage` to a label and
  passes it down through `StudioShell` to `StudioStatusBar`.
- **Alternatives:** The status bar reads the provider (couples a leaf widget to
  Riverpod); add the stage to `VideoStageFacts` (mixes UI selection into a
  facts model).
- **Consequences:** One more constructor parameter; the leaf stays pure and
  directly renderable. Cost: the shell grows a mapping table, duplicated from
  `stage_strip.dart` unless the table is shared.
- **Status:** Accepted. Reuse the existing `_shortStageLabels` vocabulary by
  exposing one shared label helper instead of copying the map.

## D-2: One progress idiom

- **Context:** The home loading state needs a progress indicator (FR-LIB-05).
- **Decision:** Reuse `ScProgressJob` with the stage label "Reading workspaces".
- **Alternatives:** A bare `CircularProgressIndicator`; the current static
  `ScEmptyState`.
- **Consequences:** Consistent with the studio's progress vocabulary; no new
  component. Cost: slightly taller than a bare spinner.
- **Status:** Accepted. The home screen and the studio share one progress idiom.

## D-3: Reason-bearing error copy

- **Context:** FR-LIB-06 requires the reason in the error state.
- **Decision:** Format the `AsyncValue.error` into the existing sentence:
  `The workspaces could not be read. <reason>`.
- **Alternatives:** Show the exception type only; show a generic sentence.
- **Consequences:** The user can act on the failure (NFR-13). Cost: raw platform
  messages appear in copy (accepted, local-only).
- **Status:** Accepted.

## D-4: Index-preserving selection after delete

- **Context:** FR-LIB-24 requires the next remaining video, not the first.
- **Decision:** Capture the deleted entry's index before the write; after the
  refresh, select `entries[min(index, length - 1)]`, or nothing when empty.
- **Alternatives:** Always select the first remaining; always clear selection.
- **Consequences:** The user stays near where they were. Cost: one index value
  held across an async boundary; guarded by `mounted`.
- **Status:** Accepted.

## Existing patterns preserved

- Data-in / callback-out leaf widgets (ADR-0003 consequences).
- Riverpod providers for shared state and dependency injection.
- No new durable client state (ADR-0003 D10).
- Design tokens for every visible value (DS-1).

## Deviations

None. Every decision reuses a pattern already in the codebase.
