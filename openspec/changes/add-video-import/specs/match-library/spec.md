## MODIFIED Requirements

### Requirement: Match creation and local video import
The application SHALL allow a user to create a match from a video already stored on the device, taking durable custody of the recording into app-owned storage at import time, recording a reference to that app-owned copy in the local catalog, and leaving the user's original file unmodified.

#### Scenario: Import creates a match record
- **WHEN** a user selects a local video file to import
- **THEN** a match record is created with its title, duration, creation time, and a reference to the app-owned copy of the recording
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
The application SHALL present stored matches with their identifying metadata, SHALL surface the media metadata read at import, SHALL indicate a match whose recording can no longer be read, and SHALL treat an empty library as a normal state rather than an error.

#### Scenario: Matches listed
- **WHEN** the user opens the match library
- **THEN** each stored match is shown with at least its title, duration, and creation date

#### Scenario: Imported media metadata shown
- **WHEN** a match whose recording was probed at import is listed
- **THEN** its resolution, frame rate, and whether it has an audio track are available with the match

#### Scenario: Unavailable recording reported
- **WHEN** a stored match's recording has become unreadable
- **THEN** the match is still listed and is marked as unavailable
- **AND** no other match in the library is hidden or removed

#### Scenario: Empty library
- **WHEN** no matches have been created
- **THEN** the application presents an empty state offering to import a video

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
- **AND** the user is asked whether to also delete the app-owned copy of the recording
- **AND** the file the user originally selected is never deleted

## ADDED Requirements

### Requirement: Import progress and single-flight
The application SHALL ensure at most one import runs at a time, SHALL make an in-progress import visible to the user, and SHALL leave the library unchanged when an import is cancelled before it completes.

#### Scenario: Import in progress is visible
- **WHEN** an import is copying a recording or reading its metadata
- **THEN** the application shows that an import is in progress

#### Scenario: Second import attempt is not started
- **WHEN** an import is already running and the user asks to import another recording
- **THEN** no second import is started

#### Scenario: Cancelled import leaves nothing behind
- **WHEN** a user cancels an import before it completes
- **THEN** no match record is created
- **AND** no partial copy of the recording remains in app-owned storage

### Requirement: Import failure reporting
The application SHALL report a distinct, user-facing message for every import failure mode, and SHALL leave no partial state behind for any of them.

#### Scenario: Unsupported recording reported
- **WHEN** a selected file cannot be read as video by the engine
- **THEN** the application reports that the recording is unsupported, naming the file
- **AND** no match record is created

#### Scenario: Insufficient storage reported
- **WHEN** the app-owned copy cannot be written because the device is out of space
- **THEN** the application reports that the recording could not be stored
- **AND** no partial copy is left behind

#### Scenario: Picker failure reported
- **WHEN** the platform picker fails instead of returning a file, for example because access was denied
- **THEN** the application presents that failure as a message rather than an unhandled error
