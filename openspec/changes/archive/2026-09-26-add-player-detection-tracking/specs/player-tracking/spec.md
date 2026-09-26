## ADDED Requirements

### Requirement: Timestamped player tracks with explicit gaps
The engine SHALL associate on-court detections across ordered sampled frames into player tracks whose IDs are stable within one analysis generation. It SHALL retain observed timestamps and coverage intervals, and SHALL represent missing or ambiguous observations as gaps rather than invented player positions.

#### Scenario: Player remains visible
- **WHEN** successive sampled frames contain an unambiguous observation of the same player
- **THEN** the observations share a track ID and retain their original-recording timestamps

#### Scenario: Occlusion exceeds reliable association
- **WHEN** a player is hidden long enough that identity cannot be linked reliably
- **THEN** the engine records a gap or new track and does not synthesize positions across the hidden interval

#### Scenario: No usable player coverage
- **WHEN** frames are sampled but player positions cannot be observed reliably
- **THEN** the artifact identifies the interval as insufficient coverage rather than as evidence of rest

### Requirement: Calibrated court positions and sides
The engine SHALL derive a representative ground position from each usable player observation, map it through the calibration valid at that timestamp, and assign a geometric court side only when the position is reliable. Side labels SHALL use the calibration's first and second halves of the net, independent of camera-left or camera-right.

#### Scenario: Ground position projects within one half
- **WHEN** a reliable observed player position projects inside the calibrated court and away from the net uncertainty band
- **THEN** the track observation has normalized court coordinates and the corresponding court side

#### Scenario: Side is ambiguous
- **WHEN** the position is near the net, outside the reliable court area, or its projection fails
- **THEN** the observation has an unknown side and is not silently assigned to either team

#### Scenario: Calibration is unavailable for an observation
- **WHEN** no valid calibration is available at an observation's timestamp
- **THEN** the observation has no court position or side and cannot contribute a usable court track position

### Requirement: Versioned tracks for downstream analysis
The engine SHALL write a completed track generation to `tracks/player_tracks.json` as a versioned, regenerable engine artifact. It SHALL provide recording duration, calibration content identity, ordered coverage intervals, and ordered observed `(timestamp_ms, track_id, u, v)` positions in the schema accepted by rally segmentation. A completed artifact SHALL also retain detection, count, side, model, and quality provenance for review.

#### Scenario: Completed analysis supplies rally segmentation
- **WHEN** tracking finishes with usable calibrated positions
- **THEN** `ArtifactKind::Tracks` is final and the rally segmenter can read its track input

#### Scenario: Analysis is cancelled or interrupted
- **WHEN** tracking ends before all required output is complete
- **THEN** no partial track artifact is marked final or consumed as valid input

#### Scenario: Inputs change
- **WHEN** calibration, sampled frames, model, or analysis configuration changes
- **THEN** the old tracks and derived rally suggestions are treated as stale and must be regenerated
- **AND** user-authored rallies, confirmed scores, and kept clips remain unchanged

#### Scenario: Existing match has no tracks
- **WHEN** an older match is opened without a track artifact
- **THEN** the match remains readable and manual review remains available

### Requirement: Cancellable analysis and reviewable results
The engine SHALL expose tracking as stage-labelled, cancellable local job work and SHALL provide read-only count, coverage, track, side, and uncertainty results through the API facade. The client SHALL access those results through its typed bridge wrapper and SHALL not turn a detection or side assignment into a score or winner without user confirmation.

#### Scenario: Reviewer inspects results
- **WHEN** analysis completes
- **THEN** the client can show observed count, track positions, side assignments, and coverage gaps with their uncertainty

#### Scenario: Analysis cannot run
- **WHEN** required calibration, frames, runtime, or weights are unavailable
- **THEN** the client shows an actionable unavailable reason and keeps manual review usable

#### Scenario: User has not confirmed a rally winner
- **WHEN** a track is assigned to a court side
- **THEN** no winner or score event is written solely from that assignment
