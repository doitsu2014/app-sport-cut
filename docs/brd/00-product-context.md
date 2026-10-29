# Sportcut — Business Requirements Document

| Field | Value |
| --- | --- |
| Document ID | BRD-SPORTCUT-000 |
| Version | 1.0 |
| Status | Draft — for approval |
| Date | 2026-10-29 |
| Product | Sportcut — offline macOS badminton match analyzer |
| Owner | Product owner |
| Contributors | Product, Design, Engineering, QA, Security/Privacy, Legal/Licensing |
| Source baseline | Commit `1541c64` (2026-10-29); design system v1.0 |

This document is the product-level BRD and the shared contract for the nine
feature BRDs in this folder. It does not restate feature-level functional
requirements; the feature writers own those. It fixes the identifiers,
objectives, shared requirements, risks, and traceability that every feature BRD
must cite.

## Related documents

- Design intent: [DESIGN.md](../../design-system/DESIGN.md) — behavior and
  contract, sections §1–§11.
- Token source: [tokens.css](../../design-system/tokens.css) — canonical values.
- Application guide: [USAGE.md](../../design-system/USAGE.md).
- Visual reference: [index.html](../../design-system/index.html) (launcher and
  overview, not the product screen).
- Interactive product screen: [studio.html](../../design-system/studio.html)
  (the interaction source for product behavior).
- Export contract: [DESIGN-HANDOFF.md](../../design-system/DESIGN-HANDOFF.md),
  [DESIGN-MANIFEST.json](../../design-system/DESIGN-MANIFEST.json).
- Feature BRDs: [01](01-workspace-and-library.md), [02](02-import-and-media-preparation.md),
  [03](03-court-calibration.md), [04](04-player-tracking.md), [05](05-rally-review.md),
  [06](06-score-and-serving.md), [07](07-highlights.md), [08](08-export.md),
  [09](09-studio-shell-jobs-and-settings.md).
- Architecture decision: [ADR-0001](../adr/0001-rust-background-service.md),
  with the [background service architecture](../architecture/background-service.md),
  [service protocol](../architecture/protocol.md), and
  [migration plan](../architecture/migration-from-ffi.md).
- Code: engine in [`core/`](../../core/), Flutter client in [`app/`](../../app/),
  model assets in [`models/`](../../models/), developer tools in [`tools/`](../../tools/).

**Evidence note.** The analysis, storage, roadmap, dependency-register, and
verification documents cited below are available at baseline `1541c64` under
`docs/` (for example `docs/architecture.md`, `docs/external-dependencies.md`,
`docs/verification/`). They are intentionally not part of the working tree:
this BRD suite is the current requirements source, and the baseline copies are
cited for provenance only. Use `git show 1541c64:docs/<file>` when provenance
matters. Code, tests, and the design system remain in the tree and are the
stronger signal where documents and code disagree.

**Architecture note (2026-10-29).** ADR-0001 supersedes every FFI transport
reference in this suite and in the feature BRDs. The Rust backend runs as a
separate background service, and the Flutter macOS studio reaches it only over
the documented service protocol. No Rust is linked into the app:
`flutter_rust_bridge`, `dart:ffi` to Rust, generated bridge bindings, and
`libsportcut_api.dylib` are retired. The **workflow** requirements in this
suite remain valid; the transport, catalog-ownership, and recording-custody
clauses are superseded by the transport-and-ownership notes in features 01, 02,
03, 08, and 09 and by §15.1 below. The Rust helper or XPC service is a separate
signed process in the bundle; it is not Rust linked into the Flutter app.

## 1. Executive summary

Sportcut turns one badminton match recording into a scored, trimmed highlight
reel on a Mac, with no cloud processing. It imports a local recording, prepares
analysis media, calibrates the court, tracks players, suggests rally and rest
spans, lets the user confirm each rally's winner in one tap, ranks the best
rallies, and renders a single reel that can be shared.

The business case is time and privacy. Editing a match by hand in a general
editor is slow, and uploading footage to a hosted tool is unacceptable for many
clubs and coaches. Sportcut keeps the recording on the device and turns the
scorekeeper's repeated work — finding rallies, noting who won, cutting clips —
into a guided, resumable workflow.

The backend — media analysis, the match catalog, recording custody, jobs, and
export — runs in a separate Rust background service. The Flutter macOS studio is
a UI and playback client; it holds only an in-memory cache and talks to the
service over a versioned local protocol. There is no Rust, FFI, or recording
custody in the client. The one scoped exception is the sandbox inbox handoff:
if the security-scoped bookmark path cannot be proven, the client may move the
picked bytes once into the service inbox, and the service verifies and owns the
result. Exactly one handoff path ships (Q-12).

This document decides the product's honest autonomy level: the engine proposes,
the user confirms. It fixes the shared requirements, the design-system
contract, the non-functional bar, and the release gates. It does not claim
release readiness; the export backend, accuracy targets, and licensing register
are open at baseline (see §3.3, §12, §16).

