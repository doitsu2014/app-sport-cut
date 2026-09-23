# media-pipeline Specification

## Purpose
Local video probing, reduced-resolution proxy generation, analysis audio
extraction, frame sampling, and the per-match artifact layout the engine writes
to disk. Every stage runs on-device against local files, and the original
recording is referenced in place and never modified.
## Requirements
### Requirement: Local video probing
The engine SHALL read media metadata from a local video file, including duration, frame rate, resolution, orientation, and audio track presence, without modifying the source file.

#### Scenario: Metadata returned for a readable file
- **WHEN** the engine probes a readable local video file
- **THEN** it returns duration, frame rate, resolution, orientation, and whether an audio track is present

#### Scenario: Unreadable input handled
- **WHEN** the engine probes a file that is missing, truncated, or not a supported media container
- **THEN** it returns an explicit error identifying the file and the reason
- **AND** it does not panic or terminate the host application

### Requirement: Analysis proxy generation
The engine SHALL generate a reduced-resolution proxy video for analysis and preview while leaving the original recording untouched.

#### Scenario: Proxy created
- **WHEN** a proxy is requested for an imported video
- **THEN** a reduced-resolution proxy file is written inside the match artifact directory
- **AND** the proxy is recorded in the match manifest

#### Scenario: Original recording unmodified
- **WHEN** proxy generation completes
- **THEN** the original video file is byte-for-byte unchanged and remains at its original location

### Requirement: Analysis audio extraction
The engine SHALL extract a separate low-bitrate audio track for analysis, and SHALL treat a missing audio track as an expected outcome rather than a failure.

#### Scenario: Audio track extracted
- **WHEN** an imported video contains an audio track
- **THEN** the engine writes a separate low-bitrate analysis audio file inside the match artifact directory

#### Scenario: Video without audio
- **WHEN** an imported video has no audio track
- **THEN** the engine reports that no analysis audio is available
- **AND** the rest of the pipeline continues without an audio signal

### Requirement: Frame sampling for analysis
The engine SHALL sample frames from the proxy at a configurable rate and SHALL emit each frame with a timestamp that maps back to the original recording timeline, so that later stages consume a bounded, timestamped frame stream instead of every frame.

#### Scenario: Frames sampled at the requested rate
- **WHEN** frame sampling is requested at a given rate for a video of known duration
- **THEN** the engine emits frames at approximately that rate
- **AND** each emitted frame carries a timestamp mapping to the original recording timeline

#### Scenario: Unsupported sampling rate rejected
- **WHEN** a sampling rate is requested that exceeds the supported maximum
- **THEN** the engine rejects the request with an explicit error rather than silently processing at a different rate

### Requirement: Per-match artifact layout
The engine SHALL store all derived media and analysis artifacts for a match inside a single match directory with a manifest recording each artifact and the original media reference.

#### Scenario: Artifacts organized under one directory
- **WHEN** the engine produces proxy, audio, or frame artifacts for a match
- **THEN** every artifact is written beneath that match's artifact directory
- **AND** the original recording is referenced rather than relocated

#### Scenario: Derived artifacts are regenerable
- **WHEN** a match's derived artifacts are deleted while the original recording and catalog record remain
- **THEN** the manifest reports which artifacts are missing
- **AND** the artifacts can be regenerated without re-importing the match

### Requirement: Offline operation guaranteed
The media pipeline SHALL perform all probing, proxy generation, audio extraction, and frame sampling using local resources only, and MUST NOT require network access.

#### Scenario: Pipeline runs without network access
- **WHEN** the media pipeline processes an imported video while network access is unavailable
- **THEN** every pipeline stage completes normally

#### Scenario: No media data leaves the device
- **WHEN** the media pipeline processes an imported video
- **THEN** it transfers no media data to any external service
