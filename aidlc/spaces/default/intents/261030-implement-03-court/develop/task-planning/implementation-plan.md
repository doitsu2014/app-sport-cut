# Implementation Plan — Court Calibration (Feature 3)

Status: Develop / Task Planning
Intent: `261030-implement-03-court`
Date: 2026-10-30
Inputs: `requirements.md`, `technical-spec.md`, `unit-breakdown.md`.

## Approach

Implement the eight units in dependency order, one review-sized diff at a time.
U2 (geometry-driven outline and net) is the walking skeleton: it proves the
architecture end to end (engine geometry → host conversion → painted outline and
net) before the visual polish units. The documentation unit comes last so the
BRD records the implemented result, not the plan.

The change is presentation-only: no Rust, no protocol, no persistence, no
dependency. The engine already returns the geometry; the work is drawing it
faithfully and making the marking surface conform to the design contract.

## Conventions

- Flutter/Dart 3, Riverpod, `package:flutter_lints/flutter.yaml`.
- Design components in `app/lib/src/app/design/`; feature wiring in
  `app/lib/src/features/calibration/` and
  `app/lib/src/features/workspace/presentation/studio/`.
- Tokens and metrics come from the design layer; no raw hex or ad-hoc pixel
  constants in feature code (DS-1).
- `rustfmt`/`cargo` are untouched; no Rust file changes.
- Comments match the surrounding density; no drive-by edits.
- One commit per unit with a "why" first message.

## Commands

| Purpose | Command |
| --- | --- |
| Client static analysis | `cd app && flutter analyze` (or set `SPORTCUT_FLUTTER_BIN` to the directory containing `flutter` first) |
| No-Rust guard | `tools/check-no-rust-in-app.sh` |
| Layering (no manifest change expected, run once) | `tools/check-layering.sh` |
| Manual run | `tools/run-macos.sh` |
| Engine health (should be unaffected) | `cargo build --workspace --manifest-path core/Cargo.toml` |

Per the working agreement, the test suites are not run as the gate for ordinary
work; verification is `flutter analyze`, the guard, source review, and a manual
run. The two pre-existing `FilledButton` screen-test failures are recorded, not
repaired.

## Review strategy

- Code Review stage: review every diff against `requirements.md` and
  `technical-spec.md`, with the security findings S-1/S-2 checked explicitly
  (geometry guard, bounded dash loop).
- The review record cites each unit's acceptance evidence with file:line.
- Refactor stage: only if the review finds structural debt (expected: none; the
  change is small and follows existing patterns).

## Milestones

1. **Skeleton** — U1 + U2: geometry drawn from the engine, no net before
   projection, rejection clears.
2. **Surface** — U3 + U4 + U5 + U6: one instruction, bed/scrim, accent
   isolation, motion.
3. **Truth** — U7: BRD and protocol docs match HEAD.
4. **Evidence** — U8: analyze, guard, manual run, contrast calculation.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Shared `overlayBed` regression | U1 consumer scan; fall back to a calibration-local constant and record the deviation. |
| Painted geometry misaligned with drag coordinates | Reuse the host's aspect-fit box; verify a drag target sits under its handle in the manual run. |
| Contrast still weak over bright footage | Chalk lines + scrim range; record the calculation and tune the scrim. |
| Motion change leaks into other controls | Limit `easeStandard` to calibration and the named shared transitions; no global curve swap. |
| Scope creep into tests/engine | Units name exact files; `git diff -- core` empty; no test files touched. |

## Definition of done

- R-CAL-01…12 implemented or documented, each with its acceptance check.
- `flutter analyze` clean; `tools/check-no-rust-in-app.sh` passes.
- Manual run passes the default → drag → project → orient → reject → save →
  reload path.
- BRD 03, BRD 00 §3.3, and `protocol.md` match HEAD.
- No new dependency, no FFI, no durable client state, no network.
