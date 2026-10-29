//! JSON-RPC 2.0 message shapes used by the protocol.
//!
//! The protocol is a JSON-RPC 2.0 subset: requests and responses carry an
//! `id`, notifications do not, batches are not supported, and the payload of a
//! frame is always one object. Extra members are ignored on both sides.

use std::fmt;

use serde::{Deserialize, Deserializer, Serialize, Serializer};
use serde_json::Value;

/// The only supported `jsonrpc` member value: `"2.0"`.
pub const JSONRPC_VERSION: &str = "2.0";

/// The `jsonrpc` version marker.
///
/// Serialization always emits `"2.0"`; deserialization rejects any other
/// value, so a mis-versioned message cannot be silently accepted.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct JsonRpcVersion;

impl JsonRpcVersion {
    /// The version string carried on the wire.
    pub const VERSION: &'static str = JSONRPC_VERSION;
}

impl fmt::Display for JsonRpcVersion {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(JSONRPC_VERSION)
    }
}

impl Serialize for JsonRpcVersion {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(JSONRPC_VERSION)
    }
}

impl<'de> Deserialize<'de> for JsonRpcVersion {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let version = String::deserialize(deserializer)?;
        if version == JSONRPC_VERSION {
            Ok(Self)
        } else {
            Err(serde::de::Error::custom(format!(
                "unsupported jsonrpc version {version:?}; expected {JSONRPC_VERSION:?}"
            )))
        }
    }
}

/// A request correlation identifier: a string or an integer, never `null`.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(untagged)]
pub enum RequestId {
    /// An integer id.
    Number(i64),
    /// A string id.
    String(String),
}

impl From<i64> for RequestId {
    fn from(id: i64) -> Self {
        Self::Number(id)
    }
}

impl From<String> for RequestId {
    fn from(id: String) -> Self {
        Self::String(id)
    }
}

impl From<&str> for RequestId {
    fn from(id: &str) -> Self {
        Self::String(id.to_string())
    }
}

impl fmt::Display for RequestId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Number(id) => write!(formatter, "{id}"),
            Self::String(id) => formatter.write_str(id),
        }
    }
}

/// A request: `{"jsonrpc":"2.0","id":...,"method":"...","params":{...}}`.
///
/// `clientRequestId` is the idempotency key for mutating methods. It is a
/// top-level extension member, not part of `params`, and is omitted when the
/// caller does not supply one.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Request {
    /// Always `"2.0"`.
    #[serde(default)]
    pub jsonrpc: JsonRpcVersion,
    /// Correlation identifier, unique per connection while in flight.
    pub id: RequestId,
    /// Method name from the protocol method tables.
    pub method: String,
    /// Method parameters; an empty object when the method takes none.
    pub params: Value,
    /// Idempotency key for mutating methods.
    #[serde(
        rename = "clientRequestId",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub client_request_id: Option<String>,
}

impl Request {
    /// Build a request with the mandatory members set and no idempotency key.
    pub fn new(id: impl Into<RequestId>, method: impl Into<String>, params: Value) -> Self {
        Self {
            jsonrpc: JsonRpcVersion,
            id: id.into(),
            method: method.into(),
            params,
            client_request_id: None,
        }
    }

    /// Attach an idempotency key for a mutating method.
    pub fn with_client_request_id(mut self, key: impl Into<String>) -> Self {
        self.client_request_id = Some(key.into());
        self
    }
}

/// A response: exactly one of `result` or `error`, correlated by `id`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Response {
    /// Always `"2.0"`.
    #[serde(default)]
    pub jsonrpc: JsonRpcVersion,
    /// The id of the request this responds to.
    pub id: RequestId,
    /// The successful result, present for a success response.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    /// The failure, present for an error response.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorObject>,
}

impl Response {
    /// Build a success response.
    pub fn success(id: impl Into<RequestId>, result: Value) -> Self {
        Self {
            jsonrpc: JsonRpcVersion,
            id: id.into(),
            result: Some(result),
            error: None,
        }
    }

    /// Build an error response.
    pub fn from_error(id: impl Into<RequestId>, error: ErrorObject) -> Self {
        Self {
            jsonrpc: JsonRpcVersion,
            id: id.into(),
            result: None,
            error: Some(error),
        }
    }

    /// Whether this response carries an error.
    pub fn is_error(&self) -> bool {
        self.error.is_some()
    }
}

/// A notification: no `id`, fire-and-forget.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Notification {
    /// Always `"2.0"`.
    #[serde(default)]
    pub jsonrpc: JsonRpcVersion,
    /// Notification method name (`job.progress`, `job.state`, ...).
    pub method: String,
    /// Notification parameters.
    pub params: Value,
}

impl Notification {
    /// Build a notification.
    pub fn new(method: impl Into<String>, params: Value) -> Self {
        Self {
            jsonrpc: JsonRpcVersion,
            method: method.into(),
            params,
        }
    }
}

