#!/usr/bin/env bash
#
# Build the engine library the Flutter app links against.
#
# The target directory matters: the generated Dart bindings load the shared
# library from core/crates/api/target/release (see the loader configuration in
# app/lib/src/bridge/generated/frb_generated.dart), so the build has to use the
# crate's own target directory rather than the workspace one.
#
# The `bridge` feature compiles the generated glue in
# core/crates/api/src/frb_generated.rs, which only exists after
# tools/generate-bridge.sh has run.
#
# The `macos-tflite-eval` feature compiles the local TFLite detector. It is
# enabled by default on macOS (the shipping target) and needs the matching
# local runtime/model paths in SPORTCUT_TFLITE_LIBRARY and
# SPORTCUT_PERSON_MODEL at run time. Set SPORTCUT_MACOS_TFLITE_EVAL=0 to build
# without it.
#
# Usage:
#   tools/build-engine-lib.sh [--debug]

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

PROFILE_FLAG="--release"
if [ "${1:-}" = "--debug" ]; then
  PROFILE_FLAG=""
fi

GLUE="${REPO_ROOT}/core/crates/api/src/frb_generated.rs"
if [ ! -f "${GLUE}" ]; then
  cat >&2 <<'EOF'
build-engine-lib: core/crates/api/src/frb_generated.rs is missing.

Generate the bindings first:
  tools/generate-bridge.sh
EOF
  exit 1
fi

cd "${REPO_ROOT}/core/crates/api"

FEATURES="bridge"
if [ "$(uname -s)" = "Darwin" ] && [ "${SPORTCUT_MACOS_TFLITE_EVAL:-1}" = "1" ]; then
  FEATURES="bridge,macos-tflite-eval"
fi

echo "==> cargo build -p sportcut-api --features ${FEATURES} ${PROFILE_FLAG}"
# shellcheck disable=SC2086
cargo build -p sportcut-api --features "${FEATURES}" --target-dir target ${PROFILE_FLAG}

echo "==> built into core/crates/api/target/(debug|release)"
ls -1 "${REPO_ROOT}/core/crates/api/target"/*/libsportcut_api.* 2>/dev/null || true
