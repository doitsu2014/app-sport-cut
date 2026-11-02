# Sportcut — Rally Review (Feature BRD 05)

## 1. Document control

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-005 |
| Version | 1.1 |
| Status | Draft — for approval |
| Date | 2026-11-02 |
| Owner | Product owner, Rally Review area |
| Contributors | Product, Design, Engineering, QA |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.1; shared review surface per BRD 09 v1.2 |
| Parent BRD | [00-product-context.md](00-product-context.md) |
| Area ID | RAL |

This document refines the shared contract in
[00-product-context.md](00-product-context.md). It cites BO, BR, DS, NFR, R, Q,
and M identifiers defined there and never redefines them. Identifiers prefixed
`FR-RAL`, `NFR-RAL`, `RAL-R`, and `Q-RAL` are scoped to this feature.

**Evidence note.** Analysis, storage, and verification documents are cited by
path at baseline `1541c64`; they are not part of the working tree, and this
suite is the current requirements source (§1 of the parent BRD). Code, tests,
and the design system in the tree are the stronger signal where a document and
the code disagree.

## 2. Purpose, users, and relationship to the product BRD

Rally review turns a continuous recording into a list of rallies the user can
act on. It proposes rally and rest spans from player motion, and it records what
the user decides about each proposal: accept as marked, accept with adjusted
boundaries, or dismiss. It also lets the user mark a rally by hand, which is the
path that always works.

Users: the club coach and the competitive player (00 §4.1), working through a
match in one sitting and returning later to finish it.

Relationship to the product BRD: this feature delivers BR-3 (semi-automatic,
user-confirmed results) for the rally span, and supplies the unscored rallies
that the Score and Serving BRD (06) confirms winners on. It does not score, rank
clips, or export. NFR-4 (user-authored data preserved) and R-5 (audio branch
inactive) are the shared requirements it most depends on.

Review happens inside the shared review surface defined by BRD 09 (FR-SHL-46
to FR-SHL-48). This feature supplies the rally content of the Rally tab; 06
supplies the scoreboard, score bug, and score-chip emphasis. It defines no
separate review layout, preview, transport, timeline, or route.

## 3. Scope

### 3.1 In scope

- Start a local segmentation job from the match's completed player tracks and a
  named calibration.
- Identify the exact analysis input generation and derive a stable generation
  identifier from it.
- Publish a versioned suggestion artifact covering the whole recording, split
  into rally, rest, and unknown spans, plus one candidate per rally.
- Fixed, deterministic duration and coverage rules (short rests joined, short
  rallies demoted, insufficient coverage refused).
- Cancel a running analysis; report failures with an actionable message.
- Review: accept, accept with adjusted boundaries, dismiss, per suggestion.
- Persist each decision against its generation; create the rally on accept.
- Manual marking from the playhead, with validation and a cancel path.
- Rally list interactions: seek to a rally, keep or drop it from the reel, and
  remove a rally without deleting the clip made from it.
- Review within the shared review surface: the Rally tab of the Review & score
  lens over the one shell-owned preview, transport, and 176 px timeline dock
  (09 FR-SHL-41, FR-SHL-46 to FR-SHL-48).

### 3.2 Out of scope

These require a change request under the parent BRD's change control.

- Audio-guided segmentation as a shipped claim; the branch exists in the engine
  but the track producer emits no intensities at baseline (R-5).
- Shuttlecock, racket, or shot-type detection; rally classification by content.
- Boundary auto-refinement, learned thresholds, or per-camera tuning.
- Editing the segmentation algorithm from the UI.
- Cloud or shared suggestion sets. All analysis is local (BR-1).
- Scoring, highlight ranking, and export. Those belong to 06, 07, and 08.

### 3.3 Delivery status and gaps

Area status is Partial (00 §3.3 row 5). No requirement below is claimed Done
without the evidence named in §8.

| Group | Status | Gap |
| --- | --- | --- |
| Suggestion generation | Partial | Thresholds tuned on one clip (`c1`); boundary accuracy unmeasured; audio inactive; no unit test in `sportcut-rally` |
| Review decisions | Partial | Accept, adjust, and dismiss are implemented and atomic, but no automated test covers decision persistence |
| Manual marking | Done | Client tests cover the span, the refusal, and the winner tap |
| Timeline and clip interactions | Partial | The shell-owned 176 px dock renders the ruler, rally, and score tracks (FR-SHL-41), with rest on the resting track; boundaries are not draggable and no user control calls `moveRally`; boundary drag inside the dock or preview overlay is the remaining gap |
| Client test coverage | Not started | No widget test for the rally review panel or `RallyReviewController` |

