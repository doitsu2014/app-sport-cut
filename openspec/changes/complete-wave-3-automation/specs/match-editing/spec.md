## MODIFIED Requirements

### Requirement: Confirming the rally winner
The application SHALL record a rally's winner only from an explicit user action, SHALL present the choice as one tap per rally, and SHALL distinguish any machine-suggested side from a confirmed winner.

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

#### Scenario: Winner never inferred as fact
- **WHEN** the user has not confirmed a winner for a rally, whether a side was suggested or not
- **THEN** the application records no winner for it
- **AND** it never derives a confirmed winner from the video without the user's confirmation

#### Scenario: Suggestion shown separately
- **WHEN** a side suggestion is available for an unscored rally
- **THEN** the review identifies it as a suggestion with its confidence and source
- **AND** left, right, and skip remain explicit user actions
