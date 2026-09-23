## Context

Phase 1 delivers a user who can build a highlight video from a local recording
with no cloud service. Import is done and verified; the editing half does not
exist. The catalog already carries the three tables the product data model calls
for (`rallies`, `score_events`, `highlight_clips`) and nothing has ever written
to them, so the schema is a partially-specified contract rather than a blank
one.

Two facts about the current engine shape drive most of the decisions below.

1. **The media layer only runs on a workstation.** `sportcut-media` discovers
   `ffmpeg`/`ffprobe` on `PATH` and shells out to them through
   `std::process::Command`. An iOS app cannot spawn an arbitrary executable, the
   sandbox gives it no `PATH` containing one, and the Homebrew build on this
   machine is GPL-3.0 and `not-shippable`. Every stage built on that layer has
   only ever executed on the host, including the import that already ships as
   "done". `app/README.md` says so in passing: the macOS debug runner is
   deliberately unsandboxed because "a sandboxed app cannot run the local
   `ffmpeg`".

2. **The job model cannot be observed from the client.** `facade.rs` creates a
   `JobSession` inside `import_media` and never returns it, and it builds a fresh
   `JobRegistry` per call. Progress and cancellation are implemented in the
   engine and unreachable from Dart; admission control is per-call, so "one heavy
   job at a time" does not actually hold across two calls.

`docs/plans/roadmap.md` records the first fact as two separate standing gates —
"Encoder choice for export" and "Platform scope". They are the same decision,
and the design below answers it once.

## Goals / Non-Goals

**Goals:**

- A user can mark rallies, confirm winners, keep and order clips, and render a
  highlight video with a scoreboard, a title card, and music — entirely offline.
- The edit is described as data (an edit decision list) so the renderer is
  swappable and the editing flow does not depend on which backend renders it.
- The rally/score/clip records are the same shape Phases 2–3 will produce, so
  segmentation and ranking later *fill in* the manual flow rather than replacing
  it.
- Long work — import, regeneration, export — is observable and cancellable from
  the client.
- The engine keeps building, linting, and testing with no mobile toolchain
  installed.

**Non-Goals:**

- No computer vision: no rally detection, no player detection, no winner
  suggestion. The user marks and confirms everything.
- No platform-native render backend. The follow-up change
  `add-platform-export-backend` owns AVFoundation/VideoToolbox and
  MediaCodec/Media3, together with the platform-scope decision it depends on.
- No streaming progress channel. Progress is polled; a `StreamSink`-based
  progress stream is a later refinement (see Decision 6).
- No export history. One current export per match, replaced on re-render.
- No templates or export presets beyond padding, music, and a title.
- No calibration work; `/match/calibration` stays a placeholder.

## Decisions

### 1. The export contract is an edit decision list, not a command line

The engine renders from an explicit edit decision list: an ordered list of clips,
each with a source start and end, lead-in and lead-out padding, and the score to
display; plus the title, the music selection, and the font to draw text with. The
engine never reads the application's SQLite catalog.

*Alternatives considered.* Having the engine read the catalog directly was
rejected: the app owns the catalog and the engine owns artifact files, and
coupling the engine to SQLite would break that split and the engine-only build.
Passing a pre-built `ffmpeg` command line from the client was rejected because it
puts the renderer's implementation in the client and makes the follow-up backend
a rewrite of the client instead of a new backend.

The consequence that matters: the same edit list renders identically under the
development toolchain and under a native backend, which is what makes the
follow-up change contained.

### 2. The first backend is the local toolchain, and that is recorded as a limit

This change renders through `MediaToolchain` and `exec` — the same seam the proxy
stage already uses — so the export runs where the rest of the media layer runs
today: the development workstation. This makes the flow real, reviewable, and
correct before a second backend exists.

*Alternatives considered.* Linking an LGPL FFmpeg build through FFI gives one
implementation for every platform, but it needs a GPL-free build per platform,
enlarges the binary, and still has to delegate H.264 to the platform encoder
because x264 is GPL — so it does not remove the native work, it only moves it.
Going straight to platform-native means writing two backends before anyone has
confirmed the editing flow is usable. Treating the current Homebrew build as
shippable is not available: it is GPL.

This change therefore does **not** satisfy the Phase 1 success criterion on a
phone on its own. It satisfies every part of it that is not the renderer's
backend, and it removes the reason the backend decision has been stuck: once the
edit is data, choosing a backend is a self-contained change.

### 3. A rally is the primitive; a clip is a rally the user kept

With no segmentation, the user is the segmenter. One gesture — mark a span, tap
the winner — produces a rally, the running score, and a clip. `rallies` is the
primitive record; `highlight_clips` is the user's selection over those rallies.

