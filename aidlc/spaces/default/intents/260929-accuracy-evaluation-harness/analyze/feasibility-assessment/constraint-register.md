# Constraint Register

## Hard constraints

| ID | Constraint | Source |
| --- | --- | --- |
| HC-1 | Offline only; no network, no cloud. | Product principle, `docs/architecture.md` |
| HC-2 | Footage and real match artifacts never committed (`.gitignore` covers `matches/`, `*.match/`, `test-media/`). | intent C-1 |
| HC-3 | No schema change to shipped artifacts. | requirements C-2 |
| HC-4 | `unsafe` forbidden; workspace deps and lints; clippy `-D warnings`. | `core/AGENTS.md`, root `Cargo.toml` |
| HC-5 | No new third-party dependency. | Dependency changes must be reviewed (org memory) — none needed |
| HC-6 | Rust 1.80 MSRV (`workspace.package.rust-version`). | root `Cargo.toml` |

## Risks

| ID | Risk | L | I | Mitigation |
| --- | --- | --- | --- | --- |
| R-1 | Hand labels are inconsistent (where does a rally start: serve toss or contact?). | M | H | Label guide in `docs/` defines start = serve contact, end = shuttle dead; tolerance absorbs ±2 s. |
| R-2 | `c1` alone is one clip — numbers not representative. | H | M | Report n per metric; roadmap stays "partially open" until ≥5 clips. |
| R-3 | Older `player_tracks.json` has no `review` → no count. | L | L | Per-clip error, other metrics still scored. |
| R-4 | Metric definitions (confidently wrong) disagree with what the roadmap author meant. | M | M | Definitions written in the label guide and verification doc; easy to change in one module. |
| R-5 | `sportcut-storage` `RallySuggestions` fields change. | L | L | Eval reads via the storage type, so a change breaks compilation rather than silently. |