## 2. Business context

### 2.1 Problem statement

A coach, club player, or parent records a match on a phone or camera, then wants
a short reel of the best rallies to review or share. Today they either scrub the
whole recording in a general video editor — finding rallies, noting the score,
cutting clips by hand — or upload the match to a hosted service and wait. Both
are slow: a 20-minute match can take far longer to edit than to play. Hosted
tools also move private footage off the device, which clubs and schools often
cannot accept. Existing editors also do not know badminton: they cannot suggest
rallies, track score context, or derive serving side.

### 2.2 Opportunity

The repository already contains a working local pipeline: media import and
artifact storage, a resumable job model, court calibration, macOS-gated player
detection and tracking, motion-first rally segmentation, pure serving-side
derivation and highlight ranking, and an FFmpeg-backed renderer behind a frozen
17-call service contract. The Flutter client is a working end-to-end
application, not a mock. The opportunity is to finish the release path — accuracy evidence, a
shippable media backend, and the remaining design and test gaps — so the
semi-automatic workflow ships on macOS.

### 2.3 Business objectives

| ID | Objective | Measure | Target | Horizon |
| --- | --- | --- | --- | --- |
| BO-1 | Cut the time from a raw recording to a shareable reel | Minutes from import to exported reel on a clean 20-minute match, versus manual editing | Provisional: under the manual baseline by a wide margin; exact target to be set after the first timed run (owner: Product) | v1 |
| BO-2 | Make scoring fast and trustworthy | Taps to confirm one rally; share of stored scores derived from confirmed winners | One winner tap per rally; 100% of displayed scores derived, never hand-entered | v1 |
| BO-3 | Make suggestions useful | Share of suggested rallies the user keeps into the reel; user-reported usefulness | Provisional: majority of kept clips come from suggestions (owner: Product) | v1 |
| BO-4 | Keep footage local | Network calls in the product path; recordings uploaded | 0 network calls; 0 uploads; status bar states the on-device promise | v1 |
| BO-5 | Meet the accuracy targets | Player-count accuracy on clean clips; rally boundary hit rate within ±2 s; confidently-wrong rate | ≥85% / ≥85% / ≤5%, as defined by the eval harness; currently unmeasured | v1 |
| BO-6 | Ship a coherent, accessible design | Design and accessibility checklist pass; contrast, focus, reduced motion verified | All Must DS requirements pass in light and dark | v1 |

Targets BO-1 and BO-3 are provisional and marked as such; BO-5's numeric
targets come from the eval harness and remain unvalidated until a labeled clip
is scored. No target is claimed as met without recorded evidence.

## 3. Scope

### 3.1 In scope for v1

- Workspaces and a match library with import, custody, and local playback.
- Import and media preparation: probe, proxy, analysis audio, sampled frames,
  artifact manifest, regeneration, and cancellation.
- Court calibration with four corners, orientation, and projected outline.
- Player tracking with review of tracks, count, quality, and gaps.
- Rally review: motion-first suggestions, accept, adjust, dismiss.
- Score and serving: one-tap winner confirmation, derived score, serving side.
- Highlights: ranking, keep/remove, trim, reorder, keep-top-N.
- Export: settings, render, progress, success state, share hand-off.
- Studio shell, background jobs, settings, and the local-only status bar.

### 3.2 Out of scope for v1

Each of these requires a change request; none may enter silently.

- Cloud sync, cloud processing, or any hosted backend.
- A social network, publishing feed, or in-app community.
- Mobile clients (iOS, Android) or a web client; v1 is one macOS app.
- Automatic officiating (calling points, faults, or lets).
- Player identity recognition or face recognition.
- Live scoring during a match.
- Tournament brackets, draws, or scheduling.
- User accounts, authentication, or multi-user sharing.

Advanced computer vision (shuttlecock, racket, shot/serve classification, speed)
is deferred, not in scope for v1.

### 3.3 Current delivery status

Status uses Done / Partial / Blocked / Not started / Deferred. Partial work is
not rounded up.

