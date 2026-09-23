# Dependency, Model, and Asset Register

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
| Shipped in | Which product artifact carries it (`engine`, `mobile-client`, `dev-only`, `none-yet`). |
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
| FFmpeg (Homebrew build) | toolchain | 8.1.1 | Homebrew Cellar, `/opt/homebrew/bin/ffmpeg` | GPL-3.0-or-later (built `--enable-gpl`) | not-shippable | dev-only | Built with `--enable-gpl --enable-libx264 --enable-libx265`. GPL components cannot be linked into a proprietary mobile build. Acceptable as a developer tool; `tools/preflight.sh` flags it. |
| FFmpeg (LGPL configuration) | toolchain | unresolved | To be built or obtained without GPL-only components | LGPL-2.1-or-later | unresolved | none-yet | Intended analysis-side probe/decode path. Must be verified GPL-free before it is used in a shipped target. |
| Rust toolchain (`rustc`, `cargo`) | toolchain | 1.97.1 | rustup | MIT OR Apache-2.0 | shippable | dev-only | Build tool; not distributed. |
| Flutter SDK / Dart | toolchain | unresolved | flutter.dev | BSD-3-Clause | unresolved | dev-only | Required for the mobile-client track; not yet installed. |
| Xcode / Android SDK / JDK | toolchain | unresolved | Apple / Google / OpenJDK vendor | platform vendor terms | unresolved | dev-only | Build tools; not distributed. |

### Engine (Rust)

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `serde` | library | 1.0.229 | crates.io | MIT OR Apache-2.0 | shippable | engine | Serialization for DTOs, manifest, and checkpoints. |
| `serde_json` | library | 1.0.151 | crates.io | MIT OR Apache-2.0 | shippable | engine | Manifest, checkpoint, and probe-output parsing. |
| `thiserror` | library | 2.0.20 | crates.io | MIT OR Apache-2.0 | shippable | engine | Derives the shared `SportcutError`. |
| `anyhow` | library | 1.0.104 | crates.io | MIT OR Apache-2.0 | shippable | engine | Error type at the facade boundary, where the client only needs a message. |
| `clap` | library | 4.6.7 | crates.io | MIT OR Apache-2.0 | shippable | engine (dev-only use) | Argument parsing for `sportcut-cli`; the binary is not shipped in the app. |
| `tempfile` | library | 3.27.0 | crates.io | MIT OR Apache-2.0 | shippable | dev-only | Test fixtures only. |
| `flutter_rust_bridge` | library | 2.13.0 (pinned, `=`) | crates.io | MIT | shippable | engine | Bridge runtime; version is pinned so regenerated bindings stay compatible. Pulls `tokio` 1.53.1, `futures`, `threadpool`, `log`, `portable-atomic`, `allo-isolate` (all MIT OR Apache-2.0). |
| `flutter_rust_bridge_codegen` | toolchain | 2.13.0 | crates.io (`cargo install`) | MIT | shippable | dev-only | Code generator. Not linked into the engine; reaches the app only through the Dart package below. |
| `ffmpeg` / `ffprobe` executables | toolchain | 8.1.1 (development build) | see the toolchain section above | GPL-3.0-or-later for this build | not-shippable | dev-only | The analysis path shells out to this toolchain today. A shipped target needs an LGPL-configured build or a platform-native replacement. |

All Rust dependencies resolve to permissive licenses (MIT, Apache-2.0, BSD,
ISC, or Unlicense). `cargo-deny`-style automated auditing is not wired up yet;
the register is maintained by hand for now, and every crate added to `core/`
must be recorded here. The full resolved set is `core/Cargo.lock`.

Every crate added to `core/` must be added here with its license and verdict. A
crate that is not listed is treated as unaudited.

