## Why

The repository holds a complete product and technical plan (`docs/README.md`) but contains no source code, no workspace layout, and no agreed answers to the decisions that cascade across every later phase — media and codec licensing, where data is stored, and where the boundary between the Flutter UI and the Rust engine sits. Feature work on tracking, rally segmentation, scoring, and export cannot start coherently until the project base exists and those decisions are locked, because reversing them later means rewriting the pipeline rather than adjusting it.

The development environment is also uneven: Rust 1.97 and FFmpeg 8.1.1 are present, but Flutter, Dart, a full Xcode install, and the Android SDK are not, and the locally installed FFmpeg is a GPL build that is not suitable for a proprietary mobile distribution. Establishing the base means resolving both the structure and that environment gap in the same step.

## What Changes

- Introduce a monorepo layout separating the native engine from the mobile client: `core/` (Rust workspace), `app/` (Flutter), plus `models/`, `tools/`, and `docs/legal/`.
- Create the Rust workspace with crate boundaries that mirror the analysis pipeline steps, and a headless `sportcut-cli` harness so the difficult media and computer-vision work can be developed and benchmarked on a workstation before any mobile UI exists.
- Create the Flutter application shell organized feature-first (`library`, `calibration`, `analysis`, `score`, `highlights`, `export`), with a local SQLite catalog and working video import and playback.
- Connect the two via `flutter_rust_bridge` v2 across a single typed facade crate, so the UI depends on DTOs and streams rather than on engine internals.
- Implement the media pipeline foundation end to end: probe metadata, generate an analysis proxy, extract an analysis audio track, and sample frames, writing into a per-match artifact directory.
- Introduce a long-running job model with progress reporting, cancellation, and checkpoint/resume, because mobile operating systems will suspend analysis and an unresumable pipeline is not shippable.
- Add a dependency, model, and asset license register as a first-class document, and replace the inherited GPL FFmpeg assumption with a license-clean media strategy.
- Add developer environment bootstrap documentation and a preflight check that reports missing toolchain components instead of failing late in a build.

No **BREAKING** changes: the repository is greenfield and this change adds code rather than modifying any existing behavior.

## Capabilities

### New Capabilities

- `project-bootstrap`: repository and workspace layout, developer environment bootstrap and preflight verification, and the dependency/model/asset license register that governs what may be shipped.
- `media-pipeline`: local video probing, proxy video generation, analysis audio extraction, frame sampling, and the per-match artifact storage layout on disk.
- `processing-jobs`: resumable, cancellable, progress-reporting job sessions for long-running local analysis work.
- `match-library`: local match records, video import from device storage, match browsing, and playback, backed by a SQLite catalog that the application owns.

### Modified Capabilities

None. No specs exist yet in `openspec/specs/`, so every capability above is new.

## Impact

- **New code**: `core/` Rust workspace (facade, jobs, media, storage crates plus a CLI harness), `app/` Flutter application, `tools/` build and asset scripts, `models/` for bundled and optional model assets.
- **Data**: a SQLite catalog owned by the application for match, rally, score, and highlight metadata, and a per-match artifact directory holding originals references, proxy video, analysis audio, calibration, and track data.
- **Dependencies**: `flutter_rust_bridge` v2 as the bridge; Rust media and storage crates; FFmpeg restricted to an LGPL-compatible configuration or replaced by platform-native media APIs; an on-device inference runtime introduced behind an abstraction for later phases.
- **Licensing and distribution**: a license register becomes a gating document, since the available GPL FFmpeg build and any bundled model weights directly affect whether the app can be distributed.
- **Development environment**: builds now require the Flutter SDK, Dart, a full Xcode installation, and the Android SDK with a JDK, none of which are currently installed on this machine.
- **Documentation**: `docs/plans/` gains the implementation plan and `docs/legal/` gains the license register; `README.md` is replaced with real setup instructions.
