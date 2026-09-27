# workspace Specification

## Purpose
Grouping imported recordings into named workspaces, browsing those workspaces as
the home surface, and the per-video pipeline toolbar that presents the existing
analysis stages in order with done/ready/blocked state and a highlighted next
step.

## ADDED Requirements

### Requirement: Workspace creation and browsing
The application SHALL let a user create a named workspace, SHALL list stored
workspaces as the home surface, and SHALL treat having no workspaces as a normal
empty state rather than an error.

#### Scenario: Workspaces listed on home
- **WHEN** the application opens
- **THEN** stored workspaces are shown with their title
- **AND** the home surface is the workspace list, not a flat match list

#### Scenario: Empty state offers a new workspace
- **WHEN** no workspaces exist
- **THEN** the application presents an empty state offering to create a workspace
      and import a video

#### Scenario: A workspace is created
- **WHEN** a user creates a workspace with a title
- **THEN** the workspace appears in the home list
- **AND** it can be opened to import and manage videos

### Requirement: Import targets a workspace
The application SHALL place an imported recording into a workspace, and SHALL
ensure a workspace exists for the import to target.

#### Scenario: Import into the open workspace
- **WHEN** a user imports a video while a workspace is open
- **THEN** the created match belongs to that workspace
- **AND** the workspace records the association durably

#### Scenario: Import with no workspace
- **WHEN** a user imports a video and no workspace exists
- **THEN** a workspace is created to hold the imported match
- **AND** the match belongs to that workspace

### Requirement: Workspace groups its videos
The application SHALL show the videos belonging to a workspace together, each
with its identifying metadata, and SHALL support multiple videos in one
workspace.

#### Scenario: Videos listed within a workspace
- **WHEN** a user opens a workspace
- **THEN** each match in that workspace is shown with at least its title,
      duration, and creation date
- **AND** a match belonging to another workspace is not shown

#### Scenario: Several videos coexist in one workspace
- **WHEN** a user imports multiple videos into the same workspace
- **THEN** every imported video is listed in that workspace
- **AND** each keeps its own pipeline state

### Requirement: Pipeline toolbar
The application SHALL present, for each video, the pipeline stages in order as a
toolbar, and SHALL mark each stage with a done, ready, or blocked state and
highlight the next actionable stage.

#### Scenario: Stages shown in order
- **WHEN** a video is shown in a workspace
- **THEN** the stages import, mark court, prepare analysis, player analysis,
      review and score, highlights, and export are presented in that order

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

### Requirement: Toolbar stage state derivation
The application SHALL derive a stage's done state from the video's catalog
records for user-authored stages and from the engine artifact manifest for
engine stages, and SHALL derive a stage's readiness from its prerequisites and
recording availability.

#### Scenario: User-authored stages read the catalog
- **WHEN** the court has been calibrated, the score has entries, or clips have
      been kept
- **THEN** the corresponding stage is marked done from the catalog record

#### Scenario: Engine stages read the manifest
- **WHEN** the match manifest reports final analysis, tracks, or export
      artifacts
- **THEN** the corresponding stage is marked done from the manifest

#### Scenario: Unavailable recording blocks
- **WHEN** a video's recording copy is no longer readable
- **THEN** stages that need the recording are marked blocked
- **AND** the video remains listed

### Requirement: Toolbar opens existing feature screens
The application SHALL open the existing feature screen for a video when its
ready stage is selected, and SHALL reuse those screens unchanged.

#### Scenario: Selecting a ready stage navigates
- **WHEN** a user selects a stage that is ready
- **THEN** the application opens that stage's existing feature screen for the
      video

#### Scenario: Selecting a blocked stage explains why
- **WHEN** a user selects a stage that is blocked
- **THEN** the application shows the missing prerequisite instead of navigating
      to a screen that cannot work

### Requirement: Workspace deletion
The application SHALL delete a workspace together with its contained videos,
using the existing per-match deletion prompts, and SHALL never delete a file the
user originally selected.

#### Scenario: Deleting a workspace removes its videos
- **WHEN** a user deletes a workspace
- **THEN** its contained videos are deleted with the existing prompts for
      derived artifacts and the app-owned recording copy
- **AND** the workspace itself is removed from the home list
- **AND** the user's original files are never deleted

### Requirement: Migration preserves existing matches
The application SHALL, when upgrading from a schema without workspaces, keep
every existing match and make it reachable from a workspace.

#### Scenario: Existing matches land in a workspace
- **WHEN** the catalog is upgraded to the schema with workspaces
- **THEN** a default workspace is created
- **AND** every previously stored match belongs to it
- **AND** the matches are reachable from the home surface
