# Source Changes — Import and Media Preparation (Feature 2)

Status: Develop / Code Generation
Intent: `261030-implement-02-import`
Branch: `261030-implement-02-import` (off `main` @ `d33d123`)

## Commits

| Unit | Commit | Subject | Requirement ids |
| --- | --- | --- | --- |
| U0 | `e756052` | fix(bridge): drop tcpNoDelay on the AF_UNIX service socket | none (macOS connection bug) |
| U1 | `4cb33db` | feat(library): report byte-copy progress from the custody copy | FR-IMP-15, NFR-2 (partial); preserves FR-IMP-08/09/11 |
| U2 | `c603d3c` | feat(workspace): show determinate import progress in both surfaces | FR-IMP-14, FR-IMP-15, NFR-2 (partial) |
| U3 | `7ca126a` | feat(analysis): count only rebuildable missing files and guide the rest | FR-IMP-28, FR-IMP-29, DS-10 |
| U4 | `62a57c3` | feat(analysis): label artifact rows READY / PARTIAL / MISSING | FR-IMP-30, DS-6 |
| U5 | `4343663` | docs(brd): reconcile Feature 2 status with the landed implementation | G4 |

## Files changed per unit

- **U0**: `app/lib/src/bridge/protocol_client.dart` — removed the TCP-only
  `setOption(tcpNoDelay)` call (macOS rejects it with EOPNOTSUPP on AF_UNIX,
  failing every service connection) and the now-unused `SocketOption` show.
- **U1**: `app/lib/src/features/library/data/recording_store.dart`
  (`takeCustody` + `_copy` gain `expectedBytes`/`onProgress`; percent-gated
  emission; `on Object` cleanup), `domain/match_library.dart` (interface
  parameter), `data/match_repository.dart` (threads `onProgress`, passes
  `expectedBytes: metadata.sizeBytes`), `app/test/support/fake_match_library.dart`
  (parameter adopted, ignored).
- **U2**: `presentation/import_controller.dart` (`ImportState.fraction`,
  guarded `onProgress` → state updates), `workspace/presentation/workspace_screen.dart`
  (`fraction: import.fraction`), `workspace/presentation/workspace_studio_screen.dart`
  (`importFraction: import.fraction`). No design-system changes.
- **U3**: `analysis/presentation/analysis_providers.dart`
  (`rebuildableMissing`/`notRebuildableMissing` getters),
  `analysis/presentation/analysis_panel.dart` (Rebuild button source switch;
  guidance note; static kind→(display, stage) map with unknown-kind fallback).
- **U4**: `analysis/presentation/artifact_rows.dart` (local `_ArtifactBadge`
  READY/PARTIAL/MISSING; `_status`→`ScStatus` delegation and unused imports
  removed; `ScStatus`/`ScPipelineRow` untouched).
- **U5**: `docs/brd/02-import-and-media-preparation.md`,
  `docs/brd/00-product-context.md` (status/evidence only; Must rows untouched).

## Execution model

Multi-agent per the approved plan: Lane A (U1→U2 chained agents), Lane B
(U3), Lane C (U4) ran concurrently in the shared tree on file-disjoint
units; U0 was committed before the lanes; U5 ran as a single agent after the
code landed. All diffs were read and verified by the conductor before
committing.
