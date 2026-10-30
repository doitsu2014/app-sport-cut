# Implementation Plan — Import and Media Preparation (Feature 2)

Status: Develop / Task Planning
Intent: `261030-implement-02-import`
Consumes: `../../ideate/technical-spec/technical-spec.md`,
`../../analyze/requirements-analysis/requirements.md`, `unit-breakdown.md`

## 1. Approach

All work is client-track (`app/`) plus documentation (`docs/brd/`); no Rust,
protocol, or dependency changes. The technical spec (§2.1–§2.8) is the
buildable contract; units U0–U5 in `unit-breakdown.md` are the delivery
slices. Risk is front-loaded: U1 (the copy-loop change with cancel/cleanup
semantics) is the biggest unknown and goes first after the U0 hygiene commit;
U1+U2 form the walking skeleton (pick → percent-stepped copy → visible
determinate bar end to end).

Execution model for Code Generation (user opted into multi-agent):

- **Lane A** (sequential): U1 → U2 — one agent per unit, U2 starts only after
  U1 lands (interface dependency).
- **Lane B**: U3 — independent agent, parallel with Lane A.
- **Lane C**: U4 — independent agent, parallel with Lanes A/B.
- **Then**: U5 — single agent after all code units pass verification.
- Lanes touch disjoint files (verified in the unit breakdown), so parallel
  agents do not conflict and no worktree isolation is needed.

Work happens on a short-lived branch `261030-implement-02-import` off `main`
(trunk-based, per team memory); U0 is its own commit, each unit commits
separately with its unit id and requirement ids in the message.

## 2. Conventions

- Riverpod `Notifier` + immutable state classes; construct `ImportState`
  directly (no `copyWith` exists); `AnalysisState` gains getters only.
- Design-system tokens only (`SportcutPalette`, `SportcutTypography`,
  `SportcutTokens`, `ScIcons`, `ScMetrics`); shared `ScStatus`/`ScPipelineRow`/
  `ScProgressJob`/`StudioShell`/`VideoRail` are **not** modified.
- Feature code stays inside `app/lib/src/features/<feature>/`; no sockets or
  protocol methods outside `app/lib/src/bridge/`.
- Optional named parameters for every signature change (source compatibility).
- No new tests (working agreement); existing tests must keep compiling; the
  only test-file edit is `FakeMatchLibrary.importVideo` (interface conformance).
- No `unsafe`, no network, no telemetry, no new durable client state, no new
  dependencies (licensing register untouched).

## 3. Commands

| Purpose | Command |
| --- | --- |
| Client static analysis | `cd app && flutter analyze` (set `SPORTCUT_FLUTTER_BIN` if `flutter` is not on PATH) |
| No-Rust-in-app guard | `tools/check-no-rust-in-app.sh` |
| Engine (untouched, sanity only if any `core/` file changes) | `tools/verify-engine.sh`, `tools/check-layering.sh` |
| Dev run for manual check (optional) | `tools/run-macos.sh` |

Test suites are **not** run as part of ordinary work (working agreement).
Known baseline: `analysis_screen_test.dart` and `library_screen_test.dart`
already fail at HEAD for unrelated UI-drift reasons (spec §3); they are
compile-compatibility checks only, not green evidence.

## 4. Review strategy

- **Per unit**: the implementing agent self-verifies with `flutter analyze`
  (+ guard script) before the unit is declared done.
- **Code Review stage** (after U1–U5): multi-agent adversarial review — one
  reviewer per unit diff against its spec section and acceptance criteria,
  plus one cross-cutting reviewer (BR-1/BR-2 invariants, cleanup-on-`Object`,
  DD-1 cap, design-token usage, guardrails). Findings are verified before
  fixing; fixes land in the Refactoring stage.
- **Human gates**: every stage ends at the approval gate (user chose
  stop-at-each-gate for this run).

## 5. Deviations and follow-ups (tracked explicitly)

- NFR-2 once-per-second cadence is **not** delivered (percentage stepping per
  approved DD-1); recorded as an open gap in U5's BRD wording.
- Large-file timing benchmark stays deferred (BRD 02 §7).
- Baseline-red widget tests are out of scope; flagged in U5 §7 wording as a
  follow-up.
- Service custody migration (ADR-0001 Phase 3–4) remains deferred; nothing
  here adds durable client state.
