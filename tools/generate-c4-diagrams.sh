#!/usr/bin/env bash
#
# Regenerate the C4 diagrams from docs/architecture/c4/model/workspace.json.
#
# The model is the source of truth for elements and declared relationships.
# Compile-time edges in the component view are read from `cargo metadata`, so
# the Rust side of the picture cannot drift from the manifests. Nothing in the
# output is typed by hand: the diagrams are evidence, not illustration.
#
# Usage:
#   tools/generate-c4-diagrams.sh           # write docs/architecture/c4/generated/
#   tools/generate-c4-diagrams.sh --check   # fail if the committed SVGs are stale
#
# Requires cargo and python3. Writes SVGs and nothing else.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"
MODEL="${REPO_ROOT}/docs/architecture/c4/model/workspace.json"
OUT_DIR="${REPO_ROOT}/docs/architecture/c4/generated"

CHECK=0
case "${1:-}" in
  "")
    ;;
  --check)
    CHECK=1
    ;;
  *)
    echo "generate-c4-diagrams: unknown argument '${1}' (expected --check)." >&2
    exit 2
    ;;
esac

if ! command -v cargo >/dev/null 2>&1; then
  echo "generate-c4-diagrams: cargo is not on PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "generate-c4-diagrams: python3 is not on PATH." >&2
  exit 1
fi

if [ ! -f "${CORE_DIR}/Cargo.toml" ]; then
  echo "generate-c4-diagrams: no Cargo workspace at ${CORE_DIR}" >&2
  exit 1
fi

if [ ! -f "${MODEL}" ]; then
  echo "generate-c4-diagrams: no model at ${MODEL}" >&2
  exit 1
fi

METADATA=$(mktemp)
trap 'rm -f "${METADATA}"' EXIT
(cd "${CORE_DIR}" && cargo metadata --no-deps --format-version 1) >"${METADATA}"

python3 - "${MODEL}" "${METADATA}" "${OUT_DIR}" "${CHECK}" <<'PY'
"""Render the C4 model to self-contained SVG.

Deterministic: the same model and manifests produce byte-identical files, so
`--check` can be a plain comparison and a diff is always a real change.
"""

import html
import json
import os
import sys

model_path, metadata_path, out_dir, check_mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"

with open(model_path, encoding="utf-8") as handle:
    model = json.load(handle)
with open(metadata_path, encoding="utf-8") as handle:
    metadata = json.load(handle)

elements = {element["id"]: element for element in model["elements"]}
crate_to_id = {element["crate"]: element["id"] for element in model["elements"] if element.get("crate")}
packages = {package["name"]: package for package in metadata["packages"]}

TYPE_LABEL = {
    "person": "Person",
    "system": "Software system",
    "container": "Container",
    "dataStore": "Data store",
    "component": "Component",
    "external": "External system",
    "note": "Note",
}
FILL = {
    "person": ("#dbe7f0", "#7f9fbf"),
    "system": ("#e3ece6", "#6f9a82"),
    "container": ("#e3ece6", "#6f9a82"),
    "component": ("#ffffff", "#9aa0a6"),
    "external": ("#f4f2ee", "#b9b4a9"),
    "dataStore": ("#f4f2ee", "#b9b4a9"),
    "note": ("#ffffff", "#b9b4a9"),
}
INK = "#1f2328"
MUTED = "#6b7280"
EDGE_STYLE = {
    "declared": ("#3d444d", "none"),
    "derived": ("#8b939c", "none"),
    "interim": ("#a8630a", "6 4"),
}

HEADER = """<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">
<title id="title">{title}</title>
<desc id="desc">{summary}</desc>
<style>
  text {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }}
  .heading {{ font-size: 14px; font-weight: 600; fill: {ink}; }}
  .group-label {{ font-size: 9.5px; font-weight: 600; letter-spacing: 0.09em; fill: {muted}; }}
  .name {{ font-size: 12.5px; font-weight: 600; fill: {ink}; }}
  .tech {{ font-size: 9px; fill: {muted}; }}
  .body {{ font-size: 10px; fill: #3d444d; }}
  .note-body {{ font-size: 10px; fill: {muted}; font-style: italic; }}
  .edge-label {{ font-size: 9.5px; fill: #3d444d; }}
  .legend {{ font-size: 9.5px; fill: {muted}; }}
</style>
<defs>
  <marker id="arrow-declared" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="{declared}"/></marker>
  <marker id="arrow-derived" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="{derived}"/></marker>
  <marker id="arrow-interim" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="{interim}"/></marker>
</defs>
<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff"/>
"""


def esc(value):
    return html.escape(str(value), quote=True)


