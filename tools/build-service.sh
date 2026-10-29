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
#   CARGO_TARGET_DIR   Override the Cargo target directory (optional).

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

echo "==> cargo build -p sportcut-service --release"
cd "${CORE_DIR}"
cargo build -p sportcut-service --release

if [ ! -x "${ARTIFACT}" ]; then
  echo "build-service: expected artifact ${ARTIFACT} was not produced" >&2
  exit 1
fi

echo "${ARTIFACT}"
