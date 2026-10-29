#!/usr/bin/env bash
#
# Check that the Rust workspace obeys the Clean Architecture dependency rule.
#
# Source-code dependencies point inward. An outer layer may depend on an inner
# one; an inner layer may never depend on an outer one, and a use case may never
# depend on the gateway that implements its port.
#
# The layer of a crate is the directory it lives in:
#
#   0 entities/    1 use-cases/    2 gateways/    3 adapters/    4 drivers/
#
# That is deliberate: the folder cannot disagree with the rule, because the
# folder is the rule. A crate added to the wrong directory is caught by the edge
# check below rather than by a hand-maintained table.
#
# The layers themselves are documented in docs/architecture/layering.md.
#
# Usage:
#   tools/check-layering.sh
#
# Exit status is 1 when any violation is found, 0 when the layout is clean.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"

if ! command -v cargo >/dev/null 2>&1; then
  echo "check-layering: cargo is not on PATH." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<'EOF'
check-layering: jq is not on PATH.

The check reads `cargo metadata` output; install jq to run it:
  brew install jq
EOF
  exit 1
fi

layer_name() {
  case "$1" in
    0) echo "entities" ;;
    1) echo "use-cases" ;;
    2) echo "gateways" ;;
    3) echo "adapters" ;;
    4) echo "drivers" ;;
  esac
}

# Adapter-to-adapter edges that are deliberate, with the condition that removes
# each one.
#
#   sportcut-service -> sportcut-api
#     ADR-0002, "Declared exception". The use cases live in sportcut-api, which
#     is still parked in adapters/ even though nothing about it is a delivery
#     mechanism: it is an ordinary library, and the FFI adapter it once served
#     is gone. Removed by moving it to core/use-cases/ — then this entry is
#     deleted and the edge is adapter -> use case, which the rule allows.
is_allowed_adapter_edge() {
  case "$1" in
    "sportcut-service->sportcut-api") return 0 ;;
    *) return 1 ;;
  esac
}

violations=0

fail() {
  violations=$((violations + 1))
  echo "  VIOLATION: $*" >&2
}

# --- 1. Dependency direction -------------------------------------------------
# Only normal dependencies are enforced. Dev-dependencies are how the tests of
# an inner layer exercise the adapter that implements its port, and that cycle
# is deliberate.
#
# Each row is: from-crate, from-layer, to-crate, to-layer.
edges=$(cd "${CORE_DIR}" && cargo metadata --no-deps --format-version 1 \
  | jq -r '
      def lvl:
        if   test("/core/entities/")  then 0
        elif test("/core/use-cases/") then 1
        elif test("/core/gateways/")  then 2
        elif test("/core/adapters/")  then 3
        elif test("/core/drivers/")   then 4
        else null end;
      . as $m
      | ([$m.packages[] | {key: .name, value: (.manifest_path | lvl)}] | from_entries) as $L
      | $m.packages[]
      | . as $p
      | .dependencies[]
      | select(.path != null)
      | select((.kind // "normal") == "normal")
      | [$p.name, ($L[$p.name] // "-"), .name, ($L[.name] // "-")]
      | @tsv')

while IFS=$'\t' read -r from from_layer to to_layer; do
  [ -z "${from}" ] && continue

  if [ "${from_layer}" = "-" ] || [ "${to_layer}" = "-" ]; then
    fail "${from} -> ${to}: one of the packages is not under a layer directory (entities/, use-cases/, gateways/, adapters/, drivers/)"
    continue
  fi

  if [ "${to_layer}" -gt "${from_layer}" ]; then
    fail "${from} (layer ${from_layer}, $(layer_name "${from_layer}")) depends on ${to} (layer ${to_layer}, $(layer_name "${to_layer}")) — dependencies must point inward"
    continue
  fi

  # Same-layer adapter edges are a peer coupling, not a direction violation.
  if [ "${from_layer}" -eq 3 ] && [ "${to_layer}" -eq 3 ]; then
    if ! is_allowed_adapter_edge "${from}->${to}"; then
      fail "${from} -> ${to}: an adapter may not depend on another adapter. Add a declared exception with a removal condition if this is deliberate."
    fi
  fi

  # The wire contract is data only: no engine types may leak into it.
  if [ "${from}" = "sportcut-protocol" ]; then
    fail "${from} -> ${to}: the protocol crate must depend only on serde, so both sides can share it"
  fi
done <<< "${edges}"

# --- 2. Entities stay pure ---------------------------------------------------
# The innermost layer is data and rules over data. A filesystem, process,
# environment, or network call in it is a layer leak, even without a Cargo edge.
#
# Reading the clock is deliberately allowed: an entity may stamp the time it was
# written. Injecting a clock would buy nothing here and would infect every
# constructor with a parameter no caller has ever needed to vary.
PURITY_PATTERNS='std::fs|std::process|std::env|std::net'

for crate_dir in "${CORE_DIR}"/entities/*/; do
  [ -d "${crate_dir}src" ] || continue
  hits=$(grep -rnE "${PURITY_PATTERNS}" "${crate_dir}src" || true)
  if [ -n "${hits}" ]; then
    while IFS= read -r hit; do
      fail "${hit} — the entity layer may not touch the filesystem, the environment, or the network"
    done <<< "${hits}"
  fi
done

# --- 3. The innermost crate depends on nothing -------------------------------
inward_edges=$(grep -F "sportcut-common"$'\t'"0"$'\t' <<< "${edges}" || true)
if [ -n "${inward_edges}" ]; then
  while IFS=$'\t' read -r from _ to to_layer; do
    fail "${from} -> ${to} (layer ${to_layer}) — sportcut-common is the innermost crate and may not depend on another workspace crate"
  done <<< "${inward_edges}"
fi

# --- Report ------------------------------------------------------------------
if [ "${violations}" -ne 0 ]; then
  echo "" >&2
  echo "check-layering: ${violations} violation(s)." >&2
  echo "See docs/architecture/layering.md for the layer model and the rule." >&2
  exit 1
fi

echo "check-layering: clean — every dependency points inward."
