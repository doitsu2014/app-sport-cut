# ui-design-system Specification

## Purpose
The cross-screen visual contract: theme-role discipline, stage-state rendering,
tabular numerals, the artifact ledger table, and the component states that make
a screen conform to the written design system rather than to a developer's
judgement.

## ADDED Requirements

### Requirement: Stage-state rendering
The application SHALL distinguish a done pipeline stage from a blocked one by a
check glyph, not by lightness alone, SHALL render a ready stage in the primary
colour, and SHALL show the selected stage on a secondary-container background.

#### Scenario: Done stages carry a check
- **WHEN** a stage's output exists
- **THEN** the stage row shows a trailing check glyph
- **AND** the check is visible without relying on the row's text colour

#### Scenario: Ready stage is highlighted
- **WHEN** one stage is ready and later stages are blocked
- **THEN** the ready stage uses the primary colour and a bold label

### Requirement: Scoreboard serving highlight
The application SHALL render the serving side's score numeral in the primary
colour while the non-serving side stays on-surface.

#### Scenario: Serving side is green
- **WHEN** one side serves next
- **THEN** that side's score numeral is the primary colour
- **AND** the other side's numeral is unchanged

### Requirement: Winner button states
The application SHALL render a picked winner side with a primary border and
tint, and a suggested winner side with a dashed border and a bullet prefix.

#### Scenario: Picked side
- **WHEN** a rally's winner is confirmed
- **THEN** the winning side's button has a primary border and a primary tint

#### Scenario: Suggested side
- **WHEN** the engine suggests a side that is not yet confirmed
- **THEN** the suggested button has a dashed border and a bullet prefix

### Requirement: Artifact ledger table
The application SHALL present a match's artifacts as a table with kind, path,
state, and size columns, and SHALL render each state as a chip: ready, partial,
or missing.

#### Scenario: Artifacts listed as a table
- **WHEN** a match's artifacts are shown
- **THEN** each artifact is a row in a table with kind, path, state, and size
- **AND** the state is a chip whose colour differs by state

#### Scenario: Missing state is a warning
- **WHEN** an artifact is missing
- **THEN** its state chip uses the warn styling rather than the ready styling

### Requirement: Tracking legend colour-coding
The application SHALL colour-code the player-analysis legend words to match the
track colours, at a lightness that holds contrast on the surface.

#### Scenario: Legend words are tinted
- **WHEN** the player-analysis legend is shown
- **THEN** the court-half words are tinted to their track colours
- **AND** the tint is darkened enough to remain readable

### Requirement: Tabular numerals
The application SHALL render score, duration, timecode, and clip numerals with
tabular figures so columns of numbers do not shift width.

#### Scenario: Numerals stay fixed-width
- **WHEN** a score, duration, or timecode numeral is shown
- **THEN** it uses tabular figures
- **AND** no bundled font is introduced

### Requirement: Selected video row and hover-reveal delete
The application SHALL show the selected video row on a secondary-container
background and SHALL reveal the row's delete action only on hover.

#### Scenario: Selected row tinted
- **WHEN** a video is selected in the studio rail
- **THEN** its row uses the secondary-container background

#### Scenario: Delete revealed on hover
- **WHEN** a video row is not hovered
- **THEN** its delete action is not visible
- **AND** hovering the row reveals it

### Requirement: Reel-ready card emphasis
The application SHALL render the finished-reel card with a primary border and a
primary check icon.

#### Scenario: Finished reel highlighted
- **WHEN** a render has finished
- **THEN** the reel-ready card has a primary border and a primary check icon
