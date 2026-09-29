# Design Decisions

| ID | Force | Decision | Rejected | Consequence |
| --- | --- | --- | --- | --- |
| DD-1 | Testability, determinism | **Functional core, imperative shell.** `sportcut-eval` is pure (values in, values out); the CLI does all I/O. | Scorer reading files itself | Metrics unit-tested without tempdirs; CLI stays thin. |
| DD-2 | Engine types may evolve | **Read models (views)** over shipped artifacts: `TrackView` deserialises only the fields needed, using the engine's own types. | Copying types; depending on `sportcut-api` | Schema drift breaks compilation, not silently; no heavy dependency. |
| DD-3 | One bad clip must not hide others | **Per-item result, not early return.** `ClipReport.status = Scored{..} \| Error{message}`; aggregate excludes errors and lists them. | `Result` bubbling from the batch | Partial reports remain useful while labeling is in progress. |
| DD-4 | Boundary matching must be deterministic and fair | **Sorted two-pointer maximum matching**: each label, in order, takes the earliest unused prediction inside its ±tolerance window. *(Amended after code review: closest-pair-first under-counted, e.g. labels [0,1000] vs predictions [600,1500] at 600 ms.)* | Closest-pair-first greedy; Hungarian assignment | Optimal for equal-width windows in 1-D, O(n+m), deterministic. |
| DD-5 | Rates must reflect the whole dataset | **Micro-averaging** (sum hits / sum labeled across clips) for aggregate rates. | Mean of per-clip rates | Long clips weigh more — matches "85% of boundaries". |
| DD-6 | Stable, diff-able output | **Integer ms throughout; floats only at the report edge**, rounded to 4 dp; clips sorted by id; `BTreeMap`/`Vec`, no `HashMap` in output. | f64 seconds | Byte-identical re-runs (NFR-1). |
| DD-7 | Typos in hand-written labels | **Strict parsing**: `deny_unknown_fields`, explicit `schema_version`. | Lenient parsing | Labeler gets an immediate named error. |
| DD-8 | Targets change as the product matures | **Targets as data** (`Target{name, threshold, comparator}`) with defaults from the roadmap in one `const` table. | Hardcoded `if` checks in rendering | One place to change thresholds; report shows them. |

Aligned with existing crate idioms: `sportcut_common::Result`/`SportcutError::InvalidInput`
for validation errors; `validate()` methods as in `SegmentationConfig`; `#![forbid(unsafe_code)]`.
