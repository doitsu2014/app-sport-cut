# Court calibration verification

Evidence for the
[`add-court-calibration`](../../openspec/changes/add-court-calibration/proposal.md)
change, gathered with Flutter 3.47.5 / Dart 3.13.4, Rust 1.97.1, and ffmpeg
8.1.1 on macOS (`SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin`).

The change itself was verified with a harness built outside the checkout, which
printed its results once. Those results are no longer the evidence: the harness
was replaced by
[`add-wave-1-2-test-coverage`](../../openspec/changes/add-wave-1-2-test-coverage/proposal.md),
which turned every check it made into a test that runs on every change. The
tables below name those tests.

## What this change had to establish first

The design rests on one assumption that would invalidate the whole coordinate
space if it were wrong: that the analysis proxy, and the frames sampled from it,
are written upright while the original recording keeps whatever rotation its
container declares. This was checked before any geometry was written, by
building a rotation-tagged fixture and running the real pipeline over it:

```bash
ffmpeg -y -f lavfi -i "color=c=red:s=160x240:r=10:d=2" \
       -f lavfi -i "color=c=blue:s=160x240:r=10:d=2" \
       -filter_complex "[0:v][1:v]hstack=inputs=2[v]" -map "[v]" \
       -c:v libx264 -pix_fmt yuv420p base.mp4
ffmpeg -y -display_rotation:v:0 90 -i base.mp4 -c copy tagged.mp4
sportcut-cli probe tagged.mp4 --json
sportcut-cli import --input tagged.mp4 --match-id rotcheck --match-root <root>
ffprobe -show_entries stream=width,height -show_entries stream_side_data=rotation \
        <root>/rotcheck/proxy/proxy.mp4
ffprobe -show_entries stream=width,height \
        <root>/rotcheck/frames/frame_000001.jpg
```

| Reading | Result |
| --- | --- |
| Original | `320x240`, `rotation_degrees: 90` |
| Proxy | `240x320`, no rotation side data |
| Sampled frame | `240x320` |
| Top-left of the sampled frame | blue, which was the right half of the stored pixels |

So the proxy and the frames carry the rotation already applied, and the stored
pixels do not. The playback surface agrees with them:
`VideoPlayerPlaybackController.buildSurface` draws the platform player's
`value.aspectRatio`, which is reported with rotation applied, inside an
`AspectRatio` box. Normalized *displayed* coordinates are therefore the one space
the preview, the proxy, and the frames share, which is what the design assumes.

## Commands

```bash
cd core && cargo fmt --all -- --check
```

```text
FORMAT OK
```

```bash
./tools/verify-engine.sh
```

```text
==> cargo fmt --all -- --check
==> cargo clippy --workspace --all-targets -- -D warnings
==> cargo test --workspace
==> engine verification passed
```

69 tests pass: `court` 20, `export` 13 + 6, `facade` 11, `job_lifecycle` 7,
`media_pipeline` 10, `offline` 2. No new dependency entered the workspace —
`git diff core/Cargo.lock` adds no crate — so `docs/legal/dependency-register.md`
needs no new row. The only new inter-crate edge is `sportcut-storage ->
sportcut-court`, both first-party and both inside the engine workspace.

```bash
cd app && flutter analyze
```

```text
Analyzing app...
No issues found! (ran in 1.4s)
```

```bash
./tools/build-engine-lib.sh
cd app && flutter test
```

```text
00:03 +127: All tests passed!
```

127 tests pass. Two of them were updated when this change added
`ArtifactManifestDto.notRebuildableKinds` (`test/support/fakes.dart`,
`test/support/fake_match_library.dart`); the rest of the growth is the coverage
change.

## The geometry, checked by property

The court is arithmetic, so it is checked against properties rather than against
stored expectations — the properties a wrong homography breaks:

```bash
cargo test -p sportcut-court
```

```text
test result: ok. 20 passed; 0 failed
```

`core/crates/court/src/homography.rs` and `core/crates/court/src/lib.rs` hold:
the unit square maps to itself, so the first corner is the court origin; the
court centre projects to where the marked quadrilateral's diagonals cross, which
a correct projective map reproduces and an affine one does not; projection
round-trips image to court and back through a trapezoid and through the affine
branch a parallelogram takes; the net lands at the midpoint of the court's long
axis in both orientations; side assignment follows the net rather than the image
position; the outline carries the marked corners and the projected net, and moves
with an edited corner; and a repeated corner, three corners in a straight line, a
corner outside the frame, a bow-tie ordering, and a quadrilateral enclosing
almost no area are each rejected with a message naming the problem.

