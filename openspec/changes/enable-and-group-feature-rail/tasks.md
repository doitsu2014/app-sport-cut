## 1. Stage state model

- [x] 1.1 Replace `StageState.blocked` with an enabled `idle` state in `pipeline_stage.dart`, keeping `done` and the "prerequisites satisfied" state
- [x] 1.2 Update `resolveStageStates` so an unmet prerequisite (or a missing recording) yields `idle` instead of a refusal
- [x] 1.3 Use the existing `nextStage` helper to derive the single `next` stage (first whose prerequisites are met)

## 2. Sectioned feature rail

- [x] 2.1 Add an Analysis section and a Studio section to the right rail, with section headers inside the 180px column
- [x] 2.2 Map the stages to sections: Mark court / Prepare analysis / Player analysis under Analysis; Review & score / Highlights / Export under Studio
- [x] 2.3 Keep Play pinned above both sections
- [x] 2.4 Render `done` with the trailing check, `next` in primary bold, and `idle` as a normal enabled row (no muted/disabled treatment)

## 3. Always-enabled navigation and guidance

- [x] 3.1 Make `_selectStage` always select the stage; remove the blocked-state short-circuit and its snackbar
- [x] 3.2 Add inline guidance for Player analysis when the proxy/tracks are missing, offering a "Prepare analysis" action that runs the existing preparation
- [x] 3.3 Confirm Review & score, Highlights, and Export keep their existing empty-state guidance and that no row refuses to open
- [x] 3.4 Remove the now-duplicate "Prepare analysis" shortcut from the studio app bar (import and delete stay)

## 4. Verify

- [x] 4.1 `flutter analyze` clean
- [x] 4.2 From a freshly imported video, every feature row opens; Player analysis offers to prepare analysis instead of surfacing an engine error

## 5. Selection-only rail emphasis

Follow-up from review: the rail's done check glyph and its persistent
primary-bold "next" cue were the only decoration left, and the `next` bold stuck
on the first actionable stage. Only the selected feature is now emphasised.

- [x] 5.1 Remove the trailing done check glyph from rail items
- [x] 5.2 Remove the persistent `next` primary-bold cue; a done row stays muted and only the selected row is bold
- [x] 5.3 Drop the now-unused `nextStage` helper
- [x] 5.4 Update the `workspace`, `workspace-studio`, and `ui-design-system` deltas and keep `flutter analyze` clean
- [x] 5.5 Keep the long rail labels on one line, so selecting a feature (which bolds the label) does not wrap it or change the row height
