#!/usr/bin/env bash
#
# Run the Flutter client on macOS, for development on a workstation.
#
# The client is a separate process from the engine. It does not link a Rust
# library and there is no generated binding: it connects to the Sportcut service
# over a Unix socket (docs/architecture/protocol.md).
#
# What it does:
#   1. checks that the inference assets are present (the app bundles them);
#   2. runs the app with `flutter run -d macos`.
#
# It does not start the service. Run tools/run-service.sh in another terminal and
# export the endpoint and state root it prints; the client reads
# SPORTCUT_ENDPOINT and SPORTCUT_STATE_ROOT (or the matching --dart-define
# values) at startup.
#
# Usage:
#   tools/run-macos.sh [extra flutter run arguments...]

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

if ! command -v flutter >/dev/null 2>&1; then
  if [ -n "${SPORTCUT_FLUTTER_BIN:-}" ] && [ -x "${SPORTCUT_FLUTTER_BIN}/flutter" ]; then
    PATH="${SPORTCUT_FLUTTER_BIN}:${PATH}"
    export PATH
  else
    echo "run-macos: flutter is not on PATH; set SPORTCUT_FLUTTER_BIN" >&2
    exit 1
  fi
fi

if [ -z "${SPORTCUT_ENDPOINT:-}" ] && [ -z "${SPORTCUT_STATE_ROOT:-}" ]; then
  echo "run-macos: no service endpoint configured." >&2
  echo "  start the service in another terminal with tools/run-service.sh," >&2
  echo "  then export SPORTCUT_ENDPOINT and SPORTCUT_STATE_ROOT (or pass" >&2
  echo "  --dart-define=SPORTCUT_ENDPOINT=... --dart-define=SPORTCUT_TOKEN=...)." >&2
  exit 1
fi

echo "==> flutter run -d macos $*"

cd "${REPO_ROOT}/app"
flutter run -d macos "$@"