## The engine path, end to end

`core/crates/api/tests/facade.rs` drives the facade the client calls, against a
match directory produced by a real import:

```text
test saving_a_calibration_writes_the_artifact_and_reads_back ... ok
test saving_the_same_calibration_again_discards_nothing ... ok
test a_missing_calibration_is_reported_as_needing_the_user ... ok
test a_match_reports_no_calibration_until_one_is_saved ... ok
```

Those four assert what the throwaway harness printed: an uncalibrated match
reports no calibration and records none; saving writes
`calibration/calibration.json` and records it in the manifest as final; the
calibration reads back with the corners and orientation the user marked, and the
geometry the client asks for directly is the same arithmetic; re-saving the same
court invalidates nothing, while a changed court invalidates the `tracks`
derived from the old one; and a wiped calibration is reported as missing and
*not* rebuildable, so a repair rebuilds the frames without inventing a court.

## Scenario to evidence mapping

### `court-calibration` (added)

| Scenario | Evidence |
| --- | --- |
| Four corners captured | `app/test/calibration_screen_test.dart`, `the four corners are marked and the court is projected`; `saving stores the court with the match` |
| Marked position independent of rotation and resolution | The rotation check above; corners are normalized, and `core/crates/court/src/lib.rs` validates them in that space |
| Marked position independent of the preview layout | `app/test/calibration_screen_test.dart`, `dragging a handle moves that corner` (the handle and the frame share one aspect-ratio box) |
| Incomplete calibration not saved | `app/test/calibration_controller_test.dart`, `an incomplete calibration is not saved`; `app/test/calibration_screen_test.dart`, `an incomplete court cannot be saved` |
| Positions outside the frame rejected | `app/test/calibration_controller_test.dart`, `a corner dragged past the edge stops at the edge`; `core/crates/court/src/lib.rs`, `a_corner_outside_the_frame_is_rejected_by_position` |
| Mapping produced for a valid calibration | `core/crates/court/src/lib.rs`, `a_valid_calibration_produces_a_mapping_in_both_directions` |
| Mapping round-trips | `core/crates/court/src/homography.rs`, `mapping_a_projected_court_round_trips` |
| Degenerate calibration rejected | `core/crates/court/src/lib.rs`, the five rejection tests; `app/test/calibration_controller_test.dart`, `a court the engine rejects is reported and nothing is drawn`; `app/test/calibration_screen_test.dart`, `a court the engine rejects is reported to the user` |
| Court orientation recorded | `core/crates/court/src/lib.rs`, `the_net_falls_on_the_courts_long_axis`; `app/test/calibration_screen_test.dart`, `the way the court runs is the user choice, and is saved` |
| Position assigned to a side | `core/crates/court/src/lib.rs`, `a_position_is_assigned_the_half_of_the_net_it_falls_in` |
| Side determined for a player position | manual-only: there is no tracking stage yet to feed a position. The mapping a tracker will read is covered by the two rows above |
| Outline available for verification | `core/crates/court/src/lib.rs`, `the_outline_carries_the_marked_corners_and_the_projected_net` |
| Outline follows an edited corner | `core/crates/court/src/lib.rs`, `the_outline_follows_an_edited_corner` |
| Calibration survives a restart | `app/test/match_catalog_test.dart`, `a court calibration is stored on the match and read back`; `core/crates/api/tests/facade.rs`, `saving_a_calibration_writes_the_artifact_and_reads_back` |
| Calibration survives deleted artifacts | The catalog is the source of truth: the calibration lives on the match row, so it is read without the artifact (`a_match_that_was_never_calibrated...` shows the null case, and the facade test shows the artifact being written from it) |
| No calibration invented | `core/crates/api/tests/facade.rs`, `a_match_reports_no_calibration_until_one_is_saved`; `app/test/match_catalog_test.dart`, `a match that was never calibrated loads with no calibration` |
| Engine writes the calibration into the match directory | `core/crates/api/tests/facade.rs`, `saving_a_calibration_writes_the_artifact_and_reads_back` |
| Edited calibration replaces the stored one | `core/crates/api/tests/facade.rs`, `saving_the_same_calibration_again_discards_nothing` |
| Artifacts from the previous court invalidated | Same test: `tracks` are dropped and named in `invalidated_kinds` |
| Unchanged calibration discards nothing | Same test |
| Missing calibration reported as needing the user | `core/crates/api/tests/facade.rs`, `a_missing_calibration_is_reported_as_needing_the_user` |
| Rebuild completes the artifacts it can reproduce | Same test: the frames are rebuilt while the calibration stays reported as not rebuildable |
| Calibration works offline | No network call exists on the path; ffmpeg and SQLite are local |
| No recording data leaves the device | As above |

