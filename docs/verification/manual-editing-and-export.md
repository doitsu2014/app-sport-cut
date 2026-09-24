# Manual editing and export verification

Evidence for the change
[`add-manual-editing-and-export`](../../openspec/changes/archive/2026-09-24-add-manual-editing-and-export/proposal.md),
gathered with Flutter 3.47.5 / Dart 3.13.4, Rust 1.97.1, and FFmpeg 8.1.1 on
macOS (`SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin`). The scenario tables below
were completed by
[`add-wave-1-2-test-coverage`](../../openspec/changes/add-wave-1-2-test-coverage/proposal.md),
which turned the observations recorded here into tests that run on every
change.

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
test result: ok. 20 passed; 0 failed  (court, unit)
test result: ok. 13 passed; 0 failed  (export, unit)
test result: ok. 6 passed; 0 failed   (export, render)
test result: ok. 11 passed; 0 failed  (facade)
test result: ok. 7 passed; 0 failed   (job lifecycle)
test result: ok. 10 passed; 0 failed  (media pipeline)
test result: ok. 2 passed; 0 failed   (offline)
==> engine verification passed
```

69 engine tests pass with no warnings — 46 of them added by the coverage change,
covering the edit list's rules, the court geometry, the job handles, and the
renderer. No test needs a mobile toolchain, and the ones that need a recording
generate it with the local `ffmpeg` and skip when that toolchain is absent.

## Client verification

```bash
cd app && flutter analyze
```

```text
Analyzing app...
No issues found! (ran in 1.4s)
```

```bash
cd app && flutter test
```

```text
00:03 +127: All tests passed!
```

127 tests pass — 74 added by the coverage change — including
`test/bridge_test.dart`, which loads the real engine library and drives the
facade: import, manifest, regeneration, a render that goes through the edit
decision list, and now the calibration calls and a cancelled import.

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
where the edit list asked for them. This run is what
`core/crates/export/tests/render.rs` now does on every change, against fixtures
it generates itself.

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

## Scenario to evidence mapping

Each row names the test that covers it. A row that says *manual-only* is a
scenario no automated test can hold, with the reason recorded in the last
section.

### `processing-jobs` — Client-observable job handles (added)

| Scenario | Evidence |
| --- | --- |
| Starting long work returns a handle | `core/crates/api/tests/facade.rs`, `importing_through_the_facade_produces_the_contract_the_client_expects` |
| Progress read while running | `app/test/export_screen_test.dart`, `a running render shows its stage and can be cancelled`; `app/test/analysis_screen_test.dart`, `a running rebuild can be cancelled` |
| Cancellation requested from the client | `core/crates/api/tests/facade.rs`, `a_cancelled_import_stops_and_leaves_nothing_final`; `app/test/bridge_test.dart`, `a running import can be cancelled from the client` |
| Terminal state readable after the call returns | `core/crates/api/tests/facade.rs`, every test that waits for a terminal state through `await_job` |
| Unknown handle reported | `core/crates/api/tests/facade.rs`, `an_unknown_job_handle_is_reported_by_identifier`; through the bindings, `app/test/bridge_test.dart`, `an unknown job handle is reported through the binding` |
| Admission reason reported | `core/crates/api/tests/facade.rs`, `importing_through_the_facade_produces_the_contract_the_client_expects` and `a_conflicting_job_is_refused_by_name_and_the_slot_is_released` |

### `media-pipeline` — Per-match artifact layout (modified)

| Scenario | Evidence |
| --- | --- |
| Artifacts organized under one directory | `core/crates/media/tests/media_pipeline.rs`; the export test asserts the reel lands in `export/highlight.mp4` |
| Derived artifacts are regenerable | `core/crates/api/tests/facade.rs`, `a_match_missing_derived_artifacts_can_be_repaired_through_the_facade` |
| Exported video recorded like every other artifact | `app/test/bridge_test.dart`, `a reel renders through the bridge and is recorded as an artifact` |
| Exported video does not displace match analysis | Same test: the manifest lists the export alongside proxy, audio, and frames |

### `highlight-export` — new capability

| Scenario | Evidence |
| --- | --- |
| Edit list describes the reel | `app/test/bridge_test.dart`, `a reel renders through the bridge and is recorded as an artifact`; `app/test/export_screen_test.dart`, `rendering asks the engine for the reel the user built` |
| Edit list independent of renderer | manual-only: there is no second backend to render through yet. `add-platform-export-backend` is the change that can test it |
| Empty reel rejected | `core/crates/export/src/edit_list.rs`, `a_reel_with_no_clips_is_rejected`; the export screen disables rendering with no clips (`an empty reel cannot be rendered`) |
| Clip outside the recording rejected | `core/crates/export/src/edit_list.rs`, `a_clip_outside_the_recording_is_rejected` and `a_clip_reaching_the_reported_duration_is_accepted` |
| Reel rendered | `core/crates/export/tests/render.rs`, `a_rendered_reel_holds_the_clips_in_order_with_padding_and_a_title` |
| Padding applied | Same test, and `core/crates/export/src/edit_list.rs`, `padding_is_clamped_to_the_recording` |
| Original recording unmodified | `core/crates/export/tests/render.rs`, the same test's content hash |
| Match audio preserved | `core/crates/export/tests/render.rs`, `the_reel_carries_the_match_audio` |
| Source without audio | `core/crates/export/tests/render.rs`, `a_recording_without_an_audio_track_renders_video_only` |
| Score overlay burned in | `core/crates/export/tests/render.rs`, `the_overlay_is_composited_into_the_encoded_frames` |
| Score does not change mid-clip | `app/test/export_screen_test.dart`, `rendering asks the engine for the reel the user built` (the scoreboard is drawn from the score at the clip's own position); `app/test/score_timeline_test.dart`, `the score at a moment is the score as it stood then` |
| Title card prepended | `core/crates/export/tests/render.rs`, the first test's opening frame |
| Overlay wording is user-supplied | `app/test/export_screen_test.dart`, the same request assertion: the scoreboard is asked for with no names, so none can be invented |
| Missing overlay reported | `core/crates/export/src/edit_list.rs`, `an_unreadable_overlay_is_named_before_rendering` |
| Music chosen from device storage | `app/test/export_screen_test.dart`, `music is chosen from device storage and stored with the match` |
| Music mixed under match audio | `core/crates/export/tests/render.rs`, `music_shorter_than_the_reel_plays_under_it_to_the_end` |
| Music shorter than the reel | Same test |
| Unreadable music reported | `core/crates/export/src/edit_list.rs`, `an_unreadable_music_track_is_named_before_rendering`; `app/test/export_screen_test.dart`, `music that is no longer on the device is reported before rendering` |
| No music selected | `core/crates/export/tests/render.rs`, the first test's silent title window |
| Export artifact recorded | `app/test/bridge_test.dart`, `a reel renders through the bridge and is recorded as an artifact` |
| Finished video handed to the user | `app/test/export_screen_test.dart`, `a finished reel is offered to the user` asserts the offer; opening the share sheet itself is manual-only |
| Cancelled export | `core/crates/export/tests/render.rs`, `a_cancelled_export_leaves_no_partial_reel` |
| Export removed with the match | `app/test/match_repository_test.dart`, deletion with and without artifacts |
| Export is repeatable | `app/test/export_screen_test.dart`, `a finished reel is offered to the user` offers `Render again`; the renderer replaces `export/highlight.mp4` |

### `match-editing` — new capability

| Scenario | Evidence |
| --- | --- |
| Editing session opened | `app/test/score_screen_test.dart`, `a span the user marks becomes a rally on the timeline` |
| Editing works offline | No network call exists on the path; the suites run with no network access |
| Editing session left and resumed | `app/test/editing_repository_test.dart`, `a marked rally is recorded and is there next time` and `the reel keeps the order the user set` |
| Rally marked from playback | `app/test/score_screen_test.dart`, `a span the user marks becomes a rally on the timeline` |
| Boundary adjusted | `app/test/editing_repository_test.dart`, `moving a rally changes that rally and no other` |
| Marking rejected | `app/test/editing_repository_test.dart`, `a rally that does not end after it starts is rejected`; `app/test/score_screen_test.dart`, `a span that does not end after it starts is refused` |
| No rally is invented | `app/test/editing_repository_test.dart`, `a match that has not been reviewed holds no records` |
| Winner confirmed with one tap | `app/test/score_screen_test.dart`, `one tap on a side records that side as the winner` |
| Winner corrected | `app/test/score_screen_test.dart`, `correcting the winner moves the point to the other side` |
| Rally left unscored | `app/test/score_screen_test.dart`, `an unscored rally shows no score for itself` |
| Winner never inferred | `app/test/editing_repository_test.dart`, `a winner is recorded only from an explicit confirmation` |
| Score advances with confirmed winners | `app/test/score_timeline_test.dart`, `the score advances one point per confirmed rally in rally order` |
| Correction rewrites the later score | `app/test/score_timeline_test.dart`, `correcting an early winner rewrites every later score`; `app/test/editing_repository_test.dart`, the score-events test |
| Score shown with the match | `app/test/editing_repository_test.dart`, the same test's `scoreSummaries` assertion |
| Score is reproducible | `app/test/score_timeline_test.dart`, `the same rallies always derive the same timeline` |
| Rally kept as a clip | `app/test/highlights_screen_test.dart`, `keeping a rally puts a clip in the reel` |
| Rally left out | `app/test/highlights_screen_test.dart`, `removing a clip takes it out of the reel and leaves the rally` |
| Clip trimmed | `app/test/highlights_screen_test.dart`, `trimming a clip moves its boundaries and not the rally` |
| Clips reordered | `app/test/highlights_screen_test.dart`, `dragging a clip rewrites the reel order` |
| Clip order is the user's | `app/test/editing_repository_test.dart`, `the reel keeps the order the user set` |

### `match-library` — Local catalog ownership and schema (modified)

| Scenario | Evidence |
| --- | --- |
| Schema changes are versioned | `app/test/match_catalog_test.dart`, `an install written before the editing records migrates in place` |
| Catalog works offline | `app/test/match_catalog_test.dart` runs against `sqflite_common_ffi` with no network |
| Editing records belong to their match | Foreign keys on `rallies`, `score_events`, `highlight_clips`, and `export_settings`, and `PRAGMA foreign_keys = ON` in `MatchCatalog.open` |
| Clip records a clip's order and origin | `an install written before the editing records migrates in place` asserts `order_index` is backfilled and `rally_id` left null for a clip that never recorded one |
| Export settings persisted | `app/test/editing_repository_test.dart`, `export settings are stored and read back` |
| Match deletion | `app/test/match_catalog_test.dart`, `deleting a match removes its dependent records` |

## Manual-only verification

These rows are not covered by an automated test, with the reason. Everything
else in the tables above is covered.

| Scenario or behaviour | Why it is manual |
| --- | --- |
| Opening the platform share sheet | `share_plus` hands the file to the operating system; there is no seam a test can assert through without the platform. The screen's offer of the file is covered |
| Exporting on a device | The render backend is the workstation's `ffmpeg`; a device cannot run it at all until `add-platform-export-backend` lands |
| The reel playing back on a device | Needs a simulator or device; the toolchain gate in the roadmap records why one is not available here |

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
- **A job reports its terminal state a moment before its worker releases the
  heavy-job admission slot.** A client that starts the next import the instant
  the previous one finished can therefore be told that another heavy job is
  still running. The application's own flow never does this — the user has to
  tap import again — but the tests that chain imports deliberately wait for the
  slot, which is what `start_import_when_admitted` and `importWhenAdmitted`
  document. Releasing the slot before the terminal state is a small, separate
  change to `sportcut-jobs`.
