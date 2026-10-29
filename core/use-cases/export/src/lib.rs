//! Highlight video rendering.
//!
//! The reel is described by an [`EditList`] — ordered clips, their padding, the
//! score to show, a title, and music — and rendered by a backend that reads
//! local files only. Today that backend is the `ffmpeg` the media layer already
//! uses, which is a development path: a GPL build cannot ship, and a packaged
//! macOS app needs a platform-native renderer. The edit list is deliberately
//! independent of the backend so a platform-native renderer can replace it
//! without the client or the catalog changing.

#![forbid(unsafe_code)]

mod edit_list;
mod render;

pub use edit_list::{EditClip, EditList, TitleCard};
pub use render::{
    render, ExportContext, RenderOutput, STAGES, STAGE_FINALIZE, STAGE_PREPARE, STAGE_RENDER,
};

/// Where a match's rendered reel is written, relative to its match directory.
///
/// One reel per match, replaced when the user exports again: the manifest
/// records an artifact kind once, and keeping the path stable means a re-render
/// cannot leave orphaned files behind.
pub const EXPORT_RELATIVE_PATH: &str = "export/highlight.mp4";
