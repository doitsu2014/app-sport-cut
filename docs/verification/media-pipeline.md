# Media pipeline verification

Evidence for section 4 of the `bootstrap-project-base` change. Recordings are
never committed: every fixture is generated with the local media toolchain into
a temporary directory.

## Engine verification

```bash
tools/verify-engine.sh
```

```text
==> cargo fmt --all -- --check
==> cargo clippy --workspace --all-targets -- -D warnings
==> cargo test --workspace
test unsupported_and_invalid_sampling_rates_are_rejected ... ok
test probe_returns_metadata_for_a_readable_file ... ok
test probe_reports_missing_truncated_and_non_media_inputs ... ok
test proxy_is_reduced_in_resolution_and_leaves_the_original_untouched ... ok
test frames_are_sampled_at_the_requested_rate_with_original_timestamps ... ok
test cancellation_marks_partial_artifacts_non_final ... ok
test audio_is_extracted_and_a_silent_pipeline_continues_without_it ... ok
test pipeline_writes_artifacts_under_one_directory_and_records_them ... ok
test a_stage_recorded_as_complete_is_not_re_executed ... ok
test derived_artifacts_are_regenerable_without_re_importing ... ok
test media_crate_contains_no_network_dependency_or_call ... ok
test pipeline_completes_with_network_access_unavailable ... ok
==> engine verification passed
```

Spec scenarios covered:

| Spec scenario | Test |
| --- | --- |
| Metadata returned for a readable file | `probe_returns_metadata_for_a_readable_file` |
| Unreadable input handled | `probe_reports_missing_truncated_and_non_media_inputs` |
| Proxy created / original unmodified | `proxy_is_reduced_in_resolution_and_leaves_the_original_untouched` |
| Audio track extracted / video without audio | `audio_is_extracted_and_a_silent_pipeline_continues_without_it` |
| Frames sampled at the requested rate | `frames_are_sampled_at_the_requested_rate_with_original_timestamps` |
| Unsupported sampling rate rejected | `unsupported_and_invalid_sampling_rates_are_rejected` |
| Artifacts organized under one directory | `pipeline_writes_artifacts_under_one_directory_and_records_them` |
| Derived artifacts are regenerable | `derived_artifacts_are_regenerable_without_re_importing` |
| No media data leaves the device | `pipeline_completes_with_network_access_unavailable`, `media_crate_contains_no_network_dependency_or_call` |

## CLI transcript

Run against a generated 640x480, 10 fps, 5-second clip with audio, with the
match root outside the repository:

```text
$ sportcut-cli probe $LAB/match.mp4
path: /tmp/sportcut-lab.vvQHB8/match.mp4
duration: 5.000 s
frame rate: 10.000 fps
resolution: 640x480 (display 640x480)
orientation: Landscape (rotation 0 degrees)
audio track: present
size: 817541 bytes

$ sportcut-cli import --input $LAB/match.mp4 --match-id demo-match --match-root $LAB/matches --rate 2
match directory: /tmp/sportcut-lab.vvQHB8/matches/demo-match
proxy: /tmp/sportcut-lab.vvQHB8/matches/demo-match/proxy/proxy.mp4
analysis audio: /tmp/sportcut-lab.vvQHB8/matches/demo-match/audio/analysis.m4a
frames: 10
artifacts recorded: 3

$ find $LAB/matches/demo-match -maxdepth 2
demo-match/audio
demo-match/calibration
demo-match/frames
demo-match/manifest.json
demo-match/proxy
demo-match/tracks

$ sportcut-cli inspect $LAB/matches/demo-match
match: demo-match
original: /private/tmp/sportcut-lab.vvQHB8/match.mp4 (present: true)
complete: proxy, analysis_audio, frames
missing: none
non-final: none
```

Regenerability: after moving `proxy/` and `frames/` aside, `inspect` reports both
as missing, `regenerate` rebuilds exactly those two, and the original recording's
SHA-256 is unchanged.

```text
$ sportcut-cli inspect $LAB/matches/demo-match
complete: analysis_audio
missing: proxy, frames
$ sportcut-cli regenerate $LAB/matches/demo-match --rate 2
regenerated: proxy, frames
$ sportcut-cli inspect $LAB/matches/demo-match
complete: analysis_audio, proxy, frames
missing: none
original unchanged: yes
```

No-audio source: the import completes and records two artifacts, reporting that
no analysis audio is available.

```text
analysis audio: none (source has no audio track)
frames: 2
artifacts recorded: 2
```

## Offline evidence

`pipeline_completes_with_network_access_unavailable` runs the whole pipeline
with `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY` pointed at `127.0.0.1:9`
(the discard port, where nothing is listening), so any attempt to leave the
machine would fail rather than silently succeed. The run completes and every
artifact is produced.

`media_crate_contains_no_network_dependency_or_call` audits the crate: no
network dependency appears in `Cargo.toml`, and no source file uses
`TcpStream`, `UdpSocket`, `std::net`, or an HTTP client. Every external process
the engine starts is the local `ffmpeg`/`ffprobe` pair with local file paths.
