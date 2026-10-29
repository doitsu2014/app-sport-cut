# macOS — install and run

Sportcut ships on macOS only. This folder is the whole macOS story: what to
install, how to run each piece from a checkout, how to package a signed app, and
what to do when something fails.

## Pick your path

| I want to… | Start here |
| --- | --- |
| Check whether this machine can build Sportcut | [prerequisites.md](prerequisites.md) |
| Build and test the engine, and run the background service | [engine-and-service.md](engine-and-service.md) |
| Run the Flutter desktop client | [desktop-app.md](desktop-app.md) |
| Produce a signed `.app` with the service and models embedded | [packaging.md](packaging.md) |
| Fix a failed build or launch | [troubleshooting.md](troubleshooting.md) |

## Quick start

From the repository root, on a clean macOS machine:

```bash
tools/preflight.sh --profile macos     # what is missing, with a fix for each
tools/verify-engine.sh                 # format, lint, layering, tests
tools/build-service.sh                 # core/target/release/sportcut-service
tools/run-service.sh                   # dev service on a temporary state root
```

To run the client instead of the service:

```bash
tools/generate-bridge.sh               # Dart bindings + Rust glue
tools/run-macos.sh                     # engine library, then flutter run -d macos
```

## Prerequisites, in one table

| Component | Version | Why | Install |
| --- | --- | --- | --- |
| Xcode | current | macOS client and codesigning | App Store, then `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` |
| Rust | 1.80 or newer | the engine | [rustup.rs](https://rustup.rs) |
| Flutter SDK | Dart 3 | the client | `brew install --cask flutter`, or [flutter.dev](https://docs.flutter.dev/get-started/install) |
| ffmpeg + ffprobe | an LGPL build | media pipeline, at runtime | `brew install ffmpeg` |
| jq | any | `tools/check-layering.sh` | `brew install jq` |
| python3 | 3.8 or newer | regenerating the layer diagram | ships with Xcode CLT |

`tools/preflight.sh` reports every missing component in one run instead of
failing one at a time. Use `--profile engine` if you only intend to work on the
Rust engine; it does not require Flutter or Xcode.

## Two things that bite every first-time setup

- **ffmpeg licensing.** A GPL build flags as a licensing problem:
  `tools/preflight.sh --strict-license` fails on it. GPL FFmpeg is not
  shippable. It is fine for local development; it is not fine in a release.
- **Flutter not on `PATH`.** Set `SPORTCUT_FLUTTER_BIN` to the directory that
  contains the `flutter` executable. Every client-track script honours it.

Both are covered in more detail in [prerequisites.md](prerequisites.md).
