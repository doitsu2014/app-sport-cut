#!/usr/bin/env bash
#
# Build the license-clean, universal ffmpeg/ffprobe that ships inside
# sportcut.app.
#
# The media toolchain is a runtime dependency of the service: probe, proxy,
# audio, frames, and export all shell out to it. A packaged app cannot assume
# Homebrew is installed, and the Homebrew build is GPL-configured, so it is not
# shippable. This script builds the LGPL configuration from the pinned FFmpeg
# source tarball:
#
#   - no --enable-gpl, no --enable-nonfree, no --enable-version3;
#   - no external libraries (--disable-autodetect), so the binaries are static
#     and carry no Homebrew dylib paths;
#   - aarch64 + x86_64 slices combined with lipo, so one app runs on Apple
#     Silicon and Intel Macs;
#   - only the built-in native codecs the pipeline uses (`mpeg4`, `aac`), the
#     native H.264/HEVC decoders, and the filters the render graph names.
#
# The result is cached under third_party/media-toolchain (git-ignored) and
# copied into the app bundle by tools/package-macos.sh.
#
# Usage:
#   tools/build-media-toolchain.sh            # build when missing or stale
#   tools/build-media-toolchain.sh --force    # always rebuild
#
# Environment:
#   SPORTCUT_MEDIA_TOOLCHAIN_DIR    output directory
#                                   (default: <repo>/third_party/media-toolchain)
#   SPORTCUT_MEDIA_TOOLCHAIN_ARCHS  slices to build (default: "arm64 x86_64")
#   SPORTCUT_FFMPEG_VERSION         pinned FFmpeg release (default: 9.0.2)
#   SPORTCUT_FFMPEG_SHA256          tarball checksum (default: pinned below)
#   SPORTCUT_MEDIA_TOOLCHAIN_JOBS   parallel make jobs (default: CPU count)

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

DEST="${SPORTCUT_MEDIA_TOOLCHAIN_DIR:-${REPO_ROOT}/third_party/media-toolchain}"
FFMPEG_VERSION="${SPORTCUT_FFMPEG_VERSION:-9.0.2}"
FFMPEG_SHA256="${SPORTCUT_FFMPEG_SHA256:-8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e}"
ARCHS="${SPORTCUT_MEDIA_TOOLCHAIN_ARCHS:-arm64 x86_64}"
JOBS="${SPORTCUT_MEDIA_TOOLCHAIN_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
MIN_MACOS="12.0"

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force) FORCE=1 ;;
    -h|--help)
      sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "build-media-toolchain: unknown argument: ${arg}" >&2
      exit 2
      ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "build-media-toolchain: this script builds the macOS app's media toolchain" >&2
  exit 1
fi

for tool in clang make lipo strip curl tar shasum; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "build-media-toolchain: ${tool} is required but was not found on PATH" >&2
    exit 1
  fi
done

FFMPEG="${DEST}/ffmpeg"
FFPROBE="${DEST}/ffprobe"
TARBALL="${DEST}/src/ffmpeg-${FFMPEG_VERSION}.tar.xz"
SOURCE="${DEST}/build/ffmpeg-${FFMPEG_VERSION}"

record_licenses() {
  mkdir -p "${DEST}/licenses"
  if [ ! -d "${SOURCE}" ]; then
    mkdir -p "${DEST}/build"
    tar -xJf "${TARBALL}" -C "${DEST}/build" \
      "ffmpeg-${FFMPEG_VERSION}/COPYING.LGPLv2.1" \
      "ffmpeg-${FFMPEG_VERSION}/LICENSE.md"
  fi
  cp "${SOURCE}/COPYING.LGPLv2.1" "${DEST}/licenses/COPYING.LGPLv2.1"
  cp "${SOURCE}/LICENSE.md" "${DEST}/licenses/LICENSE.md"
  cat > "${DEST}/licenses/README.txt" <<EOF
FFmpeg ${FFMPEG_VERSION} — LGPL 2.1 or later, built without GPL components.

This binary is a static build of FFmpeg. The corresponding source is the
upstream release tarball shipped beside this notice:

  ffmpeg-${FFMPEG_VERSION}.tar.xz
  https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz
  SHA-256 ${FFMPEG_SHA256}

The exact build configuration is recorded in the "configuration:" line of
'ffmpeg -version' and in the repository at tools/build-media-toolchain.sh.
EOF
}

