# Code Review Record — Player Tracking (Feature 04)

Status: Develop / Code Review
Intent: `261031-implement-04-player`
Date: 2026-11-01
Inputs: `source-changes.md`, `code-generation-notes.md`, the full working-tree
diff, `technical-spec.md`, `requirements.md`.

## 1. Scope

The full diff was reviewed twice: a correctness/contract pass and a
security/boundary pass. The accepted change set is U1 (fragmentation metric and
plumbing), U2 (hardened acceptance test), U4 (boundary validation and client
correctness), and U5 (unit tests). U3 (continuity-aware association) was
reverted after its checkpoint failed; the review verified that none of its code,
config fields, DTO mappings, or tests remain.

The restored baseline is top-four 6.94% (1,504/21,672), 613 identities, count
Unknown 4.2% (156 supporting frames), 35 rallies / 112 s (15%), 120.6 s. The
opt-in acceptance test fails only the RQ-01 60% gate; that is the recorded
shortfall.

## 2. Verdict

**Approved with issues.** No blocking defect was found. The code is offline, adds
no dependency, keeps the service boundary and FR-TRK-08, and the measurement,
hardening, validation, and client changes are sound. The review's major finding
was contract-record drift from the revert; it and all actionable minors were
fixed in this pass. The remaining deferred items are Done/release prerequisites,
not code defects.

## 3. Findings and disposition

| # | Severity | Finding | Disposition |
| --- | --- | --- | --- |
| 1 | Major | Approved `api-contract.md`, `architecture-doc.md`, and `technical-spec.md` still specified the reverted association fields/behaviour; `source-changes.md` still claimed them. | **Fixed:** dated revision notes added to all three records; source-change rows corrected; revert added to the deviations list. |
| 2 | Minor | `BEFORE_COUNT_QUALITY = 0.042` was compared exactly at 0.04218; a small frame-count change would fail before the RQ-01 gate. | **Fixed:** the guard now uses a supporting-frame floor (≥150) and is evaluated after the rally measurement; the RQ-01 gate remains last. |
| 3 | Minor | The test hardcoded `MIN_CONFIDENCE`, count floors, and the 1.5 s rally minimum instead of reading the recorded configuration. | **Fixed:** the recomputation uses `provenance.tracking.court.min_confidence`; count checks use `min_count_frames`/`min_count_fraction`; the rally floor uses `rally_config().min_rally_ms`. |
| 4 | Minor | `prepared_video` mapped `0:a:0` unconditionally although audio is optional. | **Fixed:** optional-stream syntax `0:a:0?`. |
| 5 | Minor | The all-filtered error path in `TrackArtifact::from_tracking` had no test. | **Fixed:** a generation whose only track is below the minimum is rejected with the named message; the existing test covers the retained boundary. |
| 6 | Minor | The tie-break test asserted a sum, which is invariant under ordering. | **Fixed:** replaced with a five-identity selection test proving the fifth is excluded. |
| 7 | Minor | `coverage_intervals` and old-artifact deserialization had no focused test. | **Fixed:** a frame-gap coverage test and a `review` JSON fixture without `fragmentation` were added. |
| 8 | Minor | C-20's raw-detection floor was not asserted. | **Fixed:** `BEFORE_RAW_DETECTIONS` (22,667) floor added beside the on-court floor. |
| 9 | Minor | After the U3 revert there was no automated FR-TRK-08 ambiguity test. | **Fixed:** two plausible tracks around one detection yield `association_ambiguous == true` and `track_id == None`. |
| 10 | Minor | The protocol note for the additive `trackQuality`/`countSupportingFrames`/`fragmentation` fields was missing. | **Fixed:** a documentation-only note added to `docs/architecture/protocol.md` §14. |
| 11 | Minor | The client rally retune (4.0/2.0 → 3.5/1.5) was not recorded in the change record. | **Fixed:** recorded in `source-changes.md` with its 35-rally/15% evidence and BRD 05 trace. |
| 12 | Minor | A machine-specific absolute video path sat in the implementation plan. | **Fixed:** replaced with `/path/to/IMG_1308.MOV`. |
| 13 | Nit | `inference_assets.dart` remained after its only caller was removed. | **Fixed:** deleted; no client-side inference-path resolution remains. |
| 14 | Minor | U6 licensing guard is paused. | **Deferred (Done prerequisite):** implement the embed/preflight guard and reconcile the EfficientDet verdict before any Done/release claim. |
| 15 | Minor | U7 BRD/protocol evidence updates are paused. | **Deferred (Done prerequisite):** update BRD 04/05 evidence and commit the acceptance test and intent records. |
| 16 | Nit | The service rejects only camelCase `runtimePath`/`modelPath`, not snake_case spellings. | **Deferred:** pre-existing defence-in-depth gap; the handler never reads those params and builds the request with `None`. |
| 17 | Nit | `.DS_Store` is tracked and modified. | **Deferred:** pre-existing, unrelated to this intent. |
| 18 | Nit | The acceptance test and intent records are untracked. | **Deferred:** commit only on the user's instruction; K-07 tracks it as a Done prerequisite. |
| 19 | Minor | Rally unit tests call private helpers (`smooth_short_rest`, `discard_short_rallies`, `collect_spans`). | **Accepted:** the public `segment` determinism/coverage cases exist; the helper cases are supplemental and will move to public inputs in a later test pass. |

## 4. Verification after fixes

- `cargo test -p sportcut-vision`: 6 passed (fragmentation ×3, FR-TRK-08
  ambiguity, coverage gap, config floors).
- `cargo test -p sportcut-api track_artifact`: 3 passed (short-track filter,
  all-filtered rejection, old-artifact deserialization).
- `cargo test -p sportcut-rally`: 6 passed.
- `tools/verify-engine.sh`: passed.
- `cargo clippy -p sportcut-api --features macos-tflite-eval --all-targets -- -D warnings`:
  passed.
- `flutter analyze`: no issues; the media screenshot suite passed (4 tests).
- Full-reference acceptance run: restored baseline (6.94%, 613 identities,
  4.2%, 35 rallies / 15%, 120.6 s); the only failing assertion is RQ-01's 60%
  gate, as recorded.

## 5. Recommendation

Approve the reviewed change set and continue to the next Develop stage. Do not
claim Done: RQ-01 remains unmet, U6/U7 are outstanding, and the acceptance test
must stay red on the 60% gate until a follow-up (calibration accuracy, detection
gating, or stitching with sign-off) closes the gap.
