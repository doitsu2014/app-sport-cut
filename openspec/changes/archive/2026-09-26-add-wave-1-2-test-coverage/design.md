## Context

Waves 1 and 2 are implemented and their verification records are written, but
what those records establish varies from "an automated test in the suite" to
"this was read and it looks right" to "a harness outside the checkout printed
this once". The three suites that exist today:

| Suite | Entry point | Size | Covers |
| --- | --- | --- | --- |
| Engine | `tools/verify-engine.sh` | 23 tests | media pipeline, job lifecycle, import and one export through the facade |
| Client | `flutter analyze` + `flutter test` | 53 tests | catalog, library, playback, routing, formatters, the real bridge |
| Bridge | inside `flutter test` | `app/test/bridge_test.dart` | import, manifest, regeneration, export — with the real engine library |

Four properties of the repository constrain how the new tests are written.

**The engine must stay testable with Rust and a media toolchain alone.**
`verify-engine.sh` runs `cargo clippy --workspace --all-targets` and
`cargo test --workspace`, so anything added must lint under the workspace's
denied lints and must not pull in Flutter, Xcode, the Android SDK, or a JDK.

**Media fixtures are generated, never committed.** `core/crates/media/tests/support/mod.rs`
builds a recording with the local `ffmpeg` into a `tempfile` directory and
*skips* (with a diagnostic) when the toolchain is missing. `api/tests/facade.rs`
keeps its own smaller copy of that idea. There is no committed footage anywhere
in the repository and no network access in any test.

**The client's screens are already dependency-injected.** `ScoreScreen` takes a
`PlaybackController`; the review screens read `matchEditingProvider`, the
calibration controller reads `mediaEngineProvider`, and `library_providers.dart`
exposes providers for the catalog, repository, picker, and playback factory. The
existing widget tests already override them. What is missing is a double for
`MatchEditing` — the interface the review screens depend on — not an interface.

**Widget tests run in a fake-async zone**, where real filesystem and SQLite work
never completes. The repository's answer, recorded in
`docs/verification/client-track.md`, is that screens depend on interfaces and
widget tests use in-memory doubles, while persistence is covered by non-widget
tests against `sqflite_common_ffi`.

## Goals / Non-Goals

**Goals:**

- Make every scenario waves 1 and 2 shipped either repeatable by a command in
  this repository or explicitly manual with a stated reason.
- Cover the rules a future change is most likely to break by accident: edit-list
  validation, court geometry, the job handle contract, and the editing domain
  the score and the reel are derived from.
- Cover the product principle the client is responsible for — the user marks
  rallies and confirms winners, and the application invents neither.
- Keep both suites green and cheap enough to run on every change, on a machine
  that has only the toolchains the preflight already requires.

**Non-Goals:**

- New product behaviour. Any behaviour a new test finds to be wrong is a defect:
  the change pauses, records what it found, and the fix is either folded in
  deliberately or split out.
- Coverage of wave-3 code that does not exist yet (`vision`, `rally`, `score`,
  `highlight` are still empty crates), or of `add-platform-export-backend`
  before it lands. Scenarios in those areas are declared uncovered with the
  missing capability named as the reason.
- A coverage-metric gate, a CI pipeline, or device/simulator automation. The
  platform scope and the toolchain to run a device test are still undecided
  gates in the roadmap.
- Changing what the tests run under. `tools/verify-engine.sh`, `flutter analyze`,
  and `flutter test` stay the entry points; no new command is introduced.

## Decisions

### D1: Bucket every scenario, then pick the cheapest layer that can assert it

The triage is done first and recorded, because it is the deliverable the
verification records consume. Each scenario from the wave-1 and wave-2 specs
goes into exactly one bucket:

| Bucket | Example | Where the test goes |
| --- | --- | --- |
| Pure rule — deterministic function of its inputs | empty reel rejected; a duplicated corner rejected | unit module inside the crate that owns the rule |
| Pipeline / facade behaviour | a render without source audio; a cancelled export | integration test binary under the crate's `tests/`, fixture generated with ffmpeg |
| Client derivation or storage | the score after a correction; a calibration round-trip | non-widget Dart test (real SQLite via `sqflite_common_ffi`) |
| Screen decision | trim disabled with no clips; save refused with three corners | widget test with an in-memory double |
| Crossing the boundary | `court_geometry`, `job_cancel` | `app/test/bridge_test.dart`, against the real library |
| Device-only or blocked on missing capability | the share sheet; a player position from a tracker | manual-only, named in the record with its reason |

