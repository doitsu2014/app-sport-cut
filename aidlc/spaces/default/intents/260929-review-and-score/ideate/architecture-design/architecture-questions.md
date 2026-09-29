# Architecture Design Questions

Mode: yolo — recommended answers auto-selected.

### Q1: How should the rail grouping be represented after the move?

A. Keep the two static `const` lists (`_analysis`, `_studio`) and move
   `PipelineStage.score` between them. *(Recommended)*
B. Introduce a data-driven section model (list of `(header, stages)`) so the
   grouping is declared once.
C. Flatten the rail and derive headers from `PipelineStage.values` order.

[Answer]: A (auto-selected). The lists are private to one widget and already
feed a single `_item` factory. A section model is more code for a two-item
regroup, and flattening would drop the **Play** row and the explicit group
boundaries. Consistency with the existing pattern wins (design-agent principle 1).

### Q2: Where in the **Analysis** group should **Review & score** go?

A. Last, after Player analysis. *(Recommended)*
B. Second, after Prepare analysis.
C. First.

[Answer]: A (auto-selected), matching pipeline order analyze → track → score and
requirements RS-2.

### Q3: Does this change introduce any trust boundary or data flow?

A. No. It is a compile-time list membership in a presentation widget; no input,
   no I/O, no persistence, no network. *(Recommended)*
B. Yes — treat it as a security-relevant change.

[Answer]: A (auto-selected). Security review is advisory and will record "no
findings" (see `architecture-doc.md`).

### Q4: Should the section headers or their styling change?

A. No. Keep "Analysis" and "Studio" and the existing `_SectionHeader`.
   *(Recommended)*
B. Rename them.

[Answer]: A (auto-selected). Renaming is out of scope in the intent statement.
