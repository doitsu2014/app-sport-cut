# Sportcut — Score and Serving (Feature BRD 06)

## 1. Document control

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-006 |
| Version | 1.1 |
| Status | Draft — for approval |
| Date | 2026-11-02 |
| Owner | Product owner, Score and Serving area |
| Contributors | Product, Design, Engineering, QA |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.1; shared review surface per BRD 09 v1.2 |
| Parent BRD | [00-product-context.md](00-product-context.md) |
| Area ID | SCR |

This document refines the shared contract in
[00-product-context.md](00-product-context.md). It cites BO, BR, DS, NFR, R, Q,
and M identifiers defined there and never redefines them. Identifiers prefixed
`FR-SCR`, `NFR-SCR`, `SCR-R`, and `Q-SCR` are scoped to this feature.

**Evidence note.** Architecture, storage, roadmap, and verification documents
are cited by path at baseline `1541c64`; they are not part of the working tree,
and this suite is the current requirements source (§1 of the parent BRD). Code,
tests, and the design system in the tree are the stronger signal where a
document and the code disagree.

## 2. Purpose, users, and relationship to the product BRD

Score and serving turns a list of rallies into a running score. The user says
who won a rally with one tap; the score, the score timeline, and the serving side
are derived from that answer. Nothing is hand-entered, and nothing is inferred
from the video.

Users: the club coach and the competitive player (00 §4.1), scoring a
recreational match at roughly one tap per rally, then correcting a mistake
without rebuilding the timeline by hand.

Relationship to the product BRD: this feature is BR-4 (one-tap scoring) and the
scoring half of BR-3. It consumes accepted and manually marked rallies from Rally
Review (05), and it supplies the score context that Highlight Ranking (07) and
Export (08) read. BO-2 sets the bar: one winner tap per rally, and every
displayed score derived rather than entered.

Scoring happens on the shared review surface defined by BRD 09 (FR-SHL-46 to
FR-SHL-48). This feature supplies the scoreboard and serving content of the
Rally tab and the Review & score lens's score-bug overlay and score-chip
timeline emphasis. Rally content in the same tab — suggestions, review
decisions, manual marking, the rally list, and boundaries — belongs to 05. This
feature defines no separate review layout, preview, transport, timeline, or
route.

Autonomy level, stated once: the engine proposes a serving side; the user
confirms every winner. The product never officiates, never calls a fault, and
never decides a point.

## 3. Scope

### 3.1 In scope

- An L/R scoreboard with tabular figures that follows the confirmed rallies.
- One-tap winner confirmation per rally, and correction of a confirmed winner.
- The score timeline derived from confirmed winners, including the score as it
  stood at any clip's position.
- Serving side derived from the previous rally's confirmed winner, with explicit
  "no server" cases.
- An explicit serving marker that does not change the winner.
- Persistence of rally winners and the derived score events.
- Error, disabled, and correction paths.

### 3.2 Out of scope

These require a change request under the parent BRD's change control.

- Automatic officiating: calling faults, lets, or service courts.
- Match formats, games to 21, intervals, or a completed-match winner; v1 tracks
  rally points as confirmed, not a rule set.
- Live scoring during play; the score is entered in review (00 §3.2).
- Team or player names in the score display; sides are Left and Right pending
  Q-9.
- Statistics derived from the score (runs, streaks, points-in-a-row).
- Cloud score sheets or sharing a score record.

### 3.3 Delivery status and gaps

Area status is Partial (00 §3.3 row 6). It is not release-ready: the engine crate
is untested and the scoreboard does not yet match the design contract.

