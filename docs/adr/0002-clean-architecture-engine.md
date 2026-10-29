# ADR-0002: Organise the Rust engine as Clean Architecture layers

| Field | Value |
| --- | --- |
| ID | ADR-0002 |
| Title | Organise the Rust engine as Clean Architecture layers |
| Status | Proposed |
| Date | 2026-10-29 |
| Deciders | Engineering lead (owner), Architecture review |
| Related | [Layering design](../architecture/layering.md), [ADR-0001](0001-rust-background-service.md), [Background service](../architecture/background-service.md), [Service protocol](../architecture/protocol.md) |

## Context

Two delivery mechanisms now drive the same engine: the legacy FFI facade that
the Flutter app links during the ADR-0001 rollout, and the JSON-RPC background
service that replaces it. A third, the headless `sportcut-cli`, runs the
pipeline on a workstation.

The engine grew pipeline-first: crates mirrored the stages, and every caller
reached whichever crate it needed. That worked while there was one caller. With
three, it produced two structural problems:

1. **Use cases depended on the gateway that stores their output.** The media
   pipeline imported `sportcut-storage` to load and save the artifact manifest;
   the job model imported it to read checkpoints and mark artifacts non-final.
   Neither could be exercised without a filesystem, and a second storage backend
   would have changed both.
2. **The use cases lived inside a delivery adapter.** `sportcut-api` holds the
   stage orchestration, the process-wide job store, and the track-artifact
   publication, alongside the FFI DTOs. `sportcut-service` therefore depends on
   `sportcut-api` — one adapter depending on another — and its wire contract is
   shaped by the legacy language-boundary types rather than by the protocol.

The engine also has no written statement of which crate may depend on which.
The build stays green only because every author happened to point the arrows
inward.

## Decision

The Rust workspace is organised as Clean Architecture layers, with dependencies
pointing inward and enforced by a check:

| Layer | Crates | Contract |
| --- | --- | --- |
| Entities | `sportcut-common`, `sportcut-court`, `sportcut-rally`, `sportcut-score`, `sportcut-highlight` | Data and rules over data. No filesystem, process, environment, or network access. |
| Use cases | `sportcut-media`, `sportcut-vision`, `sportcut-export`, `sportcut-jobs`, `sportcut-eval` | Orchestration over entities. Declares the ports it needs; never imports the adapter that implements them. |
| Gateways and contracts | `sportcut-storage`, `sportcut-protocol` | `sportcut-storage` implements the use-case ports over the filesystem. `sportcut-protocol` is the wire contract: pure data. |
| Interface adapters | `sportcut-api`, `sportcut-service` | Translate between a foreign representation (FFI DTOs, JSON-RPC) and the application. |
| Drivers | `sportcut-cli` | Composition root: wires the layers together and owns no rules. |

Three consequences follow, and all three are binding:

- **Ports are declared by the layer that needs them.** `ArtifactStore` is
  declared in `sportcut-media` and implemented by `sportcut-storage`;
  `CheckpointStore` is declared in `sportcut-jobs` and implemented by the same
  gateway. The direction of the source dependency is inward even though the
  call at runtime goes outward.
- **Entities carry no I/O.** Reading the clock is permitted; touching the
  filesystem is not.
- **A delivery adapter owns its own representation.** The FFI DTOs belong to
  `sportcut-api`, the wire types belong to `sportcut-service` and
  `sportcut-protocol`. Neither adapter borrows the other's types, because that
  is precisely the coupling that produced the violation this ADR removes.

`tools/check-layering.sh` enforces the direction, the entity purity rule, and a
declared-exception list. It runs as part of `tools/verify-engine.sh`.

## Declared exception

`sportcut-service` depends on `sportcut-api` today. This is the one
adapter-to-adapter edge in the workspace, and it is temporary:

- **Why it exists.** The engine's use cases live in `sportcut-api`, and the
  `flutter_rust_bridge` generator does not follow `pub use` re-exports, so the
  FFI DTOs must stay *defined* in that crate. The service calls the facade
  because that is where the use cases are.
- **What removes it.** Moving the use cases into a dedicated application crate
  and giving the service its own wire mapping. The protocol becomes the
  service's contract; the FFI DTOs stop being shared. ADR-0001 Phase 5, which
  retires the FFI path, is the latest point at which this is complete.
- **What it costs meanwhile.** The service inherits the legacy DTO shapes, so a
  protocol change and an FFI change cannot be reviewed independently. The
  exception is recorded in the guard with the same removal condition so it
  cannot be forgotten.

## Alternatives considered

**Keep the pipeline-shaped crates and document the intended dependencies.**
Rejected: documentation drifts, and the two real violations already existed
without anyone noticing. A rule with no check is a preference.

**Merge everything into one crate with module-level layering.** Rejected: it
removes the compiler's ability to enforce the boundary, and the engine must
keep building with no client toolchain — crate boundaries are what make that
checkable from the manifest.

**Move the FFI DTOs into a shared contract crate.** Rejected: the
`flutter_rust_bridge` generator scans the modules where items are defined and
does not follow re-exports, so the DTOs must be defined in the crate the
generator is pointed at. Sharing them would break bridge generation, which the
app depends on until Phase 5.

## Consequences

Positive:

- A use case can be tested against a stub store; `sportcut-media` no longer
  needs a match directory on disk to run its unit tests.
- The service and the FFI adapter can evolve their contracts independently as
  soon as the exception is retired.
- A new transport is a new adapter, not a change to the engine.

Costs and risks:

- Ports add indirection at two call sites (`ArtifactStore`, `CheckpointStore`).
- The layer map must be maintained when a crate is added; the check fails
  loudly rather than guessing.
- The exception above keeps one review hazard until the application layer is
  extracted.

## Compliance

- `tools/check-layering.sh` — dependency direction, entity purity, declared
  exceptions.
- `CLAUDE.md` — the working agreement states the rule for new code.
- Code review — a new outward dependency is rejected even if the check is
  bypassed by editing the layer map.
