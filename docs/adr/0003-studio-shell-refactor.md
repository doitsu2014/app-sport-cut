# ADR-0003: Rebuild the macOS client as a design-system studio shell

| Field | Value |
| --- | --- |
| ID | ADR-0003 |
| Title | Rebuild the macOS client as a design-system studio shell |
| Status | Accepted |
| Date | 2026-10-29 |
| Deciders | Product owner (D1–D4, D8, D13), Design lead (D5–D7, D15–D18), Engineering lead (D9–D12, D14, D19) |
| Related | [Plan](../plans/studio-redesign.md), [BRD-009](../brd/09-studio-shell-jobs-and-settings.md), [DESIGN.md](../../design-system/DESIGN.md), [studio.html](../../design-system/studio.html), [tokens.css](../../design-system/tokens.css) |

## Context

The exported design system in `design-system/` defines a macOS studio surface,
but the Flutter client still renders Material defaults with a pipeline rail and a
per-feature centre takeover. `workspace_studio_screen.dart` is a single
1,417-line file that owns the chrome, and the other feature views are built from
`Card`, `ListTile`, and `DataTable`. Only that one file reads `SportcutTokens`.

Two sources describe the studio: `design-system/studio.html`, the exported
prototype, and `design-system/DESIGN.md`, the written contract. They agree on
the token set and disagree on some geometry and overlay detail. `index.html` is
a component/launcher overview, not a product surface.

The refactor has to add no capability, no network, no durable client state, and
no new dependency. It is a presentation change over existing providers.

## Decision

### Contract

| ID | Decision | Rationale |
| --- | --- | --- |
| D1 | `studio.html` is the product target. `index.html` supplies component and state vocabulary only. | The manifest marks `index.html` as launcher-overview; DESIGN.md and USAGE.md call `studio.html` the macOS prototype. |
| D2 | Add a 40 px `StageStrip` under the toolbar: Play, Mark court, Prepare analysis, Player analysis, Review & score, Highlights, Export. **Approved by the product owner.** | The studio needs stage navigation that `studio.html` does not model. A horizontal strip preserves the three-pane geometry and leaves the inspector a work surface. Its height is a token so it can be removed cleanly. |
| D3 | The 176 px shared timeline dock is in v1 scope. **Approved by the product owner.** | DESIGN.md §10 and `studio.html` require it. BRD-009 §2.2 no longer excludes it; see the BRD amendment in this change. |
| D4 | Export is the single toolbar primary action. Import moves to the video-rail footer. | DESIGN.md §10 and BRD Q-SHL-02. |
| D5 | A selected rail row is `--surface-warm` plus a 1 px `--border` ring plus a check. No accent bar. | `studio.html` `.video-row.is-active`; accent stays reserved for action. |
| D6 | Keep the native macOS traffic lights; adopt `fullSizeContentView` with a transparent title bar and a leading inset. Never draw fake lights. | They are system chrome, not controls. Removes today's double title bar. |
| D7 | Use Flutter's built-in rounded Material icons through `ScIcons`. Do not load Material Symbols Rounded from Google Fonts. | The prototype's network font load would break the offline guarantee. Icons remain an internal SDK font; the register records it. |
| D8 | A missing recording gets an honest state with no relocate action. Import creates a new match, and the copy says so. | `MatchRepository` exposes only `isRecordingAvailable`; no protocol method relocates a recording. Do not invent recovery. |
| D9 | Keep the shipped accent hover/active hexes and document them as Oklab-mix approximations. | They are already visible and within a few units of the CSS mix. Recomputing mid-refactor adds risk for no visible gain. |
| D10 | No new durable client state. Search, focus mode, rail visibility, inspector tab, selected rally, timeline window, export-sheet visibility, and toasts live in one in-memory Riverpod controller. | CLAUDE.md; the service owns durable state per ADR-0001. |
| D11 | Export reuses `ExportSettings` (title, music, gain, lead-in/out). No persisted filename field; `ExportRequestDto` has none. "Include score overlays" is sheet-local. | Avoids a protocol change and durable state. Success shows `ExportedReel.fileName`. |
| D12 | Volume control and drag-to-trim rally boundaries are deferred. | `PlaybackController` has no volume API and no repository method updates a rally span. |
| D13 | Appearance follows `ThemeMode.system`; there is no in-app switch. The preview bed is fixed dark because it is footage. | DESIGN.md §10, USAGE.md, FR-SHL-30. |
| D14 | The inspector is stage-aware: Rally and Clip tabs for Play, Review & score, and Highlights; contextual panels for Mark court, Prepare analysis, Player analysis, and Export. There is no second persistent pipeline rail. | Preserves the studio inspector while giving calibration, analysis, and tracking a 320 px work surface. |

