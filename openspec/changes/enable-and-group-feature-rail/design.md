## Context

The studio's right rail is a single flat `ListView` in
`workspace_studio_screen.dart`: a `Play` row followed by every `PipelineStage`
except `import`, rendered in pipeline order. Each row's state comes from
`resolveStageStates`, and `_selectStage` refuses to open a stage whose state is
`blocked`, showing a snackbar instead.

Two things follow from that:

- The rail reads as a mostly-disabled list. As soon as one step is pending, the
  later features (most of the app) look unavailable, even though their views
  handle an empty workspace fine.
- Seven undifferentiated rows obscure the difference between features that
  *read* the match and features that *produce* the reel.

The design system's mockup fixes the rail at `.rail-stages { width:180px }`, so
section headers have to live inside a narrow column; long labels already wrap.

## Goals / Non-Goals

**Goals:**

- Present the right rail as two labelled sections — Analysis and Studio — with
  Play pinned above them.
- Make every feature selectable at any time; state is guidance, not a gate.
- Replace the "blocked" refusal with inline, actionable guidance inside the
  feature that lacks its input.
- Keep the existing done/next visual language (check glyph; primary bold).

**Non-Goals:**

- Relaxing the engine's own prerequisites. Player analysis still requires the
  proxy and calibration; the app guides the user to them rather than pretending
  the job can run.
- Reordering features *within* a section, collapsible sections, or section
  progress counts.
- Any engine, bridge, DTO, or Rust change.

## Decisions

### 1. Section membership

| Section | Features |
| --- | --- |
| _(pinned)_ | Play — the shared preview |
| **Analysis** | Mark court, Prepare analysis, Player analysis |
| **Studio** | Review & score, Highlights, Export |

```
        ┌───────────────────────────────┐
        │  ▶  Play                      │  pinned: shared preview
        │                               │
        │  ANALYSIS                     │
        │  ⬚  Mark court            ✓   │
        │  ⚙  Prepare analysis          │
        │  👤 Player analysis           │
        │                               │
        │  STUDIO                       │
        │  🏆 Review & score            │
        │  ★  Highlights                │
        │  ⬆  Export                    │
        └───────────────────────────────┘
```

The split follows the verb: Analysis features consume the recording; Studio
features shape the highlight. Review & score sits in Studio because it drives
which rallies become clips and shares the preview with the build steps. The
alternative — grouping Review & score with Analysis as "understand the match" —
is recorded as an open question; the membership is a single mapping, not a
structural commitment, so moving one row is cheap.

### 2. State becomes a hint, not a gate

`resolveStageStates` keeps computing whether a stage is done and whether its
prerequisites are satisfied, but the rail stops using that to disable anything:

| State | Meaning | Rendering |
| --- | --- | --- |
| `done` | output exists | muted text, no glyph |
| `ready` | prerequisites met, output missing | normal enabled row |
| `idle` | prerequisites not met yet | normal enabled row |

Selection overlays `secondaryContainer` and a bold label. `_selectStage` always
sets the selected stage; the `StageState.blocked` short-circuit is deleted.

**Why:** the product is deliberately user-driven, and the views already tolerate
missing input. Refusing navigation adds no safety — the engine rejects an
unprepared job regardless — and costs discoverability.

### 3. Guidance lives in the view that needs input

When a feature is opened while `idle`, it explains the missing step and offers to
run it, rather than surfacing an engine error. The pattern is one shared,
data-driven prerequisite map for the stage that needs it:

- **Player analysis → Prepare analysis.** Today, opening it without a proxy
  shows the engine's raw `analysis proxy is unavailable` string. It should show a
  short explanation and a `Prepare analysis` button that runs the preparation.
- **Review & score, Highlights.** No hard prerequisite in practice — manual
  marking and rally selection work from an empty state; keep their existing empty
  states.
- **Export.** Already disables the render button when there are no clips; keep
  that, and show the "keep at least one highlight" hint.

**Why not auto-run the prerequisite:** silently kicking off a long ffmpeg job
when a user glances at a feature is surprising, and a prepare run can be large.
An explicit button keeps the user in control and reuses the existing prepare
action.

### 4. Play and Import

- **Play** stays a pinned row above the sections. It is the shared monitor, not
  a member of either phase, and `null` is already the "no stage selected" value.
- **Import** stays the app-bar `+` custody action. It has no lens to open, so it
  is not a rail row; "enable all features" applies to the feature lenses.

### 5. Retire the app-bar Prepare analysis shortcut

Once Prepare analysis is an always-enabled rail row, the gear icon in the app bar
is a second entry point to the same action. Remove it so the sectioned rail is
the single map of the features. Import and delete stay in the app bar.

### 6. Rail emphasis is selection-only

The rail emphasises only the selected feature (secondary-container tint, bold).
It does not render a trailing check on a done stage and does not paint a
persistent primary-bold "next" cue. A done stage is a muted row.

**Why:** with every feature enabled, the done glyph and the `next` bold were the
only decoration left, and the `next` bold sticks on the first actionable stage
(for a video with tracks and no score, Review & score stays bold), which reads as
a bug. Selection is the one thing the user is doing, so it is the only thing
emphasised.

**Alternatives considered:** keep the check and only drop the `next` bold, or
keep `next` but freeze it. The explicit request was to remove the glyph and stop
the always-bold, so both go.

### 7. Rail rows stay single-line

The rail item gives its title the full column width (`contentPadding` end 8,
`minLeadingWidth` 0, `horizontalTitleGap` 8) instead of the Material 3 defaults
(end 24, leading 24, gap 16), which leave only ~100px in the 180px column. That
is enough for "Prepare analysis" at normal weight but not once the selected row
is bold, so the label wrapped to two lines and the row changed height on
selection. The reclaimed width keeps every label on one line, with a single-line
ellipsis as a fallback. This keeps the design system's 180px rail and the full
stage names.

## Risks / Trade-offs

- **[Lost progress signal]** → with no check and no next cue, the rail no longer
  distinguishes done from not-done beyond a muted `done` row. Accepted: selection
  is the single emphasis the user asked for.
- **[Idle rows look enabled but the job still fails]** → mitigate with the
  per-stage guidance in decision 3; the engine remains the source of truth for
  whether a job can run.
- **[Narrow rail + section headers]** → the rail is fixed at 180px; headers are
  short uppercase labels with a little vertical padding, and existing labels
  already wrap. If headers crowd the column, they collapse to a divider first.
- **[Review & score in the wrong section]** → membership is one mapping; moving
  it is a one-line change and does not affect behaviour.

## Migration Plan

Presentation-only, no data or artifact migration. Land in one step:
sections + always-enabled selection + the Player analysis guidance + the app-bar
shortcut removal. Rollback is reverting the presentation changes; no persisted
state changes shape.

## Open Questions

- Does **Review & score** belong in Analysis (understand the match) or Studio
  (build the highlight)? Default: Studio.
- Should **Play** be pinned above the sections (default) or become its own
  top section?
- Should a section header show progress (e.g. `ANALYSIS 2/3`), or stay a plain
  label? Default: plain label.
- Should an `idle` row carry a subtle "needs setup" affordance, or look identical
  to a ready row until opened? Default: identical, so nothing reads as disabled.