Alternative considered: cover everything at the highest level available (drive
each screen, or drive the whole facade per scenario). Rejected because the
fixture renders are the expensive part and a screen test cannot say *why* a
homography is wrong — a property test can.

### D2: Pure rules get unit modules; behaviour gets integration binaries

`core/crates/export/src/edit_list.rs` and the court crate hold rules that are
cheap to assert and awkward to reach from outside: `validate` names the offending
clip, `padded_span` clamps, the homography maps the unit square to itself,
`side_of` follows the net. These become `#[cfg(test)] mod tests` modules in the
files that own them, so the assertions can reach private helpers without widening
any public API.

The repository has no unit-test module yet, which is itself a reason to keep the
pattern narrow: anything that shells out to the media toolchain, needs a match
directory, or exercises a job goes in an integration binary under
`core/crates/export/tests/` or `core/crates/api/tests/`, matching what
`media`, `jobs`, and `api` already do.

Consequence to respect: the workspace's denied lints apply to test code too
(`clippy --all-targets`), so test helpers are written to be used rather than to
need `#[allow(dead_code)]`. The one existing exception, the `#![allow(dead_code)]`
at the top of `core/crates/media/tests/support/mod.rs`, is not copied.

Alternative considered: put every new engine test in `tests/` binaries.
Rejected — it would force geometry and validation internals into the public API
of crates whose whole point is a narrow surface.

### D3: The export tests carry their own small fixture helper rather than a shared crate

`Export` tests need the same thing `media` tests already have: a probe metadata
value, a generated video, an overlay image, a title image, and a music track.
Three options:

| Option | Cost | Verdict |
| --- | --- | --- |
| New dev-only crate `sportcut-testkit` used by `media`, `export`, and `api` tests | a new workspace member; touches existing tests to adopt it | the right refactor when a fourth consumer appears |
| Duplicate a small helper into `export/tests/support/` | ~60 lines, self-contained | **chosen** — same shape as `api/tests/facade.rs` today, and it does not touch tests the working agreement tells us to leave alone |
| `#[path]`-include `media`'s support module | no duplication | rejected — couples two crates' test binaries to a sibling's directory layout |

### D4: Renders are bounded and asserted by property, not by bytes

The fixture renders are the only slow part of the suite, so each test file
generates one small fixture (320×240, five seconds or less) and asserts several
scenarios against it instead of rendering per scenario. Bounds: no new test may
exceed the existing 120 s job deadline, and the engine suite's total time is
measured before and after.

Overlay, title, and audio assertions reproduce what the manual evidence did —
sample the rendered frames and audio windows and compare against the source —
rather than comparing output files to a golden recording. Golden files were
rejected: the local `ffmpeg` is a GPL development build whose encoder output
differs between versions, and the point of the assertion is that the overlay and
the mix are *present*, not that a particular encoder produced them.

### D5: The client's doubles stay doubles; production interfaces do not change

The review and calibration screens already depend on `MatchEditing`,
`MediaEngine`, `MatchLibrary`, and `PlaybackController`, and the existing widget
tests already override the providers that supply them. This change adds
`app/test/support/fake_match_editing.dart` — an in-memory implementation of
`MatchEditing` — and a small calibration double where the existing
`FakeMediaEngine` does not already answer (`storedCalibration`,
`lastSavedCalibration`, and `lastGeometrySegment` are already there).

The double must not become a second implementation of the product's arithmetic:
it stores rallies and clips in lists but derives the score with the real
`ScoreTimeline.fromRallies`, so a widget test cannot pass against a score the
application would never produce.

Alternative considered: make the widget tests drive the real repository over an
in-memory `sqflite_common_ffi` database. Rejected — under fake-async the database
futures do not settle, which is exactly why the existing screens depend on
interfaces.

### D6: Persistence is covered against real storage, not a double

