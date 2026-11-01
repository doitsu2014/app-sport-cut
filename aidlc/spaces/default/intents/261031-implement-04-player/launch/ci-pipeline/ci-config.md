# CI Configuration Record — Player Tracking (Feature 04)

Status: Launch / CI Pipeline
Intent: `261031-implement-04-player`
Date: 2026-11-01
Inputs: `test-plan.md`, `test-suite.md`.

## 1. Build contract (authoritative commands)

| Stage | Command |
| --- | --- |
| Engine format/lint/test/layering | `tools/verify-engine.sh` |
| Feature lint | `cargo clippy -p sportcut-api --features macos-tflite-eval --all-targets -- -D warnings` (from `core/`) |
| Layering | `tools/check-layering.sh` |
| No Rust in app | `tools/check-no-rust-in-app.sh` |
| Client analyze | `cd app && flutter analyze` |
| Client targeted tests | `cd app && flutter test test/screenshots/media_screens_test.dart` |
| Acceptance (opt-in) | `SPORTCUT_TEST_VIDEO=… SPORTCUT_TEST_VIDEO_CORNERS=… cargo test -p sportcut-api --features macos-tflite-eval --test real_footage -- --nocapture` |

These are the same commands a developer runs; no CI-specific variants exist.

## 2. Current state

- There is no `.github/workflows/`, no `.gitlab-ci.yml`, and no other hosted CI
  configuration in the repository.
- The local gate is authoritative and is what this intent used:
  `tools/verify-engine.sh`, feature clippy, `flutter analyze`, the screenshot
  suite, and the opt-in acceptance measurement.
- The default engine suite does not require Flutter, Xcode, inference assets, or
  the reference video. The acceptance run does require the pinned TFLite
  runtime/model and a local recording, so it is not a suitable default hosted
  job.

## 3. Recommended pipeline (not added by this intent)

Adding a hosted pipeline is an infrastructure change outside this intent's
approved scope and would need its own review. The recommended shape:

1. **Engine job** (cheap first): checkout; install the pinned Rust toolchain;
   cache `~/.cargo` and `core/target`; run `tools/verify-engine.sh`; run
   `tools/check-no-rust-in-app.sh`; run feature clippy.
2. **Client job:** install the pinned Flutter SDK; cache `app/.dart_tool` and
   pub cache; `flutter pub get`; `flutter analyze`; the targeted test suite.
   Do not fail on the 40 pre-existing unrelated client tests until they are
   triaged.
3. **Acceptance job (manual/nightly, self-hosted macOS):** provision the
   reference recording, the TFLite runtime/model, and the fixed corners; run
   the opt-in test. This job records the RQ-01 shortfall but is not a required
   merge gate while the 60% target is unmet.

## 4. Determinism and caching

- Pin the Rust toolchain (workspace `rust-version = 1.80`) and the Flutter SDK
  version in the pipeline configuration, not `latest`.
- Pin action versions by commit/tag; cache Cargo and pub dependencies.
- No network at test time: dependency fetch happens in setup only. The
  acceptance assets are fetched by `tools/fetch-inference-assets.sh` with
  SHA-256 verification, never committed.
- Set `CARGO_INCREMENTAL=0` and a fixed test thread count if end-to-end
  determinism is ever asserted in CI.

## 5. Secrets and permissions

- **No secrets are required** for the engine or client jobs.
- Acceptance needs local files only; do not add tokens or cloud storage.
- Grant read-only repository permissions; no write actions, no PR comments, no
  artifact uploads containing footage.
- Never echo the reference path or environment beyond the job.

## 6. Decision

No pipeline files were added. The local gate remains the supported entry point
for this intent. A hosted pipeline is a separate infra change (with its own
licensing/security review) if the project adopts CI.

## 7. Verification of this record

The commands above were run in this intent: `tools/verify-engine.sh` passed,
feature clippy passed, `flutter analyze` was clean, the screenshot suite passed,
and the acceptance run recorded 6.94% / 613 identities / 4.2% / 35 rallies /
84.1 s with the RQ-01 gate failing as recorded.
