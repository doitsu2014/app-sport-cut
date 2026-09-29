# Release Validation Report

| Req | Evidence | Status |
| --- | --- | --- |
| BR-1..BR-5 | `unanalysed_match.rs`: 3 tests fail before the fix, all 4 pass after | ✅ |
| BR-6 | Only `core/crates/api/src/facade.rs` and one new test file change; no Dart, DTO or signature changes | ✅ |
| BR-7 | `tools/verify-engine.sh` exits 0 | ✅ |

**Not verified in the running app.** The macOS app links the prebuilt engine
library, so the fix only reaches the app after the engine is rebuilt and the
app relaunched (`tools/run-macos.sh`). The expected result for
`match-1790673937629414-1` is that the Review panel shows "Manual marking is
available" with no error text. After Prepare and player tracking, "Analyze
rallies" works as before.

Decision: ready for human review. The change is uncommitted and shares the
working tree with the accuracy-harness feature. It is isolated to two files,
so it can be committed separately.
