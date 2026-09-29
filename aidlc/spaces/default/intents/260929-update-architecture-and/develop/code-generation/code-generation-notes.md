# Code Generation Notes

## Verification run

- `grep -i openspec|<former change names> docs/*.md` → no matches (DOC-9).
- Register versions cross-checked against `core/Cargo.lock` (serde, serde_json,
  thiserror 1/2, anyhow, clap, tempfile, tokio, libloading, image) and
  `app/pubspec.lock` (file_picker, flutter_riverpod, riverpod, mime, path,
  path_provider, share_plus, sqflite, video_player) — all match. No direct
  dependency missing from the register (DOC-8).
- Script conventions checked: `preflight.sh` uses `set -u` only and does not
  use `BASH_SOURCE`; doc wording corrected accordingly.
- Serving side checked in `score_view.dart`: displayed on the scoreboard, not
  auto-filled as the winner. Docs describe the display only.

## Deviations

- None from the plan. `docs/verification/**` untouched; four records there still
  link to removed `openspec/changes/...` paths (historical, out of scope).

## Found outside scope (not changed)

- `core/crates/vision/src/lib.rs:3` doc comment: "No inference ships in the
  bootstrap change" — stale.
- `core/crates/score` doc comment says it proposes the server as a tentative
  winner; the app only displays the server.
- `README.md` Status section and `AGENTS.md:35,37` describe the pre-workspace
  app and omit three `tools/` scripts.
