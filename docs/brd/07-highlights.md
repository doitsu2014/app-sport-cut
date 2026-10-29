# Sportcut — Highlights Business Requirements Document

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-007 |
| Version | 1.0 |
| Status | Draft — for approval |
| Date | 2026-10-29 |
| Product | Sportcut — offline macOS badminton match analyzer |
| Owner | Product owner |
| Contributors | Product, Design, Engineering, QA |
| Feature area | HLT (Highlights) |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.0 |
| Product BRD | [00-product-context.md](00-product-context.md) |

This document refines the product BRD for the Highlights feature. Shared
business requirements, design-system requirements, non-functional requirements,
risks, and open questions are defined in
[00-product-context.md](00-product-context.md) and are cited by ID, not
restated. Requirement IDs in this document use the `FR-HLT-nn` form; feature-local
risks and questions use `R-HLT-n` and `Q-HLT-n` so they cannot collide with the
shared `R-n` and `Q-n` sets.

## 1. Purpose, users, and relationship to the product BRD

Highlights turns the rallies a match already holds into an ordered reel. The
engine ranks rallies by how likely they are to be worth watching; the user
decides what the reel contains and in what order. The feature is the last
decision before export: an empty reel blocks export ([BR-5](00-product-context.md)),
and the reel's order is what the renderer concatenates.

Users are the personas in the product BRD §4.1: a club coach building a review
reel, a competitive player reviewing their own points, and a parent producing a
shareable clip. Their shared need is a short list of the best rallies that they
can adjust without editing video by hand.

The product BRD fixes the autonomy level: the engine proposes an order, the user
keeps, removes, trims, and reorders ([BR-3](00-product-context.md)). This
document states the bar for that proposal and for the user's edits. It adopts
[BR-5](00-product-context.md) (highlights are useful and editable),
[BR-8](00-product-context.md) and [BR-9](00-product-context.md) (design and
accessibility fidelity), and [NFR-4](00-product-context.md) (user-authored data
survives upgrades).

## 2. Scope

### 2.1 In scope for v1

- A deterministic highlight score and 1-based rank per rally.
- A ranking recomputed from current rallies and score, never read from a stale
  stored score.
- Keeping a rally into the reel and removing it again while the rally remains.
- Trimming a clip inside its rally's boundaries without moving the rally.
- Reordering the reel and persisting the user's order.
- Keeping the best N left-out rallies in one action.
- A reel summary of clip count and runtime.
- The default, loading, empty, error, busy, and success states of the screen.

### 2.2 Out of scope for v1

Each item requires a change request.

- Audio-intensity ranking signals; the engine's motion input is the only
  automatic quality signal in v1.
- Reel templates, themes, transitions, captions, and favourites.
- Ranking evaluation against human-judged "best rally" labels; no labelled reel
  set exists at baseline.
- Multi-match reels, cross-match clip selection, or per-player reels.
- Automatic clip selection without a user decision.
- Highlight playback inside this feature; the studio's shared preview and the
  export screen own playback.

### 2.3 Delivery status at baseline

Status follows the product BRD §3.3 and is not rounded up.

