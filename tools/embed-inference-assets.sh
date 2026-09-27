#!/usr/bin/env bash
#
# Copy the fetched inference assets into a built macOS .app bundle.
#
# Run from the Xcode "Runner" build phase, or manually for a packaged build:
#   tools/embed-inference-assets.sh <path-to-Sportcut.app>
#
# The assets are expected in third_party/inference/ (see
# tools/fetch-inference-assets.sh). The runtime dylib lands in
# Contents/Frameworks so the engine's dynamic load is signing-safe, and the
# model weights land in Contents/Resources.

set -euo pipefail

APP="${1:?usage: embed-inference-assets.sh <app-bundle-path>}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

RUNTIME="${REPO_ROOT}/third_party/inference/libtensorflowlite_c.dylib"
MODEL="${REPO_ROOT}/third_party/inference/model.tflite"

if [ ! -f "${RUNTIME}" ] || [ ! -f "${MODEL}" ]; then
  echo "embed-inference-assets: inference assets are missing;" >&2
  echo "  run tools/fetch-inference-assets.sh first" >&2
  exit 1
fi

mkdir -p "${APP}/Contents/Frameworks" "${APP}/Contents/Resources"
cp "${RUNTIME}" "${APP}/Contents/Frameworks/"
cp "${MODEL}" "${APP}/Contents/Resources/"

echo "==> embedded inference assets into ${APP}"