| # | Area | Status | Evidence and remaining gap |
| --- | --- | --- | --- |
| 1 | Workspace and Library | Partial | Workspace home, v5 catalog migration, and three-pane studio exist in `app/lib/src/features/workspace/` and `app/lib/src/features/library/data/match_catalog.dart`. Gap: no widget tests; stale home tests still assert the removed "No matches yet" screen; no rename/reorder or cross-workspace library. |
| 2 | Import and Media Preparation | Partial | `app/lib/src/features/library/presentation/import_controller.dart`; `core/crates/media/tests/media_pipeline.rs` (10 tests) and `offline.rs` (2); baseline `docs/verification/media-pipeline.md`. Gaps: import progress is indeterminate; the rebuild count ignores `not_rebuildable_kinds`; the analysis view uses Material components; no timing evidence for large copies. |
| 3 | Court Calibration | Partial | `core/crates/court/` (20 unit tests), `core/crates/api/tests/facade.rs`, `app/lib/src/features/calibration/`, `app/test/calibration_*_test.dart`; baseline `docs/verification/court-calibration.md`. Gaps: the overlay uses a solid amber net line, 40 px handles, and raw colours instead of the design tokens; no real-footage accuracy measurement. |
| 4 | Player Tracking | Partial | Implemented in `core/crates/vision/` and `app/lib/src/features/tracking/`, macOS-gated with feature `macos-tflite-eval`. Gaps: no vision tests, no tracked reward beyond a manual c1 run, no measured count accuracy, no client tests. |
| 5 | Rally Review | Partial | `core/crates/rally/src/lib.rs`, `app/lib/src/features/rally/`, `app/lib/src/features/editing/data/editing_store.dart`. Gaps: thresholds tuned on one clip, boundary accuracy unmeasured, audio branch unreachable (`SegmentationInput.audio = None`), no client test. |
| 6 | Score and Serving | Partial | `app/lib/src/features/score/`, `app/lib/src/features/editing/domain/score_timeline.dart`, `app/test/score_screen_test.dart`, `app/test/score_timeline_test.dart`, `app/test/editing_repository_test.dart`, baseline `docs/verification/manual-editing-and-export.md`. Gaps: the engine `sportcut-score` has no unit tests; no 2 px serving underline; score figures are 32 px rather than 48–76 px; no L/R keyboard handling; an unscored last rally still shows a server. |
| 7 | Highlights | Partial | `core/crates/highlight/src/lib.rs`, `app/lib/src/features/highlights/`, `app/test/highlights_screen_test.dart`. Gaps: audio intensity, templates, favourites not started; "keep top 10" hard-coded; no engine unit tests. |
| 8 | Export | Blocked | `core/crates/export/` (13 + 6 tests), `app/lib/src/features/export/`, baseline `docs/verification/manual-editing-and-export.md`. Blocked: dev-only GPL FFmpeg backend, no platform-native renderer, H.264/AAC patent decision open. |
| 9 | Studio Shell, Jobs, and Settings | Partial | Shell `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart`; jobs `core/crates/jobs/` (7 tests) and `core/crates/api/src/jobs.rs`, baseline `docs/verification/processing-jobs.md`. Gaps: shared timeline dock, search, keyboard, focus mode, responsive collapse, labelled state chips; no studio widget test. |

The file paths in this table describe the baseline commit. ADR-0001 moves the
catalog and recording custody into the Rust service. The functional status of
each area is unchanged, but the acceptance evidence is re-based by the migration
phases: client SQLite and custody tests are replaced by service protocol,
catalog-migration, and custody-job tests. The table's evidence paths are
baseline provenance, not the post-migration gate.

Cross-cutting gaps at baseline: no real labeled clip scored by the eval harness
(`docs/verification/accuracy-evaluation.md` Results table empty); README/AGENTS
still reference the retired documents; the license register is manual-only and
`cargo-deny` is not wired.

## 4. Users and stakeholders

### 4.1 User personas

| Persona | Context | Primary need | Success looks like |
| --- | --- | --- | --- |
| Club coach | Records matches on a Mac; reviews with players | Get the best rallies and the score without editing | A reel and a score sheet in minutes, footage never leaves the device |
| Competitive player | Records their own matches | Review own rallies and score progression | Fast, accurate score confirmation and a short reel |
| Parent or supporter | Records a child's match | A shareable highlight video | A clean reel with score context, produced locally |
| Club administrator | Owns footage handling rules | Proof that nothing is uploaded | Status bar and behaviour confirm local-only operation |

### 4.2 Stakeholders

| Role | Interest | Responsibility |
| --- | --- | --- |
| Product owner | Scope and release decision | Approves the BRD and changes |
| Design lead | Brand and experience integrity | Owns the design contract (DESIGN.md, tokens.css) |
| Engineering lead | Feasibility, correctness, evidence | Owns engine and client implementation |
| QA lead | Verification | Owns acceptance evidence and accuracy runs |
| Security/privacy | Data handling | Reviews the offline and custody promise |
| Legal/licensing | Shippable component set | Owns the dependency register and release gates |

## 5. Feature catalog

Every feature BRD cites this document for shared IDs. Area IDs are used in
`FR-<AREA>-<NN>` identifiers.

| # | Feature | BRD | Area ID |
| --- | --- | --- | --- |
| 1 | Workspace and Library | [01-workspace-and-library.md](01-workspace-and-library.md) | LIB |
| 2 | Import and Media Preparation | [02-import-and-media-preparation.md](02-import-and-media-preparation.md) | IMP |
| 3 | Court Calibration | [03-court-calibration.md](03-court-calibration.md) | CAL |
| 4 | Player Tracking | [04-player-tracking.md](04-player-tracking.md) | TRK |
| 5 | Rally Review | [05-rally-review.md](05-rally-review.md) | RAL |
| 6 | Score and Serving | [06-score-and-serving.md](06-score-and-serving.md) | SCR |
| 7 | Highlights | [07-highlights.md](07-highlights.md) | HLT |
| 8 | Export | [08-export.md](08-export.md) | EXP |
| 9 | Studio Shell, Jobs, and Settings | [09-studio-shell-jobs-and-settings.md](09-studio-shell-jobs-and-settings.md) | SHL / JOB |