| Area | Status | Evidence and gap |
| --- | --- | --- |
| Ranking engine (`sportcut-highlight`) | Partial | `core/crates/highlight/src/lib.rs` implements the weighted score, clamping, validation, and tie-break. Gap: the crate has no unit tests and no facade or client test calls `rank_highlights`. |
| Ranking recomputed on demand | Done | `app/lib/src/features/highlights/presentation/highlight_ranking_providers.dart` rebuilds the call from the loaded edit; `docs/data-storage-models.md` at baseline records that ranks are not persisted. |
| Ranking failure handling | Not started | `highlights_view.dart` reads `.value ?? {}`, so an engine error or an in-flight call renders the same unranked list with no label. |
| Keep and remove | Done | `app/lib/src/features/editing/data/editing_repository.dart` (`keepClip`); `app/test/highlights_screen_test.dart`. |
| Trim | Done | `EditingRepository.trimClip`; the trim dialog in `highlights_view.dart`; tests for apply and cancel. |
| Reorder | Done | `EditingStore.reorderClips`; `app/test/editing_repository_test.dart`, `app/test/highlights_screen_test.dart`. |
| Keep the best N | Partial | `_keepBest` keeps a literal 10 (`highlights_view.dart`); the label is `Keep top 10`. No test. |
| Clip row design | Partial | Rows show in/out timecodes, score context, duration, and actions, but no kept check, no surface ring, no lowered opacity for dismissed clips. |
| Orphan clip removal | Not started | A clip detached from a removed rally (`editing_repository_test.dart`, `removing a rally detaches its clip instead of taking it out`) makes `_rallyFor` throw `StateError` when the user removes it. |
| Feature tests | Partial | Six widget tests cover empty, keep, remove, trim apply, trim cancel, and reorder. No test covers ranking, keep-top-N, busy state, or errors. |

## 3. Functional requirements

### 3.1 Ranking

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-HLT-01 | Score each rally as `0.40·duration + 0.30·motion + 0.30·score context`, clamped to `0..1`. | Must | A 30 s rally with motion `1.0` and context `1.0` scores `1.0`; a 15 s unscored hand-marked rally scores `0.35`. |
| FR-HLT-02 | Derive the duration component as rally seconds ÷ 30, capped at 1. | Must | A 30 s or 60 s rally contributes `1.0`; a 15 s rally contributes `0.5`; a zero-length rally is rejected rather than scored. |
| FR-HLT-03 | Use the accepted suggestion's motion quality for motion, and a neutral `0.5` for a hand-marked rally. | Must | Of two otherwise identical rallies, the one accepted from a suggestion with quality `1.0` ranks above the hand-marked one. |
| FR-HLT-04 | Derive score context from the confirmed score at the rally as `1 / (1 + abs(left − right))`, and `0` when the rally has no confirmed winner. | Must | A confirmed rally at `18–16` contributes `0.333`; an unscored rally contributes `0`. |
| FR-HLT-05 | Reject a rally list with an empty id, a non-positive span, or a motion or context outside `0..1`, naming what is wrong. | Must | The engine returns an invalid-input error and no rank is produced for any rally in the call. |
| FR-HLT-06 | Rank deterministically and break ties by the earlier rally start. | Must | The same inputs in a shuffled order produce identical scores and ranks; equal scores rank the earlier start first. |
| FR-HLT-07 | Recompute the ranking from the current rallies and score on every session load. | Must | Changing a winner and reopening the match changes the order without writing a score to `rallies.highlight_score` or `highlight_clips.rank`. |
| FR-HLT-08 | Show the suggested rank on each left-out rally. | Should | A ranked left-out rally shows `#n`; its tooltip states the score as a whole percentage. An unranked rally shows no number. |
| FR-HLT-09 | Label the reel when ranking is unavailable instead of silently listing rallies unranked. | Must | An engine error or an in-flight ranking shows a labelled state; the left-out list is not presented as if the order were the suggested one. |

