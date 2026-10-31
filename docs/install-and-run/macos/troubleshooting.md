# macOS — troubleshooting

Start here:

```bash
tools/preflight.sh --profile macos
```

It reports every missing component at once, with the command that fixes each.
Most of what follows is either a preflight finding or a known macOS behaviour.

## Development runs (`tools/run-service.sh` + `tools/run-macos.sh`)

### `Failed to foreground app; open returned 1`

Not an error. `flutter run` launches the app binary, then calls `open` to bring
it forward. That call can race LaunchServices, so `open` returns 1. The app is
running; switch to it with ⌘-Tab. A second copy already running produces the
same line.

### The app launches but cannot reach the service

Check both sides use the **same** state root:

```bash
# terminal 1
tools/run-service.sh --state-root /tmp/sportcut
# terminal 2
SPORTCUT_STATE_ROOT=/tmp/sportcut tools/run-macos.sh
```

The app resolves `<root>/run/s.sock` and `<root>/run/token`. If you set
`SPORTCUT_ENDPOINT`, use it with `SPORTCUT_TOKEN` or `SPORTCUT_TOKEN_FILE`.

### `run-service: endpoint is N bytes, over the 103-byte AF_UNIX limit`

The state root's path is too long. macOS limits `sun_path` to 104 bytes
including the terminating NUL. Use a shorter root:

```bash
tools/run-service.sh --state-root /tmp/sportcut
```

### The socket is already in use, or a second service will not start

Only one service may own an endpoint. Either an earlier service is still
running, or a stale socket file is left in the state root. Stop the running
process first; the service takes an exclusive lock on startup.

### The debug app is blocked by the sandbox

The debug runner must be unsandboxed. `app/macos/Runner/DebugProfile.entitlements`
sets `com.apple.security.app-sandbox` to `false`; a sandboxed debug build cannot
open the service socket outside the container or read the recordings the service
owns. Do not enable the sandbox to “fix” a debug run.

### macOS asks for Documents or OneDrive access in development

The development catalog uses `getDatabasesPath()/sportcut.db`, which can resolve
under Documents (including a synced folder). Allow the prompt, or point the app
at a local state root; the packaged build avoids this by keeping the catalog in
Application Support.

## Packaged app (`tools/package-macos.sh`)

### The release build fails on Xcode modules

Symptoms include:

```
Could not build module 'Darwin'
cannot open .../MacOSX27.0.sdk/usr/include/mach/exception.h
```

A stale module cache can name an SDK path that has moved (for example 27.0 →
27.2). Clear the shared caches and rebuild:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/{ModuleCache.noindex,CompilationCache.noindex,Runner-*}
cd app && flutter clean && flutter build macos --release
```

The debug build is often unaffected because it reuses already-built plugins.

### `package-macos: expected service at …`

`tools/build-service.sh` did not produce `core/target/release/sportcut-service`.
Read its output; a missing Rust toolchain or a compile error stops packaging
before the app is built.

### The app opens but reports the service did not start

The supervisor prints the log path; read it:

```bash
cat "$HOME/Library/Application Support/com.sportcut.sportcut/state/logs/service.log"
```

Common causes:

- the helper is missing from `Contents/Helpers/SportcutService` (reinstall, or
  rebuild with `tools/package-macos.sh`);
- the state root is not writable;
- the socket path is over the 103-byte limit (unlikely with the packaged root);
- the helper exited immediately (the app reports the exit code).

### “sportcut.app wants to access files managed by OneDrive”

That is an older build whose catalog lived under Documents. The current build
keeps the catalog in Application Support and does not prompt. Allow it once or
rebuild with `tools/package-macos.sh`.

### Gatekeeper refuses the ad-hoc build

Opening the DMG and double-clicking an ad-hoc-signed app can be refused. Use
right-click → **Open** once, or build with a real identity:

```bash
CODESIGN_IDENTITY="Developer ID Application: …" tools/package-macos.sh
```

### `matchDir is only accepted in development builds`

A release service rejects a client-supplied `matchDir`. The current release
client omits it and resolves matches under `<state-root>/matches/<id>`. If you
are driving the socket by hand, send `matchId` only.

### The installed app shows an empty library

The packaged catalog is separate from the development one (Application Support
versus the development sqflite location). Re-import in the installed app, or
copy data deliberately; the packaged build does not migrate a development
library.

## Engine and media

### `toolchain_unavailable` — ffmpeg or ffprobe

Both binaries are required. Install them together, or point the engine at a
specific pair:

```bash
export SPORTCUT_FFMPEG=/usr/local/bin/ffmpeg
export SPORTCUT_FFPROBE=/usr/local/bin/ffprobe
```

The service accepts `--ffmpeg` and `--ffprobe` instead. The packaged app passes
`/opt/homebrew/bin` or `/usr/local/bin` when present.

### Player tracking reports unsupported

Check `service.health` first — it reports whether inference is *usable*, not
whether a file exists. The two causes:

- the service was built without the runtime feature: rebuild without
  `SPORTCUT_MACOS_TFLITE_EVAL=0`;
- the runtime or model is missing, or the model fingerprint does not match the
  supported one: fetch and embed the assets
  (`tools/fetch-inference-assets.sh`), or set `SPORTCUT_TFLITE_LIBRARY` and
  `SPORTCUT_PERSON_MODEL`.

The service ignores client-supplied inference paths by design; sending
`runtimePath` or `modelPath` is rejected.

### “Analyze rallies” says player tracks are unavailable

Rally analysis needs player tracking. Run, in order:

1. **Prepare analysis** — proxy, audio, frames.
2. **Player analysis** — `tracks/player_tracks.json`.
3. **Review & score** — rally suggestions.

The engine message is literal: `player tracks are unavailable; run player
tracking before rally analysis`.

### `job_rejected`

One heavy job runs at a time. Wait for the running job to reach a terminal state,
or cancel it, before starting another.

### `job_not_found` after a pause

The service exits on idle, and a restarted service does not know jobs from the
previous process. Reconnect, re-run `service.hello`, and re-start the work; the
checkpoint file lets an import resume instead of restarting.

### Media tests fail without ffmpeg

The media tests generate their own fixtures with `ffmpeg`. Install it, or run the
subset of the suite that does not need it — but do not treat a media test as
passing when it never ran.

## Tooling

### `check-layering: jq is not on PATH`

```bash
brew install jq
```

The check reads `cargo metadata` through `jq`. `cargo build` and the test suite
do not need it.

### Flutter tooling is ignored by the scripts

Set the SDK location explicitly:

```bash
export SPORTCUT_FLUTTER_BIN="$HOME/development/flutter/bin"
```

Every client-track script honours it, and `preflight.sh` checks it first.

### `cargo build` fails on the toolchain version

The workspace requires Rust 1.80 or newer.

```bash
rustup update
```

## When the report and the machine disagree

If `tools/preflight.sh` passes but a build fails, the failure is a build error,
not a setup error. Read the failing command's own output; the tooling reports the
command it ran, and the engine builds with only Rust and ffmpeg.
