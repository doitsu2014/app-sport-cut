# Intent Capture Questions

Mode: yolo — recommended answers auto-selected.

### Q1: What should the Prepare analysis screen be?

A. Embed the existing `AnalysisView` (match card and artifact table) and add
   the prepare action to it. The rebuild action stays. *(Recommended)*
B. A new, minimal screen with only a button.

[Answer]: A (auto-selected). The artifact table already shows what Prepare
produces, and the view already knows how to show a running job.

### Q2: What does "running in the background" mean?

A. The job runs on the engine's worker thread. The app keeps following it
   from `AnalysisController`, which is app-wide and not tied to the screen,
   so switching videos or features does not stop it or lose its progress.
   Spinners on the feature rail and the video rail show it is running.
   *(Recommended)*
B. Only a global banner.

[Answer]: A (auto-selected)

### Q3: Should selecting the rail item still auto-start the job?

A. No. It opens the screen, and the user presses Start. *(Recommended)*

[Answer]: A (auto-selected). That is the request.
