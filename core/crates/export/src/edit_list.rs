//! The edit decision list: what to render, described as data.
//!
//! The engine renders from this list and never reads the application's catalog.
//! Keeping the choice of clips out of the renderer is what lets a different
//! backend — a platform-native encoder, later — render the same reel without the
//! client changing anything, and what keeps this crate's contract independent of
//! which toolchain happens to be installed.
//!
//! The scoreboard and the title card are supplied as images rather than as text.
//! Drawing text inside the renderer needs a font-capable build of the media
//! toolchain, and those builds are not universal: the `ffmpeg` on this
//! development machine has no `drawtext` filter at all. Compositing an image
//! needs only `overlay`, which every build has — and it means the scoreboard is
//! drawn with the application's own typography, exactly as the user sees it in
//! the review screen, rather than with whatever font happened to sit next to the
//! encoder.

use std::path::{Path, PathBuf};

use sportcut_common::{Result, SportcutError};
use sportcut_media::MediaMetadata;

/// Tolerated difference between a clip boundary and the recording's duration.
///
/// A clip that reaches the end of the recording is computed in floating point
/// from a duration the probe reported, so an exact comparison would reject
/// legitimate clips.
const BOUNDARY_EPSILON_SECONDS: f64 = 0.05;

/// One clip in the reel.
#[derive(Debug, Clone, PartialEq)]
pub struct EditClip {
    /// Start of the clip in the source recording, in seconds.
    pub start_seconds: f64,
    /// End of the clip in the source recording, in seconds.
    pub end_seconds: f64,
    /// Image composited over this clip for its whole duration.
    ///
    /// The application renders it, at the recording's pixel size, with
    /// transparency outside the scoreboard. Clips that show the same scoreboard
    /// may name the same file.
    pub overlay: Option<PathBuf>,
}

impl EditClip {
    /// Duration of the clip by itself, without padding.
    pub fn duration_seconds(&self) -> f64 {
        self.end_seconds - self.start_seconds
    }
}

/// The card shown before the first clip.
#[derive(Debug, Clone, PartialEq)]
pub struct TitleCard {
    /// Image the application rendered, at the recording's pixel size.
    pub image: PathBuf,
    /// How long the card is shown.
    pub seconds: f64,
}

/// Everything needed to render one highlight video.
#[derive(Debug, Clone, PartialEq)]
pub struct EditList {
    /// Recording to read. Never modified.
    pub source: PathBuf,
    /// Where the rendered reel is written, replaced only on success.
    pub output: PathBuf,
    /// Clips, in the order they must appear.
    pub clips: Vec<EditClip>,
    /// Material added before each clip, clamped to the recording's start.
    pub lead_in_seconds: f64,
    /// Material added after each clip, clamped to the recording's end.
    pub lead_out_seconds: f64,
    /// Title card, when the user asked for one.
    pub title: Option<TitleCard>,
    /// Music mixed under the match audio.
    pub music: Option<PathBuf>,
    /// Music volume relative to the match audio, in the range `0.0..=1.0`.
    pub music_gain: f64,
}

impl EditList {
    /// A reel with no title and no music, using the default padding.
    ///
    /// Used by callers that only have clips to render; the client always fills
    /// the fields it cares about.
    pub fn new(source: impl Into<PathBuf>, output: impl Into<PathBuf>) -> Self {
        Self {
            source: source.into(),
            output: output.into(),
            clips: Vec::new(),
            lead_in_seconds: 1.0,
            lead_out_seconds: 1.0,
            title: None,
            music: None,
            music_gain: 0.25,
        }
    }

    /// The span a clip actually covers, once padding is applied and clamped to
    /// the recording.
    pub fn padded_span(&self, clip: &EditClip, source_duration: f64) -> (f64, f64) {
        let start = (clip.start_seconds - self.lead_in_seconds).max(0.0);
        let end = (clip.end_seconds + self.lead_out_seconds).min(source_duration);
        (start, end)
    }

    /// Whether the reel needs music to be read.
    pub fn has_music(&self) -> bool {
        self.music.is_some()
    }

    /// Reject a list the renderer cannot honour, naming what is wrong.
    ///
    /// Everything here is checked before the renderer starts, so a rejected
    /// export produces no partial file and no wasted encode.
    pub fn validate(&self, source: &MediaMetadata) -> Result<()> {
        if self.clips.is_empty() {
            return Err(SportcutError::InvalidInput(
                "an export needs at least one clip".to_string(),
            ));
        }
        if self.lead_in_seconds < 0.0 || self.lead_out_seconds < 0.0 {
            return Err(SportcutError::InvalidInput(
                "clip padding cannot be negative".to_string(),
            ));
        }
        if !(0.0..=1.0).contains(&self.music_gain) {
            return Err(SportcutError::InvalidInput(format!(
                "music gain {} is outside 0.0..=1.0",
                self.music_gain
            )));
        }

        let duration = source.duration_seconds;
        for (index, clip) in self.clips.iter().enumerate() {
            if !clip.start_seconds.is_finite() || !clip.end_seconds.is_finite() {
                return Err(SportcutError::InvalidInput(format!(
                    "clip {} has a boundary that is not a number",
                    index + 1
                )));
            }
            if clip.end_seconds <= clip.start_seconds {
                return Err(SportcutError::InvalidInput(format!(
                    "clip {} ends at {:.3}s, which is not after its start at {:.3}s",
                    index + 1,
                    clip.end_seconds,
                    clip.start_seconds
                )));
            }
            if clip.start_seconds < 0.0 {
                return Err(SportcutError::InvalidInput(format!(
                    "clip {} starts before the recording",
                    index + 1
                )));
            }
            if clip.end_seconds > duration + BOUNDARY_EPSILON_SECONDS {
                return Err(SportcutError::InvalidInput(format!(
                    "clip {} ends at {:.3}s, past the end of the {:.3}s recording",
                    index + 1,
                    clip.end_seconds,
                    duration
                )));
            }
            if let Some(overlay) = &clip.overlay {
                require_readable_file(overlay, &format!("overlay of clip {}", index + 1))?;
            }
        }

        if let Some(title) = &self.title {
            if title.seconds <= 0.0 {
                return Err(SportcutError::InvalidInput(
                    "a title card needs a positive duration".to_string(),
                ));
            }
            require_readable_file(&title.image, "title card image")?;
        }
        if let Some(music) = &self.music {
            require_readable_file(music, "music track")?;
        }

        Ok(())
    }
}

fn require_readable_file(path: &Path, what: &str) -> Result<()> {
    if path.is_file() {
        return Ok(());
    }
    Err(SportcutError::InvalidInput(format!(
        "the {what} {} does not exist or is not a file",
        path.display()
    )))
}
