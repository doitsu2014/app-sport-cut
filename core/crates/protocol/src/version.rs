//! Protocol version constants, negotiation, and capability names.
//!
//! Protocol §2.3: the service supports one major version at a time. Within a
//! matching major it selects `min(client.minor, service.minor)`, and that
//! selected minor is the effective version for the connection.

use std::fmt;

use serde::{Deserialize, Serialize};

/// Major version of the protocol this crate implements.
pub const PROTOCOL_MAJOR: u16 = 1;

/// Minor version of the protocol this crate implements.
pub const PROTOCOL_MINOR: u16 = 0;

/// The protocol version this crate implements.
pub const PROTOCOL_VERSION: ProtocolVersion = ProtocolVersion::V1_0;

/// Capability groups named by protocol §12.
pub mod capability {
    /// The 17 engine facade methods.
    pub const ENGINE_V1: &str = "engine.v1";
    /// The catalog and editing-record methods.
    pub const CATALOG_V1: &str = "catalog.v1";
    /// Recording custody and playback paths.
    pub const CUSTODY_V1: &str = "custody.v1";
    /// Progress and state notifications.
    pub const NOTIFICATIONS_V1: &str = "notifications.v1";
    /// `clientRequestId` deduplication.
    pub const IDEMPOTENCY_V1: &str = "idempotency.v1";
    /// `library.recording.path` playback paths.
    pub const PLAYBACK_PATH_V1: &str = "playback.path.v1";
    /// `service.metrics` counters.
    pub const METRICS_V1: &str = "metrics.v1";
    /// `service.diagnostics` bundles.
    pub const DIAGNOSTICS_V1: &str = "diagnostics.v1";
}

/// Capabilities this protocol version defines, in protocol §12 order.
pub const CAPABILITIES: [&str; 8] = [
    capability::ENGINE_V1,
    capability::CATALOG_V1,
    capability::CUSTODY_V1,
    capability::NOTIFICATIONS_V1,
    capability::IDEMPOTENCY_V1,
    capability::PLAYBACK_PATH_V1,
    capability::METRICS_V1,
    capability::DIAGNOSTICS_V1,
];

/// Capabilities the current service build actually serves.
///
/// A capability must not appear here until every method and behaviour it
/// promises is implemented. `catalog.v1`, `custody.v1`, `playback.path.v1`,
/// `metrics.v1`, and `diagnostics.v1` are defined by protocol v1 but are not
/// served by the Phase 0-1 service, so they are deliberately absent.
pub const SERVED_CAPABILITIES: [&str; 3] = [
    capability::ENGINE_V1,
    capability::NOTIFICATIONS_V1,
    capability::IDEMPOTENCY_V1,
];

/// A protocol `{ "major": ..., "minor": ... }` pair.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct ProtocolVersion {
    /// Breaking-change version.
    pub major: u16,
    /// Additive-change version.
    pub minor: u16,
}

impl ProtocolVersion {
    /// Protocol 1.0, the version this crate implements.
    pub const V1_0: Self = Self {
        major: PROTOCOL_MAJOR,
        minor: PROTOCOL_MINOR,
    };

    /// Construct a version.
    pub const fn new(major: u16, minor: u16) -> Self {
        Self { major, minor }
    }

    /// Whether both versions share a major number.
    pub const fn is_major_compatible_with(self, other: Self) -> bool {
        self.major == other.major
    }
}

impl Default for ProtocolVersion {
    fn default() -> Self {
        Self::V1_0
    }
}

impl fmt::Display for ProtocolVersion {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}.{}", self.major, self.minor)
    }
}

/// The service and client do not share a major version.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct VersionMismatch {
    /// The protocol version the client asked to speak.
    pub requested: ProtocolVersion,
    /// The version the service supports; reported in `error.data.supported`.
    pub supported: ProtocolVersion,
}

impl fmt::Display for VersionMismatch {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "protocol major {} is not supported; this service supports {}",
            self.requested.major, self.supported
        )
    }
}

impl std::error::Error for VersionMismatch {}

/// Select the effective version for a connection.
///
/// Returns `Ok(min(client.minor, service.minor))` within the service's major,
/// or a [`VersionMismatch`] when the majors differ.
pub fn negotiate(
    service: ProtocolVersion,
    client: ProtocolVersion,
) -> Result<ProtocolVersion, VersionMismatch> {
    if !service.is_major_compatible_with(client) {
        return Err(VersionMismatch {
            requested: client,
            supported: service,
        });
    }
    Ok(ProtocolVersion::new(
        service.major,
        service.minor.min(client.minor),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_constants_are_one_zero() {
        assert_eq!(PROTOCOL_MAJOR, 1);
        assert_eq!(PROTOCOL_MINOR, 0);
        assert_eq!(PROTOCOL_VERSION, ProtocolVersion::new(1, 0));
        assert_eq!(PROTOCOL_VERSION.major, 1);
        assert_eq!(PROTOCOL_VERSION.minor, 0);
    }

    #[test]
    fn version_serializes_as_major_minor() {
        assert_eq!(
            serde_json::to_value(PROTOCOL_VERSION).expect("serialize version"),
            serde_json::json!({ "major": 1, "minor": 0 })
        );
    }

    #[test]
    fn negotiation_selects_the_lower_minor() {
        let service = ProtocolVersion::new(1, 4);
        assert_eq!(
            negotiate(service, ProtocolVersion::new(1, 2)),
            Ok(ProtocolVersion::new(1, 2))
        );
        assert_eq!(
            negotiate(service, ProtocolVersion::new(1, 9)),
            Ok(ProtocolVersion::new(1, 4))
        );
        assert_eq!(
            negotiate(ProtocolVersion::new(1, 0), ProtocolVersion::new(1, 5)),
            Ok(ProtocolVersion::new(1, 0))
        );
    }

    #[test]
    fn negotiation_rejects_a_different_major() {
        let mismatch = negotiate(ProtocolVersion::new(1, 0), ProtocolVersion::new(2, 0))
            .expect_err("major mismatch");
        assert_eq!(mismatch.requested, ProtocolVersion::new(2, 0));
        assert_eq!(mismatch.supported, ProtocolVersion::new(1, 0));
    }

    #[test]
    fn capability_names_are_stable() {
        assert_eq!(
            CAPABILITIES,
            [
                "engine.v1",
                "catalog.v1",
                "custody.v1",
                "notifications.v1",
                "idempotency.v1",
                "playback.path.v1",
                "metrics.v1",
                "diagnostics.v1",
            ]
        );
    }

    #[test]
    fn served_capabilities_are_a_subset_of_the_defined_ones() {
        for served in SERVED_CAPABILITIES {
            assert!(
                CAPABILITIES.contains(&served),
                "{served} is defined by protocol v1"
            );
        }
        assert!(SERVED_CAPABILITIES.contains(&capability::ENGINE_V1));
        assert!(SERVED_CAPABILITIES.contains(&capability::NOTIFICATIONS_V1));
        for unserved in [
            capability::CATALOG_V1,
            capability::CUSTODY_V1,
            capability::PLAYBACK_PATH_V1,
            capability::METRICS_V1,
            capability::DIAGNOSTICS_V1,
        ] {
            assert!(
                !SERVED_CAPABILITIES.contains(&unserved),
                "{unserved} is not served by this build"
            );
        }
    }
}
