# workspace-studio Specification

## Purpose
Delta for the `workspace-studio` capability: the right-rail feature selector
becomes a two-section, always-enabled menu in which only the selected feature is
emphasised. A feature is never disabled, and selecting one that lacks its input
opens it with an action to produce the input.

This capability is introduced by `add-workspace-studio`, which is not yet
archived; this delta is applied against that change's spec.

## MODIFIED Requirements

### Requirement: Feature selection drives the center
The application SHALL present the features in the right rail grouped into an
Analysis section and a Studio section under a pinned Play row, SHALL emphasise
only the selected feature, and SHALL show the selected feature in the center
pane. A feature SHALL remain selectable regardless of whether its prerequisites
are satisfied, and SHALL explain any missing input rather than refusing to open.

#### Scenario: Features grouped into sections
- **WHEN** a video is selected
- **THEN** the features are grouped under an Analysis section and a Studio section
- **AND** Play is presented above both sections

#### Scenario: Only the selected feature is emphasised
- **WHEN** the user selects a feature in the right rail
- **THEN** only that feature's row is emphasised
- **AND** no feature row carries a trailing done glyph or a next-step emphasis

#### Scenario: Selecting any feature changes the center
- **WHEN** the user selects a feature in the right rail, including one whose prerequisites are not yet satisfied
- **THEN** the center pane shows that feature for the selected video

#### Scenario: A feature that needs input explains how to unblock it
- **WHEN** the user selects a feature whose required input does not exist yet
- **THEN** the feature explains the missing step and offers an action to produce it
