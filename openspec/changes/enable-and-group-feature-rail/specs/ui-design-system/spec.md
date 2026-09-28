# ui-design-system Specification

## Purpose
Delta for the `ui-design-system` capability: the feature rail's stage-state
rendering becomes selection-only. The done check glyph and the primary-colour
next stage are removed; only the selected stage is emphasised, and a completed
stage is muted without a glyph.

This capability is introduced by `align-ui-to-design-system`, which is not yet
archived; this delta is applied against that change's spec.

## MODIFIED Requirements

### Requirement: Stage-state rendering
The application SHALL emphasise only the selected stage in the feature rail, and
SHALL NOT mark a completed stage with a trailing glyph or a next stage with the
primary colour.

#### Scenario: Only the selected stage is emphasised
- **WHEN** a stage is selected in the feature rail
- **THEN** its row uses the secondary-container background
- **AND** no stage row shows a trailing check glyph
- **AND** no non-selected stage is emphasised

#### Scenario: A completed stage is muted
- **WHEN** a stage's output exists
- **THEN** the stage row uses the muted on-surface-variant colour without a glyph
