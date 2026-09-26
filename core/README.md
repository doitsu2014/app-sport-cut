# Sportcut Native Engine

The engine is a Rust workspace that builds, lints, and tests without any client
toolchain installed. It owns the media foundation, the job model, and the single
facade the Flutter client talks to.

```bash
tools/verify-engine.sh          # from the repository root
```

## Crate layout

| Crate | Path | Responsibility |
| --- | --- | --- |
| `sportcut-common` | `crates/common` | The shared error type, plus the progress and cancellation primitives that let the media pipeline report into a job without depending on the job crate. |
| `sportcut-media` | `crates/media` | Local probing, reduced-resolution proxy generation, analysis audio extraction, and frame sampling. Shells out to the media toolchain behind `MediaToolchain`. |
| `sportcut-storage` | `crates/storage` | The per-match artifact directory, the manifest that records artifacts and references the original recording, and checkpoint persistence. |
| `sportcut-jobs` | `crates/jobs` | Job lifecycle, stage-labelled monotonic progress, cancellation, checkpoint-based resume, and single-heavy-job concurrency. |
| `sportcut-api` | `crates/api` | The FFI facade: DTOs, job handles, and the only surface exposed across `flutter_rust_bridge`. |
| `sportcut-court` | `crates/court` | Placeholder for court homography and side calculation (later phase). |
| `sportcut-vision` | `crates/vision` | Placeholder with the person-detector and pose-estimator trait boundaries that later phases fill in. |
| `sportcut-rally` | `crates/rally` | Placeholder for rally/rest segmentation (later phase). |
| `sportcut-score` | `crates/score` | Placeholder for score suggestion (later phase). |
| `sportcut-highlight` | `crates/highlight` | Placeholder for highlight ranking (later phase). |
| `sportcut-cli` | `cli` | Headless harness (`sportcut-cli`) for developing and benchmarking the pipeline on a workstation. |

The crate boundaries mirror the pipeline stages so later phases fill in
boundaries instead of reshaping them. Only `sportcut-api` is exposed across the
language boundary.

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
