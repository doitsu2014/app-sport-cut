//! Phase 0 protocol conformance harness.
//!
//! The corpus under `tests/corpus/` is the frozen v1 contract: the golden
//! request/response shapes for all 17 engine methods, the error table, and the
//! version-negotiation cases. Every fixture is replayed through the same types
//! and frame codec the service uses, so a change that breaks the wire shape
//! fails here before it reaches the client.

use std::collections::HashSet;
use std::io::Cursor;

use serde_json::{json, Value};
use sportcut_protocol::{
    code_for_kind, kind_for_code, negotiate, read_frame, write_frame, ErrorObject, FrameError,
    Notification, ProtocolVersion, Request, RequestId, Response, ENGINE_METHODS, LIBRARY_METHODS,
    MAX_FRAME_BYTES, NOTIFICATION_METHODS, PROTOCOL_VERSION, SERVED_CAPABILITIES, SERVICE_METHODS,
};

const ENGINE_CORPUS: &str = include_str!("corpus/engine.json");
const ERROR_CORPUS: &str = include_str!("corpus/errors.json");
const HANDSHAKE_CORPUS: &str = include_str!("corpus/handshake.json");

fn corpus(value: &str) -> Value {
    serde_json::from_str(value).expect("corpus file is valid JSON")
}

fn framed(payload: &[u8]) -> Vec<u8> {
    let mut bytes = (payload.len() as u32).to_be_bytes().to_vec();
    bytes.extend_from_slice(payload);
    bytes
}

#[test]
fn every_engine_method_has_a_golden_request_and_response() {
    let engine = corpus(ENGINE_CORPUS);
    let cases = engine["cases"].as_array().expect("cases array");

    let mut covered = HashSet::new();
    for case in cases {
        let method = case["method"].as_str().expect("method");
        assert!(
            ENGINE_METHODS.contains(&method),
            "{method} is not in the frozen engine table"
        );
        assert!(
            covered.insert(method.to_string()),
            "{method} appears twice in the corpus"
        );

        let request = Request::new(1_i64, method, case["request"].clone());
        let request_value = serde_json::to_value(&request).expect("serialize request");
        assert_eq!(request_value["jsonrpc"], "2.0");
        assert_eq!(request_value["method"], method);
        assert!(request_value["params"].is_object());

        let decoded: Request =
            serde_json::from_value(request_value.clone()).expect("request round-trips");
        assert_eq!(decoded, request);

        let response = Response::success(1_i64, case["result"].clone());
        let response_value = serde_json::to_value(&response).expect("serialize response");
        assert_eq!(response_value["id"], 1);
        assert_eq!(response_value["result"], case["result"]);

        // The envelope survives the frame codec unchanged.
        let mut bytes = Vec::new();
        write_frame(&mut bytes, &request_value).expect("write request frame");
        let mut cursor = Cursor::new(bytes);
        assert_eq!(
            read_frame(&mut cursor).expect("read request frame"),
            request_value
        );
    }

    let expected: HashSet<String> = ENGINE_METHODS.iter().map(|m| (*m).to_string()).collect();
    assert_eq!(
        covered, expected,
        "the corpus must cover every engine method exactly once"
    );
    assert_eq!(cases.len(), 17);
}

#[test]
fn the_error_corpus_matches_the_stable_error_table() {
    let errors = corpus(ERROR_CORPUS);
    let cases = errors["cases"].as_array().expect("cases array");
    assert_eq!(cases.len(), sportcut_protocol::ERROR_CODES.len());

    for case in cases {
        let code = case["code"].as_i64().expect("code") as i32;
        let kind = case["kind"].as_str().expect("kind");
        assert_eq!(kind_for_code(code), Some(kind), "code {code}");
        assert_eq!(code_for_kind(kind), Some(code), "kind {kind}");

        let object = ErrorObject::new(code, "diagnostic").with_data(json!({
            "kind": kind,
            "retryable": false,
            "userMessage": "Try again.",
        }));
        let value = serde_json::to_value(object).expect("serialize error");
        assert_eq!(value["code"], code);
        assert_eq!(value["data"]["kind"], kind);
    }
}

#[test]
fn the_handshake_corpus_matches_version_negotiation_and_capabilities() {
    let handshake = corpus(HANDSHAKE_CORPUS);

    for case in handshake["negotiation"].as_array().expect("negotiation") {
        let service = ProtocolVersion::new(
            case["service"]["major"].as_u64().expect("major") as u16,
            case["service"]["minor"].as_u64().expect("minor") as u16,
        );
        let client = ProtocolVersion::new(
            case["client"]["major"].as_u64().expect("major") as u16,
            case["client"]["minor"].as_u64().expect("minor") as u16,
        );

        match case.get("effective") {
            Some(effective) => {
                let expected = ProtocolVersion::new(
                    effective["major"].as_u64().expect("major") as u16,
                    effective["minor"].as_u64().expect("minor") as u16,
                );
                assert_eq!(negotiate(service, client), Ok(expected));
            }
            None => {
                let mismatch = negotiate(service, client).expect_err("major mismatch");
                let supported = &case["mismatch"];
                assert_eq!(
                    mismatch.supported,
                    ProtocolVersion::new(
                        supported["major"].as_u64().expect("major") as u16,
                        supported["minor"].as_u64().expect("minor") as u16,
                    )
                );
            }
        }
    }

    let defined: Vec<String> = handshake["capabilities"]
        .as_array()
        .expect("capabilities")
        .iter()
        .map(|value| value.as_str().expect("capability").to_string())
        .collect();
    assert_eq!(
        defined,
        sportcut_protocol::version::CAPABILITIES
            .iter()
            .map(|value| (*value).to_string())
            .collect::<Vec<_>>()
    );

    let served: Vec<String> = handshake["servedCapabilities"]
        .as_array()
        .expect("served")
        .iter()
        .map(|value| value.as_str().expect("capability").to_string())
        .collect();
    assert_eq!(
        served,
        SERVED_CAPABILITIES
            .iter()
            .map(|value| (*value).to_string())
            .collect::<Vec<_>>()
    );
    assert!(served.iter().all(|capability| defined.contains(capability)));
}

