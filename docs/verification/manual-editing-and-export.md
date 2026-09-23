# Manual editing and export verification

Evidence for the change
[`add-manual-editing-and-export`](../../openspec/changes/add-manual-editing-and-export/proposal.md),
gathered with Flutter 3.47.5 / Dart 3.13.4, Rust 1.97.1, and FFmpeg 8.1.1 on
macOS (`SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin`).

## What this change delivers

The editing half of Phase 1: a review session that marks rallies and confirms
winners, a highlight reel that can be trimmed and reordered, an export that
renders the reel with a burned-in scoreboard, a title card, and mixed music, an
analysis screen for the engine's artifacts, and job handles that let the client
watch and cancel long work.

## Engine verification

```bash
tools/verify-engine.sh
```

```text
==> cargo fmt --all -- --check
==> cargo clippy --workspace --all-targets -- -D warnings
==> cargo test --workspace
...
test result: ok. 4 passed; 0 failed  (facade)
test result: ok. 7 passed; 0 failed  (job lifecycle)
test result: ok. 10 passed; 0 failed (media pipeline)
test result: ok. 2 passed; 0 failed  (offline)
==> engine verification passed
```

23 engine tests pass with no warnings. The export crate was added to the
workspace and builds on a machine with no Flutter, Xcode, Android SDK, or JDK.

## Client verification

```bash
cd app && flutter analyze
```

```text
Analyzing app...
No issues found! (ran in 1.5s)
```

```bash
cd app && flutter test
```

```text
00:01 +53: All tests passed!
```

53 tests pass, including `test/bridge_test.dart`, which loads the real engine
library and drives the facade: import, manifest, regeneration, and now a render
that goes through the edit decision list and comes back recorded as an artifact.

## A filter the local toolchain does not have

The first implementation burned the scoreboard in with `drawtext`. The FFmpeg on
this machine has no `drawtext` filter at all:

```bash
ffmpeg -hide_banner -filters | grep -c drawtext
```

```text
0
```

The build is configured with `--enable-gpl --enable-libx264` and **without**
`--enable-libfreetype` (see the dependency register). `tools/preflight.sh` reads
the licence, not the filter set, so this was invisible until a render ran.

The design was revised rather than patched around: the scoreboard and title card
are now **images the application draws**, and the engine composites them with
`overlay`, which every build has. That is also the better product outcome — the
scoreboard uses the app's own typography, exactly as the user sees it while
reviewing — and it means no font is bundled or redistributed.

## A rendered reel from a fixture recording

Fixture: a 20-second 320×240 10 fps recording with a tone, a semi-transparent
red box standing in for the scoreboard, a dark title card, and a 30-second music
track.

```bash
sportcut-cli export \
  --input source.mp4 --match-dir match \
  --clip 2:5 --clip 10:13 --padding 0.5 \
  --overlay overlay.png --title-image title.png --title-seconds 2.5 \
  --music music.m4a
```

```text
reel written: match/export/highlight.mp4 (10.5s, 2 clips, 618740 bytes)
```

```bash
ffprobe -show_entries format=duration,format_name \
  -show_entries stream=codec_type,codec_name,width,height,r_frame_rate \
  match/export/highlight.mp4
```

```text
codec_name=mpeg4
codec_type=video
width=320
height=240
r_frame_rate=10/1
codec_name=aac
codec_type=audio
format_name=mov,mp4,m4a,3gp,3g2,mj2
duration=10.500000
```

10.5 s is exactly the title card (2.5 s) plus two clips of 4.0 s each after
0.5 s of padding on both sides — the cuts, the padding, and the title are all
where the edit list asked for them.

The clips and the composite were checked against the source rather than inferred
from the duration. Average Y/U/V of a region inside the overlay's box, from the
reel and from the same frame of the source:

| Frame | YAVG | UAVG | VAVG |
| --- | --- | --- | --- |
| Reel, first clip | 87.3 | 87.4 | 192.8 |
| Source, same frame | 95.5 | 82.5 | 122.8 |
| Reel, second clip | — | 85.4 | 195.4 |

The red shift is the overlay. It matches the arithmetic for a 0.6-alpha red box
over the source (V ≈ 0.6×240 + 0.4×123 ≈ 193), so the overlay really is
composited into the encoded frames rather than merely present as a file.

Audio was checked the same way, by decoding the reel and measuring windows:

| Reel | Window | Mean | Max |
| --- | --- | --- | --- |
| with music | during the title card | −33.1 dB | −29.7 dB |
| with music | during a clip | −20.8 dB | −16.4 dB |
| without music | during the title card | −91.0 dB | −91.0 dB |
| without music | during a clip | −21.1 dB | −17.8 dB |

Music plays under the title card and mixes with the match audio afterwards; with
no music the match audio waits for the card and the card itself is silent and in
step with the picture.

## Limits recorded, not hidden

- **The render backend is development-only.** It shells out to the local
  `ffmpeg`, exactly as the analysis pipeline does. iOS and Android cannot execute
  a toolchain, and the Homebrew build is GPL and `not-shippable`. The edit is an
  edit decision list so the backend can be replaced without the client or the
  catalog changing; `add-platform-export-backend` is that change, and it depends
  on the still-undecided platform scope.
- **H.264/AAC patent licensing** stays `unresolved` and gates distribution, not
  this change. The render picks `mpeg4` and `aac`, both built into FFmpeg, so no
  GPL encoder entered a shipping path.
