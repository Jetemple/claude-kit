---
description: "Triage a list of tasks: impact, size, risk, overlap, and what to delegate vs. do by hand."
argument-hint: "[paste the task list]"
disable-model-invocation: true
disallowed-tools: Edit Write NotebookEdit
---
Tasks: $ARGUMENTS

Read the repo layout, tests, and entry points first; summarize them in 5 lines or fewer. Then one table row per task:
impact | effort (S/M/L) | risk | files likely touched | depends on | ambiguity (and the question to ask).

Then propose:
- An order.
- Which 2-3 tasks can run as parallel agents with no file overlap, and the one-paragraph brief for each (goal, files it owns, files it must not touch, done-when test).
- Which tasks I should do by hand: the ones needing the most judgment or the most ambiguous.
- What to skip if time runs out.

No code.
