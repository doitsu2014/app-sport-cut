# macOS — install, run, and deploy

Sportcut is a macOS app plus a separately launched Rust service. There are two
deployment modes, and they use different commands and different data roots.

| I want to… | Mode | Start here |
| --- | --- | --- |
| Install Sportcut on a Mac from a DMG | **Production (personal build)** | [packaging.md](packaging.md) |
| Run the debug service and the Flutter app from a checkout | **Local development** | [desktop-app.md](desktop-app.md) |
| Check what this machine can build | — | [prerequisites.md](prerequisites.md) |
| Fix a failed build, launch, or import | — | [troubleshooting.md](troubleshooting.md) |
| Work on the Rust engine alone | — | [engine-and-service.md](engine-and-service.md) |

## Mode 1 — production: DMG to install

One command builds a release app with the service, model, and TFLite runtime
embedded, signs it, and writes a DMG:

```bash
tools/package-macos.sh
# → dist/Sportcut.dmg
```

Install by opening the DMG and dragging `sportcut.app` to **Applications**.
The packaged app starts its own helper on first launch:

- state and match directories: `~/Library/Application Support/com.sportcut.sportcut/state/`
- catalog: `~/Library/Application Support/com.sportcut.sportcut/sportcut.db`
- service log: `~/Library/Application Support/com.sportcut.sportcut/state/logs/service.log`
- `ffmpeg` / `ffprobe` are required at runtime and are discovered at
  `/opt/homebrew/bin`, `/usr/local/bin`, then `PATH`

This is a **personal build**: ad-hoc signed unless `CODESIGN_IDENTITY` is set,
unsandboxed, and using the ffmpeg installed on the Mac (a GPL build is fine
locally but is not shippable). Details and the distributable path:
[packaging.md](packaging.md).

## Mode 2 — local development: debug service + app

Two processes, two terminals:

```bash
# terminal 1 — the engine host
tools/run-service.sh --state-root /tmp/sportcut

# terminal 2 — the Flutter client
SPORTCUT_STATE_ROOT=/tmp/sportcut tools/run-macos.sh
```

The app reads the endpoint and token from `SPORTCUT_STATE_ROOT` (the layout
`run-service.sh` creates). `SPORTCUT_ENDPOINT` with `SPORTCUT_TOKEN` or
`SPORTCUT_TOKEN_FILE` also works. Details:
[desktop-app.md](desktop-app.md).

## What both modes share

- The client never links Rust and never opens a socket itself; it reaches the
  engine only through `app/lib/src/bridge/sportcut_engine.dart` over the
  Sportcut Service Protocol v1.
- A match directory holds `manifest.json`, `checkpoints.json`, `proxy/`,
  `audio/`, `frames/`, `calibration/`, `tracks/`, and `export/`.
- Import copies the picked recording. The file the user selected is never
  modified.
- Analysis order matters: **Prepare analysis** (proxy, audio, frames) →
  **Player analysis** (tracks) → **Review & score** (rally suggestions). “Analyze
  rallies” reports `player tracks are unavailable` until tracking has run.
- The product is offline. No cloud, no telemetry, no network calls.

## Prerequisites, in one table

| Component | Why | Install |
| --- | --- | --- |
| Xcode | macOS client, codesigning | App Store |
| Rust 1.80+ | the engine and service | [rustup.rs](https://rustup.rs) |
| Flutter SDK (Dart 3) | the client | `brew install --cask flutter` |
| ffmpeg + ffprobe | media pipeline, at runtime | `brew install ffmpeg` |
| jq | `tools/check-layering.sh` | `brew install jq` |

`tools/preflight.sh --profile macos` reports every missing component with its
fix. `--profile engine` skips Flutter and Xcode.

## Two things that bite first-time setups

- **ffmpeg licensing.** A GPL ffmpeg build is fine for local development and a
  personal DMG, but is not shippable. `tools/preflight.sh --strict-license`
  flags it.
- **Flutter not on `PATH`.** Set `SPORTCUT_FLUTTER_BIN` to the directory that
  contains `flutter`; every client-track script honours it.
