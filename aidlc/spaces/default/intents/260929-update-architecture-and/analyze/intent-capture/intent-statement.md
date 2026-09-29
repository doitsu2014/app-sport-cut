# Intent Statement — Update architecture and docs

## Problem

`docs/` describes Sportcut as of an earlier feature wave. Since then the code
gained highlight ranking, serving-side suggestion, workspace management and a
grouped workspace studio, and the OpenSpec workflow was removed. The docs still
cite OpenSpec change names as the source of truth and report roadmap phases 3–4
as not done.

## Users

Developers and coding agents who read `docs/` to understand the system before
changing it.

## Success criteria

1. Every factual claim in the four top-level docs matches the code at HEAD
   (crates, app features, navigation, SQLite tables, artifact layout, scripts,
   dependencies, roadmap status).
2. No reference to a removed OpenSpec change name or `openspec/` path remains
   in the top-level docs.
3. `external-dependencies.md` keeps its schema, rules, verdicts and checksums;
   it gains rows only for dependencies actually present and loses its
   duplicated preamble.

## In scope

`docs/architecture.md`, `docs/data-storage-models.md`,
`docs/external-dependencies.md`, `docs/features-roadmap.md`.

## Out of scope

`docs/verification/**` (historical records), `README.md`, `AGENTS.md`,
per-track notes, code changes.

## Constraints

- Offline-only, semi-automatic, macOS-only principles are unchanged.
- Documentation only; no code, build, or dependency changes.

## Assumptions

- The code at HEAD on `main` is the truth when docs and code disagree.