*Alternatives considered.* Making `highlight_clips` the primitive and leaving
`rallies` unused keeps Wave 1 smaller but throws the score timeline away from the
record that owns it, and Phase 2 segmentation would then have to introduce
rallies that do not correspond to the clip the user already made. A single
unified "span" table abandons the product data model in `docs/README.md` §11 and
guarantees a migration later.

A clip may exist without a rally (the user kept a span that was not a scored
point), so `highlight_clips.rally_id` is nullable. The reverse is normal: every
scored rally can exist without being in the reel.

### 4. Catalog schema version 3, additive

- `highlight_clips` gains `rally_id` (nullable, references `rallies(id)`, `ON
  DELETE SET NULL`) and `order_index` (integer, not null, default 0), plus an
  index on `(match_id, order_index)`. The existing `selected` column already
  means "in the reel"; `rank` keeps its existing meaning (how good a suggestion
  was) and is not reused for user order.
- A new `export_settings` table holds one row per match: title, music path, music
  gain, and padding. It holds settings, not results — the rendered file is
  recorded in the manifest instead, as the next point explains.
- No new table for rendered exports. A rendered video is a derived artifact and
  the manifest already records derived artifacts with kind, path, state, and
  size; duplicating that in SQLite would create two sources of truth for the same
  file. The client reads exports through the existing manifest call.
- `rallies` keeps its existing columns: `confidence` stays null for manual
  rallies and `status` distinguishes confirmed from unscored.
- The running score is derived from `score_events` in rally order rather than
  cached in `matches.final_score_left/right`. One aggregate query is cheaper than
  keeping a cache and the history it duplicates in agreement.

### 5. Exported video is an artifact kind with a stable path

`ArtifactKind::Export` joins the manifest enum, writing into a new `export/`
sub-directory; the render lands at a stable relative path
(`export/highlight.mp4`). A re-render writes to a `.part` file and replaces the
previous one, which matches `record_artifact`'s replace-by-kind behavior and
avoids orphaned files.

`ARTIFACT_DIRS` and the manifest's `SCHEMA_VERSION` both change. The schema
version bump is not bookkeeping: serde rejects an unknown enum variant, so an
older engine reading a manifest containing `"kind": "export"` would fail with a
parse error. Bumping the version turns that into the clean "written by a newer
engine" error `ArtifactManifest::load` already produces.

### 6. Job handles: start returns an identifier, the client polls

`start_import`, `regenerate_match_media`, and the new `export_highlight` return a
job identifier immediately. `job_status(job_id)` returns the existing
`JobStatusDto`; `job_cancel(job_id)` requests cancellation; unknown identifiers
are reported explicitly.

Sessions live in a process-global store in `sportcut-api`, bounded to a small
number of recent jobs so a long-lived process does not accumulate them. The
`JobRegistry` becomes process-global for the same reason — otherwise admission
control only ever sees one call at a time.

*Alternatives considered.* A `StreamSink`-based progress stream is the idiomatic
`flutter_rust_bridge` answer and avoids polling, but it adds a streaming contract
to the generated surface and raises a lifetime question (what closes the stream
when the screen is disposed mid-export). Polling the same DTO the blocking call
already returns keeps the contract smaller and the change reversible; the DTOs do
not change if a stream is added later.

Import currently blocks for the whole run. It becomes start-and-poll too, which
is the shape change that makes a multi-minute export tolerable.

### 7. One new engine crate: `sportcut-export`

The edit list, its validation, and the toolchain-backed renderer live in a new
`sportcut-export` crate. `core/AGENTS.md` says crate boundaries mirror pipeline
stages and that new capability goes in the crate that owns the stage; export is a
stage with no crate. `sportcut-highlight` owns ranking, not rendering, and
widening `sportcut-media` would put an unrelated pipeline in the media
foundation.

### 8. Render approach: one pass, one filter graph, overlays as images

A single `ffmpeg` invocation reads the original once, splits the stream, trims
per clip, composites the scoreboard over each clip, and concatenates — rather
than rendering each clip to a temporary segment and joining them. One pass reads
the source once instead of once per clip and needs no temporary files.

*Alternatives considered.* Per-clip segments plus the concat demuxer is more
predictable in memory for a long reel, but it requires identical codec parameters
across segments and multiplies both temp I/O and failure modes. The clip counts a
recreational match produces are small enough that the single-pass approach is the
better default; the edit list does not change if that turns out wrong.

Audio ducking is a fixed gain on the music track rather than sidechain
compression. `docs/README.md` §8 asks for "automatically lower music volume when
original match audio is retained"; a fixed gain satisfies that without a
sidechain filter graph. True ducking is a later refinement.

**The scoreboard and title card are images the application renders, not text the
engine draws.** This was forced by the toolchain and is better anyway: burning
text needs `drawtext`, which needs a freetype-enabled `ffmpeg` build, and the
build on this machine has no `drawtext` filter at all — `tools/preflight.sh` only
checks the licence, not the filter set, so this would have been a runtime
surprise on any machine with a similarly slim build. Compositing an image needs
only `overlay`, which every build has.

