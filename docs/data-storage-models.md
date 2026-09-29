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

The app's catalog (`sportcut.db`, defined in
`app/lib/src/features/library/data/match_catalog.dart`) records the workspaces
and matches the user has imported, plus everything the user authored: accepted
rallies, confirmed scores, kept clips, and export settings. It never stores
per-frame track data (that stays in the engine's regenerable artifacts).

The schema is at **version 5**, reached by ordered migrations so a device that
skipped a release still upgrades step by step.

```text
workspaces                                   (v5)
  id PK, title, created_at

matches
  id PK, workspace_id (v5), title, created_at
  video_path, original_path (v2), source_bytes (v2), match_dir
  duration_seconds, video_width, video_height, frame_rate, has_audio
  court_calibration, team_left_name, team_right_name
  final_score_left, final_score_right

rallies
  id PK, match_id → matches (cascade)
  start_seconds, end_seconds, confidence, winner_side, status, highlight_score

score_events
  id PK, match_id → matches (cascade), rally_id → rallies (set null)
  timestamp_seconds, winner_side, left_score, right_score

highlight_clips
  id PK, match_id → matches (cascade), rally_id → rallies (set null, v3)
  start_seconds, end_seconds, rank, selected, order_index (v3)
  trim_start_seconds, trim_end_seconds

export_settings                              (v3)
  match_id PK → matches (cascade)
  title, music_path, music_gain (0.25), lead_in_seconds (1.0)
  lead_out_seconds (1.0), updated_at

rally_suggestion_decisions                   (v4)
  PK (match_id, generation_id, candidate_id), match_id → matches (cascade)
  decision ∈ {accepted, dismissed}, rally_id → rallies (set null)
```

Migration v5 moves every existing match into a workspace with id `default`,
titled "My videos". A workspace is a loose folder of recordings: it owns no
artifacts, and each video still runs the one-video pipeline.

Rallies, score events, clip selections, and export settings are user-authored
and preserved across reanalysis. Derived evidence (tracks, suggested rallies) is
regenerable and may be invalidated and replaced.

`rally_suggestion_decisions` records accepted/dismissed choices per suggestion
generation. Accepting a candidate creates an unscored rally in the same SQLite
transaction, carrying the suggestion's motion quality as the rally's
`confidence`; dismissing records only the decision. Decisions are keyed by
generation, so a rerun with the same inputs keeps them while a changed input
starts a new generation.

Serving sides and highlight ranks are pure engine calls recomputed from the
catalog on demand. They are not persisted: `rallies.highlight_score` and
`highlight_clips.rank` exist in the schema but the ranking is not written to
them.

## Match directory (engine artifacts)

Inside a match directory the engine writes:

```
manifest.json          artifact manifest with kinds, states, and identities
checkpoints.json       stage checkpoint state for resumable jobs
proxy/                 low-resolution analysis proxy
audio/                 low-bitrate analysis audio
frames/                upright, timestamped sampled JPEGs
calibration/           calibration.json
tracks/                player_tracks.json + rally_suggestions.json
export/                highlight.mp4
```

Keep that layout stable. `manifest.json` records each artifact's kind, final or
non-final state, relative path, and content identity. There are no score or
highlight-ranking artifacts; that data lives in the SQLite catalog.

## Artifact kinds and freshness

`ArtifactKind` values are `Proxy`, `AnalysisAudio`, `Frames`, `Calibration`,
`Tracks`, `RallySuggestions` (both under `tracks/`), and `Export`. A completed artifact is marked **final** only after
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
