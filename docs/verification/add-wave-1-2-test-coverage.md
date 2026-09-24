# Wave 1 and 2 test coverage verification

Evidence for
[`add-wave-1-2-test-coverage`](../../openspec/changes/add-wave-1-2-test-coverage/proposal.md),
gathered with Flutter 3.47.5 / Dart 3.13.4, Rust 1.97.1, and FFmpeg 8.1.1 on
macOS (`SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin`).

## What this change is

Tests, and only tests. No engine or client behaviour changed, no schema changed,
no dependency was added, and no generated file was touched:

```bash
git diff --stat core/Cargo.lock
git status --short | grep -E 'generated|frb_generated'
```

```text
(no output: the lock file is untouched)
(no output: no generated file is modified)
```

`docs/legal/dependency-register.md` therefore gains no row. The two suites grew
from 23 engine and 53 client tests to 69 and 127, and every scenario in the
wave-1 and wave-2 specifications now names the test that covers it or is
recorded as manual-only with a reason.

## Engine

```bash
tools/verify-engine.sh
```

```text
==> cargo fmt --all -- --check
==> cargo clippy --workspace --all-targets -- -D warnings
==> cargo test --workspace
==> engine verification passed
```

| Binary | Tests | Where the growth came from |
| --- | --- | --- |
| `core/crates/court` (unit) | 20 | new: validation, homography, net, sides, outline |
| `core/crates/export` (unit) | 13 | new: every rule of `EditList::validate`, padding, tolerance |
| `core/crates/export/tests/render.rs` | 6 | new: order, padding, title, overlay, audio, music, cancellation |
| `core/crates/api/tests/facade.rs` | 11 | +7: unknown handle, cancellation, admission, calibration save/read/invalidate, regeneration partition |
| `core/crates/jobs/tests/job_lifecycle.rs` | 7 | unchanged |
| `core/crates/media/tests/media_pipeline.rs` | 10 | unchanged |
| `core/crates/media/tests/offline.rs` | 2 | unchanged |

The engine workspace still builds and tests with only Rust and the media
toolchain. The six render tests generate their own fixtures — a two-colour
recording, an overlay image, a title card, and a short music track — into a
temporary directory the test removes, skip with a diagnostic when `ffmpeg` is
absent, and touch no network. The fixture helper is local to the export crate,
so the workspace gained no crate and the lock file is unchanged.

Cost: the render binary runs in 0.36 s and the extended facade binary in 2.7 s;
`cargo test --workspace` completes in about 6.5 s with warm caches. The render
assertions read the pixels and the audio windows of the encoded output and
compare them with the source and with the overlay image, rather than comparing
against a golden file — the local encoder is a GPL development build whose
output is not what a shipping backend will produce.

## Client

```bash
cd app && flutter analyze
cd app && flutter test
```

```text
Analyzing app...
No issues found! (ran in 1.4s)

00:03 +127: All tests passed!
```

New files: `score_timeline_test.dart`, `editing_repository_test.dart`,
`score_screen_test.dart`, `highlights_screen_test.dart`, `export_screen_test.dart`,
`overlay_renderer_test.dart`, `calibration_controller_test.dart`,
`calibration_screen_test.dart`, `analysis_screen_test.dart`, plus the doubles
`support/fake_match_editing.dart` and `support/fake_overlay_renderer.dart`.
`match_catalog_test.dart`, `bridge_test.dart`, and `support/fakes.dart` were
extended.

Three environment facts shaped the client tests and are recorded here rather
than rediscovered:

- **Widget tests run in a fake-async zone**, so real asynchronous file and
  database work never completes there. The screens are therefore driven through
  the interfaces they already depend on, and the doubles write files
  synchronously. Persistence is covered by the non-widget repository and catalog
  tests against real SQLite.
- **`dart:ui` rasterisation does not complete inside a widget test**, so the
  export screen's test uses an overlay-renderer double that records what it was
  asked to draw, and the real renderer has its own plain test
  (`overlay_renderer_test.dart`).
- **`ReorderableListView` reorders on a long press on touch platforms**, so the
  reorder test pins the theme's platform rather than depending on the host.

## A pre-existing race this change surfaced

The engine reports a job's terminal state a moment before the job's worker
releases the heavy-job admission slot, so a caller that starts the next import
the instant the previous one finished can be told another heavy job is running.
Two pre-existing tests chain imports that way and fail intermittently (observed
roughly one run in five of `core/crates/api/tests/facade.rs` and of
`app/test/bridge_test.dart`).

The behaviour is not reachable from the application — a user has to tap import
again — but the tests are correct to assert that a finished job's slot is free,
so the chained starts wait for the slot with a bounded retry
(`start_import_when_admitted`, `importWhenAdmitted`) and the observation is
recorded in
[`manual-editing-and-export.md`](manual-editing-and-export.md) under "Limits
recorded, not hidden". Releasing the slot before the terminal state is a small,
separate change to `sportcut-jobs`.

```bash
# eight consecutive runs of the binary that used to flake
for i in 1 2 3 4 5 6 7 8; do cargo test -p sportcut-api --test facade; done
```

```text
test result: ok. 11 passed; 0 failed   (× 8)
```

## What is not covered

Both wave records list their manual-only rows with a reason: the platform share
sheet, running any of this on a device or simulator, calibrating a real
recording, and the two scenarios whose feature does not exist yet — a second
render backend, and a player position from a tracking stage. `docs/plans/roadmap.md`
now carries the same rule for future waves: a wave is not closed until its
scenarios are covered or declared.
