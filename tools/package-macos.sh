#!/usr/bin/env bash
#
# Build a personal, installable Sportcut.app and a DMG.
#
# This is a local build for one Mac, not a distributable release:
#   - it is ad-hoc signed unless CODESIGN_IDENTITY is set;
#   - it uses the ffmpeg/ffprobe already installed on this machine (the GPL
#     Homebrew build is fine for local use, but not shippable);
#   - the app launches the embedded helper itself under
#     ~/Library/Application Support/Sportcut/state.
#
# Usage:
#   tools/package-macos.sh
#   CODESIGN_IDENTITY="Developer ID Application: ..." tools/package-macos.sh
#
# Output: dist/Sportcut.dmg

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
DIST="${REPO_ROOT}/dist"
APP="${REPO_ROOT}/app/build/macos/Build/Products/Release/sportcut.app"

if ! command -v flutter >/dev/null 2>&1; then
  if [ -n "${SPORTCUT_FLUTTER_BIN:-}" ] && [ -x "${SPORTCUT_FLUTTER_BIN}/flutter" ]; then
    PATH="${SPORTCUT_FLUTTER_BIN}:${PATH}"
    export PATH
  else
    echo "package-macos: flutter is not on PATH; set SPORTCUT_FLUTTER_BIN" >&2
    exit 1
  fi
fi

if ! command -v ffmpeg >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/ffmpeg ]; then
  echo "package-macos: warning: ffmpeg/ffprobe were not found." >&2
  echo "  The packaged app needs them at runtime; install with 'brew install ffmpeg'." >&2
fi

echo "==> building the service"
"${SCRIPT_DIR}/build-service.sh"

if [ -n "${CARGO_TARGET_DIR:-}" ]; then
  case "${CARGO_TARGET_DIR}" in
    /*) TARGET_DIR="${CARGO_TARGET_DIR}" ;;
    *) TARGET_DIR="${REPO_ROOT}/core/${CARGO_TARGET_DIR}" ;;
  esac
else
  TARGET_DIR="${REPO_ROOT}/core/target"
fi
SERVICE="${TARGET_DIR}/release/sportcut-service"
if [ ! -x "${SERVICE}" ]; then
  echo "package-macos: expected service at ${SERVICE}" >&2
  exit 1
fi

echo "==> building the client (release)"
(cd "${REPO_ROOT}/app" && flutter build macos --release)

if [ ! -d "${APP}" ]; then
  echo "package-macos: expected app at ${APP}" >&2
  exit 1
fi

echo "==> embedding the service and inference assets"
"${SCRIPT_DIR}/embed-service.sh" "${APP}"
"${SCRIPT_DIR}/embed-inference-assets.sh" "${APP}"

sign() {
  local target="$1"
  if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp \
      --sign "${CODESIGN_IDENTITY}" "${target}"
  else
    # Ad-hoc: no hardened runtime, so the helper may load the ad-hoc dylib.
    codesign --force --sign - "${target}"
  fi
}

sign_app() {
  local entitlements="${REPO_ROOT}/app/macos/Runner/Release.entitlements"
  if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp \
      --entitlements "${entitlements}" \
      --sign "${CODESIGN_IDENTITY}" "${APP}"
  else
    # Re-signing must carry the picker entitlement; --force alone drops it.
    codesign --force --entitlements "${entitlements}" --sign - "${APP}"
  fi
}

echo "==> signing"
if [ -f "${APP}/Contents/Frameworks/libtensorflowlite_c.dylib" ]; then
  sign "${APP}/Contents/Frameworks/libtensorflowlite_c.dylib"
fi
sign "${APP}/Contents/Helpers/SportcutService"
sign_app
codesign --verify --deep --strict "${APP}" >/dev/null 2>&1 || \
  echo "package-macos: warning: codesign verification reported an issue" >&2

echo "==> building the DMG"
rm -rf "${DIST}"
mkdir -p "${DIST}/stage"
cp -R "${APP}" "${DIST}/stage/sportcut.app"
ln -s /Applications "${DIST}/stage/Applications"
hdiutil create \
  -volname "Sportcut" \
  -srcfolder "${DIST}/stage" \
  -ov -format UDZO \
  "${DIST}/Sportcut.dmg" >/dev/null
rm -rf "${DIST}/stage"

cat <<EOF

==> packaged ${DIST}/Sportcut.dmg

Install:
  1. Open the DMG and drag sportcut.app to Applications.
  2. First launch: right-click the app and choose Open (the build is ad-hoc
     signed unless CODESIGN_IDENTITY was set).
  3. The app starts its embedded service on first launch and keeps state under
     ~/Library/Application Support/Sportcut.

Runtime requirements:
  - ffmpeg and ffprobe must be installed (the helper is started with
    /opt/homebrew/bin or /usr/local/bin, then PATH).
  - Player tracking needs the inference assets, which were embedded above.

This is a personal build. The Homebrew ffmpeg is GPL and must not be shipped;
a distributable release needs the licensing register's allowed media toolchain.
EOF
