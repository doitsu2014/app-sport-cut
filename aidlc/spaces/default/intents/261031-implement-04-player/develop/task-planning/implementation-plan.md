# Implementation Plan — Player Tracking (Feature 04)

Status: Develop / Task Planning
Intent: `261031-implement-04-player`
Date: 2026-10-31
Inputs: `technical-spec.md`, `design-decisions.md`, `api-contract.md`,
`requirements.md`.

## Approach

Measure first, then change one variable. The walking skeleton is the metric:
the fragmentation summary flows from `track_detections` through the artifact and
DTO into the hardened real-footage test, which records the pinned before value.
Only then does the association change land, and the same test measures the after
value under the same definition. Boundary validation, the client label,
unit tests, the licensing guard, and the evidence updates follow.

The order is risk-first:

1. **U1 — Pin the metric** (S1a). One definition, engine summary, artifact/DTO
   plumbing, old-artifact compatibility.
2. **U4 — Harden the acceptance test** (S1b). Fail-not-skip, RQ-01..RQ-05
   assertions, denominator/numerator floors, timing. Run it once on the current
   tracks to record the before value.
3. **U2 — Continuity-aware association** (A). Prediction, fixed-scale gate,
   plausibility/ranking split, fresh-first ordering, tentative tracks.
   Re-measure. **Stop if the broad share is below 60%.**
4. **U3 — Boundary validation and client correctness.** Reject below-floor
   values; rename the count-quality label; remove the dead asset-path passing.
5. **U5 — Unit tests** (S3). Vision, rally, artifact, and client cases.
6. **U6 — Licensing guard** (S2). Embed/preflight guard and reference fixes.
7. **U7 — Evidence and docs.** BRD/protocol updates, commit the test and records.

## Walking skeleton

U1 + U4: the engine records `FragmentationSummary`, the test reads the artifact,
recomputes the broad share, asserts the floors, and prints the value. This proves
the measurement path end to end before any association behaviour changes.

## Conventions

- Rust: `rustfmt` (100 columns), workspace lints; no `unsafe`; no new
  dependency; new config/artifact fields are `Option` or `#[serde(default)]`.
- Deterministic output: sort by `(count desc, id asc)` for the top four; no
  HashMap iteration reaches output.
- No hidden tuning: every threshold is configuration recorded in provenance.
- Flutter: `flutter_lints`; no raw colours; no new durable state.
- Scope discipline: no stitching, no detector/runtime change, no new protocol
  method, no client-owned artifact.

## Build, lint, and test commands

```bash
# Engine (format, lint, tests, layering)
tools/verify-engine.sh
tools/check-layering.sh
cd core && cargo clippy -p sportcut-api --features macos-tflite-eval \
  --all-targets -- -D warnings

# Acceptance (opt-in, full reference; ~90 s in-test)
SPORTCUT_TEST_VIDEO=/path/to/IMG_1308.MOV \
SPORTCUT_TEST_VIDEO_CORNERS='[[0.1802,0.9981],[0.8094,0.9981],[0.6938,0.3704],[0.4031,0.3704]]' \
cargo test -p sportcut-api --features macos-tflite-eval \
  --test real_footage -- --nocapture

# Client
cd app && flutter analyze
cd app && flutter test test/screenshots/media_screens_test.dart

# Guards
tools/check-no-rust-in-app.sh
tools/preflight.sh --profile engine
```

## Review strategy

- One unit per review-sized change; the human reviews each before the next.
- U2 is gated on the U4 measurement; a shortfall is recorded, never hidden.
- Each unit names its acceptance evidence in `unit-breakdown.md`.
- No commit from the agent; the working tree is reviewed with `git diff`.

## Risks and checkpoints

| Checkpoint | Question | Action if it fails |
| --- | --- | --- |
| After U4 (before) | Does the hardened test record a broad share and the floors? | Fix the measurement; do not start U2. |
| After U2 (after) | Is the broad share ≥ 60% with the numerator/denominator guards? | Stop and record the shortfall; no denominator move, no stitching. |
| After U3 | Are below-floor values rejected and the label corrected? | Fix before tests rely on them. |
| After U5 | Do both crates have the named unit tests? | Add the missing cases; they gate RQ-12. |
| Before Done | Is the licensing verdict reconciled and guarded? | Do not claim Done. |

## Definition of done

- RQ-01..RQ-12 have the evidence named in the spec; the acceptance test passes
  on the full reference with the pinned metric.
- Old artifacts and old client payloads still deserialize.
- `tools/verify-engine.sh`, feature clippy, layering, no-Rust, and
  `flutter analyze` pass.
- S2 is reconciled; the test and intent records are committed.
