# project-bootstrap Specification

## Purpose
The repository layout, the developer-environment preflight, and the dependency,
model, and asset license register that governs what may ship. This capability
exists so the native engine and the mobile client can be worked on and verified
independently, and so no component enters a build without a recorded
distribution verdict.
## Requirements
### Requirement: Repository workspace layout
The repository SHALL be organized so that the native processing engine can be developed, built, and tested independently of the mobile client, with a documented responsibility for each top-level directory.

#### Scenario: Workspace layout present
- **WHEN** a developer inspects the repository root
- **THEN** a native engine workspace, a mobile client application, model assets, developer tooling, and legal documentation directories are present
- **AND** each directory's responsibility is documented

#### Scenario: Engine builds without the mobile client toolchain
- **WHEN** a developer builds and tests the native engine workspace on a machine that has no mobile client toolchain installed
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
The repository SHALL document how to provision a development environment and how to run the verification commands for the native engine and the mobile client, so that a new contributor can reach a passing build from a fresh clone.

#### Scenario: Fresh clone to passing build
- **WHEN** a contributor follows the documented setup steps on a fresh clone
- **THEN** the documented verification commands complete successfully

#### Scenario: Toolchain-specific steps distinguished
- **WHEN** a contributor reads the setup documentation
- **THEN** steps that apply only to mobile client work are identified as such
- **AND** the steps needed for engine-only work are identified separately
