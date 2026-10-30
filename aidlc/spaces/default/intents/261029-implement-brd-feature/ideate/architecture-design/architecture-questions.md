# Architecture Design Questions

Mode: yolo; recommended answers auto-picked and recorded.

## Q1: Who resolves the stage label shown in the status bar?

A. `StudioShell` resolves it and passes one string to `StudioStatusBar`.
B. `StudioStatusBar` reads the studio controller.
C. `VideoStageFacts` carries the selected stage.
X. Other (describe)

[Answer]: A. The shell resolves it; the status bar stays data-in.

## Q2: How should the loading state on the home screen look?

A. A centred progress indicator with no copy.
B. `ScProgressJob` with a "Reading workspaces" stage label.
C. Keep the current text-plus-icon and add a spinner beside it.
X. Other (describe)

[Answer]: B. `ScProgressJob` with a "Reading workspaces" stage label, matching
the studio's progress vocabulary.

## Q3: Which entry is selected after deleting the selected video?

A. The entry now at the deleted video's index, else the previous entry, else
   none.
B. The first remaining entry.
C. Nothing.
X. Other (describe)

[Answer]: A.

## Q4: Does any gap change data ownership or the engine boundary?

A. No. All four are client presentation/state changes.
B. Yes.
X. Other (describe)

[Answer]: A.

## Contradiction analysis

- Q1-A versus C5 (no new durable state): consistent; the label is derived, not
  stored.
- Q2-B versus DS-10 (verb-first copy): "Reading workspaces" agrees with the
  existing "Reading workspaces…" copy.
- Q3-A versus FR-LIB-24: consistent.
- No open contradictions.
