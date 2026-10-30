# Design Decisions — Court Calibration (Feature 3)

Status: Ideate / Design Pattern Selection
Intent: `261030-implement-03-court`
Date: 2026-10-30
Inputs: `architecture-doc.md`, `requirements.md`.

Each record: context, decision, alternatives, consequences, status. Preferred
existing patterns unless a deviation is justified.

## DD-CAL-01 — Renderer consumes a validated engine model

- **Context.** The engine returns `CourtGeometryDto` (outline + net) and the
  client must draw it. The client currently derives the net itself.
- **Decision.** Treat the engine response as the single source of truth.
  Convert it at the host boundary into a small immutable value model
  (`ScCourtGeometry`), validate it there (counts, finiteness, 0..1), and pass it
  to a stateless presentation component. The component paints the outline and
  net it is given and derives nothing.
- **Alternatives.** (a) Keep the midpoint derivation and add the engine net
  alongside — rejected: two sources of truth and the orientation bug survives.
  (b) Paint the DTO directly in the design layer — rejected: couples the design
  component to the bridge DTO.
- **Consequences.** One authority for geometry; the design component stays
  transport-agnostic. A malformed payload degrades to "nothing drawn" rather
  than a wrong picture.
- **Status.** Accepted.

## DD-CAL-02 — Stateful interaction, stateless painting

- **Context.** The overlay needs pointer state (pressed, hovered, focused,
  active corner) and must not own domain state.
- **Decision.** Keep the existing split: `CalibrationOverlayHost` and
  `ScCourtHandle` own transient interaction state; `ScCalibrationOverlay` paints
  from props only. Add geometry as a prop, not as state.
- **Alternatives.** Folding interaction into the controller (more rebuilds,
  less local) or into a global provider (hidden coupling).
- **Consequences.** A drag repaints locally; the engine is asked once on
  release. Reuses the pattern already in the file.
- **Status.** Accepted.

## DD-CAL-03 — Boundary guard (defence in depth)

- **Context.** The security review found the new path removes the clamp that
  `_netEndpoints` provided.
- **Decision.** Validate and clamp geometry at the host boundary, and repeat the
  invariant check inside the painter. The dashed painter bounds its iteration.
- **Alternatives.** Validate only in the DTO factory (silently changes parsing
  for every consumer) or only in the painter (a second caller could bypass it).
- **Consequences.** A small duplication, justified by the security finding;
  no new exception path.
- **Status.** Accepted.

## DD-CAL-04 — Token and metric indirection

- **Context.** Raw pixel constants and a non-contract bed colour remain in the
  overlay; the design contract names tokens.
- **Decision.** Follow the existing token pattern: add `easeStandard` to the
  motion tokens, add `hairline`/`handleBorder` to `ScMetrics`, and correct
  `overlayBed`/`ScOverlayColors.bed` to the contract value after a consumer
  scan.
- **Alternatives.** A calibration-local constant file (duplicates the system) or
  leaving raw values (violates DS-1).
- **Consequences.** One place to tune; a shared-token change needs the consumer
  check recorded.
- **Status.** Accepted.

## DD-CAL-05 — Accent as a stage-scoped presentation flag

- **Context.** Two green signals appear in one pane during calibration (DS-3).
- **Decision.** Model the accent as a presentation flag on the shared transport
  (`accent: false` while the calibrate stage is active), not as a second
  transport variant and not by hiding the controls.
- **Alternatives.** Hiding the transport (breaks FR-CAL-24) or retinting it
  globally (changes every stage).
- **Consequences.** The transport stays functional; the calibration surface owns
  the one accent. Reversible.
- **Status.** Accepted.

## DD-CAL-06 — Deletion over fallback

- **Context.** `_netEndpoints` is a fallback that fabricates a net when no
  projection exists.
- **Decision.** Delete it. `null` geometry means "nothing projected yet", and
  the UI says so; no synthetic geometry is ever drawn.
- **Alternatives.** Keep it for the default state (defeats FR-CAL-05/21 and
  STATE:Default), or use it only while loading (visually indistinguishable from
  a projected court).
- **Consequences.** Honest states; the default surface is the marked court with
  no net. This is the deliberate behaviour in the BRD.
- **Status.** Accepted.

## DD-CAL-07 — Documentation reconciled from the audit ledger

- **Context.** The BRD's status cells describe a baseline that HEAD has moved
  past.
- **Decision.** Update the BRD and protocol docs from the verified ledger, one
  row per requirement, and mark evidence gaps explicitly rather than rounding
  the area up to Done.
- **Alternatives.** Regenerate the whole BRD (loses the audit trail) or leave it
  (acceptance evidence stays false).
- **Consequences.** The BRD becomes a truthful gate document; the area remains
  Partial.
- **Status.** Accepted.

## Team alignment

All seven decisions reuse patterns already present in the codebase (controller
notifier, stateless design components, token layers, stage-scoped presentation
flags). No new package, no new architectural layer, and no deviation from the
layering rules in `docs/architecture/layering.md`.
