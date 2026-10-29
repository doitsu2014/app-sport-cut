//! Protocol errors with stable codes, kinds, and user-safe messages.
//!
//! `code` and `data.kind` are the contract the client switches on; `message`
//! is diagnostic only (protocol §8). Every error built here carries the three
//! required `data` members: `kind`, `retryable`, and `userMessage`.

use serde_json::{json, Map, Value};
use sportcut_protocol::{code, kind_for_code, ErrorObject};

/// A protocol error ready to be placed in a JSON-RPC error response.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProtocolError {
    /// Numeric code from [`sportcut_protocol::code`].
    pub code: i32,
    /// Diagnostic message; never shown to the user verbatim.
    pub message: String,
    /// Whether the same request may succeed later.
    pub retryable: bool,
    /// Safe, short, verb-first UI copy.
    pub user_message: String,
    /// Additional structured context; must never contain secrets.
    pub extra: Map<String, Value>,
}

impl ProtocolError {
    /// Build an error from a code and a diagnostic message.
    ///
    /// The kind, retryability, and user message come from the documented table;
    /// an undocumented code falls back to the `internal` shape.
    pub fn new(code: i32, message: impl Into<String>) -> Self {
        let kind = kind_for_code(code).unwrap_or(sportcut_protocol::kind::INTERNAL);
        Self {
            code,
            message: message.into(),
            retryable: retryable(kind),
            user_message: user_message(kind).to_string(),
            extra: Map::new(),
        }
    }

    /// Attach a structured `data.details` value.
    pub fn with_details(mut self, details: Value) -> Self {
        self.extra.insert("details".to_string(), details);
        self
    }

    /// Attach a member directly to `error.data`, such as `supported`.
    pub fn with_data_member(mut self, name: impl Into<String>, value: Value) -> Self {
        self.extra.insert(name.into(), value);
        self
    }

    /// The `error` object for a response.
    pub fn to_object(&self) -> ErrorObject {
        ErrorObject::new(self.code, self.message.clone()).with_data(self.data())
    }

    /// The complete `data` object.
    pub fn data(&self) -> Value {
        let mut data = Map::new();
        data.insert(
            "kind".to_string(),
            json!(kind_for_code(self.code).unwrap_or(sportcut_protocol::kind::INTERNAL)),
        );
        data.insert("retryable".to_string(), json!(self.retryable));
        data.insert("userMessage".to_string(), json!(self.user_message));
        for (name, value) in &self.extra {
            data.insert(name.clone(), value.clone());
        }
        Value::Object(data)
    }
}

fn retryable(kind: &str) -> bool {
    matches!(
        kind,
        sportcut_protocol::kind::INTERNAL
            | sportcut_protocol::kind::IO
            | sportcut_protocol::kind::TOOLCHAIN_UNAVAILABLE
            | sportcut_protocol::kind::MEDIA_FAILED
            | sportcut_protocol::kind::ARTIFACT
            | sportcut_protocol::kind::JOB_FAILED
            | sportcut_protocol::kind::MIGRATION_REQUIRED
            | sportcut_protocol::kind::CATALOG_LOCKED
    )
}

