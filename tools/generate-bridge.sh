#!/usr/bin/env bash
#
# Regenerate the flutter_rust_bridge bindings.
#
# Generated files are never hand-edited and never committed: this script is the
# only supported way to produce them. It needs the Dart SDK on PATH (the code
# generator formats the Dart it emits) and the pinned code generator.
#
# Usage:
#   tools/generate-bridge.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "${REPO_ROOT}"

# Keep in step with core/crates/api/Cargo.toml.
BRIDGE_VERSION="2.13.0"

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  cat >&2 <<EOF
generate-bridge: flutter_rust_bridge_codegen is not installed.

Install the pinned version:
  cargo install flutter_rust_bridge_codegen --version ${BRIDGE_VERSION} --locked
EOF
  exit 1
fi

if ! command -v dart >/dev/null 2>&1; then
  cat >&2 <<EOF
generate-bridge: dart is not on PATH.

Install the Flutter SDK (which bundles Dart) or the standalone Dart SDK, then
run this script again. The generator formats the Dart bindings it emits.

Run tools/preflight.sh --profile macos to see what else is missing.
EOF
  exit 1
fi

echo "==> flutter_rust_bridge_codegen generate (v${BRIDGE_VERSION})"
flutter_rust_bridge_codegen generate

echo "==> generated:"
echo "    core/crates/api/src/frb_generated.rs"
echo "    app/lib/src/bridge/generated/"