### 3.2 Reel assembly

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-HLT-10 | Keep a rally into the reel at the rally's boundaries, appended last. | Must | Clip count rises by one, the new clip is last, and its start and end equal the rally's. |
| FR-HLT-11 | Treat keeping a rally that is already kept as a no-op. | Must | A second keep of the same rally leaves the clip count and order unchanged. |
| FR-HLT-12 | Remove a clip from the reel without deleting the rally or changing the score. | Must | Clip count falls by one; the rally count and both scores are unchanged; the rally appears under "Left out". |
| FR-HLT-13 | Keep a removed rally selectable until export, so a removal is reversible in the same session. | Must | After remove and re-keep, the rally is a clip again and the reel count returns to its previous value. |
| FR-HLT-14 | Trim a clip only inward, within its rally's in and out points. | Must | A requested start before the rally start clamps to the rally start; a requested end past the rally end clamps to it; the rally's own boundaries do not change. |
| FR-HLT-15 | Reject a trim whose end is not after its start. | Must | The dialog cannot produce it; a direct call is refused and nothing is written. |
| FR-HLT-16 | Leave the clip untouched when the trim dialog is cancelled. | Must | After Cancel, no trim is stored and the clip's effective start and end equal the rally's. |
| FR-HLT-17 | Mark a trimmed clip and use its effective boundaries in duration and export. | Must | The row shows `(trimmed)` and the effective duration; the export request carries the trimmed start and end. |
| FR-HLT-18 | Persist the reel order the user sets and restore it on reopen. | Must | After a drag reorder, a reopened session lists clips in the new order. |
| FR-HLT-19 | Keep the N best-ranked left-out rallies in one action, where N is a stated value rather than a literal. | Should | One activation adds `min(N, left-out count)` rallies in rank order; the control's label states N. |
| FR-HLT-20 | Summarize the reel as clip count and runtime. | Must | The summary reads `N clips · m:ss` and the runtime equals the sum of effective clip durations. |
| FR-HLT-21 | Allow a clip detached from a removed rally to be removed from the reel. | Must | Removing an orphan clip removes it without an error and without affecting any rally. |

### 3.3 Screen behaviour and states

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-HLT-22 | Show one factual empty-state sentence when the reel has no clips, and keep the left-out list usable. | Must | An empty reel shows one sentence naming the next action and the left-out list is still operable. |
| FR-HLT-23 | Show a loading state while the match's edit loads. | Must | A loading session shows a progress indicator; a failed load shows its message instead of a spinner that never ends. |
| FR-HLT-24 | Disable trim, remove, keep, and keep-best while a write is in flight. | Must | During a write, the controls are disabled and a second activation does not queue a duplicate write. |
| FR-HLT-25 | Report a failed reel action as a dismissible banner naming what happened. | Must | A rejected keep, trim, remove, or reorder shows a banner with a Dismiss action and leaves the reel unchanged. |
| FR-HLT-26 | Use singular and plural correctly in summaries and counts. | Must | One clip reads `1 clip`, not `1 clips`. |

## 4. State coverage

| State | Expected behaviour | Requirement |
| --- | --- | --- |
| Default | Reel list in the user's order; left-out strip sorted by suggested rank; reel summary visible. | FR-HLT-08, FR-HLT-18, FR-HLT-20 |
| Loading | Progress indicator until the edit loads; ranking may load after the reel and must not block it. | FR-HLT-23, FR-HLT-09 |
| Empty | One sentence plus the left-out list; no placeholder clips. | FR-HLT-22 |
| Error | Banner for a failed action; message for a failed load; labelled state when ranking fails. | FR-HLT-25, FR-HLT-23, FR-HLT-09 |
| Success | New clip appended, count updated, rally moves from "Left out" to the reel. | FR-HLT-10, FR-HLT-20 |
| Disabled | Trim, remove, keep, and keep-best disabled during a write; disabled controls keep their label. | FR-HLT-24 |
| Cancellation | Cancelling the trim dialog writes nothing and closes the dialog. | FR-HLT-16 |
| Recoverable | A removed clip's rally stays selectable until export. | FR-HLT-13 |

## 5. Design-contract specifics

The design system is a contract ([DS-1](00-product-context.md) through
[DS-15](00-product-context.md)). Values come from
[tokens.css](../../design-system/tokens.css); behaviour comes from
[DESIGN.md](../../design-system/DESIGN.md).

