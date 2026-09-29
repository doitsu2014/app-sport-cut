# Unit Breakdown

| Unit | Title | Files | Reqs | Acceptance | Depends | Size |
| --- | --- | --- | --- | --- | --- | --- |
| U1 | Move Review & score into the Analysis group | `app/lib/src/features/workspace/presentation/workspace_studio_screen.dart` | RS-1, RS-2, RS-3, RS-4, RS-5, RS-6, RS-7 | `_analysis` renders Mark court, Prepare analysis, Player analysis, Review & score; `_studio` renders only Highlights, Export; `flutter analyze` exits 0; tapping Review & score still shows `ScoreView`. | — | XS (2-line literal change) |
| U2 | Update the rail description in the design record | `docs/architecture.md` | RS-8 | Navigation sentence reads "**Analysis** (calibrate, analyze, track, score) and **Studio** (highlight, export)". | — | XS |
| U3 | Guard the grouping (optional) | `app/test/workspace_studio_rail_test.dart` (or the closest existing studio test) | RS-1, RS-2, RS-3 | A widget test asserts the Analysis order and that Studio holds only Highlight/Export; `flutter test` green. | U1 | S–M (studio needs providers/controller fakes) |

**Walking skeleton:** U1 alone is the end-to-end slice — after it, the rail shows
the new grouping and every other behaviour is unchanged. U2 is documentation;
U3 is a guard.

**Sequencing:** U1 → U2 (same short-lived branch, one review) → U3 if the team
wants the regression guard. Nothing else depends on this change, so there is no
critical path beyond U1.

**Risk front-loading:** the only unknown is whether a studio-rail widget test
can be stood up cheaply (no test currently pumps `WorkspaceStudioScreen`). U3 is
therefore optional and deferred; U1 carries no unknowns.
