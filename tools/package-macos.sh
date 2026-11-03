#!/usr/bin/env bash
#
# Build a self-contained, installable Sportcut.app and a DMG.
#
# The bundle carries everything the app needs at runtime:
#   - the service helper at Contents/Helpers/SportcutService (universal);
#   - a license-clean, universal ffmpeg/ffprobe at Contents/Helpers/;
#   - the TFLite runtime and EfficientDet-Lite0 weights for player tracking.
#
# No Homebrew (or any other runtime dependency) is required on the Mac that
# installs the DMG. The DMG also carries the FFmpeg source tarball and license
# texts required by the LGPL.
#
# Signing is ad-hoc unless CODESIGN_IDENTITY is set. Notarisation runs when
# NOTARY_PROFILE names a `notarytool` keychain profile; it requires a Developer
# ID identity as well.
#
# Usage:
#   tools/package-macos.sh
#   CODESIGN_IDENTITY="Developer ID Application: ..." \
#     NOTARY_PROFILE="sportcut-notary" tools/package-macos.sh
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
  echo "package-macos: note: no system ffmpeg found (it is not needed; the app bundles its own)." >&2
fi

if [ -n "${NOTARY_PROFILE:-}" ] && [ -z "${CODESIGN_IDENTITY:-}" ]; then
  echo "package-macos: NOTARY_PROFILE requires CODESIGN_IDENTITY to be set" >&2
  exit 1
fi

echo "==> building the service (universal)"
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
for arch in arm64 x86_64; do
  if ! lipo -verify_arch "${arch}" "${SERVICE}" >/dev/null 2>&1; then
    echo "package-macos: warning: ${SERVICE} has no ${arch} slice, so the app" >&2
    echo "  will not launch its helper on that architecture." >&2
  fi
done

echo "==> building the bundled media toolchain (LGPL, universal)"
"${SCRIPT_DIR}/build-media-toolchain.sh"

MEDIA_TOOLCHAIN="${SPORTCUT_MEDIA_TOOLCHAIN_DIR:-${REPO_ROOT}/third_party/media-toolchain}"
if [ ! -x "${MEDIA_TOOLCHAIN}/ffmpeg" ] || [ ! -x "${MEDIA_TOOLCHAIN}/ffprobe" ]; then
  echo "package-macos: expected ffmpeg/ffprobe at ${MEDIA_TOOLCHAIN}" >&2
  exit 1
fi

echo "==> ensuring inference assets"
if [ ! -f "${REPO_ROOT}/third_party/inference/libtensorflowlite_c.dylib" ] || \
   [ ! -f "${REPO_ROOT}/third_party/inference/model.tflite" ]; then
  "${SCRIPT_DIR}/fetch-inference-assets.sh"
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

echo "==> embedding the media toolchain and its license material"
mkdir -p "${APP}/Contents/Helpers" "${APP}/Contents/Resources/licenses"
cp "${MEDIA_TOOLCHAIN}/ffmpeg" "${APP}/Contents/Helpers/ffmpeg"
cp "${MEDIA_TOOLCHAIN}/ffprobe" "${APP}/Contents/Helpers/ffprobe"
chmod 0755 "${APP}/Contents/Helpers/ffmpeg" "${APP}/Contents/Helpers/ffprobe"
cp "${MEDIA_TOOLCHAIN}/licenses/COPYING.LGPLv2.1" "${APP}/Contents/Resources/licenses/"
cp "${MEDIA_TOOLCHAIN}/licenses/LICENSE.md" "${APP}/Contents/Resources/licenses/ffmpeg-LICENSE.md"
cp "${MEDIA_TOOLCHAIN}/licenses/README.txt" "${APP}/Contents/Resources/licenses/ffmpeg-README.txt"

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
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  # Notarisation wants every nested Mach-O signed with the Developer ID, not
  # only the outer app. Sign frameworks as bundles, then dylibs and helpers.
  for framework in "${APP}/Contents/Frameworks/"*.framework; do
    [ -d "${framework}" ] || continue
    name=$(basename "${framework}" .framework)
    if [ -f "${framework}/Versions/Current/${name}" ]; then
      sign "${framework}"
    fi
  done
