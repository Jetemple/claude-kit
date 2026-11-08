---
description: "Pin down the spec before any code: restatement, questions, edge cases, a challenge to my approach, then plan.md once I approve."
argument-hint: "[task, plus my proposed approach if I have one]"
disable-model-invocation: true
disallowed-tools: Edit Write NotebookEdit
---
Help me plan. Do NOT write or edit any code.

Task (and my approach, if given): $ARGUMENTS. If `problem.md` exists, read it first and treat it as the requirements.

Reply in under ~200 words, numbering every item across all sections (1, 2, 3... not restarting) so I can answer "2 yes, 5 no":
1. **Restatement**: the task in 2-3 lines: inputs, outputs, constraints. In an existing repo: which files are involved and what the current behavior is.
2. **Questions**: anything ambiguous I should ask, with the assumption you'd make otherwise.
3. **Edge cases**: the ones that matter for this task (boundaries, empty or invalid input, ordering, concurrency, error paths).
4. **My approach**: if I gave one, challenge it: where it breaks, a cheaper or cleaner alternative, and whether my complexity claim holds. If I gave none, stop here and ask for mine.
5. **Steps** (only if I gave an approach): 3-6 small, testable steps. Tag each `[me]` (judgment-heavy or core logic: I build it with you) or `[agent]` (self-contained: a subagent can build it), with the files it owns.

Then stop. Once I approve (with my answers to your numbered items), write `plan.md` and nothing else: the decisions with a one-line reason each, the edge cases, my complexity claim, and the steps, one per line as `- [ ] N. [me|agent] what; owns: files; done when: test`. Two `[agent]` steps may never own the same file.
