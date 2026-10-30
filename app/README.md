# macOS Client

The Flutter client for macOS: match library, import, playback, and the typed
wrappers over the generated engine bridge. The project is scaffolded with
`flutter create --platforms=macos --org com.sportcut`.

## Structure

```
app/
  lib/
    main.dart                     startup: load the engine, inject it, run the shell
    src/
      app/                        shell: routing, theme, dependency injection
      bridge/
        protocol_client.dart      the Unix-socket transport and JSON-RPC framing
        models.dart               protocol model types
        sportcut_engine.dart      typed wrapper the app calls; owns the connection
      features/
        library/                  match list, import, playback
        calibration/              court calibration (later phase)
        analysis/                 analysis progress and review (later phase)
        score/                    score confirmation (later phase)
        highlights/               highlight review (later phase)
        export/                   export settings (later phase)
  macos/                         platform project
  test/                           widget and catalog tests, including test/screenshots/
  integration_test/               macOS-runtime screenshot automation
```

Each feature is a folder with `domain/`, `data/`, and `presentation/` as it needs
them, so a phase lands inside its own folder instead of spreading across the app.

## Running

The app needs the engine library and the generated bindings first:

```bash
cd app
flutter pub get
flutter run -d macos            # desktop run, with the service running
```

### Running on macOS

macOS is the shipping target; the debug runner is the fastest way to run and
review the app.

```bash
tools/run-service.sh          # terminal 1: start the engine service
tools/run-macos.sh            # terminal 2: flutter run -d macos
```

The client connects to the service over a Unix socket. Export
`SPORTCUT_ENDPOINT` and `SPORTCUT_STATE_ROOT` from what `run-service.sh`
prints, or pass the values with `--dart-define`.

Two things are specific to the macOS runner:

- **`Failed to foreground app; open returned 1` comes from `flutter run`, not
  from the app.** The tool launches the app binary itself, then calls `open` to
  bring it to the front. That call happens as soon as the tool attaches — which
  can be before the app has registered itself with LaunchServices — so `open`
  returns 1 and the tool logs it. The application is running normally, and macOS
  lists it as a foreground app a moment later; it simply may not come to the
  front, so switch to it with ⌘-Tab. Flutter's own source notes there is no
  reliable moment for the call. A second copy of the app already running
  produces the same line.
- **The debug runner is unsandboxed.** `macos/Runner/DebugProfile.entitlements`
  sets `com.apple.security.app-sandbox` to `false`. A sandboxed app cannot load
  the engine library from `core/adapters/api/target/release` (it fails with
  `file system sandbox blocked open()`), cannot read the recording the user
  picked, and cannot run the local `ffmpeg`. `Release.entitlements` keeps the
  sandbox on, since a shipped desktop build would need the engine bundled and
  the media toolchain resolved differently.
- **The service has to be running.** The client does not start it in this
  phase. `tools/run-service.sh` runs it in a separate process; the client fails
  at startup with an actionable message when no endpoint is configured.

## Verifying

```bash
cd app
flutter analyze
flutter test
```

`flutter test` includes `test/bridge_test.dart`, which loads the real engine
library and drives the facade, so the native boundary is exercised without a
device. Running the app itself still requires the platform toolchains:
`tools/preflight.sh --profile macos` reports what is missing.

### Screenshots

The screenshot suites render the real app and write PNGs. The same capture path
serves both runtimes: `IntegrationTestWidgetsFlutterBinding.takeScreenshot` is
not implemented on macOS, so the suites rasterise a `RepaintBoundary` with
`RenderRepaintBoundary.toImage` and save the PNG themselves.

```bash
cd app
flutter test test/screenshots                      # headless, writes PNGs to build/screenshots
flutter test integration_test -d macos              # real macOS runtime; requires a GUI session
cd ..
tools/capture-app-screenshots.sh                    # headless suite via the shared entry point
tools/capture-app-screenshots.sh --integration      # macOS runtime suite
tools/capture-app-screenshots.sh --output DIR       # choose where the PNGs land
```

The headless suite is sized with `tester.view`; the integration suite sizes the
live binding with `setSurfaceSize`, because that runner owns the surface. The
integration path needs a logged-in GUI/WindowServer session and is not headless.

Screenshots are build output and are gitignored (`app/build/`); never commit
them. The output directory defaults to `app/build/screenshots` and can be
overridden with `SPORTCUT_SCREENSHOT_DIR` (compile-time `--dart-define` or the
environment), which the capture script sets for you.

## Dependencies

Every package added to `pubspec.yaml` gets a row in the licensing register in
[`docs/brd/00-product-context.md`](../docs/brd/00-product-context.md) before the
change that introduces it is complete. The app has no Rust dependency: it talks
to the engine over the service protocol, so a change to the wire contract is a
change to `docs/architecture/protocol.md` and to `protocol_client.dart`.
