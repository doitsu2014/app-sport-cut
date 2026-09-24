## 1. Triage the scenarios before writing anything

- [x] 1.1 Walk every scenario in `openspec/specs/match-editing/spec.md`,
      `openspec/specs/highlight-export/spec.md`, the client-observable and
      cancellation scenarios in `openspec/specs/processing-jobs/spec.md`, the
      artifact-layout scenarios in `openspec/specs/media-pipeline/spec.md`, the
      calibration scenarios in
      `openspec/changes/add-court-calibration/specs/court-calibration/spec.md`,
      and the calibration rows in `openspec/specs/match-library/spec.md`, and
      assign each to one bucket from design D1
- [x] 1.2 Note for each scenario what it can assert, so a property check is not
      written where the scenario only asks for a state change
- [x] 1.3 Identify the manual-only set and the reason for each row: device-only
      interaction, a missing capability, or a missing second backend (design D7)
- [x] 1.4 Confirm nothing in the triage requires a production change; if
      something does, stop and update this change's artifacts before writing the
      test

## 2. Engine: the edit list's rules

- [x] 2.1 Add a unit-test module to `core/crates/export/src/edit_list.rs` and
      exercise `EditList::validate` for: an empty reel, a clip ending before it
      starts, a non-finite boundary, a clip starting before the recording, a clip
      ending past the recording's duration plus the tolerance, and negative
      padding — asserting that each error names what was wrong
- [x] 2.2 Cover the music-gain range and a title card with a non-positive
      duration
- [x] 2.3 Cover an unreadable overlay, title image, and music file: each is
      rejected before rendering, naming the file (`Missing overlay reported`,
      `Unreadable music reported`)
- [x] 2.4 Cover `padded_span` clamping at the recording's start and end
      (`Padding applied`)
- [x] 2.5 Cover the boundary tolerance: a clip that reaches the reported
      duration is accepted (`Clip outside the recording rejected`, other half)

## 3. Engine: court geometry, homography, net, and sides

- [x] 3.1 Add a unit-test module to `core/crates/court/src/homography.rs` and
      assert that the unit square maps to itself, so the first corner is the
      court origin, and that projection round-trips within tolerance
      (`Mapping produced for a valid calibration`, `Mapping round-trips`)
- [x] 3.2 Assert the invariant a wrong homography breaks: for a trapezoid whose
      near edge is wider, the court centre projects to where that
      quadrilateral's diagonals cross
- [x] 3.3 Cover the rejection of a duplicated corner, three collinear corners, a
      corner outside the frame, a bow-tie ordering, and a quadrilateral enclosing
      almost no area — each with an explicit message naming the problem
      (`Degenerate calibration rejected`, `Positions outside the frame rejected`)
- [x] 3.4 Cover the net's placement: the midpoint of the court's long axis, on
      `u` when the court runs across the view and on `v` when it runs away
      (`Court orientation recorded`)
- [x] 3.5 Cover side assignment following the net rather than the image, and that
      an uncalibrated match reports no side (`Position assigned to a side`,
      `No calibration invented`)
- [x] 3.6 Cover projecting the outline and the net back into image coordinates,
      and the outline moving when a corner is edited (`Outline available for
      verification`, `Outline follows an edited corner`)

## 4. Engine: job handles and the facade

- [x] 4.1 Extend `core/crates/api/tests/facade.rs` to cover an unknown job handle:
      the error names the identifier (`Unknown handle reported`)
- [x] 4.2 Cover cancellation requested from the client: a started job cancelled
      through `job_cancel` reaches a cancelled terminal state, and its partial
      artifacts are not final (`Cancellation requested from the client`,
      `Cancellation stops work`, `Partial output not presented as final`)
- [x] 4.3 Re-assert that the admission refusal names the resource-intensive job
      already running, for a second match as well as a second import
      (`Conflicting request not run concurrently`)
- [x] 4.4 Cover the calibration facade calls against a real match directory:
      save writes `calibration/calibration.json` and records it in the manifest as
      final; the read returns the stored calibration and its projected outline;
      an uncalibrated match reports none (`Engine writes the calibration into the
      match directory`, `Calibration survives a restart`)
- [x] 4.5 Cover calibration invalidation: saving a changed court invalidates
      `tracks` and marks the calibration not rebuildable; re-saving an unchanged
      court invalidates nothing (`Artifacts from the previous court invalidated`,
      `Unchanged calibration discards nothing`,
      `Missing calibration reported as needing the user`)
