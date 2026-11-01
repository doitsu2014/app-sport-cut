# Intent — Implement 04 Player Tracking

## Problem

Player tracking is the input every later analysis stage trusts, and it is Partial
(BRD 04 §2.3). A full 739 s doubles recording run through the real pipeline
(import → court → tracking → rally) shows the gap in observable terms:

- **613 track IDs for a four-player match.** A player who leaves the frame for
  more than `max_track_gap_ms` and returns gets a new identity, and ambiguous
  associations leave the detection untracked, so the compact track stream is
  fragmented rather than four continuous players.
- **Count is `Unknown` with 4.2% quality.** Only 156 of 3,699 sampled frames
  support a per-side layout, because fragmented identities never accumulate the
  minimum observations on both sides.
- **5–9 on-court detections per frame** on a doubles court. Low-confidence
  background and boundary people enter the compact stream; short-lived
  fragments used to add jitter to every rally motion bin.
- **Rally suggestions under-detect as a consequence.** With the old summed-motion
  thresholds (4.0 / 2.0) the same recording produced 15 rallies covering 6% of
  the match, against a 35-rally baseline for this footage.

## Users

- **The player reviewing a match.** They need a stable track overlay and a
  trustworthy count before confirming match details, and rally proposals that
  cover the real rallies.
- **The engineer tuning the engine.** They need a repeatable measurement on real
  footage, not a synthetic fixture, to change detector, association, or
  threshold values without guessing.

## Success criteria (observable)

1. On the reference recording, the track artifact reports `Four` only when at
   least 60% of sampled frames support the per-side layout; otherwise it reports
   `Unknown` with the quality, supporting-frame count, and evidence interval.
   Both outcomes are acceptable evidence; an unqualified count is not.
2. Track identities are stable: each player appearing for at least one rally
   keeps one identity across that appearance; a long absence records one gap and
   one resumed identity, not a new identity per frame.
3. Spectators, adjacent-court players, and boundary people beyond the marked
   court are `OffCourt` or `Borderline`, never tracked as players.
4. The compact segmentation input contains no track seen fewer than
   `min_track_observations` times; the review evidence still shows every
   detection and its decision.
5. Rally analysis on the reference recording yields 30–40 rallies covering
   10–30% of the recording, with every candidate at least `min_rally_ms`.
6. An opt-in automation test (`cargo test -p sportcut-api --features
   macos-tflite-eval --test real_footage`) runs the real pipeline and records
   those metrics; without `SPORTCUT_TEST_VIDEO` it skips and the default suite
   is unchanged.

## In scope

- Tracking association continuity, ambiguity handling, and short-lived-fragment
  filtering in `sportcut-vision` and the track adapter.
- Detector confidence and tracking defaults re-measured on real footage.
- Rally threshold re-tuning that follows from a cleaner track stream.
- The real-footage automation test, runbook, and BRD evidence update.

## Out of scope

- Retraining or replacing EfficientDet-Lite0; a new inference runtime.
- Manual track correction (splitting, merging, dragging IDs) and any new client
  UI beyond recording the measured values.
- Automatic officiating, winner inference, network access, or a second camera.
- Client-owned durable state; the service remains the artifact owner.

## Constraints and assumptions

- Offline only; the macOS trial TFLite runtime and the pinned model bundle.
- One heavy job at a time, cancellation, and atomic publication still hold.
- `docs/brd/04-player-tracking.md` and `docs/brd/05-rally-review.md` are the
  requirement sources; a Must change needs a version bump and approval.
- The reference recording is `IMG_1308.MOV`; its court corners are rear-baseline
  doubles coordinates measured on frame 700:
  `[[0.1802,0.9981],[0.8094,0.9981],[0.6938,0.3704],[0.4031,0.3704]]`. Approved
  as the acceptance recording, with those corners kept as the real-footage test
  defaults.

## Approved decisions

- **Scope:** 04 Player Tracking; the rally retune and automation test are
  evidence produced alongside it.
- **Acceptance recording:** `IMG_1308.MOV`, full 739 s, with the corners above
  committed as the test defaults.
- **Count floor:** `Four` requires at least 60% of sampled frames supporting the
  per-side layout; otherwise `Unknown` plus quality is the correct result.
- **Short-lived-track filter:** applies to the compact rally input only; the
  review artifact keeps every detection and decision.

## Cost of doing nothing

Tracks stay fragmented and the count stays `Unknown`; the rally panel proposes
fewer than half the baseline rallies on real footage. Users cannot trust the
proposal layer, and every later stage (score, highlights, export) inherits the
same incomplete timeline.
