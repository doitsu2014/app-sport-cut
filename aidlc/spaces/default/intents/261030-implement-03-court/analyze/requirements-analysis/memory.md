# Requirements Analysis — Stage Diary

## Interpretation

- 2026-10-30: Read "satisfied" rows as regression scope, not as implementation
  work. The intent's success criteria and the BRD's acceptance rows are the same
  claim, so the matrix carries every BRD row rather than only the gaps.
- 2026-10-30: Treated `STATE:Default` and FR-CAL-05 as compatible: the default
  court is complete and saveable, but nothing is projected until the engine
  returns geometry. The audit's wording ("net not yet drawn") is the BRD's own.

## Tradeoff

- 2026-10-30: Gave the bed/scrim and contrast a single requirement (R-CAL-06)
  rather than splitting them; the contrast outcome depends on the bed colour, so
  one acceptance calculation covers both.
- 2026-10-30: Kept NFR-CAL-05 (test counts) as recorded evidence rather than a
  repair requirement, because the two failing lookups predate the intent and the
  working agreement forbids unrequested test edits.

## Open question

- 2026-10-30: Whether correcting the shared `overlayBed` token from `#050806`
  to `#0A0F0C` regresses another surface is not yet measured; the implementation
  must check consumers. If one depends on the darker value, use a
  calibration-local token instead and record the deviation.
