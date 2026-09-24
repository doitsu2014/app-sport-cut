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

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;

    /// Metadata of a plain ten-second recording, as a probe would report it.
    fn source() -> MediaMetadata {
        MediaMetadata {
            path: "source.mp4".to_string(),
            duration_seconds: 10.0,
            frame_rate: 10.0,
            width: 320,
            height: 240,
            rotation_degrees: 0,
            has_audio: true,
            size_bytes: 0,
        }
    }

    /// A reel with one clip covering the middle of the recording.
    fn reel() -> EditList {
        let mut edit_list = EditList::new("source.mp4", "reel.mp4");
        edit_list.clips = vec![EditClip {
            start_seconds: 4.0,
            end_seconds: 6.0,
            overlay: None,
        }];
        edit_list
    }

    /// A file that exists, for the rules that check readability.
    ///
    /// The crate has no test-only dependencies — `tempfile` belongs to the media
    /// crate — so the handful of files these tests need are written under the
    /// system temporary directory and removed when the test ends.
    #[derive(Debug)]
    struct Scrap {
        dir: PathBuf,
    }

    impl Scrap {
        fn new(label: &str) -> Self {
            let stamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("the clock is after the epoch")
                .as_nanos();
            let dir = std::env::temp_dir().join(format!(
                "sportcut-edit-list-{label}-{}-{stamp}",
                std::process::id()
            ));
            std::fs::create_dir_all(&dir).expect("create the scrap directory");
            Self { dir }
        }

        fn file(&self, name: &str) -> PathBuf {
            let path = self.dir.join(name);
            std::fs::write(&path, b"fixture").expect("write the fixture file");
            path
        }
    }

    impl Drop for Scrap {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.dir);
        }
    }

    #[test]
    fn a_reel_with_no_clips_is_rejected() {
        let mut edit_list = EditList::new("source.mp4", "reel.mp4");
        edit_list.clips = Vec::new();

        let error = edit_list.validate(&source()).expect_err("must be rejected");
        assert!(error.to_string().contains("at least one clip"), "{error}");
    }

    #[test]
    fn a_clip_that_does_not_end_after_it_starts_is_rejected() {
        for (start, end) in [(6.0, 4.0), (4.0, 4.0)] {
            let mut edit_list = reel();
            edit_list.clips = vec![
                EditClip {
                    start_seconds: 1.0,
                    end_seconds: 2.0,
                    overlay: None,
                },
                EditClip {
                    start_seconds: start,
                    end_seconds: end,
                    overlay: None,
                },
            ];

            let error = edit_list.validate(&source()).expect_err("must be rejected");
            // The offending clip is named by position, not by index.
            assert!(error.to_string().contains("clip 2"), "{error}");
        }
    }

    #[test]
    fn a_boundary_that_is_not_a_number_is_rejected() {
        for (start, end) in [(f64::NAN, 6.0), (4.0, f64::INFINITY)] {
            let mut edit_list = reel();
            edit_list.clips[0].start_seconds = start;
            edit_list.clips[0].end_seconds = end;

            let error = edit_list.validate(&source()).expect_err("must be rejected");
            assert!(error.to_string().contains("not a number"), "{error}");
        }
    }

    #[test]
    fn a_clip_outside_the_recording_is_rejected() {
        let mut before = reel();
        before.clips[0].start_seconds = -1.0;
        before.clips[0].end_seconds = 2.0;
        let error = before.validate(&source()).expect_err("must be rejected");
        assert!(error.to_string().contains("starts before"), "{error}");

        let mut past_the_end = reel();
        past_the_end.clips[0].end_seconds = 10.5;
        let error = past_the_end
            .validate(&source())
            .expect_err("must be rejected");
        assert!(error.to_string().contains("past the end"), "{error}");
        assert!(error.to_string().contains("10.000s"), "{error}");
    }

    #[test]
    fn a_clip_reaching_the_reported_duration_is_accepted() {
        // The client computes a clip that runs to the end of the recording from
        // a duration the probe reported, so an exact comparison would reject a
        // legitimate clip.
        let mut edit_list = reel();
        edit_list.clips[0].end_seconds = 10.04;
        edit_list.validate(&source()).expect("within tolerance");
    }

    #[test]
    fn negative_padding_is_rejected() {
        let mut edit_list = reel();
        edit_list.lead_in_seconds = -0.5;
        let error = edit_list.validate(&source()).expect_err("must be rejected");
        assert!(error.to_string().contains("padding"), "{error}");
    }

    #[test]
    fn a_music_gain_outside_the_unit_range_is_rejected() {
        for gain in [-0.1, 1.1] {
            let mut edit_list = reel();
            edit_list.music_gain = gain;
            let error = edit_list.validate(&source()).expect_err("must be rejected");
            assert!(error.to_string().contains("music gain"), "{error}");
        }
    }

    #[test]
    fn a_title_card_needs_a_positive_duration() {
        let scrap = Scrap::new("title");
        let mut edit_list = reel();
        edit_list.title = Some(TitleCard {
            image: scrap.file("title.png"),
            seconds: 0.0,
        });

        let error = edit_list.validate(&source()).expect_err("must be rejected");
        assert!(error.to_string().contains("positive duration"), "{error}");
    }

    #[test]
    fn an_unreadable_overlay_is_named_before_rendering() {
        let scrap = Scrap::new("overlay");
        let missing = scrap.dir.join("overlay.png");
        let mut edit_list = reel();
        edit_list.clips[0].overlay = Some(missing.clone());

        let error = edit_list.validate(&source()).expect_err("must be rejected");
        let message = error.to_string();
        assert!(message.contains("overlay of clip 1"), "{message}");
        assert!(message.contains("overlay.png"), "{message}");
    }

    #[test]
    fn an_unreadable_music_track_is_named_before_rendering() {
        let scrap = Scrap::new("music");
        let mut edit_list = reel();
        edit_list.music = Some(scrap.dir.join("music.m4a"));

        let error = edit_list.validate(&source()).expect_err("must be rejected");
        let message = error.to_string();
        assert!(message.contains("music track"), "{message}");
        assert!(message.contains("music.m4a"), "{message}");
    }

    #[test]
    fn an_unreadable_title_card_is_named_before_rendering() {
        let scrap = Scrap::new("title-missing");
        let mut edit_list = reel();
        edit_list.title = Some(TitleCard {
            image: scrap.dir.join("title.png"),
            seconds: 2.0,
        });

        let error = edit_list.validate(&source()).expect_err("must be rejected");
        let message = error.to_string();
        assert!(message.contains("title card image"), "{message}");
        assert!(message.contains("title.png"), "{message}");
    }

    #[test]
    fn a_readable_overlay_title_and_music_are_accepted() {
        let scrap = Scrap::new("present");
        let mut edit_list = reel();
        edit_list.clips[0].overlay = Some(scrap.file("overlay.png"));
        edit_list.title = Some(TitleCard {
            image: scrap.file("title.png"),
            seconds: 2.0,
        });
        edit_list.music = Some(scrap.file("music.m4a"));

        edit_list
            .validate(&source())
            .expect("everything is readable");
        assert!(edit_list.has_music());
    }

    #[test]
    fn padding_is_clamped_to_the_recording() {
        let mut edit_list = reel();
        edit_list.lead_in_seconds = 1.0;
        edit_list.lead_out_seconds = 1.0;

        // Inside the recording, padding is applied on both sides.
        assert_eq!(edit_list.padded_span(&edit_list.clips[0], 10.0), (3.0, 7.0));

        // At either edge, the span stops at the recording rather than running
        // past it, which is what lets a clip at the very start or end render.
        let first = EditClip {
            start_seconds: 0.2,
            end_seconds: 2.0,
            overlay: None,
        };
        assert_eq!(edit_list.padded_span(&first, 10.0), (0.0, 3.0));

        let last = EditClip {
            start_seconds: 8.0,
            end_seconds: 9.8,
            overlay: None,
        };
        assert_eq!(edit_list.padded_span(&last, 10.0), (7.0, 10.0));
    }
}
