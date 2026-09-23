## MODIFIED Requirements

### Requirement: Local catalog ownership and schema
The application SHALL own the local catalog and SHALL store match, rally, score event, highlight clip, export settings, and exported video records in a versioned local database schema consistent with the product data model.

#### Scenario: Schema changes are versioned
- **WHEN** the catalog schema changes
- **THEN** the change is applied as a versioned migration
- **AND** existing match records survive the migration

#### Scenario: Catalog works offline
- **WHEN** the catalog is read or written while network access is unavailable
- **THEN** all catalog operations succeed

#### Scenario: Editing records belong to their match
- **WHEN** a rally, score event, clip, or export setting is written
- **THEN** it is associated with the match it belongs to
- **AND** a record cannot be created for a match that does not exist

#### Scenario: Clip records a clip's order and origin
- **WHEN** a highlight clip is stored
- **THEN** the catalog records its position in the reel
- **AND** it records the rally the clip was made from when the clip came from one

#### Scenario: Export settings persisted
- **WHEN** the user chooses music or a title for a match's export
- **THEN** those choices are stored so a later session shows them again

#### Scenario: Match deletion
- **WHEN** a user deletes a match
- **THEN** its catalog records are removed
- **AND** the user is asked whether to also delete the associated derived artifacts
- **AND** the user is asked whether to also delete the app-owned copy of the recording
- **AND** the file the user originally selected is never deleted
