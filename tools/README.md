# Developer Tools

Scripts in this directory are the supported entry points for development. They
work from a checkout without requiring the mobile toolchain unless stated
otherwise.

| Script | Purpose | Requires |
| --- | --- | --- |
| `preflight.sh` | Reports every toolchain component with its detected version, flags license-affecting media configuration, and lists all missing components with remediation steps in one run. | `bash` (uses only POSIX tools plus what it is checking for) |
| `verify-engine.sh` | The single engine verification command: format check, lint, and test across the Rust workspace. | Rust toolchain, media toolchain |
| `generate-bridge.sh` | Regenerates the `flutter_rust_bridge` bindings on both sides. Generated files are not committed. | Flutter SDK, Dart, `flutter_rust_bridge_codegen` |
| `build-engine-lib.sh` | Builds `sportcut-api` with the `bridge` feature into the crate's own target directory, which is where the generated Dart bindings load the library from. | Rust toolchain, generated bindings |
| `run-macos.sh` | Development run of the Flutter client on macOS: builds the engine library, then runs `flutter run -d macos`. macOS is not a shipping target. | Flutter SDK, Xcode, CocoaPods, Rust toolchain, generated bindings |

Run `preflight.sh --profile engine` for engine-only work and `--profile mobile`
for client work. `--profile all` is the default.

Flutter and Dart are located through, in order: `SPORTCUT_FLUTTER_BIN` (the
directory containing the `flutter` executable), `FLUTTER_ROOT`, `PATH`, and the
common install locations `~/flutter/bin`, `~/development/flutter/bin`,
`~/fvm/default/bin`. Set `SPORTCUT_FLUTTER_BIN` when the SDK lives elsewhere and
you would rather not change your shell profile:

```bash
SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin tools/preflight.sh --profile mobile
```

Exit codes for `preflight.sh`:

| Code | Meaning |
| --- | --- |
| `0` | Every component required by the selected profile is present; any media licensing conflict is reported as a warning only. |
| `1` | One or more required components are missing. Every missing component is listed. |
| `2` | `--strict-license` was given and the detected media toolchain contains GPL components. |