## 4. Functional requirements

Each row is one requirement with one observable acceptance criterion. Priorities
are MoSCoW. "Refuse" means: write nothing and show the named message.

### 4.1 Suggestion generation

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-RAL-01 | Start rally analysis as a background job from a match with final tracks and a named calibration. | Must | Selecting Analyze from the Rally tab of the Review & score lens (FR-SHL-46) returns a job handle; `job_status` reaches `completed`; no network call occurs (BR-1, NFR-1). |
| FR-RAL-02 | Refuse analysis when player tracks are missing, naming the missing prerequisite. | Must | On a match with no tracks artifact, the start call returns an error containing "player tracks are unavailable; run player tracking before rally analysis", and no job starts (`core/adapters/api/tests/unanalysed_match.rs`). |
| FR-RAL-03 | Refuse analysis when the calibration artifact is missing or not final. | Must | A match with non-final or absent calibration returns "court calibration is unavailable; mark the court before rally analysis" (`core/adapters/api/src/facade.rs`). |
| FR-RAL-04 | Record the exact analysis inputs and derive a deterministic generation identifier. | Must | The stored inputs carry duration, tracks fingerprint, calibration id, audio fingerprint, and config; identical inputs produce the same `generation_id`, and a changed tracks fingerprint or config produces a different one. |
| FR-RAL-05 | Publish the suggestion set atomically and only when final. | Must | The file is written to a temporary path and renamed, and the manifest entry becomes `Final` only after the rename; a cancelled or failed run leaves no final suggestion artifact. |
| FR-RAL-06 | Treat a suggestion set whose inputs no longer match as absent, not as a result. | Must | Loading with mismatched inputs returns `None`; the UI offers analysis rather than showing stale candidates. |
| FR-RAL-07 | Fail the run when tracks or calibration change while it is executing. | Should | The job fails with "tracking or calibration changed during rally analysis; run it again" and writes no suggestion artifact. |
| FR-RAL-08 | Partition the whole recording into contiguous rally, rest, and unknown spans. | Must | The timeline starts at 0, ends at the recording duration, has no gaps or overlaps, and validates on reload. |
| FR-RAL-09 | Produce one candidate per rally span, in recording order, with a bounded quality value and explicit audio provenance. | Must | Candidate count equals rally-span count; ids are `<generation>-<index>`; quality is within 0..1; `audio_available` matches whether an audio fingerprint was supplied. |
| FR-RAL-10 | Require minimum usable track coverage before proposing anything. | Must | Coverage below the configured minimum returns "player tracks have insufficient usable coverage: N% of the recording"; zero usable bins is never reported as "no rallies". |
| FR-RAL-11 | Join a rest shorter than the configured minimum when rallies flank it. | Should | A rest shorter than `min_rest_ms` with a rally immediately before and after becomes rally, so the two rallies are proposed as one. |
| FR-RAL-12 | Demote a rally shorter than the configured minimum to rest. | Should | A rally shorter than `min_rally_ms` becomes rest and produces no candidate; the same input yields the same spans on every run. |
| FR-RAL-13 | Cancel a running analysis without changing stored rallies or decisions. | Must | Cancel requests job cancellation, the job reaches `cancelled`, the running state and job id clear, and the rally and decision tables are unchanged. |
| FR-RAL-14 | Refuse an analysis grid larger than the engine's bounded limit. | Should | A duration and bin combination above 1,000,000 bins returns "requested analysis grid is too large" before allocating work. |

