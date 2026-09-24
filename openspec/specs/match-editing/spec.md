# match-editing Specification

## Purpose
Reviewing a recording without computer vision: marking rally boundaries on the
timeline, confirming which side won each point, maintaining the running score
from those confirmations, and choosing the clips that make up the highlight reel.
The user is the segmenter and the officiant; the application records what they
decide and never invents a rally or a winner.
## Requirements
### Requirement: Entering an editing session
The application SHALL provide an editing session for a match that opens from the library, loads the match's existing editing records, and works without network access.

#### Scenario: Editing session opened
- **WHEN** the user opens a stored match for editing
- **THEN** the application presents the match's recording with a timeline the user can scrub
- **AND** any rallies, score events, and clips already recorded for that match are shown

#### Scenario: Editing works offline
- **WHEN** an editing session is used while network access is unavailable
- **THEN** scrubbing, marking, scoring, and clip selection all work normally

#### Scenario: Editing session left and resumed
- **WHEN** the user leaves an editing session and opens the match again later
- **THEN** the rallies, score events, and clips recorded in the earlier session are still present

### Requirement: Marking a rally on the timeline
The application SHALL let the user mark a span of the recording as a rally by setting a start and an end from the playback timeline, and SHALL NOT record a rally the user did not mark.

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
- **WHEN** a recording has not been reviewed
- **THEN** the application holds no rally records for it
- **AND** the application makes no claim about where rallies begin or end

### Requirement: Confirming the rally winner
The application SHALL record a rally's winner only from an explicit user action, and SHALL present the choice as one tap per rally.

#### Scenario: Winner confirmed with one tap
- **WHEN** the user taps the left or right side for a rally
- **THEN** that side is recorded as the rally's winner
- **AND** the recorded rally is marked as confirmed

#### Scenario: Winner corrected
- **WHEN** the user changes the winner of a confirmed rally
- **THEN** the rally records the new winner

#### Scenario: Rally left unscored
- **WHEN** a rally has no confirmed winner
- **THEN** the rally is recorded as unscored
- **AND** it does not contribute to the score

#### Scenario: Winner never inferred
- **WHEN** the user has not confirmed a winner for a rally
- **THEN** the application records no winner for it
- **AND** it never derives a winner from the video without the user's confirmation

### Requirement: Score timeline
The application SHALL maintain a running score for a match that is derived from the confirmed winners in rally order, and SHALL let the user correct the score by correcting a rally.

#### Scenario: Score advances with confirmed winners
- **WHEN** the user confirms winners for consecutive rallies
- **THEN** the running score increments for the winning side of each confirmed rally
- **AND** each score change is recorded against the rally that caused it

#### Scenario: Correction rewrites the later score
- **WHEN** the user changes or clears the winner of a rally that earlier rallies follow
- **THEN** the running score and the recorded score events after that rally are recomputed

#### Scenario: Score shown with the match
- **WHEN** the user returns to the library after scoring
- **THEN** the match reports the score reached by the confirmed rallies

#### Scenario: Score is reproducible
- **WHEN** the same set of rallies and confirmed winners is loaded again
- **THEN** the application derives the same running score and the same score at every rally

### Requirement: Choosing and ordering highlight clips
The application SHALL let the user decide which rallies appear in the highlight reel, trim the kept ones, reorder them, and remove them.

#### Scenario: Rally kept as a clip
- **WHEN** the user keeps a rally in the highlight reel
- **THEN** a highlight clip is recorded for that rally with its start and end timestamps
- **AND** the clip records the rally it came from

#### Scenario: Rally left out
- **WHEN** the user removes a clip from the highlight reel
- **THEN** the clip is no longer selected for the reel
- **AND** the rally and its score contribution are unaffected

#### Scenario: Clip trimmed
- **WHEN** the user trims a clip inward from its rally boundaries
- **THEN** the clip records the trimmed start and end
- **AND** the rally's own boundaries are unchanged

#### Scenario: Clips reordered
- **WHEN** the user moves a clip earlier or later in the reel
- **THEN** the reel's playback order changes to match
- **AND** the order is recorded so it survives leaving the session

#### Scenario: Clip order is the user's
- **WHEN** clips exist for a match
- **THEN** their order in the reel is the order the user set
- **AND** it is never re-ranked behind the user's back
