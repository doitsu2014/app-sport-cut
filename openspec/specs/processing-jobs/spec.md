# processing-jobs Specification

## Purpose
The long-running job model: a stable job identity, a defined lifecycle,
stage-labelled progress that does not go backwards, cooperative cancellation
that marks partial output as non-final, checkpoints that let an interrupted job
resume from the last completed stage, and admission control that runs at most
one resource-intensive job at a time.
## Requirements
### Requirement: Job lifecycle
The engine SHALL expose long-running work as an explicit job with a stable identifier and a defined lifecycle covering pending, running, completed, cancelled, and failed states, and SHALL report the current state on request.

#### Scenario: Progress reported while running
- **WHEN** a job is running
- **THEN** the engine reports the current stage and progress within that job

#### Scenario: Job completes
- **WHEN** a job finishes all of its stages successfully
- **THEN** the job is reported as completed
- **AND** the artifacts it produced are recorded

#### Scenario: Job fails
- **WHEN** a stage fails and cannot continue
- **THEN** the job is reported as failed with the failing stage and a human-readable reason

### Requirement: Job cancellation
The engine SHALL allow a running job to be cancelled, and SHALL mark any partially produced output as non-final so that incomplete artifacts are never presented as results.

#### Scenario: Cancellation stops work
- **WHEN** a running job is cancelled
- **THEN** the engine stops further work for that job

#### Scenario: Partial output not presented as final
- **WHEN** a job is cancelled after producing partial artifacts
- **THEN** those artifacts are marked non-final
- **AND** the match is not reported as analyzed

### Requirement: Checkpoint and resume
The engine SHALL persist progress checkpoints so that an interrupted job resumes from the last completed stage instead of repeating completed work.

#### Scenario: Resume after interruption
- **WHEN** a job is interrupted and later resumed
- **THEN** the engine continues from the last completed checkpoint
- **AND** stages recorded as complete are not re-executed

#### Scenario: Checkpoints survive application restart
- **WHEN** the host application restarts after an interrupted job
- **THEN** the completed stages remain discoverable from the match directory
- **AND** the job can be resumed or explicitly abandoned

### Requirement: Single concurrent heavy job
The engine SHALL run at most one resource-intensive analysis job at a time, and SHALL reject or defer further requests rather than running them concurrently.

#### Scenario: Second job for the same match rejected
- **WHEN** a job is already active for a match and another job is requested for that same match
- **THEN** the engine rejects the new request with an explicit reason

#### Scenario: Conflicting request not run concurrently
- **WHEN** a resource-intensive job is already active and another is requested
- **THEN** the engine defers or rejects the new request instead of running both at the same time

### Requirement: Progress reporting semantics
The engine SHALL report job progress per stage with a stage label and a progress value that does not decrease within a stage, so that user interfaces can present stable progress.

#### Scenario: Progress does not decrease within a stage
- **WHEN** successive progress updates are observed for a single stage
- **THEN** the reported progress value does not decrease

#### Scenario: Stage transitions identified
- **WHEN** a job advances from one stage to the next
- **THEN** the reported stage label changes to reflect the new stage
