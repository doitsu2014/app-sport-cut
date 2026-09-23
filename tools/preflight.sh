#!/usr/bin/env bash
#
# Sportcut developer environment preflight.
#
# Reports the presence, version, and license-affecting configuration of every
# toolchain component a build requires, lists every missing component together
# with a remediation step in a single run, and exits non-zero when something is
# missing.
#
# Usage:
#   tools/preflight.sh [--profile engine|mobile|all] [--strict-license]
#
# Flutter is located through, in order: SPORTCUT_FLUTTER_BIN (a directory
# containing the flutter executable), FLUTTER_ROOT, PATH, then the common
# install locations ~/flutter/bin, ~/development/flutter/bin and
# ~/fvm/default/bin. Dart is taken from the same directory, because the Flutter
# SDK bundles it.
#
# Profiles:
#   engine   components needed to build, lint, and test core/
#   mobile   components needed to build the Flutter client in app/
#   all      everything (default)
#
# Exit codes:
#   0  every component required by the profile is present
#   1  one or more required components are missing
#   2  --strict-license was given and the media toolchain has GPL components
#
# The script only reads from the machine: it installs nothing and writes no
# build output.

set -u

PROFILE="all"
STRICT_LICENSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      if [ $# -lt 2 ]; then
        echo "preflight: --profile requires a value (engine|mobile|all)" >&2
        exit 64
      fi
      PROFILE="$2"
      shift 2
      ;;
    --profile=*)
      PROFILE="${1#--profile=}"
      shift
      ;;
    --strict-license)
      STRICT_LICENSE=1
      shift
      ;;
    -h|--help)
      sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "preflight: unknown argument: $1" >&2
      echo "Try: tools/preflight.sh --help" >&2
      exit 64
      ;;
  esac
done

case "$PROFILE" in
  engine|mobile|all) ;;
  *)
    echo "preflight: unknown profile: $PROFILE (expected engine|mobile|all)" >&2
    exit 64
    ;;
esac

if [ -t 1 ]; then
  C_OK=$(printf '\033[32m')
  C_MISS=$(printf '\033[31m')
  C_WARN=$(printf '\033[33m')
  C_DIM=$(printf '\033[2m')
  C_OFF=$(printf '\033[0m')
else
  C_OK=""
  C_MISS=""
  C_WARN=""
  C_DIM=""
  C_OFF=""
fi

MISSING=""
MISSING_COUNT=0
LICENSE_CONFLICT=0

wants() {
  # wants <engine|mobile>: is this component in the selected profile?
  case "$PROFILE" in
    all) return 0 ;;
    "$1") return 0 ;;
    *) return 1 ;;
  esac
}

record_missing() {
  # record_missing <component> <remediation>
  MISSING_COUNT=$((MISSING_COUNT + 1))
  MISSING="${MISSING}${1}|${2}
"
}

has() {
  command -v "$1" >/dev/null 2>&1
}

rule() {
  printf '%s\n' "------------------------------------------------------------"
}

print_ok() {
  # print_ok <label> <detail>
  printf '  %s[ ok ]%s  %-22s %s\n' "$C_OK" "$C_OFF" "$1" "$2"
}

print_missing() {
  # print_missing <label> <detail> <remediation>
  printf '  %s[miss]%s  %-22s %s\n' "$C_MISS" "$C_OFF" "$1" "$2"
  printf '          %s%s%s\n' "$C_DIM" "remediation: $3" "$C_OFF"
}

print_note() {
  # print_note <label> <detail>
  printf '  %s[warn]%s  %-22s %s\n' "$C_WARN" "$C_OFF" "$1" "$2"
}

printf '\nSportcut developer environment preflight (profile: %s)\n' "$PROFILE"
printf 'Host: %s %s (%s)\n' "$(uname -s)" "$(uname -r)" "$(uname -m)"
rule