| Group | Status | Gap |
| --- | --- | --- |
| Score derivation and persistence | Done | Client tests cover derivation, correction, clearance, and stored events; `sportcut-score` has no unit test |
| One-tap winner | Done | Five widget tests; no test asserts the "loss is not an error" styling |
| Serving side | Partial | Engine call is correct and pure, but untested; the scoreboard derives "who serves next" from the last scored rally, so an unscored last rally still shows a server |
| Design conformance | Partial | No 2 px accent underline under the serving label; score figures at 32 px, not 48–76 px; the score bug renders a 64 px stack instead of the compact 28–36 px top-band readout |
| Keyboard and timeline dock | Partial | The shell-owned 176 px dock renders the score track (FR-SHL-41); L/R key handling, focus retention, and score-chip emphasis remain gaps |

## 4. Functional requirements

Each row is one requirement with one observable acceptance criterion. Priorities
are MoSCoW. "Refuse" means: write nothing and show the named message.

### 4.1 Scoreboard and derivation

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-SCR-01 | Label both sides in text beside their figures. | Must | The scoreboard carries a visible label for each side; removing all colour leaves the side-to-figure mapping unambiguous (DS-4). |
| FR-SCR-02 | Set every score and timecode in tabular numerals. | Must | Score figures, rally spans, and the score line on each rally row use tabular figures, so digits do not shift width as the score changes (DS-5). |
| FR-SCR-03 | Derive the score from the confirmed winners in rally order. | Must | Recomputing from the same rallies yields the same timeline and the same final score on every call (`app/test/score_timeline_test.dart`). |
| FR-SCR-04 | Show no point for a rally with no confirmed winner. | Must | An unscored rally yields no score event and its row reads "Tap the side that won it"; the scoreboard does not advance. |
| FR-SCR-05 | Rewrite every later score when an earlier winner is corrected. | Must | Changing rally 1 from Left to Right rewrites rallies 2..n and the final score; the stored timeline matches the derived one. |
| FR-SCR-06 | Withdraw the point when a winner is cleared. | Must | Clearing a winner sets the rally back to `unscored` and removes its point from the timeline and the final score. |
| FR-SCR-07 | Keep exactly one score event per confirmed rally with an identity derived from the rally. | Must | An event id is `score-<rallyId>`; re-deriving produces the same set of events rather than duplicates. |
| FR-SCR-08 | Do not present 0–0 as a scored result before a match's records have loaded. | Should | While the edit has not loaded, the scoreboard shows a loading treatment or no figures; it never shows `0` beside each side as if scored. Current code renders `0`/`0` (gap). |

### 4.2 One-tap winner

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-SCR-09 | Record a rally's winner from one action on L or R. | Must | One activation sets the winner and `status = confirmed`; the row reads "Confirmed · 1–0" and the scoreboard follows (`app/test/score_screen_test.dart`). |
| FR-SCR-10 | Prompt for an undecided rally without implying a side. | Must | An unscored rally with no available hint shows "Tap the side that won it" and no side is marked. |
| FR-SCR-11 | Show the suggested serving side as a hint that does not set the winner. | Must | A hint renders as "Suggested: Left · tap to confirm" with a dashed border; the rally's winner stays null until the user taps. |
| FR-SCR-12 | Treat a lost rally as a normal outcome, never an error. | Must | A rally won by either side renders with the same colour, border, and icon set; no danger token, error banner, or warning icon appears for a loss (DS-12, DESIGN §2). |
| FR-SCR-13 | Disable scoring and reel controls while a write is in flight. | Must | During a write, L, R, keep, and remove are disabled; they re-enable after the reload; a second tap during the write cannot create a second change. |
| FR-SCR-14 | Report a failed write with a dismissible banner and keep the previous score. | Must | A failure shows the message in a banner with a close action; the scoreboard and rows still show the pre-change state. |

