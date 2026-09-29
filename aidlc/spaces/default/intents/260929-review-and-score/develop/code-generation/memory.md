# Code Generation — diary

## Interpretation
- 2026-09-29: There is no pre-existing studio-rail test, so `flutter analyze`
  plus the absence of any rail reference in `app/test` is the strongest cheap
  evidence that nothing regresses.

## Deviation
- 2026-09-29: Skipped U3 (ordering test) per `AGENTS.md`'s "do not write new test
  files unless asked". Recorded in `code-generation-notes.md` with the reasoning.
- 2026-09-29: `flutter analyze` initially reported 326 errors from the missing
  generated bridge. Ran `tools/generate-bridge.sh` (the documented step) rather
  than treating it as a failure; analyze then passed cleanly.

## Tradeoff
- 2026-09-29: Did not run the full `flutter test` suite, to respect the repo's
  "don't run tests as ordinary work" rule. The risk is near-zero because the diff
  moves one list element and no test touches the rail.

## Open question
- 2026-09-29: None.
