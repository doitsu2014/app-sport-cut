# Sportcut — Offline Badminton Match Analyzer

Sportcut imports a badminton match recording from the device, removes the dead
time, makes score confirmation fast, suggests the best rallies as highlights,
and exports a polished video — entirely on-device, with no cloud processing.

This repository is greenfield. The architecture lives in
[docs/architecture.md](docs/architecture.md); the feature list and road map live
in [docs/features-roadmap.md](docs/features-roadmap.md), and dependencies and
storage models are documented in
[docs/external-dependencies.md](docs/external-dependencies.md) and
[docs/data-storage-models.md](docs/data-storage-models.md).

## Repository layout

| Directory | Responsibility |
| --- | --- |
| `core/` | Native Rust engine: the analysis pipeline, the media foundation, the job model, and the single FFI facade. Builds and tests without any client toolchain. |
| `app/` | Flutter macOS client: match library, review screens, and playback. |
| `models/` | Model assets and pretrained weights that ship with the app, plus the notes that map each asset to its license register entry. |
| `tools/` | Developer scripts: environment preflight, engine verification, and bridge regeneration. |
| `docs/` | Architecture, feature list and road map, external dependencies (register), and data and storage models. |
| `openspec/` | OpenSpec change artifacts. `openspec/changes/bootstrap-project-base/` is the change that created this layout. |

## Prerequisites

The project has two tracks that can be worked on separately. Work out what is
installed — and what is missing, with remediation steps — with:

```bash
tools/preflight.sh                 # everything
tools/preflight.sh --profile engine # only what the engine needs
```

**Engine track (buildable today).**

- Rust toolchain with `cargo` (1.80 or newer; developed against 1.97).
- A media toolchain: `ffmpeg` and `ffprobe` on `PATH`.
  - The probe, proxy, audio, and frame stages shell out to this toolchain, so
    the license-affecting build configuration matters. `tools/preflight.sh`
    reads it and flags GPL components, which are not shippable in a proprietary
    build (see [docs/external-dependencies.md](docs/external-dependencies.md)).

**Client track (macOS, requires a toolchain install).**

- Flutter SDK with Dart (3.x).
- A full Xcode installation, not just Command Line Tools, for macOS builds.

If the Flutter SDK is not on `PATH`, point the tooling at it explicitly:

```bash
export SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin
```

The engine is deliberately independent of the client: everything in `core/`
builds, lints, and tests on a machine that has no Flutter, Xcode, or JDK
installed.

## Verification commands

Engine track:

```bash
tools/verify-engine.sh     # cargo fmt --check, cargo clippy, cargo test
```

Client track (macOS, requires the Flutter SDK):

```bash
cd app
flutter pub get
flutter analyze
flutter test
```

Bridge generation and the engine library the app links against:

```bash
tools/generate-bridge.sh     # Dart bindings + Rust glue (not committed)
tools/build-engine-lib.sh    # core/crates/api/target/release/libsportcut_api.*
```

If the Flutter SDK is not on `PATH`, export `SPORTCUT_FLUTTER_BIN` first (see
the prerequisites above).

## Status

The engine foundation — workspace layout, media pipeline, and job model — is the
first deliverable, tracked as the OpenSpec change
`openspec/changes/bootstrap-project-base`. The Flutter shell follows once the
Xcode toolchain is installed, because it cannot be compiled or tested without
it.
