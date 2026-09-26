# Software Architecture

## What Sportcut is

Sportcut turns a badminton match recording into a polished highlight video,
entirely on the user's Mac: import a local recording, strip the downtime,
confirm the score in a few taps, pick the best rallies, and export an edited
video. Everything runs offline — recordings and analysis results never leave
the device, and no cloud or online-API dependency may be introduced.

The product is deliberately semi-automatic. The app proposes rally boundaries
and a suggested winner; the user confirms. It does not claim fully automatic
officiating, because shuttlecocks are small, fast, and often hidden.

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
  ├─ Video import and library
  ├─ Court calibration
  ├─ Video review player
  ├─ Player analysis (count, tracks, sides)
  ├─ Score confirmation
  ├─ Highlight editor
  └─ Export settings

Rust Engine (core/)
  ├─ Frame sampling and proxy          (sportcut-media)
  ├─ Court geometry / homography       (sportcut-court)
  ├─ Person detection and tracking     (sportcut-vision)
  ├─ Rally segmentation                (sportcut-rally)
  ├─ Score timeline                    (sportcut-score)
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
| `sportcut-common` | Shared error type, progress and cancellation primitives. |
| `sportcut-media` | Probe, proxy, analysis audio, frame sampling behind `MediaToolchain`. |
| `sportcut-storage` | Match artifact directory, manifest, checkpoint persistence. |
| `sportcut-jobs` | Job lifecycle, stage-labelled progress, cancellation, resume. |
| `sportcut-court` | Calibration segments, normalized court geometry, side assignment. |
| `sportcut-vision` | Decoded frames, person detection (`PersonDetector`), court candidates, tracking. |
| `sportcut-rally` | Rally segmentation and the `tracks/player_tracks.json` consumer. |
| `sportcut-score` | Score timeline. |
| `sportcut-highlight` | Highlight ranking. |
| `sportcut-export` | Edit decision list and the FFmpeg renderer. |
| `sportcut-api` | FFI facade: DTOs, job handles — the only surface across the bridge. |
| `sportcut-cli` | Headless harness for developing and benchmarking the pipeline. |

Crate boundaries mirror the pipeline stages. Only `sportcut-api` crosses the
language boundary; internal crates are free to change because the bridge only
sees that facade.

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
   input; boundaries stay user-editable.
6. **Score confirmation** — the app proposes a winning side per rally; only a
   user-confirmed winner advances the score.
7. **Highlight ranking** — rallies are scored by duration, movement, audio, and
   confirmed points; the user keeps, trims, reorders, or removes clips.
8. **Export** — selected clips are trimmed from the original, concatenated, and
   rendered with score overlays, a title card, and mixed music.

## Developer scripts (`tools/`)

`preflight.sh` (environment check, installs nothing), `verify-engine.sh`
(fmt/clippy/test), `generate-bridge.sh`, `build-engine-lib.sh`, and
`run-macos.sh` are the supported entry points. They are bash with
`set -euo pipefail`, resolve the repository root from `BASH_SOURCE`, and print
diagnostics to stderr.
