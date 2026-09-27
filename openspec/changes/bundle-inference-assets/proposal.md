## Why

Player analysis is the only runtime path that reaches outside the app bundle:
the Rust engine reads `SPORTCUT_TFLITE_LIBRARY` and `SPORTCUT_PERSON_MODEL` from
the process environment at job start, and the engine dylib is located via a
dev-only loader directory. A packaged macOS app has no shell environment and no
`core/` checkout to point at, so the shipped app cannot run inference as it is
wired today. The runtime, model, and engine library must live inside
`Sportcut.app` and be located without any developer setup.

## What Changes

- The Dart client resolves the macOS bundle's `Contents/Frameworks` and
  `Contents/Resources` paths and passes the TFLite runtime path and model path
  to the engine over the bridge when starting player analysis.
- The engine's player-analysis job accepts those explicit asset paths; the
  environment variables remain as a development fallback, not the production
  mechanism.
- The TensorFlow Lite runtime dylib and the EfficientDet-Lite0 weights are
  bundled into the app, and the engine dylib is placed in `Contents/Frameworks`
  for packaged builds.
- The `macos-tflite-eval` feature becomes the default for the shipping macOS
  target instead of an opt-in eval flag.
- The license register records the Apache-2.0 attribution carried with the
  bundled runtime and weights, and closes the `tflite-c-rs` packaging review.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `person-detection`: detector runtime and model assets are resolved from
  client-supplied bundle paths in the shipped app, with the environment-variable
  lookup retained only as a development fallback, and the shipping build bundles
  the runtime, model, and engine library inside the app.

## Impact

- **Bridge** (`core/crates/api/src/dto.rs`, `player_tracking_job.rs`,
  `facade.rs`): the player-analysis request carries runtime and model paths, and
  asset lookup prefers the supplied paths over environment variables.
- **Client** (`app/lib/src/features/tracking/...`, bridge wrapper): a bundle
  path resolver supplies the asset paths when starting analysis.
- **Packaging** (`app/macos/Runner.xcodeproj`, build scripts): a Copy Files
  phase bundles the runtime dylib, model weights, and engine dylib into the app.
- **Build** (`core/crates/api/Cargo.toml`, `tools/build-engine-lib.sh`): the
  detector feature is enabled by default for the shipping target.
- **Engine**: no detection logic changes; only how the detector locates its
  assets.
