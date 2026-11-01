# Deployment Runbook — Player Tracking (Feature 04)

Status: Launch / Deployment Automation
Intent: `261031-implement-04-player`
Date: 2026-11-01
Inputs: `ci-config.md`, `technical-spec.md`.

## 1. Environments

| Environment | What it is | Difference |
| --- | --- | --- |
| Developer workstation | `tools/run-service.sh` / `tools/run-macos.sh`; debug or release service | May use `matchDir` over the dev transport; temporary state root |
| Packaged macOS bundle | `sportcut.app` with `Contents/Helpers/SportcutService` and the inference assets | Service resolves every match under the app state root; `matchDir` rejected; assets are service-owned |

There is no server, staging, or cloud environment. The product is local-only
and offline.

## 2. Preconditions

- macOS on Apple silicon, Rust toolchain ≥ 1.80, `ffmpeg`/`ffprobe` on PATH.
- `third_party/inference/libtensorflowlite_c.dylib` and `model.tflite` present
  and matching the pinned fingerprints (`tools/fetch-inference-assets.sh`).
- Flutter toolchain only for packaging the app; the engine build does not need
  it.
- **Release block:** the EfficientDet redistribution verdict is still
  contradictory and U6's embed guard is not implemented. Do not ship a release
  bundle until S2 is reconciled (C-02/C-21).

## 3. Deploy steps (packaged bundle)

1. `tools/build-service.sh` — release service with `macos-tflite-eval` on macOS.
   Confirm `core/target/release/sportcut-service --version` reports the feature.
2. `tools/embed-service.sh <app>` — copy and sign
   `Contents/Helpers/SportcutService`.
3. `tools/embed-inference-assets.sh <app>` — copy the runtime and model into
   `Contents/Frameworks` and `Contents/Resources`.
4. `tools/package-macos.sh` — build/sign/package the app.
5. Launch the app and open a match.

The service build was exercised in this intent (0.1.0, `macos-tflite-eval`);
full bundle packaging was not re-run here because it needs the Flutter release
toolchain and signing. The scripts are unchanged by this intent.

## 4. Health and readiness

- `sportcut-service --version` reports `features: macos-tflite-eval`.
- `service.hello` / `service.health` succeed; `engine.tracking.start` accepts a
  config and rejects a client `runtimePath`/`modelPath`.
- A completed tracking artifact is schema 1, carries `review.fragmentation`, and
  the window DTO carries `countSupportingFrames` and `trackQuality`.
- The Player analysis panel shows “Count quality” (not “Coverage”) and, when the
  count is Unknown, its supporting frames and evidence interval.
- A completed rally suggestion set validates and partitions the recording.

## 5. Post-deploy verification

```bash
core/target/release/sportcut-service --version
tools/check-no-rust-in-app.sh
# In the app: import a short clip, mark the court, analyze players, analyze rallies.
```

Expected for this build: tracks publish; count is `Four` or `Unknown` with its
quality; rallies are proposed. RQ-01's 60% target is **not** met on the reference
(6.94%), so suggestions remain a proposal, not an accuracy claim.

## 6. Rollback

- Reinstall the previous signed bundle (service and app ship together; a
  version mismatch inside one bundle is a release error).
- Match artifacts are derived and regenerable; the client catalog schema is
  unchanged (v5) and this intent adds no durable client state, so rollback does
  not need a data migration.
- Rollback was **not exercised in a live signed bundle** in this intent; the
  script path is unchanged and the previous bundle is the fallback.

## 7. Data and privacy

- Recordings and artifacts stay on the device; no network path is added.
- The service owns custody and the artifact tree; the client holds only an
  in-memory cache.
- No secrets are involved.

## 8. Known issues at this deployment

- RQ-01 is unmet; the opt-in acceptance test fails the 60% gate by design.
- U6 licensing guard and U7 BRD evidence are outstanding; no release claim.
- The 40 pre-existing client test failures are unrelated and untriaged.