verify_sha256() {
  local file="$1" expected="$2" actual
  actual=$(shasum -a 256 "${file}" | awk '{print $1}')
  if [ "${actual}" != "${expected}" ]; then
    echo "build-media-toolchain: ${file} SHA-256 mismatch" >&2
    echo "  expected ${expected}" >&2
    echo "  actual   ${actual}" >&2
    return 1
  fi
}

is_fresh() {
  [ -x "${FFMPEG}" ] && [ -x "${FFPROBE}" ] || return 1
  local arch
  for arch in ${ARCHS}; do
    lipo -verify_arch "${arch}" "${FFMPEG}" >/dev/null 2>&1 || return 1
    lipo -verify_arch "${arch}" "${FFPROBE}" >/dev/null 2>&1 || return 1
  done
  # A binary from another FFmpeg release must not be reused by mistake.
  "${FFMPEG}" -hide_banner -version 2>/dev/null | head -1 | grep -q "version ${FFMPEG_VERSION}\b"
}

if [ "${FORCE}" -eq 0 ] && is_fresh; then
  record_licenses
  echo "==> media toolchain already built: ${DEST}"
  echo "    ffmpeg  $(lipo -archs "${FFMPEG}")  $("${FFMPEG}" -hide_banner -version | head -1)"
  echo "    ffprobe $(lipo -archs "${FFPROBE}")"
  exit 0
fi

mkdir -p "${DEST}/src" "${DEST}/build" "${DEST}/licenses"

echo "==> FFmpeg ${FFMPEG_VERSION}"
if [ -f "${TARBALL}" ] && verify_sha256 "${TARBALL}" "${FFMPEG_SHA256}"; then
  echo "==> source present: ${TARBALL}"
else
  echo "==> downloading FFmpeg source…"
  TMP_DOWNLOAD=$(mktemp "${DEST}/src/download.XXXXXX")
  trap 'rm -f "${TMP_DOWNLOAD}"' EXIT
  curl -fL --proto '=https' --tlsv1.2 --retry 3 \
    -o "${TMP_DOWNLOAD}" \
    "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
  verify_sha256 "${TMP_DOWNLOAD}" "${FFMPEG_SHA256}"
  mv "${TMP_DOWNLOAD}" "${TARBALL}"
  chmod 0644 "${TARBALL}"
  trap - EXIT
  echo "==> source ready: ${TARBALL}"
fi

rm -rf "${SOURCE}"
echo "==> extracting source"
tar -xJf "${TARBALL}" -C "${DEST}/build"
if [ ! -d "${SOURCE}" ]; then
  echo "build-media-toolchain: expected ${SOURCE} after extraction" >&2
  exit 1
fi

# FFmpeg's configure cares about the target architecture name; lipo and the
# app care about the slice name.
target_arch() {
  case "$1" in
    arm64) echo "aarch64" ;;
    x86_64) echo "x86_64" ;;
    *) return 1 ;;
  esac
}

for arch in ${ARCHS}; do
  if ! target_arch "${arch}" >/dev/null; then
    echo "build-media-toolchain: unsupported arch '${arch}' (expected arm64 or x86_64)" >&2
    exit 1
  fi
done

BUILT=()
for arch in ${ARCHS}; do
  ff_arch=$(target_arch "${arch}")
  BUILD_DIR="${DEST}/build/${arch}"
  rm -rf "${BUILD_DIR}"
  mkdir -p "${BUILD_DIR}"

  echo "==> configuring FFmpeg for ${arch} (LGPL, static, no external libraries)"
  (
    cd "${BUILD_DIR}"
    "${SOURCE}/configure" \
      --prefix="${BUILD_DIR}/install" \
      --arch="${ff_arch}" \
      --target-os=darwin \
      --enable-cross-compile \
      --cc=clang \
      --host-cc=clang \
      --extra-cflags="-arch ${arch} -mmacosx-version-min=${MIN_MACOS}" \
      --extra-ldflags="-arch ${arch} -mmacosx-version-min=${MIN_MACOS}" \
      --disable-autodetect \
      --disable-gpl \
      --disable-nonfree \
      --disable-network \
      --disable-doc \
      --disable-ffplay \
      --disable-debug \
      --disable-shared \
      --enable-static \
      --disable-x86asm \
      --enable-protocol=file \
      --enable-encoder=mpeg4,aac \
      --enable-muxer=mp4,mov,ipod \
      >"${BUILD_DIR}/configure.log" 2>&1
  ) || {
    echo "build-media-toolchain: configure failed for ${arch}; see ${BUILD_DIR}/configure.log" >&2
    tail -40 "${BUILD_DIR}/configure.log" >&2
    exit 1
  }

  echo "==> building FFmpeg for ${arch} (-j${JOBS})"
  if ! make -C "${BUILD_DIR}" -j"${JOBS}" ffmpeg ffprobe \
      >"${BUILD_DIR}/build.log" 2>&1; then
    echo "build-media-toolchain: build failed for ${arch}; see ${BUILD_DIR}/build.log" >&2
    tail -40 "${BUILD_DIR}/build.log" >&2
    exit 1
  fi

  cp "${BUILD_DIR}/ffmpeg" "${BUILD_DIR}/ffmpeg.${arch}"
  cp "${BUILD_DIR}/ffprobe" "${BUILD_DIR}/ffprobe.${arch}"
  BUILT+=("${arch}")
