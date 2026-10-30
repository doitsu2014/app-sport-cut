# CI Pipeline — Stage Diary

## Interpretation

- 2026-10-29: Read this ALWAYS stage as "define the pipeline for this change",
  not "create repository CI". A ci-config.md recommendation records the build
  contract; no workflow file is invented.

## Deviation

- 2026-10-29: Did not add `.github/workflows/`. Adding CI is an infrastructure
  decision outside feature 1's scope and would widen the diff.

## Open question

- 2026-10-29: Whether the project wants GitHub Actions at all, and on which
  runner image, is undecided.
