# project-bootstrap Specification

## Purpose
The repository layout, the developer-environment preflight, and the dependency,
model, and asset license register that governs what may ship. This capability
exists so the native engine and the client can be worked on and verified
independently, and so no component enters a build without a recorded
distribution verdict.
## Requirements
### Requirement: Repository workspace layout
The repository SHALL be organized so that the native processing engine can be developed, built, and tested independently of the client, with a documented responsibility for each top-level directory.

#### Scenario: Workspace layout present
- **WHEN** a developer inspects the repository root
- **THEN** a native engine workspace, a client application, model assets, developer tooling, and legal documentation directories are present
- **AND** each directory's responsibility is documented

#### Scenario: Engine builds without the client toolchain
- **WHEN** a developer builds and tests the native engine workspace on a machine that has no client toolchain installed
- **THEN** the engine build and test commands succeed

### Requirement: Developer environment preflight
The repository SHALL provide a preflight check that reports the presence, version, and license-affecting configuration of every toolchain component a build requires, and SHALL report all missing components in a single run instead of stopping at the first one.

#### Scenario: All components present
- **WHEN** the preflight check runs on a fully provisioned machine
- **THEN** it reports each required component as satisfied together with its detected version
- **AND** it completes successfully

#### Scenario: Multiple components missing
- **WHEN** the preflight check runs on a machine missing one or more required components
- **THEN** it lists every missing component together with a remediation step for each
- **AND** it completes without leaving partial build output behind

#### Scenario: Media toolchain licensing reported
- **WHEN** the preflight check locates a media toolchain installation
- **THEN** it reports that installation's license-affecting configuration
- **AND** it flags any configuration that is incompatible with proprietary distribution

### Requirement: Dependency and asset license register
The repository SHALL maintain a register recording every third-party dependency, machine-learning model, pretrained weight file, training dataset, font, audio asset, and video codec that the product uses or distributes, with its license, source, version, and distribution verdict.

#### Scenario: New dependency requires a register entry
- **WHEN** a contributor introduces a new dependency, model, or bundled asset
- **THEN** the register contains an entry for it before the change is complete
- **AND** the entry records its license, source, and whether it may ship in a proprietary build

#### Scenario: Distribution-blocking license flagged
- **WHEN** a registered component carries a license that prevents proprietary distribution
- **THEN** the register marks it as not shippable
- **AND** the register states the specific conflict

#### Scenario: Register reviewed before release
- **WHEN** a release build is prepared
- **THEN** the register contains no unresolved distribution verdict for any shipped component

### Requirement: Developer setup documentation
The repository SHALL document how to provision a development environment and how to run the verification commands for the native engine and the client, so that a new contributor can reach a passing build from a fresh clone.

#### Scenario: Fresh clone to passing build
- **WHEN** a contributor follows the documented setup steps on a fresh clone
- **THEN** the documented verification commands complete successfully

#### Scenario: Toolchain-specific steps distinguished
- **WHEN** a contributor reads the setup documentation
- **THEN** steps that apply only to client work are identified as such
- **AND** the steps needed for engine-only work are identified separately

### Requirement: Verification records name their evidence

Each verification record SHALL state, for every scenario in the specification of
the capability it covers, either the test that covers that scenario or an
explicit manual-only verdict with the reason it cannot be automated, and SHALL
NOT present a one-off run as evidence a reader can rely on.

#### Scenario: A covered scenario names its test
- **WHEN** a verification record is read for a capability that ships
- **THEN** each of its scenario rows names the test that covers the scenario
- **AND** that test exists in the suite the record's commands run

#### Scenario: An uncovered scenario is declared manual-only
- **WHEN** a scenario is not covered by an automated test
- **THEN** its row states that it is manual-only
- **AND** it gives the reason it cannot be automated, such as a device-only interaction or a feature that does not exist yet

#### Scenario: Recorded evidence can be re-run
- **WHEN** a verification record names evidence for a scenario
- **THEN** that evidence is reproduced by a command that exists in the repository
- **AND** re-running the command reproduces the observation rather than a result that was observed once and recorded

