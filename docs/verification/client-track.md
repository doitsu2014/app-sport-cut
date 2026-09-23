# Mobile client track verification

Evidence for tasks 6.3–6.4 and section 8 of the `bootstrap-project-base`
change, gathered with Flutter 3.47.5 / Dart 3.13.4.

## Toolchain state

```bash
SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin tools/preflight.sh --profile mobile
```

```text
  [ ok ]  Flutter SDK            Flutter 3.47.5 • channel stable
  [ ok ]  Dart                   Dart SDK version: 3.13.4 (stable)
  [miss]  Xcode (full install)   active developer directory is /Library/Developer/CommandLineTools
  [miss]  Android SDK            not found (checked ANDROID_HOME, ANDROID_SDK_ROOT, ~/Library/Android/sdk, adb)
  [miss]  JDK                    java is on PATH but no Java runtime is installed (macOS stub)
```

Task 7.1 is therefore only part done: the Flutter SDK and Dart are installed and
verified, a full Xcode installation, the Android SDK, and a JDK are not. The
missing three are what blocks building or running the app itself (7.5 and 9.2).

## Bridge generation and the engine library

```bash
tools/generate-bridge.sh     # flutter_rust_bridge_codegen 2.13.0
tools/build-engine-lib.sh    # cargo build -p sportcut-api --features bridge --release
```

Generated artifacts (not committed):

```text
core/crates/api/src/frb_generated.rs
app/lib/src/bridge/generated/{dto,facade,frb_generated,frb_generated.io,frb_generated.web}.dart
core/crates/api/target/release/libsportcut_api.dylib
```

Two configuration details were needed to make this work:

- `rust_input: crate::dto,crate::facade` — the generator does not follow
  `pub use` re-exports, so scanning `crate::api` produced an empty binding set.
- `add_mod_to_lib: false` — the module declaration is committed in
  `core/crates/api/src/lib.rs` and gated behind the `bridge` feature, so an
  engine-only checkout still builds with no Dart toolchain installed. Verified
  by building the workspace with the generated file moved aside.

## Client verification commands

```bash
cd app
flutter analyze     # No issues found!
flutter test        # 38 tests, all passing
```

Test files and what they cover:

| File | Covers |
| --- | --- |
| `test/bridge_test.dart` | Loads the real engine library and drives the facade: import, no-audio source, missing-artifact reporting and regeneration, typed error mapping |
| `test/match_catalog_test.dart` | Schema for matches, rallies, score events, highlight clips; match survives reopen; versioned migration preserves rows; delete cascades |
| `test/match_repository_test.dart` | Import references the recording in place and populates metadata from the engine probe; missing file, unreadable codec, and denied-access failures leave no catalog record; artifact generation; deletion with and without artifacts |
| `test/library_screen_test.dart` | Empty state, list with title/duration/date, import, cancelled import, failed import, artifact preparation, delete dialog with the artifact question, navigation to playback |
| `test/player_screen_test.dart` | Load, play/pause through the controller, scrubbing, unplayable recording disables controls and explains why |
| `test/app_shell_test.dart` | Home route, every route builds, unknown route, missing route argument, Material 3 themes |
| `test/formatters_test.dart` | Duration, date, and position formatting |

`test/bridge_test.dart` is the runtime proof that the generated bridge actually
loads: it calls the same entry points the app calls, through the native library.

## Notes on test design

- Widget tests run in a fake-async zone, where real asynchronous filesystem or
  database work never completes. The screens therefore depend on the
  `MatchLibrary` and `PlaybackController` interfaces, and widget tests use
  in-memory doubles; the SQLite and filesystem behaviour is covered by the
  non-widget repository and catalog tests.
- Every fixture recording is generated with the local `ffmpeg` into a temporary
  directory. No media is committed.

## Not verified here

- 7.5 platform build integration: the Gradle and CocoaPods wiring that links the
  engine into the app, and a device/simulator launch. Requires Xcode and the
  Android SDK.
- 9.2 manual end-to-end flow on a device. The same flow is exercised automated
  by `test/bridge_test.dart` on the host, but import from device storage,
  playback through `video_player`, and the app UI on a real device are not
  covered until the toolchains exist.
