## ADDED Requirements

### Requirement: Client-observable job handles
The engine SHALL return a handle when it starts a long-running job, and SHALL let the client read that job's status and request its cancellation while the work is still running, so that a caller is never required to block for the whole run to learn how it went.

#### Scenario: Starting long work returns a handle
- **WHEN** the client starts an import, a regeneration, or an export
- **THEN** the engine returns a job identifier before the work finishes

#### Scenario: Progress read while running
- **WHEN** the client reads the status of a job that is running
- **THEN** the engine reports the job's state, its current stage, and the progress within that stage

#### Scenario: Cancellation requested from the client
- **WHEN** the client cancels a running job by its handle
- **THEN** the engine stops further work for that job
- **AND** the job reports itself as cancelled

#### Scenario: Terminal state readable after the call returns
- **WHEN** a job finishes, fails, or is cancelled
- **THEN** the client can still read its terminal state and any failure reason by its handle

#### Scenario: Unknown handle reported
- **WHEN** the client asks about a job identifier the engine does not know
- **THEN** the engine reports that explicitly rather than returning a fabricated status

#### Scenario: Admission reason reported
- **WHEN** a job cannot start because another heavy job is already running
- **THEN** the engine reports why it was rejected
- **AND** no job handle is handed out for work that will not run

