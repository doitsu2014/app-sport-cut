# Intent Statement — Prepare analysis screen with a visible background job

## Problem

In the workspace studio, clicking **Prepare analysis** starts the job
immediately. The job produces the proxy, analysis audio and sampled frames.
The centre pane stays on playback, and the only signal is a snackbar when the
job finishes. There is no explicit start, no progress, no cancel, and no hint
that anything is running. `_preparingAnalysis` is tracked but never rendered.
Users can't tell whether the job started, is still running, or failed. This is
also how the owner ended up in Review with no analysis files.

## Users

Anyone preparing a recording in the workspace studio.

## Success criteria

1. Selecting **Prepare analysis** opens a screen in the centre pane. It shows
   the match, its analysis files, and a **Start preparing analysis** button.
   Selecting it no longer starts anything by itself.
2. Pressing the button starts the job in the background. The screen shows a
   progress bar, the current step (reading the recording, making the proxy,
   extracting audio, sampling frames), a note that the job keeps running if
   you leave the screen, and **Cancel**.
3. While it runs:
   - the **Prepare analysis** rail item shows a spinner;
   - the video's row in the left rail shows a spinner, even when another
     video or feature is selected;
   - coming back to the screen shows the live progress.
4. When the job finishes: a snackbar says the files are ready or why they
   failed, the rail refreshes, and the file table updates.
5. **Prepare analysis** on the Player analysis screen goes through the same
   job and takes you to this screen.
6. Rebuilding missing files still works from the same screen.

## Out of scope

Engine changes, queueing several jobs, notifications outside the app, and the
Player-analysis and rally jobs.

## Constraints

Dart/Flutter only. Reuse `AnalysisController`/`AnalysisView`. The engine runs
one heavy job at a time, so the UI shows one prepare job at a time.
