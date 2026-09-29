# Intent Capture Questions

Intent: `260929-accuracy-evaluation-harness`
Request: "Accuracy evaluation harness for player count and rally segmentation"
Mode: yolo — recommended answers auto-selected and recorded below.

### Q1: What problem does this solve, and for whom?

A. Phase 0 and Phase 2 accuracy targets are stated but never measured. Rally
   thresholds were tuned on one clip (`c1`) from the motion distribution only,
   and player-count accuracy has no number at all. Developers tuning the vision
   and rally pipelines have no way to tell whether a change helps or hurts.
   *(Recommended)*
B. End users need an in-app accuracy report.
X. Other

[Answer]: A (auto-selected)

### Q2: What does success look like, in observable terms?

A. One offline CLI command scores engine output for a labeled clip set against
   hand labels and prints per-clip plus aggregate metrics that map 1:1 to the
   roadmap targets: player-count accuracy (target ≥85% of clean clips),
   boundary hit rate within ±2 s (target ≥85%), confidently-wrong rate
   (target ≤5%). Re-running on the same inputs gives byte-identical output.
   *(Recommended)*
B. A, plus automatic threshold search.
X. Other

[Answer]: A (auto-selected). Threshold search is a follow-up once numbers exist.

### Q3: What is explicitly out of scope?

A. Flutter UI, labeling tool UI, automatic threshold tuning, new models,
   shuttle/shot detection, CI execution on real footage, committing footage.
   *(Recommended)*
X. Other

[Answer]: A (auto-selected)

### Q4: Hard deadlines, budget, or regulatory constraints?

A. No deadline. Footage is personal/consented and must never enter git or
   leave the machine (offline-only principle). Labels contain only timestamps
   and counts, so they may be committed for a synthetic fixture only.
   *(Recommended)*
X. Other

[Answer]: A (auto-selected)

### Q5: What happens if we do nothing?

A. Threshold changes stay guesswork; Phase 4 weight tuning has no ground truth
   to tune against; v1 success criteria cannot be claimed. *(Recommended)*
X. Other

[Answer]: A (auto-selected)

## Ambiguity and contradiction check

- "Clean videos" (Phase 0 criterion) is interpreted as clips meeting the
  recording guidelines in `docs/features-roadmap.md`; the label file carries a
  `clean` flag so the aggregate can be filtered.
- "Confidently wrong" is interpreted as a predicted rally span with no
  overlapping labeled rally, or a labeled rally fully classified as rest.
  Recorded for confirmation in requirements.
- No contradictions with org/team/project memory.
