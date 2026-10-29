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
#   CARGO_TARGET_DIR   Override the Cargo target directory (optional).

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

echo "==> cargo build -p sportcut-service"
cd "${CORE_DIR}"
cargo build -p sportcut-service

if [ ! -x "${BINARY}" ]; then
  echo "run-service: expected binary ${BINARY} was not produced" >&2
  exit 1
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

echo "==> state root: ${STATE_ROOT}"
echo "==> endpoint:   ${ENDPOINT}"
echo "==> token file: ${TOKEN_FILE}"
echo "==> binary:     ${BINARY}"

"${BINARY}" \
  --state-root "${STATE_ROOT}" \
  --endpoint "${ENDPOINT}" \
  --token-file "${TOKEN_FILE}"
