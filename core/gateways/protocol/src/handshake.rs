//! The `service.hello` handshake, protocol §2.
//!
//! These types are only the payloads of the first request and its result. The
//! frame, `jsonrpc`, and `id` members come from [`crate::rpc`]; method,
//! token, and capability validation belong to the service.

use serde::{Deserialize, Serialize};

use crate::version::ProtocolVersion;

/// `service.hello` params.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HelloParams {
    /// The protocol version the client speaks.
    pub protocol: ProtocolVersion,
    /// Identity of the client build.
    pub client: ClientInfo,
    /// Per-launch authentication token.
    pub token: String,
    /// Capabilities the client offers; the service intersects them.
    pub capabilities: Vec<String>,
}

impl HelloParams {
    /// Build a handshake request payload.
    pub fn new(
        protocol: ProtocolVersion,
        client: ClientInfo,
        token: impl Into<String>,
        capabilities: Vec<String>,
    ) -> Self {
        Self {
            protocol,
            client,
            token: token.into(),
            capabilities,
        }
    }
}

/// Identity of the calling client.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClientInfo {
    /// Client application name, for example `Sportcut.app`.
    pub name: String,
    /// Client marketing version.
    pub version: String,
    /// Client build identifier.
    pub build: String,
}

/// `service.hello` result.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HelloResult {
    /// Identity of the running service.
    pub service: ServiceInfo,
    /// The effective protocol version for this connection.
    pub protocol: ProtocolVersion,
    /// Catalog schema and ownership state.
    pub catalog: CatalogInfo,
    /// Absolute service state root.
    pub state_root: String,
    /// Absolute Unix-socket endpoint path.
    pub endpoint: String,
    /// Absolute paths the client may use for playback and render inputs.
    pub paths: ServicePaths,
    /// The capability intersection the service will serve.
    pub capabilities: Vec<String>,
    /// Negotiated limits for this service build.
    pub limits: ServiceLimits,
}

/// Identity and version of the running service.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServiceInfo {
    /// Executable name, for example `sportcutd`.
    pub name: String,
    /// Service marketing version; equals the app version in v1.
    pub version: String,
    /// Service build identifier.
    pub build: String,
    /// Random identity of this service process.
    pub instance_id: String,
    /// Operating-system process id.
    pub pid: u32,
}

/// Catalog schema and ownership state.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CatalogInfo {
    /// Catalog schema version; `6` for the Phase 4 target.
    pub schema_version: u32,
    /// `"service"` or `"client"`; kept as a string so a future owner is not a
    /// deserialization failure.
    pub owner: String,
    /// Schema version the catalog was adopted from, or `null`.
    pub adopted_from: Option<String>,
}

/// Absolute paths returned for playback and render inputs.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServicePaths {
    /// Root of the service-owned recordings.
    pub recordings: String,
    /// Root of the service-owned match artifact directories.
    pub matches: String,
    /// Root of per-export overlay and title input directories.
    pub render_inputs: String,
}

/// Negotiated service limits from protocol §2.2.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServiceLimits {
    /// Largest frame payload in bytes: 16 MiB.
    pub max_frame_bytes: u32,
    /// In-flight requests allowed per connection.
    pub max_in_flight_per_connection: u32,
    /// Open connections allowed.
    pub max_connections: u32,
    /// Progress notifications coalesced per second per job.
    pub progress_per_second: u32,
    /// Default player-track window in seconds.
    pub track_window_default_seconds: u32,
    /// Maximum player-track window in seconds.
    pub track_window_max_seconds: u32,
    /// Lightweight request timeout seen by the client.
    pub request_timeout_ms: u32,
    /// Maximum Unix-socket path length in UTF-8 bytes.
    pub endpoint_max_bytes: u32,
}

