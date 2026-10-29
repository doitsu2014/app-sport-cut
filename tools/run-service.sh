#!/usr/bin/env bash
#
# Build and run the Sportcut service for development.
#
# The service listens on a Unix socket and writes a per-launch token. It is a
# separate process (ADR-0001); this script never starts the Flutter app.
#
# By default the state root is a fresh temporary directory that is removed when
# the script exits. Pass --state-root to keep data across runs, and --keep to
# keep the temporary directory.
#
# Usage:
#   tools/run-service.sh [--state-root <path>] [--keep]
#
# Environment:
#   CARGO_TARGET_DIR            Override the Cargo target directory (optional).
#   SPORTCUT_FFMPEG             Pass --ffmpeg when set.
#   SPORTCUT_FFPROBE            Pass --ffprobe when set.
#   SPORTCUT_MACOS_TFLITE_EVAL  Set to 0 to omit the macos-tflite-eval feature on
#                               macOS (default: enabled on Darwin), matching
#                               tools/build-service.sh. Non-macOS builds never
#                               enable it.
#
# When third_party/inference contains both libtensorflowlite_c.dylib and
# model.tflite, they are passed as --tflite-library and --person-model. Fetch
# them with tools/fetch-inference-assets.sh first. The script builds with the
# same Darwin-gated feature selection as build-service.sh and checks the
# artifact reports that feature, so the development path cannot pass inference
# assets to a build that cannot use them.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"

STATE_ROOT=""
KEEP=0

usage() {
  cat <<'EOF'
usage: run-service.sh [--state-root <path>] [--keep]

  --state-root <path>  Use an explicit state root instead of a temporary one.
  --keep               Keep the temporary state root on exit.
  -h, --help           Print this help.

Environment:
  SPORTCUT_FFMPEG             ffmpeg executable; passed as --ffmpeg when set.
  SPORTCUT_FFPROBE            ffprobe executable; passed as --ffprobe when set.
  SPORTCUT_MACOS_TFLITE_EVAL  Set to 0 to omit the macos-tflite-eval feature on
                              macOS (default: enabled on Darwin).
  Inference assets in third_party/inference are passed as --tflite-library and
  --person-model when both files exist.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --state-root)
      if [ "$#" -lt 2 ]; then
        echo "run-service: --state-root requires a value" >&2
        exit 2
      fi
      STATE_ROOT="$2"
      shift 2
      ;;
    --keep)
      KEEP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "run-service: unknown argument $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v cargo >/dev/null 2>&1; then
  echo "run-service: cargo is not on PATH; install the Rust toolchain" >&2
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
BINARY="${TARGET_DIR}/debug/sportcut-service"

# Match tools/build-service.sh: the service only compiles the macOS TFLite
# evaluation runtime when the feature is on.
FEATURES=""
if [ "$(uname -s)" = "Darwin" ] && [ "${SPORTCUT_MACOS_TFLITE_EVAL:-1}" != "0" ]; then
  FEATURES="macos-tflite-eval"
fi

cd "${CORE_DIR}"
if [ -n "${FEATURES}" ]; then
  echo "==> features:   ${FEATURES}"
  echo "==> cargo build -p sportcut-service --features ${FEATURES}"
  cargo build -p sportcut-service --features "${FEATURES}"
else
  echo "==> features:   none"
  echo "==> cargo build -p sportcut-service"
  cargo build -p sportcut-service
fi

if [ ! -x "${BINARY}" ]; then
  echo "run-service: expected binary ${BINARY} was not produced" >&2
  exit 1
fi

# Smoke check: the artifact itself must claim the feature the build asked for.
# `--version` is cheap and does not touch the assets, so a stale or mis-built
# binary cannot be exercised silently.
VERSION_LINE="$("${BINARY}" --version)"
if [ -n "${FEATURES}" ]; then
  case "${VERSION_LINE}" in
    *"${FEATURES}"*) ;;
    *)
      echo "run-service: built binary does not report ${FEATURES}: ${VERSION_LINE}" >&2
      exit 1
      ;;
  esac
fi

CREATED_STATE_ROOT=0
if [ -z "${STATE_ROOT}" ]; then
  STATE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/sportcut-service.XXXXXX")
  CREATED_STATE_ROOT=1
fi
mkdir -p "${STATE_ROOT}"
STATE_ROOT=$(cd "${STATE_ROOT}" && pwd)

ENDPOINT="${STATE_ROOT}/run/s.sock"
TOKEN_FILE="${STATE_ROOT}/run/token"

if [ "${#ENDPOINT}" -gt 103 ]; then
  echo "run-service: endpoint is ${#ENDPOINT} bytes, over the 103-byte AF_UNIX limit:" >&2
  echo "  ${ENDPOINT}" >&2
  echo "Use a shorter --state-root." >&2
  if [ "${CREATED_STATE_ROOT}" = 1 ]; then
    rm -rf "${STATE_ROOT}"
  fi
  exit 1
fi

cleanup() {
  if [ "${CREATED_STATE_ROOT}" = 1 ] && [ "${KEEP}" = 0 ]; then
    rm -rf "${STATE_ROOT}"
  fi
}
trap cleanup EXIT

EXTRA_ARGS=()
INFERENCE_DIR="${REPO_ROOT}/third_party/inference"
if [ -f "${INFERENCE_DIR}/libtensorflowlite_c.dylib" ] && [ -f "${INFERENCE_DIR}/model.tflite" ]; then
  EXTRA_ARGS+=(
    --tflite-library "${INFERENCE_DIR}/libtensorflowlite_c.dylib"
    --person-model "${INFERENCE_DIR}/model.tflite"
  )
  echo "==> inference:   ${INFERENCE_DIR}"
  if [ -z "${FEATURES}" ]; then
    echo "run-service: warning: inference assets are present but macos-tflite-eval is off;" >&2
    echo "  player tracking will report unsupported. Unset SPORTCUT_MACOS_TFLITE_EVAL" >&2
    echo "  (or set it to 1) on macOS to enable it." >&2
  fi
else
  echo "==> inference:   not bundled (run tools/fetch-inference-assets.sh)"
fi
if [ -n "${SPORTCUT_FFMPEG:-}" ]; then
  EXTRA_ARGS+=(--ffmpeg "${SPORTCUT_FFMPEG}")
fi
if [ -n "${SPORTCUT_FFPROBE:-}" ]; then
  EXTRA_ARGS+=(--ffprobe "${SPORTCUT_FFPROBE}")
fi

echo "==> state root: ${STATE_ROOT}"
echo "==> endpoint:   ${ENDPOINT}"
echo "==> token file: ${TOKEN_FILE}"
echo "==> binary:     ${BINARY}"

# Bash 3.2 (the macOS default) rejects an empty array expansion under `set -u`,
# so only append the optional flags when there are any.
if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
  "${BINARY}" \
    --state-root "${STATE_ROOT}" \
    --endpoint "${ENDPOINT}" \
    --token-file "${TOKEN_FILE}" \
    "${EXTRA_ARGS[@]}"
else
  "${BINARY}" \
    --state-root "${STATE_ROOT}" \
    --endpoint "${ENDPOINT}" \
    --token-file "${TOKEN_FILE}"
fi
