# person-detection Specification

## Purpose
Delta for the `person-detection` capability: a packaged macOS app resolves the
detector runtime and model from inside the app bundle and passes them to the
engine over the bridge, with the environment-variable lookup retained only as a
development fallback.

## ADDED Requirements

### Requirement: Bundled inference asset resolution
The application SHALL resolve the detector runtime and model weights from the
macOS app bundle for a packaged build, SHALL supply those paths to the engine
when starting player analysis, and SHALL use the environment-variable paths only
as a development fallback.

#### Scenario: Packaged app locates bundled assets
- **WHEN** player analysis starts in a packaged app
- **THEN** the runtime and model paths are resolved from the app bundle and
      passed to the engine
- **AND** the engine loads the detector from those bundled files

#### Scenario: Development fallback via environment variables
- **WHEN** player analysis starts outside a packaged bundle and no explicit
      paths are supplied
- **THEN** the engine uses the environment-variable runtime and model paths

#### Scenario: Bundled assets are missing
- **WHEN** a packaged app's runtime or model file cannot be found in the bundle
- **THEN** the engine reports an actionable unavailable result
- **AND** it does not publish a final detection or track artifact

### Requirement: Shipping build bundles the inference assets
The application SHALL include the TensorFlow Lite runtime, the approved model
weights, and the engine library inside the app bundle so a packaged build runs
player analysis with no external file or environment.

#### Scenario: Assets ship inside the app
- **WHEN** the macOS app is packaged
- **THEN** the runtime and model weights are inside the app bundle
- **AND** the engine library is inside the bundle's Frameworks directory

#### Scenario: Detector compiled into the shipping library
- **WHEN** the shipping macOS engine library is built
- **THEN** the detector is enabled by default rather than as an opt-in eval
      feature
