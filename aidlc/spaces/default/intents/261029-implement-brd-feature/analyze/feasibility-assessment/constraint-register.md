# Constraint Register — Workspace and Library gaps

Intent: `261029-implement-brd-feature`

## Hard constraints (non-negotiable)

| ID | Constraint | Source | Effect on this intent |
| --- | --- | --- | --- |
| C1 | Everything runs offline; no network, telemetry, or online API in product code. | BR-1, NFR-1, CLAUDE.md | No new remote call, font, or asset fetch. |
| C2 | Design-system tokens are the single source of colour, type, spacing, radius, elevation, and motion; no raw hex outside the token layer. | BR-8, DS-1 | New text and indicators use `SportcutPalette`, `SportcutTypography`, `SportcutTokens`. |
| C3 | The app reaches the engine only through `sportcut_engine.dart`; no socket is opened in feature code. | NFR-9, CLAUDE.md | G1–G4 make no engine call. |
| C4 | No Rust, FFI, generated bindings, or dylib in the Flutter app. | NFR-9, `tools/check-no-rust-in-app.sh` | Client-only change; the guard must still pass. |
| C5 | No new durable client-owned state. | CLAUDE.md, ADR-0003 D10 | The stage label reads existing state; no persistence is added. |
| C6 | Every third-party dependency, model, asset, and codec gets a licensing-register row before the change completes. | BR-10, CLAUDE.md | No dependency is added, so no row is needed. |
| C7 | New test files are not written unless the user asks; stale tests are touched only when a change stops them compiling. | CLAUDE.md working agreement, Q3-A | Verification is `flutter analyze`, not `flutter test`. |
| C8 | English-only copy; verb-first, factual, no exclamation marks. | NFR-12, DS-10 | New strings follow the existing voice. |
| C9 | Accessibility floors: contrast, focus ring, named icon controls, 44 px hit targets, 200% text scaling without clipping. | BR-9, DS-15 | The status-bar stage label must not clip at 200%. |
| C10 | macOS focus in v1; one adaptive macOS application. | BR-12 | No mobile or web branch. |

## Soft constraints

| ID | Constraint | Source | Effect |
| --- | --- | --- | --- |
| S1 | The ASTDLC/graph tooling and AIDLC state are engine-owned; never hand-edit `aidlc/state.json`. | AIDLC stage protocol | Reports go through `my-aidlc orchestrate report`. |
| S2 | `flutter analyze` must be clean. | CLAUDE.md | Run it before declaring done. |
| S3 | Keep the studio composition root small. | ADR-0003 consequences | Compose the stage label in `studio_shell.dart`, not inside `workspace_studio_screen.dart`. |

## Assumptions

- The Flutter toolchain is available at verification time; if not, the gap is
  reported.
- The four gaps are independent enough to land in one change.