/// An error object: a stable numeric code, a diagnostic message, and optional
/// structured data.
///
/// `data.kind` and `code` are the stable contract; `message` is diagnostic and
/// must not be parsed.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ErrorObject {
    /// Numeric error code from [`crate::error::code`].
    pub code: i32,
    /// Diagnostic message; may name a file and reason.
    pub message: String,
    /// Optional structured context, including `kind`, `retryable`, and
    /// `userMessage` per protocol §8.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

impl ErrorObject {
    /// Build an error object without structured data.
    pub fn new(code: i32, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
            data: None,
        }
    }

    /// Attach structured error data.
    pub fn with_data(mut self, data: Value) -> Self {
        self.data = Some(data);
        self
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    #[test]
    fn request_serializes_with_the_mandatory_members() {
        let request = Request::new(10_i64, "engine.probe", json!({ "matchId": "match-1" }));

        assert_eq!(
            serde_json::to_value(&request).expect("serialize request"),
            json!({
                "jsonrpc": "2.0",
                "id": 10,
                "method": "engine.probe",
                "params": { "matchId": "match-1" }
            })
        );
    }

    #[test]
    fn client_request_id_is_a_top_level_member_and_omitted_when_absent() {
        let request = Request::new("req-1", "library.match.import", json!({}))
            .with_client_request_id("0f6b0f3e-6f7a-4f3e-9f0e-2d1c4b5a6978");

        let value = serde_json::to_value(&request).expect("serialize request");
        assert_eq!(
            value["clientRequestId"],
            "0f6b0f3e-6f7a-4f3e-9f0e-2d1c4b5a6978"
        );
        assert!(value.get("params").is_some());
        assert!(value["params"].get("clientRequestId").is_none());

        let plain = Request::new(1_i64, "service.ping", json!({}));
        let plain_value = serde_json::to_value(&plain).expect("serialize request");
        assert!(plain_value.get("clientRequestId").is_none());
    }

    #[test]
    fn request_round_trips_with_string_and_integer_ids() {
        let integer = Request::new(42_i64, "engine.job.status", json!({ "jobId": "job-1" }));
        let decoded: Request =
            serde_json::from_value(serde_json::to_value(&integer).expect("serialize request"))
                .expect("deserialize request");
        assert_eq!(decoded, integer);

        let string = Request::new("request-a", "service.health", json!({}));
        let decoded: Request =
            serde_json::from_value(serde_json::to_value(&string).expect("serialize"))
                .expect("deserialize request");
        assert_eq!(decoded, string);
    }

    #[test]
    fn success_response_has_no_error_member() {
        let response = Response::success(42_i64, json!({ "pong": true }));

        assert_eq!(
            serde_json::to_value(&response).expect("serialize response"),
            json!({
                "jsonrpc": "2.0",
                "id": 42,
                "result": { "pong": true }
            })
        );
        assert!(!response.is_error());
    }

    #[test]
    fn error_response_has_no_result_member() {
        let error = ErrorObject::new(crate::error::code::JOB_REJECTED, "job job-7 was rejected")
            .with_data(json!({
                "kind": "job_rejected",
                "retryable": false,
                "userMessage": "Another analysis job is running.",
                "details": { "runningJobId": "job-6" }
            }));
        let response = Response::from_error(42_i64, error);

        assert_eq!(
            serde_json::to_value(&response).expect("serialize response"),
            json!({
                "jsonrpc": "2.0",
                "id": 42,
                "error": {
                    "code": -32030,
                    "message": "job job-7 was rejected",
                    "data": {
                        "kind": "job_rejected",
                        "retryable": false,
                        "userMessage": "Another analysis job is running.",
                        "details": { "runningJobId": "job-6" }
                    }
                }
            })
        );
        assert!(response.is_error());
    }

    #[test]
    fn error_object_omits_absent_data() {
        let error = ErrorObject::new(crate::error::code::NOT_FOUND, "no such match");
        assert_eq!(
            serde_json::to_value(&error).expect("serialize error"),
            json!({ "code": -32040, "message": "no such match" })
        );
    }

    #[test]
    fn notification_has_no_id() {
        let notification = Notification::new("job.progress", json!({ "seq": 17 }));

        let value = serde_json::to_value(&notification).expect("serialize notification");
        assert_eq!(
            value,
            json!({
                "jsonrpc": "2.0",
                "method": "job.progress",
                "params": { "seq": 17 }
            })
        );
        assert!(value.get("id").is_none());
    }

    #[test]
    fn messages_round_trip_through_serde() {
        let notification = Notification::new("catalog.changed", json!({ "revision": 1042 }));
        let decoded: Notification =
            serde_json::from_value(serde_json::to_value(&notification).expect("serialize"))
                .expect("deserialize notification");
        assert_eq!(decoded, notification);
    }

    #[test]
    fn other_jsonrpc_versions_are_rejected() {
        let decoded = serde_json::from_value::<Notification>(json!({
            "jsonrpc": "1.0",
            "method": "job.state",
            "params": {}
        }));
        assert!(decoded.is_err());
    }

    #[test]
    fn jsonrpc_version_always_serializes_as_two_point_zero() {
        assert_eq!(
            serde_json::to_value(JsonRpcVersion).expect("serialize version"),
            json!("2.0")
        );
    }
}
