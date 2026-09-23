## 1. Observable job handles across the bridge

- [x] 1.1 Make the job registry process-global in `sportcut-api` so admission control spans calls, not just one call, and confirm a second heavy job is rejected while one runs
- [x] 1.2 Add a bounded job-handle store in `sportcut-api` holding each running `JobSession` behind an `Arc`, evicting the oldest terminal jobs once a small cap is reached
- [x] 1.3 Convert `import_media` into a start call that returns a job handle immediately and runs the work on the engine's worker thread
- [x] 1.4 Convert `regenerate_match_media` to the same start-and-return-handle shape
- [x] 1.5 Add `job_status(job_id)` and `job_cancel(job_id)` facade functions, reporting an unknown handle explicitly instead of inventing a status
- [x] 1.6 Add the `JobHandleDto` and any new request DTOs to `core/crates/api/src/dto.rs`, keeping the existing `JobStatusDto` as the polled shape
- [x] 1.7 Retire the client's use of `MediaImportResultDto`: after a job reaches a terminal state the client refreshes from the match manifest and the catalog instead of reading a one-shot result
- [x] 1.8 Regenerate the bindings with `tools/generate-bridge.sh` and extend `SportcutEngine`/`MediaEngine` with `startImport`, `startRegenerate`, `jobStatus`, and `jobCancel`

## 2. Catalog schema version 3

- [x] 2.1 Add migration 3 to `MatchCatalog`: `highlight_clips.rally_id` (nullable, `REFERENCES rallies(id) ON DELETE SET NULL`) and `highlight_clips.order_index` (integer, not null, default 0)
- [x] 2.2 Add the `(match_id, order_index)` index on `highlight_clips`, keeping the existing `(match_id, rank)` index and `rank`'s meaning as suggestion quality
- [x] 2.3 Backfill existing `highlight_clips` rows: `order_index` from `rank` where present, otherwise from `start_seconds`
- [x] 2.4 Add the `export_settings` table (one row per match: title, music path, music gain, padding) with a foreign key to `matches` and cascade on delete
- [x] 2.5 Extend the catalog's deletion transaction to remove `export_settings` rows with the match
- [x] 2.6 Add row mapping and read/write accessors for rallies, score events, clips, and export settings
- [x] 2.7 Confirm a version-2 install migrates in place and keeps every match, rally, score event, and clip it already had

## 3. Engine: edit decision list and export artifact

- [x] 3.1 Create the `sportcut-export` crate, add it to `core/Cargo.toml`'s workspace members and dependencies, and add its row to the crate table in `core/AGENTS.md`
- [x] 3.2 Define the edit decision list types: ordered clips with source start and end, lead-in and lead-out padding, the overlay image to composite over each clip, plus the title, music, and gain settings
- [x] 3.3 Validate an edit list before rendering: at least one clip, each clip's range inside the source duration, non-inverted trims, and readable overlay, title, and music files when they are named
- [x] 3.4 Add `ArtifactKind::Export` with its `export/` directory and `export` stage label, and add `export` to `ARTIFACT_DIRS`
- [x] 3.5 Bump `ArtifactManifest::SCHEMA_VERSION` to 2 so an older engine reports a newer-engine manifest instead of failing to parse an unknown artifact kind
- [x] 3.6 Implement the renderer as a single `ffmpeg` pass over one input: split, trim per clip, pad, concatenate in the requested order
- [x] 3.7 Composite each clip's overlay image over it for its whole duration, so the scoreboard is part of the encoded video
- [x] 3.8 Prepend the title card image when one is requested, holding the match audio back so it stays in step with the picture
- [x] 3.9 Mix user music under the match audio at a fixed gain, extending or fading music shorter than the reel, and render match-audio-only when no music is selected
- [x] 3.10 Write the render to a `.part` file, replace `export/highlight.mp4` only on success, and record the artifact in the manifest with its size
- [x] 3.11 Report per-stage progress and honour cancellation while rendering, marking partial output non-final rather than recording an export
- [x] 3.12 Add the `export_highlight` facade function returning a job handle, with the edit list and destination passed in from the client
- [x] 3.13 Keep the export path free of network access and confirm the crate builds without any mobile toolchain

## 4. Client: rally timeline and score