# ---------------------------------------------------------------- Rust ------
if wants engine || wants mobile; then
  if has rustc; then
    RUSTC_VERSION=$(rustc --version 2>/dev/null | head -n 1)
    print_ok "Rust toolchain" "$RUSTC_VERSION"
  else
    print_missing "Rust toolchain" "not found" \
      "install rustup and a stable toolchain: https://rustup.rs (engine track: required; client track: required)"
    record_missing "Rust toolchain (rustc)" "install with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  fi

  if has cargo; then
    CARGO_VERSION=$(cargo --version 2>/dev/null | head -n 1)
    print_ok "Cargo" "$CARGO_VERSION"
  else
    print_missing "Cargo" "not found" \
      "install with rustup (cargo ships with the toolchain): https://rustup.rs"
    record_missing "Cargo" "install with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  fi

  # --- Media toolchain -------------------------------------------------------
  FFMPEG_BIN=""
  FFPROBE_BIN=""
  has ffmpeg && FFMPEG_BIN=$(command -v ffmpeg)
  has ffprobe && FFPROBE_BIN=$(command -v ffprobe)

  if [ -n "$FFMPEG_BIN" ] && [ -n "$FFPROBE_BIN" ]; then
    FFMPEG_VERSION=$(ffmpeg -version 2>/dev/null | head -n 1)
    FFPROBE_VERSION=$(ffprobe -version 2>/dev/null | head -n 1)
    print_ok "Media toolchain" "$FFMPEG_VERSION"
    printf '          %s%s%s\n' "$C_DIM" "$FFPROBE_VERSION" "$C_OFF"
    printf '          %s%s%s\n' "$C_DIM" "ffmpeg: $FFMPEG_BIN" "$C_OFF"
    printf '          %s%s%s\n' "$C_DIM" "ffprobe: $FFPROBE_BIN" "$C_OFF"

    FFMPEG_CONFIG=$(ffmpeg -version 2>/dev/null | sed -n 's/^configuration: //p' | head -n 1)
    if [ -n "$FFMPEG_CONFIG" ]; then
      printf '          license-affecting configuration:\n'
      printf '            %s%s%s\n' "$C_DIM" "$FFMPEG_CONFIG" "$C_OFF"
      GPL_FLAGS=""
      for flag in --enable-gpl --enable-nonfree --enable-libx264 --enable-libx265 --enable-libxvid --enable-frei0r; do
        case "$FFMPEG_CONFIG" in
          *"$flag"*) GPL_FLAGS="${GPL_FLAGS}${flag} " ;;
        esac
      done
      if [ -n "$GPL_FLAGS" ]; then
        LICENSE_CONFLICT=1
        print_note "Media licensing" "GPL components detected: ${GPL_FLAGS% }"
        printf '          %s%s%s\n' "$C_DIM" \
          "conflict: GPL components cannot be linked into a proprietary mobile distribution." "$C_OFF"
        printf '          %s%s%s\n' "$C_DIM" \
          "remediation: use this build for local development only; ship with platform-native media APIs (AVFoundation/VideoToolbox, MediaCodec/Media3) or an LGPL-configured FFmpeg with GPL-only parts disabled. See docs/legal/dependency-register.md." "$C_OFF"
      else
        print_ok "Media licensing" "no GPL-only components detected in the build configuration"
      fi
    else
      print_note "Media licensing" "could not read the ffmpeg build configuration"
    fi
  else
    DETAIL="not found"
    [ -n "$FFMPEG_BIN" ] && DETAIL="ffmpeg found ($FFMPEG_BIN) but ffprobe is missing"
    [ -z "$FFMPEG_BIN" ] && [ -n "$FFPROBE_BIN" ] && DETAIL="ffprobe found ($FFPROBE_BIN) but ffmpeg is missing"
    print_missing "Media toolchain" "$DETAIL" \
      "install ffmpeg and ffprobe (macOS: brew install ffmpeg; Debian/Ubuntu: apt-get install ffmpeg), or point SPORTCUT_FFMPEG / SPORTCUT_FFPROBE at an existing pair"
    record_missing "Media toolchain (ffmpeg + ffprobe)" "install ffmpeg with ffprobe (brew install ffmpeg) or set SPORTCUT_FFMPEG and SPORTCUT_FFPROBE"
  fi
fi

