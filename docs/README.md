# Offline Badminton Video Analyzer — Product and Technical Plan

## 1. Product Summary

Build a mobile application that turns a badminton match recording into:

- A cleaned video with inactive periods removed
- Detected players and court-side information
- A semi-automatic score timeline
- Automatically suggested highlight clips
- An exported highlight video with score overlays and background music

The product must run fully offline. Videos and analysis results stay on the user’s device. The application must not depend on cloud AI, third-party video APIs, or online processing services.

## 2. Product Principle

The first version should not claim fully automatic officiating.

Badminton shuttlecocks are small, fast, blurred in motion, and often hidden by players or the net. Automatically determining whether a shuttlecock touched the ground, who made an error, or which team won every rally will be unreliable for normal phone recordings.

The app should instead use a human-in-the-loop workflow:

1. The app detects likely rally boundaries.
2. The app suggests which side may have won the rally.
3. The user confirms or corrects the result with one tap.
4. The score updates automatically.
5. The user exports a polished video.

This provides real value early while collecting labeled data for future model improvements.

## 3. Target User

Primary users:

- Amateur badminton players
- Badminton clubs and coaches
- Tournament organizers for local matches
- Content creators posting match highlights

Typical scenario:

A user records a match using a tripod from behind or above the court, imports the video, confirms the court boundaries, reviews suggested points and highlights, then exports a short video with music and a scoreboard.

## 4. Scope for Version 1

### Included

- Import a local video file
- Calibrate the court by selecting four court corners
- Detect the number of players on court
- Track player positions and assign them to the left or right side
- Detect active rallies and inactive periods
- Remove or skip inactive periods automatically
- Generate suggested rally clips
- Let users manually confirm which side won each rally
- Maintain a score timeline
- Suggest highlights using rally duration and movement intensity
- Trim, reorder, and remove suggested highlights
- Add user-provided music
- Export a final video with score overlays

### Excluded from Version 1

- Fully automatic official scoring
- Reliable shuttlecock landing detection
- Automatic player identity recognition
- Live camera scoring during a match
- Cloud synchronization
- Social network publishing
- Tournament bracket management

## 5. Recommended Technical Stack

| Area | Technology |
|---|---|
| Mobile user interface | Flutter |
| Native processing engine | Rust |
| Flutter-to-Rust bridge | `flutter_rust_bridge` or Dart FFI |
| Video decoding and export | FFmpeg |
| Person and pose detection | MediaPipe or RTMPose |
| On-device ML model runtime | TensorFlow Lite or ONNX Runtime |
| Local database | SQLite |
| Video playback | Flutter video player with native platform support |
| State management | Riverpod or Bloc |

All video analysis should run on-device.

## 6. Licensing Requirements

Use a written dependency register from the first day.

Recommended license direction:

- Flutter: BSD-style license
- Rust: MIT / Apache-2.0 ecosystem
- MediaPipe: Apache-2.0
- MMPose / RTMPose: Apache-2.0
- FFmpeg: use an LGPL-compatible build where possible
- SQLite: public domain

Avoid using Ultralytics YOLO in a proprietary commercial product unless the entire project is released under AGPL-3.0 or a commercial license is purchased.

Every machine-learning model, pretrained weight file, training dataset, font, music asset, and video codec must be reviewed separately. A library being open source does not automatically make every included model or weight safe for commercial redistribution.

## 7. System Architecture

```text
Flutter App
  ├─ Video import and library
  ├─ Court calibration screen
  ├─ Video review player
  ├─ Score confirmation interface
  ├─ Highlight editor
  └─ Export settings

Rust Processing Engine
  ├─ Video frame extraction
  ├─ Audio feature extraction
  ├─ Player/pose tracking
  ├─ Court-side classification
  ├─ Rally segmentation
  ├─ Event timeline generation
  ├─ Highlight ranking
  └─ FFmpeg export pipeline

Local Storage
  ├─ Original video reference
  ├─ Match metadata
  ├─ Court calibration
  ├─ Player tracks
  ├─ Rally timeline
  ├─ Score events
  └─ Export settings
```

## 8. Video Analysis Pipeline

### Step 1: Import and Normalize

