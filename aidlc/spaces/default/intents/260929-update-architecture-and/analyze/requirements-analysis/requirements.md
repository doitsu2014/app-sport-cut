# Requirements — Update architecture and docs

Source: `analyze/intent-capture/intent-statement.md`.

| ID | Requirement | Acceptance criterion |
| --- | --- | --- |
| DOC-1 | `architecture.md` lists every engine crate under `core/crates/*` and `core/cli` with its actual responsibility. | Crate table matches `core/Cargo.toml` members; each row checked against the crate's `lib.rs`/`main.rs`. |
| DOC-2 | `architecture.md` describes the client: feature modules under `app/lib/src/features/*`, navigation (workspace / studio), and the bridge wrapper. | Every feature directory appears; route/navigation description matches `router.dart` and the workspace screens. |
| DOC-3 | `architecture.md` pipeline covers highlight ranking and serving-side suggestion as implemented. | Signals and ownership (engine vs app) match the code. |
| DOC-4 | `architecture.md` developer-scripts list matches `tools/*.sh`. | Each script in `tools/` named with its purpose. |
| DOC-5 | `data-storage-models.md` SQLite section matches the tables and columns created in code. | Each `CREATE TABLE` in `app/lib` is represented; no table documented that does not exist. |
| DOC-6 | `data-storage-models.md` match-directory layout and `ArtifactKind` list match `sportcut-storage`. | Checked against `match_dir.rs` / `manifest.rs`. |
| DOC-7 | `features-roadmap.md` phase statuses reflect HEAD. | Phases 3 and 4 status updated to match shipped highlight ranking, serving-side suggestion, confirmation UI. |
| DOC-8 | `external-dependencies.md` has one preamble, no dangling OpenSpec citations, and a row for every direct dependency present. | Direct deps from `app/pubspec.yaml` and `core/crates/*/Cargo.toml` all present; schema/rules/verdicts/checksums unchanged. |
| DOC-9 | No top-level doc cites a removed OpenSpec change name or path. | `grep -i openspec docs/*.md` and change-name grep return nothing. |

Non-functional: docs keep their existing tone and structure; changes are
edits, not rewrites.