impl Default for ServiceLimits {
    fn default() -> Self {
        Self {
            max_frame_bytes: crate::frame::MAX_FRAME_BYTES as u32,
            max_in_flight_per_connection: 64,
            max_connections: 8,
            progress_per_second: 20,
            track_window_default_seconds: 60,
            track_window_max_seconds: 300,
            request_timeout_ms: 30_000,
            endpoint_max_bytes: 103,
        }
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;
    use crate::rpc::Request;

    fn client_info() -> ClientInfo {
        ClientInfo {
            name: "Sportcut.app".to_string(),
            version: "0.1.0".to_string(),
            build: "20261029.1".to_string(),
        }
    }

    #[test]
    fn hello_params_match_the_protocol_example() {
        let params = HelloParams::new(
            ProtocolVersion::new(1, 0),
            client_info(),
            "b7f0c2a4e5d64f0a9c1e2d3b4a5c6d7e",
            vec![
                "engine.v1".to_string(),
                "catalog.v1".to_string(),
                "custody.v1".to_string(),
                "notifications.v1".to_string(),
            ],
        );

        assert_eq!(
            serde_json::to_value(&params).expect("serialize hello params"),
            json!({
                "protocol": { "major": 1, "minor": 0 },
                "client": {
                    "name": "Sportcut.app",
                    "version": "0.1.0",
                    "build": "20261029.1"
                },
                "token": "b7f0c2a4e5d64f0a9c1e2d3b4a5c6d7e",
                "capabilities": [
                    "engine.v1",
                    "catalog.v1",
                    "custody.v1",
                    "notifications.v1"
                ]
            })
        );
    }

    #[test]
    fn hello_request_serializes_as_the_first_frame() {
        let params = HelloParams::new(
            ProtocolVersion::new(1, 0),
            client_info(),
            "token",
            vec!["engine.v1".to_string()],
        );
        let request = Request::new(
            1_i64,
            crate::method::SERVICE_HELLO,
            serde_json::to_value(&params).expect("serialize params"),
        );

        let value = serde_json::to_value(&request).expect("serialize request");
        assert_eq!(value["jsonrpc"], "2.0");
        assert_eq!(value["method"], "service.hello");
        assert_eq!(value["id"], 1);
        assert_eq!(
            value["params"]["protocol"],
            json!({ "major": 1, "minor": 0 })
        );
    }

    #[test]
    fn hello_result_deserializes_from_the_protocol_example() {
        let result: HelloResult = serde_json::from_value(json!({
            "service": {
                "name": "sportcutd",
                "version": "0.1.0",
                "build": "20261029.1",
                "instanceId": "0f6b0f3e-6f7a-4f3e-9f0e-2d1c4b5a6978",
                "pid": 48213
            },
            "protocol": { "major": 1, "minor": 0 },
            "catalog": {
                "schemaVersion": 6,
                "owner": "service",
                "adoptedFrom": "v5"
            },
            "stateRoot": "/Users/ana/Library/Containers/com.sportcut.sportcut/Data/Library/Application Support/Sportcut",
            "endpoint": "/Users/ana/Library/Containers/com.sportcut.sportcut/Data/run/s.sock",
            "paths": {
                "recordings": "/.../Sportcut/recordings",
                "matches": "/.../Sportcut/matches",
                "renderInputs": "/.../Sportcut/render-inputs"
            },
            "capabilities": [
                "engine.v1",
                "catalog.v1",
                "custody.v1",
                "notifications.v1",
                "idempotency.v1",
                "playback.path.v1",
                "diagnostics.v1"
            ],
            "limits": {
                "maxFrameBytes": 16777216,
                "maxInFlightPerConnection": 64,
                "maxConnections": 8,
                "progressPerSecond": 20,
                "trackWindowDefaultSeconds": 60,
                "trackWindowMaxSeconds": 300,
                "requestTimeoutMs": 30000,
                "endpointMaxBytes": 103
            }
        }))
        .expect("deserialize hello result");

        assert_eq!(result.service.name, "sportcutd");
        assert_eq!(
            result.service.instance_id,
            "0f6b0f3e-6f7a-4f3e-9f0e-2d1c4b5a6978"
        );
        assert_eq!(result.service.pid, 48213);
        assert_eq!(result.protocol, ProtocolVersion::new(1, 0));
        assert_eq!(result.catalog.schema_version, 6);
        assert_eq!(result.catalog.owner, "service");
        assert_eq!(result.catalog.adopted_from.as_deref(), Some("v5"));
        assert_eq!(result.paths.render_inputs, "/.../Sportcut/render-inputs");
        assert_eq!(result.limits.max_frame_bytes, 16_777_216);
        assert_eq!(result.limits.request_timeout_ms, 30_000);
        assert_eq!(result.limits.endpoint_max_bytes, 103);
        assert_eq!(result.capabilities.len(), 7);
    }

    #[test]
    fn hello_result_round_trips() {
        let result = HelloResult {
            service: ServiceInfo {
                name: "sportcutd".to_string(),
                version: "0.1.0".to_string(),
                build: "20261029.1".to_string(),
                instance_id: "instance-1".to_string(),
                pid: 1234,
            },
            protocol: ProtocolVersion::V1_0,
            catalog: CatalogInfo {
                schema_version: 0,
                owner: "client".to_string(),
                adopted_from: None,
            },
            state_root: "/state".to_string(),
            endpoint: "/state/run/s.sock".to_string(),
            paths: ServicePaths {
                recordings: "/state/recordings".to_string(),
                matches: "/state/matches".to_string(),
                render_inputs: "/state/render-inputs".to_string(),
            },
            capabilities: vec!["engine.v1".to_string()],
            limits: ServiceLimits::default(),
        };

        let value = serde_json::to_value(&result).expect("serialize hello result");
        assert_eq!(value["catalog"]["adoptedFrom"], serde_json::Value::Null);
        let decoded: HelloResult = serde_json::from_value(value).expect("deserialize");
        assert_eq!(decoded, result);
    }

    #[test]
    fn default_limits_match_the_protocol_example() {
        let limits = ServiceLimits::default();
        assert_eq!(limits.max_frame_bytes, 16_777_216);
        assert_eq!(limits.max_in_flight_per_connection, 64);
        assert_eq!(limits.max_connections, 8);
        assert_eq!(limits.progress_per_second, 20);
        assert_eq!(limits.track_window_default_seconds, 60);
        assert_eq!(limits.track_window_max_seconds, 300);
        assert_eq!(limits.request_timeout_ms, 30_000);
        assert_eq!(limits.endpoint_max_bytes, 103);
    }
}