When a user imports a video:

- Read duration, frame rate, orientation, resolution, and audio metadata.
- Generate a low-resolution proxy video for analysis and smooth preview.
- Preserve the original video for final rendering.
- Extract audio as a separate low-bitrate analysis track.

### Step 2: Court Calibration

Ask the user to select the four outside corners of the badminton court.

The application converts the camera view into a normalized top-down court coordinate system. This lets the app determine:

- Which players are on each side
- Whether there are two or four players
- Player movement distance
- Approximate serving position
- Whether people are likely inside or outside the court

Court calibration should be stored with the match and editable later.

### Step 3: Person Detection and Tracking

Run a lightweight person or pose model on sampled frames, initially at 5–10 frames per second.

For each detected person:

- Detect a bounding box or body landmarks
- Track the person across frames
- Estimate the court-side position
- Ignore people outside the calibrated court area where possible
- Count active players

Expected Version 1 support:

- Singles: two players
- Doubles: four players
- Camera angle: fixed, horizontal, full court visible

### Step 4: Rally Segmentation

The objective is to determine when a rally starts and stops.

Signals include:

- Number of players moving
- Player movement speed and direction changes
- Pose activity
- Presence of players in service positions
- Audio spikes from racket contact, shuttlecock impact, or crowd reaction
- Long stationary periods
- Camera changes or shake

Output example:

```text
00:00–00:18  Setup / inactive
00:18–00:42  Rally 1
00:42–00:57  Inactive
00:57–01:10  Rally 2
```

Rally boundaries should always be editable by the user.

### Step 5: Score Confirmation

At the end of each detected rally, show a compact confirmation card:

```text
Rally 12 ended at 04:21
Who won the point?

[ Left Team ]   [ Right Team ]   [ Skip ]
```

When the user confirms the winner:

- Increase that side’s score
- Store a score event in the timeline
- Use the updated serving side as a weak signal for the next rally
- Update the score overlay in the preview

The system may display a confidence suggestion, but the user must remain in control.

### Step 6: Highlight Ranking

Each rally receives a highlight score based on:

- Rally duration
- Total player movement
- Number of rapid direction changes
- Audio intensity
- Whether the rally ended with a confirmed point
- User favorites
- Optional manual rating

Suggested highlight rules:

- Long rally: high priority
- Fast player movement: high priority
- Strong crowd or racket audio: medium priority
- Very short rally: low priority
- Incomplete or uncertain rally: low priority

The user can keep, remove, trim, reorder, or favorite suggested clips.

### Step 7: Video Export

The export engine should:

- Trim selected clips from the original high-resolution video
- Add short lead-in and lead-out padding around each highlight
- Concatenate clips
- Add transitions if selected
- Overlay player/team names and score
- Add a title card and optional match details
- Mix user-provided background music
- Automatically lower music volume when original match audio is retained
- Export MP4 using H.264 video and AAC audio where licensing and platform support allow

## 9. User Experience Flow

### Match Creation

1. User selects “New Match”.
2. User imports a video.
3. App asks for court calibration.
4. App analyzes the video locally.
5. App displays the detected number of players and rally timeline.

### Score Review

1. User enters team names and starting score.
2. User reviews detected rally cards.
3. User taps the winning team for each rally.
4. User adjusts incorrect start/end timestamps if necessary.
5. App updates the final score and timeline.

### Highlight Review

1. App displays recommended highlights.
2. User keeps, removes, or trims clips.
3. User chooses a template and background music.
4. User previews the result.
5. User exports the video.

## 10. Development Phases

### Phase 0 — Research and Proof of Concept

Goal: validate the difficult technical assumptions.

Deliverables:

- Test videos from fixed camera angles
- Court calibration prototype
- Frame extraction prototype
- Person detection and player count test
- A basic rally-versus-rest classifier
- Benchmark report for speed, battery, and accuracy

Success criteria:

- Correctly identify two or four players in at least 85% of clean test videos.
- Detect most active rally periods with editable boundaries.
- Complete analysis of a 20-minute 720p video in a practical time.

### Phase 1 — Video Editing MVP

Goal: provide immediate user value without AI scoring.

Deliverables:

- Video import
- Manual trim and clip selection
- Manual score timeline
- Score overlay
- Music selection from device storage
- FFmpeg-based export

Success criteria:

- User can create a highlight video from a local recording without any cloud service.
- Exported video has correct cuts, music, and scoreboard.

### Phase 2 — Automatic Rally Detection

Goal: reduce manual editing effort.

Deliverables:

- Court calibration
- Player count
- Player tracking
- Active/inactive segment detection
- Suggested cuts
- Editable rally timeline

Success criteria:

- The app removes most rest periods automatically.
- Users can review and correct results faster than manual editing.

### Phase 3 — Semi-Automatic Scoring

Goal: make score entry fast and reliable.

Deliverables:

- Rally confirmation interface
- Left/right team selection
- Score timeline
- Serving-side heuristic
- Exportable final score

Success criteria:

- A user can score a full recreational match with one tap per rally.
- Score edits automatically update the final video overlay.

### Phase 4 — Highlight Intelligence

Goal: create better automatic highlight videos.

Deliverables:

- Highlight scoring algorithm
- Audio intensity analysis
- Motion-based ranking
- Highlight templates
- User favorite system

Success criteria:

- Recommended clips are useful enough that users keep a majority of them.

### Phase 5 — Advanced Computer Vision

Goal: improve automation using collected data.

Possible features:

- Shuttlecock detection
- Racket detection
- Smash, drop, and clear classification
- Automatic serve detection
- Shot speed estimation
- Better winner prediction

This phase should begin only after collecting enough consented, labeled match data.

## 11. Data Model

```text
Match
  id
  title
  video_path
  duration
  created_at
  court_calibration
  team_left_name
  team_right_name
  final_score_left
  final_score_right

Rally
  id
  match_id
  start_time
  end_time
  confidence
  winner_side
  status
  highlight_score

ScoreEvent
  id
  match_id
  rally_id
  timestamp
  winner_side
  left_score
  right_score

HighlightClip
  id
  match_id
  start_time
  end_time
  rank
  selected
  trim_start
  trim_end
```

## 12. Key Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Shuttlecock cannot be reliably seen | Use semi-automatic score confirmation |
| Different camera angles reduce accuracy | Require court calibration and recommend recording guidelines |
| Slow processing on lower-end phones | Use proxy video, frame sampling, background jobs, and optional desktop mode |
| Battery and overheating | Pause analysis when app is backgrounded; show progress; process in chunks |
| Model size makes app large | Use small quantized models and download optional model packs |
| License conflicts | Maintain a dependency and model-license register |
| Copyrighted music | Let users select their own music or bundle only licensed tracks |

## 13. Recording Guidelines for Users

For the best results, the app should recommend:

- Use a fixed tripod.
- Record in landscape orientation.
- Keep the full court visible.
- Place the camera behind the baseline or above the sideline.
- Avoid strong backlighting.
- Use 1080p when possible.
- Avoid frequent zooming or camera movement.
- Keep people not playing outside the court area.

## 14. Definition of Success

The first successful product version does not need perfect computer vision.

It succeeds if a badminton player can take a 30–60 minute raw match recording and, in a few minutes, produce:

- A clean video with breaks removed
- A correct, user-confirmed score timeline
- A short set of good rally highlights
- A shareable export with music and a scoreboard

## 15. Recommended First Build Order

1. Flutter video import and playback
2. Rust + FFmpeg integration
3. Manual trimming and export
4. Manual score timeline and overlay
5. Court calibration
6. Person detection and player count
7. Rally/rest segmentation
8. Semi-automatic score confirmation
9. Highlight ranking
10. Shuttlecock and advanced event detection

## 16. Final Recommendation

Build the application as an offline “AI-assisted badminton editor,” not as an automated referee.

Flutter and Rust are a strong combination for this project:

- Flutter provides a polished cross-platform mobile interface.
- Rust provides safe, fast media-processing and analysis logic.
- FFmpeg provides professional video editing capability.
- On-device open-source computer vision keeps the product private and independent from external APIs.

The best Version 1 promise is:

“Import a badminton match, automatically remove downtime, confirm scores quickly, choose the best rallies, and export a polished highlight video — all on your device.”