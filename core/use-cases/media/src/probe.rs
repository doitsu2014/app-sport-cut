//! Local video probing.

use std::ffi::OsString;
use std::path::Path;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sportcut_common::{Result, SportcutError};

use crate::exec;
use crate::toolchain::MediaToolchain;

/// Sampling and playback orientation implied by the container's rotation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Orientation {
    /// Upright landscape; no rotation metadata.
    Landscape,
    /// Rotated a quarter turn; the display is portrait.
    Portrait,
    /// Rotated half a turn.
    UpsideDown,
    /// Rotated three quarters; the display is portrait.
    PortraitReversed,
    /// Rotation metadata was present but not a right angle.
    Unknown,
}

/// Metadata read from a local video file.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MediaMetadata {
    /// Path of the file that was probed.
    pub path: String,
    /// Duration in seconds.
    pub duration_seconds: f64,
    /// Frame rate in frames per second.
    pub frame_rate: f64,
    /// Stored frame width in pixels, before rotation.
    pub width: u32,
    /// Stored frame height in pixels, before rotation.
    pub height: u32,
    /// Rotation implied by the container metadata, in degrees clockwise.
    pub rotation_degrees: i32,
    /// Whether the file contains an audio track.
    pub has_audio: bool,
    /// Size of the file in bytes.
    pub size_bytes: u64,
}

impl MediaMetadata {
    /// Display orientation derived from the rotation metadata.
    pub fn orientation(&self) -> Orientation {
        match self.rotation_degrees {
            0 => Orientation::Landscape,
            90 => Orientation::Portrait,
            180 => Orientation::UpsideDown,
            270 => Orientation::PortraitReversed,
            _ => Orientation::Unknown,
        }
    }

    /// Width and height as displayed, with rotation applied.
    pub fn display_size(&self) -> (u32, u32) {
        match self.orientation() {
            Orientation::Portrait | Orientation::PortraitReversed => (self.height, self.width),
            _ => (self.width, self.height),
        }
    }
}

/// Read metadata from a local video file without modifying it.
pub fn probe(path: &Path, toolchain: &MediaToolchain) -> Result<MediaMetadata> {
    let metadata = std::fs::metadata(path).map_err(|e| SportcutError::Probe {
        path: path.display().to_string(),
        reason: if e.kind() == std::io::ErrorKind::NotFound {
            "file not found".to_string()
        } else {
            e.to_string()
        },
    })?;

    if !metadata.is_file() {
        return Err(SportcutError::Probe {
            path: path.display().to_string(),
            reason: "not a regular file".to_string(),
        });
    }

    let size_bytes = metadata.len();
    if size_bytes == 0 {
        return Err(SportcutError::Probe {
            path: path.display().to_string(),
            reason: "file is empty".to_string(),
        });
    }

    let args: Vec<OsString> = vec![
        "-v".into(),
        "error".into(),
        "-print_format".into(),
        "json".into(),
        "-show_format".into(),
        "-show_streams".into(),
        path.into(),
    ];

    let output = match exec::run(toolchain.ffprobe(), "ffprobe", &args, path)?
        .into_success("ffprobe", path)
    {
        Ok(output) => output,
        // A probe failure is about the input file, not about the toolchain, so
        // report it as such: the caller can then show "this file could not be
        // read, because ..." instead of an internal tool error.
        Err(SportcutError::MediaToolFailed { stderr, .. }) => {
            return Err(SportcutError::Probe {
                path: path.display().to_string(),
                reason: stderr,
            })
        }
        Err(other) => return Err(other),
    };

    let json: Value = serde_json::from_slice(&output.stdout).map_err(|e| SportcutError::Probe {
        path: path.display().to_string(),
        reason: format!("probe output was not readable JSON: {e}"),
    })?;

    parse_probe_json(&json, path, size_bytes)
}

#[derive(Debug, Deserialize)]
struct ProbeDocument {
    format: Option<ProbeFormat>,
    #[serde(default)]
    streams: Vec<ProbeStream>,
}

#[derive(Debug, Deserialize)]
struct ProbeFormat {
    #[serde(default, deserialize_with = "deserialize_optional_number")]
    duration: Option<f64>,
}

#[derive(Debug, Deserialize)]
struct ProbeStream {
    codec_type: Option<String>,
    width: Option<u32>,
    height: Option<u32>,
    #[serde(default, deserialize_with = "deserialize_optional_number")]
    duration: Option<f64>,
    avg_frame_rate: Option<String>,
    r_frame_rate: Option<String>,
    nb_frames: Option<String>,
    #[serde(default)]
    side_data_list: Vec<Value>,
    #[serde(default)]
    tags: Option<ProbeTags>,
}

