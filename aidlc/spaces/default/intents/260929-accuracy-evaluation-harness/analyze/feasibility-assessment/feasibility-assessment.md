# Feasibility Assessment

No research report was produced for this intent. The code map from requirements
analysis is enough, because the work reuses existing engine types.

## Technical feasibility

| Req | Verdict | Basis |
| --- | --- | --- |
| FR-1, FR-2 label + manifest | Feasible, trivial | serde/serde_json already workspace deps. |
| FR-3 count | Feasible | `TrackingResult.count: CountAssessment{count: ObservedCount}` is in `review` of `player_tracks.json` (`crates/vision/src/tracking.rs:134,147`). `review` is `Option` — older artifacts lack it → clip error, not panic. |
| FR-4..FR-7 metrics | Feasible | `RallySuggestions.timeline: Vec<ClassifiedSpan>` covers `[0, duration)` in half-open ms spans (`crates/storage/src/rally_suggestions.rs:82`). Rally spans = consecutive `SpanKind::Rally`; boundaries are their ends. Pure integer arithmetic. |
| FR-8 CLI | Feasible | clap-derive CLI with `--json` convention exists (`cli/src/main.rs:23,488`). CLI already depends on `storage`; add `eval`, `rally`, `vision`. |
| FR-9 replay | Feasible | `sportcut_rally::segment(&SegmentationInput, &SegmentationConfig)` is pure (`crates/rally/src/lib.rs:175`); `SegmentationConfig` is serde. |
| Reading `player_tracks.json` without `sportcut-api` | Feasible | `TrackArtifact` lives in `api` (heavy: bridge, export, jobs). Eval deserialises a minimal view `{schema_version, input, review}`; serde ignores `provenance`. Avoids the dependency. |
| `rally_suggestions.json` loading | Feasible | `sportcut-storage` exposes the type; its private `validate()` is not needed — eval reads the struct via serde directly. |

No spikes needed.

## Cost, schedule

About 1–1.5 days of engineering: scorer crate (~0.5 d), CLI (~0.25 d), tests and
fixture (~0.25 d), docs and first `c1` run (~0.25 d, not counting labeling).
Labeling `c1` (~9 min, ~35 rallies) takes about 30–45 min of owner time.

## Risks

See `constraint-register.md` (R-1..R-5).

## Recommendation

**Proceed.** All requirements are feasible with existing dependencies. The main
risk is the quality of the labels, not the code.
