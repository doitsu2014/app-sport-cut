# Implementation Plan

This plan is owned by the OpenSpec change
[`bootstrap-project-base`](../../openspec/changes/bootstrap-project-base/proposal.md).
That change is the source of truth for the behaviour being built here; this file
is the human-readable map of the milestones and the setup split. That change is
now archived, so the table below records what the foundation delivered. For what
gets built next, see [`roadmap.md`](roadmap.md).

## Milestones

| # | Milestone | Change section | State |
| --- | --- | --- | --- |
| M0 | Repository foundation: layout, documentation, dependency register | `1. Repository foundation` | done |
| M1 | Toolchain preflight and setup documentation | `2. Toolchain preflight` | done |
| M2 | Native engine workspace and headless CLI | `3. Native engine workspace` | done |
| M3 | Media pipeline: probe, proxy, analysis audio, frame sampling, artifacts | `4. Media pipeline` | done |
| M4 | Processing job model: progress, cancellation, checkpoints, concurrency | `5. Processing job model` | done |
| M5 | Engine-to-client bridge: pinned codegen, frozen DTOs, Dart wrappers | `6. Engine to client bridge` | done |
| M6 | Mobile client shell | `7. Mobile client shell` | done, except the Android side of the platform build integration (bootstrap task 7.5) |
| M7 | Match library and local catalog | `8. Match library and catalog` | done |
| M8 | Verification and documentation | `9. Verification and documentation` | in progress — parked on the manual device flow (bootstrap task 9.2) |

The bootstrap change is archived, so its three unfinished tasks stay parked
rather than reopening it: installing and verifying the Android SDK and JDK
(7.1), linking the engine into the iOS and Android builds (7.5), and the manual
end-to-end flow on a device (9.2). The macOS and iOS builds run today; Android
is the part that is still missing.

## Imported recordings

Import takes custody of the recording the user picks. The platform pickers hand
back a file they made themselves in a directory the operating system is free to
empty — `NSTemporaryDirectory()` on iOS, the app cache on Android — so the picked
path is an input to a copy and never the value that is stored. The match records
the app-owned copy under `SportcutRecordings/<matchId>`, beside (not inside) the
engine's artifact directory, so deleting analysis files can never take the
recording with it.

The file the user selected is left exactly where it was: never written to,
moved, renamed, or deleted. The library reports a recording that has gone
missing rather than failing silently when it is played.

## Milestone order and the two tracks

The product plan orders work starting at Flutter video import and playback. When
this plan was written that order was not executable here — Flutter, a full Xcode
installation, and the Android SDK were all absent — so the work was split into
two tracks that meet at the bridge:

```
engine track                                  client track
core/  Rust workspace, media pipeline, jobs ──► bridge ──► app/  Flutter shell, library
```

The split has since paid off: Flutter and Xcode arrived, the engine had already
been built and tested without them, and the two tracks meet at the bridge as
designed — `app/test/bridge_test.dart` loads the real engine library. Android is
the only platform still without a toolchain.

- **Engine track** — milestones M0 to M5. Every step is verified with
  `tools/verify-engine.sh` before the next one starts.
- **Client track** — milestones M6 and M7, verified with `flutter analyze` and
  `flutter test` in `app/`. Flutter 3.47.5 and Xcode 26.6 are installed and the
  macOS and iOS builds succeed; the Android SDK and a JDK are not installed, so
  Android work is still gated.

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
