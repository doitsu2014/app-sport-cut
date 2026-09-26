# EfficientDet-Lite0 — Task Library object detection (int8)

The on-device person-detector candidate for `sportcut-vision`.

## Identity

- **Name:** EfficientDet-Lite0, Task Library object-detection variant, int8 quantization
- **Source:** [Google model file](https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/object_detection/rpi/lite-model_efficientdet_lite0_detection_metadata_1.tflite)
- **SHA-256:** `2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b`
- **License / distribution verdict:** see
  [`docs/external-dependencies.md`](../../docs/external-dependencies.md) —
  weight-redistribution terms are `unresolved`, so the weight file is not
  committed here and must not enter a shipping build until the verdict is
  `shippable`.

## Format

- **Input:** one tensor, `1×320×320×3`, UInt8, packed RGB. The detector
  letterboxes the decoded frame into this size, preserving aspect ratio.
- **Output:** four tensors from the model's `DetectionPostProcess` op:
  - `locations` — `[1, N, 4]` boxes in `[ymin, xmin, ymax, xmax]`, normalized;
  - `classes` — `[1, N]` class ids (COCO class `0` is *person*);
  - `scores` — `[1, N]` confidence values;
  - `count` — `[1]` number of valid detections.

## Intended use

Locate likely on-court players in locally sampled badminton frames, entirely
offline. `TflitePersonDetector` runs this model on macOS, filters to class `0`
(person), and hands raw boxes and scores to the court-selection stage. It never
writes winners or scores by itself.

## Packaging

The weight file stays outside the checkout during evaluation (the design keeps
trial assets local). Point `SPORTCUT_PERSON_MODEL` at the file and
`SPORTCUT_TFLITE_LIBRARY` at the matching TFLite C runtime to run player
analysis. Offline inference was confirmed against this file on the development
Mac.
