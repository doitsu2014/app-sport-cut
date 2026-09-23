## Why

Phase 1's success criterion — a user can build a highlight video from a local
recording, entirely offline — is not met. Import shipped and is verified, but the
editing half of the phase does not exist: there is no way to mark a rally, record
who won it, keep a clip, add music, or render a video. Five of the six Phase 1
deliverables in `docs/README.md` §10 are unstarted, and the three catalog tables
the bootstrap created for this work (`rallies`, `score_events`,
`highlight_clips`) have never been written to.

There is also a structural gap the roadmap does not name. The engine's media
layer discovers `ffmpeg`/`ffprobe` on `PATH` and shells out to them, so it only
runs on a workstation: an iOS app cannot spawn an arbitrary executable, and a GPL
FFmpeg build cannot ship to either mobile platform. Every stage built on that
layer — including the import that is already "done" — has only ever run on the
host. `docs/plans/roadmap.md` lists "Encoder choice for export" and "Platform
scope" as two separate standing gates; they are the same decision, and this
change settles it in a recorded design decision instead of leaving it implicit.

## What Changes

- **Review becomes an editing session.** While a recording plays, the user marks
  a span, taps who won it, and moves on. One gesture produces the rally boundary,
  the running score, and the highlight clip, because with no computer vision the
  user *is* the segmenter. Kept clips can be trimmed, reordered, and removed.
- **A rally is the primitive; a clip is a rally the user kept.** This is the
  shape Phases 2–3 hand over (segmentation proposes rallies, ranking proposes
  clips, the user confirms), so the manual flow and the future automatic flow
  converge on the same records instead of needing a second model.
- **The catalog records the edit.** `rallies`, `score_events`, and
  `highlight_clips` start being written, `highlight_clips` gains the link to the
  rally it came from and an explicit order, and export settings (music, title
  card, team names) get a home. Schema version 3, migrated forward in place.
- **Export is an edit decision list, not a command line.** The client and catalog
  produce an ordered, timestamped edit description; a new engine stage renders it
  to a highlight video with short lead-in/lead-out padding, concatenation, a
  burned-in scoreboard, a title card, and user-supplied music ducked under the
  match audio. The renderer is a swappable backend behind that contract.
- **The first export backend is the local toolchain.** It runs where the rest of
  the media layer runs today (the development workstation), which is enough to
  make the flow real, reviewable, and correct. A platform-native backend
  (AVFoundation/VideoToolbox, MediaCodec/Media3) is the follow-up change; the
  design records why the edit list must not depend on which backend renders it.
- **Long work becomes observable.** Starting an import, regeneration, or export
  returns a job handle; the client can read stage-labelled progress, cancel, and
  see the terminal state. Today `import_media` is one blocking call that keeps
  its `JobSession` private, so progress and cancellation are unreachable from the
  client even though the engine implements both.
- **The placeholder screens become real.** Analysis shows a match's artifacts,
  can regenerate missing ones, and shows progress and cancel while it does. The
  score and highlight routes become the editing session and the export settings.

No **BREAKING** changes: there is no public release, the catalog migrates forward
in place, and every existing requirement keeps its behavior.

## Capabilities

### New Capabilities

- `match-editing`: marking rallies on a recording, confirming the winner,
  maintaining the running score, and choosing, trimming, and ordering the clips
  that make up the highlight reel.
- `highlight-export`: turning the chosen clips into a rendered video — the edit
  decision list, the render pipeline, the score overlay, the title card, the
  music mix, and where the finished file goes.

### Modified Capabilities

- `match-library`: the catalog owns rally, score event, clip, and export setting
  records with versioned migrations, a clip records its order and the rally it
  came from, and deleting a match covers the records it now owns. (The library's
  entry point into an editing session is specified under `match-editing`, since
  it is new behavior rather than a change to browsing.)
- `media-pipeline`: the per-match artifact layout gains exported video artifacts,
  which are derived, regenerable, and recorded in the manifest like every other
  artifact.
- `processing-jobs`: a job's identity, progress, and cancellation become
  reachable by the client that started it, rather than being created and dropped
  inside a single blocking call.

## Impact

- **Engine**: a new `sportcut-export` crate for the edit list and the renderer
  (the export stage has no home in the existing crate boundaries); a job-handle
  registry in `sportcut-api` so sessions outlive the call that started them; new
  DTOs for the edit list, job handles, and export results; a new
  `ArtifactKind::Export` in `sportcut-storage`. Nothing in hand-written Rust gains
  `unsafe`, and the engine still builds with no mobile toolchain present.
- **Bridge**: new facade functions and DTOs, so the pinned
  `flutter_rust_bridge` version, `core/crates/api/Cargo.toml`, `app/pubspec.yaml`,
  and `tools/generate-bridge.sh` stay in step; generated bindings remain
  uncommitted.
- **Client**: a review/editing session over the existing playback controller, a
  score timeline, a clip list, the export settings screen, a real analysis
  screen, and the catalog migration to schema version 3.
- **Catalog and storage**: `highlight_clips` gains a rally link and an order;
  export settings gain persistence; exported videos are derived artifacts under
  the match directory and are removed with the match's artifacts when the user
  asks for that.
- **Legal register**: the export encoder, any font used for the overlay and title
  card, and any package added for picking audio or handing the finished file to
  the platform all need a row before this change is complete. The H.264/AAC
  patent question stays open and is the reason the shipping backend is a separate
  change.
- **Documentation**: `docs/plans/roadmap.md` (Wave 1 status, the merged
  encoder/platform gate), `core/AGENTS.md` (the new crate and the artifact
  layout), and a verification record under `docs/verification/`.
