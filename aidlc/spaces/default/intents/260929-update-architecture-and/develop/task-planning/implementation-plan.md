# Implementation Plan

1. **Fact sweep** — collect, with file:line references, the current crates,
   facade functions, app features and navigation, SQLite schema, match
   directory layout, tools scripts, direct dependencies, and remaining OpenSpec
   references.
2. **U1–U4** — edit each doc in place against the fact sweep. Preserve tone,
   headings, and the register schema. Replace OpenSpec change-name citations
   with plain feature descriptions.
3. **U5 verify** — grep for `openspec` and former change names in `docs/*.md`;
   re-check each new claim against the cited source; confirm every direct
   dependency has a register row.

No code, build config, or dependency is touched. Verification is by grep and
source cross-check; there is no doc build to run.