It also improves the product: the scoreboard is drawn with the application's own
typography, exactly as the user sees it while reviewing, instead of with whatever
font happened to sit next to the encoder. The engine's edit list therefore
carries one overlay image per clip and one title image, and no font path. A
future native backend that *can* draw text is free to accept the same images
unchanged.

### 9. Screens: the four existing routes become real, calibration stays a placeholder

- `/match/analysis` — the match's artifacts and metadata, regeneration of missing
  artifacts, and live stage progress with a cancel during a job.
- `/match/score` — the rally timeline: mark a span, confirm the winner, see the
  running score.
- `/match/highlights` — clip selection, trim, and order.
- `/match/export` — title, music, padding, render, progress, and the hand-off of
  the finished file.

`/match/calibration` stays a placeholder; calibration belongs to Wave 2.

State follows the existing patterns: a repository interface per feature that the
screens depend on, Riverpod providers for shared state, and the catalog reached
only through the repository, never from a screen.

## Risks / Trade-offs

- **The export only runs on the development workstation after this change** →
  recorded as an explicit non-goal, with `add-platform-export-backend` named as
  the follow-up. The edit list keeps that change to a new backend rather than a
  redesign. Do not let this change be described as "Phase 1 done on device".
- **`add-video-import` is complete but not archived**, so
  `openspec/specs/match-library/spec.md` still describes import by reference while
  the code takes custody. This change's `match-library` delta is written against
  the post-import behavior → archive `add-video-import` before archiving this
  change, and re-read the merged spec if the delta is applied in the other order.
- **Rendering with the GPL Homebrew build** is dev-only and already flagged in
  the register → the export path is a toolchain-consuming stage like the proxy
  stage, and the register row already says `not-shippable`. No new shipping path
  is created.
- **H.264/AAC patent licensing and store distribution** stay unresolved → they
  gate distribution, not this change. The register already carries the row.
- **The overlay is drawn by the client, so an export needs the images it
  references to exist** → validation names the missing overlay or title image
  before the render starts, and the images live with the match's artifacts so
  they survive a re-export. No font is bundled or redistributed: the scoreboard
  uses the platform's own font at runtime, which is not a redistribution.
- **User music may be undecodable** (notably DRM-protected store purchases) →
  the spec requires an explicit failure naming the file rather than a silent
  render without music.
- **Long exports are heavy on a phone** → progress and cancel exist from this
  change; the native backend should prefer hardware encoders and is where
  thermal and battery behavior can actually be measured.
- **The job session store can grow** in a long-lived process → bounded retention
  of recent jobs, with terminal jobs evicted oldest-first.
- **Adding `export/` changes a layout `AGENTS.md` calls stable** → update
  `AGENTS.md` and `core/AGENTS.md` in the same change, and keep the existing
  sub-directories untouched.
- **`MatchRecord`'s doc comment still describes import by reference**, which the
  custody change made false → correct it while the documentation task is open.

## Migration Plan

1. Catalog: migration to schema version 3, additive only — two `ALTER TABLE`
   statements on `highlight_clips`, one new index, one new table. Existing matches
   are untouched; a version-2 install migrates in place on next open. Existing
   `highlight_clips` rows (none in practice) take `order_index` from `rank` when
   present and their start time otherwise.
2. Manifest: `SCHEMA_VERSION` 1 → 2 alongside the new artifact kind. Newer
   manifests are refused by older engines with the existing explicit error, which
   is the intended behavior.
3. Bridge: regenerate after any facade or DTO change with
   `tools/generate-bridge.sh`, keeping `flutter_rust_bridge` at 2.13.0 across the
   Rust crate, `app/pubspec.yaml`, and the script.
4. Rollback: the migration is additive, so a build from before this change
   continues to read a migrated catalog — it simply ignores the new columns and
   table. Reverting the engine is safe as long as no manifest with an export
   artifact is present, which the version guard enforces.
5. Verification: `tools/verify-engine.sh`, `flutter analyze`, and `flutter test`
   in `app/`, with the evidence recorded under `docs/verification/`.

## Open Questions

- **Platform scope (iOS only, or both).** Still undecided, and it determines the
  shape of `add-platform-export-backend`. It does not block this change because
  the edit list is backend-neutral.
- **Default audio behavior.** Match audio with optional music is the assumed
  default; whether "music only" should be a first-class choice is a product call.
- **Where the finished video should go.** This change renders into the match
  directory and hands the file to the platform's save/share affordance. Making
  Photos the primary destination instead would add platform permissions and is
  worth deciding before the native backend lands.
- **Reel length.** No cap is proposed for Wave 1; a very long reel is a rendering
  cost, not a correctness problem.