def wrap(text, max_chars):
    lines = []
    current = ""
    for word in text.split():
        candidate = (current + " " + word).strip()
        if len(candidate) <= max_chars:
            current = candidate
        else:
            if current:
                lines.append(current)
            while len(word) > max_chars:
                lines.append(word[:max_chars])
                word = word[max_chars:]
            current = word
    if current:
        lines.append(current)
    return lines


def layout(element, width):
    """Return the wrapped tech and body lines and the box height."""
    body = element.get("description", "")
    body_chars = max(12, int((width - 26) / 5.55))
    body_lines = wrap(body, body_chars) if body else []
    technology = element.get("technology")
    type_label = TYPE_LABEL[element["type"]]
    if element["type"] == "note":
        tech_lines = []
    else:
        label = "[" + type_label + (": " + technology if technology else "") + "]"
        tech_lines = wrap(label, max(16, int((width - 26) / 4.95)))
    height = 12 + 18 + len(tech_lines) * 12
    if body_lines:
        height += 4 + len(body_lines) * 12.5
    height += 12
    return tech_lines, body_lines, height


def text_block(lines, cx, first_baseline, css_class, line_height):
    out = []
    for index, line in enumerate(lines):
        out.append(
            f'<text class="{css_class}" x="{cx:.1f}" y="{first_baseline + index * line_height:.1f}" '
            f'text-anchor="middle">{esc(line)}</text>'
        )
    return out


def render_node(element_id, rect, element):
    x, y, width, height = rect
    fill, stroke = FILL[element["type"]]
    cx = x + width / 2
    dash = ' stroke-dasharray="5 4"' if element["type"] == "note" else ""
    out = [
        f'<g class="node {element["type"]}">',
        f'<rect x="{x:.1f}" y="{y:.1f}" width="{width:.1f}" height="{height:.1f}" rx="7" '
        f'fill="{fill}" stroke="{stroke}" stroke-width="1.2"{dash}/>',
    ]
    if element["type"] == "note":
        body_lines = wrap(element.get("description", ""), max(12, int((width - 26) / 5.55)))
        out.append(
            f'<text class="name" x="{cx:.1f}" y="{y + 24:.1f}" text-anchor="middle">{esc(element["name"])}</text>'
        )
        out.extend(text_block(body_lines, cx, y + 40, "note-body", 12.5))
        out.append("</g>")
        return "".join(out)

    tech_lines, body_lines, _ = layout(element, width)
    out.append(
        f'<text class="name" x="{cx:.1f}" y="{y + 26:.1f}" text-anchor="middle">{esc(element["name"])}</text>'
    )
    tech_top = y + 26 + 13
    out.extend(text_block(tech_lines, cx, tech_top, "tech", 12))
    body_top = tech_top + len(tech_lines) * 12 + (12 if body_lines else 0)
    out.extend(text_block(body_lines, cx, body_top, "body", 12.5))
    out.append("</g>")
    return "".join(out)


def border_point(rect, target):
    x, y, width, height = rect
    cx, cy = x + width / 2, y + height / 2
    dx, dy = target[0] - cx, target[1] - cy
    if dx == 0 and dy == 0:
        return cx, cy
    scale_x = (width / 2) / abs(dx) if dx else float("inf")
    scale_y = (height / 2) / abs(dy) if dy else float("inf")
    scale = min(scale_x, scale_y)
    return cx + dx * scale, cy + dy * scale


