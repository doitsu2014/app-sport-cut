//! Analysis audio extraction.

use std::ffi::OsString;
use std::path::{Path, PathBuf};

use sportcut_common::{Result, SportcutError};

use crate::exec;
use crate::probe::MediaMetadata;
use crate::toolchain::MediaToolchain;

/// Sample rate of the analysis track, in hertz.
pub const ANALYSIS_AUDIO_SAMPLE_RATE: u32 = 16_000;

/// Bitrate of the analysis track.
pub const ANALYSIS_AUDIO_BITRATE: &str = "64k";

/// Extract a low-bitrate mono analysis track.
///
/// A source without an audio track is an expected outcome, not a failure: the
/// function returns `Ok(None)` and the rest of the pipeline continues without
/// an audio signal.
pub fn extract_analysis_audio(
    input: &Path,
    output: &Path,
    toolchain: &MediaToolchain,
    metadata: &MediaMetadata,
) -> Result<Option<PathBuf>> {
    if !metadata.has_audio {
        return Ok(None);
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

    let args: Vec<OsString> = vec![
        "-hide_banner".into(),
        "-nostdin".into(),
        "-y".into(),
        "-i".into(),
        input.into(),
        "-vn".into(),
        "-ac".into(),
        "1".into(),
        "-ar".into(),
        ANALYSIS_AUDIO_SAMPLE_RATE.to_string().into(),
        "-c:a".into(),
        "aac".into(),
        "-b:a".into(),
        ANALYSIS_AUDIO_BITRATE.into(),
        output.into(),
    ];

    exec::run(toolchain.ffmpeg(), "ffmpeg", &args, input)?.into_success("ffmpeg", input)?;

    let size = std::fs::metadata(output)
        .map_err(|e| SportcutError::io(output, e))?
        .len();
    if size == 0 {
        return Err(SportcutError::Artifact(format!(
            "analysis audio {} was written but is empty",
            output.display()
        )));
    }

    Ok(Some(output.to_path_buf()))
}
