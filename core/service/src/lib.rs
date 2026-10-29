//! The Sportcut background service, Phase 0-1 skeleton.
//!
//! The service is a separate process that speaks the Sportcut Service Protocol
//! v1 over a Unix domain socket. This crate owns the transport, the lifecycle
//! state machine, the handshake, and the dispatcher seam. Engine and catalog
//! methods are implemented in [`engine`] as thin adapters over the
//! `sportcut-api` facade; catalog methods remain `method_not_found` until a
//! later phase fills them in.
//!
//! The wire types, frame codec, and version rules live in `sportcut-protocol`;
//! this crate must not duplicate them.
//!
//! # Safety
//!
//! Every operating-system call is made through a safe `nix` wrapper. There is
//! no `unsafe` code in this crate and no lint exception; see [`os_glue`] for
//! the rationale and for where a future exception would be isolated.

pub mod config;
pub mod engine;
pub mod error;
pub mod idempotency;
pub mod logging;
pub mod methods;
pub mod os_glue;
pub mod paths;
pub mod rpc;
pub mod security;
pub mod server;
pub mod state_root;

pub use config::Config;
pub use server::{BindResult, Server, ServerHandle};
