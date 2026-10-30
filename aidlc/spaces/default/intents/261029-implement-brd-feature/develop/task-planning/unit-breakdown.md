# Unit Breakdown — Workspace and Library gaps

Intent: `261029-implement-brd-feature`

## U1 — Status-bar stage label (FR-LIB-20 / FR-SHL-14)

- **Files:** `domain/pipeline_stage.dart`, `studio/stage_strip.dart`,
  `studio/studio_status_bar.dart`, `studio/studio_shell.dart`.
- **Done when:** the status bar ends with `· <stage>` for the selected stage;
  Play reads `Play`; the stage strip renders unchanged.
- **Verification:** `flutter analyze`; select each stage and read the bar.
- **Risk:** a label long enough to clip at 200% — mitigated by the short
  vocabulary.

## U2 — Home loading indicator (FR-LIB-05)

- **Files:** `workspace_screen.dart`.
- **Done when:** the loading branch renders `ScProgressJob` labeled
  "Reading workspaces" and no empty-state copy.
- **Verification:** `flutter analyze`; open the app against a slow catalog.

## U3 — Home error reason (FR-LIB-06)

- **Files:** `workspace_screen.dart`.
- **Done when:** a failed read renders the failure sentence plus the reason and
  a Retry action.
- **Verification:** `flutter analyze`; force an error in a debug build.

## U4 — Next-remaining selection after delete (FR-LIB-24)

- **Files:** `workspace_studio_screen.dart`.
- **Done when:** with three videos and the middle selected, deleting it selects
  the third; deleting the last selects the second; deleting the only video
  shows the empty studio.
- **Verification:** `flutter analyze`; manual delete sequence.
- **Risk:** async gap — guard every post-await access with `mounted`.

## U5 — Documentation reconciliation

- **Files:** `docs/brd/01-workspace-and-library.md`,
  `docs/brd/00-product-context.md`.
- **Done when:** §2.3 rows and the §3.3 status row match the implemented state.
- **Verification:** read the diff.
