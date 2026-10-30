# API Contract Design — Stage Diary

## Interpretation

- 2026-10-30: Kept all new parameters (`onProgress`, `expectedBytes`, `fraction`)
  optional with defaults so every existing call site and test compiles without
  breaking changes.
