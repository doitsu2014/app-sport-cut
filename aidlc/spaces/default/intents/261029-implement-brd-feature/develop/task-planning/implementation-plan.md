# Implementation Plan — Workspace and Library gaps

Status: Develop / Task Planning
Intent: `261029-implement-brd-feature`
Consumes: `technical-spec.md`, `requirements.md`

## Sequence

| Order | Unit | Gap | Files | Depends on |
| --- | --- | --- | --- | --- |
| 1 | U1 | G1 | `pipeline_stage.dart`, `stage_strip.dart`, `studio_status_bar.dart`, `studio_shell.dart` | — |
| 2 | U2 | G2 | `workspace_screen.dart` | — |
| 3 | U3 | G3 | `workspace_screen.dart` | — |
| 4 | U4 | G4 | `workspace_studio_screen.dart` | — |
| 5 | Verify | — | — | U1–U4 |

U2 and U3 touch the same file and can land as one edit; they remain separate
units because they satisfy different requirements.

## Working agreement

- Implementation first: no new test files, no new test cases (Q3-A).
- Do not touch existing tests unless a change stops them compiling.
- Verify with `flutter analyze` (or `SPORTCUT_FLUTTER_BIN`) and
  `tools/check-no-rust-in-app.sh`.
- Update `docs/brd/01-workspace-and-library.md` §2.3 and `00-product-context.md`
  §3.3 as the last edit, per Q4-A.

## Exit criteria

1. Every line in the technical spec's change table is applied.
2. `flutter analyze` is clean (or the toolchain gap is reported, not hidden).
3. The BRD status rows match the implemented state.
4. No protocol, bridge, schema, or dependency change appears in the diff.
