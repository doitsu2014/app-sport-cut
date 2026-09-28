# workspace Specification

## Purpose
Delta for the `workspace` capability: the per-video pipeline toolbar becomes a
two-section feature menu in which every stage is present and selectable and only
the selected stage is emphasised. The capability is introduced by `add-workspace`,
and re-shaped by `add-workspace-studio`; this delta is applied against those
changes' spec.

## MODIFIED Requirements

### Requirement: Pipeline toolbar
The application SHALL present the pipeline stages as a vertical feature rail that
applies to the selected video, grouped into an Analysis section and a Studio
section under a pinned Play row, SHALL emphasise only the selected stage, and
SHALL keep every stage selectable regardless of state.

#### Scenario: Stages shown grouped
- **WHEN** a video is selected in a workspace
- **THEN** mark court, prepare analysis, and player analysis are grouped under an Analysis section
- **AND** review and score, highlights, and export are grouped under a Studio section
- **AND** Play is presented above both sections

#### Scenario: Only the selected stage is emphasised
- **WHEN** a user selects a stage in the feature rail
- **THEN** only that stage's row is emphasised
- **AND** no stage row carries a trailing done glyph or a next-step emphasis

#### Scenario: A completed stage is muted
- **WHEN** a stage's output already exists for a video
- **THEN** that stage's row is rendered muted without a trailing glyph

#### Scenario: Not-yet-ready stages stay enabled
- **WHEN** a stage requires an earlier stage that is not done, or the video's recording copy is unavailable
- **THEN** that stage remains selectable
- **AND** its row carries no disabled treatment

### Requirement: Toolbar opens existing feature screens
The application SHALL show the selected feature for the selected video in the
studio's center pane for any selected feature, SHALL reuse the feature's existing
view, and SHALL open the feature's existing full-screen route only until that
feature is hosted in the studio.

#### Scenario: Selecting any stage shows it in the studio
- **WHEN** a user selects a stage in the feature rail
- **THEN** the studio shows that stage's feature for the selected video in the center pane

#### Scenario: Selecting a stage that needs input explains why
- **WHEN** a user selects a stage whose required earlier stage is not done
- **THEN** the studio shows the feature with an explanation of the missing step and an action to produce it

#### Scenario: Unmigrated feature opens its screen
- **WHEN** a user selects a stage whose feature is not yet hosted in the studio
- **THEN** the application opens that feature's existing screen for the selected video
