# Technical Specification — Accuracy evaluation harness

## Requirement → component map

| Req | Component |
| --- | --- |
| FR-1, FR-2, FR-10 | `eval::labels` |
| FR-3, FR-9 | `eval::predict` |
| FR-4, FR-5, FR-6 | `eval::metrics` |
| FR-7, NFR-1 | `eval::report` |
| FR-8 | `cli` `Command::Eval` |

## Crate `core/crates/eval` (`sportcut-eval`)

`Cargo.toml`: workspace package fields and `[lints] workspace = true`.
Dependencies: `sportcut-common`, `sportcut-rally`, `sportcut-vision`, `serde`.
`serde_json` is a dev-dependency for the fixture test. Add
`sportcut-eval = { path = "crates/eval" }` to root `[workspace.dependencies]`.

### `labels.rs`

- `LABELS_SCHEMA_VERSION = 1`, `MANIFEST_SCHEMA_VERSION = 1`.
- `ClipLabels::validate` checks the rules in api-contract §2. It returns
  `SportcutError::InvalidInput("labels <clip_id>: <field> …")`.
- `Manifest::validate` checks: schema version, at least one clip, unique
  non-empty `clip_id`.

### `predict.rs`

- `TrackView { schema_version: u32, input: SegmentationInput, #[serde(default)] review: Option<TrackingResult> }`.
  Unknown fields are allowed here: it is a view of a larger artifact.
- `predicted_count(&TrackView) -> Option<ObservedCount>` returns
  `review.map(|r| r.count.count)`.
- `predicted_timeline(&TrackView, Prediction) -> Result<Vec<ClassifiedSpan>>`:
  - `Stored(spans)` returns the spans as given.
  - `Replay(cfg)` runs `cfg.validate()?` and then
    `sportcut_rally::segment(&view.input, &cfg)?.timeline`.

### `metrics.rs` (integer ms)

- `rally_spans(timeline)`: take the `SpanKind::Rally` spans in order and merge
  any that touch (`prev.end_ms == next.start_ms`).
- Boundaries: starts = `span.start_ms`, ends = `span.end_ms`. Starts and ends
  are matched separately and the hits are summed.
- `match_boundaries(labeled, predicted, tol)`:
  1. Build all pairs with `|l − p| ≤ tol`.
  2. Sort by `(distance, l, p)`.
  3. Walk greedily, taking a pair when neither side is used yet.
  4. Return the count.
  Two pointers bound the work to about O((n+m)·k).
- `overlaps(a, b)` is true when `min(a.end, b.end) − max(a.start, b.start) > 0`.
- `overlap_counts(labeled, predicted)`:
  - missed = labeled spans that overlap no predicted span;
  - spurious = predicted spans that overlap no labeled span;
  - computed with a sorted two-pointer sweep.
- `confidently_wrong_rate` = `(missed + spurious) / (labeled + predicted)`, or
  0.0 when the denominator is 0.
- `rally_time_iou`:
  - intersection = total overlap length between the two sorted disjoint span
    lists (two-pointer sweep);
  - union = Σ|labeled| + Σ|predicted| − intersection;
  - returns 1.0 when union = 0.

### `report.rs`

- `ClipReport { clip_id, clean: Option<bool>, outcome: ClipOutcome }`.
- `ClipOutcome = Scored(ClipMetrics) | Error { error: String }`.
  Serialised with `#[serde(tag = "status", rename_all = "snake_case")]` and
  flattened into the clip object, which gives the api-contract §4 shape.
- `ClipMetrics` holds raw counts plus `players { expected: u8, predicted: Option<ObservedCount>, correct: bool }`,
  `boundaries { labeled, hit }`, `rallies { labeled, predicted, missed, spurious }`
  and `rally_time { intersection_ms, union_ms }`.
- Rates are **derived at serialisation time** by a `Rate(Option<f64>)` newtype
  with a custom `Serialize` that rounds to 4 decimal places:
  `(x * 10_000.0).round() / 10_000.0`.
- `score_clip(labels, tracks, prediction, tol) -> ClipReport` never panics:
  - failed label validation → `Error`;
  - duration mismatch over 1000 ms → `Error`;
  - replay error → `Error`.
- `aggregate(clips, tol, source) -> EvalReport`:
  1. Sort clips by `clip_id`.
  2. Sum the counts over scored clips.
  3. Evaluate `DEFAULT_TARGETS`.
- `DEFAULT_TARGETS`:
  - `player_count_clean ≥ 0.85`
  - `boundary_hit_rate ≥ 0.85`
  - `confidently_wrong_rate ≤ 0.05`
  - Each target's status is `pass`, `fail`, or `no_data` when the value is
    `None`.
- `EvalReport::any_target_failed()` is true when any target fails or no clip
  was scored.
- `render_table(&EvalReport) -> String` produces fixed columns:

  ```text
  clip  clean  players(exp/pred)  boundary hit  missed  spurious  conf-wrong  IoU
  ```

  An aggregate row and a targets block follow. `format!` uses fixed precision
  (`{:.1}%`, `{:.3}`).

### `lib.rs`

Holds the module docs and `#![forbid(unsafe_code)]`, and re-exports the public
API from api-contract §5.

## CLI (`core/cli/src/main.rs`)

- Add `Command::Eval(EvalArgs)`.
- clap attributes:
  - `#[arg(long, conflicts_with = "labels")] manifest`;
  - `#[arg(long, requires = "match_dir")] labels`;
  - `#[arg(long, requires = "labels")] match_dir`;
  - `#[arg(long, default_value_t = 2000)] tolerance_ms: i64`, validated `>= 0`;
  - `rally_config: Option<PathBuf>`, `json: bool`, `fail_on_target: bool`.
- `load_clip(entry) -> ClipReport`:
  1. Read the labels, `player_tracks.json` and (when not replaying)
     `rally_suggestions.json`.
  2. Turn a read or parse error into `ClipReport::error(clip_id, "<file>: <err>")`.
  3. Check that the labels' `clip_id` equals the manifest `clip_id`.
- Single-clip mode: any read, parse or validation error prints to stderr and
  exits 1.
- Output: `print_json` (existing helper) or `print!("{}", render_table(..))`.
  Exit 3 when `--fail-on-target && report.any_target_failed()`.
- `cli/Cargo.toml` gains `sportcut-eval`, `sportcut-rally` and
  `sportcut-vision` (workspace).

## Cross-cutting

- Errors use `SportcutError::InvalidInput` and `Io{path}`, matching the
  existing crates.
- Determinism: no `HashMap` iteration in the output, sorted clips, fixed
  float formatting.
- Docs: `docs/verification/accuracy-evaluation.md` contains the label guide,
  metric definitions, how to run, and the first-run results table (filled once
  `c1` is labeled). The roadmap Phase 0 row links to it.

## Work breakdown seeds

1. U1 — crate skeleton, labels + manifest types and validation.
2. U2 — predict + metrics.
3. U3 — report, aggregate, targets, table.
4. U4 — CLI `eval` subcommand.
5. U5 — synthetic fixture + tests.
6. U6 — docs (label guide, verification record, roadmap link).