def curve_point(start, control, end, t):
    return (
        (1 - t) ** 2 * start[0] + 2 * (1 - t) * t * control[0] + t ** 2 * end[0],
        (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * control[1] + t ** 2 * end[1],
    )


def straight_route(source_rect, target_rect):
    source_center = (source_rect[0] + source_rect[2] / 2, source_rect[1] + source_rect[3] / 2)
    target_center = (target_rect[0] + target_rect[2] / 2, target_rect[1] + target_rect[3] / 2)
    start = border_point(source_rect, target_center)
    end = border_point(target_rect, source_center)
    control = ((start[0] + end[0]) / 2, (start[1] + end[1]) / 2)
    return start, control, end


def curve_normal(start, control, end, t):
    dx = 2 * (1 - t) * (control[0] - start[0]) + 2 * t * (end[0] - control[0])
    dy = 2 * (1 - t) * (control[1] - start[1]) + 2 * t * (end[1] - control[1])
    length = (dx * dx + dy * dy) ** 0.5
    if length == 0:
        return 0.0, 0.0
    return -dy / length, dx / length


def overlap_area(first, second):
    ax, ay, aw, ah = first
    bx, by, bw, bh = second
    overlap_x = min(ax + aw, bx + bw) - max(ax, bx)
    overlap_y = min(ay + ah, by + bh) - max(ay, by)
    return overlap_x * overlap_y if overlap_x > 0 and overlap_y > 0 else 0


def curve_tangent(start, control, end, t):
    dx = 2 * (1 - t) * (control[0] - start[0]) + 2 * t * (end[0] - control[0])
    dy = 2 * (1 - t) * (control[1] - start[1]) + 2 * t * (end[1] - control[1])
    length = (dx * dx + dy * dy) ** 0.5
    if length == 0:
        return 0.0, 0.0
    return dx / length, dy / length


def place_label(start, control, end, lines, boxes, placed, width, height):
    """Find the clearest spot for an edge label inside the canvas."""
    label_width = max(len(line) for line in lines) * 4.9 + 10
    label_height = 8 + len(lines) * 11
    best_rect, best_score = None, None
    for t in (0.5, 0.42, 0.58, 0.34, 0.66, 0.26, 0.74, 0.18, 0.82):
        point = curve_point(start, control, end, t)
        nx, ny = curve_normal(start, control, end, t)
        tx, ty = curve_tangent(start, control, end, t)
        for offset in (16, -16, 26, -26, 38, -38, 52, -52, 68, -68, 86, -86, 104, -104):
            for shift in (0, 34, -34, 60, -60, 90, -90):
                cx = point[0] + nx * offset + tx * shift
                cy = point[1] + ny * offset + ty * shift
                rect = (cx - label_width / 2, cy - label_height / 2, label_width, label_height)
                if rect[0] < 8 or rect[1] < 40:
                    continue
                if rect[0] + label_width > width - 8 or rect[1] + label_height > height - 40:
                    continue
                score = sum(overlap_area(rect, box) for box in boxes.values())
                score += sum(overlap_area(rect, other) for other in placed)
                if score == 0:
                    return rect
                if best_score is None or score < best_score:
                    best_rect, best_score = rect, score
    return best_rect


def render_edge(start, control, end, kind, label, label_rect):
    color, dash = EDGE_STYLE[kind]
    out = [
        f'<path d="M {start[0]:.1f} {start[1]:.1f} Q {control[0]:.1f} {control[1]:.1f} '
        f'{end[0]:.1f} {end[1]:.1f}" fill="none" stroke="{color}" stroke-width="1.3"'
        + (f' stroke-dasharray="{dash}"' if dash != "none" else "")
        + f' marker-end="url(#arrow-{kind})"/>'
    ]
    if label and label_rect:
        x, y, width, height = label_rect
        out.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{width:.1f}" height="{height:.1f}" '
            f'rx="3" fill="#ffffff" fill-opacity="0.94"/>'
        )
        for index, line in enumerate(label):
            out.append(
                f'<text class="edge-label" x="{x + width / 2:.1f}" y="{y + 11 + index * 11:.1f}" '
                f'text-anchor="middle">{esc(line)}</text>'
            )
    return "".join(out)


def view_boxes(view):
    boxes, groups = {}, {}
    for group in view.get("groups", []):
        groups[group["id"]] = (group["x"], group["y"], group["w"], group["h"])
    for item in view["items"]:
        element = elements[item["id"]]
        tech_lines, body_lines, height = layout(element, item["w"])
        boxes[item["id"]] = (item["x"], item["y"], item["w"], height)
    return boxes, groups


def view_edges(view, boxes):
    edges = []
    seen = set()
    for relationship in model.get("relationships", []):
        source, target = relationship["from"], relationship["to"]
        if source.startswith("group:"):
            if source.split(":", 1)[1] not in {
                group["id"] for group in view.get("groups", [])
            }:
                continue
        elif source not in boxes:
            continue
        if target.startswith("group:"):
            if target.split(":", 1)[1] not in {
                group["id"] for group in view.get("groups", [])
            }:
                continue
        elif target not in boxes:
            continue
        kind = "interim" if relationship.get("interim") else "declared"
        edges.append((source, target, kind, relationship.get("description", "")))
        seen.add((source, target))
    if view.get("deriveCrateEdges"):
        hidden_to = set(view.get("hideCrateEdgesTo", []))
        hidden_from = set(view.get("hideCrateEdgesFrom", []))
        for package_name in sorted(packages):
            if package_name not in crate_to_id:
                continue
            source_id = crate_to_id[package_name]
            if source_id not in boxes or package_name in hidden_from:
                continue
            for dependency in packages[package_name].get("dependencies", []):
                if dependency.get("path") is None:
                    continue
                if (dependency.get("kind") or "normal") != "normal":
                    continue
                dependency_name = dependency["name"]
                if dependency_name in hidden_to or dependency_name not in crate_to_id:
                    continue
                target_id = crate_to_id[dependency_name]
                if target_id not in boxes or target_id == source_id:
                    continue
                if (source_id, target_id) in seen:
                    continue
                edges.append((source_id, target_id, "derived", ""))
                seen.add((source_id, target_id))
    edges.sort(key=lambda edge: (edge[2], edge[0], edge[1]))
    return edges


