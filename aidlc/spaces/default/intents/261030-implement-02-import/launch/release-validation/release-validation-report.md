# Release Validation Report — Import and Media Preparation (Feature 2)

Status: Launch / Release Validation — awaiting the human release gate
Intent: `261030-implement-02-import`
Release candidate: branch `261030-implement-02-import`, `d33d123..eae0082`
(eight commits; feature range `d33d123..34754d7` plus the evidence commit
`eae0082`).
Consumes: `../../analyze/requirements-analysis/requirements.md`,
`../deployment/deployment-runbook.md`, `../test-plan/test-plan.md`.
Note: the framework's `test-suite` input is absent by the gate decision at
Test Generation (working agreement); the test plan's evidence path replaces
it.

## 1. Verification re-run at the release candidate (executed 2026-10-30)

| Check | Command | Result |
| --- | --- | --- |
| Client static analysis | `cd app && flutter analyze` | **4 issues, all pre-existing baseline infos** (`prefer_const_constructors` in two test files); zero in any file changed by this intent |
| No-Rust guard | `tools/check-no-rust-in-app.sh` | **OK** — no Rust, FFI, or generated bindings in the client |
| Custody regression suite (post-change) | `cd app && flutter test test/match_repository_test.dart` | **12/12 passed** — custody, original-untouched semantics, missing file, unreadable codec, denied access, cancelled import leaves neither match nor partial copy, unwritable copy leaves nothing, ENOSPC classification, artifact generation, deletion semantics |
| Engine verification | `tools/verify-engine.sh` | Not run — no `core/` change in this intent (working agreement); mandatory for the R-IMP-7 follow-up |
| Layering | `tools/check-layering.sh` | Not applicable — no manifest or crate-surface change |
| Full `flutter test` | — | Not run: `analysis_screen_test.dart` (4 cases) and `library_screen_test.dart` are red at baseline `d33d123` for unrelated UI drift; scoped run recorded instead (test plan §2) |

Media tools (`ffmpeg`/`ffprobe`) are **not installed on this machine**
(`which` returns nothing); the custody suite needs only `FakeMediaEngine` and
byte fixtures, so it ran without them. This does **not** block the manual MV
runs' definition but does mean MV-1…MV-5 must be executed on a machine with
the media toolchain and a GUI (deployment runbook §1).

## 2. Requirement coverage at the candidate

| Group | Status | Evidence |
| --- | --- | --- |
| FR-IMP-01 – FR-IMP-14, FR-IMP-16 – FR-IMP-28, FR-IMP-31 – FR-IMP-35 | Satisfied at `d33d123`, unchanged by this intent | Requirements audit §2; engine suites (prior runs, baseline `1541c64`); post-change custody suite 12/12 |
| **FR-IMP-15 (G1)** — determinate import progress, both surfaces | **Implemented; automated contract unverified, manual evidence pending** | U1/U2 commits; post-change suite covers custody/cancel but not the fraction sequence; `flutter analyze` clean; adversarial review F1 fixed. BRD-02 §7 row remains "Implemented; not suite-verified" |
| **FR-IMP-29 (G2)** — rebuildable-only count + stage guidance | **Implemented; automated contract unverified, manual evidence pending** | U3 commit; review verified the getter/button/note logic; `flutter analyze` clean |
| **FR-IMP-30 (G3)** — READY / PARTIAL / MISSING rows | **Implemented; automated contract unverified, manual evidence pending** | U4 commit; review verified badge mapping and layout parity; `flutter analyze` clean |
| **G4** — BRD reconciliation | **Done** | `4343663` + `eae0082`; Must acceptance text verifiably untouched |
| NFR-7 (tests ship with behavior) | **Waived for this intent** by the working agreement; recorded in BRD §7 | — |

Per BRD-02 §7's own acceptance rule, the feature may not be called **Done**
again until (a) the G1–G3 rows gain a named automated test or a recorded
manual run, and (b) the remaining "Not verified" claims are closed. The
post-change suite run closes the FR-IMP-08/09/10/11 evidence question; it
does not close the progress-partition-badge contracts, which the MV runs
(MV-1…MV-5, test plan §3) cover.

## 3. Operational readiness

- **Rollback**: trivial — local bundles only; this intent changes no schema,
  no service state, no recording-store or match-directory layout, so
  pre-change and post-change bundles read the same state (runbook §3).
- **Alerts/on-call**: none apply — the product is offline with no telemetry
  by guardrail; no server exists. "What to watch in the first hour" reduces
  to the smoke checklist below.
- **Smoke checklist for the first hour on a media-capable machine**:
  MV-1 (large synthetic fixture import, determinate bar, original untouched)
  → MV-2 (cancel + single-flight + clean re-import) → MV-3 (studio surface)
  → MV-4/MV-4b (rebuild count, guidance note, PARTIAL) → MV-5 (studio
  vocabulary). Record transcripts at `docs/verification/import-progress.md`.

## 4. Release decision (recommendation — the human decides)

**Go with known issues** for merging the branch, with one condition before
the feature is *labelled* Done again: the MV runs must be recorded from a
media-capable machine. Rationale: all four gaps are implemented, reviewed
(24 agents + adversarial verification), refactored after review, and the
risk-bearing custody path is green post-change under the project's own
suite; the remaining unknowns are manual-observation contracts (progress
sequence, partition note, badges), the deferred service-custody migration,
and the timing/cadence gaps — none is a correctness regression.

Known issues (accepted, named, owned):

1. **NFR-2 cadence** — percentage stepping does not guarantee one update per
   second (approved DD-1 trade-off). Owner: Engineering lead; revisit with
   the timing benchmark.
2. **Large-copy timing** — R-IMP-1's measurement half remains open.
3. **R-IMP-7** — client state-derived vs engine file-absence missing sets
   (pre-existing; NonFinal+absent shows PARTIAL and is excluded from the
   count). Engine-track follow-up.
4. **Baseline-red widget suites** — `analysis_screen_test.dart`,
   `library_screen_test.dart` (unrelated UI drift). Separate repair intent.
5. **Accessibility audit (BR-9)** — still not recorded.
6. **`sourceBytes` has no UI surface** — verified only via the catalog.
7. **CI absent** — bootstrapping CI is a separate infra follow-up.
8. **`ffmpeg` absent on the validation machine** — MV runs blocked here,
   not by the code.
