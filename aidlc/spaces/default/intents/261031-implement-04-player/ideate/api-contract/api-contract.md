# API Contract — Player Tracking (Feature 04)

> **Revision 2026-11-01 — U3 reverted.** The association fields
> `maxAssociationRadius`, `staleTrackPenaltyPerSecond`, `predictionEnabled`,
> their validation rows, and their `provenance.tracking` entries were designed
> but removed after the full-reference checkpoint failed. The shipped contract
> has only the existing tracking fields. The metric additions
> (`trackQuality`, `countSupportingFrames`, `review.fragmentation`) and the
> boundary floors remain in force.

Status: Ideate / API Contract Design
Intent: `261031-implement-04-player`
Date: 2026-10-31
Inputs: `architecture-doc.md`, `requirements.md`, `constraint-register.md`.

## 1. Interfaces in scope

| Interface | Kind | Change |
| --- | --- | --- |
| `engine.tracking.start` | JSON-RPC method over the Unix socket | Optional request fields; stricter validation of two acceptance floors |
| `engine.tracks.window` | JSON-RPC method | Optional response fields |
| `tracks/player_tracks.json` | Versioned artifact (schema 1) | Optional `review.fragmentation`; optional `provenance.tracking` fields |
| `TrackingConfig` / `FragmentationSummary` | Internal Rust contract | Additive fields with serde defaults |
| `PlayerTracksDto` / `PlayerTrackingConfigDto` | DTO/wire contract | Additive optional fields |
| `engine.rally.start` / `engine.rally.suggestions` | JSON-RPC | No change; the compact `SegmentationInput` is unchanged |

Out of scope: new methods, framing, error codes, auth, catalog, manifest, and
`engine.tracking.start` client-supplied asset paths.

## 2. `engine.tracking.start`

**Request**

```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "engine.tracking.start",
  "params": {
    "matchId": "match-42",
    "config": {
      "samplingRate": 5,
      "minConfidence": 0.2,
      "courtMargin": 0.04,
      "netMargin": 0.05,
      "maxTrackGapMs": 1200,
      "maxFrameGapMs": 500,
      "maxGroundSpeedPerSecond": 0.8,
      "ambiguityMargin": 0.1,
      "minTrackObservations": 3,
      "minCountFrames": 5,
      "minCountFraction": 0.7,
      "maxAssociationRadius": 0.25,
      "staleTrackPenaltyPerSecond": 0.5,
      "predictionEnabled": true
    }
  }
}
```

- The three new fields are optional. When omitted, the tuned defaults above
  apply and are recorded in `provenance.tracking`.
- `matchDir` is a development-only affordance; a release build rejects it.
  `runtimePath` and `modelPath` are always rejected (the service owns assets).

**Response** (unchanged shape)

```json
{ "jsonrpc": "2.0", "id": 7,
  "result": { "jobId": "job-1f3a-...-0", "matchId": "match-42" } }
```

**Validation** (all `invalid_params`):

| Field | Rule | Message |
| --- | --- | --- |
| `maxAssociationRadius` | finite, `0 < r <= 0.5` | `maxAssociationRadius must be finite and in (0, 0.5]` |
| `staleTrackPenaltyPerSecond` | finite, `>= 0` | `staleTrackPenaltyPerSecond must be finite and non-negative` |
| `predictionEnabled` | boolean (serde) | `config is invalid: ...` |
| `minCountFraction` | `>= 0.60` | `minCountFraction must be at least 0.6` |
| `minTrackObservations` | `>= 3` | `minTrackObservations must be at least 3` |
| existing fields | unchanged | unchanged |

Idempotency: starting a second heavy job is rejected by name (unchanged); the
same inputs and configuration produce the same track generation identity.

**Error example**

```json
{ "jsonrpc": "2.0", "id": 8,
  "error": { "code": -32602,
    "message": "minCountFraction must be at least 0.6",
    "data": { "kind": "invalid_params", "retryable": false,
              "userMessage": "Check the request and try again." } } }
```

## 3. `engine.tracks.window`

**Request** (unchanged): `matchId`, `startSeconds`, `endSeconds`, with the
advertised window maximum enforced.

**Response additions** (both optional; an older service omits them):

```json
{
  "schemaVersion": 1,
  "modelId": "efficientdet-lite0-task-int8-v1",
  "count": "unknown",
  "countQuality": 0.042,
  "countSupportingFrames": 156,
  "countEvidence": { "startSeconds": 0, "endSeconds": 739.601 },
  "coverage": [ ... ],
  "usableCoverage": [ ... ],
  "gaps": [ ... ],
  "frames": [ ... ],
  "trackQuality": {
    "rawDetections": 22613,
    "onCourtDetections": 21672,
    "distinctTracks": 613,
    "topFourObservations": 1504,
    "topFourShare": 0.0694
  }
}
```

