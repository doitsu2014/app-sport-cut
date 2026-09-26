# External Dependencies — Definition

Every third-party dependency, machine-learning model, pretrained weight
file, training dataset, font, audio asset, and video codec that Sportcut uses
or distributes, recorded with its source, version, license, and distribution
verdict.

This is a **gating document**: a component may not ship in a release build
unless its verdict is `shippable`. Every new dependency or asset gets a row
here before the change that introduces it is complete.

---

This register records every third-party dependency, machine-learning model,
pretrained weight file, training dataset, font, audio asset, and video codec
that Sportcut uses or distributes. It is a gating document: a component with an
unresolved or negative distribution verdict may not ship in a release build.

Required by the `project-bootstrap` capability
(`openspec/changes/bootstrap-project-base/specs/project-bootstrap/spec.md`).

## Register schema

| Column | Meaning |
| --- | --- |
| Component | Name of the dependency, model, asset, or codec. |
| Kind | One of `library`, `runtime`, `toolchain`, `model`, `dataset`, `font`, `audio`, `codec`, `platform-api`. |
| Version | Pinned version, or `unresolved` when the choice is not made yet. |
| Source | Where it comes from (package, vendor, URL, or bundled path). |
| License | SPDX identifier where possible; otherwise the license name. |
| Distribution verdict | `shippable`, `not-shippable`, or `unresolved`. Only `shippable` may ship. |
| Shipped in | Which product artifact carries it (`engine`, `macos-client`, `dev-only`, `none-yet`). |
| Notes | Specific conflict, obligation, or review requirement. |

### Rules

1. A new dependency, model, or bundled asset gets an entry **before** the change
   that introduces it is complete.
2. A component whose license prevents proprietary distribution is recorded as
   `not-shippable` with the specific conflict named in `Notes`.
3. A release build requires `shippable` for every component that ships; any
   `unresolved` verdict blocks the release.
4. Codecs, fonts, music, and model weights are reviewed separately. An
   open-source library does not make every asset it carries safe to
   redistribute.

## Register

### Toolchain (development only, not distributed)

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FFmpeg (Homebrew build) | toolchain | 8.1.1 | Homebrew Cellar, `/opt/homebrew/bin/ffmpeg` | GPL-3.0-or-later (built `--enable-gpl`) | not-shippable | dev-only | Built with `--enable-gpl --enable-libx264 --enable-libx265`. GPL components cannot be linked into a proprietary macOS build. Acceptable as a developer tool; `tools/preflight.sh` flags it. |
| FFmpeg (LGPL configuration) | toolchain | unresolved | To be built or obtained without GPL-only components | LGPL-2.1-or-later | unresolved | none-yet | Intended analysis-side probe/decode path. Must be verified GPL-free before it is used in a shipped target. |
| Rust toolchain (`rustc`, `cargo`) | toolchain | 1.97.1 | rustup | MIT OR Apache-2.0 | shippable | dev-only | Build tool; not distributed. |
| Flutter SDK / Dart | toolchain | unresolved | flutter.dev | BSD-3-Clause | unresolved | dev-only | Required for the client track; not yet installed. |
| Xcode | toolchain | unresolved | Apple | platform vendor terms | unresolved | dev-only | Build tools; not distributed. |