- [x] 4.6 Cover the regeneration partition: a match missing only derived
      artifacts reports them rebuilt, and the outcome distinguishes an artifact
      the engine cannot rebuild (`Rebuild completes the artifacts it can
      reproduce`)

## 5. Engine: rendering, against generated fixtures

- [x] 5.1 Add `core/crates/export/tests/render.rs` with a small local fixture
      helper that generates a video, an overlay image, a title image, and a music
      track into a temporary directory with the local `ffmpeg`, and skips with a
      diagnostic when the toolchain is missing (design D3, D4)
- [x] 5.2 Assert a render writes one playable file containing every clip in the
      requested order, each beginning and ending at its trimmed boundaries, and
      that the total duration is the title plus the padded clips
      (`Reel rendered`, `Padding applied`)
- [x] 5.3 Assert the source recording is byte-for-byte unchanged after a render
      (`Original recording unmodified`)
- [x] 5.4 Assert a recording with no audio track renders rather than failing, and
      that one with audio carries it (`Source without audio`, `Match audio
      preserved`)
- [x] 5.5 Assert the overlay is composited into the encoded frames by sampling a
      region of the rendered frames and comparing it with the same frame of the
      source, within tolerance — reproducing the manual check rather than
      comparing against a golden file (design D4)
- [x] 5.6 Assert the title card is prepended and shows the application's image
      (`Title card prepended`)
- [x] 5.7 Assert music shorter than the reel is padded and faded to the reel's
      length, and that with no music the render carries match audio only
      (`Music shorter than the reel`, `No music selected`)
- [x] 5.8 Assert a cancelled export leaves no partial file where the reel would be
      written, and leaves a previously rendered reel's file untouched
      (`Cancelled export`)

## 6. Client: the editing domain and its storage

- [x] 6.1 Add `app/test/score_timeline_test.dart` covering the derivation: the
      score advances one point per confirmed rally in rally order; an unscored
      rally contributes nothing; correcting or clearing an earlier winner
      rewrites every later event and the final score; the same rallies re-derived
      produce the same events; and `atSeconds` returns the score as it stood at a
      clip's position (`Score advances with confirmed winners`, `Correction
      rewrites the later score`, `Rally left unscored`, `Score is
      reproducible`, `Score does not change mid-clip`)
- [x] 6.2 Add `app/test/editing_repository_test.dart` over a real SQLite database
      in a temporary directory, covering: a rally whose end is not after its
      start is rejected and nothing is written; a boundary adjustment changes
      only that rally; a kept rally becomes a clip that records its rally and its
      boundaries; trimming moves the clip and not the rally; removing a clip from
      the reel leaves the rally and its score alone; reordering survives a
      reload; and a deleted rally leaves its clip detached rather than removed
      (`Rally marked from playback`, `Boundary adjusted`, `Marking rejected`,
      `Rally kept as a clip`, `Clip trimmed`, `Rally left out`, `Clips
      reordered`, `Clip order is the user's`)
- [x] 6.3 Cover the session round-trip: what a session writes is what the next
      `load` returns, and a match with no review returns no rallies, no clips,
      and an empty score (`Editing session left and resumed`, `No rally is
      invented`, `Winner never inferred`)
- [x] 6.4 Cover export settings persisted and read back (`Export settings
      persisted`, `Music chosen from device storage`)
- [x] 6.5 Extend `app/test/match_catalog_test.dart` — or the repository test where
      it fits better — to cover a match's calibration round-tripping through the
      catalog, a null column decoding to no calibration, and the calibration going
      with the match when it is deleted (`Court calibration owned by the
      catalog`, `Existing matches load without a calibration`, `Match deletion`)

## 7. Client: the calibration screen's controller

- [x] 7.1 Cover `nudgeCorner` clamping: a handle dragged past the frame's edge
      stops at it, and the other corners do not move (`Positions outside the frame
      rejected`)
- [x] 7.2 Cover `isComplete` and projection: fewer than four corners means no
      projection is requested, four corners in frame means the engine is asked
      for one (`Incomplete calibration not saved`)
