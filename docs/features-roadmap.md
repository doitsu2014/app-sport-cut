# Feature List and Road Map

## Target users

- Amateur badminton players
- Badminton clubs and coaches
- Tournament organizers for local matches
- Content creators posting match highlights

Typical scenario: a user records a match on a tripod behind or above the
court, imports the video, confirms the court, reviews suggested rallies and
highlights, then exports a short video with music and a scoreboard.

## Feature list

### Version 1 scope — included

- Import a local video file
- Calibrate the court by selecting four corners and the net
- Detect the number of on-court players (two / four / unknown)
- Track player positions and assign a geometric court side
- Detect active rallies and inactive periods
- Skip inactive periods automatically
- Generate suggested rally clips
- Confirm the winning side per rally with one tap
- Maintain a score timeline
- Show who serves each rally
- Suggest highlights from rally duration, movement intensity, and score context
- Trim, reorder, and remove suggested highlights
- Add user-provided music
- Export a final video with score overlays

### Version 1 scope — excluded

- Fully automatic official scoring
- Reliable shuttlecock landing detection
- Automatic player identity recognition
- Live camera scoring during a match
- Cloud synchronization
- Social network publishing
- Tournament bracket management
- iOS and Android clients (macOS is the only target)

## Road map

| Phase | Goal | Deliverables | Status |
| --- | --- | --- | --- |
| 0 | Research and proof of concept | Test footage, court-calibration prototype, frame extraction, person detection and player count, rally-vs-rest classifier, benchmark report | Footage and inference gates partially open; latency/memory benchmark recorded; accuracy harness ready (`sportcut-cli eval`, `verification/accuracy-evaluation.md`), awaiting labeled clips |
| 1 | Video editing MVP | Import, manual trim/clips, manual score timeline, overlay, music, FFmpeg export | Done — see `verification/manual-editing-and-export.md` |
| 2 | Automatic rally detection | Court calibration, player count, tracking, active/inactive segments, suggested cuts, editable timeline | Done: court calibration (`verification/court-calibration.md`), player detection and tracking, rally/rest segmentation (`verification/rally-rest-segmentation.md`; thresholds first-pass on clip c1) |
| 3 | Semi-automatic scoring | Rally confirmation UI, left/right selection, score timeline, serving-side heuristic | Done: accept/adjust/dismiss rally suggestions, one-tap winner, score timeline, serving side (`sportcut-score`) shown on the scoreboard |
| 4 | Highlight intelligence | Highlight scoring, audio intensity, motion ranking, templates, favorites | Partially done: deterministic ranking from duration, motion, and score context (`sportcut-highlight`) with "keep the best N"; audio intensity, templates, and favorites not started; weights not yet tuned |
| 5 | Advanced computer vision | Shuttlecock/racket detection, shot classification, serve detection, shot speed | Deferred — starts only after enough consented labeled data |

Alongside the phases, the client moved to **workspaces**: recordings are grouped
into workspaces and worked on in a three-pane studio (videos, one shared
preview, feature rail). See `architecture.md`.

### Success criteria

- **Phase 0** — two/four players identified in at least 85% of clean videos;
  most active rallies detected with editable boundaries.
- **Phase 1** — a highlight video can be built from a local recording with no
  cloud service.
- **Phase 2** — most rest periods are removed automatically, faster than manual
  editing.
- **Phase 3** — a full recreational match is scored with one tap per rally.
- **Phase 4** — recommended clips are useful enough that users keep most.

The first successful version succeeds if a player can take a 30–60 minute raw
recording and, in a few minutes, produce a clean video with breaks removed, a
correct user-confirmed score, a short set of good highlights, and a shareable
export.

## Recording guidelines

For best results the app recommends:

- Use a fixed tripod
- Record in landscape
- Keep the full court visible
- Place the camera behind the baseline or above the sideline
- Avoid strong backlighting
- Use 1080p when possible
- Avoid frequent zooming or camera movement
- Keep non-playing people outside the court area
