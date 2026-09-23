//! Reduced-resolution analysis proxy generation.

use std::ffi::OsString;
use std::path::{Path, PathBuf};

use sportcut_common::{Result, SportcutError};

use crate::exec;
use crate::probe::{self, MediaMetadata};
use crate::toolchain::MediaToolchain;

/// Default maximum height of the generated proxy.
pub const DEFAULT_PROXY_MAX_HEIGHT: u32 = 540;

/// Video codec used for the proxy.
///
/// `mpeg4` is an encoder built into ffmpeg itself, so a license-clean
/// (LGPL-only) build can produce a proxy without GPL components. The shipping
/// export path is platform-native regardless; this is the analysis path.
const PROXY_CODEC: &str = "mpeg4";

/// Options for proxy generation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProxyOptions {
    /// Maximum height in pixels. Width follows the source aspect ratio.
    pub max_height: u32,
}

impl Default for ProxyOptions {
    fn default() -> Self {
        Self {
            max_height: DEFAULT_PROXY_MAX_HEIGHT,
        }
    }
}

/// Result of proxy generation.
#[derive(Debug, Clone, PartialEq)]
pub struct ProxyOutput {
    /// Path of the generated proxy.
    pub path: PathBuf,
    /// Proxy width in pixels.
    pub width: u32,
    /// Proxy height in pixels.
    pub height: u32,
    /// Size of the proxy file in bytes.
    pub size_bytes: u64,
}

/// Generate a reduced-resolution proxy, leaving the original untouched.
pub fn generate_proxy(
    input: &Path,
    output: &Path,
    toolchain: &MediaToolchain,
    options: &ProxyOptions,
) -> Result<ProxyOutput> {
    if options.max_height == 0 {
        return Err(SportcutError::InvalidInput(
            "proxy max_height must be greater than zero".to_string(),
        ));
    }
    if !input.is_file() {
        return Err(SportcutError::Probe {
            path: input.display().to_string(),
            reason: "file not found".to_string(),
        });
    }

    if let Some(parent) = output.parent() {
        std::fs::create_dir_all(parent).map_err(|e| SportcutError::io(parent, e))?;
    }

    // Never upscale: the proxy height is the smaller of the source height and
    // the configured maximum.
    let scale = format!("scale=-2:'min({},ih)'", options.max_height);

    let args: Vec<OsString> = vec![
        "-hide_banner".into(),
        "-nostdin".into(),
        "-y".into(),
        "-i".into(),
        input.into(),
        "-vf".into(),
        scale.into(),
        "-c:v".into(),
        PROXY_CODEC.into(),
        "-q:v".into(),
        "6".into(),
        "-pix_fmt".into(),
        "yuv420p".into(),
        "-an".into(),
        "-movflags".into(),
        "+faststart".into(),
        output.into(),
    ];

    exec::run(toolchain.ffmpeg(), "ffmpeg", &args, input)?.into_success("ffmpeg", input)?;

    let metadata = std::fs::metadata(output).map_err(|e| SportcutError::io(output, e))?;
    if metadata.len() == 0 {
        return Err(SportcutError::Artifact(format!(
            "proxy {} was written but is empty",
            output.display()
        )));
    }

    // Read back the real dimensions rather than predicting them, so the
    // manifest describes what is actually on disk.
    let probed: MediaMetadata = probe::probe(output, toolchain)?;

    Ok(ProxyOutput {
        path: output.to_path_buf(),
        width: probed.width,
        height: probed.height,
        size_bytes: metadata.len(),
    })
}
