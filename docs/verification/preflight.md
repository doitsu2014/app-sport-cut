# Preflight verification

Evidence for task 2.5 of the `bootstrap-project-base` change: the preflight
check was run against the current development machine, and it reports the
missing mobile toolchain components together in a single run instead of
stopping at the first one.

## Commands

```bash
tools/preflight.sh --profile engine            # exit 0
tools/preflight.sh --profile all               # exit 1, five components missing
tools/preflight.sh --profile engine --strict-license   # exit 2, GPL media build
```

## Engine profile

Confirms the engine track is buildable here: Rust, cargo, and the media
toolchain are all detected with versions, and the media toolchain's
license-affecting configuration is reported and flagged.

```text
Sportcut developer environment preflight (profile: engine)
Host: Darwin 25.6.0 (arm64)
------------------------------------------------------------
  [ ok ]  Rust toolchain         rustc 1.97.1 (8bab26f4f 2026-07-14)
  [ ok ]  Cargo                  cargo 1.97.1 (c980f4866 2026-06-30)
  [ ok ]  Media toolchain        ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
          ffprobe version 8.1.1 Copyright (c) 2007-2026 the FFmpeg developers
          ffmpeg: /opt/homebrew/bin/ffmpeg
          ffprobe: /opt/homebrew/bin/ffprobe
          license-affecting configuration:
            --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  [warn]  Media licensing        GPL components detected: --enable-gpl --enable-libx264 --enable-libx265
          conflict: GPL components cannot be linked into a proprietary mobile distribution.
          remediation: use this build for local development only; ship with platform-native media APIs (AVFoundation/VideoToolbox, MediaCodec/Media3) or an LGPL-configured FFmpeg with GPL-only parts disabled. See docs/legal/dependency-register.md.
------------------------------------------------------------
All required components are present.

Media toolchain licensing: the detected build configuration contains GPL components.
  Developer use: fine.
  Shipped target: blocked until the media path uses license-clean components
  (platform-native APIs or an LGPL-configured FFmpeg).
  Register entry: docs/legal/dependency-register.md

Preflight passed.
```

## All-components profile

Every missing component is reported together, each with a remediation step, and
the run exits non-zero (1). No build output is produced.

```text
  [miss]  Flutter SDK            not found
          remediation: install the Flutter SDK for your platform (macOS: brew install --cask flutter, or download from https://docs.flutter.dev/get-started/install) and put flutter on PATH
  [miss]  Dart                   not found
          remediation: install the Flutter SDK (which bundles Dart) or the standalone Dart SDK from https://dart.dev/get-dart
  [miss]  Xcode (full install)   active developer directory is /Library/Developer/CommandLineTools (Command Line Tools only)
          remediation: install Xcode from the App Store, then run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch
  [miss]  Android SDK            not found (checked ANDROID_HOME, ANDROID_SDK_ROOT, ~/Library/Android/sdk, adb)
          remediation: install Android Studio or the Android command-line tools, set ANDROID_HOME, and accept the SDK licenses
  [miss]  JDK                    java is on PATH but no Java runtime is installed (macOS stub)
          remediation: install a JDK 17 or newer (macOS: brew install --cask temurin; or use the JDK bundled with Android Studio) and set JAVA_HOME
------------------------------------------------------------
Missing components: 5
  - Flutter SDK
      install Flutter and add it to PATH: https://docs.flutter.dev/get-started/install
  - Dart
      install the Flutter SDK (bundles Dart) or the Dart SDK: https://dart.dev/get-dart
  - Xcode (full installation)
      install Xcode from the App Store, then: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  - Android SDK
      install Android Studio or the Android command-line tools, set ANDROID_HOME, accept the licenses
  - JDK
      install a JDK 17+ (brew install --cask temurin) and set JAVA_HOME

Preflight failed: 5 component(s) missing.
```

## Notes

- `java` is present on `PATH` as the macOS stub, which is why the JDK row
  reports "no Java runtime" rather than "not found": the check runs
  `java -version` instead of trusting the executable's existence.
- `xcodebuild` is present as a Command Line Tools shim; the check verifies the
  active developer directory points into a full `Xcode.app` before reporting
  success, so the CLT-only state is reported as missing.
- `--strict-license` turns the GPL media-toolchain warning into exit code 2 for
  a shipping-target check.
