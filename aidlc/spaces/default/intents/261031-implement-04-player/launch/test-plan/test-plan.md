# Test Plan — Player Tracking (Feature 04)

Status: Launch / Test Plan
Intent: `261031-implement-04-player`
Date: 2026-11-01
Inputs: `requirements.md`, `technical-spec.md`, `source-changes.md`,
`review-record.md`.

## 1. Risk-ranked requirements

| Requirement | Impact | Likelihood of regression | Risk | Test depth |
| --- | --- | --- | --- | --- |
| RQ-01 Top-four ≥ 60% | High | High (unmet) | **Critical** | Metric unit tests + full-reference acceptance (currently failing) |
| RQ-02 Count floor | High | Medium | High | Count-floor unit test (planned), acceptance evidence, client label |
| RQ-05 Rally yield | Medium | Medium | Medium | Full-reference acceptance, no ground truth |
| RQ-06 Opt-in acceptance | Medium | Medium | Medium | Fail-not-skip behaviour |
| RQ-07 Artifact compatibility | High | Low | Medium | Old-artifact fixture, facade tests |
| RQ-10 Determinism | High | Low | Medium | Pure-function equality; no cross-hardware claim |
| RQ-12 Unit coverage | Medium | Medium | Medium | Association ambiguity, coverage, config, segmentation |
| RQ-03 Spectator rejection | High | Low | Low | Acceptance artifact scan |
| RQ-04 Compact filter | Medium | Low | Low | Artifact unit tests |
| RQ-08 Offline/ownership | High | Low | Low | Layering, no-Rust, dependency scan |
| RQ-09 300 s | Low | Low | Low | Acceptance timing (84 s measured) |
| RQ-11 Grid cap | Low | Low | Low | Rally unit test |

## 2. Strategy

**Unit (pure functions, no footage).**
- `sportcut-vision` (6): fragmentation denominator/numerator/zero case,
  top-four selection, FR-TRK-08 ambiguity, coverage gap, config floors.
- `sportcut-rally` (6): short-rest join, short-rally demotion, timeline
  partition, coverage error, grid cap, determinism — all through the public
  `segment()`.
- `sportcut-api` (3): short-track filter and review retention, all-filtered
  rejection, old-artifact deserialization.

**Integration.**
- Existing facade tests (`unanalysed_match`, import/rally fixtures) remain
  green.
- Service transport and engine-host tests remain green (`tools/verify-engine.sh`).

**Acceptance (opt-in, real footage).**
- Full `IMG_1308.MOV`, fixed corners, tracking at 5 fps.
- Fails when the video is set but the file/runtime/model is missing.
- Recomputes the broad share and asserts the engine summary; RQ-02/03/04;
  RQ-05 on the full reference; timing.
- Records the baseline: 6.94% / 613 identities / 4.2% / 35 rallies / 15% /
  84.1 s. **Fails RQ-01's 60% gate by design.**

**Client.**
- `flutter analyze` and the media screenshot suite (4 tests). The full client
  suite has 40 pre-existing failures unrelated to this intent; they are not a
  gate here and are recorded.

**Deliberately not tested.**
- Detector accuracy against ground truth (no labelled dataset).
- Cross-hardware/thread-count reproducibility of TFLite.
- The service protocol path for tracking (the acceptance test calls the library;
  C-16).
- The licensing guard (U6 not implemented) and the BRD evidence update (U7).

## 3. Environments and data

- macOS arm64, `ffmpeg`/`ffprobe` on PATH, the pinned TFLite runtime and model in
  `third_party/inference`.
- `SPORTCUT_TEST_VIDEO` points at the reference recording; corners via
  `SPORTCUT_TEST_VIDEO_CORNERS` or the committed defaults.
- Temporary match directories; `SPORTCUT_TEST_KEEP` only for diagnosis.
- No production or user footage is committed; the reference path stays outside
  the repository.
- CI/default: no inference assets required; the acceptance test skips only when
  the video is unset.

## 4. Requirement traceability

| Requirement | Evidence | Status |
| --- | --- | --- |
| RQ-01 | Metric unit tests; acceptance broad-share gate | **Fail** (6.94% < 60%) |
| RQ-02 | Acceptance count evidence; client label/screenshot test | Pass (Unknown with quality/evidence) |
| RQ-03 | Acceptance artifact scan | Pass |
| RQ-04 | Artifact tests | Pass |
| RQ-05 | Acceptance full-reference count/time | Pass by count-fit (35 / 15%); no labels |
| RQ-06 | Unset/skip and set-but-missing cases; acceptance run | Pass |
| RQ-07 | Old-artifact test; facade tests | Pass |
| RQ-08 | Layering, no-Rust, dependency scan | Pass |
| RQ-09 | Acceptance timing 84.1 s | Pass |
| RQ-10 | Rally determinism test; pure-function design | Partial (no `track_detections` rerun test) |
| RQ-11 | Rally grid-cap test | Pass |
| RQ-12 | Vision/rally/artifact tests | Partial (count floor, gaps, classification not unit-tested) |

## 5. Exit criteria

For this intent's implementation:

- **Met:** default engine suite green; feature clippy clean; `flutter analyze`
  clean; selected client tests pass; acceptance runs, records metrics, and fails
  only RQ-01.
- **Not met:** RQ-01 ≥ 60%.
- **Not started:** U6 licensing guard; U7 BRD/protocol evidence; commit of the
  acceptance test and records.
- **Known-acceptable for this iteration:** RQ-05 is count-fit only; RQ-10/RQ-12
  have the documented partial cases; the client suite's pre-existing failures
  are out of scope.

The intent must not be called Done until RQ-01 is resolved or explicitly
rescoped, U6/U7 land, and the evidence is committed.

## 6. Risks and contingencies

| Risk | Contingency |
| --- | --- |
| RQ-01 remains unmet | Follow-up: calibration accuracy, detection gating, or stitching with sign-off |
| Acceptance output varies with hardware | Keep the default suite deterministic; acceptance is a measurement, not a CI gate |
| Missing inference assets | Fail with the fetch instruction; never a false green |
| Client suite noise | Scope client verification to analyze + the targeted screenshot suite; record the pre-existing failures |

## 7. Commands

```bash
tools/verify-engine.sh
cd core && cargo clippy -p sportcut-api --features macos-tflite-eval \
  --all-targets -- -D warnings
cd app && flutter analyze
cd app && flutter test test/screenshots/media_screens_test.dart

SPORTCUT_TEST_VIDEO=/path/to/IMG_1308.MOV \
SPORTCUT_TEST_VIDEO_CORNERS='[[0.1802,0.9981],[0.8094,0.9981],[0.6938,0.3704],[0.4031,0.3704]]' \
cargo test -p sportcut-api --features macos-tflite-eval \
  --test real_footage -- --nocapture
```

## 8. Test-generation recommendation

The suites were written alongside the implementation (U5) and the review added
the missing cases. No separate test-generation pass is required for this intent;
the remaining gaps (count-floor unit test, `track_detections` determinism,
classification/gap unit tests) are recorded as RQ-12 partials for the follow-up.