### 4.3 Serving side

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-SCR-15 | Derive each rally's server from the immediately previous rally's confirmed winner. | Must | With rallies L, R, L the serving sides are none, Left, Right (`core/entities/score/src/lib.rs`). |
| FR-SCR-16 | Show no server for the first rally. | Must | The first rally is absent from the serving map and shows no serving marker. |
| FR-SCR-17 | Show no server for a rally whose immediately previous rally is unscored. | Must | With rallies L, unscored, R the third rally is absent from the serving map and shows no marker. |
| FR-SCR-18 | Show no "serves next" marker while the most recent rally is unscored. | Must | With rallies [Left won, unscored] the scoreboard shows no serving marker, because the next server is unknown. Current code uses the last scored winner (gap). |
| FR-SCR-19 | Mark the serving side with a text label and a 2 px accent underline under that label. | Must | The serving side's label carries a 2 px `--accent` underline in both themes; the marker is not carried by colour alone (DESIGN §6, DS-3, DS-4). Current code colours the figure and adds a tennis icon (gap). |
| FR-SCR-20 | Recompute serving after any winner, removal, or boundary change. | Must | After each change the serving map matches a fresh derivation over the reloaded rallies. |
| FR-SCR-21 | Keep serving derivation in the engine and out of storage. | Must | Serving sides are computed on demand through a pure facade call; no table, column, or artifact stores them. |
| FR-SCR-22 | Never set or imply a winner from the serving hint. | Must | Activating the hint, or opening the lens, writes no winner; `status` stays `unscored` until an explicit L/R action. |

### 4.4 Score timeline and context

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-SCR-23 | Show the score as it stood at a clip's position, not the final score. | Must | A clip taken from rally 3 shows the score after rally 3's point, matching the row's "Confirmed · 18–16" line; `ScoreTimeline.atSeconds` supplies it. |
| FR-SCR-24 | Burn the same score convention into exported clips. | Should | Each exported clip's overlay uses the score at that clip's effective start, and all clips use one convention (00 Q-5, BRD 08). |
| FR-SCR-25 | Show the last three rallies in the Rally tab session block beneath the scoreboard. | Must | The shared inspector's Rally tab lists the three most recent rallies with their outcome and score beneath the scoreboard, keeping the fixed panel order of FR-SHL-48; the current view lists all rallies in one scrolling list (gap, DESIGN §5.5). |
| FR-SCR-26 | Score from the L and R keys on the shared review surface. | Must | With a rally selected on any review lens and focus not in a text field, pressing L or R confirms that rally's winner without changing the lens; the key map is documented in DESIGN §10 and the same action is reachable by pointer (FR-SHL-46; gap). |
| FR-SCR-27 | Return focus to the same winner button after the score re-renders. | Should | After a keyboard or pointer score, focus stays on the action just used so repeated scoring does not require re-targeting (DESIGN §10). Gap. |
| FR-SCR-28 | Keep the timeline playhead and the score in the shell-owned 176 px dock's score track. | Should | A rally segment, its score context, and the playhead render in the shell-owned timeline dock's score track (FR-SHL-41); no per-feature dock or second scrubber exists. |

### 4.5 Persistence and integrity

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-SCR-29 | Write the confirmed rally and its derived score events as one recoverable unit. | Should | A failure while storing a winner leaves either both the rally status and the stored events unchanged, or both updated; the library score and the scoreboard never disagree. Current code writes the rally, then rewrites events in a second transaction (gap). |
| FR-SCR-30 | Do not maintain a second, hand-written score. | Must | No code writes `matches.final_score_left` or `final_score_right`; the library score is aggregated from stored score events. |
| FR-SCR-31 | Keep the score independent of clip selection. | Must | Removing a rally from the reel changes no score event; taking a rally out of the reel leaves its score alone (`app/test/editing_repository_test.dart`). |

## 5. State coverage

These are content states inside the shared review surface's state matrix
(09 §4 and DESIGN §5.7); 09 §4 owns precedence: blocking shell state > lens
content state > job state. The Review & score lens's overlay set and inspector emphasis are
governed by FR-SHL-47 and FR-SHL-48; this feature contributes content only and
defines no second preview, transport, or timeline.

