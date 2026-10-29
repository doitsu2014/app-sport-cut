//! Decode the media pipeline's upright JPEG samples into an inference buffer.

use std::path::Path;

use sportcut_common::{Result, SportcutError};

use crate::FrameView;

/// One RGB8 frame owned by the vision stage.
#[derive(Debug, Clone, PartialEq)]
pub struct DecodedRgbFrame {
    /// Timestamp on the original recording timeline.
    pub timestamp_ms: i64,
    /// Width after the media proxy's container rotation has been applied.
    pub width: u32,
    /// Height after the media proxy's container rotation has been applied.
    pub height: u32,
    /// Packed, row-major RGB8 pixels with no row padding.
    pub pixels: Vec<u8>,
}

impl DecodedRgbFrame {
    /// Borrow the decoded pixels for a synchronous detector invocation.
    pub fn view(&self) -> FrameView<'_> {
        FrameView {
            timestamp_ms: self.timestamp_ms,
            width: self.width,
            height: self.height,
            pixels: &self.pixels,
        }
    }
}

/// Read a sampled JPEG without applying another rotation to its upright pixels.
pub fn decode_sampled_jpeg(path: &Path, timestamp_ms: i64) -> Result<DecodedRgbFrame> {
    if timestamp_ms < 0 {
        return Err(SportcutError::InvalidInput(
            "person detection: sampled-frame timestamp is negative".to_string(),
        ));
    }
    let encoded = std::fs::read(path).map_err(|error| SportcutError::io(path, error))?;
    let image = image::load_from_memory_with_format(&encoded, image::ImageFormat::Jpeg).map_err(
        |error| {
            SportcutError::InvalidInput(format!(
                "person detection: cannot decode sampled JPEG at {}: {error}",
                path.display()
            ))
        },
    )?;
    let rgb = image.into_rgb8();
    let (width, height) = rgb.dimensions();
    if width == 0 || height == 0 {
        return Err(SportcutError::InvalidInput(format!(
            "person detection: sampled JPEG at {} has zero dimensions",
            path.display()
        )));
    }
    Ok(DecodedRgbFrame {
        timestamp_ms,
        width,
        height,
        pixels: rgb.into_raw(),
    })
}