| Requirement | Design source | Acceptance criterion |
| --- | --- | --- |
| Clip rows follow the clip-row composition: in/out timecodes, duration, score context, keep and dismiss actions, a kept check plus surface ring, and lowered opacity for a dismissed clip while it stays recoverable. | DESIGN.md §6 Clip row | A kept clip shows a check and a `--surface` ring with a `--border` hairline; a left-out rally is visibly dimmed and remains selectable. |
| Reel entries are rows at the list-row height and use the 4 px grid for padding. | DESIGN.md §4, §6 | Row padding is drawn from `--space-*` values on the 4 px grid; a rich row is 64 px. |
| Timecodes and durations use tabular numerals in IBM Plex Mono; score figures in Archivo are never animated. | DESIGN.md §3, §7; tokens `--text-xs` 12px, `--text-base` 16px | Every timecode and duration sets `FontFeature.tabularFigures()`; no clip number or duration animates. |
| One accent per pane: the reel's selected/kept state and the primary action share the single `--accent` role; no second green appears in the pane. | DESIGN.md §2, [DS-3](00-product-context.md) | Light `#0E6E45`, dark `#46D08D`; an audit finds at most one accent-coloured element per pane. |
| Icon-only controls carry a tooltip and an accessible name; a destructive action is never icon-only. | DESIGN.md §6 Actions | Trim and remove expose a tooltip; the remove control names its object in the tooltip. |
| The trim dialog is 420–520 px wide, left-aligned, with right-aligned Cancel and one confirming action; cancelling names no change. | DESIGN.md §5, §6 Dialog | The dialog uses one of the two stated widths and exactly two actions, Cancel and Trim. |
| Motion explains change: list reorder settles within `--motion-base` 180 ms with `cubic-bezier(0.2,0,0,1)`; nothing loops; reduced motion collapses non-essential transitions. | DESIGN.md §7; tokens `--motion-fast` 120ms, `--motion-base` 180ms | A reorder or dialog transition completes in 180 ms or less; under `prefers-reduced-motion` the reel still reorders and the dialog still opens. |
| Copy is short, factual, and verb-first, with numbers formatted as `0:10–0:20` and `12 clips · 4:38`. | DESIGN.md §8, [DS-10](00-product-context.md) | No exclamation mark, no anthropomorphic error, and no raw float duration is shown. |
| Every state carries a word or icon; colour never carries meaning alone. | DESIGN.md §1, §2, [DS-4](00-product-context.md) | Kept and left-out states are distinguishable in grayscale. |

Known drift at baseline, recorded rather than waived:

- The clip row is a Material `ListTile` with a drag handle and two icon buttons; no kept check, no surface ring, no dimmed left-out state (DESIGN.md §6).
- The summary renders `1 clips · 0:10`; the design format is `N clips · m:ss` with correct number agreement (DESIGN.md §8).
- The trim dialog is not pinned to the 520 px settings width or its elevation (DESIGN.md §4, §5).
- No reduced-motion audit is recorded for this feature.

## 6. Feature non-functional requirements

Shared requirements are cited, not restated. The rows below add feature-local
constraints.

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| NFR-HLT-1 | Ranking is a pure call: no file reads and no catalog access. | Must | `rank_highlights` accepts only a rally DTO list and returns ranks; removing the match directory does not change the result. |
| NFR-HLT-2 | Ranking returns the same scores and ranks for the same inputs on any machine. | Must | Two runs with shuffled input order produce byte-identical rank assignments. |
| NFR-HLT-3 | Ranking never blocks the reel: the user can scroll, trim, and reorder while it loads. | Must | The reel remains interactive before the ranking future completes. |
| NFR-HLT-4 | Clip selection, trim, and order are user-authored data and survive reanalysis and upgrade. | Must | Reopening the catalog after a reload restores clips, trims, and order; this is [NFR-4](00-product-context.md). |
| NFR-HLT-5 | Every Must functional requirement here has an automated test. | Must | The traceability table names a test per Must row; at baseline ranking, keep-best, busy, and orphan-clip rows have none. |
| NFR-HLT-6 | The feature makes no network call and reads no remote resource. | Must | The path completes with the network unavailable, per [BR-1](00-product-context.md) and [NFR-1](00-product-context.md). |
| NFR-HLT-7 | Errors are user-actionable and name the object and the next step; no telemetry is emitted. | Must | Every failure message names the rally or clip, or states the next action, per [NFR-13](00-product-context.md) and [DS-10](00-product-context.md). |