| State | Trigger | What the user sees | Evidence |
| --- | --- | --- | --- |
| Default | Match opened, no confirmed rally | Scoreboard at 0–0 with side labels; empty-rally sentence | `score_view.dart` |
| Loading | Edit or serving map in flight | A loading treatment or no figures; never 0–0 before records exist (target for FR-SCR-08) | Same |
| Empty | No rally marked | "No rallies yet. Scrub to a point, mark its start and end, and say who won it." | `score_screen_test.dart` |
| Empty (serving) | First rally, or previous rally unscored | No serving marker on that rally | `serving_sides_providers.dart` |
| Error | Write failed, engine call threw | Dismissible banner with the message; previous score retained | `_ProblemBanner`, `editing_providers.dart` |
| Success | Winner confirmed | "Confirmed · 18–16"; scoreboard and serving marker update | `score_screen_test.dart` |
| Disabled | Write in flight; player not ready | L, R, keep, remove, and Mark start disabled; labels retained (DS-8) | `score_view.dart` |
| Cancellation | Pending mark cancelled | Pending start cleared; nothing written | `_MarkControls` |

## 6. Design-contract specifics

- **Colour rules** (DESIGN §2): `--accent` (`#0E6E45` light, `#46D08D` dark) is
  the only signal, and it marks the serving side and the selected winner. Losing
  a rally is not an error, so `--danger` (`#B42318` / `#F27B70`) never styles a
  loss. Scores carry L/R or Left/Right text; colour never distinguishes the
  sides alone.
- **Scoreboard** (DESIGN §5.2–5.5, §6; 09 §5): the inspector's scoreboard is the
  single editable ledger, with L and R labels, 48–76 px tabular figures, a
  serving marker, and the last three rallies beneath it in the Rally tab's
  session block. The client uses 32 px Archivo figures (`--text-2xl`) and full
  side words; the size and the "last three" panel do not yet match.
- **Score bug** (DESIGN §5.2–5.3, §6; FR-SHL-42, FR-SHL-47): the Review & score
  lens paints a compact 28–36 px read-only score and serving readout in the
  preview's top band. It is pointer-transparent, never animates the score, and
  is not a second editor. The inspector ledger and the bug are never both
  hero-size; `ScScoreBug`'s 64 px stack is drift, not the target.
- **Lens emphasis** (FR-SHL-48): the Review & score lens opens the Rally tab
  scrolled to the scoreboard/winner block and pending suggestions, overlaid by
  the score bug, with scored rallies and score chips emphasised in the shared
  176 px dock. The tablist order, geometry, and controls do not change.
- **L/R on the shared surface** (FR-SHL-21, FR-SCR-26): the shortcut is available
  on every review lens by design. The shared surface makes the same single
  winner write reachable from Play, Review & score, and Highlights; it adds no
  second score path and changes no scoring rule.
- **Serving marker** (DESIGN §6): a 2 px accent underline under the serving
  side's label. The client instead tints the figure with `--accent` and adds a
  14 px icon with a "Serves next" tooltip.
- **Score band** (DESIGN §2, §6 Scoreboard): the scoreboard sits on a recessed
  surface, `--surface-warm` (`#E8ECE7` / `#182019`), with `--space-4` (16 px)
  horizontal and `--space-3` (12 px) vertical padding; dividers are hairlines,
  not cards.
- **Clip row** (DESIGN §6 Clip row): the score context on a clip row is the score at
  that clip's position, with the in/out timecodes in mono at `--text-xs` (12 px).
- **Motion** (DESIGN §7, DS-11): score digits do not animate and never count up;
  a digit changes in place. The client complies.
- **Voice** (DESIGN §8, DS-10): "Left won. Score 18–16." An error names the
  action that failed ("That change could not be saved: …"). The client complies.
- **Keyboard** (DESIGN §10): L / R score the rally. Not implemented (FR-SCR-26).

## 7. Feature non-functional requirements

Shared NFRs apply as written; this table records only the feature-specific
commitment and any local requirement.