### Precedence and corrections

| ID | Decision | Rationale |
| --- | --- | --- |
| D15 | **Where `studio.html` and DESIGN.md disagree on geometry, `studio.html` wins.** DESIGN.md fills gaps. Every visible delta is recorded in this ADR. | The handoff contract treats the export as the visual source of truth; the user asked for a realistic studio. |
| D16 | The stage bed is `#050806`, stage ink `#F2F5F0`, and stage signal `#46D08D`, fixed in both themes. | `studio.html` window tokens. This supersedes the `#0A0F0C` bed in the earlier BRD wording; the dashboard overlay still uses the ink and signal as documented. |
| D17 | The inspector uses `ScTabs` (a tablist that changes panel), separate from `ScSegmentedControl` (a filter that does not navigate). | `studio.html` `.inspector-tabs` is `role="tablist"`; USAGE.md defines segmented controls as filters. Conflating them would make the inspector announce the wrong role. |
| D18 | IBM Plex Mono stays at the bundled 400 and 500 weights. Micro-labels use 500 with `--tracking` equivalents; weight 600 is not added. | `app/pubspec.yaml` bundles only 400/500 and the family already has a register row. Adding a weight needs a new asset and a licensing change; the visual difference at 9–10 px is negligible. |
| D19 | `StageState` gains the derived states the chrome needs. `pipeline_stage.dart` keeps `done/ready/idle`; the shell derives `running` (a job is live) and `blocked` (a prerequisite is missing) from providers. `needs review` is a copy label, not a new enum case. | BRD-009 FR-SHL-09 requires BLOCKED and running percentages; the current enum cannot express them. Deriving them avoids changing the domain model for presentation. |

### Superseded design-system compositions

`index.html` screens 11 ("Review & score") and 12 ("Export settings + summary")
and the two-column review/export compositions in DESIGN.md §5 are **superseded**
by the 320 px stage-aware inspector (D14) and the 440 px export sheet. The studio
is a macOS window, not a web page: a persistent centre takeover cannot coexist
with the shared preview and timeline. The content of those screens — scoreboard,
winner confirmation, last rallies, export settings, and the summary — is carried
over in full; only their page composition is replaced.

### Geometry deltas (D15)

| Region | `studio.html` (authoritative) | Earlier `DESIGN.md` reading |
| --- | --- | --- |
| Video row height | ~43 px | 56/64 px rich rows |
| Thumbnail | 52 px wide | 64×36 |
| Rail separation | 1 px column border | 12 px gutter |
| Field height | 34 px | 40 px |
| Chip height | 18/20 px | 24 px |
| Toolbar icon | 18 px (Export 16 px) | 24 px |
| Inspector tabs | 26 px tablist | segmented filter |
| Narrow rails | 240/292 at 1200 px; 222/270 at 1040 px | same |
| Collapse | below 980 px (DESIGN.md only) | same |

Hit targets stay at or above the accessibility floor even where the visual size
is smaller: icon buttons keep a 44 px hit area via padding, and court handles are
24 px visual over a 44 px hit region.

## Consequences

- The token layer grows by `ScMetrics`, `SportcutTypography`, `ScElevation`,
  `ScTints`, `ScStatus`, `ScIcons`, and `ScOverlayColors`; `SportcutPalette`
  becomes a `ThemeExtension` so a component can read it without a provider.
- Feature views become panels over one shared preview and one editing session.
  The legacy `*_screen.dart` routes keep working until the final cleanup.
- `workspace_studio_screen.dart` becomes a composition root under ~150 lines
  after a behaviour-preserving decomposition.
- The timeline dock and the stage strip are app-specific extensions. They live
  behind `ScMetrics` values so either can be removed in one place.
- BRD-009 is amended in the same change: §2.1 adds the dock and the stage strip,
  §2.2 no longer excludes the dock, FR-SHL-08 is restated for the stage strip,
  FR-SHL-14's readiness vocabulary is aligned with the shipped copy, and
  FR-SHL-22 keeps its E binding.
- No protocol, service, or engine change is required. No new dependency.

## Alternatives considered

- **Keep the per-feature centre takeover.** Rejected: it cannot keep one preview
  and one playback session across stages (FR-SHL-10) and contradicts
  `studio.html`.
- **Port `index.html` literally as a web-style page.** Rejected: it is a design
  gallery, and its page layout fights the macOS window.
- **Recompute every `color-mix` value in Oklab at runtime.** Rejected for this
  change: Flutter has no `color-mix`; the shipped approximations are close and
  freezing them keeps the diff reviewable (D9).
- **Add IBM Plex Mono 600.** Rejected: new asset and licensing change for a
  negligible 9 px difference (D18).