## 6. Shared business requirements

These are product-wide. Feature BRDs refine them; they do not relax them.

| ID | Business requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| BR-1 | Offline and private by default | Must | No network access, telemetry, or online API in the product path; media stages call only local `ffmpeg`/`ffprobe`; the status bar states the on-device promise. |
| BR-2 | The service takes custody of the recording | Must | The service copies the picked file into the service-owned recording store, records the path in the service-owned catalog, and references it in place; the original user file is never modified; a cancelled import leaves no partial file or record. |
| BR-3 | Semi-automatic, user-confirmed results | Must | Every rally, score, and kept clip is confirmed by the user; the engine only proposes. No automatic result is persisted as if confirmed. |
| BR-4 | One-tap scoring | Must | Marking a rally span and tapping L or R records the winner; the score and serving side are derived, never hand-entered. |
| BR-5 | Highlights are useful and editable | Must | Rallies are ranked; the user can keep, remove, trim, and reorder clips; an empty reel blocks export. |
| BR-6 | One click produces one reel | Must | Export renders the selected clips to one file; success names the file, clip count, and runtime; zero clips blocks export with a plain explanation. |
| BR-7 | Matches are organized in workspaces | Must | A user can create a workspace and import or open matches within it; existing matches migrate to a default workspace. |
| BR-8 | Design-system fidelity | Must | Tokens are the single source of colour, type, spacing, radius, elevation, and motion; one accent signal per pane; every state is labelled before it is coloured. |
| BR-9 | Accessibility is a release bar | Must | Body text ≥4.5:1, large text/icons/score/focus ≥3:1 in both themes; visible focus; icon-only controls named; overlay handles ≥44 px; 200% text scaling without clipping. |
| BR-10 | Licensing gate | Must | No not-shippable dependency, model, or asset enters a release build; the dependency register is the gating source. |
| BR-11 | Recoverable, resumable jobs | Must | Long work runs off the UI thread with stage-labelled monotonic progress, cancellation, and checkpoint resume; atomic writes; cancelled output is never shown as final. |
| BR-12 | macOS focus in v1 | Must | One adaptive macOS application; no mobile or web client in v1. |

## 7. Shared design-system requirements

The design system is a contract. Each requirement cites its design section; a
feature BRD may add a stricter local rule but may not weaken these.

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| DS-1 | Tokens are the single value source | Must | Values come from `tokens.css`; no raw hex outside `tokens.css` and the fixed overlay bed `#0A0F0C`/`#F2F5F0`; new roles are added to `tokens.css` first (USAGE.md). |
| DS-2 | Light and dark are first-class themes | Must | Light is canonical; dark is a same-named override under `:root[data-theme="dark"]`; both are audited separately (DESIGN.md §2). |
| DS-3 | One accent signal per pane | Must | At most one accent-coloured element per pane; two greens in one pane means one is wrong (DESIGN.md §2). |
| DS-4 | Label before colour | Must | Every state carries a word or icon; colour reinforces but never carries meaning alone; scores carry L/R text (DESIGN.md §1, §2, §9). |
| DS-5 | Typography and tabular numerals | Must | Archivo display, IBM Plex Sans body, IBM Plex Mono micro-labels; every score, duration, and timecode uses tabular numerals and is never animated (DESIGN.md §3, §7). |
| DS-6 | Type floors | Must | Body ≥16 px; sentence text ≥12 px; mono micro-labels ≥10 px; 9 px only in dense chrome/overlays and never below 9 px; shorten copy rather than shrink (DESIGN.md §3, §9). |
| DS-7 | 4 px grid, radii, three elevations, layout constants | Must | Spacing on the 4 px grid; radii 6/10/14/pill; exactly flat/ring/raised elevations; window 52 px toolbar, 264 px video rail, 320 px feature rail, 30 px status bar, minimum window 1100×720 (DESIGN.md §4, §10). |
| DS-8 | Complete component state set | Must | Default, hover, focus, active, disabled, loading, empty, error, and success are designed, not left to defaults (DESIGN.md §6). |
| DS-9 | Visible focus ring | Must | 2 px surface gap plus 2 px accent ring in both themes; no outline removal without an equivalent replacement (DESIGN.md §4). |
| DS-10 | Scorekeeper voice | Must | Short, factual, verb-first; no exclamation marks or anthropomorphism; errors say what happened and the next action; numbers as `18–16`, `0:42`, `12 clips · 4:38` (DESIGN.md §8). |
| DS-11 | Motion explains change, and can be removed | Must | 120/180 ms with `cubic-bezier(0.2,0,0,1)`; nothing loops; reduced motion collapses non-essential transitions while layout and feedback still work (DESIGN.md §7). |
| DS-12 | Anti-patterns are prohibited | Must | No cream/beige grounds, gradients, glass, neon, count-up/confetti, colour-only scoring, second accent per pane, floating cards over the court, or invented metrics (DESIGN.md §9). |
| DS-13 | Studio shell geometry | Must | Floating macOS window at 1440×900 reference, 14 px radius, 52 px toolbar / flexible workspace / 176 px timeline dock / 30 px status bar; no in-app theme switch or viewport selector (DESIGN.md §10). |
| DS-14 | Adaptive contract | Must | Rails collapse below 980 px of available width; preview never narrower than 480 px while rails are open; no horizontal scrolling; responsive matrix of the export prototype validated (DESIGN.md §5, §10; DESIGN-HANDOFF). |
| DS-15 | Accessibility checklist | Must | Contrast floors, visible focus, named icon controls, 44 px hit targets, readable semantics for score/scrubber/transport, `prefers-reduced-motion`, and no clipping at 200% text (USAGE.md checklist; DESIGN.md §2). |

