#!/usr/bin/env bash
#
# Regenerate the macOS app icon from the Sportcut brand SVGs.
#
# Source art:
#   design-system/brand/sportcut-icon.svg        128-1024 px
#   design-system/brand/sportcut-icon-small.svg  16-64 px (simplified)
#
# Output:
#   app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png
#
# The generated PNGs are committed, so a normal Flutter build does not need
# this script. Run it only after editing the SVG sources.
#
# Usage:
#   tools/generate-app-icons.sh
#
# Requires macOS with the Xcode toolchain (AppKit + swift). The rasteriser
# keeps the transparent corners and the soft tile shadow; Quick Look is not
# used because it flattens SVG onto a white background.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
RENDERER="${SCRIPT_DIR}/render-app-icon.swift"

FULL_SVG="${REPO_ROOT}/design-system/brand/sportcut-icon.svg"
SMALL_SVG="${REPO_ROOT}/design-system/brand/sportcut-icon-small.svg"
ICONSET="${REPO_ROOT}/app/macos/Runner/Assets.xcassets/AppIcon.appiconset"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "generate-app-icons: macOS is required (AppKit)" >&2
  exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
  echo "generate-app-icons: swift was not found; install the Xcode toolchain" >&2
  exit 1
fi
for source in "${FULL_SVG}" "${SMALL_SVG}" "${RENDERER}"; do
  if [ ! -f "${source}" ]; then
    echo "generate-app-icons: missing ${source}" >&2
    exit 1
  fi
done
if [ ! -d "${ICONSET}" ]; then
  echo "generate-app-icons: missing ${ICONSET}" >&2
  exit 1
fi

render() {
  local source="$1" size="$2" output="$3"
  swift "${RENDERER}" "${source}" "${output}" "${size}"
}

# 128 px and up carry the full mark (centre line, shadow).
for size in 1024 512 256 128; do
  render "${FULL_SVG}" "${size}" "${ICONSET}/app_icon_${size}.png"
done

# 64 px and below use the simplified, enlarged mark.
for size in 64 32 16; do
  render "${SMALL_SVG}" "${size}" "${ICONSET}/app_icon_${size}.png"
done

echo "==> regenerated app icons in ${ICONSET}"
for size in 16 32 64 128 256 512 1024; do
  file="${ICONSET}/app_icon_${size}.png"
  printf '    %s: %sx%s\n' "$(basename "${file}")" \
    "$(sips -g pixelWidth "${file}" | awk '/pixelWidth/ {print $2}')" \
    "$(sips -g pixelHeight "${file}" | awk '/pixelHeight/ {print $2}')"
done