### `media-pipeline` — Per-match artifact layout (modified)

| Scenario | Evidence |
| --- | --- |
| Artifacts organized under one directory | `core/crates/api/tests/facade.rs` writes `calibration/calibration.json` inside the match directory |
| Derived artifacts are regenerable | `core/crates/media/tests/media_pipeline.rs` |
| User-authored artifacts are not regenerable | `a_missing_calibration_is_reported_as_needing_the_user` |
| Exported video recorded like every other artifact | Unchanged by this change; existing export coverage |
| Exported video does not displace match analysis | Unchanged by this change; existing export coverage |

### `match-library` — Local catalog ownership and schema (modified)

| Scenario | Evidence |
| --- | --- |
| Schema changes are versioned | No migration is needed: `court_calibration` is in the version-1 initial schema and was never written |
| Catalog works offline | Unchanged; the column is written through the same local SQLite handle |
| Editing records belong to their match | The calibration is a column on the `matches` row |
| Court calibration owned by the catalog | `app/test/match_catalog_test.dart`, `a court calibration is stored on the match and read back`; a value that cannot be decoded is reported as no calibration (`a calibration that cannot be read is reported as no calibration`) |
| Existing matches load without a calibration | `app/test/match_catalog_test.dart`, `a match that was never calibrated loads with no calibration` |
| Clip records a clip's order and origin | Unchanged by this change |
| Export settings persisted | Unchanged by this change |
| Match deletion | `app/test/match_catalog_test.dart`, `deleting a match removes its calibration with it` |

### Crossing the boundary

`app/test/bridge_test.dart`, `a calibration crosses the bridge, is stored, and
reads back`, drives `courtGeometry`, `saveCalibration`, and `matchCalibration`
through the real generated bindings and the real engine library: projecting
stores nothing, saving writes the artifact and the manifest row, and the corners
and orientation survive the round trip.

## Manual-only verification

| Scenario or behaviour | Why it is manual |
| --- | --- |
| Dragging a handle on a real touch screen | The gesture and the arithmetic are covered; whether the handle feels right under a finger is a judgement that needs a device |
| Calibrating a real match | Every fixture here is synthetic. The Phase 0 "test footage" gate is still open, so nothing measures whether a marked court is accurate on a real recording |
| Running the calibration flow on a device | Needs a simulator or device; the roadmap's platform-scope gate records why one is not available here |

## Two things implementation decided, recorded back here

- **The regeneration outcome reaches the client through the manifest, not the
  job.** Task 4.2 asked to extend the regeneration result so a caller can tell a
  rebuilt artifact from one that could not be rebuilt. The engine's
  `regenerate_missing` now returns a `Regeneration { rebuilt, not_rebuildable }`,
  but the *client* learns it from `ArtifactManifestDto.notRebuildableKinds`,
  which is a pure function of the manifest and the engine's rebuildable set.
  Reading it from the manifest means it is right whenever it is asked, rather
  than only in the moments after a repair job.
- **Calibration persistence lives in `sportcut-storage`.** It is the crate that
  owns the match directory and the manifest, so it now depends on
  `sportcut-court` for the record type. The alternative — a small module in
  `sportcut-api` — would have put artifact writing in a crate documented as a
  thin typed wrapper.

## Known limits carried forward

- The court is normalized, not metric. Distance in metres, serve position, and
  movement speed stay out of scope until a physical court model is added.
- The user states which way the court runs. Marking the net line as two further
  points would remove that question and is the natural refinement; the stored
  record is shaped so it can be added without a rewrite.
- A recording shot from behind a baseline reads as near and far, while the score
  screen still calls the two sides left and right.
