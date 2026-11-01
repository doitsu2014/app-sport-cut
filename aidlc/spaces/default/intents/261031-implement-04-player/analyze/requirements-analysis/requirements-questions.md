# Requirements Analysis Questions

## Q1: What track-continuity target should RQ-01 use?

The four longest tracks currently cover 8.7% of 17,387 on-court observations;
613 identities carry the rest. The target must be measurable from the artifact.

A. Top-four share at least 60%.
B. Top-four share at least 50%.
C. Top-four share at least 70%.
D. Record the share without a pass/fail target.
X. Other (describe)

[Answer]: A — top-four share at least 60%.

## Q2: Are focused unit tests in scope?

BRD 04 §2.3 and BRD 05 §3.3 record that `sportcut-vision` and `sportcut-rally`
have no unit tests. The real-footage test is already in scope.

A. Add focused unit tests for association, coverage, and segmentation.
B. Real-footage automation only; no new crate-level unit tests.
C. No new tests beyond the existing suite.
X. Other (describe)

[Answer]: A — add focused unit tests for association continuity, coverage intervals, and segmentation edges.

## Q3: What should happen to the detector confidence floor (currently 0.2)?

The reference run tracks 5–9 on-court people per frame on a doubles court;
many low-confidence boxes are background or boundary people.

A. Keep 0.2 and measure the effect of the association fix first.
B. Raise it to 0.35 and re-measure.
C. Make it a per-match configuration the user can tune.
X. Other (describe)

[Answer]: A — keep 0.2 and measure after the continuity fix.

## Q4: Is a five-minute budget for the full reference analysis acceptable?

The measured wall time was about 90 s in the real-footage test and about
4 minutes with shell orchestration and proxy generation.

A. Yes — 300 s is the budget (RQ-09).
B. Yes, but target 180 s.
C. No budget; correctness first.
X. Other (describe)

[Answer]: A — 300 s budget.
