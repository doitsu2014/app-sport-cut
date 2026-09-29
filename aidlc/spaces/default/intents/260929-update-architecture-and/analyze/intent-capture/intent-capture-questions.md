# Intent Capture Questions

Intent: `260929-update-architecture-and`
Request: "Update Architecture, Documents in folder @docs"
Mode: yolo — recommended answers auto-selected and recorded below.

### Q1: What problem does this solve, and for whom?

A. The `docs/` set has drifted from the code after the last feature wave
   (highlight ranking, serving-side suggestion, workspace studio) and the
   removal of OpenSpec; developers and agents read stale architecture.
   *(Recommended)*
X. Other

[Answer]: A (auto-selected)

### Q2: Which files are in scope?

A. The four top-level files in `docs/`: `architecture.md`,
   `data-storage-models.md`, `external-dependencies.md`, `features-roadmap.md`.
   `docs/verification/` records are historical evidence — out of scope except
   that nothing in the top-level docs may depend on removed OpenSpec paths.
   *(Recommended)*
B. A + `docs/verification/`
C. A + root `README.md` / `AGENTS.md`

[Answer]: A (auto-selected)

### Q3: What does success look like, observably?

A. Every factual claim in the four docs (crates, app features, routes, tables,
   artifact layout, scripts, dependencies, roadmap status) matches the code at
   HEAD, checked claim-by-claim; no dangling references to removed OpenSpec
   change names or paths. *(Recommended)*

[Answer]: A (auto-selected)

### Q4: What must NOT change?

A. Product principles (offline-only, semi-automatic, macOS-only), the
   dependency register's schema, rules and existing verdicts, and pinned
   checksums. *(Recommended)*

[Answer]: A (auto-selected)

### Q5: Deadline / cost of doing nothing?

A. No deadline; stale docs mislead future changes. *(Recommended)*

[Answer]: A (auto-selected)
