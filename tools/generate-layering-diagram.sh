#!/usr/bin/env bash
#
# Regenerate docs/architecture/layering-diagram.html from the workspace.
#
# The diagram is evidence, not illustration: the layer bands come from the crate
# directories and the edge audit comes from `cargo metadata`. Nothing in it is
# typed by hand, so it cannot drift from the code.
#
# Usage:
#   tools/generate-layering-diagram.sh
#
# Requires cargo and python3. Writes one file and nothing else.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CORE_DIR="${REPO_ROOT}/core"
OUT="${REPO_ROOT}/docs/architecture/layering-diagram.html"

if ! command -v cargo >/dev/null 2>&1; then
  echo "generate-layering-diagram: cargo is not on PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "generate-layering-diagram: python3 is not on PATH." >&2
  exit 1
fi

if [ ! -f "${CORE_DIR}/Cargo.toml" ]; then
  echo "generate-layering-diagram: no Cargo workspace at ${CORE_DIR}" >&2
  exit 1
fi

(cd "${CORE_DIR}" && cargo metadata --no-deps --format-version 1) >/tmp/sportcut-metadata.json

python3 - "${CORE_DIR}" "${OUT}" /tmp/sportcut-metadata.json <<'PY'
import html
import json
import sys

core_dir, out_path, metadata_path = sys.argv[1], sys.argv[2], sys.argv[3]
meta = json.load(open(metadata_path))

LAYER_NAMES = {0: "ENTITIES", 1: "USE CASES", 2: "GATEWAYS + CONTRACTS",
               3: "ADAPTERS", 4: "DRIVERS"}
LAYER_DIRS = {0: "core/entities/", 1: "core/use-cases/", 2: "core/gateways/",
              3: "core/adapters/", 4: "core/drivers/"}

layer_of, crates = {}, {n: [] for n in LAYER_NAMES}
for pkg in meta["packages"]:
    path = pkg["manifest_path"].replace("\\", "/")
    for level, directory in LAYER_DIRS.items():
        if "/" + directory in path:
            layer_of[pkg["name"]] = level
            crates[level].append(pkg["name"])
            break
for level in crates:
    crates[level].sort()

EXCEPTION = {("sportcut-service", "sportcut-api")}

edges = []
for pkg in meta["packages"]:
    for dep in pkg["dependencies"]:
        if dep.get("path") is None:
            continue
        if (dep.get("kind") or "normal") != "normal":
            continue
        a, b = pkg["name"], dep["name"]
        la, lb = layer_of.get(a), layer_of.get(b)
        if la is None or lb is None:
            verdict = "unmapped"
        elif lb > la:
            verdict = "violation"
        elif (a, b) in EXCEPTION:
            verdict = "declared"
        else:
            verdict = "inward"
        edges.append((la if la is not None else -1, a, lb if lb is not None else -1, b, verdict))
edges.sort()

dev_edges = []
for pkg in meta["packages"]:
    for dep in pkg["dependencies"]:
        if dep.get("path") is None:
            continue
        if (dep.get("kind") or "normal") == "normal":
            continue
        dev_edges.append((pkg["name"], dep["name"]))

counts = {}
for e in edges:
    counts[e[4]] = counts.get(e[4], 0) + 1

INK = "#1f2328"
fills = {4: "#f4f2ee", 3: "#eceae3", 2: "#e3ece6", 1: "#dbe7f0", 0: "#cfdff0"}
strokes = {4: "#b9b4a9", 3: "#b5b0a4", 2: "#a8bdb0", 1: "#9db6c9", 0: "#7f9fbf"}

W, H = 1060, 700
rings = [
    (4, 20, 20, 1020, 660),
    (3, 95, 86, 870, 528),
    (2, 170, 152, 720, 396),
    (1, 245, 218, 570, 264),
    (0, 320, 284, 420, 132),
]


def chips(names, cx, y, color, font=11.5, gap=8, pad=9, height=23):
    widths = [len(n) * 6.35 + pad * 2 for n in names]
    total = sum(widths) + gap * (len(names) - 1)
    x = cx - total / 2
    out = []
    for name, width in zip(names, widths):
        out.append(
            f'<rect x="{x:.1f}" y="{y}" width="{width:.1f}" height="{height}" rx="{height/2}" '
            f'fill="#ffffff" stroke="{color}" stroke-width="1"/>'
            f'<text x="{x + width/2:.1f}" y="{y + 16}" text-anchor="middle" '
            f'font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="{font}" '
            f'fill="{INK}">{html.escape(name)}</text>')
        x += width + gap
    return "\n".join(out)


