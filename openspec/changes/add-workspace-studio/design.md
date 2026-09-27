## Context

`add-workspace` introduced a workspace that groups videos and renders each video
as a card carrying a horizontal pipeline toolbar. Every feature is still a
full-screen `Scaffold` route that constructs its own `PlaybackController` via
`playbackControllerFactoryProvider` (calibration, tracking, score, and player all
do this). There is no shared preview, and the feature state lives inside each
route's widget state, so it is lost when the route pops.

The studio refactor moves the workspace from "folder of videos" to "tool you work
inside": a left rail of videos, a center pane with one shared preview, and a
right rail of features. This is an app-side change; the engine is untouched.

## Goals / Non-Goals

**Goals:**

- One shared video preview per selected video, owned by the studio.
- A right-rail feature selector that drives what the center pane shows, reusing
  the `done/ready/blocked` states from `add-workspace`.
- Feature screens become embeddable views hosted in the center pane, migrated in
  phases without breaking the existing routes.
- Per-match feature state survives switching videos.

**Non-Goals:**

- A shared timeline/scrubber abstraction across all features (later, if needed).
- Multi-camera, video reordering, keyboard shortcuts, or any engine change.
- Migrating all six feature screens in one step; non-migrated features keep
  their existing route until their phase lands.

## Decisions

### 1. The studio owns the player; features receive it

One `PlaybackController` is created per selected video and lives with the studio
screen. Feature views take an optional `PlaybackController` constructor
parameter; when it is absent they fall back to the existing
`playbackControllerFactoryProvider` so the legacy full-screen routes keep
working unchanged. The studio disposes the controller when the selected video
changes.

**Why:** the center preview is the constant; features are lenses. Keeping
ownership in one place is what makes Play and Calibrate able to share a seamless
preview, and the injectable-with-fallback parameter keeps every existing route
alive during the migration.

### 2. Three-pane shell composition

The studio is a single `Row`-based screen:

```
[ left rail: video list ] [ center: feature view over shared preview ] [ right rail: features ]
```

- Left rail reuses the workspace video list (id, title, availability, score) and
  drives the selected video.
- Right rail renders the seven features with their resolved state for the
  selected video; the highlighted next step comes from the existing
  `resolveStageStates`.
- Center pane renders the selected feature's view, passing the shared
  `PlaybackController` and the selected `MatchRecord`.

A feature is selected independently of the video; the center is always the
product `selectedVideo × selectedFeature`.

### 3. Feature view extraction contract

Each feature screen is split into:

- A thin route wrapper that keeps the `Scaffold` + `AppBar` and owns nothing new.
- An embeddable `XxxView` widget holding the screen's body, which receives a
  `PlaybackController?` and the `MatchRecord`.

The view is the unit the studio hosts. For preview-native features (Play,
Calibrate, then Track and Score) the view renders over the shared preview. For
form-style features (Analyze, Export, Highlights) the view docks its panel next
to or over the preview; those features may hide the preview when they have no
playback role.

### 4. Per-match feature state is keyed by `matchId`

Feature state that today lives in screen-local `State` (e.g. calibration
scrubber position, score selections) moves into Riverpod providers keyed by
`matchId`, so switching videos and back preserves work. State that is already
persisted in the catalog (court calibration, score events, clips, export
settings) is the source of truth and does not need a new provider.

### 5. Phased migration with a route fallback

| Phase | Features migrated |
| --- | --- |
| 1 | Play, Calibrate (preview-native proof) |
| 2 | Track, Score (preview + docked panel) |
| 3 | Highlights, Analyze, Export (form-style panels) |

The right rail only embeds features whose phase has landed; a not-yet-migrated
feature still navigates to its existing full-screen route when selected. This
keeps the studio shippable at every phase boundary.

## Risks / Trade-offs

- **[Two players in flight]** during migration, a non-migrated feature still
  opens a route that builds its own controller, while the studio holds one →
  both are disposed correctly by their owners; no sharing is attempted until a
  feature is migrated.
- **[Controller lifecycle]** the shared controller must pause and dispose on
  video switch, and resume on feature switch → centralized in the studio's
  selected-video handler, with a single disposal point.
- **[State loss if not keyed]** any feature state left in screen-local `State`
  after extraction is lost on switch → the `matchId`-keyed provider rule is
  applied to every extracted view before it lands.
- **[Scope creep]** migrating all six features at once risks a long, unreviewable
  change → phases keep each step small and independently shippable.

## Migration Plan

1. Land the studio shell and the injectable `PlaybackController`, migrating Play
   and Calibrate. Existing routes remain for the rest.
2. Migrate Track and Score into the center pane with docked panels.
3. Migrate Highlights, Analyze, and Export.
4. Once all features are embedded, the studio is the primary surface. The
   full-screen feature routes stay as standalone surfaces and test seams (the
   existing widget tests exercise them), and `AppRoutes.player` remains for
   playing a rendered reel.

## Open Questions

- Whether the right rail groups features (Review / Analyze / Build) or stays a
  flat ordered list. Default: flat ordered list with the next-step highlight.
- Whether the center preview persists for form-style features (Analyze, Export)
  or those features occupy the whole center. Default: preview persists; the
  feature docks a panel and may collapse the preview when it has no playback
  role.
