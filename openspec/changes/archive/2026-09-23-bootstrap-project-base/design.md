## Context

This is a greenfield repository. `docs/README.md` describes the product completely — an offline badminton match analyzer that removes downtime, supports one-tap score confirmation, suggests highlights, and exports a polished video with score overlays — but no source code, workspace layout, or stack decisions exist yet. `docs/plans/README.md` is empty and `README.md` is a one-line stub. OpenSpec is initialized with the `spec-driven` schema and no prior changes or specs.

The product plan imposes constraints that shape every decision here:

- Everything runs on-device. No cloud AI, no third-party video APIs, no network processing.
- The app is explicitly not an automated referee. Scoring is human-in-the-loop, and the pipeline exists to make review fast rather than to be authoritative.
- Licensing is a first-class concern from day one, because model weights, codecs, fonts, and music assets each carry separate terms from the libraries that ship them.

The development environment is uneven, which was verified rather than assumed:

| Component | State |
| --- | --- |
| Rust 1.97.1, cargo, rustup | Installed (target `aarch64-apple-darwin` only) |
| FFmpeg 8.1.1 | Installed, but a Homebrew build with `--enable-gpl`, `--enable-libx264`, `--enable-libx265` |
| Node 24 | Installed |
| Flutter SDK, Dart | Not installed |
| Xcode | Not installed — only CommandLineTools, so `xcodebuild` errors |
| Android SDK, JDK | Not installed |

The consequence is that the native engine is buildable today while the mobile client is not, which directly drives the first decision below.

## Goals / Non-Goals

**Goals:**

- Establish the repository structure, crate boundaries, and application folder layout that later phases build on without re-cutting.
- Deliver a buildable, testable Rust engine foundation with a headless CLI, so media handling can be developed and benchmarked before any mobile UI exists.
- Deliver a Flutter shell with local video import, playback, and a match catalog, connected to the engine through one typed boundary.
- Implement the media foundation (probe, proxy, analysis audio, frame sampling) and the long-running job model (progress, cancellation, resume).
- Make licensing and environment requirements explicit, checkable, and documented.
- Lock the storage ownership split so that neither side of the bridge has to be rewritten later.

**Non-Goals:**

- Court calibration, person detection, pose estimation, player tracking, and court-side assignment.
- Rally/rest segmentation, score suggestion, and serve heuristics.
- Highlight ranking, highlight editing, and final video export or transcoding.
- Shuttlecock, racket, or shot-type detection.
- Cloud sync, accounts, social publishing, and tournament management.
- Shipping a desktop product, though the CLI must run on a developer workstation.
- CI/CD beyond local verification commands.

Final video export and manual trimming are deliberately deferred to the next change even though `docs/README.md` lists them third in its build order. This change produces the foundation they need — media primitives, a job model, and a storage layout — and lands them as soon as the media library decision is settled.

## Decisions

### D1. Bootstrap the native engine first, the mobile client second

The product plan orders work starting at Flutter video import and playback. That order is not executable in this environment: Flutter, a full Xcode installation, and the Android SDK are all absent, so the first item could not be compiled or tested. The Rust engine, by contrast, builds today, and it holds the majority of the technical risk — decode, proxy generation, frame extraction, tracking, segmentation, and export.

The repository therefore grows on two tracks that converge at the bridge:

```
   available now                                after toolchain install
  ┌────────────────────────┐                  ┌────────────────────────┐
  │ core/  Rust workspace  │◀─── bridge ─────▶│  app/  Flutter client  │
  │  builds and tests now  │                  │  needs SDK + Xcode     │
  │  sportcut-cli harness  │                  │  + Android SDK         │
  └────────────────────────┘                  └────────────────────────┘
```

Alternatives considered: following the plan's order literally (rejected — the first step cannot be built or verified here); building the whole UI against mock data first (rejected — the bridge contract would be guesswork).

### D2. License-clean media strategy using platform-native codecs, with FFmpeg narrowly scoped

The FFmpeg binary on this machine is GPL-configured. Linking a GPL build into a proprietary mobile application is a distribution blocker, so it cannot be the shipping path, and the previously convenient `ffmpeg-kit` route is not a safe assumption either since that project has been retired.

The design uses a hybrid:

- Platform-native APIs handle encoding and export: AVFoundation with VideoToolbox on iOS, MediaCodec and Media3 on Android. This is also hardware accelerated, which matters far more than library convenience on phones.
- FFmpeg, if used at all for analysis-side probing and decoding, must be built or obtained in an LGPL-compatible configuration with GPL-only components disabled.

Alternatives considered: bundling the Homebrew GPL build (rejected — licensing); going fully platform-native immediately (deferred — weaker frame-accurate probe and decode control for analysis, revisit after measurement); treating the choice as settled now (not possible — Phase 0 benchmarks should inform it).

