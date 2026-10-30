# Intent Capture Questions

Intent: `261029-implement-brd-feature`
Request: implement BRD feature 1 (Workspace and Library, area `LIB`).

Context: the BRD status table in `docs/brd/01-workspace-and-library.md` §2.3
describes baseline `1541c64`. HEAD (`c8beacf`) has since shipped the studio
refactor: library search, focus mode, shortcuts, status bar, and the
missing-recording state are present. Feature 1 is therefore mostly built, and
"implement" means closing the verified gaps — not starting from zero.

## Q1: What does "implement feature 1" cover?

A. Audit all 37 `FR-LIB` requirements against HEAD, then implement only the
   real gaps the audit confirms.
B. Implement only `FR-LIB-15` (Locate state), overriding ADR-0003 D8, which
   deliberately offers no fake relocate action.
C. Build the full service-owned SQLite catalog v6 now (ADR-0001 Phase 4).
D. Re-implement the feature end to end.
X. Other (describe)

[Answer]: A. Audit all 37 `FR-LIB` requirements against HEAD, then implement
only the real gaps the audit confirms.

## Q2: Where does catalog and recording custody land in this intent?

A. Keep the current client-owned v5 catalog and app-owned recording copy;
   defer the v6 service migration to ADR-0001 Phase 4.
B. Move catalog and custody into the Rust service as part of this intent.
X. Other (describe)

[Answer]: A. Keep the current client-owned v5 catalog and app-owned recording
copy; defer the v6 service migration to ADR-0001 Phase 4.

## Q3: Test posture?

A. Implementation only; touch a test only when the change stops it compiling.
B. Fix the stale home/shell tests and add widget coverage for changed behavior.
C. Skip tests entirely, including stale ones that no longer compile.
X. Other (describe)

[Answer]: A. Implementation only; touch a test only when the change stops it
compiling.

## Q4: Gate autonomy for the remaining stages?

A. Auto-approve gates, as `aidlc/config.json` sets `mode: yolo`.
B. Stop for manual approval at every stage.
X. Other (describe)

[Answer]: A. Auto-approve gates, as `aidlc/config.json` sets `mode: yolo`.

## Contradiction analysis

- Q1-A versus Q2-A: consistent. Auditing and gap-filling stays inside the
  client-owned v5 catalog; no ownership change is implied.
- Q1-A versus Q3-A: consistent. The BRD's "tests blocked" row records status,
  not a requirement to author new tests; stale tests are repaired only if they
  stop compiling.
- Q1-A versus Q4-A: consistent. Auto-approval changes who signs each gate, not
  what the stages produce.
- Q1-A versus ADR-0003 D8: no conflict. The audit treats `FR-LIB-15` as satisfied
  by the deliberate "no fake relocate" design, unless the audit finds a gap the
  ADR does not cover.
- No open contradictions.
