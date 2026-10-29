//! Length-prefixed frame codec.
//!
//! Every message is one frame: a 4-byte big-endian unsigned payload length
//! followed by exactly that many bytes of UTF-8 JSON. Newline delimiters are
//! never used, and the payload carries no trailing byte.

use std::fmt;
use std::io::{self, Read, Write};

use serde::Serialize;
use serde_json::Value;

/// Bytes in the big-endian length prefix.
pub const LENGTH_PREFIX_BYTES: usize = 4;

/// Largest permitted payload, per protocol §1.3: 16 MiB.
pub const MAX_FRAME_BYTES: usize = 16 * 1024 * 1024;

/// Failure while reading or writing a frame.
///
/// Each variant maps to a protocol outcome: an empty or oversized frame is
/// reported as `frame_too_large` when a response can still be sent, invalid
/// UTF-8 or JSON as `parse_error`, and I/O failures close the connection.
#[derive(Debug)]
pub enum FrameError {
    /// The transport failed, or the peer closed mid-frame.
    Io(io::Error),
    /// The length prefix was zero; frames must carry at least one byte.
    Empty,
    /// The declared payload length exceeds [`MAX_FRAME_BYTES`].
    TooLarge {
        /// The declared or serialized payload length in bytes.
        length: u64,
    },
    /// The payload was not valid UTF-8.
    InvalidUtf8(std::str::Utf8Error),
    /// The payload was not valid JSON.
    InvalidJson(serde_json::Error),
    /// The JSON payload was valid but not an object, as §1.3 requires.
    NotAnObject,
    /// A value could not be serialized to JSON.
    Serialize(serde_json::Error),
}

impl fmt::Display for FrameError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(error) => write!(formatter, "frame I/O failed: {error}"),
            Self::Empty => formatter.write_str("frame payload must not be zero length"),
            Self::TooLarge { length } => write!(
                formatter,
                "frame payload length {length} exceeds the {} byte limit",
                MAX_FRAME_BYTES
            ),
            Self::InvalidUtf8(error) => {
                write!(formatter, "frame payload is not valid UTF-8: {error}")
            }
            Self::InvalidJson(error) => {
                write!(formatter, "frame payload is not valid JSON: {error}")
            }
            Self::NotAnObject => formatter.write_str("frame payload must be a JSON object"),
            Self::Serialize(error) => {
                write!(formatter, "frame payload could not be serialized: {error}")
            }
        }
    }
}

impl std::error::Error for FrameError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Io(error) => Some(error),
            Self::InvalidUtf8(error) => Some(error),
            Self::InvalidJson(error) | Self::Serialize(error) => Some(error),
            Self::Empty | Self::TooLarge { .. } | Self::NotAnObject => None,
        }
    }
}

impl From<io::Error> for FrameError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

/// Read one frame from `reader` and parse it as a JSON object.
///
/// The prefix and payload are read with exact-length reads, so a frame split
/// across several transport reads is reassembled. A zero length is rejected
/// before any payload read, and an oversized length is rejected before the
/// payload is allocated.
pub fn read_frame<R: Read>(reader: &mut R) -> Result<Value, FrameError> {
    let mut header = [0_u8; LENGTH_PREFIX_BYTES];
    reader.read_exact(&mut header)?;

    let length = u32::from_be_bytes(header);
    let length = u64::from(length);
    if length == 0 {
        return Err(FrameError::Empty);
    }
    if length > MAX_FRAME_BYTES as u64 {
        return Err(FrameError::TooLarge { length });
    }

    let mut payload = vec![0_u8; length as usize];
    reader.read_exact(&mut payload)?;

    let text = std::str::from_utf8(&payload).map_err(FrameError::InvalidUtf8)?;
    let value: Value = serde_json::from_str(text).map_err(FrameError::InvalidJson)?;
    if !value.is_object() {
        return Err(FrameError::NotAnObject);
    }
    Ok(value)
}

