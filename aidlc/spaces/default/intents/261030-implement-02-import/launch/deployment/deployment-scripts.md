# Deployment Scripts — Import and Media Preparation (Feature 2)

Status: Launch / Deployment Automation
Intent: `261030-implement-02-import`

## Decision: no new scripts

This intent adds no deployment automation because the repository's supported
entry points already cover the whole flow, and the Xcode build phases invoke
them automatically during `flutter build macos`:

| Script | Role | Invoked by |
| --- | --- | --- |
| `tools/preflight.sh` | read-only machine check (`--profile engine/macos`) | developers |
| `tools/build-service.sh` | `core/target/release/sportcut-service` (macOS: `macos-tflite-eval` on by default) | developers, before the app build |
| `tools/fetch-inference-assets.sh` | download + verify TFLite runtime and model | Xcode build phase |
| `tools/embed-inference-assets.sh <app>` | copy runtime + model into the bundle | Xcode build phase |
| `tools/embed-service.sh <app>` | copy/sign `Contents/Helpers/SportcutService` | Xcode build phase (only when the service binary exists) |
| `tools/check-no-rust-in-app.sh` | blocking guard: no Rust/FFI in the client | developers, release validation |
| `tools/run-service.sh` / `tools/run-macos.sh` | dev runs (temporary state root / legacy client) | developers |
| `tools/verify-engine.sh`, `tools/check-layering.sh` | engine-track gates — N/A for this intent, mandatory for the R-IMP-7 follow-up | developers |

Evidence: `app/macos/Runner.xcodeproj/project.pbxproj` shell-script build
phases call `fetch-inference-assets.sh`, `embed-inference-assets.sh
"${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"`, and — guarded by
`[ -x core/target/release/sportcut-service ]` — `embed-service.sh`, per
ADR-0001 ("the engine ships as the signed helper SportcutService, not as a
linked library").

Adding a new script here would duplicate supported entry points, contrary to
the `tools/` convention (CLAUDE.md: scripts in `tools/` are *the* supported
entry points and must work from a clean checkout with only the tools they
declare).

## Changes this intent made to deployment surface

None. No new assets, no bundle-layout change, no entitlement change, no
schema change, no service-protocol change. The only runtime-visible change
inside the existing bundle is client Dart behavior (progress fraction,
rebuild partition, artifact badges) plus the AF_UNIX connect fix.
