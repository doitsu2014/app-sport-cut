---
name: write-brd
description: >
  Use when authoring, reviewing, or revising a Business Requirements Document
  (BRD) for a product, release, or feature. Produces a grounded, testable BRD
  covering problem framing, business objectives, scope, stakeholders, business
  and functional requirements, design-system constraints, non-functional
  requirements, risks, traceability, and approval. Default output:
  docs/brd.md.
license: MIT-0
compatibility: Any repository; adapt paths, identifiers, and links to the project.
metadata:
  category: product
  output: docs/brd.md
  aliases: brd, business-requirements, requirements-document
---

# Write a Business Requirements Document

A BRD states **what the business needs and why**, in terms that can be verified.
It is the scope and acceptance reference that design, engineering, QA, security,
and licensing sign off against.

## When this skill applies

- A new product, release, or significant feature needs its outcomes, scope, and
  acceptance defined.
- An existing BRD needs review, revision, or re-baselining.
- Stakeholders disagree on scope and the decision needs a written reference.
- A design system or compliance constraint must be captured as a requirement,
  not left as an implementation preference.

## When it does not apply

- A technical design, API contract, or architecture decision → use an
  architecture or design document.
- A single small change with an obvious acceptance test → a ticket suffices.
- A test plan → write the verification plan; the BRD only names the evidence.
- A project schedule → the BRD may list milestones, but it is not a plan.

Requirements say **what** and **why**. Design says **how**. Keep the boundary.

## Non-negotiables

1. **Ground every claim in evidence.** Read the repository before writing:
   architecture, roadmap, data models, dependency register, design system, code,
   tests, and verification records. If evidence is missing, label it a gap — do
   not fill it with plausible fiction.
2. **Every requirement is testable.** Each Must and Should requirement has an
   observable acceptance criterion, including empty, error, and failure paths.
3. **Separate current state from target state.** A status table states what is
   done, partial, or blocked, with evidence links. Requirements state the bar.
4. **No invented metrics.** A number is either sourced, derived from a stated
   measurement method, or explicitly labelled provisional and owned.
5. **Stable identifiers.** Requirements never rely on prose position. Use the
   ID scheme below so reviews and traceability can cite them.
6. **Priority is explicit.** Use MoSCoW (Must / Should / Could) rather than
   ambiguous "should" language in the requirement text.
7. **The design system is a contract.** When one exists, its tokens, states,
   voice, accessibility, and anti-patterns become requirements with IDs.
8. **Version and approve.** A BRD in draft is not a commitment. Record version,
   date, status, owner, and approvers.

## Workflow

### Step 1 — Gather evidence

Read, in this order, whatever exists:

- product overview and README;
- architecture and data/storage docs;
- feature list, roadmap, and current status;
- dependency register and licensing constraints;
- design system: intent, tokens, usage/mapping, component states, voice,
  accessibility checklist, anti-patterns;
- code structure and tests that prove or contradict the documents;
- verification records and known gaps.

Record the repository commit or date used as the baseline. If documents and code
disagree, state the disagreement and treat verified code plus current evidence
as the stronger signal.

### Step 2 — Frame the problem

Write the problem in the user's terms:

- who has the problem;
- what they do today;
- why it is slow, risky, expensive, or unpleasant;
- why existing alternatives do not fit.

Then state the opportunity: what the product can do that the alternatives cannot.
Do not lead with technology. A stack choice belongs in constraints or
dependencies, not the problem statement.

### Step 3 — Define measurable outcomes

Create business objectives as `BO-1`, `BO-2`, … Each row has an objective, a
measure, a target, a horizon, and — where relevant — the evidence source.

| ID | Objective | Measure | Target | Horizon |
| --- | --- | --- | --- | --- |
| BO-1 | … | … | … | v1 |

Rules:

- Prefer outcome measures (time saved, error rate, completion) over activity
  measures (features shipped).
- If a target is provisional, say so in the row or in a note, and name who will
  confirm it.
- Do not promise a metric the product cannot observe. If instrumentation is out
  of scope, say that the metric is not currently measurable.

### Step 4 — Set scope

Three parts, all explicit:

1. **In scope** — bullet list of capabilities the release must provide.
2. **Out of scope** — capabilities deliberately excluded, with a note that they
   require a change request.
3. **Current delivery status** — a table of areas with `Status` and `Evidence`.
   Use `Done`, `Partial`, `Blocked`, `Not started`, or `Deferred`; never round
   partial work up to done.