/// Write `message` as one frame: prefix, then exactly the JSON payload.
///
/// The writer is not given a trailing newline or delimiter. Serialization is
/// checked against the same 16 MiB limit as reading, so a local value can
/// never produce a frame the peer must reject.
pub fn write_frame<W: Write, T: Serialize + ?Sized>(
    writer: &mut W,
    message: &T,
) -> Result<(), FrameError> {
    let payload = serde_json::to_vec(message).map_err(FrameError::Serialize)?;
    if payload.is_empty() {
        return Err(FrameError::Empty);
    }
    if payload.len() > MAX_FRAME_BYTES {
        return Err(FrameError::TooLarge {
            length: payload.len() as u64,
        });
    }

    writer.write_all(&(payload.len() as u32).to_be_bytes())?;
    writer.write_all(&payload)?;
    writer.flush()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::io::{Cursor, Read};

    use serde_json::json;

    use super::*;

    fn framed(payload: &[u8]) -> Vec<u8> {
        let mut bytes = (payload.len() as u32).to_be_bytes().to_vec();
        bytes.extend_from_slice(payload);
        bytes
    }

    /// A reader that returns at most one byte per call, so a single frame is
    /// necessarily delivered over many partial reads.
    struct OneByteAtATime<'a>(&'a [u8]);

    impl Read for OneByteAtATime<'_> {
        fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
            if self.0.is_empty() || buffer.is_empty() {
                return Ok(0);
            }
            buffer[0] = self.0[0];
            self.0 = &self.0[1..];
            Ok(1)
        }
    }

    #[test]
    fn round_trip_preserves_the_json_object() {
        let message = json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "engine.probe",
            "params": { "source": { "kind": "bookmark", "value": "abc" } }
        });

        let mut bytes = Vec::new();
        write_frame(&mut bytes, &message).expect("write frame");

        let mut cursor = Cursor::new(bytes);
        let decoded = read_frame(&mut cursor).expect("read frame");
        assert_eq!(decoded, message);
        assert_eq!(
            cursor.position() as usize,
            cursor.get_ref().len(),
            "the reader consumes the frame and nothing else"
        );
    }

    #[test]
    fn partial_reads_are_reassembled() {
        let message = json!({ "jsonrpc": "2.0", "method": "service.ping", "params": {} });
        let mut bytes = Vec::new();
        write_frame(&mut bytes, &message).expect("write frame");

        let mut reader = OneByteAtATime(&bytes);
        let decoded = read_frame(&mut reader).expect("read frame across partial reads");
        assert_eq!(decoded, message);
    }

    #[test]
    fn oversized_length_is_rejected_before_reading_the_payload() {
        let declared = MAX_FRAME_BYTES as u32 + 1;
        let bytes = declared.to_be_bytes().to_vec();
        let mut reader = Cursor::new(bytes);

        match read_frame(&mut reader) {
            Err(FrameError::TooLarge { length }) => {
                assert_eq!(length, u64::from(MAX_FRAME_BYTES as u32) + 1);
                assert_eq!(
                    reader.position(),
                    4,
                    "only the prefix is read when the frame is oversized"
                );
            }
            other => panic!("expected an oversized-frame error, got {other:?}"),
        }
    }

    #[test]
    fn zero_length_is_rejected() {
        let mut reader = Cursor::new(0_u32.to_be_bytes().to_vec());
        assert!(matches!(read_frame(&mut reader), Err(FrameError::Empty)));
    }

    #[test]
    fn invalid_json_is_rejected() {
        let mut reader = Cursor::new(framed(b"not json"));
        assert!(matches!(
            read_frame(&mut reader),
            Err(FrameError::InvalidJson(_))
        ));
    }

    #[test]
    fn invalid_utf8_is_rejected() {
        let mut reader = Cursor::new(framed(&[0xff, 0xfe]));
        assert!(matches!(
            read_frame(&mut reader),
            Err(FrameError::InvalidUtf8(_))
        ));
    }

    #[test]
    fn non_object_payload_is_rejected() {
        let mut reader = Cursor::new(framed(b"[1,2,3]"));
        assert!(matches!(
            read_frame(&mut reader),
            Err(FrameError::NotAnObject)
        ));
    }

    #[test]
    fn truncated_frame_is_an_io_error() {
        // Announce two bytes but provide one.
        let mut reader = Cursor::new(vec![0, 0, 0, 2, b'{']);
        assert!(matches!(read_frame(&mut reader), Err(FrameError::Io(_))));
    }

    #[test]
    fn writer_emits_no_trailing_byte() {
        let message = json!({ "jsonrpc": "2.0", "method": "service.ping", "params": {} });
        let payload = serde_json::to_vec(&message).expect("serialize");

        let mut bytes = Vec::new();
        write_frame(&mut bytes, &message).expect("write frame");

        assert_eq!(bytes.len(), LENGTH_PREFIX_BYTES + payload.len());
        assert_eq!(&bytes[LENGTH_PREFIX_BYTES..], payload.as_slice());
    }

    #[test]
    fn writing_an_oversized_payload_is_rejected() {
        // A JSON string just over the frame limit.
        let message = json!("x".repeat(MAX_FRAME_BYTES));
        let mut bytes = Vec::new();
        assert!(matches!(
            write_frame(&mut bytes, &message),
            Err(FrameError::TooLarge { .. })
        ));
        assert!(bytes.is_empty(), "nothing is written for a rejected frame");
    }
}
