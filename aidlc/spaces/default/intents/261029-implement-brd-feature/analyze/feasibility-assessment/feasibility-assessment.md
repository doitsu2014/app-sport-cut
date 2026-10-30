# Feasibility Assessment — Workspace and Library gaps

Status: Analyze / Feasibility Assessment
Intent: `261029-implement-brd-feature`
Consumes: `../intent-capture/intent-statement.md`, `../requirements-analysis/requirements.md`

## 1. Technical feasibility by gap

| Gap | Requirement | Assessment | Spikes needed |
| --- | --- | --- | --- |
| G1 | FR-LIB-20 / FR-SHL-14 | **High.** `StudioStatusBar` already receives `facts` and the shell already knows `selectedStage`; the bar needs one more input and a label. No new provider, no protocol change. | None |
| G2 | FR-LIB-05 | **High.** `WorkspaceScreen._body`'s loading branch swaps `ScEmptyState` for a progress indicator. `ScProgressJob` already exists; a compact `CircularProgressIndicator` or `ScEmptyState` variant is the only design decision. | None |
| G3 | FR-LIB-06 | **High.** `AsyncValue.error` already carries the error object; the branch passes it into the message. Watch for leaking raw exception text into user copy — use the message, not the stack. | None |
| G4 | FR-LIB-24 | **High.** `_confirmDeleteMatch` runs before `_refresh`; capture the deleted match's index in the current entry list before the write and select that index (clamped to the previous entry) after. `_ensureSelection` then only handles the empty case. | None |

All four gaps are presentation or state-selection changes inside
`app/lib/src/features/workspace/`. None touches the bridge, the protocol, the
database schema, or the Rust engine.

## 2. Effort

| Gap | Ballpark | Notes |
| --- | --- | --- |
| G1 | 0.5 day | One parameter, one text span, one set of tests skipped per policy. |
| G2 | 0.25 day | One branch, one widget. |
| G3 | 0.25 day | One string, one guard against raw exception leakage. |
| G4 | 0.5 day | Index capture around an async delete; careful with mounted checks. |

Total: roughly 1.5 developer-days, with no dependency, asset, or licensing work.

## 3. Risk

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Flutter toolchain absent, so `flutter analyze` cannot run (BRD R-7). | Medium | Medium | Check `SPORTCUT_FLUTTER_BIN` / `flutter` first; report the gap rather than claiming a clean run. |
| A status-bar label crowds the 30 px bar at 200% text scale (FR-SHL-35). | Low | Medium | Keep the stage text short, reuse the shortened vocabulary already in `stage_strip.dart`. |
| G4's post-delete selection re-triggers playback load for a video the user did not pick. | Low | Low | Select only when the deleted video was selected; otherwise leave selection untouched. |
| Stale home tests reference the removed "No matches yet" screen. | High | Low | Out of scope under Q3-A; record the known failure rather than fixing it silently. |

## 4. Path

**Proceed.** All four gaps are small, local, and inside the existing design
system. No spike is required. The only external dependency is the Flutter
toolchain for verification.
