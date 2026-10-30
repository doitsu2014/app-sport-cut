# Architecture documentation

The architecture set for Sportcut: the C4 model, four design documents, one
decision record set, and the generated diagrams. Each answers a different
question; read the one that matches yours.

## What to read for what question

| Question | Document |
| --- | --- |
| What is the system made of, and what talks to what? | [c4/README.md](c4/README.md) — start here |
| How is the Rust engine organised? What may depend on what? | [layering.md](layering.md) |
| How does the background service run, and who owns the data? | [background-service.md](background-service.md) |
| What exactly goes over the socket? | [protocol.md](protocol.md) |
| How does the app get from FFI to the service, and in what order? | [migration-from-ffi.md](migration-from-ffi.md) |
| Show me the layers with every edge classified | [layering-diagram.html](layering-diagram.html) |
| Why is the backend a separate service? | [ADR-0001](../adr/0001-rust-background-service.md) |
| Why are the crates layered this way? | [ADR-0002](../adr/0002-clean-architecture-engine.md) |

## The set

### [c4/](c4/README.md) — the C4 model

Four levels, each a page with a generated diagram: system context, containers,
components of the service and of the client. The model is
`c4/model/workspace.json`; the SVGs in `c4/generated/` are rendered from it by
`tools/generate-c4-diagrams.sh`, and `tools/check-c4-model.sh` fails when the
model and the code drift apart. Read this first if you are new to the codebase.
The code level (L4) is deliberately omitted in favour of the layering set below.

### [layering.md](layering.md) — engine design

The five layers, the directory each one lives in, the rule that dependencies
point inward, the ports that invert a call, and the one declared exception.
This is the document to read before adding a crate or a dependency.

The rule it states is enforced, not merely recorded: `tools/check-layering.sh`
derives every crate's layer from its directory and fails the build gate on an
outward dependency, a peer dependency between adapters, or a filesystem call in
the entity layer. It runs first in `tools/verify-engine.sh`.

### [background-service.md](background-service.md) — the service

The process model: how the service starts, who owns the endpoint, how a single
instance is guaranteed, how the app supervises it, and how it exits. The data
model: state root, catalog, recording store, artifacts, playback. The security
model: threat model, transport authentication, sandbox file handoff, path
safety. Packaging across the Developer ID and Mac App Store distributions.

Read this to understand what runs where, and what the app is allowed to touch.

### [protocol.md](protocol.md) — the wire contract

The normative contract between the Flutter client and the service: transport
and framing, handshake and version negotiation, the method tables, DTO rules,
error codes, progress and cancellation, limits, and worked examples.

This document is authoritative. `core/gateways/protocol` (`sportcut-protocol`)
is its machine-readable form: pure data and constants, so both sides can share
it without either coupling to the other's implementation.

### [migration-from-ffi.md](migration-from-ffi.md) — how we get there

The phased plan from the current FFI transport to the service, with parity
gates, exit criteria, dual-run switches, rollback, and a complete FFI-removal
checklist. The target is the architecture in the three documents above; the
plan is what turns the current state into it without losing a release.

## How the pieces relate

```
                 ┌──────────────────────────────┐
   Flutter app ──┤ JSON-RPC over a Unix socket  ├── background service
                 └──────────────────────────────┘
                              │
                     protocol.md defines it
                     core/gateways/protocol encodes it
                              │
                              ▼
                 ┌──────────────────────────────┐
                 │  adapters/service            │  delivery
                 │  adapters/api (retiring)     │
                 ├──────────────────────────────┤
                 │  use-cases/*                 │  application
                 ├──────────────────────────────┤
                 │  entities/*                  │  rules
                 └──────────────────────────────┘
                      layering.md governs this
```

The service boundary is ADR-0001. The engine's internal structure is ADR-0002,
and [layering.md](layering.md) is its working description.

## Keeping the set true

- A change to the wire contract is a change to [protocol.md](protocol.md) and to
  `core/gateways/protocol` in the same change.
- A new crate, a new container, or a new feature folder is a change to the
  [C4 model](c4/model/workspace.json). Run `tools/generate-c4-diagrams.sh` and
  `tools/check-c4-model.sh`, then commit the regenerated SVGs.
- A new crate or a new dependency between crates is a change governed by
  [layering.md](layering.md); run `tools/check-layering.sh`.
- A change to the service boundary requires a superseding ADR, not an edit to
  [background-service.md](background-service.md) alone.
- [layering-diagram.html](layering-diagram.html) is generated from the manifests.
  Regenerate it when the crate graph changes; do not hand-edit it.
- The SVGs under [c4/generated/](c4/generated/) are generated too. Edit the
  model, never the picture.