#### Scenario: A scenario that cannot be covered yet is named
- **WHEN** a scenario depends on capability the project does not have
- **THEN** the record names that dependency as the reason the scenario is not covered
- **AND** it does not count the scenario as verified

### Requirement: Engine behaviour is covered by the engine suite

The engine workspace SHALL cover, with tests run by the single engine
verification command, every rule whose outcome is a deterministic function of
its inputs — validation, geometry, artifact state, and job lifecycle — and SHALL
NOT leave such a rule resting on evidence produced outside the checkout.

#### Scenario: Rejection rules are exercised
- **WHEN** the engine verification command runs
- **THEN** each rule that rejects an input is exercised with an input that violates it
- **AND** the test asserts the rejection names what was wrong

#### Scenario: Geometry is checked by property rather than by a stored expectation
- **WHEN** the engine verification command runs
- **THEN** the court mapping, the net's placement, the side assignment, and the projection back to the image are checked by properties that a wrong implementation would break
- **AND** a calibration that cannot define a quadrilateral is rejected with an explicit error

#### Scenario: Engine verification needs no client toolchain
- **WHEN** the engine verification command runs on a machine with only the Rust toolchain and a media toolchain
- **THEN** the new tests complete with the rest of the workspace
- **AND** no test requires a device, a simulator, or a network connection

#### Scenario: Rendered output is checked against the source
- **WHEN** a test renders a reel from a generated fixture
- **THEN** it checks the output that the edit list asked for — the clips, their order, their padding, the title card, the overlay, and the audio — rather than only that a file was written
- **AND** it confirms the source recording is unchanged

### Requirement: Client behaviour is covered by the client suite

The client SHALL cover the behaviour the wave-1 and wave-2 screens depend on —
the records a review session produces, the score derived from them, the
calibration stored with a match, and the decisions each screen makes — with
tests that run under the documented client command and need no device.

#### Scenario: Derived state is covered without a device
- **WHEN** the client suite runs
- **THEN** the score derived from confirmed winners, its recomputation after a correction, and the reel's clip order are asserted directly
- **AND** the assertions do not require a screen

#### Scenario: Stored records are covered against real storage
- **WHEN** the client suite runs
- **THEN** the catalog round-trips a match's calibration and the review records through real SQLite
- **AND** deleting a match removes them

#### Scenario: Screen decisions are covered with doubles
- **WHEN** the client suite runs
- **THEN** each wave-1 and wave-2 screen is pumped and its decisions are exercised
- **AND** the screen depends on an interface the test can replace, so nothing in the test needs the native engine, a database, or the platform video player

#### Scenario: The application invents no rally and no winner
- **WHEN** a review session is driven without the user marking a rally or confirming a winner
- **THEN** no rally, winner, or score change is recorded
- **AND** a screen that has no confirmed winner presents no score for it

#### Scenario: Facade calls cross the real binding
- **WHEN** the client suite runs against the engine library
- **THEN** every facade call the client makes — including the calibration calls and cancellation — is exercised through the generated bindings
- **AND** the test loads the real library rather than a double of it

### Requirement: Test fixtures are generated locally

Tests SHALL generate the recordings and media they need with the local media
toolchain into a temporary directory, SHALL leave no fixture behind in the
repository, and MUST NOT reach the network.

#### Scenario: A fixture is generated, not committed
- **WHEN** a test needs a recording, an image, or an audio track
- **THEN** it generates the fixture into a temporary directory
- **AND** no media file is added to the repository

#### Scenario: A missing media toolchain skips rather than fails
- **WHEN** the media toolchain is not installed
- **THEN** the tests that need a generated fixture report that they were skipped, with a diagnostic
- **AND** the tests that need no fixture still run

#### Scenario: Tests run offline
- **WHEN** either suite runs with no network access
- **THEN** every test completes
- **AND** no test depends on a version or a file fetched at run time