fn user_message(kind: &str) -> &'static str {
    match kind {
        sportcut_protocol::kind::PARSE_ERROR => "The request could not be read. Update the app.",
        sportcut_protocol::kind::INVALID_REQUEST => {
            "The request was not valid. Update the app and try again."
        }
        sportcut_protocol::kind::METHOD_NOT_FOUND => {
            "This version of Sportcut and its analysis service do not match. Reinstall the app."
        }
        sportcut_protocol::kind::INVALID_PARAMS => "Check the request and try again.",
        sportcut_protocol::kind::INTERNAL => {
            "The analysis service hit an unexpected problem. Try again."
        }
        sportcut_protocol::kind::UNAUTHORIZED => {
            "The analysis service could not authenticate this session. Restart the app."
        }
        sportcut_protocol::kind::VERSION_MISMATCH => {
            "This version of Sportcut does not match its analysis service. Reinstall the app."
        }
        sportcut_protocol::kind::HANDSHAKE_REQUIRED => "Reconnect to the analysis service.",
        sportcut_protocol::kind::FRAME_TOO_LARGE => {
            "The request is too large. Split it into smaller requests."
        }
        sportcut_protocol::kind::IO => {
            "The analysis service could not read or write a file. Try again."
        }
        sportcut_protocol::kind::UNSUPPORTED => {
            "This version of the analysis service does not support that operation."
        }
        sportcut_protocol::kind::TOOLCHAIN_UNAVAILABLE => {
            "Install the media tools, then try again."
        }
        sportcut_protocol::kind::MEDIA_FAILED => {
            "The media tools could not process the file. Try again."
        }
        sportcut_protocol::kind::PROBE_FAILED => {
            "That file is not a recording this app can read. Choose another file."
        }
        sportcut_protocol::kind::ARTIFACT => {
            "An analysis artifact is inconsistent. Regenerate it and try again."
        }
        sportcut_protocol::kind::RESPONSE_TOO_LARGE => {
            "The result is too large. Narrow the request and try again."
        }
        sportcut_protocol::kind::JOB_REJECTED => {
            "Another analysis job is running. Wait for it to finish or cancel it."
        }
        sportcut_protocol::kind::JOB_FAILED => {
            "The analysis job failed. Try again or check the media file."
        }
        sportcut_protocol::kind::CANCELLED => "The operation was cancelled.",
        sportcut_protocol::kind::NOT_FOUND => {
            "That item no longer exists. Refresh the library and try again."
        }
        sportcut_protocol::kind::CONFLICT => {
            "That item was changed somewhere else. Refresh and try again."
        }
        sportcut_protocol::kind::JOB_NOT_FOUND => {
            "The analysis job is no longer available. Run the operation again."
        }
        sportcut_protocol::kind::MIGRATION_REQUIRED => {
            "Adopt the existing library before continuing."
        }
        sportcut_protocol::kind::CATALOG_LOCKED => {
            "The library is busy in another window. Try again in a moment."
        }
        sportcut_protocol::kind::ENDPOINT_TOO_LONG => {
            "The service could not start because its socket path is too long. Use a shorter path."
        }
        _ => "The analysis service hit an unexpected problem. Try again.",
    }
}

impl ProtocolError {
    /// `handshake_required`: the first request was not `service.hello`.
    pub fn handshake_required() -> Self {
        Self::new(
            code::HANDSHAKE_REQUIRED,
            "the first request on a connection must be service.hello",
        )
    }

    /// `unauthorized`: missing or wrong token.
    pub fn unauthorized() -> Self {
        Self::new(
            code::UNAUTHORIZED,
            "the handshake token does not match this service's token",
        )
    }

    /// `invalid_params` with a diagnostic message.
    pub fn invalid_params(message: impl Into<String>) -> Self {
        Self::new(code::INVALID_PARAMS, message)
    }

    /// `invalid_request` with a diagnostic message.
    pub fn invalid_request(message: impl Into<String>) -> Self {
        Self::new(code::INVALID_REQUEST, message)
    }

    /// `method_not_found` for a method this build does not serve.
    pub fn method_not_found(method: &str) -> Self {
        Self::new(
            code::METHOD_NOT_FOUND,
            format!("unknown or unserved method {method}"),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sportcut_protocol::{code_for_kind, kind};

    #[test]
    fn error_data_carries_kind_retryable_and_user_message() {
        let error = ProtocolError::unauthorized().data();
        assert_eq!(error["kind"], json!(kind::UNAUTHORIZED));
        assert_eq!(error["retryable"], json!(false));
        assert!(error["userMessage"].as_str().is_some_and(|m| !m.is_empty()));
    }

    #[test]
    fn every_known_code_round_trips_through_the_error_object() {
        for (code, expected_kind) in sportcut_protocol::ERROR_CODES {
            let error = ProtocolError::new(*code, "diagnostic").to_object();
            assert_eq!(error.code, *code);
            let data = error.data.expect("data");
            assert_eq!(data["kind"], json!(expected_kind));
            assert_eq!(
                code_for_kind(data["kind"].as_str().expect("kind")),
                Some(*code)
            );
        }
    }

    #[test]
    fn extra_members_are_merged_into_data() {
        let error = ProtocolError::new(code::VERSION_MISMATCH, "major mismatch")
            .with_data_member("supported", json!({ "major": 1, "minor": 0 }));
        let data = error.data();
        assert_eq!(data["supported"], json!({ "major": 1, "minor": 0 }));
        assert_eq!(data["kind"], json!(kind::VERSION_MISMATCH));
    }
}
