# Refactor Notes — Player Tracking (Feature 04)

Status: Develop / Refactoring
Intent: `261031-implement-04-player`
Date: 2026-11-01
Inputs: `review-record.md`, `source-changes.md`, current code and tests.

## 1. Justification

The code review's accepted structural item was that three rally unit tests
called private helpers (`smooth_short_rest`, `discard_short_rallies`,
`collect_spans`). Those tests pinned internal signatures: a behaviour-preserving
refactor inside `sportcut-rally` would break them even though the public
segmentation contract was unchanged. The cost is false failures and pressure
against internal cleanup; the benefit of fixing it now is that the tests assert
the public `segment()` behaviour and survive internal changes. The debt was
introduced by this intent's test pass, so it is addressed now rather than
carried forward.

## 2. Safety net

`segment` is a pure function with existing coverage for the coverage floor, the
1,000,000-bin cap, and determinism. The three rewritten tests add public
assertions for the short-rest join, short-rally demotion, and timeline
partition. No production behaviour is changed, so no characterisation tests
beyond these were needed.

## 3. Changes

Only `core/entities/rally/src/lib.rs` tests changed:

| Test | Before | After |
| --- | --- | --- |
| `short_rest_between_rallies_is_joined` | Called `smooth_short_rest` on a hand-built state vector. | Drives `segment()` with a move–stand–move track and asserts one joined rally span. |
| `short_rally_is_demoted_to_rest` | Called `discard_short_rallies` on a state vector. | Drives `segment()` with a single moving bin and asserts no candidates. |
| `spans_partition_the_recording_without_gaps` | Called `collect_spans` directly. | Drives `segment()` and asserts the public timeline is contiguous and covers the duration. |

No production code, public API, artifact schema, configuration, or client code
changed.

## 4. What stayed the same

- Segmentation thresholds, hysteresis, smoothing, minimums, coverage floor,
  grid cap, and candidate rules.
- The compact `SegmentationInput` and suggestion identity.
- All other unit tests and the acceptance harness.

## 5. Verification

- `cargo test -p sportcut-rally`: 6 passed.
- `tools/verify-engine.sh`: passed (fmt, clippy, default suites).
- `flutter analyze`: unchanged and clean.
- The opt-in acceptance measurement is unchanged: restored baseline 6.94% /
  613 identities / 4.2% / 35 rallies / 15%; the RQ-01 60% gate remains the
  recorded shortfall.

## 6. Residual structural notes

- The full-reference acceptance test is long but is one sequential evidence
  chain; splitting it would hide the order in which the metrics are produced.
  No change.
- U6 (licensing guard) and U7 (BRD/protocol evidence) remain deferred Done
  prerequisites; they are not refactoring work.
