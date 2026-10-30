#!/usr/bin/env bash
#
# Check that the C4 workspace still describes this repository.
#
# The workspace DSL is hand-reviewed, so it can drift in two directions: it can
# name a crate, file, or feature folder that no longer exists, and the code can
# grow a crate, dependency, or feature the model never learned about. Both fail
# this check. It also verifies that every view has a committed diagram and that
# the pages link to files that are really there.
#
# Usage:
#   tools/check-c4-model.sh
#
# Exit status is 1 when the model has drifted, 0 when it is current.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"
DSL="${REPO_ROOT}/docs/architecture/c4/workspace.dsl"
C4_DIR="${REPO_ROOT}/docs/architecture/c4"

if ! command -v cargo >/dev/null 2>&1; then
  echo "check-c4-model: cargo is not on PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "check-c4-model: python3 is not on PATH." >&2
  exit 1
fi

if [ ! -f "${DSL}" ]; then
  echo "check-c4-model: no workspace DSL at ${DSL}" >&2
  exit 1
fi

METADATA=$(mktemp)
trap 'rm -f "${METADATA}"' EXIT
(cd "${CORE_DIR}" && cargo metadata --no-deps --format-version 1) >"${METADATA}"

python3 - "${REPO_ROOT}" "${DSL}" "${METADATA}" "${C4_DIR}" <<'PY'
"""Cross-check the C4 workspace against the repository."""

import json
import os
import re
import sys

repo_root, dsl_path, metadata_path, c4_dir = sys.argv[1:5]

with open(dsl_path, encoding="utf-8") as handle:
    text = handle.read()
with open(metadata_path, encoding="utf-8") as handle:
    metadata = json.load(handle)

problems = []


def fail(message):
    problems.append(message)


# Only the declarations that bind an identifier are elements. Views use the
# same `container`/`component` keywords but never assign, so the `=` keeps the
# two apart.
element_pattern = re.compile(
    r'^\s*([A-Za-z_]\w*)\s*=\s*(person|softwareSystem|container|component)\s+(.*)$'
)
relationship_pattern = re.compile(
    r'^\s*([A-Za-z_]\w*)\s*->\s*([A-Za-z_]\w*)\s+"([^"]*)"'
)
view_pattern = re.compile(
    r'^\s*(?:systemContext|container|component)\s+[A-Za-z_]\w*\s+"([^"]+)"',
    re.MULTILINE,
)
property_pattern = re.compile(r'^\s*"([^"]+)"\s+"([^"]+)"\s*$')

elements = {}
properties = {}
current = None
in_properties = False

for raw in text.splitlines():
    line = raw.split("#", 1)[0].rstrip()
    if not line.strip():
        continue
    if in_properties:
        match = property_pattern.match(line)
        if match:
            properties[current][match.group(1)] = match.group(2)
            continue
        in_properties = False
    match = element_pattern.match(line)
    if match:
        identifier, kind, rest = match.group(1), match.group(2), match.group(3)
        strings = re.findall(r'"([^"]*)"', rest)
        if identifier in elements:
            fail(f"duplicate element id '{identifier}'")
        elements[identifier] = {
            "kind": kind,
            "name": strings[0] if strings else "",
            "description": strings[1] if len(strings) > 1 else "",
            "strings": strings,
        }
        properties[identifier] = {}
        current = identifier
        if "properties" in line:
            in_properties = True
        continue
    if line.strip() == "properties {":
        in_properties = True

for identifier, element in elements.items():
    if not element["name"] or not element["description"]:
        fail(f"element '{identifier}' needs a name and a description")
    if element["kind"] in ("container", "component") and len(element["strings"]) < 3:
        fail(f"{element['kind']} '{identifier}' needs a technology")

relationships = []
for raw in text.splitlines():
    line = raw.split("#", 1)[0]
    match = relationship_pattern.match(line)
    if not match:
        continue
    source, target = match.group(1), match.group(2)
    if source not in elements:
        fail(f"relationship endpoint '{source}' names no element")
    if target not in elements:
        fail(f"relationship endpoint '{target}' names no element")
    relationships.append((source, target))

views = view_pattern.findall(text)
if not views:
    fail("the workspace declares no views")