# -------------------------------------------------------------- Mobile ------
if wants mobile; then
  # --- Flutter / Dart location ------------------------------------------------
  # The Flutter SDK bundles Dart, so both resolve from one directory.
  FLUTTER_BIN_DIR=""
  if [ -n "${SPORTCUT_FLUTTER_BIN:-}" ] && [ -x "${SPORTCUT_FLUTTER_BIN}/flutter" ]; then
    FLUTTER_BIN_DIR="${SPORTCUT_FLUTTER_BIN}"
  elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "${FLUTTER_ROOT}/bin/flutter" ]; then
    FLUTTER_BIN_DIR="${FLUTTER_ROOT}/bin"
  elif has flutter; then
    FLUTTER_BIN_DIR=$(dirname "$(command -v flutter)")
  else
    for candidate in "${HOME}/flutter/bin" "${HOME}/development/flutter/bin" "${HOME}/fvm/default/bin"; do
      if [ -x "${candidate}/flutter" ]; then
        FLUTTER_BIN_DIR="${candidate}"
        break
      fi
    done
  fi

  # --- Flutter ---------------------------------------------------------------
  if [ -n "$FLUTTER_BIN_DIR" ]; then
    FLUTTER_VERSION=$("${FLUTTER_BIN_DIR}/flutter" --version 2>/dev/null | head -n 1)
    [ -z "$FLUTTER_VERSION" ] && FLUTTER_VERSION="version unavailable"
    print_ok "Flutter SDK" "$FLUTTER_VERSION"
    printf '          %s%s%s\n' "$C_DIM" "${FLUTTER_BIN_DIR}/flutter" "$C_OFF"
  else
    print_missing "Flutter SDK" "not found" \
      "install the Flutter SDK and put it on PATH, or point SPORTCUT_FLUTTER_BIN at its bin directory (macOS: brew install --cask flutter; or download from https://docs.flutter.dev/get-started/install)"
    record_missing "Flutter SDK" "install Flutter and add it to PATH: https://docs.flutter.dev/get-started/install"
  fi

  # --- Dart ------------------------------------------------------------------
  # The Dart SDK ships inside the Flutter SDK; a standalone dart on PATH also works.
  if [ -n "$FLUTTER_BIN_DIR" ] && [ -x "${FLUTTER_BIN_DIR}/dart" ]; then
    DART_VERSION=$("${FLUTTER_BIN_DIR}/dart" --version 2>&1 | head -n 1)
    print_ok "Dart" "$DART_VERSION"
  elif has dart; then
    DART_VERSION=$(dart --version 2>&1 | head -n 1)
    print_ok "Dart" "$DART_VERSION"
  else
    if [ -n "$FLUTTER_BIN_DIR" ]; then
      print_missing "Dart" "not on PATH (the Flutter SDK bundles Dart under <flutter>/bin)" \
        "put the Flutter SDK's bin directory on PATH so dart resolves, or install the standalone Dart SDK"
      record_missing "Dart" "add <flutter-sdk>/bin to PATH, or install the Dart SDK"
    else
      print_missing "Dart" "not found" \
        "install the Flutter SDK (which bundles Dart) or the standalone Dart SDK from https://dart.dev/get-dart"
      record_missing "Dart" "install the Flutter SDK (bundles Dart) or the Dart SDK: https://dart.dev/get-dart"
    fi
  fi

  # --- Xcode -----------------------------------------------------------------
  XCODE_OK=0
  DEVELOPER_DIR_PATH=$(xcode-select -p 2>/dev/null || true)
  if [ -n "$DEVELOPER_DIR_PATH" ]; then
    case "$DEVELOPER_DIR_PATH" in
      *.app/Contents/Developer*) XCODE_OK=1 ;;
      *) XCODE_OK=0 ;;
    esac
  fi
  if [ "$XCODE_OK" -eq 1 ] && has xcodebuild; then
    XCODEBUILD_VERSION=$(xcodebuild -version 2>&1 | head -n 1)
    case "$XCODEBUILD_VERSION" in
      *"requires Xcode"*) XCODE_OK=0 ;;
    esac
  else
    XCODE_OK=0
  fi

  if [ "$XCODE_OK" -eq 1 ]; then
    print_ok "Xcode (full install)" "$XCODEBUILD_VERSION"
  else
    if [ -n "$DEVELOPER_DIR_PATH" ]; then
      DETAIL="active developer directory is $DEVELOPER_DIR_PATH (Command Line Tools only)"
    else
      DETAIL="not found"
    fi
    print_missing "Xcode (full install)" "$DETAIL" \
      "install Xcode from the App Store, then run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch"
    record_missing "Xcode (full installation)" "install Xcode from the App Store, then: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  fi

  # --- Android SDK -----------------------------------------------------------
  ANDROID_SDK=""
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}" ]; then
    ANDROID_SDK="${ANDROID_HOME}"
  elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT}" ]; then
    ANDROID_SDK="${ANDROID_SDK_ROOT}"
  elif [ -d "${HOME}/Library/Android/sdk" ]; then
    ANDROID_SDK="${HOME}/Library/Android/sdk"
  fi

  if [ -z "$ANDROID_SDK" ] && has adb; then
    ANDROID_SDK=$(dirname "$(dirname "$(command -v adb)")")
  fi

  if [ -n "$ANDROID_SDK" ] && [ -d "$ANDROID_SDK" ]; then
    print_ok "Android SDK" "$ANDROID_SDK"
    if [ -d "$ANDROID_SDK/platform-tools" ]; then
      printf '          %splatform-tools present%s\n' "$C_DIM" "$C_OFF"
    else
      print_note "Android SDK" "platform-tools directory missing under $ANDROID_SDK"
    fi
    if [ -d "$ANDROID_SDK/cmdline-tools" ] || has sdkmanager; then
      printf '          %scmdline-tools present%s\n' "$C_DIM" "$C_OFF"
    else
      print_note "Android SDK" "cmdline-tools missing; install via Android Studio's SDK Manager if you need sdkmanager"
    fi
  else
    print_missing "Android SDK" "not found (checked ANDROID_HOME, ANDROID_SDK_ROOT, ~/Library/Android/sdk, adb)" \
      "install Android Studio or the Android command-line tools, set ANDROID_HOME, and accept the SDK licenses"
    record_missing "Android SDK" "install Android Studio or the Android command-line tools, set ANDROID_HOME, accept the licenses"
  fi

  # --- JDK -------------------------------------------------------------------
  JDK_OK=0
  JDK_VERSION=""
  JAVA_HOME_DETECTED=$(/usr/libexec/java_home 2>/dev/null || true)
  if has java; then
    JAVA_OUTPUT=$(java -version 2>&1 | head -n 3)
    case "$JAVA_OUTPUT" in
      *"Unable to locate a Java Runtime"*|*"No Java runtime present"*) JDK_OK=0 ;;
      *version*) JDK_OK=1 ;;
      *) JDK_OK=0 ;;
    esac
    if [ "$JDK_OK" -eq 1 ]; then
      JDK_VERSION=$(printf '%s' "$JAVA_OUTPUT" | head -n 1)
    fi
  fi
  if [ "$JDK_OK" -eq 1 ] && [ -n "$JAVA_HOME_DETECTED" ]; then
    JDK_VERSION="${JDK_VERSION} (JAVA_HOME: ${JAVA_HOME_DETECTED})"
  fi

  if [ "$JDK_OK" -eq 1 ]; then
    print_ok "JDK" "$JDK_VERSION"
  else
    if has java; then
      DETAIL="java is on PATH but no Java runtime is installed (macOS stub)"
    else
      DETAIL="not found"
    fi
    print_missing "JDK" "$DETAIL" \
      "install a JDK 17 or newer (macOS: brew install --cask temurin; or use the JDK bundled with Android Studio) and set JAVA_HOME"
    record_missing "JDK" "install a JDK 17+ (brew install --cask temurin) and set JAVA_HOME"
  fi