done

echo "==> combining slices: ${BUILT[*]}"
FFMPEG_SLICES=()
FFPROBE_SLICES=()
for arch in "${BUILT[@]}"; do
  FFMPEG_SLICES+=("${DEST}/build/${arch}/ffmpeg.${arch}")
  FFPROBE_SLICES+=("${DEST}/build/${arch}/ffprobe.${arch}")
done

lipo -create "${FFMPEG_SLICES[@]}" -output "${DEST}/ffmpeg"
lipo -create "${FFPROBE_SLICES[@]}" -output "${DEST}/ffprobe"
strip -x "${DEST}/ffmpeg" "${DEST}/ffprobe" 2>/dev/null || true
chmod 0755 "${DEST}/ffmpeg" "${DEST}/ffprobe"

echo "==> verifying the shippable configuration"
CONFIG=$("${FFMPEG}" -hide_banner -version | grep '^configuration:' || true)
if [ -z "${CONFIG}" ]; then
  echo "build-media-toolchain: ffmpeg did not report its configuration" >&2
  exit 1
fi
if printf '%s\n' "${CONFIG}" | grep -Eq -- '--enable-(gpl|nonfree|version3)'; then
  echo "build-media-toolchain: refusing a GPL/nonfree/version3 build:" >&2
  printf '%s\n' "${CONFIG}" >&2
  exit 1
fi

for arch in "${BUILT[@]}"; do
  lipo -verify_arch "${arch}" "${DEST}/ffmpeg"
  lipo -verify_arch "${arch}" "${DEST}/ffprobe"
done

# A static binary must not point back at Homebrew or any build machine path.
# otool prints one non-indented header per architecture before the tab-indented
# dependency lines, so only the latter are checked.
non_system_dylibs() {
  otool -L "$1" | grep -E '^[[:space:]]+/' | awk '{print $1}' \
    | grep -Ev '^(/usr/lib/|/System/Library/)' || true
}
if [ -n "$(non_system_dylibs "${DEST}/ffmpeg")" ]; then
  echo "build-media-toolchain: ffmpeg links a non-system library:" >&2
  non_system_dylibs "${DEST}/ffmpeg" >&2
  exit 1
fi
if [ -n "$(non_system_dylibs "${DEST}/ffprobe")" ]; then
  echo "build-media-toolchain: ffprobe links a non-system library:" >&2
  non_system_dylibs "${DEST}/ffprobe" >&2
  exit 1
fi

"${FFMPEG}" -hide_banner -encoders 2>/dev/null | grep -q ' mpeg4 ' || {
  echo "build-media-toolchain: mpeg4 encoder is missing" >&2
  exit 1
}
"${FFMPEG}" -hide_banner -encoders 2>/dev/null | grep -q ' aac ' || {
  echo "build-media-toolchain: aac encoder is missing" >&2
  exit 1
}
for filter in concat overlay scale afade amix atrim trim fps; do
  "${FFMPEG}" -hide_banner -filters 2>/dev/null | grep -q " ${filter} " || {
    echo "build-media-toolchain: required filter '${filter}' is missing" >&2
    exit 1
  }
done

echo "==> recording license material"
record_licenses

echo ""
echo "==> media toolchain ready: ${DEST}"
echo "    ffmpeg  $(lipo -archs "${DEST}/ffmpeg")"
echo "    ffprobe $(lipo -archs "${DEST}/ffprobe")"
echo "    licenses ${DEST}/licenses"
echo "    source   ${TARBALL}"
