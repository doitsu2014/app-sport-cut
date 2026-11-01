# Release Validation Report — Player Tracking (Feature 04)

Status: Launch / Release Validation
Intent: `261031-implement-04-player`
Date: 2026-11-01
Inputs: `requirements.md`, `test-suite.md`, `deployment-runbook.md`.

## 1. Release candidate

- Base: `main` at `c1c398f`.
- Candidate: the **uncommitted working tree** on top of that commit (U1/U2/U4/U5
  plus the review fixes and the rally test refactor). The acceptance test and the
  intent records are untracked.
- No version bump: package version remains `0.1.0`.
- **The candidate is not a commit.** Release validation cannot certify an
  uncommitted tree; the first release condition is to review and commit it.

## 2. Full verification

| Check | Command | Result |
| --- | --- | --- |
| Engine fmt/clippy/tests/layering | `tools/verify-engine.sh` | Pass |
| Feature clippy | `cargo clippy -p sportcut-api --features macos-tflite-eval --all-targets -- -D warnings` | Pass |
| Client analysis | `cd app && flutter analyze` | No issues |
| Client screenshot suite | `flutter test test/screenshots/media_screens_test.dart` | 4/4 pass |
| Service release build | `tools/build-service.sh` | Pass, `macos-tflite-eval` |
| Acceptance (opt-in) | full `IMG_1308.MOV`, fixed corners | Runs; **fails RQ-01** |

Unit suites: vision 9, rally 6, API 3 — all pass. The full client suite has 40
pre-existing failures unrelated to this intent.

## 3. Requirement coverage

| Requirement | Status | Decision / owner |
| --- | --- | --- |
| RQ-01 Top-four ≥ 60% | **Fail** — 6.94% (1,504/21,672), 613 identities | Not shippable as complete; follow-up (calibration/detection/stitching). Owner: engineering. |
| RQ-02 Count floor | Pass — Unknown at 4.2% with evidence; `Four` gated at 60% | Accepted as a proposal, not an official count. |
| RQ-03 Spectator rejection | Pass — artifact scan | Accepted. |
| RQ-04 Compact filter | Pass — unit + artifact tests | Accepted. |
| RQ-05 Rally yield | Pass by count-fit — 35 rallies / 15%; no ground truth | Known limitation; label a subset before claiming accuracy. |
| RQ-06 Automation | Pass — fail-not-skip, full reference | Accepted. |
| RQ-07 Artifact contract | Pass — old-artifact/serde tests | Accepted. |
| RQ-08 Offline/ownership | Pass — layering/no-Rust/dependency scan | Accepted. |
| RQ-09 300 s | Pass — 84.1 s | Accepted. |
| RQ-10 Determinism | Pass at pure-function level; cross-hardware not claimed | Accepted with the stated scope. |
| RQ-11 Grid cap | Pass — unit test | Accepted. |
| RQ-12 Unit coverage | Partial — gap/resume and classification edges open | Recorded; follow-up. |

## 4. Operational readiness

- **Health/readiness:** service feature marker, `service.hello`, track artifact
  with `review.fragmentation`, “Count quality” label, validated rally set.
- **Rollback:** reinstall the previous bundle; no catalog migration (client v5,
  no new durable client state). Documented, **not exercised live**.
- **Alerts/on-call:** not applicable — a local, offline desktop app has no server
  or paging surface. The analogous signal is the acceptance measurement and the
  in-app error surfaces.
- **Data:** recordings and artifacts stay local; no network path added.

## 5. Release decision

**No-go for release.** The implementation is verified and the default gate is
green, but three release conditions are unmet:

1. **RQ-01 is a Must requirement and fails** (6.94% vs 60%). It is not a tunable
   cosmetic gap; the association hypothesis was tested and rejected, and the
   follow-up is unscoped.
2. **Licensing is unresolved (C-02/C-21):** the EfficientDet verdict is
   contradictory and U6's embed guard does not exist. A release bundle cannot be
   built safely.
3. **Evidence is uncommitted (K-07):** the acceptance test and intent records are
   untracked, and U7 (BRD/protocol evidence) is not updated.

A **merge with known issues** is defensible only if the human explicitly accepts
RQ-01 as an open Must with an owner and a follow-up, and only after the changes
are committed and reviewed. That is a development decision, not a release.

## 6. Conditions to release

- Resolve or formally rescope RQ-01, with a measured follow-up.
- Reconcile the EfficientDet verdict and land the U6 embed guard.
- Complete U7 (BRD 04/05 and protocol evidence) and commit the acceptance test
  and records.
- Re-run this validation on the committed candidate and a packaged bundle
  (packaging was not re-run in this intent).
- Exercise rollback once in a signed bundle.

## 7. Recommendation to the human gate

Recommend **no-go** for release; recommend **approve the implementation for
merge with known issues** only if RQ-01 is explicitly accepted as an open Must
and the commit/review conditions are met. The model recommends; the human
decides.