fi

rule

# ------------------------------------------------------------- Summary ------
if [ "$MISSING_COUNT" -eq 0 ]; then
  printf '%sAll required components are present.%s\n' "$C_OK" "$C_OFF"
else
  printf '%sMissing components: %s%s\n' "$C_MISS" "$MISSING_COUNT" "$C_OFF"
  printf '%s' "$MISSING" | while IFS='|' read -r component remediation; do
    [ -z "$component" ] && continue
    printf '  - %s\n      %s\n' "$component" "$remediation"
  done
fi

if [ "$LICENSE_CONFLICT" -eq 1 ]; then
  printf '\n%sMedia toolchain licensing:%s the detected build configuration contains GPL components.\n' "$C_WARN" "$C_OFF"
  printf '  Developer use: fine.\n'
  printf '  Shipped target: blocked until the media path uses license-clean components\n'
  printf '  (platform-native APIs or an LGPL-configured FFmpeg).\n'
  printf '  Register entry: docs/legal/dependency-register.md\n'
fi

printf '\n'

if [ "$MISSING_COUNT" -gt 0 ]; then
  printf 'Preflight failed: %s component(s) missing.\n' "$MISSING_COUNT"
  exit 1
fi

if [ "$LICENSE_CONFLICT" -eq 1 ] && [ "$STRICT_LICENSE" -eq 1 ]; then
  printf 'Preflight failed: --strict-license requires a license-clean media toolchain.\n'
  exit 2
fi

printf 'Preflight passed.\n'
exit 0
