## Why

Waves 1 and 2 shipped, and both verification records are honest about how much
of what they claim was never automated. `docs/verification/manual-editing-and-export.md`
says "the review screens have no automated coverage" and lists six scenarios it
verified by reading the code; `docs/verification/court-calibration.md` verified
all twenty-one of its scenarios with a **throwaway harness built outside the
checkout and then deleted**. That evidence cannot be re-run, so nothing stops a
later change — the platform export backend, person detection, a refactor of the
catalog — from silently breaking the behaviour those waves are built on.

The gaps are not evenly spread and they are not equally expensive:

| Track | What is verified today | What is not |
| --- | --- | --- |
| Engine | 23 tests: media pipeline, job lifecycle, import/export through the facade | every rule in `EditList::validate`, all court geometry, every render behaviour the verification record observed by hand |
| Client | 53 tests: catalog, library, playback, routing, real bridge load | the entire editing domain — rallies, winners, the derived score, clip order — and every wave-1 and wave-2 screen |
| Bridge | `bridge_test.dart` drives import, manifest, regeneration, export | `court_geometry`, `save_match_calibration`, `match_calibration`, `job_cancel` never cross the Dart binding in a test |

The behaviour is worth locking down now because the next change on the critical
path is `add-platform-export-backend`, which replaces the renderer that the
export tests would otherwise pin, and because the client screens are the only
place the product principle is enforced — the user confirms every rally and
every winner, and no test currently asserts that the application never invents
one.

## What Changes

- The engine's deterministic rules become tests: edit-list validation (empty
  reel, clip outside the recording, non-finite or inverted boundaries, negative
  padding, out-of-range music gain, an unreadable overlay, title, or music file),
  padding clamped to the recording's bounds, and the court geometry — homography
  round-trip, the unit square mapping to itself, the net on the long axis in both
  orientations, side assignment, and the rejection of a degenerate quadrilateral.
- The engine's render behaviour becomes tests that generate their own ffmpeg
  fixtures and skip when the toolchain is absent, exactly as the existing media
  tests do: a render without a source audio track, padding clamped at the
  recording's edges, a title card prepended, the overlay composited into the
  encoded frames, music shorter than the reel, and a cancelled export leaving the
  previous reel's file untouched.
- The job surface is covered where it is only documented today: an unknown job
  handle, a client-requested cancellation, and the admission refusal naming the
  resource-intensive job.
- The client's editing domain gets the coverage it never had: rally validation
  and adjustment, winner confirmation and correction, the derived score timeline
  recomputed from a correction, clip keep/trim/reorder with the order surviving a
  reload, export settings, and a deleted rally leaving its clip detached rather
  than removed.
- The wave-1 review screens and the wave-2 calibration screen get widget tests
  driven by in-memory doubles over the interfaces the screens already depend on.
  No production interface is introduced for them: `MatchEditing`, `MediaEngine`,
  `MatchLibrary`, and `PlaybackController` already exist and widget tests already
  override them elsewhere. What is missing is a fake `MatchEditing`.
- `court_geometry`, `save_match_calibration`, `match_calibration` and `job_cancel`
  are exercised through the real Dart bindings in `app/test/bridge_test.dart`, so
  the calibration path is proven across the FFI boundary rather than only on
  either side of it.
- The verification records stop describing one-off runs as evidence: every
  scenario row in `docs/verification/manual-editing-and-export.md` and
  `docs/verification/court-calibration.md` names the test that covers it, or is
  re-classified as manual-only with the reason. Scenarios that cannot be covered
  yet because the feature they read does not exist — a second render backend, a
  tracking stage to feed a player position — are named as such instead of
  counted as verified.

## Capabilities

### New Capabilities

None. This change adds no product behaviour; it makes behaviour that already
ships repeatable to check.

### Modified Capabilities

- `project-bootstrap`: the developer-verification requirement extends from "the
  documented commands complete successfully" to what those commands must
  actually establish — every scenario a shipped capability's spec contains is
  either covered by a test in the documented suite or declared manual-only with
  a stated reason, and no scenario rests on evidence that cannot be re-run.

## Impact

- **Engine**: new test binaries under `core/crates/export/tests/` and
  `core/crates/court/tests/`, extensions to
  `core/crates/api/tests/facade.rs`, and unit-test modules inside the crates
  that own pure rules (`export::edit_list`, `court`). No production code is
  expected to change; if a rule turns out to be untestable without exposing it,
  that is a design conflict to resolve in the design artifact, not a reason to
  widen a public API. `tools/verify-engine.sh` runs the new tests unchanged, and
  the engine still builds with no Flutter, Xcode, Android SDK, or JDK.
- **Client**: new test files under `app/test/` for the editing domain, the
  catalog's calibration round-trip, and the five screens, plus a new
  `test/support/fake_match_editing.dart` double. `flutter test` remains the entry
  point.
- **Bridge**: `app/test/bridge_test.dart` grows; no generated file is edited and
  no version pin moves, because the facade surface itself does not change.
- **Dependencies**: none. Doubles are hand-written, as the existing ones are, and
  fixtures are generated with the local `ffmpeg` into temporary directories — so
  `docs/legal/dependency-register.md` gains no row and no media is committed.
- **Documentation**: the two wave verification records, the roadmap's
  "Verification" paragraph and its working rule for each wave, and the test-count
  claims in `docs/verification/client-track.md` change. `AGENTS.md`'s "implement
  first, tests are optional" agreement stays as it is: this change is the
  explicit request the agreement asks for.
