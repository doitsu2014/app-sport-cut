# Sportcut BRD Suite — Index and Reading Guide

This folder holds the business requirements for Sportcut v1. The suite is one
shared contract (`00-product-context.md`) plus nine feature BRDs. The shared
document fixes objectives, business requirements, design-system requirements,
non-functional requirements, risks, and identifiers; each feature BRD adds its
own functional requirements and evidence.

## Reading order

1. **00-product-context.md** — read first. It defines scope, the autonomy level
   (the engine proposes, the user confirms), the shared IDs, and the release
   gates every feature must cite.
2. **09-studio-shell-jobs-and-settings.md** — read second. The shell, job model,
   and settings cut across all features.
3. **01 through 08** in workflow order — Workspace and Library, Import, Court
   Calibration, Player Tracking, Rally Review, Score, Highlights, Export.

Feature BRDs assume the shared requirements and do not restate them.

## Architecture decision

[ADR-0001](../adr/0001-rust-background-service.md) decides the backend
boundary: the Rust engine, catalog, recording custody, jobs, and export run in a
separate background service, and the Flutter macOS studio is a client that talks
to it over the [service protocol](../architecture/protocol.md). No Rust is
linked into the app; FFI, `flutter_rust_bridge`, generated bridge bindings, and
`libsportcut_api.dylib` are retired. Read the
[target architecture](../architecture/background-service.md) and the
[migration plan](../architecture/migration-from-ffi.md) with it.

The decision supersedes every FFI transport, catalog-ownership, and
recording-custody clause in the feature BRDs. Their **workflow** requirements
are unchanged: the same user flows, confirmations, progress, cancellation,
checkpoints, and artifacts remain valid. The **ownership and transport**
clauses are not unchanged: the catalog is service-owned at schema v6, recording
custody belongs to the service, and the client reaches both only over the
protocol. Each affected feature BRD carries a transport-and-ownership note
that supersedes its older clauses. See the
[service-boundary traceability table](00-product-context.md#151-service-boundary-traceability).

## Documents

| File | Scope | Area ID |
| --- | --- | --- |
| [00-product-context.md](00-product-context.md) | Product BRD and shared contract: objectives, scope, BR, DS, NFR, risks, traceability, approval | — |
| [01-workspace-and-library.md](01-workspace-and-library.md) | Workspaces, match catalog, studio entry, local playback, custody | LIB |
| [02-import-and-media-preparation.md](02-import-and-media-preparation.md) | File import, probe, proxy, analysis audio, frames, manifest, regeneration | IMP |
| [03-court-calibration.md](03-court-calibration.md) | Four-corner marking, orientation, court outline and net, saved calibration | CAL |
| [04-player-tracking.md](04-player-tracking.md) | Local person detection, track review, player count, coverage and gaps | TRK |
| [05-rally-review.md](05-rally-review.md) | Rally/rest suggestions, accept, adjust, dismiss, manual review | RAL |
| [06-score-and-serving.md](06-score-and-serving.md) | One-tap winner confirmation, derived score, serving side | SCR |
| [07-highlights.md](07-highlights.md) | Ranking, keep/remove, trim, reorder, keep-top-N | HLT |
| [08-export.md](08-export.md) | Reel settings, render, progress, success state, share hand-off | EXP |
| [09-studio-shell-jobs-and-settings.md](09-studio-shell-jobs-and-settings.md) | Three-pane shell, toolbar, timeline dock, status bar, jobs, settings | SHL / JOB |

## Shared identifier legend

| Prefix | Meaning | Owner |
| --- | --- | --- |
| `BO-n` | Business objective, with measure and target | 00 |
| `BR-n` | Shared business requirement, with priority and acceptance criterion | 00 |
| `FR-<AREA>-nn` | Feature functional requirement (`AREA` is LIB, IMP, CAL, TRK, RAL, SCR, HLT, EXP, or SHL/JOB) | Feature BRD |
| `DS-n` | Design-system requirement from DESIGN.md, tokens.css, and USAGE.md | 00 |
| `NFR-n` | Non-functional requirement | 00 |
| `R-n` | Risk with likelihood, impact, mitigation, and owner | 00 |
| `Q-n` | Open question with owner and reason it matters | 00 |
| `M-n` | Milestone with exit criterion | 00 |

Priorities are MoSCoW: **Must**, **Should**, **Could**. A Must is a release
blocker.

## Maintenance

- Generated 2026-10-29 from baseline commit `1541c64` and design system v1.0.
- Architecture update 2026-10-29: ADR-0001 moves the backend to a separate Rust
  service and retires the FFI transport. Workflow requirements are unchanged;
  transport, catalog ownership, and recording custody clauses are superseded by
  the transport-and-ownership notes in features 01, 02, 03, 08, and 09. See
  [00-product-context.md](00-product-context.md),
  [§8 NFR-4/NFR-9](00-product-context.md#8-non-functional-requirements), and
  [§15.1 service-boundary traceability](00-product-context.md#151-service-boundary-traceability).
- Change control lives in [00-product-context.md §18](00-product-context.md#18-approval):
  a change to scope, a Must requirement, or the design contract requires a
  version bump and a recorded approval. A service-boundary or transport change
  also requires a superseding ADR.
- The nine feature BRDs own their `FR-<AREA>` requirements and cite this shared
  contract for objectives and cross-cutting requirements.
- Evidence from the analysis, storage, roadmap, dependency-register, and
  verification documents is cited at baseline `1541c64` for provenance. Those
  files are intentionally not part of the working tree; this suite replaces them
  as the requirements source. README/CLAUDE.md references are reconciled under M-1.
- Do not round Partial or Blocked status up to Done. Status and evidence live in
  [00 §3.3](00-product-context.md#33-current-delivery-status).
