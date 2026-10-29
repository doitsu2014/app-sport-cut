//! Protocol error codes and stable error kinds.
//!
//! Protocol §8 freezes the numeric codes and their `kind` strings. `message`
//! is diagnostic, but `code` and `data.kind` are the contract the client
//! switches on.

/// Numeric JSON-RPC and protocol error codes, verbatim from protocol §8.
pub mod code {
    /// Frame is not valid JSON.
    pub const PARSE_ERROR: i32 = -32700;
    /// Not a valid request object, batch, or bad `id`.
    pub const INVALID_REQUEST: i32 = -32600;
    /// Unknown method or capability not negotiated.
    pub const METHOD_NOT_FOUND: i32 = -32601;
    /// Missing, malformed, or out-of-range params; also `invalid_input`.
    pub const INVALID_PARAMS: i32 = -32602;
    /// Unexpected service failure.
    pub const INTERNAL: i32 = -32603;
    /// Missing or wrong token, or a different UID.
    pub const UNAUTHORIZED: i32 = -32000;
    /// Protocol major not supported.
    pub const VERSION_MISMATCH: i32 = -32001;
    /// The first method was not `service.hello`.
    pub const HANDSHAKE_REQUIRED: i32 = -32002;
    /// Frame over 16 MiB or zero length.
    pub const FRAME_TOO_LARGE: i32 = -32003;
    /// Filesystem operation failed.
    pub const IO: i32 = -32020;
    /// Valid request outside this build.
    pub const UNSUPPORTED: i32 = -32022;
    /// ffmpeg/ffprobe missing or unusable.
    pub const TOOLCHAIN_UNAVAILABLE: i32 = -32023;
    /// Media tool returned an error.
    pub const MEDIA_FAILED: i32 = -32024;
    /// File could not be read as media.
    pub const PROBE_FAILED: i32 = -32025;
    /// Manifest or artifact inconsistent.
    pub const ARTIFACT: i32 = -32026;
    /// Result exceeds 16 MiB.
    pub const RESPONSE_TOO_LARGE: i32 = -32027;
    /// Admission control rejected the job.
    pub const JOB_REJECTED: i32 = -32030;
    /// A job stage failed.
    pub const JOB_FAILED: i32 = -32031;
    /// Cooperative cancellation.
    pub const CANCELLED: i32 = -32032;
    /// No such match, rally, clip, or workspace.
    pub const NOT_FOUND: i32 = -32040;
    /// Duplicate id or conflicting write.
    pub const CONFLICT: i32 = -32041;
    /// Unknown job, often after a service restart.
    pub const JOB_NOT_FOUND: i32 = -32042;
    /// Legacy catalog not adopted yet.
    pub const MIGRATION_REQUIRED: i32 = -32043;
    /// Another writer holds the catalog.
    pub const CATALOG_LOCKED: i32 = -32044;
    /// The Unix socket path exceeds 103 bytes.
    pub const ENDPOINT_TOO_LONG: i32 = -32045;
}