| Requirement | Shared ID | Feature commitment |
| --- | --- | --- |
| Scoring does not block the UI. | NFR-2 | A winner write is one local SQLite transaction; the pane keeps its layout and disables its controls instead of showing a blocking spinner. |
| Confirmed winners survive interruption. | NFR-3, NFR-4 | A winner tap is committed before the UI reports success; a crash never leaves a half-written timeline. |
| The score is derived, not migrated by hand. | NFR-4 | Confirmations live in `rallies`; `score_events` is rewritten from them, so a schema change re-derives rather than patches. |
| Every score state is reachable from the keyboard. | NFR-6, DS-15 | L/R plus focus retention makes the pane operable without a pointer (FR-SCR-26, FR-SCR-27). |
| Engine and client agree on the rule. | NFR-7 | `sportcut-score` gets unit tests for the first-rally and unscored-previous cases. |
| One derivation implementation. | NFR-SCR-1 | The client never reimplements the serving rule; it calls `serving_sides`. |
| One display rule for scores. | NFR-SCR-2 | Derivation, the scoreboard, the library summary, and the export overlay all read the same `ScoreTimeline`. |

## 8. Acceptance and verification evidence

| Requirement group | Evidence in the tree | Prior record |
| --- | --- | --- |
| Derivation, correction, clearance, at-a-position | `app/lib/src/features/editing/domain/score_timeline.dart`; `app/test/score_timeline_test.dart` (7 tests) | Baseline `docs/verification/manual-editing-and-export.md` |
| Stored events, atomic replace, reel independence | `app/lib/src/features/editing/data/editing_store.dart`, `editing_repository.dart`; `app/test/editing_repository_test.dart` (13 tests) | Baseline `docs/verification/client-track.md` (test inventory) |
| One-tap winner, refusal, unscored row | `app/lib/src/features/score/presentation/score_view.dart`; `app/test/score_screen_test.dart` (5 widget tests) | Same |
| Serving rule | `core/entities/score/src/lib.rs`, `core/adapters/api/src/facade.rs` (`serving_sides`) | **No engine test**, no facade test; verified by reading the code only |
| Export score context | `app/lib/src/features/export/presentation/export_providers.dart` (`score.atSeconds`) | `app/test/export_screen_test.dart` covers the scoreboard image |
| Design conformance | [DESIGN.md §5.2–5.7, §6, §10](../../design-system/DESIGN.md), [tokens.css](../../design-system/tokens.css); `app/lib/src/features/workspace/presentation/studio/inspector_pane.dart`, `app/lib/src/app/design/components/sc_score_bug.dart` | Not audited; the shared inspector hosts the Rally tab, but the compact top-band score bug, the 2 px serving underline, the hero size, and the last-three panel are gaps (§3.3) |

Statements to hold to: the serving marker is implemented but untested; the 2 px
underline, the "last three rallies" panel, the L/R keys, and the
unscored-last-rally rule have neither a test nor an implementation. They are
requirements, not done work.

## 9. Dependencies, constraints, risks, open questions

### 9.1 Dependencies

| Dependency | What this feature needs | Condition to ship |
| --- | --- | --- |
| Rally Review (BRD 05) | Rallies with spans, and unscored rallies from acceptance | Required; without rallies the score has no unit |
| Studio shell (BRD 09) | The shared review surface, the Rally and Clip inspector, and the 176 px timeline dock that host this feature's content (FR-SHL-46 to FR-SHL-48) | Required; 06 defines content, not layout |
| `sportcut-score` and `sportcut-api` | `serving_sides` as a pure facade call | Internal |
| Design system v1.1 | Scoreboard size, serving underline, score-bug scale, keyboard map (DESIGN §5.2–5.7, §6, §10) | Design lead |
| Export (BRD 08) | Composites the score overlay per clip | Required for the scoreboard on a reel |

### 9.2 Constraints

- The score is a function of the rallies; no second editable score field exists
  (FR-SCR-30).
