# match-library Specification

## Purpose
Delta for the `match-library` capability: a match now belongs to a workspace,
import records that membership, the catalog schema gains a workspaces table and
a workspace association, and match browsing happens within a workspace.

## MODIFIED Requirements

### Requirement: Match creation and local video import
The application SHALL allow a user to create a match from a video already stored on the device, taking durable custody of the recording into app-owned storage at import time, recording a reference to that app-owned copy in the local catalog, recording the workspace the match belongs to, and leaving the user's original file unmodified.

#### Scenario: Import creates a match record
- **WHEN** a user selects a local video file to import
- **THEN** a match record is created with its title, duration, creation time, and a reference to the app-owned copy of the recording
- **AND** the match belongs to a workspace
- **AND** media metadata is populated from the imported file

#### Scenario: Original recording left untouched
- **WHEN** a match is created from a local video file
- **THEN** the file the user selected is byte-for-byte unchanged and remains at its original location
- **AND** it is never moved, renamed, or deleted by the import

#### Scenario: Imported recording survives an operating-system purge
- **WHEN** a recording is imported from a source the platform hands back as a temporary or cache copy
- **THEN** the match's recording is a copy the application owns
- **AND** after the application restarts and the platform has purged its temporary and cache directories, the match's recording is still readable

#### Scenario: Transient picker path is not stored as the recording
- **WHEN** the platform picker returns a path outside app-owned storage
- **THEN** the catalog does not record that transient path as the match's recording

#### Scenario: Import cannot access the file
- **WHEN** the selected file cannot be read because access is denied or the file no longer exists
- **THEN** the application reports a clear error
- **AND** no incomplete match record remains in the catalog
- **AND** no partial copy of the recording is left in app-owned storage

### Requirement: Match library browsing
The application SHALL present a workspace's stored matches with their identifying metadata, SHALL surface the media metadata read at import, SHALL indicate a match whose recording can no longer be read, and SHALL treat an empty workspace as a normal state rather than an error.

#### Scenario: Matches listed within a workspace
- **WHEN** the user opens a workspace
- **THEN** each stored match in that workspace is shown with at least its title, duration, and creation date

#### Scenario: Imported media metadata shown
- **WHEN** a match whose recording was probed at import is listed
- **THEN** its resolution, frame rate, and whether it has an audio track are available with the match

#### Scenario: Unavailable recording reported
- **WHEN** a stored match's recording has become unreadable
- **THEN** the match is still listed and is marked as unavailable
- **AND** no other match in the workspace is hidden or removed

#### Scenario: Empty workspace
- **WHEN** a workspace has no matches
- **THEN** the application presents an empty state offering to import a video

### Requirement: Local catalog ownership and schema
The application SHALL own the local catalog and SHALL store workspace, match, court calibration, rally, score event, highlight clip, export settings, and exported video records in a versioned local database schema consistent with the product data model.

#### Scenario: Schema changes are versioned
- **WHEN** the catalog schema changes
- **THEN** the change is applied as a versioned migration
- **AND** existing match records survive the migration

#### Scenario: Catalog works offline
- **WHEN** the catalog is read or written while network access is unavailable
- **THEN** all catalog operations succeed

#### Scenario: Workspace membership stored
- **WHEN** a match is created or opened
- **THEN** the match records the workspace it belongs to
- **AND** the workspace association survives a restart

#### Scenario: Editing records belong to their match
- **WHEN** a rally, score event, clip, export setting, or court calibration is written
- **THEN** it is associated with the match it belongs to
- **AND** a record cannot be created for a match that does not exist

#### Scenario: Court calibration owned by the catalog
- **WHEN** a match is calibrated
- **THEN** the calibration is stored as part of that match's record
- **AND** it is readable without opening the engine or reading the match's artifact directory

#### Scenario: Existing matches load without a calibration
- **WHEN** a stored match that was created before calibration existed is loaded
- **THEN** it loads normally and reports that it has no calibration
- **AND** no other field of that match changes

#### Scenario: Clip records a clip's order and origin
- **WHEN** a highlight clip is stored
- **THEN** the catalog records its position in the reel
- **AND** it records the rally the clip was made from when the clip came from one

#### Scenario: Export settings persisted
- **WHEN** the user chooses music or a title for a match's export
- **THEN** those choices are stored so a later session shows them again

#### Scenario: Match deletion
- **WHEN** a user deletes a match
- **THEN** its catalog records are removed, including its court calibration
- **AND** the user is asked whether to also delete the associated derived artifacts
- **AND** the user is asked whether to also delete the app-owned copy of the recording
- **AND** the file the user originally selected is never deleted
