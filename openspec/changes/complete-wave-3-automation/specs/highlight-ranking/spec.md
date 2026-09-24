## ADDED Requirements

### Requirement: Explainable rally ranking
The application SHALL rank reviewed rallies as highlight recommendations using rally duration, available normalized player movement, available audio intensity, and confirmed score context. Ranking SHALL be reproducible for the same input snapshot and SHALL expose the available contributing signals and any material coverage limitation.

#### Scenario: Complete inputs
- **WHEN** reviewed rallies have valid duration, track movement, audio, and confirmed score context
- **THEN** each eligible rally receives a bounded ranking score and a deterministic rank
- **AND** the reviewer can see the signals contributing to that rank

#### Scenario: Missing optional signal
- **WHEN** audio, movement coverage, or confirmed score context is unavailable for a rally
- **THEN** ranking uses the remaining valid signals and identifies the missing information
- **AND** it does not treat missing audio or an unconfirmed point as a zero-quality rally

#### Scenario: Very short or incomplete rally
- **WHEN** a rally is very short or its analysis coverage is incomplete
- **THEN** the rank reflects a documented quality penalty or uncertainty
- **AND** the rally remains available for manual selection

#### Scenario: Equal scores
- **WHEN** two rallies have equal ranking scores
- **THEN** their order is determined reproducibly by their recording position

### Requirement: Recommendation is separate from reel selection
The application SHALL present ranked rallies as recommendations and SHALL add a clip to the highlight reel only after a user selection. Reranking SHALL NOT change a kept clip's selection, trim, or user-defined order.

#### Scenario: Ranked candidates appear
- **WHEN** the ranking result is shown
- **THEN** unkept rallies appear in recommendation order
- **AND** no new highlight clip is written merely because a rally ranked highly

#### Scenario: User keeps a recommendation
- **WHEN** the user chooses to keep a recommended rally
- **THEN** the application creates a clip for that rally through the existing editing flow
- **AND** the user can trim, reorder, or remove it

#### Scenario: Ranking changes after review
- **WHEN** a winner correction, boundary change, or new analysis changes the recommendation order
- **THEN** kept clips retain their selection, trims, and user-defined order

### Requirement: Freshness and offline operation
Ranking SHALL use only current local rally and media inputs and confirmed score events. It SHALL invalidate or withhold results when the input snapshot changes and SHALL NOT require network access.

#### Scenario: Confirmed score changes
- **WHEN** a user corrects a winner and the later score timeline changes
- **THEN** ranking no longer presents the prior score-context result as current
- **AND** the selected reel remains intact while recommendations are refreshed

#### Scenario: Offline ranking
- **WHEN** the device is offline and the local match inputs are available
- **THEN** highlight recommendations can be computed and reviewed without transferring data off-device
