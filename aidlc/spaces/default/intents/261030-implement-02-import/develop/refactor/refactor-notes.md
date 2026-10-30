# Refactor Notes — Import and Media Preparation (Feature 2)

Status: Develop / Refactoring
Intent: `261030-implement-02-import`
Consumes: `../code-review/review-record.md`, `../code-generation/source-changes.md`
Commit: `34754d7` (8 files, +30/−12)

## 1. Justification

The code review confirmed 3 minor + 4 nit findings against commits
`e756052..4343663`. F1 is a genuine contract defect: the documented terminal
`onProgress(1.0)` was suppressed on every multi-chunk copy larger than
~12.8 MiB because the rounded percent reaches 100 at ratio ≈ 0.995 and the
post-flush emission was gated on `lastPercent < 100`. The remaining findings
are documentation/format accuracy. All are fixed now rather than later
because they are mechanical, in-scope, and cheap while the context is fresh;
none changes architecture.

## 2. Safety net

Per the project working agreement no tests were added or run. Safety net for
this stage: (a) each fix is behavior-identical except F1, whose new emission
sequence was re-derived by hand and re-read in source (in-loop steps ≤ 99%,
unconditional post-flush `1.0`, cap 1 + ≤99 + 1 = 101, cancel still exits
before the terminal call, degenerate `totalBytes <= 0` unchanged); (b)
`flutter analyze` re-run after the fixes: 4 issues, all the known
pre-existing baseline infos (fake's two shifted 146/152 → 148/154 because the
F2 doc comment added two lines above them), zero new; (c) full diffs reviewed
before committing.

## 3. What changed (finding → change)

| Finding | Change | Files |
| --- | --- | --- |
| F1 (minor) | In-loop gate now `percent > lastPercent && percent < 100`; post-flush `onProgress(1.0)` unconditional when a callback exists; explanatory comment added | `recording_store.dart` |
| F2 (nit) | Three `onProgress` dartdocs reworded to the real contract (0.0 before first chunk; updates as the copy advances; 1.0 once flushed; may stop early on cancel/failure; 1.0 ≠ match saved); fake documents that it intentionally ignores the callback | `recording_store.dart`, `match_library.dart`, `match_repository.dart`, `fake_match_library.dart` |
| F3 (nit) | `ImportState` constructor wrapped parameter-per-line (dart-format clean; no behavior change) | `import_controller.dart` |
| F4 (nit) | Row doc comment: size is trailing on the numbered row, path beneath | `artifact_rows.dart` |
| F5 (minor) | BRD-02 §9 BR-8/BR-11 verification cells carry the red-at-baseline caveat pointing at §7 | `docs/brd/02-import-and-media-preparation.md` |
| F6 (nit) | Revision rows in both BRDs: "status, evidence, and explanation cells only" | both BRDs |
| F7 (minor, deferred by gate decision) | Recorded as risk **R-IMP-7** in BRD-02 §8.3: pre-existing divergence between the client's state-derived missing set and the engine's file-absence `missingKinds` (a non-final artifact with an absent file shows PARTIAL and is excluded from the rebuild count though regeneration would rebuild it); follow-up is engine-track (`core/adapters/api` conversion maps absent-path entries to Missing) | `docs/brd/02-import-and-media-preparation.md` |

Aligned artifacts (review-mandated wording corrections, not behavior):
technical-spec §2.1 steps 3/5 and §3 performance budget; design-decisions
DD-1 refined (status: "Approved (refined by code review F1, 2026-10-30)").

## 4. What stayed the same

- No public signature changed; all edits are inside existing units U1–U5.
- Cleanup invariants (`on Object` → `remove(matchId)` → rethrow), cancel
  semantics, clamp/fallback behavior, getters, badge rendering, and all
  Must acceptance text in the BRDs are untouched.
- No new tests, no new dependencies, no engine (`core/`) changes.

## 5. Verification

| Command | Result |
| --- | --- |
| `cd app && flutter analyze` | 4 issues — all pre-existing baseline infos; zero in changed files |
| `tools/check-no-rust-in-app.sh` | not re-run (no dependency/build-file change in this commit; last green run at `62a57c3`, and this commit adds only Dart/doc edits) |
| Manual re-derivation of the F1 emission sequence | ≤ 101 invocations; terminal value exactly `1.0`; cancel path unchanged |

## 6. Follow-ups (explicit)

1. **R-IMP-7** (engine track): map absent-path manifest entries to Missing in
   `core/adapters/api` so client state, rebuild count, and row badge agree
   with the engine's file-absence truth.
2. Repair the baseline-red widget suites (`analysis_screen_test.dart`,
   `library_screen_test.dart`) in a separate intent — blocked on nothing here,
   out of scope by the working agreement.
3. Large-copy timing measurement + NFR-2 once-per-second cadence decision
   (BRD-02 §7 remaining gaps).
