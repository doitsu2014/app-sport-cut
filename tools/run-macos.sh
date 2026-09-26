#!/usr/bin/env bash
#
# Run the Flutter client on macOS, for development on a workstation.
#
# macOS is the product's shipping target; this script runs the client on the
# desktop for development and review.
#
# What it does:
#   1. checks that the bridge bindings have been generated;
#   2. builds the engine library into core/crates/api/target/release;
#   3. points the generated loader at that directory and runs the app.
#
# The loader needs the pointer because it resolves its default directory
# relative to the process working directory, which is not the project directory
# for a packaged macOS app.
#
# Usage:
#   tools/run-macos.sh [extra flutter run arguments...]

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

ENGINE_LIB_DIR="${REPO_ROOT}/core/crates/api/target/release"

if [ ! -f "${REPO_ROOT}/core/crates/api/src/frb_generated.rs" ]; then
  echo "run-macos: bindings are missing; run tools/generate-bridge.sh first" >&2
  exit 1
fi

"${SCRIPT_DIR}/build-engine-lib.sh"

if [ ! -f "${ENGINE_LIB_DIR}/libsportcut_api.dylib" ]; then
  echo "run-macos: ${ENGINE_LIB_DIR}/libsportcut_api.dylib was not produced" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  if [ -n "${SPORTCUT_FLUTTER_BIN:-}" ] && [ -x "${SPORTCUT_FLUTTER_BIN}/flutter" ]; then
    PATH="${SPORTCUT_FLUTTER_BIN}:${PATH}"
    export PATH
  else
    echo "run-macos: flutter is not on PATH; set SPORTCUT_FLUTTER_BIN" >&2
    exit 1
  fi
fi

echo "==> engine library: ${ENGINE_LIB_DIR}/libsportcut_api.dylib"
echo "==> flutter run -d macos $*"

cd "${REPO_ROOT}/app"
FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR="${ENGINE_LIB_DIR}/" \
  flutter run -d macos "$@"
