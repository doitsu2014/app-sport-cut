# workspace Specification

## Purpose
Delta for the `workspace` capability: the per-video pipeline toolbar becomes a
single vertical feature rail applying to the selected video, and selecting a
feature shows it in the studio's center pane rather than opening a separate
screen. This capability is introduced by `add-workspace`, which must be
archived or synced before this delta is applied.

## MODIFIED Requirements

### Requirement: Pipeline toolbar
The application SHALL present the pipeline stages in order as a vertical feature
rail that applies to the selected video, SHALL mark each stage with a done,
ready, or blocked state for that video, and SHALL highlight the next actionable
stage.

#### Scenario: Stages shown in order
- **WHEN** a video is selected in a workspace
- **THEN** the stages import, mark court, prepare analysis, player analysis,
      review and score, highlights, and export are presented in that order in the
      feature rail

#### Scenario: Next step highlighted
- **WHEN** a video has completed one or more stages and later stages remain
- **THEN** the first stage that can be done now is highlighted as the next step

#### Scenario: Done stages marked
- **WHEN** a stage's output already exists for a video
- **THEN** that stage is marked done

#### Scenario: Blocked stages marked
- **WHEN** a stage requires an earlier stage that is not done, or the video's
      recording copy is unavailable
- **THEN** that stage is marked blocked

### Requirement: Toolbar opens existing feature screens
The application SHALL show the selected feature for the selected video in the
studio's center pane, SHALL reuse the feature's existing view, and SHALL open the
feature's existing full-screen route only until that feature is hosted in the
studio.

#### Scenario: Selecting a ready stage shows it in the studio
- **WHEN** a user selects a stage that is ready
- **THEN** the studio shows that stage's feature for the selected video in the
      center pane

#### Scenario: Selecting a blocked stage explains why
- **WHEN** a user selects a stage that is blocked
- **THEN** the application shows the missing prerequisite instead of showing a
      feature that cannot work

#### Scenario: Unmigrated feature opens its screen
- **WHEN** a user selects a stage whose feature is not yet hosted in the studio
- **THEN** the application opens that feature's existing screen for the selected
      video
