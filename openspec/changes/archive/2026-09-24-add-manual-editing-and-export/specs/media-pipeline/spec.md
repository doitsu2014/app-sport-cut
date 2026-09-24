## MODIFIED Requirements

### Requirement: Per-match artifact layout
The engine SHALL store all derived media and analysis artifacts for a match, including rendered highlight videos, inside a single match directory with a manifest recording each artifact and the original media reference.

#### Scenario: Artifacts organized under one directory
- **WHEN** the engine produces proxy, audio, frame, or export artifacts for a match
- **THEN** every artifact is written beneath that match's artifact directory
- **AND** the original recording is referenced rather than relocated

#### Scenario: Derived artifacts are regenerable
- **WHEN** a match's derived artifacts are deleted while the original recording and catalog record remain
- **THEN** the manifest reports which artifacts are missing
- **AND** the artifacts can be regenerated without re-importing the match

#### Scenario: Exported video recorded like every other artifact
- **WHEN** the engine renders a highlight video for a match
- **THEN** the rendered file is recorded in the manifest with its kind, relative path, state, and size

#### Scenario: Exported video does not displace match analysis
- **WHEN** a match has both analysis artifacts and a rendered highlight video
- **THEN** the manifest lists both
- **AND** neither is presented as a substitute for the other