### 4.2 Review decisions

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-RAL-15 | List only candidates the user has not decided for the current generation. | Must | A candidate with an accepted or dismissed decision for the generation does not appear in the pending list; a different generation shows all its candidates as pending. |
| FR-RAL-16 | Accept a candidate as an unscored rally in one transaction with its decision record. | Must | One transaction inserts the rally and an `accepted` decision linked to it; the rally has `status = unscored` and no winner; a failure leaves neither row. |
| FR-RAL-17 | Record the candidate's motion quality as the accepted rally's confidence. | Should | The created rally's `confidence` equals the candidate's quality so highlight ranking has a motion signal (00 §6, BR-5). |
| FR-RAL-18 | Adjust both boundaries before accepting, and refuse an empty or inverted range. | Must | The adjust dialog shows the current range; its accept action is disabled while the end is not after the start; cancelling the dialog writes nothing; an accepted adjusted range is what the rally stores. |
| FR-RAL-19 | Refuse an accept that overlaps a rally already in the match. | Must | The transaction rejects the accept with "That suggestion overlaps a rally already in the match."; the UI disables Accept for that candidate and labels it "Overlaps a reviewed rally · adjust or dismiss". |
| FR-RAL-20 | Dismiss a candidate for the current generation only, creating no rally. | Must | A `dismissed` decision row is written with a null rally id; the rally table is unchanged; the candidate leaves the pending list. |
| FR-RAL-21 | Refuse to dismiss a candidate already accepted while its rally exists. | Should | Dismissing an accepted candidate raises "An accepted suggestion cannot be dismissed while its rally remains." |
| FR-RAL-22 | Make acceptance idempotent for the same generation and candidate. | Should | A second accept of an accepted candidate with a live rally writes nothing and creates no second rally. |
| FR-RAL-23 | Keep decisions across a rerun with unchanged inputs, and start a new generation unreviewed. | Must | Re-analysis with identical inputs shows the same decisions; a changed input generation shows its candidates as pending and never applies old decisions to new ids. |
| FR-RAL-24 | Report a failed decision without changing records, and allow retry. | Must | A failed accept or dismiss shows "That suggested rally could not be accepted" / "That suggestion could not be dismissed", clears the busy state, and leaves the candidate pending. |

### 4.3 Manual marking

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-RAL-25 | Mark a rally from the playhead with a start action then an end action. | Must | "Mark start" records the current position and relabels itself "Start at 0:42"; "Mark end" creates one unscored rally spanning the two positions (`app/test/score_screen_test.dart`). |
| FR-RAL-26 | Refuse an invalid span with a plain sentence and write nothing. | Must | A span whose end is not after its start, that starts before 0, that ends after the recording, or whose boundary is not finite is refused with the matching message (for example "A rally has to end after it starts."). |
| FR-RAL-27 | Cancel a pending start without recording a rally. | Must | "Cancel" clears the start and restores "Mark start"; the rally count is unchanged. |
| FR-RAL-28 | Keep manual marking available when no suggestions exist. | Must | With no suggestions, the panel states manual marking is available and "Analyze rallies" stays reachable. |

### 4.4 Timeline and clip interactions

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-RAL-29 | Seek the shared preview to a rally's start when its row is activated. | Must | Activating a rally row seeks the one shared preview to that rally's start time and marks that rally as selected, without changing the lens or the playback session (FR-SHL-45, FR-SHL-46). |
| FR-RAL-30 | Toggle a rally in or out of the reel from its row. | Must | The keep action creates one clip carrying the rally's span at the end of the reel order; the same action removes it; the rally and its score are unchanged (`editing_repository_test.dart`). |
| FR-RAL-31 | Remove a rally while keeping the clip made from it. | Must | Deleting a rally deletes its suggestion decisions and detaches its clip (`rally_id` set null); the clip stays in the reel and score events for other rallies are rewritten. |
| FR-RAL-32 | Edit an accepted rally's start and end. | Should | A boundary change moves that rally only, keeps its winner and status, and rewrites the score from the corrected position. Repository support exists and is tested; the client exposes no control (gap). |
| FR-RAL-33 | Drag a rally boundary inside the shared timeline dock or the preview overlay, on the Review & score lens only. | Could | Boundary edges drag with at least a 20 px hit target, distinct from the 24/44 px corner handles; rally and rest segments stay buttons for seek and select; a drag updates one rally through `moveRally`; no second scrubber or per-feature timeline appears (FR-SHL-41; DESIGN §5.6). Not implemented (gap). |

## 5. State coverage

These are content states inside the shared review surface's state matrix
(09 §4 and DESIGN §5.7); 09 §4 owns precedence: blocking shell state > lens
content state > job state. The Review & score lens's overlay set and inspector emphasis are
governed by FR-SHL-47 and FR-SHL-48; this feature contributes content only and
defines no second preview, transport, or timeline.

