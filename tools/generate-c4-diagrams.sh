#!/usr/bin/env bash
#
# Regenerate the C4 diagrams from docs/architecture/c4/workspace.dsl.
#
# The workspace DSL is the source of truth for L1–L3. Structurizr exports it to
# C4-PlantUML, PlantUML renders each view to SVG, and the SVGs are committed.
# Structurizr has no code level, so L4 is generated in the same run from
# `cargo metadata` and the Rust module graph. Both steps run in pinned Docker
# images, so the output is byte-identical on every machine and nothing is
# installed into the checkout.
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
CORE_DIR="${REPO_ROOT}/core"
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

# --- L4: the code view -----------------------------------------------------
# Structurizr cannot draw a code level, so L4 is generated from the crate
# manifests and the module graph: one package per crate (nested by layer), one
# component per source module, solid arrows for `use crate::` references, and
# dashed arrows for `use sportcut_*` crate dependencies. Edges to
# sportcut-common are omitted, matching the L3 rule.

python3 - "${REPO_ROOT}" "${CORE_DIR}" "${WORK_DIR}/l4-code.puml" <<'PY'
import json
import os
import re
import subprocess
import sys

repo_root, core_dir, out_path = sys.argv[1:4]

meta = json.loads(
    subprocess.check_output(
        ["cargo", "metadata", "--no-deps", "--format-version", "1"], cwd=core_dir
    )
)

LAYER_BY_DIR = {
    "entities": "Entities",
    "use-cases": "Use cases",
    "gateways": "Gateways + contracts",
    "adapters": "Adapters",
    "drivers": "Drivers",
}

def ident(value):
    return re.sub(r"[^A-Za-z0-9_]", "_", value)

def module_path(root, file_path):
    rel = os.path.relpath(file_path, os.path.join(root, "src")).replace(os.sep, "/")
    if rel == "lib.rs":
        return "", "lib.rs"
    if rel == "main.rs":
        return "main", "main.rs"
    if rel.endswith("/mod.rs"):
        rel = rel[:-7]
    elif rel.endswith(".rs"):
        rel = rel[:-3]
    return rel.replace("/", "::"), rel + ".rs"

crates = {}
for package in meta["packages"]:
    root = os.path.dirname(package["manifest_path"])
    src = os.path.join(root, "src")
    if not os.path.isdir(src):
        continue
    files = []
    for directory, _, names in os.walk(src):
        for name in names:
            if name.endswith(".rs"):
                files.append(os.path.join(directory, name))
    files.sort()
    layer_dir = os.path.relpath(root, core_dir).split(os.sep)
    layer = next(
        (LAYER_BY_DIR[part] for part in layer_dir if part in LAYER_BY_DIR),
        "Crates",
    )
    developer_only = package["name"] in ("sportcut-cli", "sportcut-eval")
    modules = {}
    for file_path in files:
        path, label = module_path(root, file_path)
        modules[path] = (file_path, label)
    crates[package["name"]] = {
        "layer": layer,
        "developer_only": developer_only,
        "modules": modules,
    }

crate_ids = {name: ident(name) for name in crates}
module_ids = {}
for crate, values in crates.items():
    for path, (_, label) in values["modules"].items():
        module_ids[(crate, path)] = ident(f"{crate}__{path or label.replace('.', '_')}")

intra = set()
cross = set()

