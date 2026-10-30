# Deployment Runbook — Court Calibration (Feature 3)

Status: Launch / Deployment Automation
Intent: `261030-implement-03-court`
Date: 2026-10-30

## 1. Environments

| Environment | Purpose | Differences |
| --- | --- | --- |
| Development | Run from source against the dev service | `tools/run-macos.sh`; service state root is temporary; `matchDir` is accepted (debug build) |
| Release (macOS app) | Shipped app bundle | Service built with `tools/build-service.sh` (release), embedded by `tools/embed-service.sh`; release service rejects `matchDir` |
| CI | None exists | `.github/` is absent; the CI stage is skipped and the commands below are the manual equivalent |

This feature is client-only: no service, database, schema, or network
deployment. The deployment is a macOS app build and the repository merge.

## 2. Pre-conditions

- `tools/preflight.sh` passes for the target profile (`engine` or `macos`).
- `tools/verify-engine.sh` passes on `core/` (unchanged by this feature, but the
  release gate runs it).
- `cd app && flutter analyze` is clean.
- `tools/check-no-rust-in-app.sh` passes.
- The target commit is reviewed and the intent's review record is approved.

## 3. Deploy steps

1. **Build the engine/service.**
   ```bash
   tools/build-service.sh
   tools/embed-service.sh "$APP_BUNDLE"
   ```
   On macOS this enables `macos-tflite-eval` by default; set
   `SPORTCUT_MACOS_TFLITE_EVAL=0` only for an inference-free build.
2. **Build the Flutter client.**
   ```bash
   cd app
   flutter build macos --release
   ```
3. **Embed inference assets (if the build includes tracking).**
   ```bash
   tools/embed-inference-assets.sh "$APP_BUNDLE"
   ```
4. **Launch the app** from the bundle (not `flutter run`) to exercise the
   packaged service.
5. **Import one match, mark the court, save, reopen.** The runbook's live check.

## 4. Verification

| Check | Expected |
| --- | --- |
| `flutter analyze` | No issues |
| `tools/check-no-rust-in-app.sh` | OK |
| `tools/capture-app-screenshots.sh` | 21/21 pass; `calibration_default` shows no net, `calibration_projected` shows the engine outline and dashed net |
| Controller tests | 12/12 pass |
| Manual live check | Mark court → the dashed net follows the orientation control; rejection clears it; save shows `Court marked for <title>`; reopen restores corners and **Update court** |
| No network | The app makes no outbound connection while marking/saving |

**Important release limitation.** The packaged app currently sends `matchDir`
with every match-scoped call, and a release service rejects it
(`engine.rs:477-494`). Until ADR-0001 Phase 3/4 lands and the client stops
sending `matchDir`, the packaged service cannot serve calibration (or any
match-scoped call) unless the release build is adjusted. Treat packaged
end-to-end verification as **blocked on Phase 3/4**; the development transport
is the supported path for this feature today. This is recorded as C-15 and must
not be mistaken for a passing release check.

## 5. Health and readiness

- **Ready:** the app launches, the library opens, the dev service answers
  `service.health`, and the calibration surface renders.
- **Healthy:** marking, projection, save, and reopen complete without a banner;
  the status bar still reports local-only.
- **Not ready:** the calibration surface is blank, projection never returns, or
  a packaged service rejects match-scoped calls (see the limitation above).

## 6. Rollback

- The change is client presentation only; roll back by reverting the merge
  commit. There is no data migration to undo.
- Saved calibrations remain compatible: the artifact schema is unchanged
  (`schema_version` 1) and the v5 catalog column is untouched.
- A rolled-back app still reads calibrations saved by this version.
- Rollback drill status: **not exercised** (no staging environment). Reverting
  the commit is the documented path.

## 7. Post-deploy

- Confirm the BRD 03 §3.3 status remains Partial with the evidence gaps visible.
- Leave the four follow-ups in `code-generation-notes.md` open: stale screen
  tests, golden-image assertion, real-footage accuracy, ADR-0001 Phase 3-4.