| State | Trigger | What the user sees | Evidence |
| --- | --- | --- | --- |
| Default | Match opened, no suggestion set for current inputs | "Manual marking is available"; Analyze enabled; no candidate list | `rally_review_providers.dart` |
| Loading | Analysis job running | Stage label plus determinate progress bar and Cancel | `RallyPanel` in the shared inspector |
| Empty (suggestions) | Completed set, nothing pending | "No unreviewed suggestions. You can still mark rallies." | Same |
| Empty (rallies) | No rally recorded | "No rallies yet. Scrub to a point, mark its start and end, and say who won it." | `score_screen_test.dart` |
| Error (analysis) | Job failed, or the call threw | Panel text "Rally analysis could not finish." or "Rally analysis is unavailable: …" | `rally_review_providers.dart` |
| Error (decision) | Accept or dismiss rejected | Inline message; candidate stays pending | Same |
| Error (overlap) | Candidate overlaps a rally | Row subtitle names the overlap; Accept disabled | `rally_panel.dart` |
| Success | Candidate accepted | New unscored rally in the list; candidate leaves the panel | Same |
| Disabled | Analysis unavailable in this build; a write in flight | Analyze disabled; accept, adjust, and dismiss disabled while busy | Same |
| Cancellation (job) | Cancel pressed | Job reaches cancelled; running state clears | `rallyReviewControllerProvider.cancel` |
| Cancellation (marking) | Cancel pressed after a start | Pending start cleared; nothing written | `_MarkControls` |

## 6. Design-contract specifics

- **One signal, labelled.** `--accent` (`#0E6E45` light, `#46D08D` dark) marks
  selection and progress only; every state carries a word (DESIGN §2, DS-3,
  DS-4). The suggestion panel's counts and the per-row overlap note are text,
  not colour alone.
- **Timeline dock** (DESIGN §5.6, FR-SHL-41): one shell-owned 176 px dock on
  every lens. Rest spans use `--surface-warm` (`#E8ECE7` / `#182019`), unkept
  rally segments a 22% `--accent` tint, kept segments a 32% `--accent` tint, the
  selected segment a 2 px `--fg` outline (`#101713` / `#EDF2EC`), and the
  playhead a 1 px `--accent` line. Timecodes sit above the track in mono at
  `--text-xs` (12 px). Boundaries drag only under FR-RAL-33, with a 20 px
  minimum target; segments remain buttons for seek and select. The Review &
  score lens emphasises scored rallies and score chips; kept and left-out state
  stays at base weight.
- **Clip row** (DESIGN §6 Clip row): in/out timecodes, duration, score context,
  keep/remove; kept clips use a check plus a surface ring; left-out clips drop
  opacity and stay recoverable until export. "Dismiss" applies to rally
  suggestions only, never to clips; 07 uses the same keep/remove vocabulary.
  The client uses a star with accent fill instead of a check plus ring (gap
  against §6).
- **Shared review surface** (DESIGN §5.1–5.6; 09 FR-SHL-46 to FR-SHL-48): one
  shell — toolbar, stage strip, video rail, preview, inspector, timeline dock,
  and status bar. This feature owns the rally content of the Rally tab in the
  inspector: suggestions, review decisions, manual marking, the rally
  list, and rally boundary edits. It supplies the Rally tab's default scroll
  anchor on Play (the rally list and last rallies). It does not own the score
  bug, the scoreboard/winner content, or score-chip timeline emphasis; 06 owns
  those parts of the Review & score lens. It defines no separate review layout,
  preview, transport, timeline, or route; a lens change never reloads the
  recording or moves the shell geometry.
- **Inspector emphasis** (FR-SHL-48): the inspector keeps the same regions and
  order in every lens (collapsed pipeline summary, Rally|Clip tablist, scrolling
  body, reel summary). The lens sets only the default tab and scroll anchor, so
  the Clip tab stays one click away and no control moves or disappears.
- **Type and shape.** Row titles use `--text-base` (16 px) with tabular numerals
  for spans; radii `--radius-md` 10 px on buttons and rows, `--radius-lg` 14 px
  on panels; spacing on the 4 px grid (`--space-2` 8, `--space-3` 12,
  `--space-4` 16). Focus uses the 2 px surface gap plus 2 px accent ring
  (`--focus-ring`, DS-9).
