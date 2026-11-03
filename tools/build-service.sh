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
#   SPORTCUT_SERVICE_ARCHS    Slices to build on macOS, space-separated
#                             (default: "arm64 x86_64"). Set to "native" to
#                             build only the host slice.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"

if ! command -v cargo >/dev/null 2>&1; then
  echo "build-service: cargo is not on PATH; install the Rust toolchain" >&2
  exit 1
fi

# Homebrew's rust formula is not rustup-managed: `rustup target add` installs
# into a different toolchain and the cross build then fails to find `core`.
# Prefer rustup's cargo/rustc pair whenever rustup knows one, so the target
# check and the build agree on the same sysroot.
if command -v rustup >/dev/null 2>&1; then
  RUSTUP_CARGO=$(rustup which cargo 2>/dev/null || true)
  if [ -n "${RUSTUP_CARGO}" ]; then
    RUSTUP_BIN_DIR=$(dirname "${RUSTUP_CARGO}")
    case ":${PATH}:" in
      *":${RUSTUP_BIN_DIR}:"*) ;;
      *) PATH="${RUSTUP_BIN_DIR}:${PATH}"; export PATH ;;
    esac
  fi
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

# A shipped app is universal: the Flutter shell is built for both slices, so the
# helper must run on either Mac. Cross-compiling needs the other Rust standard
# library, which rustup installs on demand.
SERVICE_ARCHS="${SPORTCUT_SERVICE_ARCHS:-arm64 x86_64}"
if [ "$(uname -s)" != "Darwin" ] || [ "${SERVICE_ARCHS}" = "native" ]; then
  SERVICE_ARCHS=""
fi

triple_for_arch() {
  case "$1" in
    arm64) echo "aarch64-apple-darwin" ;;
    x86_64) echo "x86_64-apple-darwin" ;;
    *) return 1 ;;
  esac
}

if [ -n "${SERVICE_ARCHS}" ]; then
  for arch in ${SERVICE_ARCHS}; do
    if ! triple_for_arch "${arch}" >/dev/null; then
      echo "build-service: unsupported arch '${arch}' (expected arm64 or x86_64)" >&2
      exit 1
    fi
  done
  if ! command -v rustup >/dev/null 2>&1; then
    echo "build-service: rustup is required to install the x86_64 slice" >&2
    exit 1
  fi
  echo "==> targets: ${SERVICE_ARCHS}"
  for arch in ${SERVICE_ARCHS}; do
    triple=$(triple_for_arch "${arch}")
    if ! rustup target list --installed | grep -qx "${triple}"; then
      echo "==> installing Rust target ${triple}"
      rustup target add "${triple}"
    fi
  done
fi

cd "${CORE_DIR}"
if [ -n "${SERVICE_ARCHS}" ]; then
  SLICES=()
  for arch in ${SERVICE_ARCHS}; do
    triple=$(triple_for_arch "${arch}")
    echo "==> cargo build -p sportcut-service --release --target ${triple}${FEATURES:+ --features ${FEATURES}}"
    if [ -n "${FEATURES}" ]; then
      cargo build -p sportcut-service --release --target "${triple}" --features "${FEATURES}"
    else
      cargo build -p sportcut-service --release --target "${triple}"
    fi
    SLICES+=("${TARGET_DIR}/${triple}/release/sportcut-service")
  done

  echo "==> lipo -create -output ${ARTIFACT}"
  mkdir -p "${TARGET_DIR}/release"
  lipo -create "${SLICES[@]}" -output "${ARTIFACT}"
elif [ -n "${FEATURES}" ]; then
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
