# L4 — Code (deliberately omitted)

There is no code-level C4 view in this set, by decision rather than omission.

## Why

A code-level view already exists and is enforced:

| Question | Where |
| --- | --- |
| Which layer does a crate belong to, and what may depend on what? | [layering.md](../layering.md) |
| Show me every edge, classified inward / violation / declared | [layering-diagram.html](../layering-diagram.html) (generated from `cargo metadata`) |
| Does the code still obey the rule? | `tools/check-layering.sh`, first step of `tools/verify-engine.sh` |
| What goes over the socket, field by field? | [protocol.md](../protocol.md) and `core/gateways/protocol` |
| Where does each file live? | the crate's `src/lib.rs` module tree |

A hand-maintained class diagram would either duplicate the layering set or drift
from it. The layering view is regenerated from the manifests, so it cannot.

## When to make an exception

Draw an L4 for one component only when its internals are the risk: a state
machine with non-obvious transitions, a retry or recovery path, or a
concurrency protocol. Keep it beside the code that implements it, and link it
from the L3 page rather than adding a fifth global level.

Candidates in this codebase, if one ever needs it:

- the job loop and checkpoint resume in `core/use-cases/jobs`;
- the import/cancel/reconnect supervision in `core/adapters/service`;
- the protocol frame codec in `core/gateways/protocol`.

Until then, the absence of an L4 is the architecture: the layers and the wire
contract carry the constraints, and both are machine-checked.