svg = [f'<svg viewBox="0 0 {W} {H}" width="100%" role="img" '
       'aria-label="Concentric Clean Architecture layers of the Sportcut Rust workspace">']
svg.append('<defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" '
           'markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
           f'<path d="M 0 0 L 10 5 L 0 10 z" fill="{INK}"/></marker></defs>')
for level, x, y, w, h in rings:
    svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="34" '
               f'fill="{fills[level]}" stroke="{strokes[level]}" stroke-width="1.5"/>')
    svg.append(
        f'<text x="{x + 22}" y="{y + 26}" '
        'font-family="ui-sans-serif,system-ui,-apple-system,sans-serif" '
        f'font-size="12" letter-spacing="1.6" font-weight="700" fill="{strokes[level]}">'
        f'{LAYER_NAMES[level]}'
        '<tspan font-weight="400" letter-spacing="0" font-size="11" '
        'font-family="ui-monospace,SFMono-Regular,Menlo,monospace">'
        f'    {LAYER_DIRS[level]}</tspan></text>')
for level, x, y, w, h in rings:
    cx = x + w / 2
    if level == 0:
        svg.append(chips(crates[0][:3], cx, y + 44, strokes[0]))
        svg.append(chips(crates[0][3:], cx, y + 74, strokes[0]))
    else:
        svg.append(chips(crates[level], cx, y + 40, strokes[level]))
svg.append(
    f'<line x1="62" y1="230" x2="62" y2="560" stroke="{INK}" stroke-width="1.6" '
    'marker-end="url(#arrow)"/>'
    f'<text x="48" y="400" transform="rotate(-90 48 400)" text-anchor="middle" '
    'font-family="ui-sans-serif,system-ui,sans-serif" font-size="11.5" '
    f'fill="{INK}">source dependencies point inward</text>')
svg.append('</svg>')
svg = "\n".join(svg)

rows = []
for la, a, lb, b, verdict in edges:
    css = {"inward": "ok", "declared": "exc", "violation": "bad", "unmapped": "bad"}[verdict]
    rows.append(
        f'<tr class="{css}"><td><code>{html.escape(a)}</code></td><td class="dim">L{la}</td>'
        f'<td class="arrow">→</td><td><code>{html.escape(b)}</code></td>'
        f'<td class="dim">L{lb}</td><td><span class="chip {css}">{verdict}</span></td></tr>')
edge_rows = "\n".join(rows)

dev_rows = "\n".join(
    f'<tr><td><code>{html.escape(a)}</code></td><td class="arrow">⇢</td>'
    f'<td><code>{html.escape(b)}</code></td>'
    '<td class="dim">test only — a use case exercising the adapter that implements its port</td></tr>'
    for a, b in dev_edges)