### Engine (Rust)

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `serde` | library | 1.0.229 | crates.io | MIT OR Apache-2.0 | shippable | engine | Serialization for DTOs, manifest, and checkpoints. |
| `serde_json` | library | 1.0.151 | crates.io | MIT OR Apache-2.0 | shippable | engine | Manifest, checkpoint, and probe-output parsing. |
| `image` (JPEG-only build) | library | 0.24.9 (pinned, `=`) | crates.io | MIT OR Apache-2.0 | shippable | engine | Decodes locally sampled JPEG frames into RGB8 for person inference. Default codecs are disabled. Rust MSRV 1.63. |
| `tflite-c-rs` | library | 0.0.1 (pinned, `=`, optional) | crates.io | MIT OR Apache-2.0 | unresolved | macOS evaluation feature | Safe API over a dynamically loaded TFLite C library; requires API and packaging review before shipping. The default engine build does not enable it. |
| `libloading` | library | 0.8.9 | crates.io (`tflite-c-rs` transitive) | ISC | shippable | macOS evaluation feature | Loads the local TFLite C runtime; no download at runtime. |
| `thiserror` / `thiserror-impl` 1.x | library | 1.0.69 | crates.io (`tflite-c-rs` transitive) | MIT OR Apache-2.0 | shippable | macOS evaluation feature | Error definitions for the optional inference wrapper; separate from workspace `thiserror` 2.x. |
| `bytemuck` | library | 1.25.2 | crates.io (`image` transitive) | Zlib OR Apache-2.0 OR MIT | shippable | engine | Pixel-buffer conversion used by the JPEG-only `image` build. |
| `byteorder` | library | 1.5.0 | crates.io (`image` transitive) | Unlicense OR MIT | shippable | engine | Byte-order helpers used by `image`. |
| `color_quant` | library | 1.1.0 | crates.io (`image` transitive) | MIT | shippable | engine | Color helper pulled by `image` with default features disabled. |
| `jpeg-decoder` | library | 0.3.2 | crates.io (`image` transitive) | MIT OR Apache-2.0 | shippable | engine | Pure-Rust JPEG decoding for sampled analysis frames. |
| `num-traits` | library | 0.2.19 | crates.io (`image` transitive) | MIT OR Apache-2.0 | shippable | engine | Numeric helpers used by `image`. |
| `autocfg` | library | 1.5.1 | crates.io (`num-traits` build dependency) | Apache-2.0 OR MIT | shippable | build-time | Build helper; not bundled in the app. |
| `thiserror` | library | 2.0.20 | crates.io | MIT OR Apache-2.0 | shippable | engine | Derives the shared `SportcutError`. |
| `anyhow` | library | 1.0.104 | crates.io | MIT OR Apache-2.0 | shippable | engine | Error type at the facade boundary, where the client only needs a message. |
| `clap` | library | 4.6.7 | crates.io | MIT OR Apache-2.0 | shippable | engine (dev-only use) | Argument parsing for `sportcut-cli`; the binary is not shipped in the app. |
| `tempfile` | library | 3.27.0 | crates.io | MIT OR Apache-2.0 | shippable | dev-only | Test fixtures only. |
| `flutter_rust_bridge` | library | 2.13.0 (pinned, `=`) | crates.io | MIT | shippable | engine | Bridge runtime; version is pinned so regenerated bindings stay compatible. Pulls `tokio` 1.53.1, `futures`, `threadpool`, `log`, `portable-atomic`, `allo-isolate` (all MIT OR Apache-2.0). |
| `flutter_rust_bridge_codegen` | toolchain | 2.13.0 | crates.io (`cargo install`) | MIT | shippable | dev-only | Code generator. Not linked into the engine; reaches the app only through the Dart package below. |
| `ffmpeg` / `ffprobe` executables | toolchain | 8.1.1 (development build) | see the toolchain section above | GPL-3.0-or-later for this build | not-shippable | dev-only | The analysis path shells out to this toolchain, and so does the highlight renderer added by `add-manual-editing-and-export`, which also selects `mpeg4` and `aac` — both built into ffmpeg — so nothing here needs a GPL encoder. A shipped target needs an LGPL-configured build or a platform-native renderer; |

All Rust dependencies resolve to permissive licenses (MIT, Apache-2.0, BSD,
ISC, or Unlicense). `cargo-deny`-style automated auditing is not wired up yet;
the register is maintained by hand for now, and every crate added to `core/`
must be recorded here. The full resolved set is `core/Cargo.lock`.

Every crate added to `core/` must be added here with its license and verdict. A
crate that is not listed is treated as unaudited.

### macOS client

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Flutter framework | library | unresolved | flutter.dev | BSD-3-Clause | unresolved | macos-client | Runtime is redistributed inside the app bundle; confirm the bundled license notice on first release. |
| SQLite (bundled by `sqflite`) | library | 2.4.4 (Dart package) | pub.dev / sqlite.org | Public domain (SQLite core) | shippable | macos-client | The database engine ships inside the app; SQLite itself is public domain. |
| `sqflite` | library | 2.4.4 | pub.dev | BSD-2-Clause | shippable | macos-client | The app owns the catalog; the engine never opens this database. |
| `sqflite_common_ffi` | library | 2.4.3 (dev-dependency) | pub.dev | MIT | shippable | dev-only | Runs the catalog tests against a real SQLite on the host; not shipped. |
| `flutter_rust_bridge` (Dart package) | library | 2.13.0 (pinned in `app/pubspec.yaml`) | pub.dev | MIT | shippable | macos-client | Must match the Rust crate and generator versions; regenerating bindings with a different generator version is a contract change. |
| `flutter_lints` | library | ^4.0.0 (dev-dependency) | pub.dev | BSD-3-Clause | shippable | dev-only | Lint rules for the client; not shipped. |
| `flutter_riverpod` (with `riverpod` 3.4.3) | library | 3.4.3 | pub.dev | MIT | shippable | macos-client | State management and dependency injection; the plan named Riverpod or Bloc, and this is the choice. |
| `share_plus` | library | 13.3.0 | pub.dev | BSD-3-Clause | shippable | macos-client | Hands the finished highlight video to the platform's save and share sheet. Introduced by `add-manual-editing-and-export`. |
| `share_plus_platform_interface` | library | 7.2.0 | pub.dev | BSD-3-Clause | shippable | macos-client | Platform interface for `share_plus`, pulled in by it. |
| `mime` | library | 2.1.0 | pub.dev | BSD-3-Clause | shippable | macos-client | MIME-type lookup used by `share_plus` when handing a file to the platform. |
| `url_launcher_platform_interface` | library | 2.3.2 | pub.dev | BSD-3-Clause | shippable | macos-client | Pulled in by `share_plus`; unused on the macOS target. |
| `url_launcher_linux`, `url_launcher_web`, `url_launcher_windows` | library | 3.2.3 / 2.4.3 / 3.1.6 | pub.dev | BSD-3-Clause | shippable | macos-client | Transitive companions of `share_plus` for desktop and web; they ship as unused code on macOS. |
| `path` / `path_provider` | library | 1.9.1 / 2.1.6 | pub.dev | BSD-3-Clause | shippable | macos-client | Path joining and the platform documents directory for match artifacts. |
| `file_picker` | library | 13.1.0 | pub.dev | MIT | shippable | macos-client | Choosing a recording from device storage. |
| `video_player` | library | 2.14.0 | pub.dev | BSD-3-Clause | shippable | macos-client | Local playback; it wraps AVPlayer on macOS, which is the platform decode path the licensing design prefers. |

