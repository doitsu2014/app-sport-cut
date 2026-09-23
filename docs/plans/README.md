# Implementation Plan

This plan is owned by the OpenSpec change
[`bootstrap-project-base`](../../openspec/changes/bootstrap-project-base/proposal.md).
That change is the source of truth for the behaviour being built here; this file
is the human-readable map of the milestones and the setup split.

## Milestones

| # | Milestone | Change section | State |
| --- | --- | --- | --- |
| M0 | Repository foundation: layout, documentation, dependency register | `1. Repository foundation` | in progress |
| M1 | Toolchain preflight and setup documentation | `2. Toolchain preflight` | in progress |
| M2 | Native engine workspace and headless CLI | `3. Native engine workspace` | in progress |
| M3 | Media pipeline: probe, proxy, analysis audio, frame sampling, artifacts | `4. Media pipeline` | in progress |
| M4 | Processing job model: progress, cancellation, checkpoints, concurrency | `5. Processing job model` | in progress |
| M5 | Engine-to-client bridge: pinned codegen, frozen DTOs, Dart wrappers | `6. Engine to client bridge` | in progress |
| M6 | Mobile client shell | `7. Mobile client shell` | done (platform builds still gated on Xcode/Android SDK) |
| M7 | Match library and local catalog | `8. Match library and catalog` | done |
| M8 | Verification and documentation | `9. Verification and documentation` | in progress |

## Milestone order and the two tracks

The product plan orders work starting at Flutter video import and playback. That
order is not executable on a machine without Flutter, a full Xcode
installation, or the Android SDK, so the work is split into two tracks that meet
at the bridge:

```
engine track (buildable now)                    client track (needs the toolchain)
core/  Rust workspace, media pipeline, jobs ──► bridge ──► app/  Flutter shell, library
```

- **Engine track** — milestones M0 to M5. Every step is verified with
  `tools/verify-engine.sh` before the next one starts.
- **Client track** — milestones M6 and M7, verified with `flutter analyze` and
  `flutter test` in `app/`. The Flutter SDK and Dart are installed; a full Xcode
  installation, the Android SDK, and a JDK are not, so building or running the
  app on a device is still gated.

## Setup steps by track

Run `tools/preflight.sh --profile engine` or `tools/preflight.sh --profile mobile`
to check one track at a time.

| Step | Engine-only work | Mobile client work |
| --- | --- | --- |
| Rust toolchain (`rustc`, `cargo`) | required | required (the app embeds the engine) |
| Media toolchain (`ffmpeg`, `ffprobe`) | required | required, and must be license-clean for shipping |
| Flutter SDK + Dart | not needed | required |
| Full Xcode installation | not needed | required for iOS |
| Android SDK + platform tools | not needed | required for Android |
| JDK | not needed | required for Android |

Media toolchain licensing is the one setup step that is not merely
convenience: the Homebrew FFmpeg on this machine is a GPL build, which cannot be
linked into a proprietary mobile distribution. `tools/preflight.sh` reports the
detected configuration and flags GPL components; the shipping path uses
platform-native media APIs instead. See
[`docs/legal/dependency-register.md`](../legal/dependency-register.md).

## Bridge regeneration

`flutter_rust_bridge` v2 generates both sides of the bridge. Generated files are
never hand-edited and never committed:

| Generated artifact | Path |
| --- | --- |
| Rust glue | `core/crates/api/src/frb_generated.rs` |
| Dart bindings | `app/lib/src/bridge/generated/` |

Regenerate with `tools/generate-bridge.sh` (see milestone M5). Hand-written,
typed Dart wrappers live in `app/lib/src/bridge/` next to — not inside — the
generated directory.

## Verification

Each milestone closes with its evidence recorded:

- Engine: `tools/verify-engine.sh` (format, lint, test).
- Client: `flutter analyze` and `flutter test` in `app/`, including
  `test/bridge_test.dart`, which loads the real engine library.
- Preflight: `tools/preflight.sh`, output captured in
  [`docs/verification/`](../verification/).
- Offline guarantee: the media pipeline runs with network access unavailable;
  the evidence is recorded with the same command output.
