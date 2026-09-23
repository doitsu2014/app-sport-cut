# Feature roadmap

`docs/README.md` says what the product is and why it is shaped the way it is.
[`README.md`](README.md) in this folder is the record of the foundation that has
been built. This file sequences what gets built next, what each feature depends
on, and which decisions block which features.

It is a plan, not a commitment: the OpenSpec change for a feature is the source
of truth for that feature's behaviour once it exists.

## Where things stand

**Engine** (`core/`) — the foundation is complete and verified:

| Capability | State |
| --- | --- |
| Probe, reduced-resolution proxy, analysis audio, frame sampling | Done |
| Per-match artifact directory, manifest, regeneration | Done |
| Job model: lifecycle, non-decreasing progress, cancellation, checkpoints, single heavy job | Done |
| Headless CLI harness | Done |
| `court`, `vision`, `rally`, `score`, `highlight` | Empty crates — fixed boundaries, no implementation |

**Bridge** — `core/crates/api/src/facade.rs` exposes the calls the client makes:
`probe_media`, `match_manifest`, `media_import_stages`, and the start/poll pair
`start_import` / `start_regenerate_match_media` / `export_highlight` with
`job_status` and `job_cancel`. Long work returns a job handle instead of blocking
for the whole run, so the client can show stage-labelled progress and cancel
while the engine works. The job registry is process-wide, so "one heavy job at a
time" holds across calls rather than within one.

**Client** (`app/`) — shell, routing, theme, and dependency injection; the match
library with import custody, media metadata, availability reporting, and
deletion; offline playback with transport controls; a four-table SQLite catalog
that now writes `rallies`, `score_events`, `highlight_clips`, and
`export_settings`; a review session for marking rallies and confirming winners;
a highlight reel with trimming and ordering; an export screen that renders the
reel; and an analysis screen for the engine's artifacts. One route is still a
placeholder: calibration.

**Toolchain** — Flutter 3.47.5 and Xcode 26.6 are installed, and the macOS and
iOS builds both succeed. The Android SDK and a JDK are not installed, so no
Android build has been produced. The local FFmpeg is a GPL Homebrew build and is
development-only.

**Verification** — the engine runs 23 tests (`tools/verify-engine.sh`); the
client runs 53 (`flutter analyze` and `flutter test`), including
`app/test/bridge_test.dart`, which loads the real engine library. The evidence
is under [`docs/verification/`](../verification/).

## Wave 1 — finish Phase 1: a useful product with no computer vision

The Phase 1 success criterion in `docs/README.md` is that a user can build a
highlight video from a local recording without any cloud service. Everything
needed for that now exists; these four features close it.

| Feature | Delivers | Depends on | Gate |
| --- | --- | --- | --- |
| Job progress and cancellation across the bridge, plus the Analysis screen | Stage label, progress value, and cancel reach the client; the Analysis route stops being a placeholder | Nothing | None |
| Trim and export | Choose clips from a match, write `highlight_clips` rows, produce an edited video | Nothing new — playback, probe metadata, the job model, and the artifact layout all exist | **Encoder decision** |
| Manual score timeline | One-tap winner confirmation, writing `rallies` and `score_events`; the human-in-the-loop loop the product is built around | Nothing | None |
| Score overlay, music, title card | Burned-in scoreboard, user-supplied music ducked under match audio | Trim and export, manual score timeline | Encoder decision; music asset licensing |

All four are implemented by the change
[`add-manual-editing-and-export`](../../openspec/changes/add-manual-editing-and-export/proposal.md),
which is the source of truth for their behavior. One limit is deliberate and
recorded rather than hidden: **the export renders through the local `ffmpeg`
toolchain, which only runs on a workstation.** The mobile platforms cannot
execute a toolchain at all, and the Homebrew build is GPL. The edit is described
as data — an edit decision list — so the renderer can be replaced by a
platform-native one without the client or the catalog changing; that replacement
is the change named in the gates below.

Suggested order: **trim and export → manual score timeline → job progress and
cancellation as soon as a stage becomes long enough to need it.**

