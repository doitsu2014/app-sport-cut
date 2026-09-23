#!/usr/bin/env bash
#
# The single verification command for the engine track.
#
# Runs formatting, lint, and test across the whole Rust workspace in core/.
# Requires the Rust toolchain and the media toolchain (the media tests generate
# their own fixtures with ffmpeg).
#
# Usage:
#   tools/verify-engine.sh
#
# Extra arguments are passed to `cargo test`, for example:
#   tools/verify-engine.sh -- --nocapture

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"

if [ ! -f "${CORE_DIR}/Cargo.toml" ]; then
  echo "verify-engine: no Cargo workspace at ${CORE_DIR}" >&2
  exit 1
fi

cd "${CORE_DIR}"

echo "==> cargo fmt --all -- --check"
cargo fmt --all -- --check

echo "==> cargo clippy --workspace --all-targets -- -D warnings"
cargo clippy --workspace --all-targets -- -D warnings

echo "==> cargo test --workspace"
cargo test --workspace "$@"

echo "==> engine verification passed"
