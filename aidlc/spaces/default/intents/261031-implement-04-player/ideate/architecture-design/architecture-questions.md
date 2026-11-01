# Architecture Design Questions

## Q1: Where is the RQ-01 top-four share computed?

The track artifact already carries `review.frames` with every detection, so the
number can be derived without changing the artifact; exposing it from the engine
would add a field to the versioned track artifact.

A. The real-footage test computes it from `review.frames`; the engine stays
   unchanged.
B. The engine adds a fragmentation summary to `TrackingResult` and the artifact.
C. Both: the engine records a summary and the test asserts it against its own
   independent computation.
X. Other (describe)

[Answer]: C — approved: engine records a FragmentationSummary; the test recomputes it and asserts agreement plus the 60% gate.

## Q2: How should the association parameters enter `TrackingConfig`?

New tuning fields (staleness penalty, prediction weight, tentative-track
behaviour) are serialized into `TrackProvenance`, so a missing serde default
would stop old `player_tracks.json` deserializing and a client-facing field is a
protocol change.

A. Add optional fields with serde defaults; document a protocol minor bump.
B. Reuse existing fields and constants; no protocol or artifact change.
C. Add a versioned association-config block with explicit migration.
X. Other (describe)

[Answer]: A — approved: optional fields with serde defaults; documentation-only protocol note, no negotiated bump.

## Q3: Is the count-quality label fix in this intent?

The review panel labels count quality as “Coverage”
(`tracking_panel.dart:140`); FR-TRK-16 says a coverage figure must come from the
coverage intervals, and the screenshot test asserts the wrong label.

A. Yes — rename it “Count quality”, keep the percentage, update the test.
B. Separate client fix; this intent records the issue only.
X. Other (describe)

[Answer]: A — approved: rename to “Count quality” and update the screenshot test.

## Q4: How should the RQ-09 300 s budget be enforced?

The debug-build acceptance run measured ~90 s; a hard wall-clock assertion can
flake under parallel test load or on a slower machine.

A. Always assert ≤ 300 s.
B. Record per-stage timings always; enforce only with
   `SPORTCUT_TEST_ENFORCE_BUDGET=1` (or an optimized build).
C. Record only; no assertion.
X. Other (describe)

[Answer]: B — approved: print per-stage timings every run; enforce ≤300 s only in an optimized build or with SPORTCUT_TEST_ENFORCE_BUDGET=1.
