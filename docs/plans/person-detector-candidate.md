# macOS Person Detector Trial

This records the local candidate for OpenSpec change
`add-player-detection-tracking`. It is a development trial, not a selected
shipping runtime or model. No runtime binary or weight file is committed.

## Candidate inputs

| Component | Source and identity | Current verdict |
| --- | --- | --- |
| Rust wrapper | `tflite-c-rs` 0.0.1, optional `macos-tflite-eval` feature | License is permissive; API and packaging review remains open |
| TFLite C runtime | EdgeFirst macOS arm64 build of TFLite 2.19.0; archive SHA-256 `1de9594d626f2a8c6500739acd0691d46f920f295ba1daf95c02adcccf73ad33`; dylib SHA-256 `bd96fa2035fe06f52941e598e7281d1d59e84a4a1d63912698a5093b516c7d6a` | Local trial only; binary provenance and distribution review remain open |
| Model | Google's EfficientDet-Lite0 Task Library int8 v1; SHA-256 `2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b` | Local trial only; weight redistribution and training-data terms remain open |

The model accepts one 320×320×3 `UInt8` RGB tensor. Its four postprocessed
outputs are boxes `[1,25,4]` in `(top,left,bottom,right)` order, classes
`[1,25]`, scores `[1,25]`, and a count `[1]`, all `Float32`. The embedded label
map starts with `person` at index 0. The backend letterboxes the upright frame
and maps returned boxes back into its displayed pixel coordinates.

Google's separate MediaPipe EfficientDet-Lite0 downloads have two raw outputs
(class scores and anchor boxes). They require MediaPipe's metadata-driven
postprocessor, so the current four-output backend does not accept them.

## Local check

The optional Rust feature built and linted on the development Mac. A direct
offline inference call using the local runtime and model succeeded on a blank
320×320 RGB frame and returned zero person detections. This checks loading and
the tensor contract only; it does not establish detection accuracy on badminton
footage, runtime cost, or rights to redistribute either binary.

The `PersonDetector` implementation requires explicit local runtime and model
paths. It neither downloads assets nor activates in the default engine build.
The dependency register records every trial component with an unresolved
distribution verdict where appropriate.

For a local macOS development run, set `SPORTCUT_MACOS_TFLITE_EVAL=1`,
`SPORTCUT_TFLITE_LIBRARY` to the local `.dylib`, and `SPORTCUT_PERSON_MODEL`
to the exact Task Library model file, then use `tools/run-macos.sh`. The build
script enables the trial feature only when requested. These variables point
outside the checkout and are never saved with a match.
