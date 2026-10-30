# C4 model

Sportcut's architecture as a [Structurizr](https://structurizr.com) workspace:
one model, four views, each answering a different question. Every diagram is
rendered from the same `workspace.dsl`, so the pictures cannot disagree with
each other.

## Read in this order

| Level | Page | Diagram | Answers |
| --- | --- | --- | --- |
| L1 | [01-system-context.md](01-system-context.md) | [l1-system-context.svg](generated/l1-system-context.svg) | Who uses Sportcut, and what it touches outside its own boundary? |
| L2 | [02-containers.md](02-containers.md) | [l2-containers.svg](generated/l2-containers.svg) | What runs where, and who owns the data? |
| L3 | [03-components-service.md](03-components-service.md) | [l3-components-service.svg](generated/l3-components-service.svg) | Which crates make up the service, and how do they depend on each other? |
| L3 | [03-components-client.md](03-components-client.md) | [l3-components-client.svg](generated/l3-components-client.svg) | How is the Flutter client organised, and where does it reach the engine? |
| L4 | [04-code.md](04-code.md) | — (deliberately omitted) | Why there is no code-level C4 view here. |

The SVGs open in any browser, render inline on GitHub, and need no network: the
renderer embeds its fonts and styles.

## How to read a diagram

| Notation | Meaning |
| --- | --- |
| Rounded box | A C4 element: person, software system, container, data store, or component. The bracket names its type and technology. |
| Boundary box | A C4 group: a layer, a folder, or a set of tools. It carries no behaviour. |
| Arrow | A declared relationship. The label is the verb that crosses it, and the technology is the mechanism. |
| «Person», «External», «Database» | Structurizr tags. They shape the icon and colour; the text always wins. |

One arrow is one direction. The service component view is dense by design: its
arrows are the compile-time dependencies between crates.

## The workspace

[workspace.dsl](workspace.dsl) is the single source of truth for:

- every element (name, C4 type, technology, one-sentence responsibility);
- every declared relationship (from, to, verb, mechanism);
- every view (which elements appear, in which group).

It does not hold protocol method tables, database schemas, or sequence flows.
Those live in [protocol.md](../protocol.md),
[background-service.md](../background-service.md), and the code.

Two properties bind the model to the repository:

| Property | Meaning | Checked by |
| --- | --- | --- |
| `"crate"` | The service component's Cargo package | `tools/check-c4-model.sh` |
| `"path"` | The client component's folder or file | `tools/check-c4-model.sh` |
| `"excluded" "true"` | Shown in the model but kept out of the rendered views (the developer-only CLI) | The generator's view expression and the checker |

### Regenerate and check

```bash
tools/generate-c4-diagrams.sh --pull    # once per machine: fetch the pinned images
tools/generate-c4-diagrams.sh           # rewrite generated/*.svg
tools/generate-c4-diagrams.sh --check   # fail if the committed SVGs are stale
tools/check-c4-model.sh                 # fail if the workspace drifted from the code
```

Rendering runs in two pinned Docker images:

| Tool | Image | Licence |
| --- | --- | --- |
| Structurizr | `structurizr/structurizr:2026.10.26` | Apache-2.0 |
| PlantUML (with the MIT C4-PlantUML stdlib) | `plantuml/plantuml:1.2026.9` | LGPL-3.0 |

Both are dev-only and never ship. The tags are pinned because the SVGs are
committed and `--check` compares bytes: a renderer upgrade is a reviewed change,
not a silent drift. After the first `--pull`, generation is offline.

`check-c4-model.sh` verifies the workspace against the repository:

- every workspace crate is mapped exactly once, and every named path exists;
- every feature folder under `app/lib/src/features/` is covered;
- the component view's crate relationships match `cargo metadata` in both
  directions — no missing dependency, no invented one;
- every view has a committed diagram and no diagram matches a missing view;
- every relative link in these pages resolves.

Run both commands whenever the crate graph, a container, or a feature folder
changes, and commit the regenerated SVGs.

## Why there is no L4

A code-level view already exists and is enforced:
[layering.md](../layering.md) states the rule,
[layering-diagram.html](../layering-diagram.html) is generated from `cargo
metadata`, and `tools/check-layering.sh` fails the build on an outward
dependency. A second L4 in the workspace would either duplicate that or drift
from it. [04-code.md](04-code.md) records the decision.

## How this set relates to the others

- **C4** (these pages): what exists, and what talks to what.
- **[layering.md](../layering.md), [background-service.md](../background-service.md), [protocol.md](../protocol.md)**: how each part works.
- **[ADR-0001](../../adr/0001-rust-background-service.md), [ADR-0002](../../adr/0002-clean-architecture-engine.md), [ADR-0003](../../adr/0003-studio-shell-refactor.md)**: why it is shaped this way.
- **[BRD](../../brd/README.md)**: what the product requires; requirements cite architecture, never the other way round.
