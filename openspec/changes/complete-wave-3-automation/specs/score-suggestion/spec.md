## ADDED Requirements

### Requirement: Evidence-based side suggestions
The application SHALL offer a left or right winner suggestion for a reviewed rally only when a validated local side cue supports it. Each offered suggestion SHALL include its source and a bounded confidence indication. When evidence is missing, contradictory, or below the accepted threshold, the application SHALL explicitly offer no suggestion. It SHALL NOT claim that a suggestion is an official point decision.

#### Scenario: Supported side cue
- **WHEN** a reviewed rally has sufficient validated evidence favoring one side
- **THEN** the review shows that side as a suggestion with confidence and a brief source explanation
- **AND** both side choices and skip remain available to the user

#### Scenario: Weak or contradictory evidence
- **WHEN** the available signals cannot reliably distinguish a winner
- **THEN** the review shows no suggested side and explains the uncertainty
- **AND** the user can still choose left, right, or skip

#### Scenario: No valid winner cue
- **WHEN** a rally has only duration, movement amount, a previous confirmed winner, or score context, without a validated side cue
- **THEN** the engine abstains rather than guessing a winner

### Requirement: Suggestions never change the score
The engine SHALL keep side suggestions separate from confirmed winners, and the application SHALL change score records only after an explicit user choice. A later analysis run SHALL NOT overwrite a confirmed or corrected winner.

#### Scenario: Suggestion appears
- **WHEN** analysis offers a side for an unscored rally
- **THEN** the rally remains unscored
- **AND** the score timeline and overlay remain based only on confirmed winners

#### Scenario: User confirms or corrects
- **WHEN** the user taps a side, whether it matches the suggestion or not
- **THEN** that chosen side becomes the confirmed winner
- **AND** the score timeline is recomputed from confirmed rallies in order

#### Scenario: User skips
- **WHEN** the user skips a suggested rally
- **THEN** no winner or score event is created for it

#### Scenario: Analysis rerun after confirmation
- **WHEN** a new suggestion differs from a previously confirmed winner
- **THEN** the confirmed winner and its score event remain unchanged
- **AND** the new suggestion does not replace the user's decision

### Requirement: Fresh and local analysis
Score suggestions SHALL be derived from local inputs identified by rally boundaries, calibration, tracking and other evidence generations, and algorithm version. The application SHALL NOT present a stale result as current, and analysis SHALL work without transferring media or review data to a network service.

#### Scenario: Rally or evidence changed
- **WHEN** a rally boundary, calibration, track generation, or side-evidence input changes
- **THEN** the prior suggestion for that rally is marked stale or withheld until recomputed

#### Scenario: Offline review
- **WHEN** the device is offline and local inputs are available
- **THEN** scoring suggestions can be computed and reviewed locally
