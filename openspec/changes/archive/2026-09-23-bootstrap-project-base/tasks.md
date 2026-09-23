## 1. Repository foundation

- [x] 1.1 Create the top-level workspace layout: `core/` for the native engine, `app/` for the mobile client, `models/` for model assets, `tools/` for developer scripts, and `docs/legal/` for licensing records
- [x] 1.2 Replace the stub `README.md` with a project overview, prerequisites, and the verification commands for both tracks
- [x] 1.3 Extend `.gitignore` to cover Flutter and Dart build output, generated bridge bindings, per-match artifact directories, and test media
- [x] 1.4 Write the implementation plan into `docs/plans/README.md`, summarizing the milestones and linking back to this change
- [x] 1.5 Create `docs/legal/dependency-register.md` with the register schema and seed rows for Flutter, Rust crates, the media toolchain, SQLite, the intended inference runtime, and any bundled model

## 2. Toolchain preflight

- [x] 2.1 Implement the preflight script reporting Rust, cargo, the media toolchain, the Flutter SDK, Dart, a full Xcode installation, the Android SDK, and the JDK with detected versions
- [x] 2.2 Report the license-affecting configuration of the detected media toolchain and flag GPL components as incompatible with proprietary distribution
- [x] 2.3 Report every missing component in a single run, each with a remediation step, and exit non-zero
- [x] 2.4 Document which setup steps apply to engine-only work versus mobile client work
- [x] 2.5 Verify the preflight check against the current machine and confirm it reports the missing Flutter SDK, Dart, Xcode, Android SDK, and JDK together

## 3. Native engine workspace

- [x] 3.1 Create the `core/` Cargo workspace with crates for the facade, jobs, media, and artifact storage
- [x] 3.2 Add placeholder crates for court, vision, rally, score, and highlight so later phases fill in boundaries rather than reshape them
- [x] 3.3 Add workspace-wide formatting and lint configuration plus a shared error type used across crates
- [x] 3.4 Add the `sportcut-cli` binary crate with subcommand scaffolding for headless lab use
- [x] 3.5 Add a single local verification command for the engine covering format, lint, and test

## 4. Media pipeline

- [x] 4.1 Implement local video probing returning duration, frame rate, resolution, orientation, and audio track presence
- [x] 4.2 Implement reduced-resolution proxy generation that leaves the original recording untouched
- [x] 4.3 Implement analysis audio extraction to a low-bitrate track
- [x] 4.4 Treat a video without an audio track as an expected outcome that reports no analysis audio and lets the pipeline continue
- [x] 4.5 Implement configurable frame sampling that emits timestamped frames mapped to the original timeline, and rejects rates above the supported maximum
- [x] 4.6 Implement the per-match artifact directory with a manifest that records each artifact and references the original recording in place
- [x] 4.7 Implement regenerability: detect missing derived artifacts from the manifest and regenerate them without re-importing the match
- [x] 4.8 Confirm the media path performs no network access and add a test asserting it
- [x] 4.9 Wire the CLI subcommands to probing, proxy generation, audio extraction, and frame sampling
- [x] 4.10 Add tests covering unreadable or truncated input, a video with no audio track, and an unsupported sampling rate

## 5. Processing job model

- [x] 5.1 Implement the job session with a stable identifier and pending, running, completed, cancelled, and failed states
- [x] 5.2 Emit stage-labeled progress events with a value that does not decrease within a stage
- [x] 5.3 Implement cancellation that stops work and marks partial artifacts as non-final
- [x] 5.4 Persist checkpoints into the match directory and resume from the last completed stage after interruption
- [x] 5.5 Enforce a single concurrent resource-intensive job, rejecting or deferring additional requests
- [x] 5.6 Add tests for resume after a simulated interruption, cancellation mid-stage, and rejection of a concurrent request for the same match

## 6. Engine to client bridge

- [x] 6.1 Pin `flutter_rust_bridge` v2 and add its codegen configuration to the facade crate
- [x] 6.2 Define the facade DTOs for media metadata, job state and progress, and the artifact manifest as the frozen contract
- [x] 6.3 Generate the Dart bindings as a verification step and document the regeneration command instead of hand-maintaining bindings
- [x] 6.4 Wrap the generated bindings in typed Dart wrappers under the client's bridge folder

## 7. Mobile client shell

- [ ] 7.1 Install and verify the mobile toolchain: Flutter SDK, Dart, a full Xcode installation, the Android SDK, and a JDK
- [x] 7.2 Scaffold the `app/` Flutter project for iOS and Android
- [x] 7.3 Set up the feature-first folder structure for library, calibration, analysis, score, highlights, and export
- [x] 7.4 Add the application shell with routing, theme, and dependency injection scaffolding
- [ ] 7.5 Integrate the native engine into the build for both platforms and confirm the generated bridge loads at runtime

## 8. Match library and catalog

- [x] 8.1 Define the local database schema for match, rally, score event, and highlight clip records with a versioned migration framework
- [x] 8.2 Implement match creation from a selected local video file, referencing the original in place rather than copying it
- [x] 8.3 Populate media metadata on import by calling the engine probe
- [x] 8.4 Implement the library list showing title, duration, and creation date, with an empty state that offers to import
- [x] 8.5 Implement local playback with standard transport controls
- [x] 8.6 Handle import failures caused by denied access, a missing file, or an unsupported codec without leaving partial catalog records
- [x] 8.7 Implement match deletion that removes catalog records and asks whether to also delete derived artifacts

## 9. Verification and documentation

- [x] 9.1 Run the engine test suite and confirm every media and job scenario in the specs has a corresponding test
- [ ] 9.2 Manually verify the client flow end to end: import a real recording, view its metadata, generate a proxy, and play it back with network access unavailable
- [x] 9.3 Confirm no pipeline stage requires network access and record the evidence in the change
- [x] 9.4 Update the dependency register with every dependency, model, and asset introduced during implementation
- [x] 9.5 Record the platform scope and media library decisions resolved during implementation back into `design.md`
