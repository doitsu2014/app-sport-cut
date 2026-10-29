#!/usr/bin/env bash
#
# Build the Sportcut background service in release and print its path.
#
# The service is a separate executable (ADR-0001); it is never linked into the
# Flutter app. The artifact is `sportcut-service` in the Cargo target directory.
#
# Usage:
#   tools/build-service.sh
#
# Environment:
#   CARGO_TARGET_DIR          Override the Cargo target directory (optional).
#   SPORTCUT_MACOS_TFLITE_EVAL  Set to 0 to omit the macos-tflite-eval feature on
#                             macOS (default: enabled on Darwin). Non-macOS builds
#                             never enable it.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"

if ! command -v cargo >/dev/null 2>&1; then
  echo "build-service: cargo is not on PATH; install the Rust toolchain" >&2
  exit 1
fi

if [ -n "${CARGO_TARGET_DIR:-}" ]; then
  case "${CARGO_TARGET_DIR}" in
    /*) TARGET_DIR="${CARGO_TARGET_DIR}" ;;
    *) TARGET_DIR="${CORE_DIR}/${CARGO_TARGET_DIR}" ;;
  esac
else
  TARGET_DIR="${CORE_DIR}/target"
fi
ARTIFACT="${TARGET_DIR}/release/sportcut-service"

FEATURES=""
if [ "$(uname -s)" = "Darwin" ] && [ "${SPORTCUT_MACOS_TFLITE_EVAL:-1}" != "0" ]; then
  FEATURES="macos-tflite-eval"
fi

cd "${CORE_DIR}"
if [ -n "${FEATURES}" ]; then
  echo "==> features: ${FEATURES}"
  echo "==> cargo build -p sportcut-service --release --features ${FEATURES}"
  cargo build -p sportcut-service --release --features "${FEATURES}"
else
  echo "==> features: none"
  echo "==> cargo build -p sportcut-service --release"
  cargo build -p sportcut-service --release
fi

if [ ! -x "${ARTIFACT}" ]; then
  echo "build-service: expected artifact ${ARTIFACT} was not produced" >&2
  exit 1
fi

echo "${ARTIFACT}"
