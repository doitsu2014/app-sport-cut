# Processing job model verification

Evidence for section 5 of the `bootstrap-project-base` change.

```bash
tools/verify-engine.sh
```

```text
test progress_does_not_decrease_within_a_stage_and_resets_on_stage_change ... ok
test a_second_job_for_the_same_match_is_rejected ... ok
test a_conflicting_heavy_job_is_rejected_and_the_slot_is_released ... ok
test a_failing_stage_reports_the_stage_and_a_reason ... ok
test cancellation_stops_work_and_marks_partial_artifacts_non_final ... ok
test a_completed_job_reports_completed_and_records_its_stages ... ok
test an_interrupted_job_resumes_from_the_last_completed_stage ... ok
==> engine verification passed
```

Spec scenarios covered:

| Spec scenario | Test |
| --- | --- |
| Progress reported while running | `progress_does_not_decrease_within_a_stage_and_resets_on_stage_change`, `a_completed_job_reports_completed_and_records_its_stages` |
| Job completes | `a_completed_job_reports_completed_and_records_its_stages` |
| Job fails | `a_failing_stage_reports_the_stage_and_a_reason` |
| Cancellation stops work | `cancellation_stops_work_and_marks_partial_artifacts_non_final` |
| Partial output not presented as final | same test: the manifest's artifacts are all `non_final` and the summary reports nothing complete |
| Resume after interruption | `an_interrupted_job_resumes_from_the_last_completed_stage` |
| Checkpoints survive application restart | same test: a fresh `CheckpointStore` reads `checkpoints.json` from the match directory and the second run skips `probe` and `proxy` |
| Second job for the same match rejected | `a_second_job_for_the_same_match_is_rejected` |
| Conflicting request not run concurrently | `a_conflicting_heavy_job_is_rejected_and_the_slot_is_released` |
| Progress does not decrease within a stage | `progress_does_not_decrease_within_a_stage_and_resets_on_stage_change` (requests `0.2, 0.6, 0.3, 0.6, 0.9` are reported as `0.2, 0.6, 0.6, 0.6, 0.9`) |
| Stage transitions identified | same test: moving to `audio` resets the value and changes the label |

## Design notes

- The lease from `JobRegistry::try_admit` is dropped when a job ends, including
  on the error path, so a failed job cannot leave the engine permanently busy.
- `CheckpointStore` writes `checkpoints.json` into the match directory after
  every completed stage, and records the lifecycle state when a job fails or is
  cancelled. A cancelled job keeps its completed stages, so resuming continues
  rather than restarting.
- `mark_artifacts_non_final` is invoked on cancellation, converting every
  finished artifact in the manifest to `non_final`.