## 8. Non-functional requirements

| ID | Requirement | Priority | Acceptance criterion |
| --- | --- | --- | --- |
| NFR-1 | Offline operation | Must | The product path completes with the network unavailable; media stages depend only on the local toolchain (baseline `core/crates/media/tests/offline.rs`). |
| NFR-2 | UI responsiveness | Must | Long work runs off the UI thread; one heavy job at a time and one job per match; progress is stage-labelled and never decreases within a stage. |
| NFR-3 | Crash safety and resume | Must | Artifact writes are atomic (temp + rename or final-state flip); checkpoints survive restart; interrupted output is never presented as final. |
| NFR-4 | Data integrity and migrations | Must | The service-owned catalog migrations are versioned (v6 adopts the v5 workspaces data); schemas are versioned (manifest 3, checkpoint 1, calibration 1, tracks 1, rally suggestions 1); user-authored data is preserved across upgrades and the v5→v6 adoption. |
| NFR-5 | Security and least privilege | Must | Release runs sandboxed with user-selected read-only access only; no secrets in source or logs; debug-unsandboxed is not a release configuration. |
| NFR-6 | Accessibility | Must | Meets DS-15; verified in light and dark. |
| NFR-7 | Testability | Must | Each Must requirement names observable acceptance evidence; engine tests run without Flutter/Xcode/JDK; new behavior ships with tests. |
| NFR-8 | Engine independence | Must | `core/` builds, lints (`-D warnings`), and tests with default features and no client toolchain; the service transport and macOS TFLite detector are feature-scoped. |
| NFR-9 | Service boundary and protocol versioning | Must | The Rust backend runs as a separate background service and the Flutter client reaches it only over the documented protocol (`docs/architecture/protocol.md`). No Rust, `dart:ffi`, `flutter_rust_bridge`, generated bridge bindings, or `libsportcut_api.dylib` is linked into, loaded by, or shipped inside the Flutter app executable or process. A separate signed helper or XPC service in the app bundle is permitted: it is a separate Mach-O and process, never `dlopen`ed. The protocol major version is negotiated at handshake. |
| NFR-10 | Licensing gate | Must | The dependency register records a verdict per component; `tools/preflight.sh --strict-license` gates GPL builds; no unresolved row ships. |
| NFR-11 | Number and copy formatting | Must | Scores use en dash (`18–16`), timecodes `0:42`, summaries `12 clips · 4:38`; labels are verb-first. |
| NFR-12 | English only in v1 | Must | All shipped copy is English; localization is a later change request. |
| NFR-13 | Local diagnostics | Must | Errors are user-actionable and name the file and reason; no telemetry or remote logging; diagnostics stay on the device. |

## 9. Assumptions

- v1 targets macOS only; users hold local recording files.
- A labeled clip set will be supplied to score accuracy before release.
- A shippable media/export backend (LGPL FFmpeg or platform-native) can be
  adopted without changing the product contract.
- Model weight redistribution will be resolved in favour of a shippable verdict.
- A release build environment with Flutter, Xcode, and a signing/notarization
  identity for the app and its helper is available.
- Users accept the semi-automatic model: the engine proposes, they confirm.
- The design system v1.0 files are the authoritative experience contract.

## 10. Constraints

- Offline only: no cloud or network dependency in the product path.
- macOS minimum window 1100×720; rails collapse before the preview shrinks.
- Rust workspace lints: `unsafe_code = "deny"` with one narrow, documented
  exception for the service OS-glue module (`getpeereid`/`LOCAL_PEERCRED`,
  `flock`, parent-PID checks, bookmark resolution, `libxpc`); safe wrapper
  crates (`nix`, `objc2`, `objc2-foundation`) are preferred and pinned. No FFI
  exception is restored. `dbg_macro`/`todo` denied; rustfmt 100 columns. A CI
  check confines the unsafe allowance to the named module.