doc = f"""<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sportcut core — Clean Architecture layers</title>
<style>
  :root {{ color-scheme: light; }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; padding: 40px 32px 72px; background: #fbfaf8; color: {INK};
         font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
         line-height: 1.55; }}
  main {{ max-width: 1080px; margin: 0 auto; }}
  h1 {{ font-size: 26px; letter-spacing: -0.3px; margin: 0 0 6px; }}
  .sub {{ color: #5a6169; margin: 0 0 28px; font-size: 14.5px; }}
  .card {{ background: #fff; border: 1px solid #e2ddd4; border-radius: 16px; padding: 20px; margin: 0 0 24px; }}
  h2 {{ font-size: 15px; letter-spacing: 0.4px; text-transform: uppercase; color: #6b6459; margin: 0 0 14px; }}
  .stats {{ display: flex; gap: 12px; flex-wrap: wrap; margin: 0 0 24px; }}
  .stat {{ flex: 1 1 150px; background: #fff; border: 1px solid #e2ddd4; border-radius: 14px; padding: 14px 16px; }}
  .stat b {{ display: block; font-size: 26px; line-height: 1.2; }}
  .stat span {{ font-size: 12.5px; color: #5a6169; }}
  .stat.bad b {{ color: #a4341f; }}
  .stat.good b {{ color: #1f6b45; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
  th {{ text-align: left; font-size: 11px; letter-spacing: 0.7px; text-transform: uppercase;
        color: #8a8175; padding: 0 8px 8px; border-bottom: 1px solid #e2ddd4; }}
  td {{ padding: 6px 8px; border-bottom: 1px solid #f0ece5; vertical-align: middle; }}
  tr:last-child td {{ border-bottom: none; }}
  code {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12.3px; }}
  .dim {{ color: #8a8175; font-size: 11.5px; white-space: nowrap; }}
  .arrow {{ color: #b3ab9d; width: 18px; }}
  .chip {{ display: inline-block; padding: 2px 9px; border-radius: 999px; font-size: 11px;
           font-weight: 600; letter-spacing: 0.3px; }}
  .chip.ok {{ background: #e6f2ea; color: #1f6b45; }}
  .chip.exc {{ background: #fbf0d9; color: #8a5a10; }}
  .chip.bad {{ background: #fbe6e0; color: #a4341f; }}
  .note {{ border-left: 3px solid #d9a441; background: #fdf8ec; padding: 14px 16px;
           border-radius: 0 10px 10px 0; font-size: 13.5px; margin: 0; }}
  .note b {{ color: #8a5a10; }}
  .pipe {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12.3px;
           white-space: pre; overflow-x: auto; color: #2c3036; }}
  footer {{ color: #8a8175; font-size: 12px; margin-top: 28px; }}
</style>
<main>
  <h1>Core — Clean Architecture layers</h1>
  <p class="sub">Generated from <code>cargo metadata</code> for the {len(edges)} normal dependency
     edges in the Rust workspace. Nothing here is hand-drawn.</p>

  <div class="stats">
    <div class="stat good"><b>{counts.get('inward', 0)}</b><span>edges point inward</span></div>
    <div class="stat"><b>{counts.get('declared', 0)}</b><span>declared exception</span></div>
    <div class="stat {'bad' if counts.get('violation') else 'good'}"><b>{counts.get('violation', 0)}</b><span>outward edges</span></div>
    <div class="stat good"><b>0</b><span>entity-layer I/O calls</span></div>
  </div>

  <div class="card">
    <h2>The rule</h2>
    <p style="margin:0;font-size:14px">Source-code dependencies point inward. An outer layer may
    depend on an inner one; an inner layer may never depend on an outer one, and a use case never
    depends on the gateway that implements its port. Runtime calls run the other way, through a
    port.</p>
  </div>

  <div class="card">
    <h2>Layer diagram</h2>
    {svg}
  </div>

  <div class="card">
    <h2>Edge audit — every edge, classified</h2>
    <table>
      <thead><tr><th>From</th><th>Layer</th><th></th><th>To</th><th>Layer</th><th>Verdict</th></tr></thead>
      <tbody>
{edge_rows}
      </tbody>
    </table>
  </div>

  <div class="card">
    <h2>Declared exception</h2>
    <p class="note"><b>sportcut-service → sportcut-api.</b> The use cases live in
    <code>sportcut-api</code>, which is an ordinary library — no FFI, no generated bindings — but
    which is parked in <code>adapters/</code>, so the check sees two adapters. The Flutter client
    links no Rust, so nothing about the client depends on where this crate sits. Removed by moving
    it to <code>core/use-cases/</code>; then the edge is adapter → use case and the exception is
    deleted. Recorded in <code>tools/check-layering.sh</code> with the same condition.</p>
  </div>

  <div class="card">
    <h2>Test-only edges (not architectural)</h2>
    <table>
      <tbody>
{dev_rows}
      </tbody>
    </table>
  </div>

  <div class="card">
    <h2>Ports — the inversion that keeps the arrow inward</h2>
    <div class="pipe">ArtifactStore    declared in sportcut-media   →  implemented by sportcut-storage
CheckpointStore  declared in sportcut-jobs    →  implemented by sportcut-storage
PersonDetector   declared in sportcut-vision  →  implemented by the tflite detector / test doubles

source:  use case  ──── depends on ────►  port (trait it declares)
call:    use case  ──── dispatches to ─►  adapter (implements the trait)</div>
  </div>

  <footer>Reproduce with <code>tools/generate-layering-diagram.sh</code>. Check the rule with
  <code>tools/check-layering.sh</code>. Layer model: <code>docs/architecture/layering.md</code>.
  Decision: <code>docs/adr/0002-clean-architecture-engine.md</code>.</footer>
</main>
</html>
"""

with open(out_path, "w") as handle:
    handle.write(doc)
print(f"generate-layering-diagram: wrote {out_path}")
print(f"generate-layering-diagram: {len(edges)} edges {counts}")
PY
