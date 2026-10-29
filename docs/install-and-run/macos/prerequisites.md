# macOS prerequisites

Everything a macOS machine needs to build, test, and run Sportcut, and how to
check it. Nothing here installs automatically: `tools/preflight.sh` only reads
the machine and reports.

## Check before installing anything

```bash
tools/preflight.sh                     # everything
tools/preflight.sh --profile engine    # Rust engine only: no Flutter, no Xcode
tools/preflight.sh --profile macos     # the client: adds Flutter and Xcode
tools/preflight.sh --strict-license    # additionally fails on a GPL ffmpeg build
```

One run lists every missing component with its remediation step, and exits
non-zero if anything is missing. Run it again after installing rather than
retrying the build.

## Required

### Xcode

Needed for the client and for codesigning. Command-line tools alone are not
enough for `flutter build macos`.

```bash
xcode-select --install                  # command-line tools, if not already present
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Confirm with `xcodebuild -version`. The engine track does not need Xcode; use
`--profile engine` and you can skip this section entirely.

### Rust 1.80 or newer

The workspace sets `rust-version = "1.80"` and `edition = "2021"`.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Confirm with `rustc --version` and `cargo --version`.

### Flutter SDK (Dart 3)

Needed for the client only.

```bash
brew install --cask flutter
```

If Flutter is installed somewhere `PATH` does not reach, point the scripts at
it instead of editing your shell profile:

```bash
export SPORTCUT_FLUTTER_BIN="$HOME/development/flutter/bin"
```

`tools/preflight.sh` also looks at `FLUTTER_ROOT`, then `PATH`, then
`~/flutter/bin`, `~/development/flutter/bin`, and `~/fvm/default/bin`. Dart is
taken from the same directory, because the Flutter SDK bundles it.

### ffmpeg and ffprobe

Required at runtime by the media pipeline. Both are needed; one without the
other is reported as missing.

```bash
brew install ffmpeg
```

If you manage builds yourself, point the engine at a specific pair:

```bash
export SPORTCUT_FFMPEG=/usr/local/bin/ffmpeg
export SPORTCUT_FFPROBE=/usr/local/bin/ffprobe
```

The service accepts `--ffmpeg` and `--ffprobe` instead; `tools/run-service.sh`
passes the environment variables through when they are set.

#### Licensing

GPL FFmpeg is **not shippable**. Homebrew's default build is fine for local
development, and `tools/preflight.sh --strict-license` will fail on it so this
cannot be discovered at release time. A release needs an LGPL build. The
licensing register in
[`docs/brd/00-product-context.md`](../../brd/00-product-context.md) is the
authority on what may ship.

### jq

`tools/check-layering.sh` reads `cargo metadata` through `jq`.

```bash
brew install jq
```

Missing `jq` fails the layering check with an install instruction rather than a
confusing error. It is not needed for `cargo build` or the test suite.

### python3

Used only by `tools/generate-layering-diagram.sh`. macOS ships it with the
command-line tools.

## Optional

| Variable | Effect |
| --- | --- |
| `SPORTCUT_FLUTTER_BIN` | Directory containing `flutter`, for client-track scripts |
| `SPORTCUT_FFMPEG`, `SPORTCUT_FFPROBE` | Explicit media binaries |
| `SPORTCUT_TFLITE_LIBRARY` | Explicit TensorFlow Lite runtime, when not in the app bundle |
| `SPORTCUT_PERSON_MODEL` | Explicit person-detection model, when not in the app bundle |
| `SPORTCUT_INFERENCE_DIR` | Where `tools/fetch-inference-assets.sh` places assets (default `third_party/inference`) |
| `SPORTCUT_MACOS_TFLITE_EVAL` | `0` builds the service without the local macOS TFLite runtime |
| `CARGO_TARGET_DIR` | Share or relocate Cargo's target directory |
| `CODESIGN_IDENTITY` | Signing identity for `tools/embed-service.sh` |

## What each track actually needs

| Track | Rust | Flutter | Xcode | ffmpeg | jq |
| --- | --- | --- | --- | --- | --- |
| Engine (`cargo build`, `tools/verify-engine.sh`) | yes | no | no | for media tests | for layering |
| Background service | yes | no | no | yes, at runtime | — |
| Flutter client | yes | yes | yes | yes | — |
| Release packaging | yes | yes | yes | yes (LGPL) | — |

The engine track is deliberately buildable without the client toolchain. If a
change makes Flutter or Xcode necessary to build `core/`, that is a defect, not
a setup step.