#[test]
fn the_frozen_method_tables_are_unique_and_well_formed() {
    let all: Vec<&str> = SERVICE_METHODS
        .iter()
        .chain(ENGINE_METHODS.iter())
        .chain(LIBRARY_METHODS.iter())
        .copied()
        .collect();
    let unique: HashSet<&str> = all.iter().copied().collect();
    assert_eq!(unique.len(), all.len(), "request method names are unique");

    for method in SERVICE_METHODS {
        assert!(method.starts_with("service."), "{method}");
    }
    for method in ENGINE_METHODS {
        assert!(method.starts_with("engine."), "{method}");
    }
    for method in LIBRARY_METHODS {
        assert!(method.starts_with("library."), "{method}");
    }
    for method in NOTIFICATION_METHODS {
        assert!(
            method.starts_with("job.")
                || method.starts_with("catalog.")
                || method.starts_with("service."),
            "{method}"
        );
    }
    assert!(!ENGINE_METHODS.contains(&"engine.start.doesNotExist"));
    assert_eq!(PROTOCOL_VERSION, ProtocolVersion::new(1, 0));
}

#[test]
fn framing_edge_cases_follow_the_contract() {
    // Zero-length frames are refused before a payload is read.
    assert!(matches!(
        read_frame(&mut Cursor::new(0_u32.to_be_bytes().to_vec())),
        Err(FrameError::Empty)
    ));

    // Oversized frames are refused from the prefix alone.
    let declared = (MAX_FRAME_BYTES + 1) as u32;
    assert!(matches!(
        read_frame(&mut Cursor::new(declared.to_be_bytes().to_vec())),
        Err(FrameError::TooLarge { .. })
    ));

    // Malformed JSON and non-object payloads are distinguishable.
    assert!(matches!(
        read_frame(&mut Cursor::new(framed(b"{not json"))),
        Err(FrameError::InvalidJson(_))
    ));
    assert!(matches!(
        read_frame(&mut Cursor::new(framed(b"[1,2,3]"))),
        Err(FrameError::NotAnObject)
    ));

    // A frame split across reads is reassembled.
    let message = json!({ "jsonrpc": "2.0", "method": "service.ping", "params": {} });
    let mut bytes = Vec::new();
    write_frame(&mut bytes, &message).expect("write");
    struct OneByteAtATime<'a>(&'a [u8]);
    impl std::io::Read for OneByteAtATime<'_> {
        fn read(&mut self, buffer: &mut [u8]) -> std::io::Result<usize> {
            if self.0.is_empty() || buffer.is_empty() {
                return Ok(0);
            }
            buffer[0] = self.0[0];
            self.0 = &self.0[1..];
            Ok(1)
        }
    }
    let decoded = read_frame(&mut OneByteAtATime(&bytes)).expect("partial reads are reassembled");
    assert_eq!(decoded, message);
}

#[test]
fn null_ids_are_rejected_and_duplicate_ids_are_correlated() {
    let null_id = json!({ "jsonrpc": "2.0", "id": null, "method": "service.ping", "params": {} });
    assert!(
        serde_json::from_value::<Request>(null_id).is_err(),
        "a request id must not be null"
    );

    let float_id = json!({ "jsonrpc": "2.0", "id": 1.5, "method": "service.ping", "params": {} });
    assert!(
        serde_json::from_value::<Request>(float_id).is_err(),
        "a request id must be a string or an integer"
    );

    // Duplicate ids are legal on the wire; the client correlates by id and the
    // second response is what completes the second request.
    let first = Request::new(7_i64, "service.ping", json!({}));
    let second = Request::new(7_i64, "service.info", json!({}));
    assert_eq!(first.id, second.id);
    let first_response = Response::success(first.id.clone(), json!({ "pong": true }));
    let second_response = Response::success(second.id.clone(), json!({ "build": "x" }));
    assert_eq!(first_response.id, RequestId::Number(7));
    assert_eq!(second_response.id, RequestId::Number(7));
    assert!(first_response.result.is_some());
    assert!(second_response.result.is_some());
}

#[test]
fn notifications_have_no_id_and_unknown_fields_are_ignored() {
    let notification = Notification::new("job.progress", json!({ "seq": 1 }));
    let value = serde_json::to_value(notification).expect("serialize");
    assert!(value.get("id").is_none());

    let with_extra = json!({
        "jsonrpc": "2.0",
        "id": 3,
        "method": "service.ping",
        "params": {},
        "clientRequestId": "key-1",
        "futureMember": { "ignored": true }
    });
    let decoded: Request = serde_json::from_value(with_extra).expect("extra members ignored");
    assert_eq!(decoded.client_request_id.as_deref(), Some("key-1"));
    assert_eq!(decoded.id, RequestId::Number(3));
}
