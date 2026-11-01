# Deployment Scripts — Player Tracking (Feature 04)

Status: Launch / Deployment Automation
Intent: `261031-implement-04-player`
Date: 2026-11-01

No new deployment scripts were added. The existing supported scripts cover the
local macOS bundle; this intent changes the service and client code they carry.

## 1. Scripts

| Script | Purpose | Parameters / environment | Exercised here |
| --- | --- | --- | --- |
| `tools/build-service.sh` | Release build of `sportcut-service` | `SPORTCUT_MACOS_TFLITE_EVAL=0` omits the trial feature; `CARGO_TARGET_DIR` optional | **Yes** (9.48 s, `0.1.0`, `macos-tflite-eval`) |
| `tools/embed-service.sh <app>` | Copy and sign `Contents/Helpers/SportcutService` | Path to `sportcut.app` | No (needs a built bundle) |
| `tools/embed-inference-assets.sh <app>` | Copy the TFLite runtime and model into the bundle | Path to `sportcut.app` | No; **no licensing-verdict guard yet (U6)** |
| `tools/package-macos.sh` | Build/sign/package the macOS app | Flutter release toolchain; signing identity | No (needs Flutter/Xcode) |
| `tools/run-service.sh` | Dev service on a temporary or supplied state root | `--state-root`, `--keep`; tool paths | Yes (earlier iterations) |
| `tools/run-macos.sh` | Dev run of the legacy client on macOS | Flutter toolchain | No |
| `tools/check-no-rust-in-app.sh` | Blocking guard: no Rust/FFI in the app | — | **Yes** (passed) |

## 2. Behaviour and idempotency

- All scripts are bash with `set -euo pipefail` and resolve the repository root
  from `BASH_SOURCE`.
- Builds are incremental Cargo/Flutter builds; embed steps overwrite the target
  copies in place, so re-running is safe.
- There is no teardown: the deliverable is a local app, not a hosted service.
  Removing the app bundle is the teardown.
- Version comes from the Cargo workspace/package and the app bundle; nothing is
  hardcoded in this intent.
- No secrets or machine-specific paths are required by any script.

## 3. Fail-fast and verification

- `build-service.sh` checks the built artifact reports `macos-tflite-eval` when
  the feature is enabled, so an inference-less build cannot be mistaken for a
  tracking-capable one.
- `embed-inference-assets.sh` verifies the source files exist; it does **not**
  verify the licensing verdict. U6 must add that guard before release.
- `check-no-rust-in-app.sh` is the blocking boundary guard and passed.
- Post-deploy checks are in `deployment-runbook.md`.

## 4. Gaps

- **U6 (licensing guard):** `embed-inference-assets.sh` can copy a model whose
  redistribution verdict is unresolved. Release is blocked until the guard lands
  (C-02/C-21).
- **Packaging not re-run:** the full bundle was not rebuilt in this intent; the
  service artifact was. The packaging path is unchanged.
- **Rollback:** reinstall the previous bundle; not exercised live (see the
  runbook).
