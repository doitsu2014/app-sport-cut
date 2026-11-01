# Intent Capture Questions

## Q1: Which workflow does "the next BRD" mean?

The last intent was `261030-implement-03-court`, so the next feature in the
series is 04. The two other requested tasks (rally analysis fixes and real-video
automation) live mostly in 04's downstream consumer, 05.

A. 04 Player Tracking — fix tracking continuity, count quality, spectator
   rejection, and the real-footage measurement that rally analysis depends on.
B. 05 Rally Review — focus the workflow on suggestion generation, thresholds,
   and review decisions; leave tracking as it is.
C. A new BRD 10 — Rally analysis accuracy, with real-footage measurement and
   automation as its own feature.
D. Both 04 and 05, in sequence, under one intent.
X. Other (describe)

[Answer]: A — 04 Player Tracking.

## Q2: Is `IMG_1308.MOV` the acceptance recording?

The measurement used the full 739 s recording and these rear-baseline doubles
court corners: `[[0.1802,0.9981],[0.8094,0.9981],[0.6938,0.3704],[0.4031,0.3704]]`.

A. Yes — record it as the reference recording and keep those corners in the
   real-footage test defaults.
B. Yes for measurement, but do not commit the corners; require an env override.
C. No — use a different recording (describe where it lives and its corners).
X. Other (describe)

[Answer]: A — record the recording and keep the measured corners as the test
defaults.

## Q3: What count-quality floor makes `Four` trustworthy?

The current run reports `Unknown` at 4.2% supporting frames. A floor turns the
count into a testable acceptance criterion.

A. At least 60% of sampled frames support the per-side layout.
B. At least 40%.
C. Record the count and quality without a floor; treat the count as a proposal
   only.
X. Other (describe)

[Answer]: A — at least 60% of sampled frames.

## Q4: Where should the short-lived-track filter apply?

Tracks seen fewer than `min_track_observations` times (3) are removed from the
compact rally input; 189 of 17,387 positions on the reference recording came
from those fragments.

A. Compact input only — the review artifact keeps every detection (current
   change).
B. Compact input and the review panel — hide those fragments from the user.
C. No filter — keep every tracked position in the rally input.
X. Other (describe)

[Answer]: A — compact input only; the review artifact keeps every detection.
Approved together with intent capture.
