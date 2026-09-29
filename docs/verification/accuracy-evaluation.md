# Accuracy evaluation

How to measure player-count and rally/rest segmentation accuracy against hand
labels, and the results recorded so far. This page is the evidence for the
Phase 0 and Phase 2 accuracy targets in `../features-roadmap.md`.

## What is measured

| Metric | Definition | Target |
| --- | --- | --- |
| Player count | Recording-level `ObservedCount` from `player_tracks.json` (`review.count.count`) equals the labeled `players`. `unknown`, or a missing `review`, counts as wrong. Reported over all clips and over clips labeled `clean`. | ≥ 85% of clean clips |
| Boundary hit rate | Every labeled rally has a start boundary and an end boundary. A labeled boundary is hit when a predicted boundary of the same kind lies within ±tolerance (default 2 000 ms, inclusive). Matching is one-to-one: the closest pair is taken first. | ≥ 85% |
| Confidently wrong | (missed + spurious) / (labeled + predicted) rallies. *Missed*: a labeled rally that no predicted rally overlaps. *Spurious*: a predicted rally that overlaps no labeled rally. `unknown` spans are not confident, so they count toward neither. | ≤ 5% |
| Rally-time IoU | Time both labeled and predicted as rally, divided by time either labeled or predicted as rally. Informational. | — |

Aggregate rates are **micro-averaged**: counts are summed across clips first,
so long clips carry more weight.

## Labeling a clip

Write one JSON file per recording and keep it beside the footage, **outside
the repository**:

```json
{
  "schema_version": 1,
  "clip_id": "c1",
  "duration_ms": 544000,
  "players": 4,
  "clean": false,
  "rallies": [
    { "start_ms": 12500, "end_ms": 18200 }
  ],
  "notes": "off-angle, fixed camera"
}
```

Rules:

- **Start** is the serve contact; **end** is the moment the shuttle is dead
  (lands, hits the net, or goes out). A let is not a separate rally.
- Rallies are in order and do not overlap. Times are in milliseconds on the
  original recording, which is what any video player shows.
- `players` is 2 (singles) or 4 (doubles).
- `clean` is `true` only if the recording follows every recording guideline in
  the roadmap.
- `duration_ms` must be within 1 s of the analysed duration.
- Unknown fields are rejected, so a typo is reported rather than ignored.
- Do not put anyone's name in `notes`.

To score several clips together, write a manifest. Relative paths resolve
against the manifest's folder:

```json
{
  "schema_version": 1,
  "clips": [
    { "clip_id": "c1", "labels": "c1.labels.json", "match_dir": "/path/to/matches/c1" }
  ]
}
```

The match directory must already contain `tracks/player_tracks.json` (from
player tracking) and, unless you replay segmentation, `tracks/rally_suggestions.json`
(from rally analysis).

## Running

From `core/`:

```text
cargo run -p sportcut-cli -- eval --manifest ~/sportcut-labels/manifest.json
cargo run -p sportcut-cli -- eval --labels c1.labels.json --match-dir ~/matches/c1 --json
```

| Flag | Effect |
| --- | --- |
| `--tolerance-ms <ms>` | Boundary tolerance (default 2000). |
| `--rally-config <json>` | Re-run segmentation on the stored tracks with this `SegmentationConfig`, and score that result instead of the stored suggestions. Use it to try new thresholds without the app. |
| `--json` | Print the full report as JSON. |
| `--fail-on-target` | Exit 3 when a target fails or nothing could be scored. |

Exit codes: 0 means the report was printed, 1 means unreadable or invalid
input, 2 means a command-line usage error (from clap), 3 means
`--fail-on-target` and a target was missed. In manifest mode, a
clip whose files are missing or invalid is listed as `error` and the other
clips are still scored.

Example `--rally-config` file with the thresholds the app ships today:

```json
{
  "bin_ms": 500, "max_track_gap_ms": 2000,
  "enter_motion_per_second": 4.0, "exit_motion_per_second": 2.0,
  "audio_intensity_threshold": 0.5,
  "min_rally_ms": 1500, "min_rest_ms": 3000, "min_usable_coverage": 0.40
}
```

Output is deterministic: running again on the same inputs prints the same bytes.

## Results

| Date | Clips (clean) | Source | Player count (clean) | Boundary hit | Conf. wrong | IoU |
| --- | --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | — | — |

No labeled clip has been scored yet. The next step is to label `c1`
(`~/Downloads/IMG_1194.mov`, see `rally-rest-segmentation.md`) and record the
first row here. Numbers from fewer than five clips are indicative only.
