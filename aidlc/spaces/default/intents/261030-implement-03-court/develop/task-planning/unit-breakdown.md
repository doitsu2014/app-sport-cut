# Unit Breakdown — Court Calibration (Feature 3)

Status: Develop / Task Planning
Intent: `261030-implement-03-court`
Date: 2026-10-30
Spec: `ideate/technical-spec/technical-spec.md`

Each unit is a review-sized vertical slice with its own acceptance criterion.
Sizes are relative (S ≤ half day, M ≤ one day).

## U1 — Motion and metric tokens

- **Requirements:** R-CAL-08 (foundation).
- **Acceptance:** `SportcutTokens` exposes `easeStandard = Cubic(0.2, 0.0, 0.0,
  1.0)` and the scrim values; `ScMetrics` exposes `hairline = 1` and
  `handleBorder = 2`; the consumer scan for `overlayBed`/`ScOverlayColors.bed` is
  recorded and the shared value is corrected to `#0A0F0C` unless a consumer
  depends on `#050806`.
- **Files:** `app/lib/src/app/design/sportcut_tokens.dart`,
  `app/lib/src/app/design/sc_metrics.dart`,
  `app/lib/src/app/design/sc_overlay_colors.dart` (consumer scan across
  `app/lib`).
- **Dependencies:** none.
- **Size:** S.

## U2 — Geometry-driven outline and net (walking skeleton)

- **Requirements:** R-CAL-01, R-CAL-02, R-CAL-03, R-CAL-04.
- **Acceptance:** `ScCourtGeometry` exists; the overlay paints the engine outline
  and dashed net from it; `geometry == null` paints neither; `_netEndpoints` is
  deleted; malformed geometry paints nothing and does not throw; the host
  converts the DTO and passes it; a valid projection after a rejection paints
  again.
- **Files:** `app/lib/src/app/design/components/sc_calibration_overlay.dart`,
  `app/lib/src/features/calibration/presentation/calibration_overlay_host.dart`.
- **Dependencies:** U1 (for `hairline`; can start in parallel with a local
  constant and switch).
- **Size:** M. This is the thinnest end-to-end slice that proves the design: one
  frame in, engine geometry out, painted.

## U3 — One plain instruction line

- **Requirements:** R-CAL-05.
- **Acceptance:** The overlay instruction is plain text (no `DecoratedBox`/
  border) at `xs12`+, names the projected net; the panel's instruction paragraph
  and `_cornerHints` are removed; each handle carries `Corner n: <name>`
  semantics; the non-projected progress copy is a prompt.
- **Files:** `sc_calibration_overlay.dart`, `calibration_panel.dart`.
- **Dependencies:** U2 (shared overlay edit).
- **Size:** S.

## U4 — Fixed bed, scrim, and contrast

- **Requirements:** R-CAL-06.
- **Acceptance:** The overlay paints the fixed `#0A0F0C` bed and a 32-56 %
  scrim beneath the markings; essential lines use chalk `#F2F5F0`; the recorded
  contrast calculation shows ≥3:1 for graphics and ≥4.5:1 for text in both
  themes; the chosen scrim value is documented.
- **Files:** `sc_calibration_overlay.dart`, `sportcut_tokens.dart` (scrim),
  `sportcut_tokens.dart`/`sc_overlay_colors.dart` (bed, from U1).
- **Dependencies:** U1, U2.
- **Size:** S-M (tuning).

## U5 — Accent isolation during calibration

- **Requirements:** R-CAL-07.
- **Acceptance:** `ScTransport` accepts `accent` (default true); the calibrate
  stage passes false; the play control and scrub fill/thumb render neutral while
  staying enabled; a drag shows exactly one accent element (the dragged handle).
- **Files:** `app/lib/src/app/design/components/sc_transport.dart`,
  `app/lib/src/features/workspace/presentation/studio/video_preview.dart`,
  `app/lib/src/features/workspace/presentation/studio/preview_pane.dart`,
  `app/lib/src/features/calibration/presentation/calibration_view.dart`.
- **Dependencies:** U1.
- **Size:** M.

## U6 — Calibration motion

- **Requirements:** R-CAL-09.
- **Acceptance:** Handle fill/border and net changes animate at 120/180 ms with
  `easeStandard`; reduced motion collapses them to zero; no animation loops.
- **Files:** `sc_calibration_overlay.dart`.
- **Dependencies:** U1, U2.
- **Size:** S.

## U7 — Documentation reconciliation

- **Requirements:** R-CAL-10, R-CAL-11, R-CAL-12.
- **Acceptance:** BRD 03 §1/§2.3/§4/§5/§7/§10 and BRD 00 §3.3 row 3 match the
  verified HEAD state; §4 describes the real Cancel control; the evidence table
  records the absent verification record and stale tests; `protocol.md` corrects
  the one-step save, the §6.3/§6.2 cross-references, and the token-shaped
  example.
- **Files:** `docs/brd/03-court-calibration.md`, `docs/brd/00-product-context.md`,
  `docs/architecture/protocol.md`.
- **Dependencies:** U2-U6 (statuses must reflect the implemented result).
- **Size:** M.

## U8 — Verification and evidence

- **Requirements:** NR-CAL-01…06; all R-CAL acceptance checks.
- **Acceptance:** `flutter analyze` clean; `tools/check-no-rust-in-app.sh`
  passes; `git diff -- core` empty; a manual run exercises default, drag,
  projection, orientation, rejection, save, and reload; the contrast
  calculation is recorded in the code-review record.
- **Files:** none (evidence only).
- **Dependencies:** U1-U7.
- **Size:** S.

## Dependency graph

```text
U1 ──► U2 ──► U3
 │      ├──► U4
 │      └──► U6
 └──────────► U5
U2..U6 ──► U7 ──► U8
```

## Critical path and risk

- **Critical path:** U1 → U2 → U4 → U7 → U8.
- **Risk first:** U1's `overlayBed` consumer scan (FR-01) and U2's box alignment
  (FR-04) are the two unknowns; both land early.
- **Independent after U1:** U5 can proceed in parallel with U2-U4.

## Explicit follow-ups (not units)

- Repair the two stale `FilledButton` screen-test lookups (needs a user request
  under `CLAUDE.md`).
- Recreate a real verification record with a labeled clip (out of scope).
- ADR-0001 Phase 3-4 service catalog and release-service `matchDir` resolution.