`EditingStore` and `EditingRepository` are covered the way `match_catalog_test.dart`
and `match_repository_test.dart` already cover the library: a temporary directory,
a real SQLite file through `sqflite_common_ffi`, and `sqfliteFfiInit` in
`setUpAll`. The scenarios that need this are rally validation and adjustment,
clip keep/trim/reorder with the order surviving a reload, export settings,
a deleted rally detaching its clip rather than deleting it, and the match row's
calibration column round-tripping.

### D7: Scenarios with nothing to assert yet are declared, not stubbed

Three kinds of scenario have no test that could fail today, and none of them gets
a placeholder:

- **Blocked on a capability**: "edit list independent of renderer" needs a second
  backend; "side determined for a player position" needs a tracking stage.
- **Blocked on the toolchain gates**: anything requiring a device, a simulator,
  the share sheet, or a real recording's accuracy.
- **Blocked on the feature's own noise**: ergonomic questions like whether a
  handle feels right under a finger.

Each is recorded in the verification table as manual-only with that reason.
A stub that asserts nothing would be worse than the honest row.

### D8: The verification records change shape, and nothing parses them

The two wave records' "scenario to evidence" tables gain a column naming the test
for each row, and the prose that says "verified by reading the code" is replaced
by what actually covers each scenario. The records stay prose plus tables:
a script that parses specs and greps test names was considered and rejected as
brittle against prose that is deliberately written for a reader.

### D9: The working agreement stands; the roadmap's wave rule carries the coverage step

`AGENTS.md` says to implement first and to add tests when asked. This change is
exactly that ask, in one place, and does not need the agreement rewritten.
What waves 1 and 2 exposed is that closing a wave without coverage is how a
throwaway harness becomes the only evidence, so the roadmap's "working rule for
each wave" gains the coverage step: a wave's scenarios are covered or declared
manual-only with a reason before the wave is called done.

Alternative considered: amend `AGENTS.md` to require coverage for every change.
Rejected for now — it would contradict the deliberate "implement first" posture
for ordinary feature work, and the wave-closure rule gets the same protection
without that cost. Recorded as an open question below.

## Risks / Trade-offs

- **The engine suite gets slower, and a slow suite gets skipped.** → Bound the
  fixtures (D4), reuse one fixture per file, and record before/after timings in
  the verification record so a regression is visible.

- **A new test encodes today's behaviour as correct even where the spec says
  otherwise.** → Every test is written from the spec's WHEN/THEN, not from
  reading the implementation. If the two disagree, the change pauses: the
  artifact is updated or the defect is recorded, rather than the assertion being
  loosened to match the code.

- **Doubles drift from the real store or engine.** → The double reuses
  `ScoreTimeline` (D5); the real store is covered by the non-widget tests (D6);
  and the FFI surface is covered against the real library in `bridge_test.dart`.

- **`bridge_test.dart` needs the generated bindings and the built engine
  library**, so it is not runnable on a machine that has only Dart. That is
  already true of the file today, and its header documents the two commands; the
  new calls inherit the same requirement rather than adding one.

- **Test coverage of the renderer is time-limited by the export backend's
  replacement.** `add-platform-export-backend` will replace the ffmpeg renderer.
  The tests are written against the edit list and the rendered result — order,
  padding, title, overlay, audio — which is exactly the contract that change must
  keep, so they should survive it; the fixture-generation helper is the only part
  that assumes ffmpeg is present, and it skips when it is not.

## Migration Plan

No product migration: no schema change, no dependency change, no generated file
change. The suites run under the existing commands, and the change's own
verification run records the new counts and the engine suite's timing under
`docs/verification/`, alongside the updated wave records.

Rollback is deleting test files; nothing in the shipped paths depends on them.

## Open Questions

1. **Does `AGENTS.md` change after all?** The default here leaves the working
   agreement alone and puts the coverage step in the roadmap's wave rule. If the
   intent is that *every* change carries coverage from now on, that is an
   `AGENTS.md` edit and a different change.
2. **Do the ffmpeg-dependent tests fail or skip when the toolchain is missing?**
   The default is skip-with-diagnostic, matching `media` and `facade`. Failing
   would make a Rust-only machine unable to run `verify-engine.sh` to completion,
   which the guards in `AGENTS.md` argue against.
3. **Is the wave-0 import and library coverage in scope?** `docs/verification/video-import.md`
   has its own thin spots. This change stops at waves 1 and 2 as asked; widening
   it is a scope decision, not a technical one.
