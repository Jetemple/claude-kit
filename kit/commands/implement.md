---
description: "Implement steps from plan.md: [me] steps one small diff at a time with me, [agent] steps as parallel subagents that each own their files."
argument-hint: "[step numbers; default: the next step not done]"
disable-model-invocation: true
---
Implement from `plan.md`. Steps: $ARGUMENTS (default: the first `- [ ]` step; if it's `[agent]`, also every other unchecked `[agent]` step it doesn't depend on).

Read `plan.md` first. If it's missing, stop and tell me to run `/spec`. Say which steps you're taking and the files each owns.

**`[me]` step:** write only that step, as the smallest diff that passes its done-when test. Run the tests and show the real output. Walk me through the diff in 3 lines or fewer, then stop so I can read it, change it, or reject it. Never start the next step on your own.

**`[agent]` steps:** if two of them share a file, or one depends on a step that isn't done, stop and say which; launch nothing. Otherwise launch one `general-purpose` subagent per step, all in the same message so they run in parallel. Each brief: the problem statement verbatim, the step's goal and done-when test, the files it owns, "touch no other file; if you need to, stop and report", and "follow the Delegated task rules: run the tests, report in at most 10 lines". Wait until every launched agent has reported. Then show each report, run the full test suite once, and list what each changed (`git diff --stat` in a repo, otherwise the files). Don't fix their work yourself.

When a step's tests pass, change its `- [ ]` to `- [x]` in `plan.md`; if I reject the change, set it back.