- Serving is derived at display time and is never persisted (FR-SCR-21).
- Sides are Left and Right until Q-9 decides whether names are v1.
- A correction rewrites the whole timeline; a patch-only update is not allowed.
- The score is not a rules engine: it counts confirmed rally points and stops
  there.

### 9.3 Feature risks

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| SCR-R1 | The serving rule regresses with no engine test (00 §3.3 row 6) | Medium | High | Add unit tests for the first rally, an unscored previous rally, and a correction | Engineering lead |
| SCR-R2 | The scoreboard shows a stale or invented figure during load (FR-SCR-08) | Medium | Medium | Render a loading state until the edit is present; add a widget test | QA lead |
| SCR-R3 | Displayed score and library summary diverge after an interrupted write (FR-SCR-29) | Low | High | Write the rally and events in one transaction; test a failure injected between them | Engineering lead |
| SCR-R4 | Design drift: no serving underline, wrong figure size, oversized score bug (R-6) | High | Medium | Align the scoreboard and score bug to DESIGN §5.2–5.3, §5.5, §6; add a golden or size assertion | Design lead |

### 9.4 Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-SCR-1 | Do side labels read "L / R" as DESIGN §6 says, or "Left / Right" as the client shows? | The copy is a design-contract value used in the scoreboard and the export overlay | Design lead |
| Q-SCR-2 | Does "who serves next" appear at all in v1, or only the per-rally server? | FR-SCR-18 defines the correct behaviour only if the marker is kept | Product owner |
| Q-SCR-3 | Is a clip's score the score before or after its own point? | Changes the export overlay for every clip; the client currently uses after | Product owner |
| Q-SCR-4 | Should a match format (game to 21, best of three) be v1 or deferred? | Without it the product shows a running count, not a score line | Product owner |

## 10. Traceability

| Requirement | Shared requirement | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| FR-SCR-01..07 | BR-4, BO-2 | §2, §5.2–5.5, §6 Scoreboard | `app/lib/src/features/editing/domain/score_timeline.dart`, `score_event.dart`, `rally.dart` | `app/test/score_timeline_test.dart`, `app/test/editing_repository_test.dart` |
| FR-SCR-08 | DS-8, NFR-2 | §5.7 States | `app/lib/src/features/score/presentation/score_view.dart` | Gap |
| FR-SCR-09..14 | BR-3, BR-4, DS-4, DS-12 | §2, §5.5, §6, §8 Voice | `score_view.dart`, `editing_providers.dart` | `app/test/score_screen_test.dart` |
| FR-SCR-15..22 | BR-3, BR-4 | §6 Scoreboard (serving marker) | `core/entities/score/src/lib.rs`, `core/adapters/api/src/facade.rs`, `app/lib/src/features/score/presentation/serving_sides_providers.dart` | Gap: no engine or widget test |
| FR-SCR-23..28 | BR-5, BR-8, DS-9, DS-15 | §5.2–5.6, §10 Keyboard; 09 FR-SHL-41, FR-SHL-46 to FR-SHL-48 | `score_timeline.dart` (`atSeconds`), `app/lib/src/features/export/presentation/export_providers.dart` | `app/test/export_screen_test.dart`; keyboard and dock: gap |
| FR-SCR-29..31 | NFR-3, NFR-4 | — | `app/lib/src/features/editing/data/editing_store.dart`, `editing_repository.dart`, `match_catalog.dart` | `app/test/editing_repository_test.dart` |

## 11. Approval

Version 1.1 (2026-11-02) aligns scoring with the shared review surface
(09 FR-SHL-46 to FR-SHL-48): the scoreboard is the inspector ledger, the score
bug is a compact read-only top-band readout on the Review & score lens, L/R
scoring works on any lens, and the score track belongs to the shell-owned dock.
It requires re-approval.

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |

---

**Change control.** This document inherits
[00-product-context.md §18](00-product-context.md#18-approval). A change to
scope, a Must requirement, or the design contract requires a version bump, a
recorded decision, and a re-run of the BRD quality checklist.
