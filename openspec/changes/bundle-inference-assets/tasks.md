## 1. Bridge contract

- [x] 1.1 Add optional runtime and model path fields to `PlayerTrackingRequestDto` in `core/crates/api/src/dto.rs`
- [x] 1.2 Thread the supplied paths into `player_tracking_job.rs` and make `local_asset` prefer explicit paths over environment variables
- [x] 1.3 Regenerate the bridge (`tools/generate-bridge.sh`) so the new DTO fields reach Dart

## 2. Client bundle path resolver

- [x] 2.1 Add a bundle path resolver that derives `Contents/Frameworks` and `Contents/Resources` from `Platform.resolvedExecutable`
- [x] 2.2 Wire the resolver into the tracking controller so it supplies the paths when starting player analysis

## 3. Packaging

- [x] 3.1 Add a Copy Files build phase (or equivalent) placing the TFLite runtime dylib in `Contents/Frameworks` and the model in `Contents/Resources`
- [x] 3.2 Embed the engine dylib in `Contents/Frameworks` for packaged builds per the FRB macOS convention

## 4. Build and license register

- [x] 4.1 Flip `macos-tflite-eval` to default-on for the macOS shipping target in `build-engine-lib.sh` (keep the `SPORTCUT_MACOS_TFLITE_EVAL=0` opt-out)
- [ ] 4.2 Record the Apache-2.0 NOTICE/attribution and close the `tflite-c-rs` packaging review in `docs/external-dependencies.md`

## 5. Verify

- [x] 5.1 `cargo build -p sportcut-api --features bridge,macos-tflite-eval` succeeds and `flutter analyze` is clean
- [ ] 5.2 A packaged macOS build runs player analysis with the environment variables unset
