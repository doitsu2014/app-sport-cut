# Intent Capture Questions

Intent: `260929-doctor`
Request: "please optimized document" — clarified by the human to mean
**documentation optimization**, with the folder `docs/` named as the entry
point.

Target folder contents (13 files, ~1777 lines):

- Top-level: `architecture.md`, `data-storage-models.md`,
  `external-dependencies.md`, `features-roadmap.md`
- `verification/`: 9 per-change verification records (historical evidence)

---

## Round 1 — answers as given

### Q1: What kind of "optimization" do you want?

A. Structure & navigation
B. Clarity rewrite
C. Accuracy pass
D. De-duplication
E. All of the above, as one coherent documentation-quality pass
X. Other

[Answer]: E — all of the above.

### Q2: Which files are in scope?

E. Whole repo docs, including `openspec/` and root-level markdown.

[Answer]: E

### Q3: Are the `verification/` records editable?

E. Unsure — recommend an approach and I will confirm.

[Answer]: E

### Q4: What does success look like, observably?

E. I will state the criterion directly.

[Answer]: E — criterion to be supplied by the human (see Follow-up F3).

### Q5: What must NOT change?

E. No constraints — propose freely.

[Answer]: E

### Q6: Deadline, or cost of doing nothing?

A. No deadline; the pain is real but tolerable — optimise for quality.

[Answer]: A

---

## Round 2 — follow-ups (open)

The Round 1 answers leave three things unresolved. Nothing is written into the
intent statement until these are settled.

### F1: Where is the scope boundary? (from Q2=E)

"Whole repo docs" taken literally is larger than the `docs/` folder named in the
request, and it crosses artifacts the project treats as structured data:

| Band | Files | Nature |
| --- | --- | --- |
| `docs/` | 13 | The named target |
| `README.md`, `AGENTS.md` | 2 | Root reader/agent docs; `AGENTS.md` is 316 lines and duplicates `architecture.md` |
| `CLAUDE.md` | 1 | 52-line harness stub (`.pi`/`.claude` config), not project documentation |
| `openspec/changes/*/` | ~30 | Live change artifacts — source of truth for in-flight work |
| `openspec/specs/` | ~11 | Current capability specs — source of truth |
| `openspec/changes/archive/**` | ~43 | Historical, dated records of closed changes |
| `.pi/`, `.codex/` | 33 | Agent-harness/tool configuration, not project docs |
| `app/`, `core/`, `models/`, `tools/` | 5 | Per-track `AGENTS.md`/notes |

The project's own rules (`AGENTS.md` → OpenSpec workflow) call `openspec/specs/`
and change artifacts the source of truth and the archive historical. Editing
presentation is safe; rewriting meaning is a contract change.

Which boundary do you want?

A. **`docs/` + root `README.md` + `AGENTS.md` only.** The documentation a human
   or agent reads to understand the product. Excludes `openspec/`, harness
   config, and per-track notes. *(Recommended — matches the request.)*
B. **A + non-archived `openspec/`** (`specs/` and live `changes/`), wording and
   structure only, never meaning or acceptance criteria.
C. **A + per-track `AGENTS.md`** under `app/`, `core/`, `models/`, `tools/`.
D. **Everything listed above**, including `openspec/changes/archive/**`,
   `.pi/`, `.codex/`, and `CLAUDE.md`.
E. A boundary I will describe.
X. Other (describe)

[Answer]:

### F2: `verification/` records — confirm the recommendation (from Q3=E)

Recommendation: **lightly editable (option B below).** These 9 files are the
recorded evidence the OpenSpec workflow requires, and `AGENTS.md` treats
verification runs as the one place recorded evidence is mandatory. Their value
is that commands, results, and conclusions are trustworthy and dated.

A. Immutable — never edit; at most fix a broken link.
B. **Lightly editable** — fix formatting, headings, typos, and broken links;
   never alter commands, outputs, results, measurements, or conclusions.
   *(Recommended.)*
C. Fully editable — rewrite for consistency like any other doc, provided facts
   and results are preserved verbatim in substance.
D. Out of scope.
X. Other (describe)

[Answer]:

### F3: The observable success criterion (from Q4=E)

You chose to state this yourself. Please give the one sentence you want the
intent to be measured against. If it helps, the candidates from Round 1 were:
a one-hop documentation index proved by a walkthrough; a checked list of every
corrected factual claim; a measurable duplication reduction with zero
information loss; or passing markdownlint plus a link check. Any of those is
acceptable as the answer, as is your own wording.

[Answer]:
