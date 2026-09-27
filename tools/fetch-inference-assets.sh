#!/usr/bin/env bash
#
# Fetch the inference assets the packaged macOS app bundles: the TensorFlow
# Lite C runtime and the EfficientDet-Lite0 model weights.
#
# This is a developer/build-time tool, not product code: it runs once at build
# time to place assets into a gitignored directory, from which the macOS app
# bundle step copies them. Nothing in the running app downloads anything.
#
# The assets are verified against the SHA-256 values recorded in
# docs/external-dependencies.md before they are accepted.
#
# Usage:
#   tools/fetch-inference-assets.sh
#
# Environment:
#   SPORTCUT_INFERENCE_DIR   where to place the assets
#                            (default: <repo>/third_party/inference)

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

DEST="${SPORTCUT_INFERENCE_DIR:-${REPO_ROOT}/third_party/inference}"
mkdir -p "${DEST}"

# macOS (Apple Silicon) TFLite C runtime, EdgeFirstAI build.
RUNTIME_URL="https://github.com/EdgeFirstAI/tflite-rs/releases/download/tflite-v2.19.0/libtensorflowlite_c-macos-arm64.tar.gz"
RUNTIME_DYLIB_SHA256="bd96fa2035fe06f52941e598e7281d1d59e84a4a1d63912698a5093b516c7d6a"

# EfficientDet-Lite0 Task Library int8 weights.
MODEL_URL="https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/object_detection/rpi/lite-model_efficientdet_lite0_detection_metadata_1.tflite"
MODEL_SHA256="2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b"

RUNTIME_DYLIB="${DEST}/libtensorflowlite_c.dylib"
MODEL="${DEST}/model.tflite"

verify_sha256() {
  local file="$1" expected="$2"
  local actual
  actual=$(shasum -a 256 "${file}" | awk '{print $1}')
  if [ "${actual}" != "${expected}" ]; then
    echo "fetch-inference-assets: ${file} SHA-256 mismatch" >&2
    echo "  expected ${expected}" >&2
    echo "  actual   ${actual}" >&2
    return 1
  fi
}

# Model: download when absent or when the stored file does not match.
if [ -f "${MODEL}" ] && verify_sha256 "${MODEL}" "${MODEL_SHA256}" 2>/dev/null; then
  echo "==> model present: ${MODEL}"
else
  echo "==> downloading model weights…"
  curl -fL --proto '=https' --tlsv1.2 --retry 3 -o "${MODEL}" "${MODEL_URL}"
  verify_sha256 "${MODEL}" "${MODEL_SHA256}"
  echo "==> model ready: ${MODEL}"
fi

# Runtime: download and extract when absent or when the dylib does not match.
if [ -f "${RUNTIME_DYLIB}" ] && verify_sha256 "${RUNTIME_DYLIB}" "${RUNTIME_DYLIB_SHA256}" 2>/dev/null; then
  echo "==> runtime present: ${RUNTIME_DYLIB}"
else
  echo "==> downloading TFLite runtime…"
  TMP=$(mktemp -d)
  trap 'rm -rf "${TMP}"' EXIT
  curl -fL --proto '=https' --tlsv1.2 --retry 3 -o "${TMP}/runtime.tar.gz" "${RUNTIME_URL}"
  tar -xzf "${TMP}/runtime.tar.gz" -C "${TMP}"
  FOUND=$(find "${TMP}" -name 'libtensorflowlite_c.dylib' -print -quit)
  if [ -z "${FOUND}" ]; then
    echo "fetch-inference-assets: libtensorflowlite_c.dylib not found in the archive" >&2
    exit 1
  fi
  cp "${FOUND}" "${RUNTIME_DYLIB}"
  verify_sha256 "${RUNTIME_DYLIB}" "${RUNTIME_DYLIB_SHA256}"
  echo "==> runtime ready: ${RUNTIME_DYLIB}"
fi
