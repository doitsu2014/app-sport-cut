## 1. Settle the frame-orientation assumption before building on it

- [x] 1.1 Generate a rotation-tagged fixture with ffmpeg and confirm the proxy, and the frames sampled from it, are upright while the original keeps its rotation tag
- [x] 1.2 Confirm the playback surface shows the rotated frame, so normalized displayed coordinates are the space the user's taps and the sampled frames share
- [x] 1.3 If either check fails, stop and revise the design's canonical coordinate space before implementing the homography

## 2. Court geometry in `sportcut-court`

- [x] 2.1 Replace the placeholder doc comment in `core/crates/court/src/lib.rs` with the calibration record: four normalized corners, the court orientation (away from the camera, or across the view), and the segment start time
- [x] 2.2 Implement validation that rejects a calibration that cannot define a quadrilateral — duplicate, collinear, or out-of-range corners — with an explicit error naming the problem
- [x] 2.3 Implement the homography from normalized image coordinates to the court's unit square, including its inverse, and expose the mapping as two 3×3 matrices
- [x] 2.4 Place the net on the court plane from the recorded orientation: the midpoint of the court's long axis, which is the axis away from the camera when the nearest edge is a baseline and across the view when it is a sideline
- [x] 2.5 Implement side assignment as which half of the net a normalized court position falls in, and keep it independent of where the camera was standing
- [x] 2.6 Implement projection of the court outline and the net back into image coordinates for display
- [x] 2.7 Keep the crate free of any native or platform dependency so the engine workspace still builds and tests with only Rust and ffmpeg

## 3. Calibration artifacts and honest regeneration in the engine

- [x] 3.1 Define the `calibration/calibration.json` record with a schema version and a list of segments, each carrying a start time, the corners, and the orientation; write exactly one segment covering the recording
- [x] 3.2 Add the engine-side save that writes the record, records `ArtifactKind::Calibration` in the manifest with a final state, and returns the two matrices
- [x] 3.3 Add the engine-side read that returns the stored calibration and its projected outline, and reports explicitly when a match has none
- [x] 3.4 Narrow `regenerate_missing` to report only the artifact kinds it can actually recompute, and report a missing calibration as an artifact the engine cannot rebuild rather than as restored
- [x] 3.5 Make the calibration artifact invalidate `ArtifactKind::Tracks` when a saved calibration differs from the one it replaces, and invalidate nothing when the value is unchanged
- [x] 3.6 Confirm the engine never derives a calibration, a court, a net, or a side for a match that has none

## 4. Bridge surface

- [x] 4.1 Add DTOs for the calibration record, the four normalized corners, the court orientation, the save request, and the read result including the two matrices and the projected outline
- [x] 4.2 Expose the save and read calls on `sportcut-api`'s facade and extend the regeneration result so a caller can tell a rebuilt artifact from one that could not be rebuilt
- [x] 4.3 Re-run `tools/generate-bridge.sh` and confirm no generated file is hand-edited or committed
- [x] 4.4 Add the typed Dart wrappers next to — not inside — `app/lib/src/bridge/generated/`, and confirm feature code imports only `app/lib/src/bridge/sportcut_engine.dart`

## 5. Calibration in the catalog

- [x] 5.1 Add the calibration to `MatchRecord` including `copyWith`, and map it in both directions against the existing `court_calibration` column
- [x] 5.2 Confirm an install that predates this change loads every match with no calibration and no other field altered, and that no new migration is required because the column already exists
- [x] 5.3 Add the store method that saves a match's calibration as part of the match, writing the catalog last so a failed artifact write leaves the previous calibration intact
- [x] 5.4 Confirm deleting a match removes its calibration with the rest of its records

## 6. The calibration screen

- [x] 6.1 Replace the placeholder screen with a scrubber over the recording so the user can choose a moment where the court is clearly visible
- [x] 6.2 Render the video surface and the corner overlay in the same box at the same aspect ratio, so a tap divided by the box size is the normalized coordinate
- [x] 6.3 Implement four draggable corner handles in a fixed, labelled screen order, with the first corner and the direction of travel stated in the interface
- [x] 6.4 Ask which way the court runs in the user's terms — away from the camera, or across the view — and default to the case the product plan names first
- [x] 6.5 Draw the projected court outline and net over the recording once the corners are complete, so the user checks the calibration against the painted lines instead of trusting four taps
- [x] 6.6 Reject an incomplete or out-of-frame calibration in the interface, and report the engine's error when the corners cannot define a quadrilateral
- [x] 6.7 Reopen a stored calibration for editing, and make the distance from the library to calibration reachable from a match

## 7. Documentation

- [x] 7.1 Update `docs/plans/roadmap.md` to record court calibration as implemented and to state what the wave still waits on
- [x] 7.2 Record the end-on-camera consequence: for a recording shot from behind a baseline, the two sides read as near and far even though the score screen labels them left and right
- [x] 7.3 Note in the roadmap or the product plan that metric distances, serve position, and movement speed remain out of scope and need a physical court model
- [x] 7.4 Confirm no third-party dependency, model, or weight was introduced and that `docs/legal/dependency-register.md` therefore needs no new row

## 8. Verification

- [x] 8.1 Run `cargo fmt --all` and `tools/verify-engine.sh` in the engine and confirm formatting, lint, and tests are clean
- [x] 8.2 Run `flutter analyze` in `app/` and confirm it is clean
- [x] 8.3 Update the existing tests that this change stops compiling — the artifact-layout and regeneration tests in particular — without adding new test files
- [x] 8.4 Run the change verification workflow and record the evidence under `docs/verification/`