- **Voice.** Errors name what happened and the next action; no blame, no
  exclamation (DESIGN §8, DS-10). Existing copy already follows this.
- **Quality is a heuristic, not a probability.** The engine documents quality as
  a motion-and-support measure, not winner confidence (`dto.rs`). The panel
  labels it "Signal quality N%"; see Q-RAL-3.

## 7. Feature non-functional requirements

Shared NFRs apply as written; this table records only the feature-specific
commitment and any local requirement.

| Requirement | Shared ID | Feature commitment |
| --- | --- | --- |
| Analysis runs off the UI thread with stage-labelled progress and cancellation. | NFR-2, BR-11 | One job at a time; progress never decreases within the stage; Cancel is always reachable while running. |
| Analysis artifacts are atomic and never final on failure. | NFR-3 | Temporary file plus rename; manifest `Final` only after the write. |
| User-authored rallies and decisions survive reanalysis. | NFR-4 | Regeneration replaces only `tracks/rally_suggestions.json`; the catalog is never written by a job. |
| Suggestions are derived and regenerable. | NFR-4 | A stale or missing set is `None`, never a partial result. |
| Errors stay local and actionable. | NFR-13 | Messages name the missing prerequisite or the failed action; no telemetry. |
| No network in the analysis path. | NFR-1, BR-1 | Segments from local track data only. |
| Deterministic output for identical inputs. | NFR-RAL-1 | Same inputs and config produce the same `generation_id` and the same spans. |
| Bounded segmentation work. | NFR-RAL-2 | The grid is capped at 1,000,000 bins; the run fails fast rather than exhausting memory. |
| The engine never writes user-authored records. | NFR-RAL-3 | Jobs write inside the match directory only; the service catalog is written by catalog methods, not by analysis jobs. |

## 8. Acceptance and verification evidence

| Requirement group | Evidence in the tree | Prior record |
| --- | --- | --- |
| Generation, freshness, atomic publish | `core/entities/rally/src/lib.rs`, `core/gateways/storage/src/rally_suggestions.rs`, `core/adapters/api/src/facade.rs`, `core/adapters/api/tests/unanalysed_match.rs` | Baseline `docs/verification/rally-rest-segmentation.md` (one clip, 35 rallies, thresholds recorded) |
| Manual marking, validation | `app/test/score_screen_test.dart` (5 widget tests), `app/test/editing_repository_test.dart` (13 tests) | Baseline `docs/verification/manual-editing-and-export.md` |
| Decision persistence | `app/lib/src/features/editing/data/editing_store.dart`, `match_catalog.dart` migration v4 | **No test.** No case in `editing_repository_test.dart` calls accept or dismiss. |
| Timeline and clip interactions | `editing_repository_test.dart`: keep, trim, reorder, detach on delete | Baseline `docs/verification/client-track.md` (test inventory) |
| Shared review surface, lens emphasis | `app/lib/src/features/workspace/presentation/studio/studio_shell.dart`, `inspector_pane.dart`, `stage_strip.dart`, `timeline_dock.dart`; `app/lib/src/features/score/presentation/rally_panel.dart` | The shell renders the stage strip, the 176 px dock, and the stage-aware inspector, and the score bug exists; the per-lens default tab and scroll anchor (FR-SHL-48) and the compact top-band score-bug placement (FR-SHL-47) are gaps |
| Segmentation accuracy | Eval harness present, Results table empty | Unmeasured (R-1, BO-5) |

Status statements to hold to: acceptance and dismissal are implemented
atomically but unproven by test; the engine crate has no unit test; boundary
accuracy has never been measured against labels. FR-SHL-46 to FR-SHL-48 are
shared-surface requirements: the shell exists, but no feature BRD may claim
its lens behaviour is Done while the default tab, scroll anchor, and overlay
placement are unverified.

## 9. Dependencies, constraints, risks, open questions

### 9.1 Dependencies

