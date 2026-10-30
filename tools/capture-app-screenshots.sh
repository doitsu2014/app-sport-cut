#!/usr/bin/env bash
#
# Capture the client's screenshot suites as PNGs.
#
# The suites render the real app at the studio's reference window size and
# write PNGs through RepaintBoundary.toImage. `IntegrationTestWidgetsFlutter-
# Binding.takeScreenshot` is not implemented on macOS, so the integration run
# uses the same capture path as the headless one; only the surface sizing
# differs.
#
# Usage:
#   tools/capture-app-screenshots.sh [--integration] [--output DIR]
#
#   --integration   run app/integration_test on the macOS desktop runtime
#                   (needs a real GUI session) instead of the headless
#                   widget-test suite under app/test/screenshots
#   --output DIR    where the PNGs are written; relative paths are resolved
#                   against the repository root. Default: app/build/screenshots
#   --help          print this message
#
# Screenshots are build output. Both `app/build/` and `**/build/` are ignored
# by git; do not commit the PNGs.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

MODE=headless
OUTPUT=""

usage() {
  printf '%s\n' \
    "Usage: tools/capture-app-screenshots.sh [--integration] [--output DIR]" \
    "" \
    "  --integration   run app/integration_test on the macOS desktop runtime" \
    "                  (needs a real GUI session) instead of the headless" \
    "                  widget-test suite under app/test/screenshots" \
    "  --output DIR    where the PNGs are written; relative paths are resolved" \
    "                  against the repository root. Default: app/build/screenshots" \
    "  --help          print this message"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --integration)
      MODE=integration
      shift
      ;;
    --output)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "capture-app-screenshots: --output needs a directory" >&2
        exit 2
      fi
      OUTPUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "capture-app-screenshots: unknown argument: $1" >&2
      echo "  run tools/capture-app-screenshots.sh --help" >&2
      exit 2
      ;;
  esac
done

if ! command -v flutter >/dev/null 2>&1; then
  if [ -n "${SPORTCUT_FLUTTER_BIN:-}" ] && [ -x "${SPORTCUT_FLUTTER_BIN}/flutter" ]; then
    PATH="${SPORTCUT_FLUTTER_BIN}:${PATH}"
    export PATH
  else
    echo "capture-app-screenshots: flutter is not on PATH; set SPORTCUT_FLUTTER_BIN" >&2
    exit 1
  fi
fi

if [ -z "${OUTPUT}" ]; then
  OUTPUT="${REPO_ROOT}/app/build/screenshots"
elif [ "${OUTPUT#/}" = "${OUTPUT}" ]; then
  OUTPUT="${REPO_ROOT}/${OUTPUT}"
fi

mkdir -p "${OUTPUT}"
OUTPUT=$(cd "${OUTPUT}" && pwd)

cd "${REPO_ROOT}/app"

echo "==> flutter pub get" >&2
flutter pub get

status=0
if [ "${MODE}" = "integration" ]; then
  echo "==> flutter test integration_test -d macos" >&2
  echo "    SPORTCUT_SCREENSHOT_DIR=${OUTPUT}" >&2
  flutter test integration_test -d macos \
    --dart-define="SPORTCUT_SCREENSHOT_DIR=${OUTPUT}" || status=$?
else
  echo "==> flutter test test/screenshots" >&2
  echo "    SPORTCUT_SCREENSHOT_DIR=${OUTPUT}" >&2
  SPORTCUT_SCREENSHOT_DIR="${OUTPUT}" flutter test test/screenshots || status=$?
fi

count=$(find "${OUTPUT}" -type f -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
echo "capture-app-screenshots: output directory: ${OUTPUT}" >&2
echo "capture-app-screenshots: PNG files: ${count}" >&2

exit "${status}"
