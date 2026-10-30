# Technical Specification — Stage Diary

## Interpretation

- 2026-10-30: Ran a four-agent ground-truth survey (custody flow, import UI,
  analysis UI, BRD docs) against HEAD `d33d123` before drafting; signatures in
  the spec are copied from source, not from the plan documents.
- Key findings baked into the spec: `StudioShell`/`VideoRail`/`ScProgressJob`
  already accept the fraction (only two call sites lack it);
  `FakeMatchLibrary` must gain the optional `onProgress` to keep implementing
  `MatchLibrary`; test fakes report `sizeBytes: 1024` for a 4 MiB fixture so
  the fraction must clamp; `ScStatus` cannot express `PARTIAL`/`MISSING`, so
  `_ArtifactRow` renders a local badge per DD-3; empty `notRebuildableKinds`
  in fakes keeps existing rebuild-label assertions green.
- Work breakdown seeded as U0 (commit the unrelated protocol_client AF_UNIX
  fix separately) → U1 (G1 data/domain) → U2 (G1 presentation); U3 (G2), U4
  (G3) independent; U5 (G4 docs) last; V = `flutter analyze` +
  `tools/check-no-rust-in-app.sh` per unit.

## Adversarial verification (2 lenses: source correctness, completeness)

- 2026-10-30: Two verifier agents attacked the draft; 2 major + 9 minor
  findings, all folded in:
  - **major** — `onProgress` is a new throw source inside the copy loop;
    `takeCustody` cleanup broadened to `on Object` + `remove(matchId)` +
    rethrow so nothing strands the recording dir/.part (FR-IMP-09/BR-2).
  - **major** — `analysis_screen_test.dart` and `library_screen_test.dart`
    already fail at baseline (ScSectionHeader uppercases labels, ScButton is
    not a FilledButton, "No matches yet" removed); spec no longer cites them
    as green evidence, only as compile-compatibility, and does not repair
    them (working agreement).
  - Fixed bogus symbols (`SportcutError::InvalidMedia` → `SportcutError::Probe`;
    `ArtifactManifest::record_final` → `record_artifact`), line ref
    (workspace_screen.dart:77), broken §3.x→§2.x cross-references, undefined
    `clampedFraction` (fraction vs percent now both defined), 102-vs-DD-1's-101
    cap (post-flush `1.0` suppressed when percent already 100), NFR-2
    once-per-second cadence recorded as a remaining gap (no timer — DD-1),
    FR-IMP-29 Must acceptance text kept untouched (rally_suggestions mapping
    lives in spec §2.6 + BRD status text only), split FR-IMP-16..24 into
    per-ID rows, added dependencies/configuration per component, added
    check-no-rust-in-app.sh to V, NFR-7 test clause explicitly waived.