The exact library selection remains an open question, but the boundary is fixed: media access lives behind the engine's media crate so the choice can be revised without touching callers.

### D3. Crate boundaries mirror pipeline steps, with one facade crate as the only FFI surface

The Rust workspace is divided so that each crate corresponds to a stage of the analysis pipeline described in `docs/README.md`. Only one crate — the facade — is exposed across the language boundary. Everything else is an internal dependency, which keeps generated bridge code small and lets internal crates be refactored freely.

```
                    ┌──────────────────────────┐
   Flutter  ───────▶│      sportcut-api        │  ← only FFI surface
                    │  DTOs, job handles, stream│
                    └───────┬──────────────────┘
                            │
        ┌───────────────────┼───────────────────┬──────────────────┐
        ▼                   ▼                   ▼                  ▼
  ┌───────────┐      ┌───────────┐      ┌───────────┐     ┌───────────┐
  │ jobs      │      │ media     │      │ court     │     │ vision    │
  │ progress  │      │ probe     │      │ homography│     │ detector  │
  │ cancel    │      │ proxy     │      │ side calc │     │ tracker   │
  │ checkpoint│      │ audio     │      └───────────┘     └───────────┘
  └───────────┘      │ frames    │       (later phases)
                     └───────────┘
```

Crates for later phases (`court`, `vision`, `rally`, `score`, `highlight`) are created as part of the layout but stay empty of behavior in this change; only `api`, `jobs`, `media`, and the storage helper carry implementation.

### D4. Flutter to Rust via `flutter_rust_bridge` v2

The bridge carries frequent structured traffic — job progress events, media metadata, match and rally records — so hand-written marshalling would be a persistent tax and a source of memory bugs. `flutter_rust_bridge` v2 generates typed bindings and supports async and streaming calls, which the job model needs.

Alternatives considered: raw `dart:ffi` with `cbindgen` (rejected — more control than this project needs, paid for in boilerplate and manual lifecycle management); a platform-channel design (rejected — pushes engine work into Dart and splits the pipeline).

The cost is a codegen step and version coupling, so the bridge version is pinned and bindings are regenerated as a verification step rather than by hand.

### D5. The application owns the catalog; the engine owns artifact files

Persistent data splits by shape rather than by layer:

| Data | Owner | Storage |
| --- | --- | --- |
| Match, rally, score event, highlight clip records | Flutter app | SQLite catalog via a Dart ORM |
| Proxy video, analysis audio, calibration, frame and track data | Rust engine | Files inside a per-match artifact directory |

The alternative — giving the engine ownership of SQLite — was rejected because it makes every UI query a bridge round trip and couples the engine to a schema that the UI frequently reshapes. The other alternative, both sides writing one SQLite file, was rejected because concurrent writers invite corruption and undefined behavior. Keeping per-frame track data out of SQLite also avoids storing hundreds of thousands of rows that the UI never queries row-wise.

The catalog schema follows the data model in `docs/README.md` so that later phases add columns rather than restructure tables.

### D6. Long-running work runs as an explicit, resumable, cancellable job

Mobile operating systems suspend backgrounded applications, and analysis of a 30–60 minute recording will outlive a foreground session. A single long-running function call would therefore be lost on suspension and could not report progress or be cancelled.

The engine exposes a job session with a stable identifier, stage-labeled progress events, a cancellation signal, and checkpoints written into the match directory. A job interrupted mid-stage resumes from the last completed checkpoint instead of restarting. Cancellation leaves partial artifacts explicitly marked non-final so they are never mistaken for completed results.

Alternatives considered: fire-and-forget with a completion callback (rejected — no progress, no resume, no cancel); in-memory task queue with no persistence (rejected — same loss on suspension).

### D7. Inference runtime is abstracted now, chosen later

No detection or pose code ships in this change, but the vision crate is created with trait boundaries for a person detector and a pose estimator so that the later choice between an on-device TFLite model, a platform ML kit, or an ONNX-based model does not reshape the pipeline. The on-device TFLite route with an Apache-2.0 licensed model is the intended default because it matches the no-cloud constraint and keeps redistribution terms reviewable.

### D8. Model and asset distribution favors bundling, with optional packs treated as a reviewed exception

The product promises fully offline operation, which is in tension with distributing model packs on demand. The base layout assumes small models are bundled for the features that ship, and any optional pack is an explicit, user-initiated download whose terms are recorded in the license register. Bundle size is tracked as a constraint rather than discovered later.

## Risks / Trade-offs

