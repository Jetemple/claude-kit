---
description: "Critical review of the current changes for bugs, edge cases, security, and style."
argument-hint: "[file, path, or task to limit the review to]"
disable-model-invocation: true
disallowed-tools: Edit Write NotebookEdit
---
Review the current changes critically. In a git repo, run `git status --short` and `git diff HEAD`, and read any untracked files in full. Outside a repo, review the current file. If $ARGUMENTS names a file, path, or task, limit the review to it. Be a skeptical senior reviewer, not a cheerleader.

Report, most severe first, numbering every finding across categories (so I can answer "1 fix, 2 skip"), each with file:line and a one-line fix:
1. **Correctness**: bugs, missed edge cases, wrong assumptions, off-by-one errors.
2. **Design**: is the data structure still the right shape, or are we patching around it?
3. **Security and robustness**: input validation, error handling, secrets, injection, resource use.
4. **Code quality**: naming, dead code, duplication, readability, missing tests.

Say "nothing significant" for a category if so. Don't edit code; I'll pick what to fix.
