//! Discovery of the `ffmpeg` / `ffprobe` pair the pipeline shells out to.

use std::path::{Path, PathBuf};

use sportcut_common::{Result, SportcutError};

/// Environment variable that overrides the `ffmpeg` binary.
pub const FFMPEG_ENV: &str = "SPORTCUT_FFMPEG";

/// Environment variable that overrides the `ffprobe` binary.
pub const FFPROBE_ENV: &str = "SPORTCUT_FFPROBE";

/// The media toolchain used by every stage.
///
/// Discovery order is: the explicit environment override, then the first
/// matching executable on `PATH`. There is no fallback to a bundled binary,
/// because the engine must not ship a GPL toolchain by accident.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MediaToolchain {
    ffmpeg: PathBuf,
    ffprobe: PathBuf,
}

impl MediaToolchain {
    /// Build a toolchain from explicit binary paths.
    pub fn new(ffmpeg: impl Into<PathBuf>, ffprobe: impl Into<PathBuf>) -> Self {
        Self {
            ffmpeg: ffmpeg.into(),
            ffprobe: ffprobe.into(),
        }
    }

    /// Discover the toolchain, returning an actionable error when either binary
    /// is absent.
    pub fn discover() -> Result<Self> {
        let ffmpeg = resolve_binary(FFMPEG_ENV, "ffmpeg")?;
        let ffprobe = resolve_binary(FFPROBE_ENV, "ffprobe")?;
        Ok(Self { ffmpeg, ffprobe })
    }

    /// Path of the `ffmpeg` binary.
    pub fn ffmpeg(&self) -> &Path {
        &self.ffmpeg
    }

    /// Path of the `ffprobe` binary.
    pub fn ffprobe(&self) -> &Path {
        &self.ffprobe
    }
}

fn resolve_binary(env_var: &str, name: &str) -> Result<PathBuf> {
    if let Ok(explicit) = std::env::var(env_var) {
        if !explicit.is_empty() {
            let path = PathBuf::from(&explicit);
            if is_executable(&path) {
                return Ok(path);
            }
            return Err(SportcutError::ToolchainUnavailable(format!(
                "{env_var} points at {explicit}, which is not an executable file"
            )));
        }
    }

    let path_var = std::env::var_os("PATH").ok_or_else(|| {
        SportcutError::ToolchainUnavailable(
            "PATH is not set, so the media toolchain cannot be found".to_string(),
        )
    })?;

    for dir in std::env::split_paths(&path_var) {
        let candidate = dir.join(name);
        if is_executable(&candidate) {
            return Ok(candidate);
        }
    }

    Err(SportcutError::ToolchainUnavailable(format!(
        "{name} was not found on PATH; install ffmpeg or set {env_var} to its location"
    )))
}

fn is_executable(path: &Path) -> bool {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        match std::fs::metadata(path) {
            Ok(metadata) => metadata.is_file() && metadata.permissions().mode() & 0o111 != 0,
            Err(_) => false,
        }
    }
    #[cfg(not(unix))]
    {
        path.is_file()
    }
}