crates = {package["name"] for package in metadata["packages"]}
crate_to_element = {}
for identifier, values in properties.items():
    crate = values.get("crate")
    if not crate:
        continue
    if crate not in crates:
        fail(f"element '{identifier}' names missing crate '{crate}'")
    if crate in crate_to_element:
        fail(f"crate '{crate}' is mapped twice ('{crate_to_element[crate]}' and '{identifier}')")
    crate_to_element[crate] = identifier
for crate in sorted(crates - set(crate_to_element)):
    fail(f"workspace crate '{crate}' is not in the C4 workspace")

for identifier, values in properties.items():
    path = values.get("path")
    if path and not os.path.exists(os.path.join(repo_root, path)):
        fail(f"element '{identifier}' names missing path '{path}'")

features_dir = os.path.join(repo_root, "app/lib/src/features")
if os.path.isdir(features_dir):
    covered = {
        values["path"].rstrip("/")
        for values in properties.values()
        if values.get("path") and "app/lib/src/features/" in values["path"]
    }
    for name in sorted(os.listdir(features_dir)):
        if not os.path.isdir(os.path.join(features_dir, name)):
            continue
        relative = "app/lib/src/features/" + name
        if relative not in covered:
            fail(f"feature folder '{relative}' is not in the C4 workspace")

generated = sorted(
    name[:-4]
    for name in os.listdir(os.path.join(c4_dir, "generated"))
    if name.endswith(".svg")
) if os.path.isdir(os.path.join(c4_dir, "generated")) else []
for view in views:
    if view not in generated:
        fail(f"view '{view}' has no generated diagram (run tools/generate-c4-diagrams.sh)")
for diagram in generated:
    if diagram not in views:
        fail(f"generated diagram '{diagram}.svg' matches no view")

# The service component view models the path dependencies among the crates,
# except the two documented exclusions: edges to sportcut-common (every crate
# may use it) and everything from the developer-only CLI.
hidden_crates = {"sportcut-common"}
excluded_elements = {
    identifier for identifier, values in properties.items() if values.get("excluded") == "true"
}
excluded_crates = {
    properties[identifier]["crate"]
    for identifier in excluded_elements
    if properties[identifier].get("crate")
}

cargo_edges = set()
for package in metadata["packages"]:
    source = package["name"]
    if source in hidden_crates or source in excluded_crates:
        continue
    for dependency in package.get("dependencies", []):
        if dependency.get("path") is None:
            continue
        if (dependency.get("kind") or "normal") != "normal":
            continue
        target = dependency["name"]
        if target not in crates or target in hidden_crates or target in excluded_crates:
            continue
        cargo_edges.add((source, target))

modelled_edges = set()
element_crates = {
    identifier: properties[identifier]["crate"]
    for identifier in properties
    if properties[identifier].get("crate")
}
for source, target in relationships:
    if source in element_crates and target in element_crates:
        modelled_edges.add((element_crates[source], element_crates[target]))

for source, target in sorted(cargo_edges - modelled_edges):
    fail(f"compile-time dependency {source} -> {target} is missing from the C4 workspace")
for source, target in sorted(modelled_edges - cargo_edges):
    fail(f"C4 workspace declares {source} -> {target}, which is not a dependency")

link_pattern = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
for name in sorted(os.listdir(c4_dir)):
    if not name.endswith(".md"):
        continue
    page = os.path.join(c4_dir, name)
    with open(page, encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            for target in link_pattern.findall(line):
                target = target.split("#", 1)[0]
                if not target or "://" in target or target.startswith("mailto:"):
                    continue
                if not os.path.exists(os.path.normpath(os.path.join(c4_dir, target))):
                    fail(f"{name}:{line_number} links to missing '{target}'")

if problems:
    print(f"check-c4-model: {len(problems)} problem(s) in the C4 workspace:", file=sys.stderr)
    for problem in problems:
        print("  - " + problem, file=sys.stderr)
    sys.exit(1)

print(
    f"check-c4-model: OK ({len(elements)} elements, {len(views)} views, "
    f"{len(crates)} crates, {len(modelled_edges)} compile-time edges)"
)
PY
