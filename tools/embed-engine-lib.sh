#!/usr/bin/env bash
#
# Copy the pre-built engine library into a built macOS .app bundle.
#
# Build the library first (tools/build-engine-lib.sh), then run this from the
# Xcode "Runner" build phase or manually for a packaged build:
#   tools/embed-engine-lib.sh <path-to-Sportcut.app>
#
# The dylib lands in Contents/Frameworks so the app can open it directly,
# without the development-only loader directory or environment variable.

set -euo pipefail

APP="${1:?usage: embed-engine-lib.sh <app-bundle-path>}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

DYLIB="${REPO_ROOT}/core/crates/api/target/release/libsportcut_api.dylib"

if [ ! -f "${DYLIB}" ]; then
  echo "embed-engine-lib: engine library is not built;" >&2
  echo "  run tools/build-engine-lib.sh first" >&2
  exit 1
fi

mkdir -p "${APP}/Contents/Frameworks"
cp "${DYLIB}" "${APP}/Contents/Frameworks/"

echo "==> embedded engine library into ${APP}"