- **Mobile toolchain absent, so the client track cannot be verified here** → Order milestones so the engine track proceeds independently, add a preflight command that reports exactly what is missing, and treat Flutter work as gated rather than blocked.
- **Final media library choice is unresolved** → Keep all media access behind the media crate, prefer platform-native encode and export paths that are license-clean regardless, and block export work until the decision is recorded.
- **A GPL-configured FFmpeg is already installed on this machine and could be linked by accident** → Make the preflight check report the FFmpeg configuration and fail a shipping-target build when GPL components are detected.
- **Two-track development can drift, with the UI expecting an engine contract that does not exist** → Freeze the facade DTOs and job interface early, and generate bindings rather than hand-maintaining them.
- **Bridge codegen couples engine and client versions** → Pin the bridge version and regenerate bindings as a verification step.
- **Artifact directories grow large, since track data scales with duration and frame rate** → Define the directory layout with derived artifacts clearly separable and deletable, and record a retention rule so a match can be reduced to its original plus catalog record.
- **Proxy generation is slow on low-end hardware** → Sample frames at a reduced rate for analysis, keep proxy resolution low, and defer throughput targets to Phase 0 benchmarking rather than inventing them now.
- **"Project base" changes expand indefinitely** → The non-goals list is explicit, and deferred work is assigned to named follow-up changes rather than absorbed.
- **Offline promise versus optional model downloads** → Default to bundling, require an explicit user action and a register entry for any download, and keep the promise honest in user-facing copy.

## Migration Plan

The repository is greenfield, so there is no data or behavior to migrate.

Rollout is simply merge order: the workspace layout and documentation land first, then the engine foundation, then the Flutter shell once the toolchain is installed. Rollback is reverting the change; because no user data exists, there is no state to unwind.

Two hygiene requirements accompany the change: ignore build outputs and generated artifacts in version control, and keep per-match artifact directories outside the repository so test media never gets committed.

## Decisions resolved during implementation

Recorded at the end of the engine track, as required by task 9.5. The decisions
above were the plan; these are the choices the code actually made where the plan
left room.

### R1. The analysis path uses license-clean encoders inside the media crate

D2 left the analysis-side codec open. The proxy is encoded with ffmpeg's built-in
MPEG-4 Part 2 encoder (`-c:v mpeg4`) and the analysis audio with the built-in AAC
encoder (`-c:a aac`), both of which are native to ffmpeg and therefore available
in an LGPL-only build. Neither is used for the exported highlight video, which
stays on the platform-native path (AVFoundation/VideoToolbox on iOS, MediaCodec
on Android).

Consequence: the development machine's GPL build is usable as a developer tool
without creating a shipping dependency, and `tools/preflight.sh
--strict-license` fails a shipping check that finds GPL components.

### R2. Media access sits behind a discovered toolchain, not a bundled binary

`sportcut-media` resolves `ffmpeg` and `ffprobe` from `SPORTCUT_FFMPEG` /
`SPORTCUT_FFPROBE`, then from `PATH`, and errors with an actionable message when
either is missing. There is deliberately no bundled-binary fallback, because
bundling is the licensing decision this design defers until the Phase 0
measurements land.

### R3. The pipeline is four checkpointed stages, not one call

`probe`, `proxy`, `audio`, and `frames` are separate stages that the job model
drives and checkpoints one at a time (`sportcut_jobs::execute` plus
`sportcut_media::run_stage`). This is what makes resume work: an import
interrupted after `proxy` re-runs only `audio` and `frames`, and importing an
already-complete match executes nothing.

Two supporting choices fall out of it:

- `checkpoints.json` and `manifest.json` live side by side in the match
  directory; checkpoints record progress, the manifest records artifacts.
- Artifact paths are fixed within the match directory (`proxy/proxy.mp4`,
  `audio/analysis.m4a`, `frames/`), so an artifact can be located from the
  manifest alone.

### R4. The facade is the only FFI surface and it is exercised in Rust

`sportcut-api` defines the DTOs, conversions, and four entry points —
`probe_media`, `import_media`, `match_manifest`, `regenerate_match_media` — and
`flutter_rust_bridge` is pinned to `=2.13.0` with `flutter_rust_bridge.yaml`
pointing at `crate::api`. Facade behaviour is covered by Rust tests, so the
contract the client will bind to is already tested; what remains for the client
track is generating the bindings and wrapping them in Dart.

### R5. Test media is generated, never committed

Media tests build their fixtures with the local ffmpeg into a temporary
directory, and skip with a printed reason when the toolchain is absent. The
trade-off is deliberate: no redistribution question attaches to the fixtures,
and the cost is that a machine without ffmpeg reports passing tests that did not
actually exercise media. `tools/preflight.sh --profile engine` is the guard
against that being mistaken for coverage.

