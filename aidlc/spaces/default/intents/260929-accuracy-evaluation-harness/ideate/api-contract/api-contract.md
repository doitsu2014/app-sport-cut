# API Contract — Accuracy evaluation harness

## 1. CLI

```text
sportcut eval --manifest <manifest.json> [options]
sportcut eval --labels <clip.labels.json> --match-dir <dir> [options]

options:
  --tolerance-ms <ms>       boundary tolerance, default 2000, must be >= 0
  --rally-config <json>     replay segmentation with this SegmentationConfig
  --json                    print the EvalReport as pretty JSON
  --fail-on-target          exit 3 if any target fails
```

`--manifest` and `--labels` are mutually exclusive, and `--match-dir` requires
`--labels`.

| Exit | Meaning |
| --- | --- |
| 0 | Scoring ran. Individual clips may still be in `error`. |
| 1 | Usage error, an unreadable or invalid manifest/labels file (single-clip mode), or an invalid `--rally-config`. |
| 2 | Command-line usage error (clap default). |
| 3 | `--fail-on-target` is set and a target failed, or no clip could be scored. |

In manifest mode, a clip whose files can't be read or parsed becomes an
`error` clip. The run continues with the other clips.

## 2. Label file v1 (`*.labels.json`)

```json
{
  "schema_version": 1,
  "clip_id": "c1",
  "duration_ms": 544000,
  "players": 4,
  "clean": false,
  "rallies": [
    { "start_ms": 12500, "end_ms": 18200 },
    { "start_ms": 31000, "end_ms": 39750 }
  ],
  "notes": "off-angle, fixed camera"
}
```

Rules:
- `players` must be 2 or 4.
- Each rally must satisfy `0 <= start_ms < end_ms <= duration_ms`.
- Rallies must be sorted and must not overlap. Touching (`end == next start`)
  is allowed.
- `clip_id` must be non-empty.
- Unknown fields are rejected (`deny_unknown_fields`) so typos surface.
- A rally starts at serve contact and ends when the shuttle is dead.

## 3. Manifest v1

```json
{
  "schema_version": 1,
  "clips": [
    { "clip_id": "c1", "labels": "c1.labels.json", "match_dir": "/Users/me/Sportcut/matches/c1" }
  ]
}
```

Relative paths are resolved against the manifest's directory. A `clip_id` must
be unique in the manifest and must equal the `clip_id` inside its labels file.

## 4. Report JSON (`--json`)

```json
{
  "schema_version": 1,
  "tolerance_ms": 2000,
  "prediction_source": "stored",
  "clips": [
    {
      "clip_id": "c1",
      "status": "scored",
      "clean": false,
      "players": { "expected": 4, "predicted": "four", "correct": true },
      "boundaries": { "labeled": 70, "hit": 58, "hit_rate": 0.8286 },
      "rallies": { "labeled": 35, "predicted": 36, "missed": 1, "spurious": 2 },
      "confidently_wrong_rate": 0.0423,
      "rally_time": { "intersection_ms": 160000, "union_ms": 207470, "iou": 0.7712 }
    },
    { "clip_id": "c2", "status": "error", "error": "player_tracks.json: file not found" }
  ],
  "aggregate": {
    "scored_clips": 1,
    "error_clips": ["c2"],
    "player_count": { "correct": 1, "total": 1, "accuracy": 1.0,
                      "clean_correct": 0, "clean_total": 0, "clean_accuracy": null },
    "boundaries": { "labeled": 70, "hit": 58, "hit_rate": 0.8286 },
    "rallies": { "labeled": 35, "predicted": 36, "missed": 1, "spurious": 2 },
    "confidently_wrong_rate": 0.0423,
    "rally_time_iou": 0.7712,
    "targets": [
      { "name": "player_count_clean", "threshold": ">= 0.85", "value": null, "status": "no_data" },
      { "name": "boundary_hit_rate", "threshold": ">= 0.85", "value": 0.8286, "status": "fail" },
      { "name": "confidently_wrong_rate", "threshold": "<= 0.05", "value": 0.0423, "status": "pass" }
    ]
  }
}
```

- `prediction_source` is `"stored"`, or `{"replay": <SegmentationConfig>}`.
- Rates are rounded to 4 decimals at serialisation. `null` means the
  denominator was 0 (except for the confidently-wrong rate, which is 0 when
  both counts are 0).
- `predicted` uses the engine's `ObservedCount` spelling (`two`, `four`,
  `unknown`), or `null` when the artifact has no `review`.
- `status` is one of `pass`, `fail` or `no_data`.
- Clips are sorted by `clip_id`.

## 5. Rust library (`sportcut-eval`)

```rust
pub struct ClipLabels { schema_version, clip_id, duration_ms, players: u8, clean, rallies: Vec<LabeledRally>, notes: Option<String> }
impl ClipLabels { pub fn validate(&self) -> Result<()> }
pub struct Manifest { schema_version, clips: Vec<ManifestEntry> }
impl Manifest { pub fn validate(&self) -> Result<()> }

pub struct TrackView { schema_version: u32, input: SegmentationInput, review: Option<TrackingResult> }

pub enum Prediction<'a> { Stored(&'a [ClassifiedSpan]), Replay(SegmentationConfig) }
pub fn score_clip(labels: &ClipLabels, tracks: &TrackView, prediction: Prediction<'_>, tolerance_ms: i64) -> ClipReport
pub fn aggregate(clips: Vec<ClipReport>, tolerance_ms: i64, source: PredictionSource) -> EvalReport
pub fn render_table(report: &EvalReport) -> String

// metrics (pub for tests and later reuse)
pub fn rally_spans(timeline: &[ClassifiedSpan]) -> Vec<TimeSpan>
pub fn match_boundaries(labeled: &[i64], predicted: &[i64], tolerance_ms: i64) -> usize
pub fn overlap_counts(labeled: &[TimeSpan], predicted: &[TimeSpan]) -> (usize /*missed*/, usize /*spurious*/)
pub fn rally_time_iou(labeled: &[TimeSpan], predicted: &[TimeSpan]) -> f64
```

## Compatibility

- Label, manifest and report files each carry `schema_version: 1`. A breaking
  change bumps the version, and readers reject versions they don't know.
- Shipped artifacts are read-only. The eval code tolerates a missing `review`.
