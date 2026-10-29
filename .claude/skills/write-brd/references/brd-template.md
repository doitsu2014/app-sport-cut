# <Product> — Business Requirements Document

| Field | Value |
| --- | --- |
| Document ID | BRD-<PRODUCT>-001 |
| Version | 0.1 |
| Status | Draft — for approval |
| Date | <YYYY-MM-DD> |
| Product | <product and one-line description> |
| Owner | <role or name> |
| Contributors | Product, Design, Engineering, QA, Security, Legal/Licensing |
| Source baseline | <commit sha or date, and the documents/design version used> |

## Related documents

- [Architecture](architecture.md)
- [Feature list and road map](features-roadmap.md)
- [Data and storage models](data-storage-models.md)
- [External dependencies](external-dependencies.md)
- [Design system](<path>/DESIGN.md)
- [Design tokens](<path>/tokens.css)
- [Verification index](verification/)

## 1. Executive summary

<Three short paragraphs: what the product is, the business case, and what this
document decides. State the product's honest autonomy level: what it automates
and what the user confirms.>

## 2. Business context

### 2.1 Problem statement

<Who has the problem, what they do today, and why that is slow, risky, costly, or
unpleasant. No technology-first framing.>

### 2.2 Opportunity

<What the product can do that existing alternatives cannot, and what already
exists in the repository to support it.>

### 2.3 Business objectives

| ID | Objective | Measure | Target | Horizon |
| --- | --- | --- | --- | --- |
| BO-1 |  |  |  | v1 |
| BO-2 |  |  |  | v1 |

<Note any provisional target and who will confirm it.>

## 3. Scope

### 3.1 In scope for v1

- …

### 3.2 Out of scope for v1

- …

<List tempting adjacent work explicitly. State that adding it requires a change
request.>

### 3.3 Current delivery status

| Area | Status | Evidence |
| --- | --- | --- |
|  | Done / Partial / Blocked / Not started / Deferred | <link> |

## 4. Users and stakeholders

### 4.1 User personas

| Persona | Context | Primary need | Success looks like |
| --- | --- | --- | --- |
|  |  |  |  |

### 4.2 Stakeholders

| Role | Interest | Responsibility |
| --- | --- | --- |
| Product owner | Scope and release decision | Approves the BRD and changes |
| Design lead | Brand and experience integrity | Owns the design contract |
| Engineering lead | Feasibility and correctness | Owns implementation and evidence |
| QA lead | Verification | Owns acceptance evidence |
| Security/privacy | Data handling | Reviews the privacy promise |
| Legal/licensing | Shippable component set | Owns release gates |

## 5. Business requirements

| ID | Business requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| BR-1 |  | Must |  |
| BR-2 |  | Must |  |

## 6. Functional requirements

### 6.1 <Domain>

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-<AREA>-01 |  | Must |  |

### 6.2 <Domain>

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| FR-<AREA>-01 |  | Must |  |

<Repeat for each user-facing domain. Cover default, loading, empty, error,
success, disabled, and cancellation states.>

## 7. Experience and design-system requirements

<Delete this section if the project has no design system. Cite the design
document section in each criterion.>

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| DS-1 | Tokens are the single source of color, type, spacing, radius, elevation, and motion. | Must | No raw values outside the token file and approved overlays. |
| DS-2 | Light and dark are first-class themes. | Must | Both themes are built from tokens and audited separately. |
| DS-3 |  |  |  |

## 8. Non-functional requirements

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| NFR-1 |  | Must |  |
| NFR-2 |  | Must |  |

<Cover performance, reliability, data integrity, security/privacy,
accessibility, testability, maintainability, build portability, licensing,
formatting/localization, and diagnostics.>

## 9. Assumptions

- …

## 10. Constraints

- …

## 11. Dependencies

### 11.1 Internal

| Dependency | What the product needs | Owner |
| --- | --- | --- |
|  |  |  |

### 11.2 External

| Dependency | Use | Release condition |
| --- | --- | --- |
|  |  |  |

## 12. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-1 |  | Medium | High |  |  |

## 13. Success measures

### 13.1 Product outcomes

| Measure | Target | Source |
| --- | --- | --- |
|  |  |  |

### 13.2 Quality or accuracy measures

| Metric | Definition | Target | Current evidence |
| --- | --- | --- | --- |
|  |  |  |  |

### 13.3 Design and release readiness

| Measure | Target |
| --- | --- |
|  |  |

## 14. Traceability

| Business requirement | Functional requirements | Design contract | Owning code | Verification |
| --- | --- | --- | --- | --- |
| BR-1 | FR-… | §… | `path/` | `verification/….md` |

## 15. Delivery approach and milestones

| Milestone | Exit criterion | Status |
| --- | --- | --- |
| M-1 |  | Open |

## 16. Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-1 |  |  |  |

## 17. Glossary

| Term | Meaning |
| --- | --- |
|  |  |

## 18. Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |
| Legal/licensing |  | Approve / revise |  |

---

**Change control.** A change to scope, a Must requirement, or the design
contract requires a version bump and a recorded approval decision. A change that
introduces a dependency updates the dependency register before the implementing
change is complete.
