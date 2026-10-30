# C4 model

Sportcut's architecture drawn at the level you need, from who uses it down to
the crates inside the service. Each level is a page with a diagram and the table
of elements behind it.

The diagrams are generated from [model/workspace.json](model/workspace.json) and
committed as SVG. Nothing in them is drawn by hand, so a picture cannot quietly
disagree with the manifests.

## Read in this order

| Level | Page | Diagram | Answers |
| --- | --- | --- | --- |
| L1 | [01-system-context.md](01-system-context.md) | [l1-system-context.svg](generated/l1-system-context.svg) | Who uses Sportcut, and what it touches outside its own boundary? |
| L2 | [02-containers.md](02-containers.md) | [l2-containers.svg](generated/l2-containers.svg) | What runs where, and who owns the data? |
| L3 | [03-components-service.md](03-components-service.md) | [l3-components-service.svg](generated/l3-components-service.svg) | Which crates make up the service, and how do they depend on each other? |
| L3 | [03-components-client.md](03-components-client.md) | [l3-components-client.svg](generated/l3-components-client.svg) | How is the Flutter client organised, and where does it reach the engine? |
| L4 | [04-code.md](04-code.md) | — (deliberately omitted) | Why there is no code-level C4 view here. |

The SVG files open in any browser and render inline on GitHub. They are
self-contained: no fonts, scripts, or images are fetched from a network.

## How to read a diagram

| Notation | Meaning |
| --- | --- |
| Rounded box | A C4 element: person, software system, container, data store, or component. The second line names its type and technology. |
| Group rectangle | A boundary: a layer, a folder, or a set of tools. It carries no behaviour. |
| Solid dark arrow | A declared relationship. The label is the verb that crosses it. |
| Solid grey arrow | A compile-time dependency read from `cargo metadata`. Only the service component view uses these. |
| Dashed amber arrow | An interim relationship retired by ADR-0001 Phase 4. |
| Dashed box | A note, not an element. |

One arrow is one direction. A relationship that carries traffic both ways is
drawn as two arrows in the text where it matters; in the diagram the verb names
the direction that matters.

## The model

[model/workspace.json](model/workspace.json) is the single source of truth for:

- every element (id, name, C4 type, technology, one-sentence responsibility);
- every declared relationship (from, to, verb, mechanism);
- the layout of each view (which elements appear, where, in which group).

It is not the place for protocol method tables, database schemas, or sequence
flows. Those live in [protocol.md](../protocol.md),
[background-service.md](../background-service.md), and the code.

The model is reviewed like code. An element id is stable once used; a
description stays to one sentence; `technology` names where the thing lives
(crate or path) rather than repeating the description.

### Regenerate and check

```bash
tools/generate-c4-diagrams.sh           # rewrite generated/*.svg
tools/generate-c4-diagrams.sh --check   # fail if the committed SVGs are stale
tools/check-c4-model.sh                 # fail if the model drifted from the code
```

`check-c4-model.sh` verifies the model against the repository: every workspace
crate appears exactly once, every named path exists, every feature folder is
covered, every relationship endpoint exists, every view's diagram is committed,
and every relative link in these pages resolves. Run both commands whenever the
crate graph, a container, or a feature folder changes, and commit the SVGs.

## Why there is no L4

A code-level view already exists and is enforced:
[layering.md](../layering.md) states the rule,
[layering-diagram.html](../layering-diagram.html) is generated from `cargo
metadata`, and `tools/check-layering.sh` fails the build on an outward
dependency. A second L4 drawn here would either duplicate that or drift from it.
[04-code.md](04-code.md) records the decision.

## How this set relates to the others

- **C4** (these pages): what exists, and what talks to what.
- **[layering.md](../layering.md), [background-service.md](../background-service.md), [protocol.md](../protocol.md)**: how each part works.
- **[ADR-0001](../../adr/0001-rust-background-service.md), [ADR-0002](../../adr/0002-clean-architecture-engine.md), [ADR-0003](../../adr/0003-studio-shell-refactor.md)**: why it is shaped this way.
- **[BRD](../../brd/README.md)**: what the product requires; requirements cite architecture, never the other way round.
