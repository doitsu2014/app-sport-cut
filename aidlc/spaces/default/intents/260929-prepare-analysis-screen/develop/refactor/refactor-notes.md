# Refactor Notes

I reviewed the diff for duplication and state leaks; no code changes were
needed.

- `repair` and `prepare` already share `_runJob` / `_finish` / `_follow`.
- **Stale reads.** When `open()` completes, the result is dropped if the viewed
  match has changed in the meantime.
- **Job for one match, view on another.** `_finish` writes the job's failure to
  the view's `problem` only when the view is still on that match. The studio
  snackbar still reports it.
- **Re-entering the view mid-job.** `open()` changes only the manifest fields
  and keeps the `running` / `jobId` / `stage` it already has.

Left for later (out of scope): `MatchRepository.generateArtifacts` has no
callers left in `lib/`.
