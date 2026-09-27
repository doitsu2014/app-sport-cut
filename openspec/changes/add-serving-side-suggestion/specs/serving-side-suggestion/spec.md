## ADDED Requirements

### Requirement: Deriving the serving side
The engine SHALL derive, for an ordered caller-supplied list of rallies, which
side served each rally, using the rule that the winner of a rally serves the
next one, and SHALL NOT read the application's catalog to do so.

#### Scenario: Serving side follows the previous winner
- **WHEN** the application sends rallies in order with their confirmed winners
- **THEN** each rally after the first is assigned the winner of the rally
  immediately before it as its serving side

#### Scenario: First rally has no server
- **WHEN** the first rally in the list is considered
- **THEN** it is assigned no serving side
- **AND** no suggestion is made for it

#### Scenario: Unscored previous rally hides the server
- **WHEN** a rally's immediately previous rally has no confirmed winner
- **THEN** that rally is assigned no serving side

#### Scenario: Derivation is independent of the catalog
- **WHEN** the same rally list is derived by two different callers
- **THEN** both receive the same serving sides

#### Scenario: Invalid rally rejected
- **WHEN** a rally has no identifier
- **THEN** the engine rejects the request naming the offending rally
- **AND** no serving sides are returned

### Requirement: Proposing the server as the winner
The application SHALL propose the serving side as the tentative winner on
rallies that have no confirmed winner, and SHALL NOT record that winner until
the user confirms it.

#### Scenario: Suggestion shown for an unscored rally
- **WHEN** an unscored rally has a serving side
- **THEN** the score screen shows that side as the suggested winner

#### Scenario: Suggestion never recorded automatically
- **WHEN** a rally shows a suggested winner
- **THEN** no winner is recorded and the score does not move until the user
  confirms or chooses the other side

#### Scenario: No suggestion without a server
- **WHEN** a rally has no serving side
- **THEN** the score screen shows no suggested winner for it

### Requirement: Showing the serving side on the scoreboard
The application SHALL show which side serves next on the scoreboard, derived
from the winner of the last confirmed rally, and SHALL show no server before
any rally is confirmed.

#### Scenario: Server shown after a confirmed rally
- **WHEN** at least one rally has a confirmed winner
- **THEN** the scoreboard marks the winning side of the last confirmed rally as
  serving next

#### Scenario: No server before the first confirmation
- **WHEN** no rally has a confirmed winner
- **THEN** the scoreboard shows no serving side
