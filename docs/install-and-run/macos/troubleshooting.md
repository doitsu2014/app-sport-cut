# macOS — troubleshooting

Start here:

```bash
tools/preflight.sh --profile macos
```

It reports every missing component at once, with the command that fixes each.
Most of what follows is either a preflight finding or a known macOS behaviour.

## Symptoms

### `Failed to foreground app; open returned 1`

**Not an error.** `flutter run` launches the app binary, then calls `open` to
bring it forward. That call can race LaunchServices, so `open` returns 1. The
app is running; switch to it with ⌘-Tab. A second copy already running produces
the same line.

### The app launches but the engine fails to load (`file system sandbox blocked open()`)

The debug runner must be unsandboxed. `app/macos/Runner/DebugProfile.entitlements`
sets `com.apple.security.app-sandbox` to `false`; that is deliberate — a
sandboxed debug build cannot open the engine library from the build directory,
read the recording the user picked, or run the local `ffmpeg`.

Check that you are running the Debug configuration. Do not enable the sandbox to
"fix" a debug run; the release configuration is where the sandbox belongs.

### `embed-engine-lib: engine library is not built`

```bash
tools/build-engine-lib.sh
```

Then re-run the embed step. The library is
`core/adapters/api/target/release/libsportcut_api.dylib`.

### `generate-bridge: flutter_rust_bridge_codegen is not installed`

The script prints the exact pinned install line. Use it, and keep the version in
step with `core/adapters/api/Cargo.toml` and `app/pubspec.yaml`.

### `generate-bridge: dart is not on PATH`

Install the Flutter SDK, which bundles Dart, or put `<flutter>/bin` on `PATH`.
The generator formats the Dart it emits, so the bare Rust generator is not
enough.

### `check-layering: jq is not on PATH`

```bash
brew install jq
```

The check reads `cargo metadata` through `jq`. `cargo build` and the test suite
do not need it.

### `run-service: endpoint is N bytes, over the 103-byte AF_UNIX limit`

The state root's path is too long. macOS limits `sun_path` to 104 bytes
including the terminating NUL. Use a shorter `--state-root`:

```bash
tools/run-service.sh --state-root /tmp/sportcut
```

### `toolchain_unavailable` — ffmpeg or ffprobe

Both binaries are required. Install them together, or point the engine at a
specific pair:

```bash
export SPORTCUT_FFMPEG=/usr/local/bin/ffmpeg
export SPORTCUT_FFPROBE=/usr/local/bin/ffprobe
```

The service accepts `--ffmpeg` and `--ffprobe` instead.

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

### `job_rejected`

One heavy job runs at a time. Wait for the running job to reach a terminal state,
or cancel it, before starting another.

### `job_not_found` after a pause

The service exits on idle, and a restarted service does not know jobs from the
previous process. Reconnect, re-run `service.hello`, and re-start the work; the
checkpoint file lets an import resume instead of restarting.

### The socket is already in use, or a second service will not start

Only one service may own an endpoint. Either an earlier service is still running,
or a stale socket file is left in the state root. Stop the running process first;
the service takes an exclusive lock on startup and refuses to double-bind.

### `cargo build` fails on the toolchain version

The workspace requires Rust 1.80 or newer.

```bash
rustup update
```

### Media tests fail without ffmpeg

The media tests generate their own fixtures with `ffmpeg`. Install it, or run the
subset of the suite that does not need it — but do not treat a media test as
passing when it never ran.

### Flutter tooling is ignored by the scripts

Set the SDK location explicitly:

```bash
export SPORTCUT_FLUTTER_BIN="$HOME/development/flutter/bin"
```

Every client-track script honours it, and `preflight.sh` checks it first.

## When the report and the machine disagree

If `tools/preflight.sh` passes but a build fails, the failure is a build error,
not a setup error. Read the failing command's own output; the tooling reports the
command it ran, and the engine builds with only Rust and ffmpeg.
