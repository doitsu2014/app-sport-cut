## ADDED Requirements

### Requirement: Local rally and rest proposals
The engine SHALL analyze timestamped court-aware player tracks to propose rally intervals on the original recording timeline. It SHALL keep the intervals ordered, non-overlapping, within the recording duration, and distinguish rest from intervals with insufficient track coverage. Analysis SHALL work without network access and SHALL NOT modify the recording.

#### Scenario: Usable tracks produce proposals
- **WHEN** a match has a valid calibration and usable player tracks across a covered portion of the recording
- **THEN** analysis returns candidate rally intervals with start and end timestamps on the original recording timeline
- **AND** it identifies rest and unknown intervals in the analyzed portion
- **AND** no candidate has an end before or equal to its start or overlaps another candidate

#### Scenario: Missing or unusable tracks
- **WHEN** tracks, calibration, or sufficient track coverage are unavailable
- **THEN** analysis reports which input is missing or unusable
- **AND** it does not report an empty candidate set as proof that no rallies occurred

#### Scenario: Analysis remains local
- **WHEN** the device has no network connection
- **THEN** rally analysis can run from local match artifacts
- **AND** no recording, track, or audio data leaves the device

### Requirement: Optional audio evidence and suggestion quality
The engine SHALL use analysis audio only as an optional supporting signal and SHALL report the signals and coverage behind each suggestion. A suggestion SHALL NOT identify a winner or claim to be an official point.

#### Scenario: Recording without audio
- **WHEN** usable tracks exist and no analysis audio is available
- **THEN** analysis can propose rallies from motion alone
- **AND** the result states that audio evidence was unavailable

#### Scenario: Audio without player motion
- **WHEN** an audio spike occurs without supporting player activity
- **THEN** that spike alone does not create a rally candidate

#### Scenario: Low-quality coverage
- **WHEN** a candidate is derived from sparse but usable track coverage
- **THEN** its quality indication reflects that limitation
- **AND** the reviewer can see that it is uncertain

### Requirement: Cancellable and regenerable analysis
The application SHALL start segmentation as a local processing job with stage-labelled progress and cancellation. The engine SHALL store a completed suggestion set as a versioned, regenerable match artifact with the inputs and algorithm version that produced it. It SHALL NOT present partial output as final.

#### Scenario: Completed analysis
- **WHEN** a segmentation job finishes
- **THEN** a versioned suggestion artifact is recorded in the match manifest as final
- **AND** the client can read its candidates, rest/unknown intervals, quality values, and input identity

#### Scenario: Job cancelled
- **WHEN** the user cancels segmentation before completion
- **THEN** the job ends without a final suggestion set from that run
- **AND** existing accepted rallies and score events remain unchanged

#### Scenario: Inputs change
- **WHEN** calibration, player tracks, usable audio, or segmentation parameters differ from those recorded with a suggestion set
- **THEN** the old suggestions are treated as stale until regenerated
- **AND** accepted or manually marked rallies, confirmed winners, score events, and clips remain intact

#### Scenario: Repeated analysis of the same inputs
- **WHEN** analysis is rerun with the same inputs and algorithm parameters
- **THEN** equivalent candidates retain stable identities so review decisions for that generation remain applicable

### Requirement: Suggestions do not edit the match by themselves
The application SHALL keep machine suggestions separate from user-authored rallies and SHALL apply no scoring or clip selection until the user explicitly acts.

#### Scenario: Suggestions first appear
- **WHEN** analysis produces candidates for an unreviewed match
- **THEN** the review screen shows them as proposals
- **AND** the SQLite rallies, score events, and highlight clips remain unchanged

#### Scenario: Suggestions overlap reviewed rallies
- **WHEN** a newly generated candidate overlaps a rally already accepted or marked by the user
- **THEN** the application does not silently replace or duplicate that rally
- **AND** the reviewer can inspect the conflict before making any change
