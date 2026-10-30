# Requirements Analysis Questions

Intent: `261030-implement-03-court`
Mode: yolo (`aidlc/config.json`) — recommended answers auto-selected and
recorded below.

## Q1: How should the default court behave before any projection?

A. Keep the BRD's STATE:Default as written: four default corners and an enabled
   Save, but no net or outline until the engine returns geometry; the
   non-projected supporting line becomes a prompt.
B. Project automatically on open so a default net appears immediately.
C. Disable Save until the user drags a corner and the engine projects.
X. Other (describe)

[Answer]: A. Keep STATE:Default as written: no net or outline until the engine
returns geometry; the supporting line becomes a prompt.

## Q2: Where should the `#0A0F0C` bed correction land?

A. Correct the shared `SportcutTokens.overlayBed` and `ScOverlayColors.bed` to
   `#0A0F0C`, then check every consuming surface for regressions.
B. Add a calibration-only constant and leave the shared tokens at `#050806`.
X. Other (describe)

[Answer]: A. Correct the shared token and check consumers; the design system
contract names `#0A0F0C` and both current values disagree with it.

## Q3: Remove or demote the inspector's duplicate instruction and hints?

A. Remove the instruction paragraph and the four `_cornerHints`; put corner
   names into each handle's `Semantics` label.
B. Keep the hints but restyle them as micro-labels and remove only the
   paragraph.
C. Keep both; treat the numbered handles as the single instruction instead.
X. Other (describe)

[Answer]: A. Remove both; corner order stays on the numbered handles and their
semantics.

## Q4: How is STATE:Cancellation resolved?

A. Document the real behaviour: a Cancel control leaves the stage without
   saving and the unsaved session stays parked.
B. Remove the Cancel control so the BRD's "no cancel action" text becomes true.
X. Other (describe)

[Answer]: A. Document the real behaviour; removing a working control is a
product decision outside this intent.

## Q5: Test posture inherited from the intent?

A. Implementation only; no new tests; leave the two stale `FilledButton`
   lookups recorded as an evidence gap.
B. Repair the two lookups (`FilledButton` → `ScButton`) while touching the
   feature.
X. Other (describe)

[Answer]: A. Implementation only; no new tests; record the stale lookups.

## Contradiction analysis

- Q1-A versus the intent's criterion 2: consistent. "No net before projection"
  is the BRD's own state row; the projection still runs on open for a
  calibrated match, so FR-CAL-17 keeps its restored net.
- Q2-A versus the design contract: consistent. The contract value is `#0A0F0C`;
  the regression check is the safeguard for other consumers.
- Q3-A versus FR-CAL-08: consistent. The criterion forbids a second instruction
  block; moving order into handle semantics preserves FR-CAL-02.
- Q4-A versus FR-CAL-15 and STATE:Cancellation: consistent. No behavioural
  change, only documentation.
- Q5-A versus `CLAUDE.md`: consistent. The two lookups were already failing
  before this intent; repairing them needs an explicit request.
- No open contradictions.
