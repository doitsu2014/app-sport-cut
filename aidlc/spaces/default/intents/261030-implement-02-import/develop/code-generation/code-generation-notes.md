# Code Generation Notes — Import and Media Preparation (Feature 2)

Status: Develop / Code Generation
Intent: `261030-implement-02-import`

## Commands run (exact) and results

| Command | When | Result |
| --- | --- | --- |
| `cd app && flutter analyze` | per lane, post-edit (4 agents) | 0 issues in any unit's files; only pre-existing foreign infos |
| `cd app && flutter analyze` | conductor, after all lanes | **4 issues, all `prefer_const_constructors` infos**: `test/export_screen_test.dart:170`, `test/support/fakes.dart:119`, `test/support/fake_match_library.dart:146`/`:152` |
| `git blame` on the 4 lint lines | conductor | all four predate this change (commits `66b7ce0`, `ee5e5f6`); the fake's two shifted +1 line because U1 added the parameter above them |
| `tools/check-no-rust-in-app.sh` | conductor, after all lanes | `OK (no Rust, FFI, or generated bindings in the client)`, exit 0 |
| `flutter test` / `tools/verify-engine.sh` | — | **not run** — working agreement: no suites in ordinary work; no `core/` file changed |

Conclusion: zero analyzer issues introduced; the 4 remaining infos are
baseline. `flutter analyze` is as clean on this branch as it was on
`d33d123` (same 4 infos).

## Deviations from the technical spec

1. **U0 scope addition (conductor)**: the committed working-tree fix left
   `SocketOption` in the `dart:io` show clause, producing an
   `unused_shown_name` warning; removed and folded into the U0 commit by
   amend before any unit landed.
2. **U2 naming**: the `onProgress` closure parameter is named `fraction`
   (spec sketch used placeholder `f`); the state update was wrapped across
   lines for the 80-column format. Semantics identical.
3. **U1 fake lints not fixed**: silencing the two pre-existing
   `prefer_const_constructors` infos in `fake_match_library.dart` would
   require edits beyond the unit's named change; left as baseline (recorded
   as a follow-up, not a defect of this change).
4. No other deviations; all four lane agents reported `deviations: none`
   against their spec sections, and the conductor verified each diff against
   spec §2.1–§2.7 before committing.

## Known baseline issues (not caused by, and not fixed by, this change)

- `app/test/analysis_screen_test.dart` (4 cases) and
  `app/test/library_screen_test.dart` (several cases) fail at `d33d123`:
  `ScSectionHeader` uppercases labels ("Artifacts" vs "ARTIFACTS"),
  `ScButton` is not a `FilledButton`, and the "No matches yet" home screen
  was removed in `757c748`. Per the working agreement these stale
  expectations were not repaired; the units guarantee only that the files
  still compile (verified via `flutter analyze`, which analyzes test files).
- NFR-2's once-per-second cadence is not delivered (percentage stepping per
  approved DD-1) and the large-file timing benchmark stays deferred; both
  are recorded in the BRD by U5.

## U5 record

- Single docs agent implemented spec §2.8 against the landed commits
  (`4cb33db`..`62a57c3`); both BRDs bumped to Version 1.1 / 2026-10-30 with
  the source baseline updated and prior provenance (`1541c64`) retained.
- Conductor reviewed the full diff before committing (`4343663`): no Must
  acceptance text changed (only the two "Not implemented at baseline"
  markers removed); §7 rows say "Implemented; not suite-verified", never
  "Passed"; baseline-red widget tests recorded; NFR-7 waiver stated;
  R-IMP-1 partial / R-IMP-2 mitigated / Q-IMP-4 answered; BR-8 pointer
  fixed; BR-9 accessibility gap and all deferred ADR-0001 / timing text
  preserved.
- Agent-reported deviations (all formatting-level, accepted): revision row
  added to the existing approval tables instead of a new changelog; Q-IMP-4
  closed in place via `Q-IMP-4 (answered)` to keep the 4-column table;
  baseline-red tests got a dedicated evidence row.
- Only the two BRD files were modified (verified via `git status` before
  the commit).