- Only the Sportcut service crosses the process boundary; protocol DTOs are the
  frozen client contract. No Rust library is linked into the app.
- The client and service communicate only over the documented local protocol;
  the service is a separate signed process, not a linked library.
- Match-directory layout and schema versions are stable.
- `tokens.css` is the single source of design values.
- Development FFmpeg is GPL-configured and not shippable.
- The Rust service executable ships with the app and the protocol has an
  independent major/minor version; FFI (`flutter_rust_bridge`, `dart:ffi`,
  `libsportcut_api.dylib`) is retired by ADR-0001.
- The product promise is local-only and must never imply a cloud path.

## 11. Dependencies

### 11.1 Internal

| Dependency | What the product needs | Owner |
| --- | --- | --- |
| Design system v1.0 | Tokens, states, voice, accessibility contract | Design lead |
| Engine crates (`core/`) | Media, storage, jobs, court, vision, rally, score, highlight, export | Engineering lead |
| Rust service (`core/service`) | Engine, catalog, recording custody, jobs, and export in a separate process; frozen 17-call engine contract over the protocol | Engineering lead |
| Service protocol (`core/crates/protocol`) | Versioned request, response, notification, and error contract | Engineering lead |
| Flutter client (`app/`) | Studio, features, playback, protocol client, in-memory cache, Riverpod state | Engineering lead |
| Eval harness (`core/crates/eval`, CLI) | Accuracy scoring and threshold replay | QA lead |
| Developer tools (`tools/`) | Preflight, engine verification, service build and embedding, no-Rust-in-app checks | Engineering lead |

### 11.2 External

| Dependency | Use | Release condition |
| --- | --- | --- |
| FFmpeg / ffprobe | Probe, proxy, audio, frames, render | LGPL build or platform-native replacement; GPL build is dev-only |
| TensorFlow Lite C runtime | macOS person detection | Apache-2.0 notice; pinned by SHA-256 |
| EfficientDet-Lite0 int8 weights | Person detection | Weight redistribution verdict reconciled; pinned |
| Flutter packages (Riverpod, file_picker, video_player, share_plus, path_provider) | Client runtime; `sqflite` retained through the Phase 4 rollback and shadow read, removed at Phase 5 | Recorded shippable in the register |
| Rust service executable | Separate backend process: engine, catalog, recording store, jobs, export | Signed and notarized with the app; project code MIT |
| SQLite (via `rusqlite`, bundled or system linkage) | Service-owned catalog storage | Licensed and recorded (SQLite public domain; the crate is MIT). Linkage model is ADR-0001 Q-4 and must be resolved before release: bundled SQLite affects binary size and deployment target, system SQLite affects the minimum macOS version. No release with an unresolved row (BR-10, NFR-10) |
| Local IPC (Unix domain socket; XPC fallback) | Client–service transport | OS-provided; no additional dependency |
| Fonts (Archivo, IBM Plex Sans, IBM Plex Mono) | Offline typography | OFL-1.1; bundled, client-only |

**History.** `flutter_rust_bridge` 2.13.0 and `libsportcut_api.dylib` were the
FFI transport through baseline `1541c64`. ADR-0001 retires them; the Rust
service executable, SQLite, and local IPC rows replace them. The retired FFI
exception to the Rust `unsafe_code` lint is not restored; the replacement is the
narrow OS-glue allowance in §10.

## 12. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-1 | Accuracy targets unverified; no labeled clip scored | High | High | Score a labeled clip with the eval harness; report player-count and boundary metrics before claiming Done | QA lead |
| R-2 | Export backend is dev-only GPL FFmpeg; no native renderer | High | High | Adopt an LGPL FFmpeg configuration or a platform-native renderer; keep FFmpeg behind the backend seam | Engineering lead |
| R-3 | Model weight licensing is contradictory (register vs `models/README.md`) | Medium | High | Reconcile to one verdict; update register before release | Legal/licensing |
| R-4 | H.264/AAC patent licensing unresolved | Medium | High | Legal review; choose a codec/distribution path before store build | Legal/licensing |
| R-5 | Audio-guided rally analysis inactive (`audio = None`) | Medium | Medium | Wire the audio artifact into segmentation or document motion-only as the v1 claim | Engineering lead |
| R-6 | Design drift between tokens and implementation | Medium | Medium | Token check in review; reconcile radii, toast duration, raw hexes, selected-rally outline | Design lead |
| R-7 | Client test gaps and stale tests | High | Medium | Add workspace/studio/tracking/rally tests; fix tests that assert removed screens | QA lead |
| R-8 | Job-model race and over-broad cancellation invalidation | Medium | Medium | Narrow invalidation to the job's outputs; document or fix the admission-slot race | Engineering lead |
| R-9 | Retired documentation is still referenced by README/AGENTS and external links | High | Low | Update README/AGENTS and links to point at `docs/brd`; keep baseline copies as provenance only | Engineering lead |
| R-10 | Scope creep (cloud, social, mobile, auto officiating) | Medium | High | Enforce the out-of-scope list via change control | Product owner |
| R-11 | FFI-to-service migration regression: a facade call, error, progress, cancellation, checkpoint, artifact, or catalog behavior changes during the move | Medium | High | Phase 0 behavior corpus; parity harness across both transports; phased exit gates; catalog and recording migration rehearsal with rollback; no dual writes | Engineering lead |
| R-12 | The sandboxed helper cannot resolve an app-created security-scoped bookmark, blocking the primary import path | Medium | High | Bookmark entitlement on both targets; signed sandbox spike with SHA-256 proof; if it fails, first-class inbox handoff with digest, cleanup, and one shipped path (Q-12) | Engineering lead |
| R-13 | The SQLite crate/linkage model is unresolved, blocking the dependency register | Medium | Medium | Record the `rusqlite`/system-SQLite verdict, license, binary-size impact, and deployment target before release (Q-11, ADR-0001 Q-4) | Engineering lead / Legal/licensing |

