## Context

Sportcut's home screen is a flat match list. Each row hides six actions behind a
"⋮" popup menu (`Play`, `Review and score`, `Mark the court`, `Prepare analysis
files`, `Player analysis`, `Delete`), and the real pipeline — import, calibrate,
analyze, track, score, highlight, export — is never presented as a sequence. The
engine pipeline is already fully built; this change is app-side only: add a
workspace that groups recordings and a stateful pipeline toolbar that reaches
the existing feature screens in order.

Navigation today is a plain route table (`app/lib/src/app/router.dart`) where
every screen takes a `MatchRecord` as its route argument. Feature screens are
reused unchanged; only the home surface and the way screens are reached change.

## Goals / Non-Goals

**Goals:**

- A named workspace groups multiple imported videos; the workspace screen is
  the home screen.
- Import targets a workspace.
- Each video shows the pipeline as an ordered toolbar with `done` / `ready` /
  `blocked` per stage and the next actionable stage highlighted.
- Reuse every existing feature screen and the existing import flow unchanged.
- Existing installed data survives: every match lands in a workspace.

**Non-Goals:**

- Multi-camera sync, merging, or any engine change.
- Auto-advancing wizard that forces the user through stages.
- Reordering videos within a workspace, drag-and-drop, or workspace templates.
- iOS/Android: macOS remains the only target.

## Decisions

### 1. Data model — `workspaces` table + nullable `workspace_id`

New `workspaces` table (`id`, `title`, `created_at`) and a nullable
`workspace_id` column on `matches`, applied as catalog migration version 5.

**Why nullable:** SQLite `ALTER TABLE ... ADD COLUMN` with `NOT NULL` needs a
`DEFAULT`, which would write a meaningless sentinel value into every existing
row. The migration instead seeds one default workspace and assigns existing
matches to it, so from the app's point of view every match has a workspace.

**Alternatives considered:** a many-to-many `workspace_members` join table would
let one video live in several workspaces — rejected, YAGNI; a video belongs to
one workspace. A separate `workspace_catalog` database — rejected, the schema is
already versioned in one place.

### 2. Workspace is a loose folder, not a locked session

A workspace has a title and a created date. Videos can be added to it at any
time. Import takes a target workspace; the home screen's import action targets
the currently open workspace, and the workspace-empty state offers "New
workspace" the way the current empty library offers import.

**Deleting a workspace** deletes its contained videos using the existing
per-match delete prompts (artifacts / recording copy), then the workspace row.
A workspace is deletable even when non-empty; the prompts already make the
destructive parts explicit.

### 3. The pipeline toolbar and stage state

One toolbar per video, rendered as a horizontally scrollable strip of stage
chips in pipeline order:

```
Import · Mark court · Prepare analysis · Player analysis · Review & score · Highlights · Export
```

Each stage resolves to one of three states:

- `done` — the stage's output already exists for this video.
- `ready` — the stage can be done now; this is the highlighted next step.
- `blocked` — an earlier stage is not done, or the recording copy is gone.

**State source — two kinds of stage:**

| Stage | `done` when | becomes `ready` when |
| --- | --- | --- |
| Import | video exists (always) | — |
| Mark court | catalog `courtCalibration.isComplete` | recording available |
| Prepare analysis | manifest has final `proxy`/`frames`/`analysis_audio` | court marked |
| Player analysis | manifest has final `tracks` | analysis prepared |
| Review & score | catalog has score events for the match | tracks present |
| Highlights | catalog has highlight clips | tracks present |
| Export | manifest has final `export` | at least one selected clip |

User-authored stages (court, score, clips) read the catalog; engine stages
(analysis, tracks, export) read the existing `ArtifactManifestDto` through
`MatchLibrary.manifest`, which already crosses the bridge without generating
anything. Recording availability reuses `isRecordingAvailable`.

The **leftmost `ready` stage is the highlighted "next step"**. `blocked` stages
stay tappable only when safe: a blocked stage whose prerequisite is missing
shows a one-line reason instead of navigating.

### 4. Manifest reads are batched, not per-frame

Reading a manifest is a bridge call per match. The workspace screen loads
manifests once per view into a Riverpod provider keyed by the visible
workspace, and the toolbar renders from that snapshot. It is not re-read on
every rebuild; importing or finishing a stage invalidates the provider.

### 5. Navigation and feature folders

- New route `AppRoutes.workspace = '/'` (replaces `library` as home) plus a
  workspace-scoped route carrying the workspace id; feature screens keep their
  existing `MatchRecord` argument.
- New folder `app/lib/src/features/workspace/` with `domain/`, `data/`, and
  `presentation/` subfolders, following the existing feature layout.
- The flat `LibraryScreen` is retired; its import, delete, and availability
  logic move into the workspace screen (import logic is already behind
  `importControllerProvider` and reuses as-is).

## Risks / Trade-offs

- **[Manifest read cost]** one bridge call per video per workspace view →
  batched once per view in a provider; acceptable at library scale.
- **[Stage-state staleness]** a stage finished outside the toolbar (e.g. via an
  old route) may not refresh → finishing any stage invalidates the workspace
  providers, same pattern the library already uses for calibration.
- **[Precise `done` for engine stages]** artifact kinds and final-vs-partial
  semantics come from the engine manifest; if a kind name shifts, a stage can
  misreport → mapping is centralized in one stage-state resolver so there is a
  single place to adjust.
- **[Migration]** seeding a default workspace and reassigning existing matches
  is a one-time write; a failure mid-migration is rolled back by the existing
  transaction-based migration runner.

## Open Questions

- Whether the toolbar shows all seven stages or collapses "Prepare analysis"
  and "Player analysis" into a single "Analyze" chip. Default: all seven, since
  the app already exposes both actions and the user asked to structure what
  exists.
- Whether a workspace title is auto-derived (e.g. "Session · Thu") or always
  user-entered. Default: user-entered with a sensible default, matching the
  existing match-title behavior.
