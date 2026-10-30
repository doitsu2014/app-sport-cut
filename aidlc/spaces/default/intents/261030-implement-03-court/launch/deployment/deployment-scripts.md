# Deployment Scripts — Court Calibration (Feature 3)

Status: Launch / Deployment Automation
Intent: `261030-implement-03-court`
Date: 2026-10-30

No new deployment script is introduced. This feature is a client build; the
supported entry points already exist in the repository and are reused here.

## Scripts used

| Script | Purpose | Notes |
| --- | --- | --- |
| `tools/preflight.sh --profile macos` | Check the macOS client toolchain and media tools | Read-only; installs nothing |
| `tools/preflight.sh --profile engine` | Check the engine toolchain | Read-only |
| `tools/verify-engine.sh` | `cargo fmt --check`, clippy, tests | Engine untouched, but part of the release gate |
| `tools/build-service.sh` | Build `core/target/release/sportcut-service` | Enables `macos-tflite-eval` by default |
| `tools/embed-service.sh <app>` | Copy and sign `Contents/Helpers/SportcutService` | Release packaging |
| `tools/embed-inference-assets.sh <app>` | Copy the TFLite runtime and model | Only when tracking is in the build |
| `tools/capture-app-screenshots.sh` | Headless visual verification | Writes PNGs to `app/build/screenshots` (build output) |
| `tools/check-no-rust-in-app.sh` | Enforce the no-FFI boundary | Blocking guard |
| `tools/check-layering.sh` | Enforce the Clean Architecture rule | Run if a manifest changes; none here |
| `cd app && flutter build macos --release` | Build the client | Standard Flutter command |

## Idempotence and safety

- Every script is safe to re-run: the build/embed steps overwrite outputs, the
  preflight scripts only read, and the screenshot script replaces its PNGs.
- No script writes secrets. The service token is generated per launch at
  runtime; no token is compiled or committed.
- Build output stays under `app/build/`, `core/target/`, and the app bundle;
  nothing points an artifact root at the checkout.

## Environment parameters

| Variable | Effect |
| --- | --- |
| `SPORTCUT_FLUTTER_BIN` | Directory containing `flutter` when it is not on `PATH` |
| `SPORTCUT_MACOS_TFLITE_EVAL=0` | Build the service without player tracking |
| `SPORTCUT_TFLITE_LIBRARY` / `SPORTCUT_PERSON_MODEL` | Service-side inference asset overrides (never client-supplied) |

## Not provided

- No CI workflow: the repository has no `.github/`; the CI stage is skipped.
- No release packaging beyond the existing embed scripts; ADR-0001 Phase 6 owns
  packaging and supervision.
- No installer, notarisation, or update feed: out of scope for this intent.
