# claude-kit

A small, portable Claude Code setup for working where the human drives: plan first, take small
reviewed steps, verify by running, and understand every line that ships. It installs in a few
seconds on a laptop or in a fresh GitHub Codespace, and uninstalls back to exactly what you had.

## Install

From a clone (read `install.sh` first; it is short):

```
git clone https://github.com/Jetemple/claude-kit && cd claude-kit
./install.sh --project /path/to/repo   # only that repo's .claude/
./install.sh                           # or user-wide ~/.claude/
```

Or in one line, for a throwaway environment like a Codespace:

```
curl -fsSL https://raw.githubusercontent.com/Jetemple/claude-kit/main/install.sh | bash
```

What the installer changes:

- The user-wide install adds the commands and the agents, replaces your `~/.claude/CLAUDE.md`, and the `permissions` block of
  `~/.claude/settings.json` until you uninstall. Your other settings keys (auth, env, model, hooks)
  stay. The merge needs `jq` or `python3`.
- Anything it replaces is moved to `.claude-kit/backup/` first.
- `./install.sh --uninstall` (add `--project DIR` if you used it) restores those backups. If you
  edited an installed file in the meantime, your version is kept as `<file>.claude-kit-edited` (numbered if that name is taken). Reinstalling keeps a copy the same way before it replaces your edited `permissions`.
- `./install.sh --status` lists what is installed.

## What's in it

| File | What it does |
|---|---|
| `kit/CLAUDE.md` | Working rules, with two modes (below) and a short definition of "production ready" |
| `kit/settings.json` | Permissions: `sudo`, `rm -r`, `git push`, `git reset --hard` and reads of `.env` and common credential files are denied; installs, `rm`, `mv` and git history changes ask first; pytest, ruff, mypy and `git add` run without a prompt |
| `/spec` | Restate the task (from `problem.md` if present), challenge my approach or propose one, list edge cases, then quick questions with recommended answers. No code; once I approve it writes `plan.md` with steps tagged `[me]` or `[agent]` |
| `/check` | An independent check by a separate Opus agent (medium effort) that never saw the conversation and gets only the problem statement and file paths. Before any code (`plan.md` with no step done) it runs `plan-reviewer` on the plan: missed requirements, wrong complexity claims, unsafe parallel steps. After, it runs the tests, then `blind-checker` writes its own tests from the spec and reports the real output. Force either with `/check plan` or `/check code` |
| `/implement` | Implements the next step of `plan.md`. A `[me]` step: one small diff, tests run, then it stops for my review. `[agent]` steps: parallel subagents, each owning its own files (refuses if two share one), then the full test suite |
| `/explain` | Plain explanation of the code: what, how, complexity, the line to know. Give it my explanation instead and it checks mine |
| `/critique` | Skeptical review of the current changes, untracked files included |
| `/triage` | Rank a list of tasks, flag file overlap, and draft briefs for the ones safe to run as parallel agents |
| `agents/plan-reviewer` | The independent reviewer behind `/check` before any code. Read, Grep and Glob only; fresh context and no CLAUDE.md |
| `agents/blind-checker` | The independent tester behind `/check`. Fresh context and no CLAUDE.md (both agents need Claude Code 2.1.271+ for that; the installer warns if older). Told to write only new `test_blind_*.py` files and never touch implementation code: an instruction, not a lock, since it can run shell commands |

The commands only run when you type them; Claude won't invoke them on its own. The review-only ones
(`/explain`, `/critique`, `/triage`, and `/spec` apart from writing `plan.md`) tell Claude not to edit and turn off its file-editing
tools for the turn you run them (your follow-up, like "1 fix", can edit again); shell commands are still available, so treat that as a strong default, not a lock. Their names
avoid Claude Code's built-in `/plan`, `/review` and `/verify`.

## Two modes

- **Together (default):** I reason, Claude challenges (`/spec` proposes an approach only when I don't give one). One function, bug or test per turn, run
  after every change, and I write at least one edge-case test myself. Keep Manual permission mode (the kit sets it)
  so every edit shows up for review.
- **Delegated:** when I hand Claude a whole task, or it runs as a subagent, it finishes the task,
  stays inside the files it owns, runs the tests, and reports back in ten lines. With several
  agents running, switch to accept-edits mode (Shift+Tab) so edit prompts don't pile up, and
  review the result with `/critique` instead.

A typical loop:

1. Write the requirements into `problem.md` and ask the person who owns them your questions.
2. `/spec`, with your approach if you have one; answer its numbered items ("go" takes its recommendations); it writes `plan.md`.
3. `/check`: a fresh agent attacks the plan before any code exists. Read the plan yourself after.
4. `/implement`, one step per call (no loop), reading each result: `[me]` steps as small diffs I read, `[agent]` steps as parallel subagents.
5. `/check` again once the core works: now a fresh agent tests the code from the spec alone.
6. `/explain` in your own words, then `/critique` and pick what to fix.

The point of both checks is that the model that planned or wrote the work doesn't grade it.
For a list of independent tasks: `/triage` first, keep the judgment-heavy ones for yourself, and
hand two or three non-overlapping ones to agents.

## Limits

The permission rules are guardrails against the usual spelling of risky commands, not a sandbox.
They match the command text Claude writes, so a script can still do anything the shell can. For
real isolation, use Claude Code's sandbox or a disposable environment.

## Tests

```
bash tests/test_install.sh        # throwaway HOMEs; never touches your real config
/bin/bash tests/test_install.sh   # macOS's stock bash 3.2
```

MIT licensed.