- [x] 7.3 Cover the engine's rejection reaching the screen: a degenerate
      quadrilateral produces the engine's message and no projected court
      (`Degenerate calibration rejected`, from the screen's side)
- [x] 7.4 Cover opening a stored calibration: the stored corners and orientation
      are loaded and re-projected, and `save` is refused while the calibration is
      incomplete (`Calibration survives a restart`,
      `Incomplete calibration not saved`)
- [x] 7.5 Cover orientation changes re-projecting, and the saved calibration
      carrying the corners and orientation the user set (`Court orientation
      recorded`)

## 8. Client: the screens

- [x] 8.1 Add `app/test/support/fake_match_editing.dart`: an in-memory
      `MatchEditing` that derives its score with the real `ScoreTimeline` and
      records what each call was given (design D5)
- [x] 8.2 Add `app/test/score_screen_test.dart` covering: a marked span becomes a
      rally on the timeline; a rally with an end before its start is refused with
      the reason shown; one tap on a side records that side as the winner and
      advances the score; correcting the winner changes the score; and the screen
      shows no score for a rally with no confirmed winner (`Rally marked from
      playback`, `Marking rejected`, `Winner confirmed with one tap`, `Winner
      corrected`, `Rally left unscored`)
- [x] 8.3 Add `app/test/highlights_screen_test.dart` covering keep/remove,
      trimming, and reordering reaching the editing interface in the order the
      user set (`Rally kept as a clip`, `Rally left out`, `Clip trimmed`, `Clips
      reordered`)
- [x] 8.4 Add `app/test/export_screen_test.dart` covering: rendering is refused
      with no clips; the overlay and title images come from the renderer and the
      overlay omits team names the user never supplied; a running export reports
      its stage and progress and can be cancelled; a finished export offers the
      user the file; and a failure is reported rather than silently retried
      (`Empty reel rejected`, `Overlay wording is user-supplied`, `Cancelled
      export`, `Finished video handed to the user`)
- [x] 8.5 Add `app/test/calibration_screen_test.dart` covering: the four handles
      are present and labelled in a fixed order; dragging one moves it in
      normalized coordinates inside the video box; the projected outline and net
      are drawn once the corners are complete; saving is refused while the
      calibration is incomplete; and an edited calibration re-projects without
      touching another corner (`Four corners captured`, `Marked position
      independent of the preview layout`, `Outline available for
      verification`)
- [x] 8.6 Cover the analysis screen's stage, progress, and cancel controls, which
      wave 1 added and nothing exercises (`Progress read while running`,
      `Cancellation requested from the client`, from the screen's side)

## 9. Bridge: the calls that never crossed the binding

- [x] 9.1 Extend `app/test/bridge_test.dart` to save a calibration through
      `saveCalibration` for an imported fixture match, then read it back through
      `matchCalibration`, asserting the corners and orientation survived the
      boundary
- [x] 9.2 Ask for the projection through `courtGeometry` and assert an outline
      and a net come back, and that the manifest reports the calibration as
      recorded
- [x] 9.3 Start an import and cancel it through `jobCancel`, asserting the
      terminal state the client sees, and starting a second import afterwards to
      show the admission slot was released (`Cancellation requested from the
      client`, `Unknown handle reported` through the binding)
- [x] 9.4 Confirm the file still loads the real engine library and documents the
      `tools/generate-bridge.sh` / `tools/build-engine-lib.sh` precondition

## 10. Verification records and the roadmap

- [x] 10.1 Rewrite the scenario-to-evidence tables in
      `docs/verification/manual-editing-and-export.md` so each row names the test
      that covers it, and replace the "no automated coverage" prose with what
      actually covers the review screens
- [x] 10.2 Rewrite the tables in `docs/verification/court-calibration.md` the
      same way, and remove the harness's output as the evidence for scenarios the
      engine tests now hold
- [x] 10.3 Record the manual-only rows in both records with their reason: the
      share sheet, the device launch, a real recording's accuracy, drag
      ergonomics, a second render backend, and a player position from a tracker
      that does not exist
- [x] 10.4 Add the coverage step to the roadmap's "working rule for each wave",
      and update the roadmap's Verification paragraph with the new suite sizes
- [x] 10.5 Update the test-count and coverage tables in
      `docs/verification/client-track.md`

## 11. Verification

- [x] 11.1 Run `tools/verify-engine.sh` and confirm formatting, lint (which
      includes the new test code under `--all-targets`), and every test pass
- [x] 11.2 Run `cd app && flutter analyze` and confirm it is clean
- [x] 11.3 Run `cd app && flutter test` after `tools/generate-bridge.sh` and
      `tools/build-engine-lib.sh`, and confirm every test passes
- [x] 11.4 Confirm no generated file was hand-edited or committed, no dependency
      was added (`git diff core/Cargo.lock` is empty), and
      `docs/legal/dependency-register.md` needs no new row
- [x] 11.5 Record the run and the engine suite's before/after timing under
      `docs/verification/`, and mark this change's tasks complete as they land
