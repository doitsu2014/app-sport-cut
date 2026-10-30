# Developer Tools

Scripts in this directory are the supported entry points for development. They
work from a checkout without requiring the client toolchain unless stated
otherwise.

| Script | Purpose | Requires |
| --- | --- | --- |
| `preflight.sh` | Reports every toolchain component with its detected version, flags license-affecting media configuration, and lists all missing components with remediation steps in one run. | `bash` (uses only POSIX tools plus what it is checking for) |
| `verify-engine.sh` | The single engine verification command: layering check, format check, lint, and test across the Rust workspace. | Rust toolchain, media toolchain, `jq` |
| `check-layering.sh` | Enforces the Clean Architecture dependency rule, deriving each crate's layer from its directory. | `cargo`, `jq` |
| `generate-layering-diagram.sh` | Regenerates `docs/architecture/layering-diagram.html` from `cargo metadata`. | `cargo`, `python3` |
| `generate-c4-diagrams.sh` | Renders `docs/architecture/c4/model/workspace.json` to the committed SVGs under `docs/architecture/c4/generated/`. Compile-time edges come from `cargo metadata`; `--check` fails when the SVGs are stale. | `cargo`, `python3` |
| `check-c4-model.sh` | Cross-checks the C4 model against the repository: every workspace crate mapped once, every path and feature folder present, every view diagram committed, every relative link resolves. | `cargo`, `python3` |
| `run-macos.sh` | Development run of the Flutter client on macOS with `flutter run -d macos`. The client connects to a service started separately. | Flutter SDK, Xcode, CocoaPods |
| `capture-app-screenshots.sh` | Runs the screenshot suites and captures the app as PNGs: the headless widget-test suite by default, or `--integration` for the macOS desktop suite. Writes to `app/build/screenshots` unless `--output` names another directory; prints the absolute output path and PNG count. | Flutter SDK; macOS runtime with a GUI session for `--integration` |

Run `preflight.sh --profile engine` for engine-only work and `--profile macos`
for client work. `--profile all` is the default.

Flutter and Dart are located through, in order: `SPORTCUT_FLUTTER_BIN` (the
directory containing the `flutter` executable), `FLUTTER_ROOT`, `PATH`, and the
common install locations `~/flutter/bin`, `~/development/flutter/bin`,
`~/fvm/default/bin`. Set `SPORTCUT_FLUTTER_BIN` when the SDK lives elsewhere and
you would rather not change your shell profile:

```bash
SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin tools/preflight.sh --profile macos
```

Exit codes for `preflight.sh`:

| Code | Meaning |
| --- | --- |
| `0` | Every component required by the selected profile is present; any media licensing conflict is reported as a warning only. |
| `1` | One or more required components are missing. Every missing component is listed. |
| `2` | `--strict-license` was given and the detected media toolchain contains GPL components. |

## Service foundation (Phase 0-1)

ADR-0001 moves the Rust backend into a separate background service process. The
Phase 0-1 scripts are:

| Script | Purpose |
| --- | --- |
| `build-service.sh` | Builds `sportcut-service` in release and prints the artifact path. On macOS it enables the `macos-tflite-eval` feature by default; set `SPORTCUT_MACOS_TFLITE_EVAL=0` to omit it. |
| `embed-service.sh <app-bundle>` | Copies the service to `Contents/Helpers/SportcutService`, sets mode `0755`, and signs it when `CODESIGN_IDENTITY` is set; otherwise prints the exact `codesign` command and exits 0. Warns when the inference assets are missing. |
| `fetch-inference-assets.sh` | Downloads the TFLite C runtime and EfficientDet-Lite0 weights into `third_party/inference`, verifying each SHA-256. Build-time only; nothing downloads at runtime. |
| `embed-inference-assets.sh <app-bundle>` | Copies the fetched runtime to `Contents/Frameworks` and the model to `Contents/Resources`. |
| `run-service.sh` | Builds and runs the service in development with a temporary or explicit state root, and prints the endpoint and token path. Uses the same Darwin-gated `macos-tflite-eval` selection as `build-service.sh`, verifies the built artifact reports it, and passes `--tflite-library`/`--person-model` when `third_party/inference` holds both assets, plus `--ffmpeg`/`--ffprobe` from `SPORTCUT_FFMPEG`/`SPORTCUT_FFPROBE`. |
| `check-no-rust-in-app.sh` | Scans `app/` and any given bundle for FFI, `dart:ffi`, `DynamicLibrary`, generated bindings, and shipped Rust libraries. Blocking: any finding fails. |

The service owns media-tool discovery and inference asset resolution. It accepts
`--ffmpeg`, `--ffprobe`, `--tflite-library`, and `--person-model`; when the
inference flags are absent it resolves the bundle files
(`Contents/Frameworks/libtensorflowlite_c.dylib`,
`Contents/Resources/model.tflite`), then `SPORTCUT_TFLITE_LIBRARY` and
`SPORTCUT_PERSON_MODEL`. The service protocol never accepts client-supplied
`runtimePath` or `modelPath`; `engine.tracking.start` rejects them. The client
never sends them. `ffmpeg` and `ffprobe` are still required at runtime for
probe, proxy, audio, frames, and export; only the inference assets are optional,
and their absence leaves the service usable for everything except player
tracking.

The no-Rust guard is blocking and has no allowlist: the FFI path is gone, so a
reappearance is a regression. It does not replace the FFI removal checklist in
the [migration plan](../docs/architecture/migration-from-ffi.md#6-complete-ffi-removal-checklist).