for crate, values in crates.items():
    paths = values["modules"]
    for path, (file_path, _) in paths.items():
        text = open(file_path, encoding="utf-8").read()

        def resolve(reference, base=path):
            if not reference:
                return
            parts = reference.split("::")
            if parts[0] == "super":
                base_parts = base.split("::") if base else []
                while parts and parts[0] == "super":
                    parts.pop(0)
                    if base_parts:
                        base_parts.pop()
                parts = base_parts + parts
            elif parts and parts[0] == "self":
                parts = parts[1:]
                parts = (base.split("::") if base else []) + parts
            candidate = "::".join(parts)
            while candidate:
                target = candidate.rsplit("::", 1)[0] if "::" in candidate else ""
                if candidate in paths:
                    if (crate, path) != (crate, candidate):
                        intra.add(((crate, path), (crate, candidate)))
                    return
                if not target:
                    break
                candidate = target
            root = "" if "" in paths else ("main" if "main" in paths else None)
            if root is not None and path != root:
                intra.add(((crate, path), (crate, root)))

        for match in re.finditer(r"\bcrate::", text):
            rest = text[match.end() :]
            if rest.startswith("{"):
                close = rest.find("}")
                body = rest[1:close] if close != -1 else rest[1:]
                entries = [entry.strip() for entry in body.split(",")]
                for entry in entries:
                    resolve(entry.split(" as ")[0].split("::")[0])
                continue
            head = re.match(r"[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)*", rest)
            if head:
                resolve(head.group(0))

        for match in re.finditer(r"\bsportcut_([a-z0-9_]+)::", text):
            target = "sportcut-" + match.group(1).replace("_", "-")
            if target not in crates:
                continue
            if target == crate:
                # lib.rs and main.rs are separate roots in one package; a
                # binary's `use sportcut_x::...` points at the library root.
                rest = text[match.end() :]
                if rest.startswith("{"):
                    root = "" if "" in paths else ("main" if "main" in paths else None)
                    if root is not None and path != root:
                        intra.add(((crate, path), (crate, root)))
                else:
                    head = re.match(
                        r"[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)*",
                        rest,
                    )
                    if head:
                        resolve(head.group(0))
                continue
            if target == "sportcut-common":
                continue
            cross.add((crate, target))

lines = ["@startuml"]
lines.append("title Sportcut L4 - Rust module graph")
lines.append("skinparam componentStyle rectangle")
lines.append("skinparam packageStyle rectangle")
lines.append("skinparam shadowing false")
lines.append("skinparam defaultFontName Helvetica")
lines.append("skinparam component {")
lines.append("  BackgroundColor #F4F8FB")
lines.append("  BorderColor #5B7FA6")
lines.append("  FontSize 11")
lines.append("}")
lines.append("skinparam package {")
lines.append("  BackgroundColor #FFFFFF")
lines.append("  BorderColor #9AA7B4")
lines.append("  FontSize 12")
lines.append("}")
lines.append("")

by_layer = {}
for crate, values in crates.items():
    by_layer.setdefault(values["layer"], []).append(crate)

for layer in sorted(by_layer):
    lines.append(f'package "{layer}" as {ident("layer_" + layer)} {{')
    for crate in sorted(by_layer[layer]):
        values = crates[crate]
        stereotype = " <<developer-only>>" if values["developer_only"] else ""
        lines.append(f'  package "{crate}" as {crate_ids[crate]}{stereotype} {{')
        for path in sorted(values["modules"]):
            _, label = values["modules"][path]
            lines.append(
                f'    component "{label}" as {module_ids[(crate, path)]}'
            )
        lines.append("  }")
    lines.append("}")

lines.append("")
for (source, target) in sorted(intra):
    lines.append(
        f"{module_ids[source]} --> {module_ids[target]}"
    )
lines.append("")
for (source, target) in sorted(cross):
    lines.append(f"{crate_ids[source]} ..> {crate_ids[target]}")

lines.append("")
lines.append("legend right")
lines.append("  Generated from cargo metadata and the Rust module graph.")
lines.append("  Solid: `use crate::` inside a crate. Dashed: `use sportcut_*` between crates.")
lines.append("  Edges to sportcut-common are omitted, matching the L3 rule.")
lines.append("endlegend")
lines.append("@enduml")
lines.append("")

with open(out_path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines))

print(
    f"l4-code: {len(crates)} crates, "
    f"{sum(len(values['modules']) for values in crates.values())} modules, "
    f"{len(intra)} intra-crate and {len(cross)} cross-crate edges",
    file=sys.stderr,
)
PY

docker run --rm -v "${REPO_ROOT}:/repo" "${PLANTUML_IMAGE}" \
  -tsvg /repo/build/c4-work/l4-code.puml >/dev/null

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

# The L4 code view is rendered from the module graph, not by Structurizr.
if [ "${MODE}" = "check" ]; then
  if [ ! -f "${OUT_DIR}/l4-code.svg" ] || \
    ! cmp -s "${WORK_DIR}/l4-code.svg" "${OUT_DIR}/l4-code.svg"; then
    failures+=("l4-code.svg")
  fi
else
  cp "${WORK_DIR}/l4-code.svg" "${OUT_DIR}/l4-code.svg"
fi

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
  if [ "${name}" = "l4-code" ]; then
    continue
  fi
  if ! printf '%s\n' "${VIEWS}" | grep -qx "${name}"; then
    rm -f "${stale}"
  fi
done

echo "generate-c4-diagrams: wrote ${OUT_DIR}" >&2
