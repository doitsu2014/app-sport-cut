# Engine layering — design and code

How the Rust workspace under `core/` is designed, and how that design maps onto
crates, modules, and dependencies. This document is normative for `core/`. It
sits inside the service boundary decided by
[ADR-0001](../adr/0001-rust-background-service.md) and formalised by
[ADR-0002](../adr/0002-clean-architecture-engine.md).

## The rule

**Source-code dependencies point inward.**

An outer layer may depend on an inner one. An inner layer may never depend on an
outer one, and a use case may never depend on the gateway that implements its
port. Runtime control flow runs the other way: a driver invokes a use case,
which calls a port, which dispatches to an adapter. The *source* dependency and
the *call* direction are opposites in exactly that one place, and that inversion
is what the rule is for.

Three invariants follow, and all three are checked:

1. **Direction** — no crate depends on a crate in a higher layer.
2. **Purity** — the entity layer takes no filesystem, process, environment, or
   network call.
3. **Peers** — an adapter does not depend on another adapter, except where
   [declared](#declared-exception).

## Layers

Innermost first. The number is the layer index; the directory is where the
crates of that layer live, and `tools/check-layering.sh` derives the layer from
the path rather than from a hand-maintained table. The folder cannot disagree
with the rule, because the folder *is* the rule.

| Layer | Clean Architecture name | Directory | Crates | Responsibility |
| --- | --- | --- | --- | --- |
| 0 | Entities | `core/entities/` | `sportcut-common`, `sportcut-court`, `sportcut-rally`, `sportcut-score`, `sportcut-highlight` | Enterprise rules that would survive a rewrite of the UI, the transport, and the storage format: what an artifact is and when it is stale, court geometry, rally segmentation, rally suggestion identity, scoring and serving, highlight ranking. |
| 1 | Use cases | `core/use-cases/` | `sportcut-media`, `sportcut-vision`, `sportcut-export`, `sportcut-jobs`, `sportcut-eval` | Application-specific rules: probe, proxy, audio, frames; detect and track; render; the job lifecycle and its single-heavy-job limit; accuracy scoring. Each declares the ports it needs. |
| 2 | Gateways and contracts | `core/gateways/` | `sportcut-storage`, `sportcut-protocol` | `sportcut-storage` implements the use-case ports over the filesystem. `sportcut-protocol` encodes the wire contract as data: frames, the JSON-RPC subset, the handshake, method names, error codes. |
| 3 | Interface adapters | `core/adapters/` | `sportcut-service`, `sportcut-api` | `sportcut-service` translates JSON-RPC into a use-case call and back. `sportcut-api` holds the use cases and their DTOs; it is an ordinary library parked here pending a move to `core/use-cases/` — see [Declared exception](#declared-exception). |
| 4 | Frameworks and drivers | `core/drivers/` | `sportcut-cli` | The headless composition root. Wires layers together, owns no rules. |

### What each layer may know

| Layer | May depend on | Must not know |
| --- | --- | --- |
| Entities | `serde`, `thiserror` | Files, processes, environment, sockets, cargo features that select a backend |
| Use cases | Entities, other use cases, `sportcut-common` | Gateways, adapters, transport, the client toolchain |
| Gateways | Entities, use cases (for their port declarations) | Adapters |
| Adapters | Everything inward | Another adapter's representation |
| Drivers | Everything | — |

## Ports

A port is declared by the layer that needs it and implemented by the layer that
can satisfy it. This is the mechanism that keeps the arrow inward while the call
goes outward.

| Port | Declared in | Implemented by | Runtime shape |
| --- | --- | --- | --- |
| `ArtifactStore` | `sportcut-media::pipeline` | `sportcut_storage::MatchDirectory` | The pipeline asks for the manifest and for a path; the adapter owns the directory and the file. |
| `CheckpointStore` | `sportcut-jobs::checkpoint` | `sportcut_storage::CheckpointStore` | The runner reads completed stages and records each stage; the adapter owns `checkpoints.json`. |
| `PersonDetector` | `sportcut-vision` | `sportcut_vision::tflite_detector` (feature-gated) and test doubles | Detection is injected so packaging stays separate from frame, court, and tracking rules. |
| `MediaToolchain` | `sportcut-media::toolchain` | Not an adapter: discovered from the environment | The ffmpeg/ffprobe pair is a value the composition root resolves, not a policy the pipeline owns. |

Because both storage ports are implemented in `sportcut-storage`, that crate
depends on `sportcut-media` and `sportcut-jobs`. The direction is inward, which
the rule allows. Neither use-case crate depends on `sportcut-storage`.

## A request through the layers

A `engine.rally.start` call from the Flutter client:

```
Flutter (Dart)  ── JSON-RPC over AF_UNIX ────────────────────────────┐
                                                                     │
                                              ┌──────────────────────▼──────────┐
   layer 3  adapter                           │  sportcut-service                │
                                              │  wire JSON ↔ engine DTOs         │
                                              └──────────────────────┬──────────┘
                                                                     │
                                              ┌──────────────────────▼──────────┐
   layer 1  use case                          │  sportcut-api                    │
                                              │  rally segmentation use case     │
                                              │  read tracks → segment → publish │
                                              └───────────┬──────────────────────┘
                                                          │
   layer 0  entities       ┌──────────────────────────────▼───────────────────┐
                           │ sportcut-rally: candidates, suggestions           │
                           │ sportcut-jobs: lifecycle, progress, cancellation  │
                           └──────────────────────────────┬───────────────────┘
                                                          │ port
                           ┌──────────────────────────────▼───────────────────┐
   layer 2  gateway        │ sportcut-storage: manifest, tracks, checkpoints,  │
                           │ suggestions on disk                               │
                           └───────────────────────────────────────────────────┘
```

Read the source arrows as pointing up (adapter → use case → entities); read
the calls as pointing down through the port.

## Adapters own their representation

An adapter converts between a foreign representation and the application. It
does not lend its types to another adapter.

- **The wire contract** is `core/gateways/protocol` (`sportcut-protocol`): pure
  data and constants, depending only on serde, shared by both sides.
- **The service adapter** (`core/adapters/service`) owns the mapping between the
  protocol's camelCase JSON and the engine's request and response types. A change
  to the wire is made there and in `protocol.md`, together.
- **The app's client** (`app/lib/src/bridge/protocol_client.dart`) owns the
  other side of the same mapping: framing, the handshake, and its own model
  classes.

There is no generated binding and no shared library between the app and the
engine. The app used to link one; that path is gone.

## Declared exception

| Edge | Why | Removed when |
| --- | --- | --- |
| `sportcut-service` → `sportcut-api` | The use cases live in `sportcut-api`, which is parked in `adapters/` even though it is an ordinary library, not a delivery mechanism. The check treats every edge inside layer 3 as a peer coupling. | `sportcut-api` moves to `core/use-cases/`. Then the edge is adapter → use case, which the rule allows, and the exception is deleted from `tools/check-layering.sh`. |

The exception is listed in `tools/check-layering.sh` with the same condition.
Adding a second one requires a decision recorded in this document first.

### Target state

```
layer 1  core/use-cases/engine   sportcut-engine
                                 use cases + their request/response DTOs,
                                 job store, tracking, rally, export
layer 3  core/adapters/service   → engine: wire JSON ↔ engine DTOs
                                 no adapter-to-adapter edge
```

Nothing else has to change. The crate is already an ordinary library with no
FFI, no generated code, and no client toolchain dependency; moving the directory
and renaming the package is what removes the exception.

An optional refinement, if the use cases should expose domain types rather than
storage records, is to move the remaining artifact formats inward:

1. `RallySuggestions`, `StoredRallyCandidate`, `SuggestionInputs` — **done**;
   they live in `sportcut-rally`.
2. `TrackArtifact` / `TrackProvenance` and `CalibrationSave` — the artifact
   formats move to the entity layer, with the file I/O staying in
   `sportcut-storage`.

## The entity layer is pure

`tools/check-layering.sh` scans `common`, `court`, `rally`, `score`, and
`highlight` for `std::fs`, `std::process`, `std::env`, and `std::net`. A match is
a violation even without a Cargo edge, because it makes the entity untestable
without an environment.

Two things that look like exceptions and are not:

- **Reading the clock is allowed.** An entity may stamp the time it was written.
  Injecting a clock would infect every constructor with a parameter no caller has
  ever needed to vary.
- **Serialization is allowed.** The manifest is `serde`-derived so it can be
  stored, and that representation is also the file format. That is a property of
  the entity, not a dependency on the gateway.

## Composition roots

`sportcut-service` and `sportcut-cli` are the only places allowed to construct
concrete adapters and hand them to use cases. They wire, they do not decide:
a rule that lives in a binary cannot be tested without that binary.

## Adding a crate

1. Put it in the directory for its layer. A new pipeline stage is a use case;
   a new file format is a gateway; a new transport is an adapter.
2. Put it in the directory for that layer. A crate outside
   `entities/`, `use-cases/`, `gateways/`, `adapters/`, or `drivers/` fails the
   check — the guard does not silently ignore the unknown.
3. Depend only on the same layer or lower.
4. If the crate needs something from a higher layer, declare a port in the crate
   that needs it and implement it in the higher layer. Do not add the dependency.

## Running the check

```bash
tools/check-layering.sh
```

It reads `cargo metadata --no-deps` and does not build, so it is cheap enough to
run before every commit. It needs `cargo` and `jq`, and runs as the first step of
`tools/verify-engine.sh`.

## Related

- [Architecture documentation index](README.md) — how this document fits the
  rest of the set.
- [Layer diagram](layering-diagram.html) — a self-contained artifact generated
  from `cargo metadata`: the concentric layers plus every dependency edge
  classified inward / declared / outward. Regenerate it with
  `tools/generate-layering-diagram.sh`; do not hand-edit it.
- [ADR-0002](../adr/0002-clean-architecture-engine.md) — the decision and its
  alternatives.
- [background-service.md](background-service.md) — the service process, the
  protocol, and the no-Rust-in-app boundary.
- [protocol.md](protocol.md) — the wire contract `sportcut-protocol` encodes.
- `CLAUDE.md` — the working agreement that states the rule for new code.