#[derive(Debug, Deserialize)]
struct ProbeTags {
    rotate: Option<String>,
}

/// ffprobe reports some fields as strings and others as numbers depending on
/// the container; accept both.
fn deserialize_optional_number<'de, D>(
    deserializer: D,
) -> std::result::Result<Option<f64>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = Option::<Value>::deserialize(deserializer)?;
    Ok(value.and_then(|value| match value {
        Value::Number(number) => number.as_f64(),
        Value::String(text) => text.parse::<f64>().ok(),
        _ => None,
    }))
}

fn parse_probe_json(json: &Value, path: &Path, size_bytes: u64) -> Result<MediaMetadata> {
    let document: ProbeDocument =
        serde_json::from_value(json.clone()).map_err(|e| SportcutError::Probe {
            path: path.display().to_string(),
            reason: format!("probe output did not match the expected shape: {e}"),
        })?;

    let video = document
        .streams
        .iter()
        .find(|stream| stream.codec_type.as_deref() == Some("video"))
        .ok_or_else(|| SportcutError::Probe {
            path: path.display().to_string(),
            reason: "no video stream found; the file may be truncated or not a video container"
                .to_string(),
        })?;

    let width = video
        .width
        .filter(|width| *width > 0)
        .ok_or_else(|| SportcutError::Probe {
            path: path.display().to_string(),
            reason: "video stream did not report a width".to_string(),
        })?;
    let height = video
        .height
        .filter(|height| *height > 0)
        .ok_or_else(|| SportcutError::Probe {
            path: path.display().to_string(),
            reason: "video stream did not report a height".to_string(),
        })?;

    let duration_seconds = video
        .duration
        .or_else(|| document.format.as_ref().and_then(|format| format.duration))
        .filter(|duration| *duration > 0.0)
        .ok_or_else(|| SportcutError::Probe {
            path: path.display().to_string(),
            reason: "no duration reported; the file may be truncated".to_string(),
        })?;

    let frame_rate =
        parse_frame_rate(video, duration_seconds).ok_or_else(|| SportcutError::Probe {
            path: path.display().to_string(),
            reason: "video stream did not report a frame rate".to_string(),
        })?;

    let has_audio = document
        .streams
        .iter()
        .any(|stream| stream.codec_type.as_deref() == Some("audio"));

    Ok(MediaMetadata {
        path: path.display().to_string(),
        duration_seconds,
        frame_rate,
        width,
        height,
        rotation_degrees: rotation_degrees(video),
        has_audio,
        size_bytes,
    })
}

fn parse_frame_rate(video: &ProbeStream, duration_seconds: f64) -> Option<f64> {
    let declared = video
        .avg_frame_rate
        .as_deref()
        .and_then(parse_rational)
        .or_else(|| video.r_frame_rate.as_deref().and_then(parse_rational))
        .filter(|rate| *rate > 0.0);

    if declared.is_some() {
        return declared;
    }

    let frames = video
        .nb_frames
        .as_deref()
        .and_then(|frames| frames.parse::<f64>().ok())
        .filter(|frames| *frames > 0.0);

    frames
        .map(|frames| frames / duration_seconds)
        .filter(|rate| rate.is_finite() && *rate > 0.0)
}

/// Parse ffprobe's `"num/den"` rational frame rate.
fn parse_rational(value: &str) -> Option<f64> {
    let (numerator, denominator) = value.split_once('/')?;
    let numerator: f64 = numerator.trim().parse().ok()?;
    let denominator: f64 = denominator.trim().parse().ok()?;
    if denominator == 0.0 {
        return None;
    }
    let rate = numerator / denominator;
    if rate.is_finite() && rate > 0.0 {
        Some(rate)
    } else {
        None
    }
}

fn rotation_degrees(video: &ProbeStream) -> i32 {
    for entry in &video.side_data_list {
        if let Some(rotation) = entry.get("rotation").and_then(Value::as_f64) {
            return normalize_rotation(rotation);
        }
    }

    if let Some(rotate) = video.tags.as_ref().and_then(|tags| tags.rotate.as_deref()) {
        if let Ok(rotation) = rotate.parse::<f64>() {
            return normalize_rotation(rotation);
        }
    }

    0
}

fn normalize_rotation(degrees: f64) -> i32 {
    let rounded = degrees.round() as i32;
    ((rounded % 360) + 360) % 360
}
