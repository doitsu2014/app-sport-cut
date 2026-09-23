# Model Assets

Model files and pretrained weights that ship with the app live here, one
subdirectory per model.

Rules for anything committed to this directory:

1. Every weight file has a row in
   [`docs/legal/dependency-register.md`](../docs/legal/dependency-register.md)
   with its license, source, version, and distribution verdict.
2. Weights are reviewed independently of the runtime that executes them: an
   Apache-2.0 runtime does not make the weights that run on it redistributable.
3. Large optional packs are not committed. If the offline promise is relaxed for
   a pack, the download is explicit, user-initiated, and recorded in the
   register.

No model ships in the current change. The `sportcut-vision` crate defines the
detector and pose-estimator boundaries that a model will plug into later; the
intended default runtime (TensorFlow Lite, Apache-2.0) with an Apache-2.0 model
is recorded as a pending decision.

## Layout

```
models/
  <model-name>/
    MODEL.md     license, source, version, checksum, intended use
    <weights>    the weight file itself (only when it may ship)
```
