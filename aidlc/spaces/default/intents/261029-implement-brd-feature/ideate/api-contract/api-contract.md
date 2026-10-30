# API Contract — Workspace and Library gaps (G1–G4)

Status: Ideate / API Contract Design
Intent: `261029-implement-brd-feature`
Consumes: `../architecture-design/architecture-doc.md`, `requirements.md`

## 1. Interfaces in scope

This change touches **no** service-protocol method, no bridge model, and no
database schema. The interfaces are internal Flutter widget contracts.

| Interface | Kind | Changes |
| --- | --- | --- |
| `StudioStatusBar` | Widget constructor | Adds `stageLabel`. |
| `StudioShell` | Widget constructor | Passes `stageLabel` through to the status bar. |
| `WorkspaceStudioScreen` | Composition root | Derives the label from `selectedStage`. |
| `WorkspaceScreen` | Screen | Loading/error branch behavior; delete-selection rule. |
| `MatchRepository` / `MatchCatalog` | Data access | Unchanged. |

## 2. Contracts

### 2.1 `StudioStatusBar`

```dart
StudioStatusBar({
  required int videoCount,
  required int missingCount,
  required MatchListEntry? entry,
  required VideoStageFacts? facts,
  required String stageLabel,   // new
})
```

- `stageLabel` is the short, human label for the selected stage (`Play`,
  `Court`, `Analysis`, `Tracking`, `Score`, `Clips`, `Export`) using the same
  vocabulary as `stage_strip.dart`.
- Rendered after the readiness label in the right-hand cluster.
- Empty string is invalid; the shell always supplies a label, defaulting to
  `Play`.

**Example (rendered line):**

```text
On-device · No cloud   3 videos · 0 missing            Score 18–16    Ready to export · Score
```

**Error example:** not applicable — the widget renders data and has no failure
channel. A null `entry` hides the readiness and score, as today.

### 2.2 Home loading and error states

| State | Contract |
| --- | --- |
| Loading | A progress indicator labeled "Reading workspaces"; no empty-state copy. |
| Error | `The workspaces could not be read. <reason>` plus a Retry action that invalidates `workspaceListProvider` and re-reads. |

```text
The workspaces could not be read. DatabaseException(database is locked)
```

### 2.3 Delete-selection rule

Given the loaded entry list `L`, a deleted match at index `i`:

1. If `L` is now empty → select nothing (empty studio).
2. Else select `L[min(i, L.length - 1)]`.

Idempotent: deleting a non-selected match leaves the selection unchanged.

## 3. Compatibility

- **Not a protocol change.** The service protocol, its major version, and the
  bridge models are untouched.
- The `StudioStatusBar` constructor change is source-breaking for its call
  sites inside this repository; all call sites are updated in the same change.
  No external consumer exists.
- No deprecation policy is needed for internal widgets.

## 4. Explicit non-contracts

- No `library.workspace.update` (rename) — Q-8.
- No `library.recording.relocate` — ADR-0003 D8.
- No v6 catalog or custody method — ADR-0001 Phase 4.
