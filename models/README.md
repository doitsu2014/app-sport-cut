# Model Assets

Model files and pretrained weights that ship with the app live here, one
subdirectory per model.

Rules for anything committed to this directory:

1. Every weight file has a row in
   [`docs/external-dependencies.md`](../docs/external-dependencies.md)
   with its license, source, version, and distribution verdict.
2. Weights are reviewed independently of the runtime that executes them: an
   Apache-2.0 runtime does not make the weights that run on it redistributable.
3. Large optional packs are not committed. If the offline promise is relaxed for
   a pack, the download is explicit, user-initiated, and recorded in the
   register.

No weights ship in the current change. The EfficientDet-Lite0 int8 candidate
is documented under `efficientdet-lite0-task-int8/`, but its weight file is kept
outside the checkout (design D1 keeps trial assets local) until its
redistribution verdict in the register is `shippable`.

## Layout

```
models/
  <model-name>/
    MODEL.md     license, source, version, checksum, intended use
    <weights>    the weight file itself (only when it may ship)
```