- [x] 4.1 Add the editing domain models (rally, score event, highlight clip, export settings) with the product data model's field meanings
- [x] 4.2 Define the editing repository interface the screens depend on, following the interface-per-feature pattern the library already uses
- [x] 4.3 Implement the repository over the catalog, including the score derivation that reads confirmed winners in rally order
- [x] 4.4 Add an editing controller exposing the loaded rally list, the running score, and the score at any position, with the records recomputed when a winner changes
- [x] 4.5 Make the score screen the rally timeline: scrub playback, set start and end, and reject a span whose end is not after its start
- [x] 4.6 Add one-tap winner confirmation per rally, with a correction path, and show the running score as rallies are confirmed
- [x] 4.7 Mark a rally unscored when no winner is confirmed, and keep it out of the score
- [x] 4.8 Recompute the recorded score events after the changed rally when a winner is corrected or cleared
- [x] 4.9 Add the entry point from the library into the editing session, and show the score reached by confirmed rallies on the match in the library list
- [x] 4.10 Reload a match's rallies, score events, and clips when an editing session opens, so edits survive leaving the session

## 5. Client: clip selection and order

- [x] 5.1 Let the user keep or remove a rally as a highlight clip, recording the clip with the rally it came from
- [x] 5.2 Let the user trim a kept clip's start and end within its rally without changing the rally's own boundaries
- [x] 5.3 Let the user reorder clips and persist the order, keeping `rank` untouched
- [x] 5.4 Show the current reel in order on the highlights screen with each clip's duration and the score it will display

## 6. Client: export settings, render, and hand-off

- [x] 6.1 Build the edit decision list from the match's selected clips, the score at each clip's position, and the match's export settings
- [x] 6.2 Make the export screen edit the title, padding, and music selection, persisting them through the export settings repository
- [x] 6.3 Add audio picking from device storage, storing only the path, and report an unreadable or undecodable file explicitly rather than rendering without it
- [x] 6.4 Render the scoreboard and title card as transparent images at the recording's pixel size, with the app's own typography, and pass their paths in the edit decision list
- [x] 6.5 Start the render from the export screen and show stage-labelled progress with a working cancel
- [x] 6.6 On completion, read the export artifact from the manifest and let the user play the finished reel in the app
- [x] 6.7 Add the save/share hand-off for the finished file, including any dependency, register row, and platform purpose string it needs
- [x] 6.8 Report an explicit failure to the user when a render fails, and leave the previous export untouched

## 7. Analysis screen

- [x] 7.1 Show the match's original media metadata and every recorded artifact with its relative path, state, and size
- [x] 7.2 Offer regeneration of artifacts the manifest reports as missing
- [x] 7.3 Drive regeneration from the job handle: show the current stage and progress, allow cancel, and show the terminal state including a failure reason
- [x] 7.4 Show a cancelled or interrupted artifact as non-final rather than as a result

## 8. Documentation, licensing, and verification

- [x] 8.1 Update `docs/plans/roadmap.md`: Wave 1 status, and merge the "Encoder choice for export" and "Platform scope" gates into the single decision they are, naming `add-platform-export-backend` as the follow-up
- [x] 8.2 Update the storage contract in `AGENTS.md` and `core/AGENTS.md` to include the `export/` sub-directory and the new `sportcut-export` crate
- [x] 8.3 Correct the stale `MatchRecord` doc comment that still describes the recording as referenced in place
- [x] 8.4 Add a dependency-register row for the bundled font with a distribution verdict and the artifact it ships in
- [x] 8.5 Add register rows for any package added for audio picking or the save/share hand-off, and confirm the export encoder's existing entries still describe what is used
- [x] 8.6 Confirm no GPL component entered a shipping path, and that the render backend is recorded as development-only
- [x] 8.7 Run `cargo fmt --all` and `cargo clippy --workspace --all-targets -- -D warnings` in `core/`
- [x] 8.8 Run `flutter analyze` in `app/` and confirm it is clean
- [x] 8.9 Run the change verification workflow (`tools/verify-engine.sh` and `flutter test`) and record the evidence, including a rendered reel from a fixture recording, under `docs/verification/`
- [x] 8.10 Map every scenario in the change's spec deltas to the evidence that covers it, and record the platform-scope and export-backend limits explicitly in the verification record
