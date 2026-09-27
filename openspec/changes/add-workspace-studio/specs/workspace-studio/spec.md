# workspace-studio Specification

## Purpose
The three-pane workspace studio: videos on the left, one shared video preview in
the center, and the features as a vertical rail on the right. Features become
lenses on the shared preview, hosted in the center pane, with per-match feature
state that survives switching videos.

## ADDED Requirements

### Requirement: Studio layout
The application SHALL present an open workspace as a three-pane studio: the
workspace's videos in a left rail, the selected video's preview in the center,
and the features in a right rail.

#### Scenario: Three panes shown
- **WHEN** a user opens a workspace
- **THEN** the videos are listed in a left rail
- **AND** the selected video's preview is shown in the center
- **AND** the features are listed in a right rail

#### Scenario: Empty workspace
- **WHEN** a workspace has no videos
- **THEN** the studio presents an empty state offering to import a video

### Requirement: Shared preview per selected video
The application SHALL own one playback controller for the selected video and
reuse it across the features that act on that video, and SHALL replace the
preview when the selected video changes.

#### Scenario: One preview reused across features
- **WHEN** the user switches between features for the same selected video
- **THEN** the center preview continues to show the same video rather than
      restarting playback for each feature

#### Scenario: Preview follows the selected video
- **WHEN** the user selects a different video
- **THEN** the center preview shows the newly selected video

### Requirement: Feature selection drives the center
The application SHALL list the features in the right rail with their done, ready,
or blocked state for the selected video, SHALL highlight the next actionable
feature, and SHALL show the selected feature in the center pane.

#### Scenario: Features listed with state
- **WHEN** a video is selected
- **THEN** each feature is marked done, ready, or blocked for that video
- **AND** the next actionable feature is highlighted

#### Scenario: Selecting a feature changes the center
- **WHEN** the user selects a feature in the right rail
- **THEN** the center pane shows that feature for the selected video

### Requirement: Feature state survives switching videos
The application SHALL preserve a feature's in-progress state for a video when the
user switches to another video and back.

#### Scenario: State preserved across a switch
- **WHEN** the user is partway through a feature on one video, switches to a
      different video, and switches back
- **THEN** the first video's in-progress state is restored rather than reset

### Requirement: Preview-native features are hosted in the center
The application SHALL host the features that act directly on playback — playback
and court calibration — as views over the shared preview in the center pane,
without opening a separate screen.

#### Scenario: Playback shown in the center
- **WHEN** the playback feature is selected
- **THEN** transport controls appear over the shared preview in the center pane

#### Scenario: Calibration shown over the preview
- **WHEN** the court-calibration feature is selected
- **THEN** the court corner controls appear over the shared preview in the
      center pane

### Requirement: Non-migrated features keep their route
The application SHALL, until a feature is hosted in the studio, open that
feature's existing full-screen route when it is selected.

#### Scenario: Unmigrated feature opens its screen
- **WHEN** a feature that has not yet been embedded in the studio is selected
- **THEN** the application opens that feature's existing screen for the selected
      video
