# Source Changes

Working-tree changes for this intent (`git diff`):

| File | Change |
| --- | --- |
| `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart` | `PipelineStage.score` removed from `_FeatureRail._studio` and appended to `_FeatureRail._analysis`. |
| `docs/architecture.md` | Navigation sentence now reads "**Analysis** (calibrate, analyze, track, score) and **Studio** (highlight, export)". |

```diff
--- a/app/lib/src/features/workspace/presentation/workspace_studio_screen.dart
+++ b/app/lib/src/features/workspace/presentation/workspace_studio_screen.dart
@@ -475,11 +475,11 @@ class _FeatureRail extends StatelessWidget {
     PipelineStage.calibrate,
     PipelineStage.analyze,
     PipelineStage.track,
+    PipelineStage.score,
   ];
 
   /// Features that shape the highlight.
   static const List<PipelineStage> _studio = <PipelineStage>[
-    PipelineStage.score,
     PipelineStage.highlight,
     PipelineStage.export,
   ];
```

```diff
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -112,8 +112,8 @@
 workspace's videos, one shared video preview in the centre (the studio owns one
 playback controller per selected video and hands it to the active feature), and
-a right feature rail — **Play**, then **Analysis** (calibrate, analyze, track)
-and **Studio** (score, highlight, export). Each rail item shows the stage state
+a right feature rail — **Play**, then **Analysis** (calibrate, analyze, track,
+score) and **Studio** (highlight, export). Each rail item shows the stage state
 (`done` / `ready` / `idle`) derived from the video's facts; `idle` is guidance,
 not a gate.
```

No other source file changed. `PipelineStage`, `resolveStageStates`,
`_buildCenter`, `ScoreView`, `PlayerTrackingView`, and the route table are
untouched.
