## 1. Data model

- [x] 1.1 Add a `Workspace` domain model (`id`, `title`, `createdAt`) under `app/lib/src/features/workspace/domain/`
- [x] 1.2 Add `workspace_id` to `MatchRecord` and its `copyWith`
- [x] 1.3 Add the `workspaces` table and a `workspace_id` column migration (version 5) in `match_catalog.dart`, seeding a default workspace and assigning existing matches to it
- [x] 1.4 Extend `MatchCatalog` with workspace queries: insert/list/delete workspace and list matches by workspace

## 2. Repository

- [x] 2.1 Extend the `MatchLibrary` interface with workspace operations (`listWorkspaces`, `createWorkspace`, `listMatches(workspaceId)`, `deleteWorkspace`)
- [x] 2.2 Implement those operations in `MatchRepository` and make `importVideo` record the target workspace

## 3. Routing

- [x] 3.1 Add a workspace home route (`AppRoutes.workspace = '/'`) and set it as `initialRoute`; keep every feature route carrying its `MatchRecord`

## 4. Workspace screen

- [x] 4.1 Add workspace Riverpod providers (workspace list, matches-in-workspace, import controller reuse)
- [x] 4.2 Build `WorkspaceScreen` as the home: workspace list, empty state, create-workspace and import actions
- [x] 4.3 Move import, availability, and delete handling from `LibraryScreen` into the workspace screen (reusing `importControllerProvider`)

## 5. Pipeline toolbar

- [x] 5.1 Add a stage model and a stage-state resolver that derives `done`/`ready`/`blocked` from catalog records and the engine manifest
- [x] 5.2 Add a batched manifest provider keyed by workspace (one bridge read per video per view)
- [x] 5.3 Build the `PipelineToolbar` widget: seven stages in order, done/ready/blocked rendering, next-step highlight
- [x] 5.4 Wire stage taps: ready stages navigate to the existing feature screen; blocked stages show the missing prerequisite

## 6. Wire-up and retire

- [x] 6.1 Retire `LibraryScreen` and point the app shell at `WorkspaceScreen`
- [x] 6.2 Invalidate workspace providers when a stage finishes (import, calibration, generation, tracking, scoring, clips, export)

## 7. Verify

- [x] 7.1 `flutter analyze` clean and the macOS build runs with the workspace home visible
