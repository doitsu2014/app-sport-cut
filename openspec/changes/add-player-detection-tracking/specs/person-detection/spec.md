## ADDED Requirements

### Requirement: Offline person detection from sampled frames
The engine SHALL locate people in timestamped sampled frames using a bundled, distribution-approved on-device runtime and model. Detection SHALL require no network access, and its result SHALL retain the frame timestamp, displayed-frame bounding box, confidence, and model identity.

#### Scenario: People located in an analysis frame
- **WHEN** a readable sampled frame is analyzed with the approved model
- **THEN** the engine returns each detected person's image-space box and confidence with the frame's original-recording timestamp

#### Scenario: Analysis without connectivity
- **WHEN** a match is analyzed with network access disabled
- **THEN** person detection runs entirely from local frames, runtime, and model bytes

#### Scenario: Runtime or weights unavailable
- **WHEN** the approved runtime or model bytes cannot be loaded
- **THEN** the engine reports an actionable unavailable result and does not publish a final detection or track artifact

### Requirement: On-court candidate selection
The engine SHALL use the calibration valid at a frame timestamp to distinguish likely court players from other detected people. It SHALL retain selection evidence and SHALL NOT treat an off-court person as a player solely because their detection confidence is high.

#### Scenario: Spectator appears beside the court
- **WHEN** a frame contains detected people inside and outside the calibrated court
- **THEN** only plausible on-court detections contribute to the player count and tracks
- **AND** rejected detections remain inspectable with a reason

#### Scenario: Calibration is missing or stale
- **WHEN** no valid calibration covers the frame
- **THEN** the engine reports that court-player selection is unavailable for that frame
- **AND** it does not assert a player count from uncalibrated boxes

### Requirement: Evidence-based player count
The engine SHALL report two, four, or unknown observed on-court players from sustained observations across a recorded time interval. It SHALL include a quality indication and SHALL use unknown when visibility or tracking evidence cannot support either count.

#### Scenario: Sustained singles evidence
- **WHEN** adequately observed frames consistently show one tracked on-court player on each side
- **THEN** the assessment reports two players with its evidence interval and quality

#### Scenario: Sustained doubles evidence
- **WHEN** adequately observed frames consistently show two tracked on-court players on each side
- **THEN** the assessment reports four players with its evidence interval and quality

#### Scenario: Occlusion or inconsistent observations
- **WHEN** one side is repeatedly obscured or observations disagree about the count
- **THEN** the assessment reports unknown instead of converting a transient missing detection into a match-format change

### Requirement: Reviewed inference assets
The selected runtime, exact model weights, and any dataset used to produce shipped weights MUST have separate source, version, license, and distribution verdicts in the dependency register before the detector ships.

#### Scenario: Model license is unresolved
- **WHEN** model-weight redistribution terms have not been approved
- **THEN** those weights are excluded from the shipping product path
