## ADDED Requirements

### Requirement: Ranking rallies into a highlight score
The engine SHALL rank a caller-supplied list of rallies into a highlight order,
returning a score in `0.0..=1.0` and a `1`-based rank for each, computed from
each rally's duration, optional motion quality, and score context, and SHALL NOT
read the application's catalog to do so.

#### Scenario: Rallies scored and ordered
- **WHEN** the application sends a list of rallies with their start, end,
  motion (when known), and score context
- **THEN** the engine returns one score and rank per rally
- **AND** the best-scoring rally has rank `1`
- **AND** no score falls outside `0.0..=1.0`

#### Scenario: Motion unknown falls back to neutral
- **WHEN** a rally is sent without a motion quality
- **THEN** the rally is still ranked using its duration and score context
- **AND** the ranking does not fail

#### Scenario: Ranking is independent of the catalog
- **WHEN** the same rally list is ranked by two different callers
- **THEN** both receive the same scores and ranks

#### Scenario: Unscored rally carries no score context
- **WHEN** a rally has no confirmed winner
- **THEN** its score context contributes nothing to its highlight score

#### Scenario: Invalid rally rejected
- **WHEN** a rally's end is not after its start, or a signal is outside its
  `0.0..=1.0` range
- **THEN** the engine rejects the request naming the offending rally
- **AND** no ranking is returned

### Requirement: Suggesting highlights in the application
The application SHALL surface the ranked rallies so the best candidates come
first, SHALL let the user keep the best N rallies with a single action, and
SHALL NOT change the reel's order or contents without an explicit user action.

#### Scenario: Ranked candidates shown
- **WHEN** a match has rallies
- **THEN** the highlights screen shows a suggested order for them with the
  best-scoring first
- **AND** the user's existing reel order is unchanged

#### Scenario: Keep the best N
- **WHEN** the user asks to keep the best N rallies
- **THEN** the top N ranked rallies are added to the reel
- **AND** rallies already in the reel are not duplicated

#### Scenario: Ranking never forces a reel
- **WHEN** rallies are ranked
- **THEN** no clip is kept, removed, or reordered until the user acts

### Requirement: Accepted suggestions keep their motion quality
The application SHALL record a rally accepted from an analysis suggestion with
that suggestion's quality as the rally's confidence, and SHALL leave a
hand-marked rally's confidence unset.

#### Scenario: Suggestion quality recorded
- **WHEN** the user accepts a rally suggestion
- **THEN** the created rally records the suggestion's quality as its confidence

#### Scenario: Manual rally has no confidence
- **WHEN** the user marks a rally by hand
- **THEN** the rally has no recorded confidence
