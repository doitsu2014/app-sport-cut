# Deployment Runbook — Import and Media Preparation (Feature 2)

Status: Launch / Deployment Automation
Intent: `261030-implement-02-import`
Product shape: offline macOS desktop app + embedded signed helper service
(ADR-0001). There is no server, no store distribution, and no CI in this
repository; "deployment" is producing a complete local app bundle and
validating it. Release candidate: `d33d123..34754d7` on branch
`261030-implement-02-import`.

## 1. Build sequence (order matters)

1. **Machine check**: `tools/preflight.sh --profile macos` — reads only,
   installs nothing. Flags GPL FFmpeg builds (not shippable; fine for dev).
2. **Service first**: `tools/build-service.sh` →
   `core/target/release/sportcut-service`. On macOS the `macos-tflite-eval`
   feature is on by default; `SPORTCUT_MACOS_TFLITE_EVAL=0` omits it and the
   bundle runs everything except player tracking.
3. **App bundle**: `cd app && flutter build macos --release`. The Xcode build
   phases then embed automatically (see deployment-scripts.md):
   - `tools/fetch-inference-assets.sh` + `tools/embed-inference-assets.sh`
     (TFLite runtime + model into `Contents/Frameworks` / `Contents/Resources`);
   - `tools/embed-service.sh` (copies/signs the service into
     `Contents/Helpers/SportcutService`) — **only when step 2 produced the
     binary**, so a clean checkout can still build the app.
4. **Guards**: `tools/check-no-rust-in-app.sh` (blocking). Engine guards
   (`tools/verify-engine.sh`, `tools/check-layering.sh`) are not applicable
   to this intent (no `core/` change) but are mandatory for the R-IMP-7
   engine follow-up.

## 2. Validation after build

1. **Evidence runs**: execute the test plan's required items at the release
   candidate — `cd app && flutter test test/match_repository_test.dart` and
   the MV-1…MV-5 manual runs — recording the transcript at
   `docs/verification/import-progress.md` (test-plan §3/§5).
2. **Bundle smoke**: launch the built app; confirm it spawns the embedded
   `SportcutService` (no client-supplied inference paths are ever sent; the
   service resolves bundle files then `SPORTCUT_TFLITE_LIBRARY` /
   `SPORTCUT_PERSON_MODEL`), connects over the Unix socket (the U0 AF_UNIX
   fix), and imports the generated fixture end to end.
3. **Dev loop equivalents**: `tools/run-service.sh` (service on a temporary
   state root) and `tools/run-macos.sh` (legacy client dev run).

## 3. Rollback and state

- Dev/local distribution only: rollback = delete the app bundle and rebuild
  from the previous commit; there is no deploy target to roll back.
- **This intent changes no schema and no service state**: the client v5
  catalog, the recording store layout (`~/Documents/SportcutRecordings`), and
  the match directory layout (`manifest.json`, `checkpoints.json`, `proxy/`,
  `audio/`, `frames/`, `calibration/`, `tracks/`, `export/`) are untouched, so
  bundles before/after this change read the same state. Derived media stays
  outside the repository.

## 4. Secrets and permissions

- None. The product is offline by guardrail: no network entitlement, no
  telemetry, no accounts. Code signing uses the local Xcode identity;
  `tools/embed-service.sh` handles signing the helper. No CI secrets exist
  (no CI); if CI is bootstrapped later (recorded follow-up), it needs no
  product secrets — only toolchain setup.
