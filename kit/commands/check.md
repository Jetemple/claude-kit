---
description: "Independent check by a separate Opus agent that never saw our conversation. Before any code: reviews plan.md. After: writes tests from the spec and runs them."
argument-hint: '[optional: "plan", "code", or a file to test]'
disable-model-invocation: true
---
Run an independent check. Focus: $ARGUMENTS

The checker's value is that it hasn't seen our conversation. Its prompt must contain only the problem statement, copied verbatim (from `problem.md` or what I gave you; if you have neither, stop and ask me), and the file paths it needs. Nothing else: no summary of the implementation or approach, our discussion, known bugs, or what you think the right answer is.

**Which check:** if the focus says "plan", check the plan; if it says "code" or names a file, check the code. Otherwise decide: `plan.md` exists and has no `- [x]` step → plan; anything else → code. Say which one you're running in one line.

**Plan:** launch the `plan-reviewer` subagent with the problem statement and the path to `plan.md` (if there is none, stop and tell me to run `/spec` first). Show its report exactly as returned. Then, for each numbered finding, one line: agree or disagree and why, and the change to `plan.md` you'd make. Don't edit `plan.md` until I answer.

**Code:**
1. Run the existing tests, including any I wrote, and show the real output.
2. Launch the `blind-checker` subagent with the problem statement and the paths of the files to test.
3. Show its report exactly as returned.
4. For each failure, say in one or two lines whether it's a real bug or a spec ambiguity worth asking about, and propose the minimal fix. Say whether it's a patch or a sign the design needs a refactor.

Do not change implementation code in this step. I'll decide what to fix and whether to keep `test_blind_*.py`.
