//! Sportcut Service Protocol v1.
//!
//! This crate is the single source of truth for the wire contract between the
//! Flutter client and the Sportcut background service. It defines the frame
//! codec, the JSON-RPC subset, the handshake, the method names, the error
//! codes, and the protocol version rules described in
//! `docs/architecture/protocol.md`.
//!
//! The crate deliberately contains no transport, no service logic, and no
//! engine types: it is data and constants only, so both sides can share it
//! without coupling to an implementation.

#![forbid(unsafe_code)]

pub mod error;
pub mod frame;
pub mod handshake;
pub mod method;
pub mod rpc;
pub mod version;

pub use error::{code, code_for_kind, kind, kind_for_code, ERROR_CODES};
pub use frame::{read_frame, write_frame, FrameError, LENGTH_PREFIX_BYTES, MAX_FRAME_BYTES};
pub use handshake::{
    CatalogInfo, ClientInfo, HelloParams, HelloResult, ServiceInfo, ServiceLimits, ServicePaths,
};
pub use method::{
    required_capability, ENGINE_METHODS, LIBRARY_METHODS, NOTIFICATION_METHODS, SERVICE_METHODS,
};
pub use rpc::{ErrorObject, JsonRpcVersion, Notification, Request, RequestId, Response};
pub use version::{
    negotiate, ProtocolVersion, VersionMismatch, PROTOCOL_MAJOR, PROTOCOL_MINOR, PROTOCOL_VERSION,
    SERVED_CAPABILITIES,
};