Export is the feature the bootstrap change explicitly deferred, and it carries
the highest user value. The score timeline is the cheapest of the four: its
two tables already exist in the schema and it needs no new engine capability.

## Wave 2 — Phase 2: court and players

| Feature | Delivers | Depends on | Gate |
| --- | --- | --- | --- |
| Court calibration | Four-corner selection, homography into a normalized court, a calibration artifact in the manifest, editable later | Nothing | None — can start at any time |
| Person detection and player count | The `vision` backend, people located in sampled frames, two or four players | Inference runtime and weights chosen | Test footage; inference runtime; model weights |
| Player tracking and court-side assignment | Per-frame tracks, each assigned to the left or right side | Court calibration, person detection | As above |

Court calibration is unusual in having no gate at all, but its payoff only
arrives once tracking exists. Start it early if you want to de-risk the CV track
in small steps; start it late if you would rather ship the Wave 1 value first.

## Wave 3 — Phase 2 and 3: automation

| Feature | Delivers | Depends on | Gate |
| --- | --- | --- | --- |
| Rally and rest segmentation | Editable rally boundaries from motion and audio | Tracking | Wave 2 gates |
| Semi-automatic score suggestion | A suggested side per rally, confirmed by the user | Segmentation, score timeline | Wave 2 gates |
| Highlight ranking | Clips ranked by duration, movement, audio intensity, and score context | Segmentation | Wave 2 gates |

The product principle holds throughout: these features suggest, and the user
confirms. Nothing here may claim to officiate.

## Wave 4 — polish and reach

| Feature | Delivers | Depends on | Gate |
| --- | --- | --- | --- |
| Highlight templates and export presets | Repeatable, shareable looks | Wave 1 export | Encoder decision |
| Advanced CV: shuttlecock, shots, serve | Shot classification and richer events | Collected, consented, labeled data | Data collection; model licensing |

Wave 4 should not begin before there is labeled data to train and evaluate
against.

## Critical path

```text
import (done) ──► trim and clips ──► export ──► overlay + music ──► templates
                        ▲               ▲
  manual score ─────────┘               │
                                        │
  job progress / cancel ────────────────┘      (enabler, no dependencies)

  court calibration ──► player tracking ──► rally segmentation
        (no gate)              ▲                    │
                    footage + runtime + weights     ▼
                                    score suggestion ──► highlight ranking
```

The upper branch is shippable today. The lower branch is gated on inputs the
project does not have yet, so it is the wrong place to spend the next change.

## Standing gates

| Gate | Blocks | State |
| --- | --- | --- |
| Encoder choice for export | A shippable export | Still unresolved for shipping, but no longer blocking the *work*. `add-manual-editing-and-export` records the decision: the edit is an edit decision list, the first renderer is the local ffmpeg (development only), and the renderer is swappable. The follow-up change `add-platform-export-backend` owns AVFoundation/VideoToolbox and MediaCodec/Media3, and produces H.264 with the platform's hardware encoder |
| H.264 / AAC patent licensing | A store distribution, separately from the library license | `unresolved` in the register |
| Inference runtime | Person detection and everything downstream | TensorFlow Lite is `unresolved` (not yet introduced) |
| Model weights and datasets | Person detection and everything downstream | No weights ship; `models/` holds only a README |
| Test footage | The Phase 0 success criteria and all computer-vision work | Not available |
| Platform scope (iOS only, or both) | `add-platform-export-backend`, CI, bridge packaging, and how much platform-native media code is needed | Undecided. Note this is the same decision as the encoder row above: "which encoder" is really "where media I/O happens", and the mobile platforms can only do it natively |
| Distribution channel (store or sideload) | How strict the licensing bar is | Undecided |

Every gate above is recorded in
[`docs/legal/dependency-register.md`](../legal/dependency-register.md), and a
component may not enter a build without a row and a distribution verdict there.

## Working rule for each wave

A feature is not done when it compiles. It is done when its OpenSpec change
exists, the behaviour matches the spec, formatting and lint are clean for the
track that was touched, any new dependency has a register row, and the evidence
is recorded under [`docs/verification/`](../verification/).
