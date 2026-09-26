# Rally/rest segmentation verification

Evidence for task 4.2 of `add-rally-rest-segmentation`, gathered on the
development Mac (Apple M4 Max, macOS 26.6.2) with Flutter 3.47.5 and the engine
built with `bridge,macos-tflite-eval`.

## What ran

End-to-end on the consented doubles clip `c1` (`~/Downloads/IMG_1194.mov`,
off-angle, fixed camera, ~9 min 4 s):

```text
import → calibrate court → player analysis (tracks) → analyze rallies (segmentation)
```

The resulting engine artifacts live in the match directory:

```text
calibration/calibration.json
tracks/player_tracks.json        (schema 1, ~10.5 MB, 5 fps, 4 track IDs)
tracks/rally_suggestions.json    (versioned RallySuggestions artifact)
```

## Result

Segmentation ran motion-only (no audio intensities are produced yet) and
classified the timeline into rally / rest / unknown spans. The review screen
shows the suggestions with accept / adjust / dismiss actions, and candidates
overlapping existing rallies are suppressed rather than duplicated.

Thresholds were tuned from the real track data. The summed-motion distribution
has median ~2.2 court-units/s and p90 ~4.9; the original first-pass thresholds
(enter 0.30, exit 0.15) classified 99.6% of bins as rally, merging a ~7-minute
stretch into one candidate. The tuned thresholds are:

```text
bin_ms 500 · max_track_gap_ms 2000
enter_motion_per_second 4.0 · exit_motion_per_second 2.0
min_rally_ms 1500 · min_rest_ms 3000 · min_usable_coverage 0.40
```

Replaying these thresholds over `player_tracks.json` yields 35 rallies,
~207 s of rally time (~38%), median rally 4 s, max 19 s — no false merge.

## Limitation

The boundary-quality acceptance target (±2 s on at least 85% of boundaries,
at most 5% confidently wrong) has **not** been measured against labeled ground
truth. The thresholds above are a first pass tuned to the motion distribution;
they are unverified for boundary accuracy. Audio support is compiled in but
inactive because the track producer does not yet emit audio intensities, so
silent-video behaviour is untested. These remain open until labeled footage is
available.