## 13. Success measures

### 13.1 Product outcomes

| Measure | Target | Source |
| --- | --- | --- |
| Time from import to exported reel | Below manual baseline; target set after first timed run | BO-1 |
| Scores derived from confirmed winners | 100% | BO-2 |
| Kept clips originating from suggestions | Provisional majority | BO-3 |
| Network calls in product path | 0 | BO-4 |

### 13.2 Quality and accuracy measures

| Metric | Definition | Target | Current evidence |
| --- | --- | --- | --- |
| Player-count accuracy | Clean-clip agreement with labels | ≥85% | Unmeasured (Results table empty) |
| Boundary hit rate | Rally boundary within ±2 s | ≥85% | Unmeasured |
| Confidently-wrong rate | Confident wrong count | ≤5% | Unmeasured |
| Rally-time IoU | Informational overlap | Reported only | Unmeasured |

### 13.3 Design and release readiness

| Measure | Target |
| --- | --- |
| Must DS requirements passing in light and dark | 100% |
| Must client flows with automated tests | Workspace, studio, tracking, rally review |
| Dependency register rows with a verdict | 100% resolved |
| Shippable media/export backend selected | Yes |

## 14. Milestones

| Milestone | Exit criterion | Status |
| --- | --- | --- |
| M-1 Requirements baseline approved | This BRD suite reviewed and approved; README/AGENTS references reconciled to `docs/brd`; register and model notes agree | Open |
| M-2 Accuracy baseline | One labeled clip scored; BO-5 metrics reported | Open |
| M-3 Shippable media backend | LGPL FFmpeg or native renderer selected; export passes on release config | Open |
| M-4 Client parity and design gaps | Timeline dock, labelled states, search/keyboard/responsive decisions, a11y checklist | Open |
| M-5 Release gate and licensing | All Must BR/NFR/DS pass; legal sign-off on patents, model, and FFmpeg | Open |

## 15. Traceability index

Business requirements map to feature BRDs as follows. Each feature BRD carries
the detailed `FR-<AREA>-nn` rows and their acceptance evidence.

| Business requirement | Feature BRD(s) |
| --- | --- |
| BR-1 Offline and private | All; primary 02, 08, 09 |
| BR-2 Recording custody | 01, 02 |
| BR-3 Semi-automatic confirmation | 04, 05, 06 |
| BR-4 One-tap scoring | 06 |
| BR-5 Highlight usefulness | 07 |
| BR-6 One-click reel | 08 |
| BR-7 Workspaces | 01 |
| BR-8 Design-system fidelity | All; primary 09 |
| BR-9 Accessibility | All; primary 09 |
| BR-10 Licensing gate | All; primary 08, 09 |
| BR-11 Recoverable jobs | 02, 09 (JOB) |
| BR-12 macOS focus | All; primary 09 |

### 15.1 Service-boundary traceability

ADR-0001 changes transport, catalog ownership, and recording custody. These
rows map the affected shared requirements to the clauses that now define them.

