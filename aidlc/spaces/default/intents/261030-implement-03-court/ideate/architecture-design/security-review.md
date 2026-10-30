# Security Review — Architecture Design

Intent: `261030-implement-03-court`
Reviewer: `security-agent` (AIDLC Ideate / Architecture Design, advisory)
Date: 2026-10-30
Verdict: **pass-with-hardening** — no blocking findings.

## Scope

Reviewed the architecture document, requirements, and constraint register
against HEAD (`git diff -- app core` empty at this stage). Code inspected:
`app/lib/src/features/calibration/presentation/**`,
`app/lib/src/app/design/components/sc_calibration_overlay.dart`,
`app/lib/src/bridge/sportcut_engine.dart`,
`core/adapters/service/src/engine.rs` (`resolve_match`), and
`app/lib/src/features/library/data/match_catalog.dart`.

## Trust boundaries

| ID | Boundary | Controls at HEAD | Impact of this intent |
| --- | --- | --- | --- |
| TB1 | Pointer → controller/overlay | Index bounds, 0..1 clamps, completeness gate (`calibration_controller.dart:141-153`, `sc_calibration_overlay.dart:208-216,385-391`) | Unchanged |
| TB2 | Flutter client ↔ service | Unix socket only, token handshake, same-UID peer check, 0700/0600 modes, 103-byte guard | No protocol change |
| TB3 | Service → client renderer | `CourtGeometryDto.fromJson` parses shape/types only; the overlay currently ignores geometry and derives the net from clamped corners | **Changed:** the overlay paints engine-supplied geometry directly |
| TB4 | Client catalog → UI/engine | Parameterized SQL; defensive calibration decode | No schema/write change |
| TB5 | Service state root | `matchId` validation; debug-only canonicalized `matchDir` | No change |

## Findings

| ID | Severity | Finding | Recommendation | Disposition |
| --- | --- | --- | --- | --- |
| S-1 | Hardening | The design removes the only bounds guard on painted geometry. `_netEndpoints` clamped derived points, but the new path passes `geometry.net` to a painter whose `_scale` does not clamp; `CourtGeometryDto.fromJson` validates neither finiteness nor range; `Clip.none` lets out-of-box values escape. | Clamp and validate geometry (4 corners, exactly 2 net points, finite, 0..1) before painting; keep `Clip.none` only with the clamp, else use `Clip.hardEdge`. | **Folded** into architecture §3.1 and requirements R-CAL-01/R-CAL-02. |
| S-2 | Hardening | `_drawDashed` loops with a fixed 13 px advance; a pathological endpoint (~1e12) would freeze the UI thread. | Covered by the S-1 clamp; additionally cap the loop or break when the length exceeds a multiple of the box diagonal. | **Folded** into architecture §3.1 and R-CAL-02. |
| S-3 | Hardening | Architecture §7 claimed "no input crosses a new boundary"; the service→renderer geometry flow materially changes and must be named so the implementation validates it. | Amend §7 to name TB3 and the validation requirement; keep "no new I/O, dependency, or boundary". | **Fixed** in architecture §7. |
| S-4 | Hardening | `docs/architecture/protocol.md:166` embeds a 32-hex token-shaped example. It is regenerated per launch, but the repo forbids token-shaped literals. | Replace with `<per-launch-token>` during the R-CAL-12 documentation edit. | **Folded** into R-CAL-12. |
| S-5 | Accepted risk | The dev token can arrive via `--dart-define`, environment, or token file; a dart-define is compiled into a development build. | Release packaging must supply the token at launch without compiling it in. | Owner: Platform / ADR-0001 Phase 6. |
| S-6 | Accepted risk | The client trusts `video_path`/`match_dir` from its own SQLite catalog; a same-user attacker could point playback at another local file. | Resolve recording paths service-side when the catalog moves. | Owner: Client track / ADR-0001 Phase 3-4. |
| S-7 | Accepted risk | In debug builds `matchDir` need only resolve under the state root, not under `matches/<matchId>`. | If hardened later, require the path to be exactly `<state-root>/matches/<matchId>`. | Owner: Service host / ADR-0001. |

## Controls reviewed and holding

- Pointer input is bounds-checked and clamped before the engine sees it;
  projection is gated on four in-frame corners.
- Service path handling is defence-in-depth: absolute paths, canonicalization,
  nearest-existing-ancestor resolution, and `starts_with` confinement; release
  builds refuse `matchDir` outright.
- Catalog access is parameterized; malformed calibration JSON degrades to "no
  calibration" rather than failing the match.
- The service token is never logged (redacted `Debug` impl), and the token file
  and endpoint are 0600/0700 with the 103-byte guard.
- Local-only guarantee intact: the only transport is an `AF_UNIX` address; the
  design adds no network, telemetry, dependency, or durable client state.
- Save ordering (artifact first, catalog last) bounds the integrity impact of a
  partial save.

## Accepted risks with owner

| Risk | Owner | Condition |
| --- | --- | --- |
| S-5 dev token via dart-define/env/file | Platform / Phase 6 | Revisit at release packaging. |
| S-6 catalog-supplied paths | Client track / Phase 3-4 | Migrates with service-owned catalog. |
| S-7 debug `matchDir` scope | Service host | Development-only; release rejects it. |
| S-4 token-shaped example until R-CAL-12 | Docs owner | Fixed opportunistically in the R-CAL-12 edit. |

## Verdict

**pass-with-hardening.** No blocking findings. The intent adds no network
surface, dependency, secret handling, durable client state, or protocol change;
the implementation must carry the S-1/S-2 guard and the S-3 corrected wording.
