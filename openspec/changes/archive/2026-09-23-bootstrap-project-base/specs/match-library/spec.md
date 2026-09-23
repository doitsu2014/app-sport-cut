## ADDED Requirements

### Requirement: Match creation and local video import
The application SHALL allow a user to create a match from a video already stored on the device, recording the match in the local catalog with a reference to the original file rather than a duplicate copy.

#### Scenario: Import creates a match record
- **WHEN** a user selects a local video file to import
- **THEN** a match record is created with its title, duration, creation time, and a reference to the original file
- **AND** media metadata is populated from the imported file

#### Scenario: Original recording not duplicated
- **WHEN** a match is created from a local video file
- **THEN** the original file is referenced in place
- **AND** no duplicate copy of the recording is stored by default

#### Scenario: Import cannot access the file
- **WHEN** the selected file cannot be read because access is denied or the file no longer exists
- **THEN** the application reports a clear error
- **AND** no incomplete match record remains in the catalog

### Requirement: Match library browsing
The application SHALL present stored matches with their identifying metadata, and SHALL treat an empty library as a normal state rather than an error.

#### Scenario: Matches listed
- **WHEN** the user opens the match library
- **THEN** each stored match is shown with at least its title, duration, and creation date

#### Scenario: Empty library
- **WHEN** no matches have been created
- **THEN** the application presents an empty state offering to import a video

### Requirement: Local video playback
The application SHALL play back an imported recording from local storage with standard transport controls, and SHALL function without network access.

#### Scenario: Playback works offline
- **WHEN** the user plays an imported recording while network access is unavailable
- **THEN** playback starts and transport controls operate normally

#### Scenario: Unsupported media reported
- **WHEN** playback cannot start because the recording uses an unsupported format or codec
- **THEN** the application surfaces an explicit message identifying the problem
- **AND** the match remains listed in the library

### Requirement: Local catalog ownership and schema
The application SHALL own the local catalog and SHALL store match, rally, score event, and highlight clip records in a versioned local database schema consistent with the product data model.

#### Scenario: Schema changes are versioned
- **WHEN** the catalog schema changes
- **THEN** the change is applied as a versioned migration
- **AND** existing match records survive the migration

#### Scenario: Catalog works offline
- **WHEN** the catalog is read or written while network access is unavailable
- **THEN** all catalog operations succeed

#### Scenario: Match deletion
- **WHEN** a user deletes a match
- **THEN** its catalog records are removed
- **AND** the user is asked whether to also delete the associated derived artifacts
