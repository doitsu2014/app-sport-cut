# Test Plan — Move Review & score to the Analysis menu

## Risk ranking

| Requirement | Impact if wrong | Likelihood | Risk | Depth |
| --- | --- | --- | --- | --- |
| RS-1, RS-2, RS-3 (grouping and order) | Low (cosmetic confusion) | Medium (a later edit can silently revert it) | **Medium** | Deepest available: one ordering widget test, else manual + code review |
| RS-4, RS-5, RS-6 (score still opens, state/spinner intact) | Medium (would break a working feature) | Very low (shared `_item` path untouched) | Low | Regression via existing score tests + manual |
| RS-7 (no wider change) | Medium | Very low | Low | Diff review |
| RS-8 (doc) | Low | Medium | Low | Doc review |
| RS-9, RS-10 (analyze/tests) | Medium | Low | Low | Local commands |
| RS-E1, RS-E2, RS-E3 (edge cases) | Low | Low | Low | Covered by the widget test / manual |

Effort follows impact × likelihood: the only non-trivial risk is silent
regression of the grouping, which is exactly what a single ordering assertion
retires.

## Strategy

| Level | What | Scope |
| --- | --- | --- |
| Widget (unit-level) | **One** focused test: pump the rail (or its groups) and assert the Analysis order (Mark court, Prepare analysis, Player analysis, Review & score) and that Studio is Highlight/Export only. Named for RS-1/RS-2/RS-3. | The whole requirement |
| Widget (regression) | Existing `app/test/score_screen_test.dart` covers `ScoreView`; it must stay green (RS-4). | Score behaviour |
| Manual | Launch the studio (`tools/run-macos.sh`), confirm the rail reads Play, Analysis (…, Review & score), Studio (Highlights, Export), and that Review & score opens the score view. | RS-1..RS-6, RS-E1..RS-E3 |
| Static | `flutter analyze`; diff review that only two files changed. | RS-7, RS-9, RS-11 |

**Happy-path floor:** at minimum, the rail must render both groups with the
correct membership and open the score view from its new position.

**Repo policy caveat:** `AGENTS.md` says not to add test files unless the user
asks. The single ordering test is therefore *planned and recommended*, and the
Test Generation stage may record it as deferred; the manual + static checks are
the mandatory floor either way.

## Environments and data

- Flutter widget tests in `app/test/`, driven by the existing provider/controller
  fakes (no engine binary). No production footage or user data.
- A minimal `VideoStageFacts` / stage-state map so the rail can render; no
  artifacts on disk.
- If a studio-level pump proves expensive, test the grouping at the smallest
  widget boundary that still observes `_analysis` / `_studio` order.

## Exit criteria

- `cd app && flutter analyze` exits 0. **Already met** (No issues found).
- If the ordering test is generated: `flutter test <the new test>` passes.
- Existing `score_screen_test.dart` passes.
- Manual studio check confirms the new grouping and that Review & score works.

## Deliberately not tested

- Pixel styling, colours, fonts, and exact spacing (no behaviour).
- `resolveStageStates` and stage prerequisites (unchanged; covered by existing
  tests elsewhere).
- The exact wording of `docs/architecture.md` (doc review, not a test).
- Golden/screenshot tests — not used in this repo.