`trackQuality` is the pinned RQ-01 summary: denominator = every `OnCourt`
detection (including ambiguous ones), numerator = the four largest per-ID
counts. It is copied from the artifact's embedded review, not recomputed per
window.

## 4. Track artifact schema 1 (data contract)

```json
{
  "schema_version": 1,
  "input": { "duration_ms": 739601, "calibration_id": "fnv1a64:...",
             "coverage": [ ... ], "positions": [ ... ], "audio": null },
  "review": {
    "frames": [ ... ],
    "coverage": [ ... ],
    "usable_coverage": [ ... ],
    "gaps": [ ... ],
    "count": { "count": "unknown", "evidence": { ... },
               "quality": 0.042, "supporting_frames": 156 },
    "fragmentation": {
      "raw_detections": 22613,
      "on_court_detections": 21672,
      "distinct_tracks": 613,
      "top_four_observations": 1504,
      "top_four_share": 0.0694
    }
  },
  "provenance": {
    "frames_fingerprint": "...", "proxy_fingerprint": "...",
    "calibration_id": "...", "runtime_id": "...", "model_id": "...",
    "model_fingerprint": "...", "sampling_rate": 5.0,
    "tracking": {
      "min_confidence": 0.2, "court_margin": 0.04, "net_margin": 0.05,
      "max_track_gap_ms": 1200, "max_frame_gap_ms": 500,
      "max_ground_speed_per_second": 0.8, "ambiguity_margin": 0.1,
      "min_track_observations": 3, "min_count_frames": 5,
      "min_count_fraction": 0.7, "max_association_radius": 0.25,
      "stale_track_penalty_per_second": 0.5, "prediction_enabled": true
    }
  }
}
```

- `fragmentation` is optional and serde-defaulted; an artifact written before
  this intent still deserializes.
- The three association fields are optional in `provenance.tracking` with the
  tuned defaults; an old artifact still deserializes and validates.
- `input` (the compact rally contract) and `schema_version` are unchanged.

## 5. Compatibility and versioning

This is a **documentation-only protocol note**, not a negotiated minor bump:
every wire addition is optional, the DTO has no `deny_unknown_fields`, and
unknown fields are ignored. A negotiated version change would require both
`PROTOCOL_MINOR` (`core/gateways/protocol/src/version.rs`) and the client
`protocolMinor` to move together; neither moves here.

| Change | Classification |
| --- | --- |
| Add an optional request/response field | Compatible; documentation note |
| An old client omits the new config fields | Compatible; defaults apply |
| An old service omits `trackQuality` / `countSupportingFrames` | Compatible; client model treats both as optional |
| An old artifact lacks `fragmentation` or the new config fields | Compatible; serde defaults |
| Make any new field required, rename a field, change a meaning, add/remove a method or error code, or bump the artifact schema | **Breaking**; requires a negotiated version and a migration plan |

Deprecation policy: no field is deprecated by this intent. The compact
`SegmentationInput`, the manifest, and the catalog are untouched.

## 6. Internal contracts

```rust
// sportcut-vision
pub struct TrackingConfig {
    pub max_association_radius: f64,           // serde default 0.25
    pub stale_track_penalty_per_second: f64,   // serde default 0.5
    pub prediction_enabled: bool,              // serde default true
    // existing fields ...
}

pub struct FragmentationSummary {
    pub raw_detections: usize,
    pub on_court_detections: usize,
    pub distinct_tracks: usize,
    pub top_four_observations: usize,
    pub top_four_share: f64,
}

pub struct TrackingResult {
    // existing fields ...
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub fragmentation: Option<FragmentationSummary>,
}
```

The ambiguity rule is a behaviour contract, not a wire field: `association_ambiguous`
is decided from ranking-independent plausibility; freshness/staleness only order
assignment. `track_id` stays `None` for an ambiguous detection (FR-TRK-08).

## 7. Verification hooks

- Contract/deserialization test: an old `player_tracks.json` fixture without
  `fragmentation` and the new config fields deserializes as schema 1.
- DTO test: an old `engine.tracks.window` response without the new fields parses
  in Dart; the new fields round-trip.
- Validation tests: each new bound and both acceptance floors reject with
  `invalid_params`; an old payload with none of the new fields is accepted.
- Service rejection test: a client-supplied `runtimePath`/`modelPath` is still
  rejected.
- Real-footage test: asserts the engine summary equals its independent
  recomputation and gates the broad share at 60%.

## 8. Decisions (approved 2026-10-31)

- Acceptance floors below the approved minimums are **rejected** with
  `invalid_params`; they are not clamped. The caller must send a valid floor and
  the effective value is recorded in provenance.
- The additive fields are a **documentation-only protocol note**; neither
  `PROTOCOL_MINOR` nor the client `protocolMinor` moves.
