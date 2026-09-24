# Court calibration verification

Evidence for the `add-court-calibration` change, gathered with Flutter 3.47.5 /
Dart 3.13.4, Rust 1.97.1, and ffmpeg 8.1.1 on macOS
(`SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin`).

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

23 tests pass: `facade` 4, `job_lifecycle` 7, `media_pipeline` 10, `offline` 2.
No new dependency entered the workspace — `git diff core/Cargo.lock` adds no
crate — so `docs/legal/dependency-register.md` needs no new row. The only new
inter-crate edge is `sportcut-storage -> sportcut-court`, both first-party and
both inside the engine workspace.

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
00:01 +53: All tests passed!
```

53 tests pass, the same set as before this change. Two of them were updated
because the new `ArtifactManifestDto.notRebuildableKinds` field made their
constructions stop compiling (`test/support/fakes.dart`,
`test/support/fake_match_library.dart`); no test file was added.

## The engine path, end to end

The repository's working agreement is to implement first and not to add test
files, so the new engine behaviour was exercised by a throwaway harness built
outside the checkout against the real crates — the pipeline that runs, the
manifest that is written, and the facade the client actually calls. It printed:

```text
1. imported a match with a manifest
2. an uncalibrated match reports no calibration and records none
3. derived geometry without storing: net (0.216, 0.493)-(0.784, 0.493)
4. saving wrote the file and recorded it in the manifest as final
5. the calibration reads back, and the manifest view reports nothing missing
6. re-saving the same court invalidates nothing
7. a changed court invalidated the tracks derived from the old one
8. a missing calibration is reported as unrebuildable (rebuilt [])

all engine calibration checks passed
```

The geometry itself was checked separately, against properties rather than
against a stored expectation:

- the unit square maps to itself, so the first corner is the court origin;
- the court centre projects to `(0.500000, 0.457143)` for a trapezoid whose near
  edge is wider — exactly where that quadrilateral's diagonals cross, which is
  the invariant a wrong homography breaks;
- projection round-trips image to court and back;
- the net lands at the midpoint of the court's long axis in both orientations,
  through `u` when the court runs across the view and through `v` when it runs
  away;
- a repeated corner, three corners in a straight line, a corner outside the
  frame, a bow-tie ordering, and a quadrilateral enclosing almost no area are
  each rejected with a message naming the problem.

## Scenario to evidence mapping

### `court-calibration` (added)

| Scenario | Evidence |
| --- | --- |
| Four corners captured | Harness step 4 |
| Marked position independent of rotation and resolution | The rotation check above, plus normalized corners |
| Marked position independent of the preview layout | The overlay and the video share one `AspectRatio`; `app_shell_test`'s `every route in the table builds a screen` constructs the screen |
| Incomplete calibration not saved | `CalibrationController.save` and `MatchRepository.saveCalibration` both refuse; harness step 2 shows an unmarked match records nothing |
| Positions outside the frame rejected | `nudgeCorner` clamps to the frame; `CalibrationSegment::validate` rejects an out-of-range corner with a named error |
| Mapping produced for a valid calibration | Harness step 3 |
| Mapping round-trips | Geometry checks above |
| Degenerate calibration rejected | Geometry checks above |
| Court orientation recorded | Harness steps 3, 4, and the two net orientations |
| Position assigned to a side | Geometry checks: `side_of` follows the net on the long axis |
| Side determined for a player position | `CalibrationSegment::side_of`; there is no tracking stage yet to feed it |
| Outline available for verification | Harness step 3 returns the outline and the net |
| Outline follows an edited corner | Harness step 7 changes a corner and the projection is re-derived |
| Calibration survives a restart | Harness step 5 reads the stored calibration back |
| Calibration survives deleted artifacts | Harness step 8; the catalog copy is the source of truth and the artifact is re-written from it |
| No calibration invented | Harness steps 2 and 8 |
| Engine writes the calibration into the match directory | Harness step 4 |
| Edited calibration replaces the stored one | Harness step 7 |
| Artifacts from the previous court invalidated | Harness step 7 drops `tracks` |
| Unchanged calibration discards nothing | Harness step 6 |
| Missing calibration reported as needing the user | Harness step 8 |
| Rebuild completes the artifacts it can reproduce | `regenerate_missing` now partitions at the top; the existing `media_pipeline` regeneration test asserts the rebuilt half |
| Calibration works offline | No network call exists on the path; ffmpeg and SQLite are local |
| No recording data leaves the device | As above |

### `media-pipeline` — Per-match artifact layout (modified)

| Scenario | Evidence |
| --- | --- |
| Artifacts organized under one directory | Harness step 4 writes `calibration/calibration.json` inside the match directory |
| Derived artifacts are regenerable | `media_pipeline` regeneration test |
| User-authored artifacts are not regenerable | Harness steps 2 and 8 |
| Exported video recorded like every other artifact | Unchanged by this change; existing export coverage |
| Exported video does not displace match analysis | Unchanged by this change; existing export coverage |

### `match-library` — Local catalog ownership and schema (modified)

| Scenario | Evidence |
| --- | --- |
| Schema changes are versioned | No migration is needed: `court_calibration` is in the version-1 initial schema and was never written |
| Catalog works offline | Unchanged; the column is written through the same local SQLite handle |
| Editing records belong to their match | The calibration is a column on the `matches` row |
| Court calibration owned by the catalog | `MatchCatalog.encodeCalibration` writes it on the match row; `MatchRecord.courtCalibration` reads it without the engine |
| Existing matches load without a calibration | A null column decodes to no calibration, and no other field is touched |
| Clip records a clip's order and origin | Unchanged by this change |
| Export settings persisted | Unchanged by this change |
| Match deletion | The calibration lives on the `matches` row, which deletion removes; `library_screen_test` covers the delete flow |

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

## Not verified here

- **The calibration screen's interaction.** Dragging a handle, scrubbing to a
  clear frame, and pressing save are not covered by a test: this change adds no
  test files, and the existing client tests only assert that the route builds.
  The screen's arithmetic is thin by design — a drag is a delta divided by the
  box size, and the geometry comes from the engine — but the flow has not been
  driven.
- **A real recording.** The rotation check and the engine harness both use
  synthetic ffmpeg fixtures. The Phase 0 "test footage" gate is still open, and
  nothing here measures whether a marked court is accurate on a real match.
- **The end-to-end path on a device.** The engine harness drives the real
  facade, and `bridge_test` loads the real engine library, but the two have not
  been run together on the calibration calls: no test exercises
  `save_match_calibration` or `court_geometry` *through* the Dart bindings.
  `flutter analyze` proves those bindings exist and typecheck.

## Known limits carried forward

- The court is normalized, not metric. Distance in metres, serve position, and
  movement speed stay out of scope until a physical court model is added.
- The user states which way the court runs. Marking the net line as two further
  points would remove that question and is the natural refinement; the stored
  record is shaped so it can be added without a rewrite.
- A recording shot from behind a baseline reads as near and far, while the score
  screen still calls the two sides left and right.
