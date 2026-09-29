# Software Architecture

## What Sportcut is

Sportcut turns a badminton match recording into a polished highlight video,
entirely on the user's Mac: import a local recording, strip the downtime,
confirm the score in a few taps, pick the best rallies, and export an edited
video. Everything runs offline — recordings and analysis results never leave
the device, and no cloud or online-API dependency may be introduced.

The product is deliberately semi-automatic. The app proposes rally boundaries,
who serves, and a highlight order; the user confirms. It does not claim fully
automatic officiating, because shuttlecocks are small, fast, and often hidden.

## Stack

| Layer | Choice |
| --- | --- |
| Client | Flutter / Dart 3, macOS desktop |
| Client state | Riverpod (`flutter_riverpod`) |
| Native engine | Rust workspace, edition 2021, `rust-version = 1.80` |
| Language boundary | `flutter_rust_bridge` v2, pinned to **2.13.0** |
| Media processing | `ffmpeg` / `ffprobe`, behind the `MediaToolchain` abstraction |
| Person detection | TensorFlow Lite C runtime + EfficientDet-Lite0 int8 (offline) |
| Client catalog | SQLite (`sqflite`) |

## System architecture

```
Flutter App (app/)
  ├─ Workspaces (home) and the three-pane studio
  ├─ Video import, library, and playback
  ├─ Court calibration
  ├─ Analysis preparation (proxy, audio, frames)
  ├─ Player tracking (count, tracks, sides)
  ├─ Rally review and score confirmation (+ serving side)
  ├─ Highlights (ranked suggestions, keep / trim / reorder)
  └─ Export settings and rendering

Rust Engine (core/)
  ├─ Frame sampling and proxy          (sportcut-media)
  ├─ Court geometry / homography       (sportcut-court)
  ├─ Person detection and tracking     (sportcut-vision)
  ├─ Rally segmentation                (sportcut-rally)
  ├─ Serving-side derivation           (sportcut-score)
  ├─ Highlight ranking                 (sportcut-highlight)
  ├─ FFmpeg export                     (sportcut-export)
  └─ Single FFI facade                 (sportcut-api)

Local storage
  ├─ App-owned copy of the recording
  ├─ SQLite catalog (app)
  ├─ Match artifact directory (engine)
  └─ Model/runtime bytes (bundled or local, offline)
```

## Engine crates

| Crate | Responsibility |
| --- | --- |
| `sportcut-common` | Shared `SportcutError`, progress events, and `CancelToken`. |
| `sportcut-media` | Probe, proxy, analysis audio, frame sampling behind `MediaToolchain`; the import pipeline and regeneration of missing media. |
| `sportcut-storage` | Match artifact directory, manifest, calibration and rally-suggestion persistence. |
| `sportcut-jobs` | Job lifecycle, registry (one heavy job at a time), checkpoints, cancellation, resume. |
| `sportcut-court` | Calibration segments, homography / normalized court mapping, side assignment. |
| `sportcut-vision` | Decoded frames, TFLite person detection (feature `macos-tflite-eval`), on-court candidate classification, tracking. |
| `sportcut-rally` | Motion-first rally/rest segmentation from court-position tracks and coverage intervals, optional audio intensity. |
| `sportcut-score` | `serving_sides`: who served each rally, from the confirmed winners (winner of a rally serves the next). |
| `sportcut-highlight` | `rank`: deterministic highlight score (`0..1`) and 1-based rank per rally. |
| `sportcut-export` | Edit decision list and the FFmpeg renderer (`export/highlight.mp4`). |
| `sportcut-api` | FFI facade: DTOs, job handles, the player-tracking job, and the tracks artifact — the only surface across the bridge. |
| `sportcut-eval` | Pure scoring of player count and rally segmentation against hand labels (`verification/accuracy-evaluation.md`). Not shipped. |
| `sportcut-cli` | Headless harness (`core/cli`) to probe, proxy, sample, run the import pipeline, inspect or regenerate a match directory, and score accuracy (`eval`). Not shipped. |

Crate boundaries mirror the pipeline stages. Only `sportcut-api` crosses the
language boundary; internal crates are free to change because the bridge only
sees that facade.

### Facade surface (`core/crates/api/src/facade.rs`)

| Area | Calls |
| --- | --- |
| Media import | `media_import_stages`, `probe_media`, `start_import`, `start_regenerate_match_media`, `match_manifest` |
| Calibration | `court_geometry`, `save_match_calibration`, `match_calibration` |
| Tracking and rallies | `start_player_tracking`, `match_player_tracks`, `start_rally_segmentation`, `match_rally_suggestions` |
| Scoring and highlights | `serving_sides`, `rank_highlights` (pure calls: no files, no catalog) |
| Export | `export_highlight` |
| Jobs | `job_status`, `job_cancel` |

Long-running work (`start_*`, `export_highlight`) returns a job handle polled
through `job_status`; the registry admits one heavy job at a time.

## Client (`app/lib/src/`)

| Module | Responsibility |
| --- | --- |
| `app/` | App shell, theme, dependency injection, and the route table (`router.dart`). |
| `bridge/` | `sportcut_engine.dart` — the typed wrapper; the only way feature code reaches the engine. |
| `features/workspace` | Workspaces (home screen), `PipelineStage` state per video, and the three-pane studio. |
| `features/library` | Import, SQLite catalog (`match_catalog.dart`), recording store, match repository, playback. |
| `features/calibration` | Court corner/net marking over the video frame. |
| `features/analysis` | Preparing analysis media (proxy, audio, frames). |
| `features/tracking` | Running player tracking and reviewing count, tracks, and sides. |
| `features/rally` | Rally-suggestion review state (accept / adjust / dismiss). |
| `features/editing` | Domain and persistence for rallies, score events, highlight clips, and export settings. |
| `features/score` | Score confirmation screen and the serving-side indicator. |
| `features/highlights` | Ranked highlight candidates and "keep the best N". |
| `features/export` | Export settings, overlay rendering, music picker, and the export job. |

