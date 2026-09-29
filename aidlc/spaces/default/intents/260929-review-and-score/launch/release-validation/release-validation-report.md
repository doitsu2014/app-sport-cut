# Release Validation Report

Release candidate: working tree on commit `25534ff` (uncommitted change; two
files). Target: local macOS desktop app (`tools/run-macos.sh`).

## Requirement coverage

| Req | Evidence | Status |
| --- | --- | --- |
| RS-1, RS-2, RS-3 (Review & score under Analysis; order; Studio reduced) | Diff moves `PipelineStage.score` into `_analysis` and out of `_studio`; `_analysis` order is calibrate, analyze, track, score. Reviewed in `review-record.md`. | ✅ (code review; automated test deferred by policy) |
| RS-4 (still opens `ScoreView`) | `_item` → `onSelectStage` → `_buildCenter` `case PipelineStage.score` untouched; `flutter test test/score_screen_test.dart` → 5/5 pass. | ✅ |
| RS-5 (state/spinner intact) | Shared `_item`/`_FeatureItem` path unchanged; reviewed. | ✅ |
| RS-6 (Player analysis `onOpenScore`) | No diff; reviewed. | ✅ |
| RS-7 (no wider change) | `git diff --stat`: only `workspace_studio_screen.dart` and `docs/architecture.md`. | ✅ |
| RS-8 (doc matches) | `docs/architecture.md` diff shows the new grouping. | ✅ |
| RS-9 (`flutter analyze` clean) | `cd app && flutter analyze` → No issues found! (1.7s). | ✅ |
| RS-10 (existing tests) | Focused `score_screen_test.dart` green. Full suite not run per `AGENTS.md`. | ⚠️ partial |
| RS-11 (no new dep / engine change) | No `pubspec.yaml` / `core/` change. | ✅ |

No must-have requirement is unverified; two carry caveats recorded below.

## Verification re-run

- `tools/generate-bridge.sh` — generated bridge files (never committed); required
  before analysis in a clean checkout.
- `cd app && flutter analyze` — **No issues found!**
- `cd app && flutter test test/score_screen_test.dart` — **5/5 pass**.
- Full `flutter test` — **not run**, per the repo's "don't run test suites as
  ordinary work" rule. A prior intent recorded 18 pre-existing failures
  (library / highlights / app-shell / catalog) unchanged by this kind of change;
  none touch the rail.

## Known issues / caveats

1. **No automated ordering test.** The single regression test from the test plan
   is deferred because `AGENTS.md` forbids new test files unless asked. The
   grouping is verified by code review and the design record.
2. **Manual studio check outstanding.** The rail grouping is visible in the diff
   but has not been eyeballed in a running app. It requires `tools/run-macos.sh`;
   it is a cosmetic, low-risk check.
3. **Pre-existing test-suite failures** (not caused by this change) remain from
   earlier work; out of scope for this intent.

## Operational readiness

- **Rollback:** trivial — revert the two-file change. No data or schema.
- **Alerts / on-call:** none; local desktop app, no service.
- **Watch in the first hour:** nothing operational; a user would simply see the
  rail order.

## Release decision

**Go-with-known-issues (cosmetic).** The change is minimal, reversible, and
`flutter analyze` is clean. The only caveats are the deferred ordering test and
the pending manual look, neither of which blocks the release of a UI regroup.

A human owns the release decision.
