# Source Changes

| Unit | File | Change |
| --- | --- | --- |
| U1 | `docs/architecture.md` | Updated system diagram; engine-crate table corrected (score, highlight, cli); new facade-surface table; new client-module table and navigation (workspace studio, feature rail, routes); pipeline steps 5–7 describe suggestion review, serving sides, and the ranking formula; scripts table adds `embed-engine-lib.sh`, `fetch-inference-assets.sh`, `embed-inference-assets.sh`. |
| U2 | `docs/data-storage-models.md` | Catalog section rewritten to the v5 schema (workspaces, export_settings, rally_suggestion_decisions, added columns, default workspace migration); ranking/serving not persisted; match-dir file names and full `ArtifactKind` list. |
| U3 | `docs/features-roadmap.md` | Phase 3 Done, Phase 4 Partially done; workspace note; OpenSpec change names replaced with verification-record paths; v1 list adds serving side and score context. |
| U4 | `docs/external-dependencies.md` | Duplicate preamble and duplicate "every crate" rule removed; OpenSpec citations replaced; truncated ffmpeg note fixed; model row clarified. Schema, rules, verdicts, checksums unchanged. |

Requirements covered: DOC-1 … DOC-9.
