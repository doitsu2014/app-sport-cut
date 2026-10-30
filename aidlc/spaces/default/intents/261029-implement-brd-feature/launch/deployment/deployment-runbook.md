# Deployment Runbook — Workspace and Library gaps

Status: Launch / Deployment Automation
Intent: `261029-implement-brd-feature`

## 1. Environments

| Environment | How the app is run | What this change affects |
| --- | --- | --- |
| Developer macOS | `tools/run-macos.sh` or `cd app && flutter run -d macos` | The six client files compile and render differently; no tooling change. |
| Packaged macOS app | `tools/embed-service.sh <app>` / `tools/embed-inference-assets.sh <app>` | None. The changed files are Dart UI; the service and inference bundles are untouched. |

## 2. Release checklist for this change

1. `cd app && flutter analyze` — clean (four pre-existing test infos excepted).
2. `tools/check-no-rust-in-app.sh` — OK.
3. Launch the app and run the manual checks in
   `../test-plan/test-plan.md` §2.
4. Confirm the BRD status rows still match the build (`docs/brd/01` §2.3).

## 3. Rollback

Revert the six client files and the two BRD docs. There is no migration, no
schema change, and no user data to restore.

## 4. Out of scope

- Code signing, notarisation, and the release channel: unchanged by this
  intent.
