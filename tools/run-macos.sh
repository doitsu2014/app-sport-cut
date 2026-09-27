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
#   3. fetches the inference assets (TFLite runtime + model);
#   4. runs the app; the Xcode build embeds the engine library and inference
#      assets into the .app bundle, so the app finds them without environment
#      variables.
#
# The fetch is idempotent: it downloads once and then verifies the cached
# copies, so the first run needs network and later runs do not.
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

"${SCRIPT_DIR}/fetch-inference-assets.sh"

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
