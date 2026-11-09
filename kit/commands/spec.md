---
description: "Pin down the spec before any code: restatement, an approach (mine challenged, or one proposed), edge cases, quick questions with recommended answers, then plan.md once I approve."
argument-hint: "[task, plus my proposed approach if I have one]"
disable-model-invocation: true
disallowed-tools: Edit Write NotebookEdit
---
Help me plan. Do NOT write or edit any code.

Task (and my approach, if given): $ARGUMENTS. If `problem.md` exists, read it first and treat it as the requirements.

Reply in under ~250 words. Section headers are not numbered; number every item under them in one run across all sections (1, 2, 3... never restarting) so I can answer "2 yes, 5 no":
- **Restatement**: the task in 2-3 lines: inputs, outputs, constraints. In an existing codebase: which files are involved and what the current behavior is.
- **Approach**: if I gave one, challenge it: where it breaks, a cheaper or cleaner alternative, and whether my complexity claim holds (if I gave none, state it). If I gave no approach, propose the simplest correct one with its time and space complexity (amortized and worst case if they differ), and one alternative in a line.
- **Edge cases**: the ones that matter, each with the behavior you'd implement in a few words. If the right behavior is genuinely unclear, put it in Questions instead; never list it twice.
- **Questions**, last, three at most: the clarifying questions worth asking the interviewer or owner, each a quick choice with your recommended answer and a one-line reason, e.g. "Invalid limit: raise ValueError or clamp? (ValueError: fail loud)". Easy to answer with confidence; no open-ended questions back to me.

Then stop. Any reply that says go or approve, or answers by number, is approval; a question I don't answer takes your recommended answer, and my answer wins where it differs. Then write `plan.md` and no other file, still no code: the decisions with a one-line reason each, the edge cases with their behavior, the approach and its complexity, and 3-6 small, testable steps that each build or test something, one per line as `- [ ] N. [me|agent] what; owns: files; done when: test`. Tag `[me]` for judgment-heavy or core logic (I build it with you) and `[agent]` for self-contained work a subagent can build. Two `[agent]` steps may never own the same file. After writing it, list the steps in chat, one line each, so I can retag before `/check`.
