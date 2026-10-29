# Sportcut Native Engine

The engine is a Rust workspace that builds, lints, and tests without any client
toolchain installed. It owns the media foundation, the job model, and the single
facade the Flutter client talks to.

```bash
tools/verify-engine.sh          # from the repository root
```

## Crate layout

The workspace is layered: dependencies point inward, and a use case never
depends on the gateway that implements its port. The layer model, the ports, and
the one declared exception are in
[`docs/architecture/layering.md`](../docs/architecture/layering.md);
`tools/check-layering.sh` enforces them.

| Layer | Crate | Path | Responsibility |
| --- | --- | --- | --- |
| entities | `sportcut-common` | `entities/common` | The shared error type; progress and cancellation primitives; the artifact manifest entities and match-directory layout; the sampled frame the media pipeline produces and vision consumes. |
| entities | `sportcut-court` | `entities/court` | Court homography and side calculation. |
| entities | `sportcut-rally` | `entities/rally` | Rally/rest segmentation. |
| entities | `sportcut-score` | `entities/score` | Score suggestion. |
| entities | `sportcut-highlight` | `entities/highlight` | Highlight ranking. |
| use cases | `sportcut-media` | `use-cases/media` | Local probing, reduced-resolution proxy generation, analysis audio extraction, and frame sampling. Declares the `ArtifactStore` port. |
| use cases | `sportcut-vision` | `use-cases/vision` | Person detection and court-aware tracking behind the `PersonDetector` trait. |
| use cases | `sportcut-export` | `use-cases/export` | Edit-list construction and highlight rendering. |
| use cases | `sportcut-jobs` | `use-cases/jobs` | Job lifecycle, stage-labelled monotonic progress, cancellation, checkpoint-based resume, and single-heavy-job concurrency. Declares the `CheckpointStore` port. |
| use cases | `sportcut-eval` | `use-cases/eval` | Scores player count and rally segmentation against hand labels (`sportcut-cli eval`); see `docs/verification/accuracy-evaluation.md`. |
| gateways | `sportcut-storage` | `gateways/storage` | The per-match artifact directory and manifest persistence, and the checkpoint file. Implements the use-case ports over the filesystem. |
| contracts | `sportcut-protocol` | `gateways/protocol` | Sportcut Service Protocol v1: frames, JSON-RPC subset, handshake, methods, error codes. Data and constants only. |
| adapters | `sportcut-api` | `adapters/api` | The FFI facade: DTOs, job handles, and the only surface exposed across `flutter_rust_bridge`. |
| adapters | `sportcut-service` | `adapters/service` | The background service host that serves the protocol over a Unix socket. |
| drivers | `sportcut-cli` | `drivers/cli` | Headless harness (`sportcut-cli`) for developing and benchmarking the pipeline on a workstation. |

The directory a crate lives in is its layer:

```
core/
  entities/     common  court  rally  score  highlight
  use-cases/    media  vision  export  jobs  eval
  gateways/     storage  protocol
  adapters/     api  service
  drivers/      cli
```

`tools/check-layering.sh` derives each crate's layer from that path, so a crate
moved into the wrong directory is a build-gate failure rather than a slow drift.
Only `sportcut-api` is exposed across the language boundary, and it is retired at
ADR-0001 Phase 5.

## Storage split

The engine owns artifact files; the Flutter application owns the SQLite catalog.
Given a match directory such as
`~/SportcutMatches/<match-id>/`, the engine writes:

```
<match-dir>/
  manifest.json      artifacts, their state, and the original recording reference
  checkpoints.json   completed job stages, so an interrupted job resumes
  proxy/             reduced-resolution analysis proxy
  audio/             low-bitrate analysis audio (absent when the source has none)
  frames/            sampled, timestamped frames
  calibration/       reserved for court calibration (later phase)
  tracks/            reserved for per-frame track data (later phase)
```

The original recording is referenced in place and never copied or modified.
