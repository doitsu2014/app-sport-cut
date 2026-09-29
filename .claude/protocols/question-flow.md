# Question Flow

The question flow is how a stage gathers the human decisions it needs. It is
file-backed so answers survive context loss and can be reviewed.

## Format

```markdown
# <Stage> Questions

## Q1: <question>

A. <option>
B. <option>
C. <option>
D. <option>
E. <option>
X. Other (describe)

[Answer]:

## Q2: <question>

...
```

## Rules

- Every question has 2–5 lettered options plus `X. Other`.
- The human writes `[Answer]: C` (optionally with extra text).
- Never invent an answer or infer one from silence.
- If an answer is ambiguous or contradicts an earlier answer, ask a follow-up
  and record both the question and the resolution.

## Modes

| Mode | How it works |
| --- | --- |
| Guided | The conductor walks the human through each question interactively. |
| Self-guided | The human edits the questions file directly. |
| Chat | The human answers conversationally; the conductor writes the answers into the file. |

All three converge on the same file. The file is the source of truth.

## Contradiction analysis

Before generating artifacts:

1. Read every answered question.
2. Detect ambiguity (an answer that could mean two things) and contradiction
   (two answers that cannot both hold).
3. Resolve each one with the human and update the file.
4. Only then generate artifacts.