/// Stable error kind strings carried in `error.data.kind`, verbatim from
/// protocol §8.
pub mod kind {
    /// Kind for [`super::code::PARSE_ERROR`].
    pub const PARSE_ERROR: &str = "parse_error";
    /// Kind for [`super::code::INVALID_REQUEST`].
    pub const INVALID_REQUEST: &str = "invalid_request";
    /// Kind for [`super::code::METHOD_NOT_FOUND`].
    pub const METHOD_NOT_FOUND: &str = "method_not_found";
    /// Kind for [`super::code::INVALID_PARAMS`].
    pub const INVALID_PARAMS: &str = "invalid_params";
    /// Kind for [`super::code::INTERNAL`].
    pub const INTERNAL: &str = "internal";
    /// Kind for [`super::code::UNAUTHORIZED`].
    pub const UNAUTHORIZED: &str = "unauthorized";
    /// Kind for [`super::code::VERSION_MISMATCH`].
    pub const VERSION_MISMATCH: &str = "version_mismatch";
    /// Kind for [`super::code::HANDSHAKE_REQUIRED`].
    pub const HANDSHAKE_REQUIRED: &str = "handshake_required";
    /// Kind for [`super::code::FRAME_TOO_LARGE`].
    pub const FRAME_TOO_LARGE: &str = "frame_too_large";
    /// Kind for [`super::code::IO`].
    pub const IO: &str = "io";
    /// Kind for [`super::code::UNSUPPORTED`].
    pub const UNSUPPORTED: &str = "unsupported";
    /// Kind for [`super::code::TOOLCHAIN_UNAVAILABLE`].
    pub const TOOLCHAIN_UNAVAILABLE: &str = "toolchain_unavailable";
    /// Kind for [`super::code::MEDIA_FAILED`].
    pub const MEDIA_FAILED: &str = "media_failed";
    /// Kind for [`super::code::PROBE_FAILED`].
    pub const PROBE_FAILED: &str = "probe_failed";
    /// Kind for [`super::code::ARTIFACT`].
    pub const ARTIFACT: &str = "artifact";
    /// Kind for [`super::code::RESPONSE_TOO_LARGE`].
    pub const RESPONSE_TOO_LARGE: &str = "response_too_large";
    /// Kind for [`super::code::JOB_REJECTED`].
    pub const JOB_REJECTED: &str = "job_rejected";
    /// Kind for [`super::code::JOB_FAILED`].
    pub const JOB_FAILED: &str = "job_failed";
    /// Kind for [`super::code::CANCELLED`].
    pub const CANCELLED: &str = "cancelled";
    /// Kind for [`super::code::NOT_FOUND`].
    pub const NOT_FOUND: &str = "not_found";
    /// Kind for [`super::code::CONFLICT`].
    pub const CONFLICT: &str = "conflict";
    /// Kind for [`super::code::JOB_NOT_FOUND`].
    pub const JOB_NOT_FOUND: &str = "job_not_found";
    /// Kind for [`super::code::MIGRATION_REQUIRED`].
    pub const MIGRATION_REQUIRED: &str = "migration_required";
    /// Kind for [`super::code::CATALOG_LOCKED`].
    pub const CATALOG_LOCKED: &str = "catalog_locked";
    /// Kind for [`super::code::ENDPOINT_TOO_LONG`].
    pub const ENDPOINT_TOO_LONG: &str = "endpoint_too_long";
}

/// Every documented code with its stable kind, in protocol §8 table order.
pub const ERROR_CODES: &[(i32, &str)] = &[
    (code::PARSE_ERROR, kind::PARSE_ERROR),
    (code::INVALID_REQUEST, kind::INVALID_REQUEST),
    (code::METHOD_NOT_FOUND, kind::METHOD_NOT_FOUND),
    (code::INVALID_PARAMS, kind::INVALID_PARAMS),
    (code::INTERNAL, kind::INTERNAL),
    (code::UNAUTHORIZED, kind::UNAUTHORIZED),
    (code::VERSION_MISMATCH, kind::VERSION_MISMATCH),
    (code::HANDSHAKE_REQUIRED, kind::HANDSHAKE_REQUIRED),
    (code::FRAME_TOO_LARGE, kind::FRAME_TOO_LARGE),
    (code::IO, kind::IO),
    (code::UNSUPPORTED, kind::UNSUPPORTED),
    (code::TOOLCHAIN_UNAVAILABLE, kind::TOOLCHAIN_UNAVAILABLE),
    (code::MEDIA_FAILED, kind::MEDIA_FAILED),
    (code::PROBE_FAILED, kind::PROBE_FAILED),
    (code::ARTIFACT, kind::ARTIFACT),
    (code::RESPONSE_TOO_LARGE, kind::RESPONSE_TOO_LARGE),
    (code::JOB_REJECTED, kind::JOB_REJECTED),
    (code::JOB_FAILED, kind::JOB_FAILED),
    (code::CANCELLED, kind::CANCELLED),
    (code::NOT_FOUND, kind::NOT_FOUND),
    (code::CONFLICT, kind::CONFLICT),
    (code::JOB_NOT_FOUND, kind::JOB_NOT_FOUND),
    (code::MIGRATION_REQUIRED, kind::MIGRATION_REQUIRED),
    (code::CATALOG_LOCKED, kind::CATALOG_LOCKED),
    (code::ENDPOINT_TOO_LONG, kind::ENDPOINT_TOO_LONG),
];

/// Look up the stable kind for a numeric error code.
pub fn kind_for_code(code: i32) -> Option<&'static str> {
    ERROR_CODES
        .iter()
        .find_map(|(known_code, kind)| (*known_code == code).then_some(*kind))
}