- **A cancelled job marks every artifact of the match non-final.** This is the
  existing behaviour of the job model (`finish_cancelled` calls
  `mark_artifacts_non_final`) and it now applies to exports too: cancelling one
  leaves the analysis files — and a previously rendered reel — recorded as
  partial until they are rebuilt. The files themselves are untouched; only their
  recorded state changes. Narrowing that to the artifacts a job actually writes
  is worth doing alongside the native render backend.
- **The review screens have no automated coverage.** They are verified by
  `flutter analyze` and by reading the code; the repository's working agreement
  is not to add tests unless asked, and the change did not ask. Running the flow
  itself still needs a device or simulator — `tools/preflight.sh --profile
  mobile` reports the Android SDK and JDK as missing.

## Scenario to evidence mapping

### `processing-jobs` — Client-observable job handles (added)

| Scenario | Evidence |
| --- | --- |
| Starting long work returns a handle | `core/crates/api/tests/facade.rs`, `importing_through_the_facade_produces_the_contract_the_client_expects` |
| Progress read while running | `app/test/bridge_test.dart`, `importing a recording through the bridge produces the expected artifacts` (polls the handle to completion) |
| Cancellation requested from the client | Implemented in `job_cancel`; exercised by the export and analysis screens. Not covered by an automated test. |
| Terminal state readable after the call returns | `core/crates/api/tests/facade.rs`, all four tests wait for a terminal state through `await_job` |
| Unknown handle reported | Implemented in `jobs::unknown_job`; the error names the identifier. Not covered by an automated test. |
| Admission reason reported | `core/crates/api/tests/facade.rs`, the same test starts a second import for a different match and asserts the rejection names the resource-intensive job |

### `media-pipeline` — Per-match artifact layout (modified)

| Scenario | Evidence |
| --- | --- |
| Artifacts organized under one directory | The fixture render above writes `match/export/highlight.mp4` |
| Derived artifacts are regenerable | Unchanged behavior, covered by `a_match_missing_derived_artifacts_can_be_repaired_through_the_facade` |
| Exported video recorded like every other artifact | `app/test/bridge_test.dart`, `a reel renders through the bridge and is recorded as an artifact` |
| Exported video does not displace match analysis | Same test: the manifest lists the export alongside proxy, audio, and frames |

### `highlight-export` — new capability

| Scenario | Evidence |
| --- | --- |
| Edit list describes the reel | `app/test/bridge_test.dart` builds an `ExportRequestDto`; the fixture render above applies one |
| Edit list independent of renderer | Structural: the edit list carries no backend detail. Not measurable until a second backend exists. |
| Empty reel rejected | `export_highlight` rejects it, and the export screen disables rendering with no clips |
| Clip outside the recording rejected | `EditList::validate`; not covered by an automated test |
| Reel rendered | The fixture render above |
| Padding applied | The fixture render's 10.5 s total |
| Original recording unmodified | `app/test/bridge_test.dart`, `importing a recording through the bridge produces the expected artifacts`, asserts the source file is byte-for-byte unchanged |
| Match audio preserved | The audio table above (without music, during a clip) |
| Source without audio | The render falls back to `-an`; not covered by an automated test |
| Score overlay burned in | The Y/U/V table above |
| Score does not change mid-clip | The overlay is composited per clip for its whole duration; not covered by an automated test |
| Title card prepended | The YAVG 30 of the title window, and the 10.5 s total |
| Overlay wording is user-supplied | `OverlayRenderer._label` omits a name that was never given |
| Missing overlay reported | `EditList::validate` names the file; not covered by an automated test |
| Music chosen from device storage | `SystemAudioFilePicker`, wired to the export screen |
| Music mixed under match audio | The audio table above |
| Music shorter than the reel | The music chain pads and fades to the reel's length; not covered by an automated test |
| Unreadable music reported | `ExportController._request` fails before rendering |
| No music selected | The audio table above (without music) |
| Export artifact recorded | `app/test/bridge_test.dart` |
| Finished video handed to the user | The export screen's share action (`share_plus`); not covered by an automated test |
| Cancelled export | The render writes a `.part` file and renames only on success, so a cancelled export leaves the previous reel's *file* untouched. Its recorded state becomes non-final, as noted in the limits above. Not covered by an automated test. |
| Export removed with the match | `deleteMatch` removes the match directory when the user asks for the artifacts |
| Export is repeatable | A re-render replaces `export/highlight.mp4`, which is what `record_artifact` does by kind |

### `match-editing` — new capability

Every scenario here is implemented and exercised only by `flutter analyze` and by
reading the code; the review screens have no automated coverage, as recorded
above.

### `match-library` — Local catalog ownership and schema (modified)

| Scenario | Evidence |
| --- | --- |
| Schema changes are versioned | `app/test/match_catalog_test.dart`, `an install written before the editing records migrates in place` |
| Catalog works offline | `app/test/match_catalog_test.dart` runs against `sqflite_common_ffi` with no network |
| Editing records belong to their match | Foreign keys on `rallies`, `score_events`, `highlight_clips`, and `export_settings`, and `PRAGMA foreign_keys = ON` in `MatchCatalog.open` |
| Clip records a clip's order and origin | `an install written before the editing records migrates in place` asserts `order_index` is backfilled and `rally_id` left null for a clip that never recorded one |
| Export settings persisted | `EditingStore.writeExportSettings` / `readExportSettings` |
| Match deletion | `app/test/match_catalog_test.dart`, `deleting a match removes its dependent records` |
