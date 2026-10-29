# macOS — run the desktop client

The Flutter client, on a workstation, from a checkout.

## Transport

The client talks to the engine over the Sportcut Service Protocol on a Unix
socket. There is no shared library, no generated binding, and no FFI: the engine
is a separate process. Start it first, then run the app with an endpoint.

```bash
tools/run-service.sh        # terminal 1
```

`run-service.sh` prints the endpoint and the token path. Export
`SPORTCUT_ENDPOINT` and `SPORTCUT_STATE_ROOT` (or pass
`--dart-define=SPORTCUT_ENDPOINT=...` and `--dart-define=SPORTCUT_TOKEN=...`)
before starting the app.

## Before you start

- [Prerequisites](prerequisites.md) satisfied: Xcode, Rust, Flutter, ffmpeg.
- `tools/preflight.sh --profile macos` passes.

## Run it

```bash
cd app
flutter pub get
flutter run -d macos
```

Or use the wrapper, which checks the endpoint is configured first:

```bash
tools/run-macos.sh
```

## Two macOS-specific behaviours

**The debug runner is unsandboxed.** `macos/Runner/DebugProfile.entitlements`
sets `com.apple.security.app-sandbox` to `false`. A sandboxed debug build cannot
reach the service socket outside the app container, and cannot read the
recordings the service owns. `Release.entitlements` keeps the sandbox on. Do not
"fix" the debug entitlement; it is what makes a checkout runnable.

**`Failed to foreground app; open returned 1`** is `flutter run`, not the app.
The tool launches the binary and then calls `open` to bring it forward, which
can race LaunchServices. The app is running; switch to it with ⌘-Tab. A second
running copy produces the same line.

## Verify without a device

```bash
cd app
flutter analyze
flutter test
```

`flutter test` includes `test/bridge_test.dart`, which loads the real engine
library and drives the facade, so the native boundary is exercised headlessly.
That requires the engine library to have been built first.

## Recording and artifacts

The app never modifies the file the user selected. Import takes custody by
copying the recording; the original is left alone. Derived media is written
outside the repository — never point an artifact root at the checkout.

## Where to go next

- Package a signed build: [packaging.md](packaging.md)
- Something failed: [troubleshooting.md](troubleshooting.md)
