#!/usr/bin/env bash
#
# Guardrail for ADR-0001: the Flutter client must contain no Rust FFI.
#
# The script scans `app/` for FRB, `dart:ffi`, `DynamicLibrary`, `RustLib`,
# generated bridge bindings, and `libsportcut_api`. It also accepts app bundle
# paths and inspects those for a shipped dylib or FFI residue.
#
# The check is blocking: any finding fails. There is no allowlist. The FFI path
# is gone, so a reappearance is a regression, not known debt.
#
# Usage:
#   tools/check-no-rust-in-app.sh [--strict] [--app <path>] [<app-bundle> ...]

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

# Blocking. `--strict` is still accepted so existing callers keep working.
STRICT=1
APP_DIR="${REPO_ROOT}/app"
BUNDLES=()

usage() {
  cat <<'EOF'
usage: check-no-rust-in-app.sh [--strict] [--app <path>] [<app-bundle> ...]

  --strict       Accepted for compatibility; the check is always strict.
  --app <path>   Client tree to scan (default: <repo>/app).
  <app-bundle>   Built .app bundle(s) to inspect for a shipped dylib/FFI strings.
  -h, --help     Print this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict)
      STRICT=1
      shift
      ;;
    --app)
      if [ "$#" -lt 2 ]; then
        echo "check-no-rust-in-app: --app requires a value" >&2
        exit 2
      fi
      APP_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        BUNDLES+=("$1")
        shift
      done
      ;;
    -*)
      echo "check-no-rust-in-app: unknown argument $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      BUNDLES+=("$1")
      shift
      ;;
  esac
done

if [ ! -d "${APP_DIR}" ]; then
  echo "check-no-rust-in-app: ${APP_DIR} is not a directory" >&2
  exit 2
fi
APP_DIR=$(cd "${APP_DIR}" && pwd)

PATTERNS=(
  "flutter_rust_bridge"
  "dart:ffi"
  "DynamicLibrary"
  "ExternalLibrary"
  "RustLib"
  "frb_generated"
  "libsportcut_api"
)

FINDINGS=()
MISSING_BUNDLES=()

record_finding() {
  local path="$1"
  local pattern="$2"
  if [ -e "${REPO_ROOT}/${path}" ]; then
    FINDINGS+=("${path}|${pattern}")
  fi
  return 0
}

scan_file() {
  local file="$1"
  local rel="${file#"${REPO_ROOT}/"}"
  local pattern
  for pattern in "${PATTERNS[@]}"; do
    if grep -IqF -e "${pattern}" "${file}" 2>/dev/null; then
      FINDINGS+=("${rel}|${pattern}")
    fi
  done
}

# Skip generated build output, dependency checkouts, and copied preview trees.
while IFS= read -r -d '' file; do
  scan_file "${file}"
done < <(find "${APP_DIR}" \
  \( \
    -path '*/.dart_tool' -o -path '*/.dart_tool/*' \
    -o -path '*/build' -o -path '*/build/*' \
    -o -path '*/Pods' -o -path '*/Pods/*' \
    -o -path '*/ephemeral' -o -path '*/ephemeral/*' \
    -o -path '*/.symlinks' -o -path '*/.symlinks/*' \
    -o -path '*/.widget_preview' -o -path '*/.widget_preview/*' \
    -o -path '*/lib/src/bridge/generated' -o -path '*/lib/src/bridge/generated/*' \
  \) -prune -o -type f -print0)

# Generated bridge bindings are never committed; if they exist, they are debt.
GENERATED_DIR="${APP_DIR}/lib/src/bridge/generated"
if [ -d "${GENERATED_DIR}" ]; then
  while IFS= read -r -d '' file; do
    rel="${file#"${REPO_ROOT}/"}"
    FINDINGS+=("${rel}|generated-bridge")
  done < <(find "${GENERATED_DIR}" -type f -print0)
fi

# Core/build-graph checks from background-service §14.1. These catch the
# bridge-only configuration the app scan alone cannot see: the cdylib/staticlib
# crate types, the `bridge` feature, and the FRB package and config.
if grep -Rq "flutter_rust_bridge" "${REPO_ROOT}/core/Cargo.toml" 2>/dev/null; then
  record_finding "core/Cargo.toml" "flutter_rust_bridge"
