## Why

Wave 2 of the roadmap starts with court calibration, and it is the only feature
in that wave with no external gate: no inference runtime, no model weights, and
no test footage are needed to build it. It is also the prerequisite every later
computer-vision feature reads — player detection needs the court polygon to
ignore people off the court, and court-side assignment needs the mapping from
image coordinates to court coordinates. Meanwhile the pieces are already
scaffolded and idle: a `sportcut-court` crate with no implementation, an
`ArtifactKind::Calibration` and `calibration/` directory that nothing writes, a
`matches.court_calibration` column that nothing reads, and a `/match/calibration`
route showing a placeholder. The app has promised the user a calibration step
since the product plan was written and cannot deliver it.

## What Changes

- The user calibrates the court by marking four corners on the recording. The
  corners are stored as normalized coordinates in the **displayed** frame space,
  so the same values are valid for the original recording, the analysis proxy,
  the sampled frames, and the on-screen preview without any conversion.
- The engine gains a court plane in `sportcut-court`: a homography between
  normalized image coordinates and a **unit-square court**. The user states which
  way the court runs — away from the camera, or across the view — which is what
  tells the engine whether the edge nearest the camera is a baseline or a
  sideline and therefore where the net falls. Side assignment is which half of
  the net a point falls in. The court is addressed in normalized coordinates
  rather than metres, so deciding who is on which side never depends on the
  physical court's dimensions, and the near/far versus left/right ambiguity of an
  end-on camera does not become a stored decision about the score.
- The calibration is recorded with the match and is editable later. Re-calibrating
  invalidates derived artifacts that were computed from the old court instead of
  silently leaving them in place.
- The engine writes the calibration into the match directory as an artifact so a
  headless run can work from the match directory alone, and the manifest reports
  it like every other artifact.
- Regeneration stops over-claiming: an artifact the engine cannot rebuild —
  because it is user input rather than derived output — is reported as such
  rather than counted as repaired. **BREAKING** for the regeneration contract: a
  caller that treated every missing artifact as rebuildable must now handle a
  kind that is missing and not rebuildable.

## Capabilities

### New Capabilities

- `court-calibration`: marking the court on a recording, the normalized court
  plane and the homography to it, projecting the court back onto the image for
  the user to check, side assignment, persistence with the match, and editing
  the calibration afterwards.

### Modified Capabilities

- `media-pipeline`: the per-match artifact layout gains a user-authored
  calibration artifact, and the "derived artifacts are regenerable" requirement
  narrows to artifacts the engine can actually recompute — a missing
  calibration is reported as needing the user, not as repaired.
- `match-library`: the catalog becomes the source of truth for a match's
  calibration, and the match record carries it so the calibration survives a
  wiped artifact directory and is available without opening the engine.

## Impact

- **Engine**: `sportcut-court` gains the homography, the court plane, side
  assignment, and validation; it becomes a real dependency of `sportcut-api`.
  `sportcut-media` gains the regeneration distinction between rebuildable and
  user-authored artifacts. `sportcut-api` gains a facade call to save a
  calibration and one to read the projected court, plus DTOs for both.
- **Bridge**: new DTOs and facade calls cross `flutter_rust_bridge`, so
  `tools/generate-bridge.sh` must be re-run and the version pins in
  `core/crates/api/Cargo.toml`, `app/pubspec.yaml`, and the generation script
  stay untouched and equal.
- **Client**: `features/calibration/` grows from a placeholder into a real
  screen with a scrubber, four draggable handles, and a projected court overlay;
  `MatchRecord`, the catalog's match row mapping, and the bridge wrapper change
  to carry the calibration.
- **Catalog**: the `court_calibration` column becomes live. No new column is
  needed, so the migration is limited to loading and writing it — a stored match
  that never had a calibration keeps loading with none.
- **Dependencies**: no new third-party dependency and no model weights, so
  `docs/legal/dependency-register.md` gains no row. The homography is arithmetic
  the engine implements itself.
- **Documentation**: the roadmap's Wave 2 status and the calibration placeholder
  text change; the product plan's court-calibration step is now implemented
  rather than promised.