| Dependency | What this feature needs | Condition to ship |
| --- | --- | --- |
| Player tracking (BRD 04) | A final `tracks/player_tracks.json` with coverage intervals and positions | Required; without it only manual marking works |
| Court calibration (BRD 03) | A final calibration identity for the generation | Required |
| `sportcut-rally`, `sportcut-storage`, `sportcut-api` | Segmentation, suggestion persistence, the facade calls | Internal |
| Downstream: Score and Serving (BRD 06) | 09 hosts the shared review surface; 06 supplies score and serving content for the Rally tab, and a winner change must not disturb review decisions | Internal |
| Design system v1.1 | Shared review surface, timeline dock, and clip-row treatments (DESIGN §5.1–5.6) | Design lead |

### 9.2 Constraints

- Suggestions are derived artifacts; the catalog is the only home for
  user-authored data (NFR-4).
- Thresholds are explicit configuration, not learned, and are recorded with each
  generation so a result can be replayed.
- A candidate id is `<generation>-<index>`; decisions are meaningless across
  generations by construction.
- Segmentation is motion-first; audio input is optional and inactive at baseline.

### 9.3 Feature risks

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| RAL-R1 | Unmeasured boundary accuracy makes suggestions untrustworthy (R-1) | High | High | Score one labeled clip with the eval harness; report boundary hit rate before claiming Done | QA lead |
| RAL-R2 | Thresholds tuned on one clip do not generalize | High | Medium | Re-tune across several clips; record the threshold set per run | Engineering lead |
| RAL-R3 | A change to the catalog drops decision rows | Low | High | Keep migration v4 additive; test migration from v3 | Engineering lead |
| RAL-R4 | Users lose review work when tracks are regenerated | Medium | High | Rallies and decisions live in the catalog, not the suggestion artifact; regeneration may replace the artifact but must never delete catalog rows | Engineering lead |

### 9.4 Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-RAL-1 | Is boundary drag inside the shared timeline dock (FR-RAL-33) v1, or is plus/minus boundary nudge acceptable? | FR-SHL-41 owns the dock geometry; the client has no control for `moveRally` and no second scrubber may be added | Design lead |
| Q-RAL-2 | Should the analysis threshold set stay fixed in the client, or become a per-match setting? | Affects reproducibility claims and the settings scope (BRD 09) | Product owner |
| Q-RAL-3 | How should the heuristic quality value be labelled so it is not read as a probability? | DESIGN §9 forbids invented metrics; the DTO says quality is not confidence | Design lead |
| Q-RAL-4 | When tracks change, should stale decisions be pruned or kept for provenance? | Affects table growth and NFR-4 wording | Engineering lead |

## 10. Traceability

| Requirement | Shared requirement | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| FR-RAL-01..14 | BR-3, BR-11, NFR-2, NFR-3 | §5.1–5.2; 09 FR-SHL-46 | `core/entities/rally/src/lib.rs`, `core/gateways/storage/src/rally_suggestions.rs`, `core/adapters/api/src/facade.rs` | `core/adapters/api/tests/unanalysed_match.rs`; baseline `docs/verification/rally-rest-segmentation.md` |
| FR-RAL-15..24 | BR-3 | §5.2–5.5, §6 Clip row; 09 FR-SHL-48 | `app/lib/src/features/rally/presentation/rally_review_providers.dart`, `app/lib/src/features/editing/data/editing_store.dart` | Gap: no test |
| FR-RAL-25..28 | BR-3, BR-4 | §5.5, §6 Actions, §8 Voice | `app/lib/src/features/score/presentation/score_view.dart`, `app/lib/src/features/editing/data/editing_repository.dart` | `app/test/score_screen_test.dart` |
| FR-RAL-29..31 | BR-5 | §5.6 Timeline dock, §6 Clip row; 09 FR-SHL-41 | `app/lib/src/features/editing/data/editing_store.dart`, `editing_repository.dart` | `app/test/editing_repository_test.dart` |
| FR-RAL-32..33 | BR-8, DS-3, DS-8 | §5.6 Timeline dock; 09 FR-SHL-41 | `app/lib/src/features/editing/domain/match_editing.dart` (no UI) | Gap |

## 11. Approval

Version 1.1 (2026-11-02) aligns this feature with the shared review surface
(09 FR-SHL-46 to FR-SHL-48): it defines the Review & score lens's overlay,
inspector emphasis, and timeline emphasis, and it removes the
separate-review-composition and private-scrubber claims. It requires
re-approval.

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