### Navigation

`/` is the workspace list. A workspace opens the **studio**: a left rail of the
workspace's videos, one shared video preview in the centre (the studio owns one
playback controller per selected video and hands it to the active feature), and
a right feature rail — **Play**, then **Analysis** (calibrate, analyze, track)
and **Studio** (score, highlight, export). Each rail item shows the stage state
(`done` / `ready` / `idle`) derived from the video's facts; `idle` is guidance,
not a gate.

Features not yet embedded in the studio open their full-screen route:
`/match/player`, `/match/calibration`, `/match/analysis`,
`/match/player-tracking`, `/match/score`, `/match/highlights`, `/match/export`
(each takes a `MatchRecord`).

## The two tracks

Work is split into an **engine track** (`core/`) and a **client track** (`app/`)
that meet at the bridge. The engine builds, lints, and tests on a machine with
no Flutter, Xcode, or JDK — it needs only the Rust toolchain and `ffmpeg`.

```bash
tools/preflight.sh --profile engine   # what the engine needs
tools/preflight.sh --profile macos    # what the macOS client needs

tools/verify-engine.sh                # cargo fmt --check, clippy, test
cd app && flutter analyze             # client static analysis

tools/generate-bridge.sh              # Dart bindings + Rust glue (not committed)
tools/build-engine-lib.sh             # engine library the app links against
tools/fetch-inference-assets.sh       # build-time TFLite runtime + model download
tools/run-macos.sh                    # dev run of the client on macOS
```

## The bridge

`flutter_rust_bridge` v2 is pinned to **2.13.0** in three places that must move
together: `core/crates/api/Cargo.toml`, `app/pubspec.yaml`, and
`tools/generate-bridge.sh`.

- Generated files are never hand-edited and never committed:
  `core/crates/api/src/frb_generated.rs` and `app/lib/src/bridge/generated/`.
- The codegen input is `crate::dto,crate::facade`; the committed module
  declaration is in `core/crates/api/src/lib.rs` behind the `bridge` feature.
- Hand-written typed Dart wrappers live in `app/lib/src/bridge/` next to — not
  inside — the generated directory. Feature code talks to the engine only
  through `app/lib/src/bridge/sportcut_engine.dart`.

## Analysis pipeline

1. **Import and normalize** — probe duration/rate/orientation/resolution/audio;
   copy the recording into the app-owned store; generate a low-resolution proxy
   and a low-bitrate analysis audio track. The original is never modified.
2. **Court calibration** — the user marks the four court corners and the net;
   the engine derives a normalized top-down court mapping, stored with the
   match and editable later.
3. **Person detection** — the TFLite detector locates people in sampled frames
   (offline); the court mapping keeps likely on-court players and rejects
   spectators.
4. **Player tracking** — detections are linked into timestamped tracks with
   explicit gaps, projected through calibration, and assigned a geometric court
   side (`First`/`Second`, unknown near the net).
5. **Rally segmentation** — active/inactive periods are proposed from the track
   input; the user accepts, adjusts, or dismisses each suggestion.
6. **Score confirmation** — the user confirms the winning side per rally; only a
   user-confirmed winner advances the score. `serving_sides` applies the
   rally-point rule (the previous rally's winner serves) and the score screen
   shows who serves; the first rally, or one after an unscored rally, has no
   server.
7. **Highlight ranking** — `rank_highlights` scores each rally as
   `0.40·duration + 0.30·motion + 0.30·score context`, clamped to `0..1`:
   duration is seconds/30 (capped at 1), motion is the accepted suggestion's
   quality (`rally.confidence`, `0.5` when hand-marked), and score context is
   `1 / (1 + |left − right|)` at that rally (`0` when unscored). Ties go to the
   earlier rally. The ranking is recomputed, not persisted; the user keeps,
   trims, reorders, or removes clips, or keeps the best N in one tap.
8. **Export** — selected clips are trimmed from the original, concatenated, and
   rendered with score overlays, a title card, and mixed music.

## Developer scripts (`tools/`)

| Script | Purpose |
| --- | --- |
| `preflight.sh` | Check the toolchain (presence, versions, license-affecting config); installs nothing. |
| `verify-engine.sh` | `cargo fmt --check`, clippy, and tests across `core/`. |
| `generate-bridge.sh` | Regenerate the bridge bindings (not committed). |
| `build-engine-lib.sh` | Build the engine library the app links against. |
| `embed-engine-lib.sh` | Copy the built engine library into a built macOS `.app`. |
| `fetch-inference-assets.sh` | Build-time download and checksum check of the TFLite runtime and model. |
| `embed-inference-assets.sh` | Copy the fetched inference assets into a built `.app`. |
| `run-macos.sh` | Dev run of the client on macOS. |

They are bash scripts that print diagnostics to stderr. The build scripts use
`set -euo pipefail` and resolve the repository root from `BASH_SOURCE`;
`preflight.sh` uses only `set -u` and reports every check, exiting `1` when a
required component is missing and `2` on a GPL toolchain under
`--strict-license`.
