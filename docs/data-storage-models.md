# Data and Storage Models

## Ownership split

- The **engine** owns artifact files: derived media and analysis output inside
  each match directory.
- The **app** owns the SQLite catalog and the app-owned copy of each imported
  recording.

Only `sportcut-api` crosses the language boundary; the app talks to the engine
through its typed bridge wrapper. Derived media belongs outside the repository —
never point an artifact root at the checkout.

## Client catalog (SQLite)

The app's catalog records the matches the user has imported, plus everything the
user authored: accepted rallies, confirmed scores, and kept clips. It never
stores per-frame track data (that stays in the engine's regenerable artifacts).

Core records:

```text
Match
  id, title, video_path, duration, created_at
  court_calibration, team_left_name, team_right_name
  final_score_left, final_score_right

Rally
  id, match_id, start_time, end_time, confidence, winner_side
  status, highlight_score

ScoreEvent
  id, match_id, rally_id, timestamp, winner_side, left_score, right_score

HighlightClip
  id, match_id, start_time, end_time, rank, selected, trim_start, trim_end
```

Rallies, score events, and clip selections are user-authored and preserved
across reanalysis. Derived evidence (tracks, suggested rallies) is regenerable
and may be invalidated and replaced.

A small `rally_suggestion_decisions` table records accepted/dismissed choices
per suggestion generation. Accepting a candidate creates an unscored rally in
the same SQLite transaction; dismissing records only the decision. Decisions are
keyed by generation, so a rerun with the same inputs keeps them while a changed
input starts a new generation.

## Match directory (engine artifacts)

Inside a match directory the engine writes:

```
manifest.json          artifact manifest with kinds, states, and identities
checkpoints.json       stage checkpoint state for resumable jobs
proxy/                 low-resolution analysis proxy
audio/                 low-bitrate analysis audio
frames/                upright, timestamped sampled JPEGs
calibration/           court calibration
tracks/                player_tracks.json + rally_suggestions.json
export/                rendered highlight output
```

Keep that layout stable. `manifest.json` records each artifact's kind, final or
non-final state, relative path, and content identity.

## Artifact kinds and freshness

`ArtifactKind` values include calibration, proxy, analysis audio, sampled
frames, tracks, and export. A completed artifact is marked **final** only after
successful completion; cancelled or interrupted output stays non-final and is
never consumed as a valid result.

Freshness is driven by content identities: calibration identity, sampled-frame
and proxy fingerprints, model/runtime identities, and analysis configuration.
When any input changes, the old tracks and derived rally suggestions are treated
as stale and regenerated. User-authored rallies, confirmed scores, and kept
clips are untouched.

Older matches with no tracks remain readable and keep manual review.

## Import custody

Import takes custody of a recording: the picked file is copied into
`SportcutRecordings/<matchId>` and that copy is what the match records, because
the platform picker may hand back a file in a directory the app does not own.
The file the user selected is never copied, moved, renamed, or modified — it is
not ours to touch. The library reports a recording that has gone missing rather
than failing silently.

## Tracks artifact

`tracks/player_tracks.json` is the versioned, regenerable producer envelope. Its
schema-1 `input` carries the rally-segmentation contract:

- `duration_ms`
- calibration content identity
- ordered non-overlapping coverage intervals
- ordered observed `(timestamp_ms, track_id, u, v)` positions

A separate producer section adds detector/model/config identity, per-frame
boxes, count assessment, side and quality information, and explicit gaps, so the
raw evidence stays inspectable without changing the downstream contract.

## Rally suggestions artifact

`tracks/rally_suggestions.json` is the versioned `RallySuggestions` artifact. It
holds the input fingerprint, algorithm version, deterministic candidate IDs,
rally intervals, rest/unknown intervals, quality values, and signal provenance.
It is written atomically and published final only on success; a cancelled run
leaves no final suggestion set. The segmentation is motion-first and optional
audio, and its thresholds are recorded so a result can be reproduced.

## Model and runtime bytes

Model weights and the inference runtime are pinned by checksum (see
`external-dependencies.md`). During development they are loaded from local paths
via `SPORTCUT_TFLITE_LIBRARY` and `SPORTCUT_PERSON_MODEL`; a packaged release
bundles them inside the app so analysis runs with networking disabled.