## 7. Acceptance and verification evidence

### 7.1 Evidence available at baseline

| Requirement group | Evidence | Status |
| --- | --- | --- |
| Keep a rally | `app/test/highlights_screen_test.dart`, `keeping a rally puts a clip in the reel` | Passes |
| Remove a clip, keep the rally | `highlights_screen_test.dart`, `removing a clip takes it out of the reel and leaves the rally`; `editing_repository_test.dart`, `taking a rally out of the reel leaves its score alone` | Passes |
| Trim applies and does not move the rally | `highlights_screen_test.dart`, `trimming a clip moves its boundaries and not the rally` | Passes |
| Trim cancel writes nothing | `highlights_screen_test.dart`, `cancelling a trim leaves the clip as it was` | Passes |
| Reorder persists | `highlights_screen_test.dart`, `dragging a clip rewrites the reel order`; `editing_repository_test.dart`, `the reel keeps the order the user set` | Passes |
| Empty reel | `highlights_screen_test.dart`, `a match with no clips shows the empty reel and what is left out` | Passes |
| Clip detaches from a removed rally | `editing_repository_test.dart`, `removing a rally detaches its clip instead of taking it out` | Passes |
| Ranking formula | `core/crates/highlight/src/lib.rs` source; baseline `docs/architecture.md` §Analysis pipeline, step 7 | No test |
| Ranking determinism and tie-break | Source only (`rank`, `total_cmp`, then `start_ms`) | No test |
| Keep the best N | Source only (`_keepBest`, literal 10) | No test |
| Ranking unavailable | None; the provider's value is read with `?? {}` | Gap |
| Orphan clip removal | None; `_rallyFor` throws `StateError` | Gap |
| Busy state | None | Gap |

### 7.2 Gaps in evidence

- `core/crates/highlight/` has no test module or `dev-dependencies`, and no facade test invokes `rank_highlights`; the formula is verified only by reading the source.
- No recorded evaluation compares the suggested order with human-judged best rallies. The accuracy harness scores player count and rally boundaries only, and its Results table is empty at baseline.
- The widget tests never override `sportcutEngineProvider`, so ranking fails inside them and is swallowed; they prove the reel works with no ranking, not that ranking works.

## 8. Dependencies, constraints, risks, and open questions

### 8.1 Assumptions

- Motion quality is available on accepted suggestions as `rally.confidence`;
  hand-marked rallies have none.
- The score at a clip's position is derived from confirmed winners, never
  hand-entered.
- Users accept that the suggested order is advice, not a decision.

### 8.2 Constraints

- The engine never reads the application catalog; the caller supplies rallies
  and signals.
- The ranking is not persisted; `rallies.highlight_score` and
  `highlight_clips.rank` exist in the schema but are not written.
- A clip belongs to one rally or is detached; a detached clip has no rally to
  restore boundaries from.
- The client owns clip selection, trim, and order; the engine owns only the
  score and rank.

### 8.3 Dependencies

| Dependency | What the feature needs | Owner |
| --- | --- | --- |
| `sportcut-highlight` | Weighted score, validation, deterministic tie-break | Engineering lead |
| `sportcut-api` facade | `rank_highlights` DTO call, no file access | Engineering lead |
| `EditingRepository` / `EditingStore` | Clip persistence, trim, order, foreign keys | Engineering lead |
| `ScoreTimeline` | Score at a rally and the confirmed gap | Engineering lead |
| Design system v1.0 | Clip-row composition, states, voice, motion | Design lead |

