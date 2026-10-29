# BRD Quality Checklist

Run this before declaring a BRD ready for review. Every unchecked box is either
fixed or recorded as an open question with an owner.

## Evidence

- [ ] The document names the repository commit or date used as its baseline.
- [ ] Every claim about current behavior links to code, a document, a test, or a
      verification record.
- [ ] Where documents and code disagree, both are stated and the stronger
      evidence is identified.
- [ ] Missing evidence is labelled as a gap, not filled with plausible detail.

## Problem and outcomes

- [ ] The problem statement describes users and their current work, not the
      technology.
- [ ] The product's autonomy level is stated (automatic versus user-confirmed).
- [ ] Every business objective has a measure, a target, and a horizon.
- [ ] Provisional targets are labelled and have an owner.
- [ ] No metric is promised that the product cannot observe.

## Scope

- [ ] In-scope capabilities are listed as user-facing outcomes.
- [ ] Out-of-scope capabilities are explicit, including tempting adjacent work.
- [ ] The current delivery status uses Done / Partial / Blocked / Not started /
      Deferred, never rounded up.
- [ ] Every Partial or Blocked area names the gap and the evidence.

## Requirements

- [ ] Every Must and Should requirement has an observable acceptance criterion.
- [ ] Acceptance criteria cover empty, error, disabled, cancellation, and
      interruption paths where relevant.
- [ ] One requirement per row; bundled behaviors are split.
- [ ] IDs are stable, unique, and referenced consistently.
- [ ] Priority is explicit (Must / Should / Could).
- [ ] No requirement is a disguised implementation choice unless it is genuinely
      constrained.
- [ ] The product's privacy, custody, and data-handling promises are requirements,
      not assumptions.
- [ ] Licensing and release gates are requirements.

## Design system

- [ ] The design system is treated as a contract, not a suggestion.
- [ ] Token source, themes, signal discipline, typography, spacing, states,
      focus, voice, motion, and anti-patterns are represented.
- [ ] Accessibility is a requirement with a named checklist or standard.
- [ ] Known design gaps are stated in the status table.
- [ ] The responsive or adaptive contract names the viewports or window sizes.

## Non-functional

- [ ] Performance and UI responsiveness are addressed.
- [ ] Reliability covers atomic writes, cancellation, and resumability.
- [ ] Data integrity covers migrations and preservation of user-authored data.
- [ ] Security covers secrets, least privilege, and offline guarantees.
- [ ] Testability states how each Must requirement is verified.
- [ ] Maintainability states the module boundary and pinned-version rules.
- [ ] Build portability and toolchain independence are addressed where relevant.

## Risks and dependencies

- [ ] Every high-impact risk has a mitigation and an owner.
- [ ] Scope, accuracy, licensing, supply-chain, design-drift, and data-loss risks
      are considered.
- [ ] Internal and external dependencies name what the product needs and the
      condition under which it may ship.
- [ ] The dependency register is the gating source, not a duplicate list.

## Traceability and measures

- [ ] Business requirements trace to functional or non-functional requirements.
- [ ] The traceability matrix names design sections, owning code, and
      verification evidence.
- [ ] Success measures include product outcomes, quality metrics, and release
      readiness.
- [ ] Milestones have exit criteria and honest status.

## Document hygiene

- [ ] Document control has ID, version, status, date, owner, and baseline.
- [ ] Open questions have owners and a reason they matter.
- [ ] The glossary defines domain terms and abbreviations.
- [ ] The approval table names the roles that must sign off.
- [ ] Change control is stated.
- [ ] Every relative link resolves.
- [ ] No marketing language, exclamation marks, or unfalsifiable adjectives.
- [ ] Dates are absolute (`2026-10-29`), not relative.
- [ ] The document does not claim release readiness while a release gate is open.
