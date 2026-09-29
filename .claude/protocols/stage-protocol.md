# Stage Protocol

This protocol is mandatory for every stage in every phase. It defines the
backing loop, the question flow, the approval gate, and the completion report.

## 1. The forwarding loop

You are the conductor. Your entire control structure is:

```
Loop:
  1. directive = run `my-aidlc orchestrate next $ARGUMENTS`
  2. act on directive.kind (see below)
  3. after stage work, run `my-aidlc orchestrate report --stage <slug> --result <outcome>`
  4. resume at step 1 with the directive the report returns, or stop when it
     returns done / error / parked
```

The engine owns all between-stage routing: scope resolution, sequencing,
resume, gate status, and workflow completion. You never re-derive routing in
prose. You own the quality of execution inside the move the engine names.

## 2. Directive kinds

| kind | What you do |
| --- | --- |
| `print` | Do exactly what `directive.message` says, print its output, and stop. |
| `error` | Stop. Print `directive.message` verbatim. Do not retry or work around it. |
| `done` | The workflow is complete. Present the completion summary and stop. |
| `parked` | The workflow is parked. Tell the user how to resume and stop. |
| `ask` | Render `directive.question`, wait for the human, then follow `directive.route`. |
| `run-stage` | Run the named stage body, then report its outcome. |

## 3. Question flow

Use a file-backed question flow for any stage that needs input.

1. Create `<record>/<phase>/<stage>/<stage>-questions.md`.
2. Number the questions. Under each, provide lettered options `A`–`E` plus
   `X` (Other).
3. Ask the human to answer inline with `[Answer]: <letter> <text>`.
4. Detect ambiguity and contradictions. Resolve them inside the stage; never
   carry an open contradiction forward.
5. The questions file is the source of truth for the answers.

For one to three simple options, a structured question UI is also acceptable.
All three flows (guided, self-guided, chat) converge on the questions file.

## 4. Approval gate

Every executed stage ends at a human approval gate.

- Present the artifacts produced, their paths, and a concise summary.
- Offer: **Approve**, **Request Changes**, and (where relevant) **Skip**.
- On Approve, report `--result approved`.
- On Request Changes, report `--result rejected --reason "<feedback>"`, then
  run the Keep / Modify / Redo loop and report `--result revised`.
- The gate is a separate turn: never render it in the same message as a
  question that is still awaiting an answer.

### Keep / Modify / Redo

| Choice | Meaning |
| --- | --- |
| Keep | Accept the artifact as-is. |
| Modify | Edit the existing artifact in place. |
| Redo | Discard partial artifacts and re-run the stage. |

## 5. Completion report

Report every lifecycle outcome exactly once:

```
my-aidlc orchestrate report --stage <slug> --result <outcome> [--user-input "..."] [--reason "..."]
```

Valid results: `in-progress`, `awaiting-approval`, `approved`, `rejected`,
`revised`, `completed`, `skipped`.

A conditional stage that does not apply reports `--result skipped` with a
non-blank `--reason`. Never mark a stage complete that you did not run.

## 6. Talking to the user

Speak as a teammate helping build software, not as a framework narrating
itself. These words stay internal: engine, directive, dispatch, conductor,
harness, scope grid, steering. Report substance — questions, gates, artifacts,
errors — and stay quiet between steps.

## 7. Context loading

Before running a stage body:

1. Read the lead agent persona from the path named in the directive.
2. Read the stage file (`directive.stage_file`).
3. Read each existing path in `directive.consumes`.
4. Read the active scope file when the directive names one.

Agent names alone are not loaded context. Read the files.