fi
if [ -f "${APP}/Contents/Frameworks/libtensorflowlite_c.dylib" ]; then
  sign "${APP}/Contents/Frameworks/libtensorflowlite_c.dylib"
fi
sign "${APP}/Contents/Helpers/ffmpeg"
sign "${APP}/Contents/Helpers/ffprobe"
sign "${APP}/Contents/Helpers/SportcutService"
sign_app
if ! codesign --verify --deep --strict "${APP}"; then
  echo "package-macos: signature verification failed; refusing to package" >&2
  exit 1
fi

echo "==> building the DMG"
rm -rf "${DIST}"
mkdir -p "${DIST}/stage"
cp -R "${APP}" "${DIST}/stage/sportcut.app"
ln -s /Applications "${DIST}/stage/Applications"

# The LGPL requires the corresponding source to travel with a static build.
mkdir -p "${DIST}/stage/Licenses"
cp "${MEDIA_TOOLCHAIN}/licenses/COPYING.LGPLv2.1" "${DIST}/stage/Licenses/"
cp "${MEDIA_TOOLCHAIN}/licenses/LICENSE.md" "${DIST}/stage/Licenses/ffmpeg-LICENSE.md"
cp "${MEDIA_TOOLCHAIN}/licenses/README.txt" "${DIST}/stage/Licenses/FFmpeg.txt"
cp "${MEDIA_TOOLCHAIN}/src/ffmpeg-"*.tar.xz "${DIST}/stage/Licenses/"
cp "${SCRIPT_DIR}/build-media-toolchain.sh" "${DIST}/stage/Licenses/"
chmod 0644 "${DIST}/stage/Licenses/"*

hdiutil create \
  -volname "Sportcut" \
  -srcfolder "${DIST}/stage" \
  -ov -format UDZO \
  "${DIST}/Sportcut.dmg" >/dev/null
rm -rf "${DIST}/stage"

DMG="${DIST}/Sportcut.dmg"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "==> signing the DMG"
  codesign --force --timestamp --sign "${CODESIGN_IDENTITY}" "${DMG}"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "==> notarising the DMG (this can take a few minutes)"
  xcrun notarytool submit "${DMG}" \
    --keychain-profile "${NOTARY_PROFILE}" --wait
  echo "==> stapling the notarisation ticket"
  xcrun stapler staple "${DMG}"
  xcrun stapler validate "${DMG}"
fi

cat <<EOF

==> packaged ${DMG}

Install:
  1. Open the DMG and drag sportcut.app to Applications.
  2. Launch it. $(if [ -n "${NOTARY_PROFILE:-}" ]; then echo "The build is signed and notarised, so Gatekeeper accepts it."; else echo "This build is ad-hoc signed, so the first launch needs right-click → Open."; fi)
  3. The app starts its embedded service on first launch and keeps state under
     ~/Library/Application Support/com.sportcut.sportcut.

Runtime requirements:
  - None beyond macOS 12 or later. ffmpeg, ffprobe, the service helper, the
    TFLite runtime, and the person model are all inside the bundle.
  - Player tracking needs the bundled TFLite runtime's architecture and OS:
    Apple Silicon running macOS 15 or later. Everything except tracking runs on
    Intel and on macOS 12 or later.

Notarisation:
  $(if [ -n "${NOTARY_PROFILE:-}" ]; then echo "Completed with keychain profile '${NOTARY_PROFILE}'."; else echo "Not performed. Set CODESIGN_IDENTITY and NOTARY_PROFILE to notarise:";
     echo "  xcrun notarytool store-credentials sportcut-notary \\";
     echo "    --apple-id <your Apple ID> --team-id <TEAMID> --password <app-specific password>";
     echo "  CODESIGN_IDENTITY=\"Developer ID Application: ... (TEAMID)\" \\";
     echo "    NOTARY_PROFILE=sportcut-notary tools/package-macos.sh"; fi)
EOF