### R6. The bridge is built into the engine behind a feature flag

`sportcut-api` declares `flutter_rust_bridge` as an optional dependency and
compiles the generated glue only under the `bridge` feature. The generator runs
with `add_mod_to_lib: false`, and the module declaration is committed in
`lib.rs` behind that feature. The workspace lint for `unsafe_code` moved from
`forbid` to `deny` for the same reason: the generated FFI entry points contain
`unsafe`, and `forbid` cannot be overridden locally. The override is a single
`#[allow(unsafe_code)]` on the generated module; every hand-written crate still
forbids unsafe at its root.

Consequence: `tools/verify-engine.sh` and a fresh clone build with no Dart
toolchain, which is what the `project-bootstrap` spec requires, while the
Flutter build turns the feature on through `tools/build-engine-lib.sh`.

### R7. The client layer is seam-driven so it can be tested without a device

Three interfaces carry the platform-dependent behaviour, and each exists because
it makes the client testable off-device:

| Interface | Real implementation | Test double |
| --- | --- | --- |
| `MediaEngine` | `BridgeMediaEngine` over `SportcutEngine` | `FakeMediaEngine`, and the real engine in `bridge_test.dart` |
| `MatchLibrary` | `MatchRepository` over SQLite | `FakeMatchLibrary` |
| `PlaybackController` | `VideoPlayerPlaybackController` over `video_player` | `FakePlaybackController` |

This was not decoration: widget tests run in a fake-async zone where real
asynchronous database and filesystem calls never complete, so a screen holding a
concrete repository hung the suite. The same seam keeps the SQLite behaviour
covered by ordinary tests that do run real I/O.

### R8. Client stack choices inside the plan's stated range

The plan named "Riverpod or Bloc" and did not name a router, an ORM, or a
playback package. The choices, and why:

- **`flutter_riverpod`** for state and dependency injection. The engine,
  repository, file picker, and playback factory are providers, so a test
  overrides exactly the piece it cares about.
- **A plain route table** (`lib/src/app/router.dart`) rather than `go_router`.
  Seven screens, no deep links, no nested navigation yet: a routing package
  would add a dependency without removing code. The table is the single place to
  change when that stops being true.
- **`sqflite` with a hand-written schema and migrations**, wrapped in
  `MatchCatalog`, rather than a code-generating ORM. The schema follows the
  product data model and is versioned from the start, which is what the spec
  requires; an ORM can be layered on later without touching the screens.
- **`video_player`** for playback, behind `PlaybackController`.
- **Match artifacts live under `<documents>/SportcutMatches/<match-id>/`**, and
  the original recording is referenced in place: never copied, and never deleted
  when a match is deleted.

### R9. Recording the client track's remaining gap

Flutter 3.47.5 with Dart 3.13.4 was installed during implementation, which
unblocked bridge generation, the Dart wrappers, the Flutter scaffold, the
library, and the catalog. A full Xcode installation, the Android SDK, and a JDK
are still absent, so task 7.1 is only partly done and tasks 7.5 and 9.2 cannot
be verified: the Gradle/CocoaPods wiring that links the engine into the platform
builds, and a run on a device or simulator.
`docs/verification/client-track.md` records exactly what was and was not
verified.

### Still open

Unchanged from the list below, plus the client track that the mobile toolchain
gates: platform scope (iOS first versus both in parallel), the final media
library and export path, desktop analysis mode, distribution channel, test
footage, and model sourcing. Sections 6.3–6.4, 7, 8, 9.2, and the client half of
9.4 remain unverified on this machine; `tools/preflight.sh --profile mobile`
lists what has to be installed first.

## Open Questions

- **Platform scope**: iOS only first, or iOS and Android in parallel? This changes CI needs, bridge packaging, and the amount of platform-native media code required.
- **Final media library selection**, to be settled by Phase 0 measurements of probe accuracy, decode speed, and license fit, rather than by preference.
- **Desktop analysis mode**: whether a macOS build ships as a development or power-user mode. It would make heavy models and a GPL FFmpeg build permissible in that target, but it changes the licensing analysis and should be decided deliberately.
- **Distribution channel**: App Store and Play Store versus sideloading first. Store review raises the bar on bundled model and codec licensing.
- **Test footage availability**: the Phase 0 success criteria in `docs/README.md` cannot be evaluated without fixed-camera test recordings, and this is the gating input for the computer-vision track.
- **Model pack sourcing**: whether optional packs are acceptable at all given the offline promise, and if so, who hosts them and under what terms.
- **Reusable component packaging**: whether the engine eventually publishes as a standalone library for a desktop or server target, which would affect how strictly the facade crate avoids mobile-only dependencies.
