#!/usr/bin/env bash
#
# Copy the built service into a macOS .app bundle and sign it.
#
# The service is a separate signed helper at
# Contents/Helpers/SportcutService (ADR-0001). Build it first:
#
#   tools/build-service.sh
#   tools/embed-service.sh /path/to/Sportcut.app
#
# When CODESIGN_IDENTITY is set, the helper is signed in place. When it is not
# set, the script copies the helper, prints the exact codesign command to run,
# and exits 0 so packaging can continue without a signing identity.
#
# Usage:
#   CODESIGN_IDENTITY="Developer ID Application: ..." tools/embed-service.sh <app-bundle>

set -euo pipefail

APP="${1:-}"
if [ -z "${APP}" ]; then
  echo "usage: embed-service.sh <app-bundle-path>" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"

if [ ! -d "${APP}" ]; then
  echo "embed-service: ${APP} is not a directory" >&2
  exit 1
fi
APP=$(cd "${APP}" && pwd)

if [ -n "${CARGO_TARGET_DIR:-}" ]; then
  case "${CARGO_TARGET_DIR}" in
    /*) TARGET_DIR="${CARGO_TARGET_DIR}" ;;
    *) TARGET_DIR="${CORE_DIR}/${CARGO_TARGET_DIR}" ;;
  esac
else
  TARGET_DIR="${CORE_DIR}/target"
fi
SERVICE="${TARGET_DIR}/release/sportcut-service"

if [ ! -x "${SERVICE}" ]; then
  cat >&2 <<EOF
embed-service: ${SERVICE} is missing.
Build the service first:
  tools/build-service.sh
EOF
  exit 1
fi

HELPER="${APP}/Contents/Helpers/SportcutService"
mkdir -p "$(dirname "${HELPER}")"
cp "${SERVICE}" "${HELPER}"
chmod 0755 "${HELPER}"

echo "==> embedded ${HELPER}"

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "==> codesign --force --options runtime --timestamp --sign \"${CODESIGN_IDENTITY}\" \"${HELPER}\""
  codesign --force --options runtime --timestamp \
    --sign "${CODESIGN_IDENTITY}" "${HELPER}"
  codesign --verify --strict --verbose=2 "${HELPER}"
  echo "==> signed and verified ${HELPER}"
else
  cat <<EOF

CODESIGN_IDENTITY is not set; the helper was copied but not signed.
Run this exact command before packaging:

  codesign --force --options runtime --timestamp --sign "<identity>" "${HELPER}"

EOF
fi
