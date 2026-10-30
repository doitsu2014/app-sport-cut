# Test Plan — Import and Media Preparation (Feature 2)

Status: Launch / Test Plan (revision 2 — folds the two-lens adversarial
verification findings)
Intent: `261030-implement-02-import`
Consumes: `../../analyze/requirements-analysis/requirements.md`,
`../../ideate/technical-spec/technical-spec.md`,
`../../develop/code-generation/source-changes.md`,
`../../develop/code-review/review-record.md`,
`../../develop/refactor/refactor-notes.md`
Release candidate: branch `261030-implement-02-import`, range
`d33d123..34754d7` — seven commits: `e756052` (U0), `4cb33db` (U1),
`c603d3c` (U2), `7ca126a` (U3), `62a57c3` (U4), `4343663` (U5), `34754d7`
(refactor).

## 0. Governing constraint

The working agreement distinguishes three things, and this plan keeps them
apart:

1. **Running the existing suites** — required here. This Launch workflow
   requires recorded evidence, which is exactly the working agreement's
   exception ("that workflow requires the suites, so run … `flutter test` in
   `app/` at that point"). §5 names the specific re-run.
2. **Recorded manual runs** — the MV path in §3; produces BRD-02 §7-grade
   evidence without touching test files.
3. **Writing new tests** — still requires an explicit user request. The §4
   catalog is therefore a plan, not a commitment; §5's alternative evidence
   path applies only if the user explicitly asks for tests.

BRD-02 §7's rule stands throughout: nothing is recorded as "Passed" without
a named test run or a recorded manual run.

## 1. Requirements → risk ranking (impact × likelihood)

| # | Risk area | Requirements | Review findings | Impact × Likelihood | Why |
| --- | --- | --- | --- | --- | --- |
| R1 | Custody invariants: original never modified; cancel/failure/throwing-callback leaves no directory, `.part`, or catalog record | FR-IMP-08/09/10/11/12, BR-1/BR-2 | — | High × Medium | U1 broadened cleanup to `on Object` and added counting inside the copy loop — the file-integrity core of the product |
| R2 | Progress contract: 0.0 first, percent-gated exact ratio, terminal exactly 1.0, ≤ 101 emissions, clamp vs stale probe size, degenerate `totalBytes <= 0`, no emission after cancel | FR-IMP-15, NFR-2, DD-1 | F1 (fixed), F2 (fixed) | Medium × High | F1 was a real defect here found in review; the arithmetic is subtle (rounded percent reaches 100 at ≈ 0.995) |
| R3 | Rebuild partition vs engine truth: count excludes `notRebuildableKinds`; guidance names the producing stage; unknown kinds fall back safely | FR-IMP-28/29, DS-10 | F7 (→ R-IMP-7) | Medium × Medium | Known pre-existing divergence: a NonFinal entry whose file is absent shows PARTIAL and is excluded from the count even though regeneration would rebuild it (R-IMP-7, engine-track follow-up) |
| R4 | Status vocabulary separation: artifact rows read READY/PARTIAL/MISSING; the studio keeps its BRD-09 vocabulary (READY, ANALYZING n%, the done check icon, BLOCKED — note `ScPipelineRow` renders done as an icon with semantic label, not the word DONE) | FR-IMP-30, DS-6, BRD-09 | F4 (fixed) | Medium × Low | U4 replaced a shared-component delegation with a local badge |
| R5 | Import state lifecycle: fraction null in idle/picking, no stale percent after success/cancel/failure, single-flight guard intact, **both surfaces** (workspace home and studio video rail) | FR-IMP-13/14/15 | — | Medium × Medium | U2 threads callbacks into Riverpod state from inside an awaited call; FR-IMP-15 requires both surfaces |
| R6 | Documentation honesty: BRD status/evidence matches code; no "Passed" without a run; deferred items preserved; doc comments match behavior | G4 | F3, F5, F6 (fixed) | Low × Medium | U5 + refactor touched two BRDs and several dartdocs |
| R7 | Service connection regression from the AF_UNIX fix | (bug fix) | — | High × Low | U0 removed a `setOption` call macOS rejected; every feature depends on the socket |

## 2. Strategy

**Levels and what runs now vs later:**

- **Static analysis (run, done):** `cd app && flutter analyze` — zero issues
  in changed files; 4 pre-existing baseline infos only. Touched lines are
  dart-format clean (F3).
- **Guard scripts (run, done):** `tools/check-no-rust-in-app.sh` — green.
  `tools/check-layering.sh` / `tools/verify-engine.sh` — not applicable
  (no `core/` change); mandatory if R-IMP-7's engine follow-up lands.
- **Multi-agent adversarial review (run, done):** 7 lenses / 24 agents over
  the code range; all confirmed findings fixed (F1–F6) or recorded
  (F7 → R-IMP-7). This plan itself was verified by a two-lens panel and
  revised (this document is revision 2).
- **Existing-suite re-run (REQUIRED, not yet executed):**
  `cd app && flutter test test/match_repository_test.dart` at the release
  candidate — the only automated regression net for the changed
  `recording_store.dart` / `match_repository.dart` (custody, cancellation,
  unreadable codec, unwritable copy, ENOSPC, catalog failure). The BRD's
  "Passing at the video-import baseline" predates the change and is stale
  evidence for FR-IMP-08/09/10/11; the re-run result and commit must be
  recorded and the BRD §7 row updated to the post-change run. The full
  `app/test` suite is red at baseline (`analysis_screen_test.dart`,
  `library_screen_test.dart` — unrelated UI drift), so the run is scoped to
  the affected file; that scoping is recorded with the result.
- **Manual validation runs (evidence path, not yet executed):** MV-1…MV-5
  below. "Recorded" means a transcript at `docs/verification/import-progress.md`
  (matching the existing `docs/verification/media-pipeline.md` pattern)
  containing: date, release-candidate commit, exact steps, and observed
  results per criterion.
- **Automated suite (cataloged, deliberately NOT written now):** §4. The
  alternative evidence path in §5 applies only on an explicit user request
  for tests.

**Deliberately not tested (with reason):** large-file timing benchmark
(deferred; R-IMP-1 open half); NFR-2 once-per-second cadence (open gap —
percentage stepping by approved DD-1); engine media/job suites (no `core/`
change and the working agreement — they *can* run on the same machine as the
MVs, which has `ffmpeg`, if an evidence request ever names them);
accessibility audit (BR-9 gap kept visible); pixel-golden visual tests (no
golden infrastructure in the client track).

## 3. Environments, fixtures, and manual validation runs

Environment: macOS dev machine; service via `tools/build-service.sh` +
`tools/run-service.sh`; `ffmpeg`/`ffprobe` present. **All media is synthetic,
ffmpeg-generated fixture footage** (e.g. `testsrc2` video + sine audio, ≥ 1 GB
for MV-1) — never user recordings, never committed footage (CLAUDE.md fixture
rule; stage rule "no production data in tests"). Useful roots: recordings
store `~/Documents/SportcutRecordings/<matchId>`, match directory
`~/Documents/SportcutMatches/<matchId>` (`MatchPaths.forDocuments()`).

| ID | Risk | Steps | Pass criterion |
| --- | --- | --- | --- |
| MV-1 | R1, R2, R7 | Start the dev service; launch the app; import the ≥ 1 GB generated fixture from the workspace home | App connects (AF_UNIX fix); bar is determinate 0%→100% with stage label; the fixture's mtime/size are unchanged after import; the match appears and is selected. (`sourceBytes` has no UI surface: verify optionally via the catalog DB, else record as unobserved.) |
| MV-2 | R2, R5 | During a second import, press Cancel mid-copy; tap Import again while a third import runs (single-flight); after the cancelled import, start and complete a fourth | Cancel is silent: no match row, `~/Documents/SportcutRecordings/<matchId>` gone (including `.part`); the concurrent second request is declined without opening a picker; the completed import shows 0%→100% with no stale percent at start or end |
| MV-3 | R5 (FR-IMP-15 both surfaces) | Import a fixture from the studio surface; switch inspector stages mid-import | `VideoRail` footer shows the same determinate progress with percentage; Import is disabled while running; progress survives stage switches |
| MV-4 | R3, R4 | **Preconditions:** a match whose preparation completed with no cancelled job (all manifest entries Final) **and** whose court was saved via Mark court (so a Final `calibration` entry exists — deletion alone cannot create one). Then delete the `proxy/` file and the `calibration/` file from the match directory and reopen the analysis panel; press Rebuild | Rows: proxy MISSING, calibration MISSING, others READY (word + icon + colour). Button reads "Rebuild 1 missing file" (proxy only). Note names court calibration → Mark court. Rebuild re-creates the proxy **and re-samples frames** (engine `regenerate_missing` re-records frames when proxy is missing and invalidates tracks/rally suggestions — expected, per FR-IMP-26); the count/button never counted calibration |
| MV-4b | R3, R4 (PARTIAL) | On a separate match, start preparation and cancel it mid-job; reopen the panel | Interrupted artifacts read PARTIAL (NonFinal). If a NonFinal entry's file is also absent it shows PARTIAL and is excluded from the rebuild count — the accepted R-IMP-7 divergence; record the observation |
| MV-5 | R4 | With a job running, open the studio pipeline panel/inspector; compare with the artifact rows | Pipeline surfaces keep the studio vocabulary: READY, ANALYZING n% while running, the done check icon (icon-only by design — the word DONE is not rendered by `ScPipelineRow`), BLOCKED where a stage is blocked; artifact rows simultaneously keep READY/PARTIAL/MISSING. Full `ScStatus` vocabulary assertions (including needsReview, which no studio mapping currently produces) belong to deferred catalog item 10, not to this manual run |

## 4. Automated test catalog (deferred until tests are explicitly requested)

Requirement-named, unhappy paths first; happy-path floor per component (team
memory). Would live in `app/test/`. Prerequisites: repair the baseline-red
widget suites first (stale `FilledButton`/label expectations), or run the new
files in isolation and record that the full suite remains red for unrelated
reasons.

1. `fr_imp_15_progress_is_percent_gated` — fixture with
   `expectedBytes == source.lengthSync()` and many 64 KiB chunks: emissions
   strictly increasing exact ratios < 1.0 in-loop, none ≥ 1.0 before flush,
   terminal exactly 1.0, ≤ 101 total. (A stale-size fixture cannot exercise
   the gate: the first chunk clamps to 1.0 — see the separate clamp test.)
2. `fr_imp_15_stale_expected_bytes_clamps` — `expectedBytes: 1024` for a
   4 MiB source: every emission clamped ≤ 1.0, sequence ends [0.0, 1.0].
3. `fr_imp_15_degenerate_total_reports_zero_then_one` — `expectedBytes: 0`
   with an empty source: exactly [0.0, 1.0].
4. `fr_imp_09_cancel_leaves_nothing_and_emits_no_terminal` — cancel
   mid-copy: directory removed, no 1.0 after the cancel point, silent UI.
5. `fr_imp_09_throwing_callback_still_cleans_up` — `onProgress` throws:
   `remove(matchId)` runs, original error propagates (`on Object` path).
6. `fr_imp_12_original_untouched` — import a fixture; assert source
   mtime/bytes unchanged and `MatchRecord.originalPath`/`sourceBytes` set.
7. `fr_imp_13_single_flight_and_no_stale_fraction` — second `start()`
   declined; after success/failure/cancel `ImportState.fraction == null`.
   Requires a cancel/onProgress-aware repository double: today's
   `FakeMatchLibrary` accepts and ignores both.
8. `fr_imp_29_partition_follows_not_rebuildable_kinds` — manifest with
   missing calibration + proxy: `rebuildableMissing == [proxy]`,
   `notRebuildableMissing == [calibration]`; label "Rebuild 1 missing file";
   note names Mark court.
9. `fr_imp_29_unknown_kind_falls_back_safely` — `notRebuildableKinds`
   contains a future kind: no crash, generic wording.
10. `fr_imp_30_badge_vocabulary` — widget test: final/nonFinal/missing rows
    render READY/PARTIAL/MISSING words with icons.
11. `fr_imp_30_studio_vocabulary_untouched` — component-level assertions:
    `ScPipelineRow` renders done as the check icon with semantic label,
    needsReview/blocked as uppercase words; plus a pump of
    `WorkspaceStudioScreen`/`VideoRail` with a non-null `importFraction`
    showing the determinate bar (the studio surface no MV-free path covers).

## 5. Exit criteria for Release Validation

**Met already:** analyze clean in changed files; guard script green; every
confirmed review finding fixed (F1–F6) or recorded (F7 → R-IMP-7); commits
scoped per unit; BRDs honest ("Implemented; not suite-verified").

**Required before the feature is called Done again (BRD-02 §7):**

1. `flutter test test/match_repository_test.dart` green at the release
   candidate; result + commit recorded; BRD-02 §7 "Client import path" row
   updated from the stale baseline citation to the post-change run.
2. MV-1, MV-2, MV-3, MV-4 (with MV-4b for PARTIAL) recorded in
   `docs/verification/import-progress.md` — this set covers both FR-IMP-15
   surfaces, the single-flight guard, and the READY/PARTIAL/MISSING
   vocabulary end to end.
3. A final document/format check that the F2–F6 wording fixes read correctly
   in the shipped files (dartdocs, row comment, BRD cells, revision rows).
4. **Or, only on explicit user request for tests:** the §4 catalog
   implemented and green (isolated-run caveat recorded), which substitutes
   for items 2–3's coverage but not for item 1.

**Known-acceptable gaps (go-with-known-issues candidates):** NFR-2 cadence;
large-copy timing (R-IMP-1); R-IMP-7 engine follow-up (MV-4b records its
user-visible effect); baseline-red widget suites; accessibility audit (BR-9);
`sourceBytes` not surfaced in the UI.

**Coverage floor:** not measured this intent (no new tests without an
explicit request; waiver recorded). Applies when §4 is implemented.
