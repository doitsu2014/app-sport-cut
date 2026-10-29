//! The service's engine surface: the operations the background service calls.
//!
//! The Flutter client never links this crate. It reaches the engine over the
//! Sportcut Service Protocol, and `sportcut-service` — the JSON-RPC adapter —
//! calls the functions here. There is no FFI, no generated binding, and no
//! shared library: `sportcut-api` is an ordinary `rlib` and the app is a
//! separate process.
//!
//! See `docs/architecture/layering.md` for where this crate sits and
//! `docs/architecture/protocol.md` for the wire contract the service exposes.

mod convert;
mod dto;
mod facade;
mod jobs;
#[cfg(all(target_os = "macos", feature = "macos-tflite-eval"))]
mod player_tracking_job;
pub mod track_artifact;

pub use dto::*;
pub use facade::*;
