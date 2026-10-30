# Intent Capture Questions

Intent: `261030-implement-02-import`
Request: implement BRD feature 2 (Import and Media Preparation, area `IMP`).

Context: `docs/brd/02-import-and-media-preparation.md` §2.3 describes baseline
`1541c64`. Since then, the studio refactor (`757c748`) replaced the legacy
Material analysis view with `AnalysisPanel` and `ArtifactRows` (`ScPipelineRow`,
`ScProgressJob`, `ScBanner`). However, two Must requirements remain unimplemented
on `HEAD` (`d33d123`): `FR-IMP-15` (determinate import progress fraction during
recording copy) and `FR-IMP-29` (rebuild count excludes `notRebuildableKinds`
and names the stage that produces non-rebuildable missing artifacts).

## Q1: What does "implement feature 2" cover?

A. Audit all 35 `FR-IMP` requirements against HEAD, then implement only the
   real gaps the audit confirms (`FR-IMP-15` determinate import progress,
   `FR-IMP-29` rebuild count and non-rebuildable reporting, and any other
   verified gap), plus reconcile the BRD status tables.
B. Build the full service-owned recording custody and catalog v6 now (ADR-0001
   Phase 3–4).
C. Re-implement the media pipeline and import controller end to end.
X. Other (describe)

[Answer]: A. Audit all 35 `FR-IMP` requirements against HEAD, then implement
only the real gaps the audit confirms (`FR-IMP-15` determinate import progress,
`FR-IMP-29` rebuild count and non-rebuildable reporting, and any other verified
gap), plus reconcile the BRD status tables.

## Q2: Where does recording custody land in this intent?

A. Keep the current client-owned v5 catalog and app-owned recording copy
   (`RecordingStore`), wiring byte-fraction progress into the existing streamed
   copy; defer the service-owned custody migration to ADR-0001 Phase 3–4.
B. Move recording custody and catalog writes into the Rust service as part of
   this intent.
X. Other (describe)

[Answer]: A. Keep the current client-owned v5 catalog and app-owned recording
copy (`RecordingStore`), wiring byte-fraction progress into the existing
streamed copy; defer the service-owned custody migration to ADR-0001 Phase 3–4.

## Q3: Test posture?

A. Implementation first per the project working agreement (`CLAUDE.md`); touch
   an existing test only when our change stops it compiling, and verify with
   `flutter analyze` and `tools/check-no-rust-in-app.sh`.
B. Add new unit and widget test suites for every `FR-IMP` requirement.
X. Other (describe)

[Answer]: A. Implementation first per the project working agreement (`CLAUDE.md`);
touch an existing test only when our change stops it compiling, and verify with
`flutter analyze` and `tools/check-no-rust-in-app.sh`.

## Q4: Gate autonomy for the stages in this intent?

A. Auto-approve gates (`aidlc/config.json` sets `mode: yolo` and the user asked
   to run the workflow).
B. Stop for manual approval at every stage.
X. Other (describe)

[Answer]: A. Auto-approve gates (`aidlc/config.json` sets `mode: yolo` and the
user asked to run the workflow).

## Contradiction analysis

- Q1-A versus Q2-A: consistent. Auditing and closing `FR-IMP-15` and `FR-IMP-29`
  stays within the current client-owned v5 catalog and `RecordingStore` copy
  while the ADR-0001 Phase 3–4 custody migration remains deferred.
- Q1-A versus Q3-A: consistent. `CLAUDE.md` explicitly overrides default test
  scaffolding ("Do not write new test files or add test cases unless the user
  explicitly asks for tests"). Existing tests are touched only if signature or
  widget changes break compilation.
- Q1-A versus Q4-A: consistent. Auto-approval governs gate transitions, not the
  substance of the artifacts or code changes.
- No open contradictions.
