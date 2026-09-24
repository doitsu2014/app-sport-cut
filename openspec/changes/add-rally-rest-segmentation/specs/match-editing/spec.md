## MODIFIED Requirements

### Requirement: Marking a rally on the timeline
The application SHALL let the user mark a span of the recording as a rally by setting a start and an end from the playback timeline, and SHALL let the user turn a proposed rally into a stored rally only by accepting or adjusting and accepting it. It SHALL NOT record a rally without a user action.

#### Scenario: Rally marked from playback
- **WHEN** the user sets a start and an end while reviewing a recording
- **THEN** a rally is recorded for that match with those boundary timestamps
- **AND** the rally is shown on the timeline at that position

#### Scenario: Boundary adjusted
- **WHEN** the user adjusts the start or end of a recorded rally
- **THEN** the stored boundary changes to the new value
- **AND** no other rally's boundaries change

#### Scenario: Marking rejected
- **WHEN** the user attempts to record a rally whose end is not after its start
- **THEN** the application rejects it and reports why
- **AND** no rally record is created

#### Scenario: No rally is invented
- **WHEN** analysis has produced candidates but the user has not marked or accepted a rally
- **THEN** the application holds no rally records for those candidates
- **AND** the candidates are clearly presented as suggestions, not confirmed rallies

#### Scenario: Suggested rally accepted
- **WHEN** the user accepts a proposed rally, with or without adjusting its boundaries
- **THEN** the accepted span is saved as an unscored rally
- **AND** its suggestion decision survives leaving and reopening the review session
- **AND** no winner, score event, or clip is created by acceptance alone

#### Scenario: Suggested rally dismissed
- **WHEN** the user dismisses a proposed rally
- **THEN** that candidate is hidden for the same analysis generation after reopening the review session
- **AND** no rally, winner, score event, or clip is created

#### Scenario: Manual editing remains available
- **WHEN** segmentation is unavailable, cancelled, or produces poor suggestions
- **THEN** the user can still mark, adjust, score, and select rallies manually

#### Scenario: Analysis rerun preserves review
- **WHEN** segmentation is rerun after the user has edited a match
- **THEN** accepted and manually marked rallies, confirmed winners, score events, and existing clips remain unchanged
- **AND** newly generated overlapping candidates are not silently inserted into the review
