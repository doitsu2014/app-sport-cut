# Verification record

Evidence gathered while implementing this change. Per-task detail lives in
`docs/verification/`:

| File | Covers |
| --- | --- |
| [`docs/verification/preflight.md`](../../../docs/verification/preflight.md) | Task 2.5 — preflight against this machine; every missing component reported in one run |
| [`docs/verification/media-pipeline.md`](../../../docs/verification/media-pipeline.md) | Section 4 — media pipeline tests and CLI transcript |
| [`docs/verification/processing-jobs.md`](../../../docs/verification/processing-jobs.md) | Section 5 — job lifecycle, progress, cancellation, resume, admission |
| [`docs/verification/client-track.md`](../../../docs/verification/client-track.md) | Tasks 6.3–6.4 and section 8 — generated bindings, Dart wrappers, library, catalog, playback |

## Engine verification command

```bash
tools/verify-engine.sh
```

```text
==> cargo fmt --all -- --check
==> cargo clippy --workspace --all-targets -- -D warnings
==> cargo test --workspace
==> engine verification passed
```

23 test functions pass across the media, job, facade, and offline suites. Every
scenario in the `media-pipeline` and `processing-jobs` specs maps to a named
test; the mapping is in the two files above.

## Task 9.1 — media and job scenarios have tests

| Spec | Scenario | Test |
| --- | --- | --- |
| media-pipeline | Metadata returned for a readable file | `probe_returns_metadata_for_a_readable_file` |
| media-pipeline | Unreadable input handled | `probe_reports_missing_truncated_and_non_media_inputs` |
| media-pipeline | Proxy created | `proxy_is_reduced_in_resolution_and_leaves_the_original_untouched`, `pipeline_writes_artifacts_under_one_directory_and_records_them` |
| media-pipeline | Original recording unmodified | `proxy_is_reduced_in_resolution_and_leaves_the_original_untouched` |
| media-pipeline | Audio track extracted | `audio_is_extracted_and_a_silent_pipeline_continues_without_it` |
| media-pipeline | Video without audio | `audio_is_extracted_and_a_silent_pipeline_continues_without_it`, `a_source_without_audio_imports_and_reports_no_analysis_audio` |
| media-pipeline | Frames sampled at the requested rate | `frames_are_sampled_at_the_requested_rate_with_original_timestamps` |
| media-pipeline | Unsupported sampling rate rejected | `unsupported_and_invalid_sampling_rates_are_rejected` |
| media-pipeline | Artifacts organized under one directory | `pipeline_writes_artifacts_under_one_directory_and_records_them` |
| media-pipeline | Derived artifacts are regenerable | `derived_artifacts_are_regenerable_without_re_importing`, `a_match_missing_derived_artifacts_can_be_repaired_through_the_facade` |
| media-pipeline | Pipeline runs without network access | `pipeline_completes_with_network_access_unavailable` |
| media-pipeline | No media data leaves the device | `media_crate_contains_no_network_dependency_or_call` |
| processing-jobs | Progress reported while running | `progress_does_not_decrease_within_a_stage_and_resets_on_stage_change` |
| processing-jobs | Job completes | `a_completed_job_reports_completed_and_records_its_stages` |
| processing-jobs | Job fails | `a_failing_stage_reports_the_stage_and_a_reason` |
| processing-jobs | Cancellation stops work | `cancellation_stops_work_and_marks_partial_artifacts_non_final` |
| processing-jobs | Partial output not presented as final | `cancellation_stops_work_and_marks_partial_artifacts_non_final` |
| processing-jobs | Resume after interruption | `an_interrupted_job_resumes_from_the_last_completed_stage` |
| processing-jobs | Checkpoints survive application restart | `an_interrupted_job_resumes_from_the_last_completed_stage` |
| processing-jobs | Second job for the same match rejected | `a_second_job_for_the_same_match_is_rejected` |
| processing-jobs | Conflicting request not run concurrently | `a_conflicting_heavy_job_is_rejected_and_the_slot_is_released` |
| processing-jobs | Progress does not decrease within a stage | `progress_does_not_decrease_within_a_stage_and_resets_on_stage_change` |
| processing-jobs | Stage transitions identified | `progress_does_not_decrease_within_a_stage_and_resets_on_stage_change` |

## Task 9.3 — no pipeline stage requires network access

Recorded evidence:

1. `pipeline_completes_with_network_access_unavailable` runs the whole pipeline
   with `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY` set to `http://127.0.0.1:9`
   (the discard port, where nothing listens) and asserts that the proxy, audio,
   and frames are all produced. Any attempt to leave the machine would fail
   rather than silently succeed.
2. `media_crate_contains_no_network_dependency_or_call` asserts that no network
   crate appears in `core/crates/media/Cargo.toml` and that no source file uses
   `TcpStream`, `UdpSocket`, `std::net`, or an HTTP client.
3. Every external process the engine starts goes through
   `core/crates/media/src/exec.rs`, which runs the local `ffmpeg`/`ffprobe`
   binaries with local file paths. There is no other process invocation in the
   crate.

The CLI end-to-end run in `docs/verification/media-pipeline.md` was performed
with the match directory outside the repository; no stage contacted a network
service, and the offline test above is the automated form of the same check.

## Client track

```bash
cd app && flutter analyze && flutter test
```

```text
No issues found!
All tests passed!   (38 tests)
```

Covered: the generated bridge loading the native library, the catalog schema and
migrations, import and its failure modes, the library screen, playback, the
shell, and formatting. `docs/verification/client-track.md` has the detail.

## Not yet verified

Tasks that still need a platform toolchain:

- 7.1 — the Flutter SDK and Dart are installed and verified; a full Xcode
  installation, the Android SDK, and a JDK are not.
- 7.5 — the Gradle/CocoaPods wiring that links the engine into the iOS and
  Android builds, and a launch on a simulator or device. The bridge's runtime
  load is confirmed on the host by `test/bridge_test.dart`.
- 9.2 — the manual end-to-end flow on a device.

`SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin tools/preflight.sh --profile mobile`
reports the current state and the remediation for each missing component.
