# Constraint Register

## Hard constraints

| ID | Constraint | Source |
| --- | --- | --- |
| HC-1 | Offline only; no network, telemetry, or online API. | Product principle, `docs/architecture.md` |
| HC-2 | Client track only; no engine, bridge, or `core/` change. | Intent scope; `core/AGENTS.md` |
| HC-3 | No new third-party dependency; `pubspec.yaml` unchanged. | RS-11; org memory (dependency changes reviewed) |
| HC-4 | Do not hand-edit or commit generated bridge files. | Root `AGENTS.md` |
| HC-5 | Presentation-only: `PipelineStage`, `resolveStageStates`, and the route table stay as they are. | RS-7 |
| HC-6 | `flutter analyze` clean (lints from `flutter_lints`). | RS-9; `app/AGENTS.md` |
| HC-7 | Documentation stays authoritative: `docs/architecture.md` must match the rail. | RS-8; root `AGENTS.md` |

## Risks

| ID | Risk | L | I | Mitigation |
| --- | --- | --- | --- | --- |
| R-1 | A future edit reintroduces the old grouping. | M | L | Optional single ordering widget test (RS-1/RS-2); otherwise code review against the doc. |
| R-2 | The doc sentence is missed, leaving `architecture.md` wrong. | M | L | RS-8 is an explicit requirement and part of the change, not a follow-up. |
| R-3 | Moving score changes perceived pipeline order or gating. | L | L | It does not: prerequisites live in `resolveStageStates` and are untouched; the rail already treats every stage as selectable. |