The out-of-scope list is a scope-control tool. Include tempting adjacent work
(cloud sync, mobile clients, automation beyond the product's claim) so it cannot
creep in silently.

### Step 5 — Identify users and stakeholders

- **Personas:** role, context, primary need, and what success looks like.
- **Stakeholders:** product, design, engineering, QA, security/privacy,
  legal/licensing, support. For each, state their interest and responsibility.

Use they/them when a person's pronouns are not stated.

### Step 6 — Write business requirements

Business requirements describe outcomes the organization needs, not screens.
Use `BR-1`, `BR-2`, … Each row:

`ID | Business requirement | Priority | Acceptance criterion`

Acceptance criteria are binary and observable. "Fast" is not a criterion;
"export completes without blocking the UI and the success state names the file"
is.

Cover at minimum:

- the core value proposition;
- privacy, custody, and data-handling promises;
- human confirmation where the product is semi-automatic;
- licensing and release gates;
- accessibility and brand consistency when a design system exists;
- platform focus and explicit non-goals.

### Step 7 — Write functional requirements by domain

Group by user-facing domain, not by code module. Suggested prefixes:

`FR-<AREA>-<NN>` — for example `FR-LIB-01`, `FR-IMP-01`, `FR-EXP-01`.

Each row has a requirement, a priority, and a testable acceptance criterion.
Cover the full state set for each domain: default, loading, empty, error,
success, disabled, and cancellation. Include:

- what the user sees and can do;
- what is persisted versus derived;
- what happens on cancel, interruption, or missing input;
- what the system must never do silently.

One requirement per row. Do not bundle three behaviors into one criterion —
split them so tests can cite them.

### Step 8 — Add experience and non-functional requirements

When a design system exists, convert it into `DS-` requirements: token source,
themes, signal discipline, type and numerals, spacing and layout geometry,
component states, focus, voice, motion and reduced motion, accessibility, and
prohibited anti-patterns. Cite the design document section in the criterion.

Then write `NFR-` requirements for:

- performance and responsiveness;
- reliability, atomic writes, resumability;
- data integrity and migrations;
- security, secrets, least privilege, offline guarantees;
- accessibility;
- testability and verification;
- maintainability and module boundaries;
- build portability and pinned versions;
- licensing and release gates;
- formatting and localization stance;
- diagnostics and observability.

### Step 9 — Record constraints, assumptions, dependencies, risks

- **Assumptions:** what must be true for the requirements to be achievable.
- **Constraints:** non-negotiable boundaries (offline-only, licensing, minimum
  window, pinned versions, schema history, platform).
- **Dependencies:** internal owners and external components, each with the
  condition under which it may ship.
- **Risks:** `R-1` … with likelihood, impact, mitigation, and owner. Include
  scope-creep, accuracy, licensing, supply chain, design drift, and data-loss
  risks where relevant.

### Step 10 — Add traceability and success measures

- **Success measures:** product outcomes, accuracy or quality metrics, design
  and release readiness. Link each to its source.
- **Traceability matrix:** `BR → FR/NFR/DS → design section → code path →
  verification evidence`. The matrix is an index, not a substitute for tests.

### Step 11 — Validate and publish

Run `references/quality-checklist.md` before declaring the document ready.

Output conventions:

- Default path: `docs/brd.md`.
- Multiple BRDs: `docs/brd-<slug>.md`.
- Never overwrite an existing BRD without reading it first. If it exists,
  revise in place and bump the version; preserve the change history.
- Use the current date, status `Draft` until approved, and an approval table.
- Verify every relative link resolves before finishing.

## Identifier scheme

| Prefix | Use |
| --- | --- |
| `BO-n` | Business objective |
| `BR-n` | Business requirement |
| `FR-<AREA>-nn` | Functional requirement by domain |
| `DS-n` | Design-system requirement |
| `NFR-n` | Non-functional requirement |
| `R-n` | Risk |
| `M-n` | Milestone |
| `Q-n` | Open question |

Priorities: **Must** (release blocker), **Should** (v1 where feasible),
**Could** (later).

## Section skeleton

1. Document control
2. Executive summary
3. Business context — problem, opportunity, objectives
4. Scope — in, out, current status
5. Users and stakeholders
6. Business requirements
7. Functional requirements
8. Experience and design-system requirements
9. Non-functional requirements
10. Assumptions
11. Constraints
12. Dependencies
13. Risks and mitigations
14. Success measures
15. Traceability
16. Delivery approach and milestones
17. Open questions
18. Glossary
19. Approval

Use `references/brd-template.md` as the starting skeleton.

## Writing style

- Write like a precise operator, not a marketer: short, factual, specific.
- Name the object: the file, the stage, the side, the action.
- Verb-first labels for actions.
- No exclamation marks, anthropomorphism, or filler.
- Define jargon in the glossary on first use.
- Format numbers for scanning: `18–16`, `0:42`, `12 clips · 4:38`.
- Avoid "robust", "seamless", "world-class", and other unfalsifiable words.
- Use tables for anything with two or more dimensions; use prose for reasoning.

## Handling disagreement

- If the repository contradicts a stakeholder claim, record both and label the
  evidence.
- If a requirement is not achievable under the constraints, say so in the risk
  or open-question table rather than weakening the acceptance criterion.
- If a decision is genuinely the user's, ask before encoding it. Offer a
  recommendation, not a survey.

## Change control

A change to scope, a Must requirement, or the design contract requires:

1. a version bump;
2. a recorded decision in the document control or approval table;
3. an update to the dependency register if a new component is introduced;
4. re-running the quality checklist.

## Files

- `references/brd-template.md` — fill-in skeleton with the canonical tables.
- `references/quality-checklist.md` — the gate to run before publishing.