| ID | Updated requirement | Updated clauses |
| --- | --- | --- |
| BR-2 | Recording custody is service-owned. The service copies the picked file into its store and owns validation, cataloging, and deletion. The client writes no recording bytes except the documented one-file inbox handoff, which is digest-verified and deleted after custody. | [01 §3.4](01-workspace-and-library.md#34-catalog-and-recording-custody), [02 §2.1](02-import-and-media-preparation.md#21-in-scope), [08 §8.2](08-export.md#82-constraints), [09 §8.1](09-studio-shell-jobs-and-settings.md#81-dependencies); [background-service §6.3](../architecture/background-service.md#63-recording-store), [§7.3](../architecture/background-service.md#73-sandbox-file-handoff); [protocol §6.1](../architecture/protocol.md#61-workspaces-and-matches) |
| NFR-4 | The catalog is service-owned at schema v6. v5 adoption is a cancellable, resumable job. Rollback restores the retained v5 backup or resets `user_version` after closing WAL; a v6 database does not open in a v5 client without that reset. | [01 §3.4](01-workspace-and-library.md#34-catalog-and-recording-custody), [02](02-import-and-media-preparation.md), [03](03-court-calibration.md), [08](08-export.md); [migration §3](../architecture/migration-from-ffi.md#3-phased-plan), [§8](../architecture/migration-from-ffi.md#8-rollback) |
| NFR-9 | The Flutter client is protocol-only: no Rust, FFI, FRB bindings, or dylib in the Flutter executable or process. A separate signed helper or XPC service in the bundle is permitted. Protocol major/minor negotiation and the endpoint rule are fixed in the protocol. | Transport notes in [01](01-workspace-and-library.md), [02](02-import-and-media-preparation.md), [03](03-court-calibration.md), [08](08-export.md), [09](09-studio-shell-jobs-and-settings.md); [ADR-0001](../adr/0001-rust-background-service.md); [background-service §14](../architecture/background-service.md#14-no-rust-in-app-enforcement); [protocol §1](../architecture/protocol.md#1-transport-and-framing) |

## 16. Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-1 | Which labeled clips will seed the accuracy baseline, and who labels them? | BO-5 cannot be measured without them | QA lead |
| Q-2 | LGPL FFmpeg or a platform-native renderer for the shipping export path? | Blocks export release (R-2) | Engineering lead |
| Q-3 | What is the H.264/AAC distribution decision? | Blocks store build (R-4) | Legal/licensing |
| Q-4 | Are the EfficientDet weights shippable by redistribution? | Reconciles register and model notes (R-3) | Legal/licensing |
| Q-5 | Is the reel shared via the macOS share sheet only, or copied to a chosen folder? | Shapes the export success state | Product owner |
| Q-6 | What music source ships, and under what license? | Affects export and licensing | Legal/licensing |
| Q-7 | Is the prototype's 360–1920 px responsive matrix in scope for the native window, or only for the reference? | Prevents inheriting web-mobile layout as a window contract | Design lead |
| Q-8 | Are workspace rename/reorder and a cross-workspace library v1? | Affects LIB scope | Product owner |
| Q-9 | Are team or player names surfaced in v1, or left as Left/Right? | Affects score and export copy | Product owner |
| Q-10 | Is local diagnostics logging sufficient, with no telemetry ever? | Confirms NFR-13 stance | Product owner |
| Q-11 | Which SQLite linkage ships: `rusqlite` with bundled SQLite or the system library? | Affects the dependency register, binary size, license record, and minimum macOS deployment target; gates release (ADR-0001 Q-4) | Engineering lead / Legal/licensing |
| Q-12 | Does the sandbox spike prove the helper can resolve an app-created security-scoped bookmark, or does the inbox handoff become the shipped path? | Decides the only import path and which entitlements ship; do not ship both (ADR-0001 Q-2) | Engineering lead |

## 17. Glossary

| Term | Meaning |
| --- | --- |
| Match | One recording plus its derived artifacts and catalog record |
| Workspace | A named grouping of matches |
| Rally | A play from serve to point; the unit scored and clipped |
| Rest | The interval between rallies |
| Proxy | Reduced-resolution copy used for analysis |
| Analysis audio | Low-bitrate mono audio extracted for analysis |
| Frames | Timestamped upright JPEG samples |
| Calibration | Four court corners plus orientation mapped to a homography |
| Homography | Projective image-to-court mapping and its inverse |
| Tracks | Player detections associated over time |
| Rally suggestion | A proposed rally span awaiting user acceptance |
| Serving side | The side that serves a rally, derived by the rally-point rule |
| Highlight reel | The ordered set of kept clips exported as one video |
| Edit decision list | Backend-independent list of trims, overlays, and audio |
| Artifact | A derived file recorded in the match manifest |
| Manifest | Versioned record of artifacts and their state |
| Checkpoint | Per-stage resume record in `checkpoints.json` |
| Service | The separate Rust background process that owns the engine, catalog, recordings, jobs, and export |
| Catalog | The service-owned SQLite database of workspaces, matches, rallies, scores, clips, and settings |
| Recording store | The service-owned copy of each imported recording |
| Protocol | The versioned local request, response, notification, and error contract between the client and the service |
| Facade | The frozen 17-call engine contract exposed by the service over the protocol |
| DTO | Data transfer object at the service protocol boundary |
| BRD / BO / BR / FR / DS / NFR | Document, objective, business, functional, design-system, and non-functional identifiers |

## 18. Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |
| Engineering lead |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |
| Legal/licensing |  | Approve / revise |  |

---

**Change control.** A change to scope, a Must requirement, or the design
contract requires a version bump, a recorded approval decision, an update to the
dependency register if a dependency is introduced, and a re-run of the quality
checklist. Feature BRDs inherit this document's version and baseline and must
cite it. A change to the service boundary, transport, or catalog ownership also
requires a superseding ADR in addition to this change control.