### Media and codecs

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Apple AVFoundation / VideoToolbox | platform-api | system | macOS SDK | Apple platform terms | shippable | macos-client | Preferred encode/export path on macOS; no GPL involvement. |
| MPEG-4 Part 2 encoder (`-c:v mpeg4`) | codec | bundled with ffmpeg | ffmpeg (built in) | LGPL-2.1-or-later (native ffmpeg encoder, no external library) | shippable | engine (analysis proxy only) | Chosen so a license-clean ffmpeg build can produce the analysis proxy without GPL encoders such as libx264. It is never used for the exported highlight video. |
| AAC encoder (`-c:a aac`) | codec | bundled with ffmpeg | ffmpeg (built in) | LGPL-2.1-or-later (native ffmpeg encoder) | shippable | engine (analysis audio only) | Native encoder, so the analysis audio path also avoids GPL components. |
| H.264 / AAC codecs | codec | n/a | Platform encoders | Patent licensing applies to the codec, separate from the software license | unresolved | macos-client | Codec patent licensing (e.g. via MPEG LA pools) is a distribution question independent of the library license. Review before shipping a store build. |

### Inference runtime and models

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TensorFlow Lite C runtime, EdgeFirst macOS build | runtime | 2.19.0 | [EdgeFirstAI release](https://github.com/EdgeFirstAI/tflite-rs/releases/tag/tflite-v2.19.0) | Apache-2.0 | shippable | macos-client | Redistribute with the Apache-2.0 notice. Downloaded archive SHA-256 `1de9594d626f2a8c6500739acd0691d46f920f295ba1daf95c02adcccf73ad33`, extracted dylib SHA-256 `bd96fa2035fe06f52941e598e7281d1d59e84a4a1d63912698a5093b516c7d6a`. No build-time or product-time download is enabled. |
| EfficientDet-Lite0 Task Library int8 weights | model | 1 | [Google model file](https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/object_detection/rpi/lite-model_efficientdet_lite0_detection_metadata_1.tflite) | Apache-2.0 (Google) | shippable | macos-client | Redistribute with the Apache-2.0 notice. SHA-256 `2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b`; unlike the MediaPipe download, exposes the four `DetectionPostProcess` outputs. |
| COCO 2017 training images/annotations | dataset | provenance for EfficientDet-Lite0 candidate | [COCO dataset](https://cocodataset.org/) | CC-BY + individual image terms (varies) | not-shippable | none-yet | Training-data provenance only; no dataset bytes are bundled or distributed. The underlying images carry varied, sometimes non-commercial terms, so the dataset itself may not ship. |
| Person/pose model weights | model | none selected for distribution | not selected | n/a | unresolved | none-yet | No model ships yet. Weights carry their own license, separate from the runtime. Ultralytics YOLO weights are AGPL-3.0 and are excluded unless the project relicenses or buys a commercial license. |

### Fonts, music, and other bundled assets

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Score overlay font | font | none | not bundled | n/a | shippable | none | Not bundled and not distributed. The scoreboard and title card are drawn by the application at runtime with the platform's own font, then handed to the renderer as an image, so nothing is redistributed. See `add-manual-editing-and-export`. |
| Background music tracks | audio | none | not selected | n/a | unresolved | none-yet | Export music is bundled or user-provided; either way the redistribution terms are recorded here. |
| Brand assets (icon, logo) | asset | none | project-owned | project copyright | unresolved | none-yet | Project-owned; confirm any third-party components used to produce them. |

## Review gate

Before a release build:

1. Every component that ships has a `shippable` verdict.
2. No shipped component has an `unresolved` verdict.
3. Any `not-shippable` component is either excluded from the shipped artifact
   or replaced.

The preflight check (`tools/preflight.sh`) covers the one case that can be
detected automatically today: a GPL-configured media toolchain on the build
machine.