def render_view(view):
    boxes, groups = view_boxes(view)
    all_boxes = dict(boxes)
    for group_id, rect in groups.items():
        all_boxes["group:" + group_id] = rect

    width = view["width"]
    height = view["height"] + 46
    parts = [
        HEADER.format(
            width=width,
            height=height,
            title=esc(model["title"] + " — " + view["title"]),
            summary=esc(view.get("summary", "")),
            ink=INK,
            muted=MUTED,
            declared=EDGE_STYLE["declared"][0],
            derived=EDGE_STYLE["derived"][0],
            interim=EDGE_STYLE["interim"][0],
        ),
        f'<text class="heading" x="24" y="26">{esc(view["level"] + " · " + view["title"])}</text>',
    ]

    for group in view.get("groups", []):
        parts.append(
            f'<rect x="{group["x"]}" y="{group["y"]}" width="{group["w"]}" height="{group["h"]}" '
            f'rx="10" fill="#fbfaf7" stroke="#d8d5cd" stroke-width="1"/>'
        )
        parts.append(
            f'<text class="group-label" x="{group["x"] + 14:.1f}" y="{group["y"] + 18:.1f}">'
            f'{esc(group["label"].upper())}</text>'
        )

    kinds = set()
    placed_labels = []
    parts.append('<g class="edges">')
    for source_id, target_id, kind, label in view_edges(view, boxes):
        kinds.add(kind)
        source_rect = all_boxes.get(source_id) or all_boxes["group:" + source_id.split(":", 1)[1]]
        target_rect = all_boxes.get(target_id) or all_boxes["group:" + target_id.split(":", 1)[1]]
        start, control, end = straight_route(source_rect, target_rect)
        lines = wrap(label, 26) if label else []
        label_rect = (
            place_label(start, control, end, lines, boxes, placed_labels, width, view["height"])
            if lines
            else None
        )
        if label_rect:
            placed_labels.append(label_rect)
        parts.append(render_edge(start, control, end, kind, lines, label_rect))
    parts.append("</g>")

    parts.append('<g class="nodes">')
    for item in view["items"]:
        parts.append(render_node(item["id"], boxes[item["id"]], elements[item["id"]]))
    parts.append("</g>")

    legend = [
        ("declared", "Declared relationship"),
        ("derived", "Compile-time dependency (cargo metadata)"),
        ("interim", "Interim until ADR-0001 Phase 4"),
    ]
    baseline = view["height"] + 26
    parts.append(f'<line x1="24" y1="{view["height"] + 8}" x2="{width - 24}" y2="{view["height"] + 8}" stroke="#e5e2da"/>')
    x = 24
    for kind, text in legend:
        if kind not in kinds:
            continue
        color = EDGE_STYLE[kind][0]
        dash = ' stroke-dasharray="6 4"' if EDGE_STYLE[kind][1] != "none" else ""
        parts.append(f'<line x1="{x}" y1="{baseline - 3}" x2="{x + 26}" y2="{baseline - 3}" stroke="{color}" stroke-width="1.3"{dash}/>')
        parts.append(f'<text class="legend" x="{x + 32}" y="{baseline}">{esc(text)}</text>')
        x += 32 + len(text) * 5.1 + 26
    parts.append("</svg>")
    return "".join(parts)


failures = []
os.makedirs(out_dir, exist_ok=True)
for view in model["views"]:
    target = os.path.join(out_dir, view["id"] + ".svg")
    rendered = render_view(view)
    if check_mode:
        try:
            with open(target, encoding="utf-8") as handle:
                current = handle.read()
        except FileNotFoundError:
            current = None
        if current != rendered:
            failures.append(view["id"] + ".svg")
    else:
        with open(target, "w", encoding="utf-8") as handle:
            handle.write(rendered)

if check_mode:
    if failures:
        sys.stderr.write(
            "generate-c4-diagrams: stale diagram(s): " + ", ".join(failures) + "\n"
            "Run tools/generate-c4-diagrams.sh and commit the result.\n"
        )
        sys.exit(1)
    sys.stderr.write("generate-c4-diagrams: all diagrams are current.\n")
else:
    sys.stderr.write(
        "generate-c4-diagrams: wrote " + str(len(model["views"])) + " diagrams to " + out_dir + "\n"
    )
PY