fi
if grep -q "flutter_rust_bridge" "${REPO_ROOT}/core/adapters/api/Cargo.toml" 2>/dev/null; then
  record_finding "core/adapters/api/Cargo.toml" "flutter_rust_bridge"
fi
if grep -Eq 'crate-type[[:space:]]*=[[:space:]]*\[[^]]*"(cdylib|staticlib)"' \
  "${REPO_ROOT}/core/adapters/api/Cargo.toml" 2>/dev/null; then
  record_finding "core/adapters/api/Cargo.toml" "crate-type cdylib/staticlib"
fi
if grep -q '^bridge[[:space:]]*=' "${REPO_ROOT}/core/adapters/api/Cargo.toml" 2>/dev/null; then
  record_finding "core/adapters/api/Cargo.toml" "bridge feature"
fi
record_finding "flutter_rust_bridge.yaml" "flutter_rust_bridge config"
record_finding "core/adapters/api/src/frb_generated.rs" "frb_generated"

# The Flutter app target must not consume a Rust archive.
while IFS= read -r -d '' archive; do
  rel="${archive#"${REPO_ROOT}/"}"
  case "${rel}" in
    */XPCServices/*) ;;
    *) FINDINGS+=("${rel}|rust-archive") ;;
  esac
done < <(find "${APP_DIR}" -name '*.a' -path '*sportcut*' \
  -not -path '*/XPCServices/*' -print0 2>/dev/null)

# The narrow unsafe allowance is confined to the OS-glue module.
while IFS= read -r -d '' source; do
  rel="${source#"${REPO_ROOT}/"}"
  case "${rel}" in
    */os_glue.rs | */os_glue/*) continue ;;
  esac
  # Ignore full-line comments, which often explain the absence of unsafe code.
  if grep -nE '\bunsafe\b' "${source}" 2>/dev/null \
    | grep -vE '^[0-9]+:[[:space:]]*(//|/\*|\*)' >/dev/null 2>&1; then
    FINDINGS+=("${rel}|unsafe")
  fi
done < <(find "${REPO_ROOT}/core" \
  \( -path '*/target' -o -path '*/target/*' \) -prune -o \
  -type f -name '*.rs' -print0 2>/dev/null)

# Inspect built bundles when given.
FFI_STRING_REGEX='flutter_rust_bridge|RustLib|libsportcut_api|frb_generated|dart:ffi|DynamicLibrary'
for bundle in ${BUNDLES[@]+"${BUNDLES[@]}"}; do
  if [ ! -e "${bundle}" ]; then
    echo "check-no-rust-in-app: error: requested bundle ${bundle} does not exist" >&2
    MISSING_BUNDLES+=("${bundle}")
    continue
  fi
  BUNDLE_PATH=$(cd "${bundle}" && pwd)

  while IFS= read -r -d '' dylib; do
    rel="${dylib#"${REPO_ROOT}/"}"
    FINDINGS+=("${rel}|libsportcut_api")
  done < <(find "${BUNDLE_PATH}" -name 'libsportcut_api.*' -print0)

  while IFS= read -r hit; do
    [ -z "${hit}" ] && continue
    rel="${hit#"${REPO_ROOT}/"}"
    FINDINGS+=("${rel}|ffi-residue")
  done < <(grep -a -r -l -E "${FFI_STRING_REGEX}" "${BUNDLE_PATH}" 2>/dev/null || true)
done

TOTAL_COUNT=${#FINDINGS[@]}

echo "==> app tree: ${APP_DIR}"

if [ "${TOTAL_COUNT}" -gt 0 ]; then
  echo "==> FFI violations (${TOTAL_COUNT}):"
  for finding in ${FINDINGS[@]+"${FINDINGS[@]}"}; do
    echo "  ${finding%%|*}: ${finding##*|}"
  done
fi

if [ "${#MISSING_BUNDLES[@]}" -gt 0 ]; then
  echo "check-no-rust-in-app: FAILED (requested bundle missing; the check cannot pass vacuously)" >&2
  exit 1
fi

if [ "${TOTAL_COUNT}" -gt 0 ]; then
  echo "check-no-rust-in-app: FAILED (${TOTAL_COUNT} finding(s))" >&2
  exit 1
fi

echo "check-no-rust-in-app: OK (no Rust, FFI, or generated bindings in the client)"
exit 0
