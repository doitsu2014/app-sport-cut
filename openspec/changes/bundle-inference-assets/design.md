## Context

Player analysis starts in `core/crates/api/src/player_tracking_job.rs`, which
reads two process environment variables through `local_asset`:
`SPORTCUT_TFLITE_LIBRARY` (the TFLite C runtime) and `SPORTCUT_PERSON_MODEL`
(the EfficientDet-Lite0 weights). It loads the runtime via `libloading` (through
`tflite-c-rs`) and the model via the Task Library API, all at job start. The
engine dylib itself is located by flutter_rust_bridge through
`ExternalLibraryLoaderConfig(ioDirectory: '../core/crates/api/target/release/')`,
overridden at dev time by `run-macos.sh` via
`FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR`.

All three assets currently live outside the app bundle, which is fine for the
development workstation and impossible for a packaged app. The dependency
register already verdicts the runtime and weights as Apache-2.0 `shippable`;
only `tflite-c-rs` still needs its API/packaging review closed.

## Goals / Non-Goals

**Goals:**

- A packaged macOS app runs player analysis with no environment variables and
  no `core/` checkout.
- Asset paths are resolved once by the client and passed to the engine over the
  bridge, replacing environment lookup as the production mechanism.
- The runtime, model, and engine dylib are bundled inside `Sportcut.app`.

**Non-Goals:**

- ffmpeg/export licensing (GPL → LGPL build or AVFoundation renderer) — a
  separate change.
- Codec patent review, code signing, hardened runtime, or notarization — later
  packaging changes.
- Any change to detection logic, the model itself, or tracking behavior.

## Decisions

### 1. Dart resolves bundle paths; the engine receives explicit paths

The client resolves the two asset paths from the macOS bundle and passes them
with the player-analysis request; `local_asset` uses the supplied paths first
and falls back to the environment variables only when they are absent.

**Why:** the Rust cdylib has no reliable notion of its containing bundle, while
Dart always knows `Platform.resolvedExecutable` (the `Contents/MacOS` binary)
and can derive `Contents/Frameworks` and `Contents/Resources` from it. This
matches how flutter_rust_bridge already locates the engine dylib.

**Alternatives considered:** resolving the bundle in Rust from
`std::env::current_exe()` was rejected because the current executable is the
runner, not the library, and the library is loaded into that process without a
guaranteed relative path; baking `$HOME/Downloads/...` defaults into the engine
was rejected as a machine-specific path in product code.

### 2. Environment variables become a dev fallback, not removed

`local_asset` keeps its current environment lookup as the fallback so
`tools/run-macos.sh` and the eval workflow continue to work without a fully
assembled bundle. Production always supplies paths, so the fallback never fires
in a packaged app.

**Why:** preserving the dev loop; the env vars are the only thing making the
unbundled eval run work, and removing them would break the current eval flow
before packaging is complete.

### 3. Bundle layout

```
Sportcut.app/
  Contents/
    MacOS/Sportcut            ← the runner binary
    Frameworks/
      libsportcut_api.dylib   ← engine library (FRB)
      libtensorflowlite_c.dylib
    Resources/
      model.tflite            ← EfficientDet-Lite0 weights
```

A Copy Files build phase in `app/macos/Runner.xcodeproj` places the runtime and
model; the engine dylib follows the existing FRB macOS embedding convention
(`Contents/Frameworks`). The model could alternatively be a Flutter asset, but
bundling it in `Resources` keeps it out of the Dart asset pipeline and lets the
Rust side read a plain file path.

Implemented as a single Xcode Run Script phase (`Embed Inference Assets`) that
runs `tools/fetch-inference-assets.sh` (download + SHA-256 verify),
`tools/embed-inference-assets.sh` (runtime + model), and
`tools/embed-engine-lib.sh` (engine dylib). The engine dylib is opened directly
from the bundle by `SportcutEngine.initialize()` via `ExternalLibrary.open`
when present, so the packaged app never touches the development loader
directory or `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR`.

### 4. Bridge contract

`PlayerTrackingRequestDto` gains two optional path fields (runtime and model).
When both are present the engine uses them; when absent it falls back to the
environment variables. The existing Dart tracking controller fills them from
the bundle resolver, so feature code keeps talking to the typed wrapper rather
than the generated DTO directly.

### 5. Feature flag flip

`macos-tflite-eval` stays as the feature name (renaming is churn with no
benefit) but becomes enabled by default for the macOS shipping target in
`build-engine-lib.sh`, so the detector is compiled into the library the app
links. The opt-out (`SPORTCUT_MACOS_TFLITE_EVAL=0`) remains for engine-only
builds that must not need the runtime.

## Risks / Trade-offs

- **[Hardened runtime blocks dlopen outside the bundle]** once signing lands,
  `libloading` can only open bundled, signed dylibs → bundling in
  `Frameworks` is exactly what makes the inference path signing-safe.
- **[Path derivation is bundle-version specific]** `Platform.resolvedExecutable`
  walking to `../Frameworks` and `../Resources` depends on the standard macOS
  bundle layout → the resolver is a single function with a clear comment, and a
  failed resolution surfaces as the existing "runtime/model unavailable" error.
- **[Env fallback masks a missing bundle]** if the packaged app forgets the
  assets, a dev machine with env vars set would silently succeed → acceptable
  because production machines have no env vars, so the fallback cannot fire
  there.
- **[tflite-c-rs review is a gate]** the register still lists it `unresolved` →
  this change records the attribution and closes the review, but shipping is
  gated on that verdict, not on this code.

## Migration Plan

1. Land the bridge path fields and the Rust-side explicit-path preference with
   the env fallback; no behavior change in the eval flow.
2. Add the bundle path resolver and wire it into the tracking controller.
3. Add the Copy Files phase and flip the feature default; verify a packaged
   build runs analysis with the env vars unset.
4. Record the Apache-2.0 NOTICE and close the `tflite-c-rs` register verdict.

## Open Questions

- Whether the model ships as a `Contents/Resources` file or a Flutter asset.
  Default: `Contents/Resources`, read by the engine as a plain path.
- Whether to also bundle a `NOTICE`/attribution UI or only a text file.
  Default: a text file in `Resources` plus the register rows.
