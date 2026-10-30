#!/usr/bin/env bash
#
# Regenerate the C4 diagrams from docs/architecture/c4/workspace.dsl.
#
# The workspace DSL is the source of truth. Structurizr exports it to
# C4-PlantUML, PlantUML renders each view to SVG, and the SVGs are committed.
# Both steps run in pinned Docker images, so the output is byte-identical on
# every machine and nothing is installed into the checkout.
#
# Usage:
#   tools/generate-c4-diagrams.sh           # write docs/architecture/c4/generated/
#   tools/generate-c4-diagrams.sh --check   # fail if the committed SVGs are stale
#   tools/generate-c4-diagrams.sh --pull    # pull the pinned images, then generate
#
# Requires Docker (daemon running) and python3. The images are pulled once;
# after that generation is offline.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
DSL="${REPO_ROOT}/docs/architecture/c4/workspace.dsl"
OUT_DIR="${REPO_ROOT}/docs/architecture/c4/generated"
WORK_DIR="${REPO_ROOT}/build/c4-work"

# Pinned deliberately: the SVGs are committed and --check compares bytes, so a
# different renderer version must be a reviewed change, not a silent upgrade.
STRUCTURIZR_IMAGE="structurizr/structurizr:2026.10.26"
PLANTUML_IMAGE="plantuml/plantuml:1.2026.9"

MODE="generate"
case "${1:-}" in
  "")
    ;;
  --check)
    MODE="check"
    ;;
  --pull)
    MODE="pull"
    ;;
  *)
    echo "generate-c4-diagrams: unknown argument '${1}' (expected --check or --pull)." >&2
    exit 2
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "generate-c4-diagrams: docker is not on PATH." >&2
  echo "The C4 diagrams are rendered with the pinned Structurizr and PlantUML images." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "generate-c4-diagrams: the Docker daemon is not running." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "generate-c4-diagrams: python3 is not on PATH." >&2
  exit 1
fi

if [ ! -f "${DSL}" ]; then
  echo "generate-c4-diagrams: no workspace DSL at ${DSL}" >&2
  exit 1
fi

if [ "${MODE}" = "pull" ]; then
  docker pull "${STRUCTURIZR_IMAGE}"
  docker pull "${PLANTUML_IMAGE}"
  MODE="generate"
fi

for image in "${STRUCTURIZR_IMAGE}" "${PLANTUML_IMAGE}"; do
  if ! docker image inspect "${image}" >/dev/null 2>&1; then
    echo "generate-c4-diagrams: image ${image} is not present." >&2
    echo "Run tools/generate-c4-diagrams.sh --pull once to fetch the pinned images." >&2
    exit 1
  fi
done

VIEWS=$(python3 - "${DSL}" <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    text = handle.read()
views = re.findall(
    r'^\s*(?:systemContext|container|component)\s+[A-Za-z_]\w*\s+"([^"]+)"',
    text,
    flags=re.MULTILINE,
)
if not views:
    sys.exit("generate-c4-diagrams: no views found in the workspace DSL")
for view in views:
    print(view)
PY
)

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}/export" "${OUT_DIR}"
trap 'rm -rf "${WORK_DIR}"' EXIT

docker run --rm -v "${REPO_ROOT}:/repo" "${STRUCTURIZR_IMAGE}" \
  export \
  -w /repo/docs/architecture/c4/workspace.dsl \
  -f plantuml/c4plantuml \
  -o /repo/build/c4-work/export

docker run --rm -v "${REPO_ROOT}:/repo" "${PLANTUML_IMAGE}" \
  -tsvg /repo/build/c4-work/export >/dev/null

failures=()
for view in ${VIEWS}; do
  source="${WORK_DIR}/export/structurizr-${view}.svg"
  target="${OUT_DIR}/${view}.svg"
  if [ ! -f "${source}" ]; then
    echo "generate-c4-diagrams: Structurizr produced no SVG for view '${view}'." >&2
    exit 1
  fi
  if [ "${MODE}" = "check" ]; then
    if [ ! -f "${target}" ] || ! cmp -s "${source}" "${target}"; then
      failures+=("${view}.svg")
    fi
  else
    cp "${source}" "${target}"
  fi
done

if [ "${MODE}" = "check" ]; then
  if [ "${#failures[@]}" -gt 0 ]; then
    echo "generate-c4-diagrams: stale diagram(s): ${failures[*]}" >&2
    echo "Run tools/generate-c4-diagrams.sh and commit the result." >&2
    exit 1
  fi
  echo "generate-c4-diagrams: all diagrams are current." >&2
  exit 0
fi

for stale in "${OUT_DIR}"/*.svg; do
  [ -e "${stale}" ] || continue
  name=$(basename "${stale}" .svg)
  if ! printf '%s\n' "${VIEWS}" | grep -qx "${name}"; then
    rm -f "${stale}"
  fi
done

echo "generate-c4-diagrams: wrote ${OUT_DIR}" >&2