### 8.4 Risks

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-HLT-1 | Weights are hand-chosen and unvalidated; the suggested order may not match what users keep. The source comment states they are to be re-tuned once ranked footage exists. | Medium | Medium | Collect kept-versus-suggested data before tuning; state the weights as provisional, not proven. | Product owner |
| R-HLT-2 | Ranking has no automated test; a regression in the formula or tie-break is invisible. | High | Medium | Add engine unit tests for weights, clamping, validation, determinism, and ties; add a facade test. | QA lead |
| R-HLT-3 | Silent ranking failure shows an unranked list that looks like a suggestion. | High | Medium | Label the unavailable state; assert it in a widget test. | Engineering lead |
| R-HLT-4 | Design drift in the clip row and summary weakens the stated contract. | Medium | Medium | Reconcile the row, the ring, the dimmed state, and the plural with DESIGN.md §6 and §8. | Design lead |
| R-HLT-5 | Removing a rally leaves an orphan clip that the reel cannot remove. | Medium | High | Handle a detached clip in the view; add the test. | Engineering lead |

Shared risks that bear on this feature: [R-6](00-product-context.md) design
drift, [R-7](00-product-context.md) client test gaps, [R-1](00-product-context.md)
unverified accuracy claims.

### 8.5 Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-HLT-1 | Is keeping the best N a fixed value or a user setting? | Decides whether FR-HLT-19 is one control or a settings row. | Product owner |
| Q-HLT-2 | Must a removed-then-restored clip keep its trim, or is restoring the untrimmed rally acceptable? | The current code recreates the clip at the rally's boundaries and loses the trim. | Product owner |
| Q-HLT-3 | Should the suggested score be visible as a number, or only as a rank? | Affects the chip label and the tooltip in DESIGN.md §6. | Design lead |
| Q-HLT-4 | Is an orphan clip (rally deleted) ever legitimate, or should deleting a rally delete its clip? | Currently the clip survives by design; the reel cannot remove it. | Product owner |

## 9. Traceability

| Business requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| [BR-5](00-product-context.md) Highlights are useful and editable | FR-HLT-01…FR-HLT-25 | DESIGN.md §5, §6, §8 | `core/crates/highlight/src/lib.rs`; `app/lib/src/features/highlights/`; `app/lib/src/features/editing/data/editing_repository.dart` | `app/test/highlights_screen_test.dart`; `app/test/editing_repository_test.dart` |
| [BR-3](00-product-context.md) User-confirmed results | FR-HLT-10…FR-HLT-13, FR-HLT-19 | DESIGN.md §6 Clip row | `editing_repository.dart` (`keepClip`) | Same tests; ranking never selects a clip |
| [BR-8](00-product-context.md) Design fidelity | Section 5 rows; FR-HLT-26 | DESIGN.md §2, §3, §4, §6, §7, §8 | `highlights_view.dart` | Design audit — not recorded |
| [BR-9](00-product-context.md) Accessibility | Section 5 focus, contrast, and hit-target rows | DESIGN.md §2, §4; USAGE.md checklist | `highlights_view.dart` | Accessibility checklist — not recorded |
| [NFR-4](00-product-context.md) Data integrity | FR-HLT-17, FR-HLT-18, NFR-HLT-4 | — | `editing_store.dart` (`highlight_clips`, `order_index`) | `editing_repository_test.dart`, order and settings tests |

Code index: `highlights_view.dart`, `highlight_ranking_providers.dart`,
`highlights_screen.dart`, `highlight_clip.dart`, `match_edit.dart`,
`editing_repository.dart`, `core/crates/highlight/src/lib.rs`, and
`facade.rs` (`rank_highlights`). Prior evidence at baseline:
`docs/verification/manual-editing-and-export.md`,
`docs/verification/accuracy-evaluation.md`, `docs/architecture.md` (step 7),
`docs/data-storage-models.md` (`highlight_clips`; ranks not persisted).

## 10. Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |

**Change control.** A change to scope, a Must requirement, or the design
contract requires a version bump and a recorded approval. A new dependency
updates the register before the implementing change is complete. This document
inherits the version and baseline of
[00-product-context.md](00-product-context.md).