### Mobile client

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Flutter framework | library | unresolved | flutter.dev | BSD-3-Clause | unresolved | mobile-client | Runtime is redistributed inside the app bundle; confirm the bundled license notice on first release. |
| SQLite (bundled by `sqflite`) | library | 2.4.4 (Dart package) | pub.dev / sqlite.org | Public domain (SQLite core) | shippable | mobile-client | The database engine ships inside the app; SQLite itself is public domain. |
| `sqflite` | library | 2.4.4 | pub.dev | BSD-2-Clause | shippable | mobile-client | The app owns the catalog; the engine never opens this database. |
| `sqflite_common_ffi` | library | 2.4.3 (dev-dependency) | pub.dev | MIT | shippable | dev-only | Runs the catalog tests against a real SQLite on the host; not shipped. |
| `flutter_rust_bridge` (Dart package) | library | 2.13.0 (pinned in `app/pubspec.yaml`) | pub.dev | MIT | shippable | mobile-client | Must match the Rust crate and generator versions; regenerating bindings with a different generator version is a contract change. |
| `flutter_lints` | library | ^4.0.0 (dev-dependency) | pub.dev | BSD-3-Clause | shippable | dev-only | Lint rules for the client; not shipped. |
| `flutter_riverpod` (with `riverpod` 3.4.3) | library | 3.4.3 | pub.dev | MIT | shippable | mobile-client | State management and dependency injection; the plan named Riverpod or Bloc, and this is the choice. |
| `path` / `path_provider` | library | 1.9.1 / 2.1.6 | pub.dev | BSD-3-Clause | shippable | mobile-client | Path joining and the platform documents directory for match artifacts. |
| `file_picker` | library | 13.1.0 | pub.dev | MIT | shippable | mobile-client | Choosing a recording from device storage. |
| `video_player` | library | 2.14.0 | pub.dev | BSD-3-Clause | shippable | mobile-client | Local playback; it wraps AVPlayer on iOS and ExoPlayer/Media3 on Android, which are the platform decode paths the licensing design prefers. |

### Media and codecs

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Apple AVFoundation / VideoToolbox | platform-api | system | iOS SDK | Apple platform terms | shippable | mobile-client | Preferred encode/export path on iOS; no GPL involvement. |
| Android MediaCodec / Media3 | platform-api | system | Android SDK | Apache-2.0 | shippable | mobile-client | Preferred encode/export path on Android. |
| MPEG-4 Part 2 encoder (`-c:v mpeg4`) | codec | bundled with ffmpeg | ffmpeg (built in) | LGPL-2.1-or-later (native ffmpeg encoder, no external library) | shippable | engine (analysis proxy only) | Chosen so a license-clean ffmpeg build can produce the analysis proxy without GPL encoders such as libx264. It is never used for the exported highlight video. |
| AAC encoder (`-c:a aac`) | codec | bundled with ffmpeg | ffmpeg (built in) | LGPL-2.1-or-later (native ffmpeg encoder) | shippable | engine (analysis audio only) | Native encoder, so the analysis audio path also avoids GPL components. |
| H.264 / AAC codecs | codec | n/a | Platform encoders | Patent licensing applies to the codec, separate from the software license | unresolved | mobile-client | Codec patent licensing (e.g. via MPEG LA pools) is a distribution question independent of the library license. Review before shipping a store build. |

### Inference runtime and models

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TensorFlow Lite | runtime | unresolved | tensorflow.org | Apache-2.0 | unresolved | none-yet | Intended default on-device runtime; not introduced in this change. |
| Person/pose model weights | model | none | not selected | n/a | unresolved | none-yet | No model ships yet. Weights carry their own license, separate from the runtime. Ultralytics YOLO weights are AGPL-3.0 and are excluded unless the project relicenses or buys a commercial license. |
| Training datasets | dataset | none | not selected | n/a | unresolved | none-yet | Any dataset used to produce shipped weights must be listed with its own terms. |

### Fonts, music, and other bundled assets

| Component | Kind | Version | Source | License | Distribution verdict | Shipped in | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Score overlay font | font | none | not selected | n/a | unresolved | none-yet | Must be licensed for redistributable embedding in an app binary. |
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
