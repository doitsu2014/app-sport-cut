# Architecture — Accuracy evaluation harness

## Context

```text
 match dir (outside repo)                 labels (outside repo, or fixture)
 ├─ tracks/player_tracks.json  ─┐         ├─ manifest.json
 └─ tracks/rally_suggestions.json ┐       └─ <clip>.labels.json
                                  │ │              │
                  ┌───────────────▼─▼──────────────▼───────┐
                  │ cli: `sportcut eval`  (file I/O, args)  │
                  │   reads JSON → typed values             │
                  └───────────────┬─────────────────────────┘
                                  │ ClipInputs (in-memory)
                  ┌───────────────▼─────────────────────────┐
                  │ sportcut-eval (pure)                    │
                  │   labels ─ validate                     │
                  │   predict ─ stored timeline | replay ───┼──▶ sportcut_rally::segment
                  │   metrics ─ count, boundaries, wrong, IoU│
                  │   report  ─ aggregate, targets, table   │
                  └───────────────┬─────────────────────────┘
                                  ▼
                      stdout: table | JSON report
```

## Components

| Component | Responsibility | Depends on |
| --- | --- | --- |
| `sportcut-eval::labels` | `ClipLabels`, `Manifest` types; `validate()` (FR-1, FR-2, FR-10). | serde, `sportcut-common` (error type) |
| `sportcut-eval::predict` | `TrackView`; extract predicted count; rally spans from `Vec<ClassifiedSpan>`; optional replay with a `SegmentationConfig` (FR-3, FR-9). | `sportcut-vision`, `sportcut-rally` |
| `sportcut-eval::metrics` | Pure functions over `[Span]` pairs: boundary matching, missed/spurious, confidently-wrong, IoU (FR-4..FR-6). | none |
| `sportcut-eval::report` | `ClipReport`, `EvalReport`, aggregation, targets, `render_table` (FR-7, NFR-1). | serde |
| `cli` `eval` subcommand | Parse args, resolve manifest-relative paths, read files, map read failures to per-clip errors, print, exit codes (FR-8). | `sportcut-eval`, `sportcut-storage` (`RallySuggestions`), `sportcut-rally` |

## Data flow per clip

1. CLI reads labels → `ClipLabels::validate()`.
2. CLI reads `player_tracks.json` → `TrackView`, and `rally_suggestions.json` →
   `RallySuggestions` (only when not replaying).
3. `sportcut-eval::score_clip(labels, track_view, prediction_source, tolerance)`
   → `ClipReport` (or `ClipReport{status: Error(msg)}`).
4. `sportcut-eval::aggregate(Vec<ClipReport>, targets)` → `EvalReport`.

## Security review

- Local files only; no network, no subprocess, no model loading.
- Manifest paths are resolved relative to the manifest directory. Absolute paths
  are allowed (the footage lives outside the repo by design). The tool runs with
  the user's own permissions on the user's own files, so path traversal is not a
  trust boundary.
- JSON parsing uses serde with typed structs. Very large inputs could exhaust
  memory, but the inputs are the user's own artifacts (about 10 MB today).
- No secrets are involved. Labels contain only timestamps, counts and free-text
  notes; the label guide warns against putting personal names in `notes`.

## Non-goals

No app, bridge or FFI surface. No persistence of reports; the user redirects
stdout if they want a file.
