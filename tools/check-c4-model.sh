#!/usr/bin/env bash
#
# Check that the C4 model still describes this repository.
#
# The model is hand-reviewed, so it can drift in two directions: it can name a
# crate, file, or feature folder that no longer exists, and the code can grow a
# crate or feature the model never learned about. Both fail this check. It also
# verifies that the committed diagrams exist and that the pages link to files
# that are really there.
#
# Usage:
#   tools/check-c4-model.sh
#
# Exit status is 1 when the model has drifted, 0 when it is current.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"
MODEL="${REPO_ROOT}/docs/architecture/c4/model/workspace.json"
C4_DIR="${REPO_ROOT}/docs/architecture/c4"

if ! command -v cargo >/dev/null 2>&1; then
  echo "check-c4-model: cargo is not on PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "check-c4-model: python3 is not on PATH." >&2
  exit 1
fi

if [ ! -f "${MODEL}" ]; then
  echo "check-c4-model: no model at ${MODEL}" >&2
  exit 1
fi

METADATA=$(mktemp)
trap 'rm -f "${METADATA}"' EXIT
(cd "${CORE_DIR}" && cargo metadata --no-deps --format-version 1) >"${METADATA}"

python3 - "${REPO_ROOT}" "${MODEL}" "${METADATA}" "${C4_DIR}" <<'PY'
"""Cross-check the C4 model against the repository."""

import json
import os
import re
import sys

repo_root, model_path, metadata_path, c4_dir = sys.argv[1:5]

with open(model_path, encoding="utf-8") as handle:
    model = json.load(handle)
with open(metadata_path, encoding="utf-8") as handle:
    metadata = json.load(handle)

problems = []


def fail(message):
    problems.append(message)


TYPES = {"person", "system", "container", "dataStore", "component", "external", "note"}
elements = model.get("elements", [])
views = model.get("views", [])
ids = {}
for element in elements:
    element_id = element.get("id")
    if not element_id:
        fail("an element has no id")
        continue
    if element_id in ids:
        fail(f"duplicate element id '{element_id}'")
    ids[element_id] = element
    if element.get("type") not in TYPES:
        fail(f"element '{element_id}' has unknown type '{element.get('type')}'")
    if not element.get("name") or not element.get("description"):
        fail(f"element '{element_id}' needs a name and a description")
    if element.get("type") != "note" and not element.get("technology"):
        fail(f"element '{element_id}' needs a technology")

group_ids = {group["id"] for view in views for group in view.get("groups", [])}
for relationship in model.get("relationships", []):
    for end in ("from", "to"):
        value = relationship.get(end, "")
        if value.startswith("group:"):
            if value.split(":", 1)[1] not in group_ids:
                fail(f"relationship endpoint '{value}' names no group")
        elif value not in ids:
            fail(f"relationship endpoint '{value}' names no element")
    if not relationship.get("description"):
        fail(f"relationship {relationship.get('from')} -> {relationship.get('to')} has no description")

crates = {package["name"] for package in metadata["packages"]}
mapped = {}
for element in elements:
    crate = element.get("crate")
    if crate is None:
        continue
    if crate not in crates:
        fail(f"element '{element['id']}' names missing crate '{crate}'")
    if crate in mapped:
        fail(f"crate '{crate}' is mapped twice ('{mapped[crate]}' and '{element['id']}')")
    mapped[crate] = element["id"]
for crate in sorted(crates - set(mapped)):
    fail(f"workspace crate '{crate}' is not in the model")

for element in elements:
    path = element.get("path")
    if path and not os.path.exists(os.path.join(repo_root, path)):
        fail(f"element '{element['id']}' names missing path '{path}'")

features_dir = os.path.join(repo_root, "app/lib/src/features")
if os.path.isdir(features_dir):
    covered = {
        element["path"].rstrip("/")
        for element in elements
        if element.get("path") and "app/lib/src/features/" in element["path"]
    }
    for name in sorted(os.listdir(features_dir)):
        directory = os.path.join(features_dir, name)
        if not os.path.isdir(directory):
            continue
        relative = "app/lib/src/features/" + name
        if relative not in covered:
            fail(f"feature folder '{relative}' is not in the model")

in_views = set()
for view in views:
    view_id = view.get("id")
    if not view_id:
        fail("a view has no id")
        continue
    diagram = os.path.join(c4_dir, "generated", view_id + ".svg")
    if not os.path.isfile(diagram):
        fail(f"view '{view_id}' has no generated diagram (run tools/generate-c4-diagrams.sh)")
    for item in view.get("items", []):
        item_id = item.get("id")
        if item_id not in ids:
            fail(f"view '{view_id}' places unknown element '{item_id}'")
        in_views.add(item_id)
    for group in view.get("groups", []):
        for key in ("x", "y", "w", "h"):
            if key not in group:
                fail(f"view '{view_id}' group '{group.get('id')}' misses '{key}'")

for element in elements:
    if element.get("crate") and element["id"] not in in_views:
        fail(f"crate element '{element['id']}' is in no view")

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
    print(f"check-c4-model: {len(problems)} problem(s) in the C4 model:", file=sys.stderr)
    for problem in problems:
        print("  - " + problem, file=sys.stderr)
    sys.exit(1)

print(
    f"check-c4-model: OK ({len(elements)} elements, {len(views)} views, "
    f"{len(crates)} crates)"
)
PY