/// Look up the numeric code for a stable kind string.
pub fn code_for_kind(kind: &str) -> Option<i32> {
    ERROR_CODES
        .iter()
        .find_map(|(code, known_kind)| (*known_kind == kind).then_some(*code))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn numeric_codes_match_the_protocol_table() {
        assert_eq!(code::PARSE_ERROR, -32700);
        assert_eq!(code::INVALID_REQUEST, -32600);
        assert_eq!(code::METHOD_NOT_FOUND, -32601);
        assert_eq!(code::INVALID_PARAMS, -32602);
        assert_eq!(code::INTERNAL, -32603);
        assert_eq!(code::UNAUTHORIZED, -32000);
        assert_eq!(code::VERSION_MISMATCH, -32001);
        assert_eq!(code::HANDSHAKE_REQUIRED, -32002);
        assert_eq!(code::FRAME_TOO_LARGE, -32003);
        assert_eq!(code::IO, -32020);
        assert_eq!(code::UNSUPPORTED, -32022);
        assert_eq!(code::TOOLCHAIN_UNAVAILABLE, -32023);
        assert_eq!(code::MEDIA_FAILED, -32024);
        assert_eq!(code::PROBE_FAILED, -32025);
        assert_eq!(code::ARTIFACT, -32026);
        assert_eq!(code::RESPONSE_TOO_LARGE, -32027);
        assert_eq!(code::JOB_REJECTED, -32030);
        assert_eq!(code::JOB_FAILED, -32031);
        assert_eq!(code::CANCELLED, -32032);
        assert_eq!(code::NOT_FOUND, -32040);
        assert_eq!(code::CONFLICT, -32041);
        assert_eq!(code::JOB_NOT_FOUND, -32042);
        assert_eq!(code::MIGRATION_REQUIRED, -32043);
        assert_eq!(code::CATALOG_LOCKED, -32044);
        assert_eq!(code::ENDPOINT_TOO_LONG, -32045);
    }

    #[test]
    fn kind_strings_match_the_protocol_table() {
        assert_eq!(kind::PARSE_ERROR, "parse_error");
        assert_eq!(kind::INVALID_REQUEST, "invalid_request");
        assert_eq!(kind::METHOD_NOT_FOUND, "method_not_found");
        assert_eq!(kind::INVALID_PARAMS, "invalid_params");
        assert_eq!(kind::INTERNAL, "internal");
        assert_eq!(kind::UNAUTHORIZED, "unauthorized");
        assert_eq!(kind::VERSION_MISMATCH, "version_mismatch");
        assert_eq!(kind::HANDSHAKE_REQUIRED, "handshake_required");
        assert_eq!(kind::FRAME_TOO_LARGE, "frame_too_large");
        assert_eq!(kind::IO, "io");
        assert_eq!(kind::UNSUPPORTED, "unsupported");
        assert_eq!(kind::TOOLCHAIN_UNAVAILABLE, "toolchain_unavailable");
        assert_eq!(kind::MEDIA_FAILED, "media_failed");
        assert_eq!(kind::PROBE_FAILED, "probe_failed");
        assert_eq!(kind::ARTIFACT, "artifact");
        assert_eq!(kind::RESPONSE_TOO_LARGE, "response_too_large");
        assert_eq!(kind::JOB_REJECTED, "job_rejected");
        assert_eq!(kind::JOB_FAILED, "job_failed");
        assert_eq!(kind::CANCELLED, "cancelled");
        assert_eq!(kind::NOT_FOUND, "not_found");
        assert_eq!(kind::CONFLICT, "conflict");
        assert_eq!(kind::JOB_NOT_FOUND, "job_not_found");
        assert_eq!(kind::MIGRATION_REQUIRED, "migration_required");
        assert_eq!(kind::CATALOG_LOCKED, "catalog_locked");
        assert_eq!(kind::ENDPOINT_TOO_LONG, "endpoint_too_long");
    }

    #[test]
    fn every_code_and_kind_round_trips() {
        assert_eq!(ERROR_CODES.len(), 25);
        for (code, kind) in ERROR_CODES {
            assert_eq!(kind_for_code(*code), Some(*kind));
            assert_eq!(code_for_kind(kind), Some(*code));
        }
        assert_eq!(kind_for_code(1), None);
        assert_eq!(code_for_kind("not_a_kind"), None);
    }
}
