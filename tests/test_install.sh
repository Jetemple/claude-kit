#!/usr/bin/env bash
# Exercises install.sh in throwaway HOMEs. Run: bash tests/test_install.sh
# To test macOS's stock bash 3.2: /bin/bash tests/test_install.sh (the installer runs under the same bash).
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL=("$BASH" "$KIT/install.sh")
FILES="CLAUDE.md settings.json commands/spec.md commands/check.md commands/implement.md commands/explain.md commands/critique.md commands/triage.md agents/blind-checker.md agents/plan-reviewer.md"
fail() { echo "FAIL: $*"; exit 1; }
ok() { echo "ok: $*"; }
json_has() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if eval(sys.argv[2]) else 1)" "$1" "$2"; }

echo "bash $BASH_VERSION"

# 1. Mac-like: existing user config with a symlinked CLAUDE.md and a colliding command.
H="$(mktemp -d)"; mkdir -p "$H/.claude/commands" "$H/rules"
echo "my rules" > "$H/rules/CLAUDE.md"; ln -s "$H/rules/CLAUDE.md" "$H/.claude/CLAUDE.md"
echo '{"theme":"dark","permissions":{"additionalDirectories":["/x"]}}' > "$H/.claude/settings.json"
echo "mine" > "$H/.claude/commands/check.md"; echo "other" > "$H/.claude/commands/keep.md"
HOME="$H" "${INSTALL[@]}" >/dev/null
cmp -s "$H/.claude/CLAUDE.md" "$KIT/kit/CLAUDE.md" || fail "mac: CLAUDE.md not installed"
[ ! -L "$H/.claude/CLAUDE.md" ] || fail "mac: still a symlink"
json_has "$H/.claude/settings.json" 'd["theme"]=="dark" and len(d["permissions"]["deny"])>0 and "additionalDirectories" not in d["permissions"]' || fail "mac: settings not swapped"
HOME="$H" "${INSTALL[@]}" >/dev/null   # idempotent rerun must not clobber backup
[ -L "$H/.claude/.claude-kit/backup/CLAUDE.md" ] || fail "mac: backup lost on rerun"
grep -q mine "$H/.claude/.claude-kit/backup/commands/check.md" || fail "mac: command backup lost"
ls "$H/.claude"/*.claude-kit-edited >/dev/null 2>&1 && fail "mac: rerun flagged untouched files as edited"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
[ -L "$H/.claude/CLAUDE.md" ] && grep -q "my rules" "$H/.claude/CLAUDE.md" || fail "mac: symlink not restored"
grep -q additionalDirectories "$H/.claude/settings.json" || fail "mac: settings not restored"
grep -q mine "$H/.claude/commands/check.md" || fail "mac: command not restored"
[ -f "$H/.claude/commands/keep.md" ] || fail "mac: unrelated file touched"
[ ! -e "$H/.claude/commands/spec.md" ] && [ ! -e "$H/.claude/agents" ] && [ ! -e "$H/.claude/.claude-kit" ] || fail "mac: leftovers"
ok "mac user install / rerun / restore"

# 2. Fresh Codespace: no ~/.claude at all.
H="$(mktemp -d)"
HOME="$H" "${INSTALL[@]}" >/dev/null
for f in $FILES; do cmp -s "$H/.claude/$f" "$KIT/kit/$f" || fail "fresh: $f"; done
[[ "$(HOME="$H" "${INSTALL[@]}" --status)" == *"installed at"* ]] || fail "fresh: status"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
[ ! -e "$H/.claude" ] || fail "fresh: ~/.claude left behind"
ok "fresh codespace user install / uninstall"

# 3. Project mode in someone else's git repo with an existing .claude/settings.json,
#    invoked with a relative path from the parent dir.
H="$(mktemp -d)"; R="$H/repo"; mkdir -p "$R/.claude" "$R/sub"; git -C "$R" init -q
echo '{"x":1}' > "$R/.claude/settings.json"; git -C "$R" add -A; git -C "$R" -c user.email=t@t -c user.name=t commit -qm init
(cd "$H" && HOME="$H" "${INSTALL[@]}" --project repo >/dev/null)
cmp -s "$R/.claude/CLAUDE.md" "$KIT/kit/CLAUDE.md" || fail "project: not installed"
json_has "$R/.claude/settings.json" 'd["x"]==1 and "permissions" in d' || fail "project: settings not merged"
(cd "$R/sub" && HOME="$H" "${INSTALL[@]}" --project .. >/dev/null)
HOME="$H" "${INSTALL[@]}" --uninstall --project "$R" >/dev/null
[ -z "$(git -C "$R" status --porcelain)" ] || { git -C "$R" status --porcelain; fail "project: repo not clean after uninstall"; }
[ ! -e "$H/.claude" ] || fail "project: touched HOME"
ok "project install in foreign repo / restore"

# 4. A failed first install, then a rerun, must keep the user's originals...
H="$(mktemp -d)"; C="$(mktemp -d)"; cp -r "$KIT/install.sh" "$KIT/kit" "$C/"
mkdir -p "$H/.claude"; echo ORIG > "$H/.claude/CLAUDE.md"; echo '{"o":1}' > "$H/.claude/settings.json"
rm "$C/kit/commands/check.md"
HOME="$H" "$BASH" "$C/install.sh" >/dev/null 2>&1 && fail "partial: expected failure"
cp "$KIT/kit/commands/check.md" "$C/kit/commands/"
HOME="$H" "$BASH" "$C/install.sh" >/dev/null
HOME="$H" "$BASH" "$C/install.sh" --uninstall >/dev/null
grep -q ORIG "$H/.claude/CLAUDE.md" && grep -q '"o"' "$H/.claude/settings.json" || fail "partial: originals lost"
[ -z "$(ls -A "$H/.claude/commands" 2>/dev/null)" ] && [ ! -e "$H/.claude/.claude-kit" ] || fail "partial: kit leftovers"
# ...and, from an empty ~/.claude, leave nothing of the kit behind.
H="$(mktemp -d)"; rm "$C/kit/commands/check.md"
HOME="$H" "$BASH" "$C/install.sh" >/dev/null 2>&1 && fail "partial-empty: expected failure"
cp "$KIT/kit/commands/check.md" "$C/kit/commands/"
HOME="$H" "$BASH" "$C/install.sh" >/dev/null
HOME="$H" "$BASH" "$C/install.sh" --uninstall >/dev/null
[ ! -e "$H/.claude" ] || { find "$H/.claude"; fail "partial-empty: kit files left behind"; }
ok "failed install + rerun keeps originals and leaves nothing behind"

# 5. An interrupted uninstall can be rerun without losing the restored original.
H="$(mktemp -d)"; mkdir -p "$H/.claude"; echo ORIG > "$H/.claude/CLAUDE.md"
HOME="$H" "${INSTALL[@]}" >/dev/null
chmod a-w "$H/.claude/commands"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null 2>&1 && fail "interrupted: expected failure"
chmod u+w "$H/.claude/commands"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
grep -q ORIG "$H/.claude/CLAUDE.md" || fail "interrupted: original lost"
[ ! -e "$H/.claude/commands" ] && [ ! -e "$H/.claude/.claude-kit" ] || fail "interrupted: leftovers"
ok "interrupted uninstall reruns safely"

# 6. Edits made while installed survive uninstall.
H="$(mktemp -d)"
HOME="$H" "${INSTALL[@]}" >/dev/null
echo "my note" >> "$H/.claude/CLAUDE.md"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
grep -q "my note" "$H/.claude/CLAUDE.md.claude-kit-edited" || fail "edited: edit lost"
ok "edits kept as .claude-kit-edited"

# 6b. Repeated edits across reinstalls never overwrite an earlier kept copy.
H="$(mktemp -d)"
HOME="$H" "${INSTALL[@]}" >/dev/null
echo "edit one" >> "$H/.claude/CLAUDE.md"
HOME="$H" "${INSTALL[@]}" >/dev/null
echo "edit two" >> "$H/.claude/CLAUDE.md"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
grep -qs "edit one" "$H/.claude/CLAUDE.md.claude-kit-edited" || fail "repeat-edit: first edit lost"
grep -qs "edit two" "$H/.claude/CLAUDE.md.claude-kit-edited.1" || fail "repeat-edit: second edit lost"
ok "repeated edits each kept"

# 6c. Rerunning install keeps other settings keys, including ones added while installed.
H="$(mktemp -d)"; mkdir -p "$H/.claude"; echo '{"model":"keep-me","env":{"KEEP":"yes"}}' > "$H/.claude/settings.json"
HOME="$H" "${INSTALL[@]}" >/dev/null
python3 -c "import json,sys; p=sys.argv[1]; d=json.load(open(p)); d['theme']='dark'; json.dump(d,open(p,'w'))" "$H/.claude/settings.json"
HOME="$H" "${INSTALL[@]}" >/dev/null
json_has "$H/.claude/settings.json" 'd["model"]=="keep-me" and d["env"]["KEEP"]=="yes" and d["theme"]=="dark" and "deny" in d["permissions"]' || fail "rerun-settings: keys dropped"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
json_has "$H/.claude/settings.json" 'd=={"model":"keep-me","env":{"KEEP":"yes"}}' || fail "rerun-settings: original not restored"
ok "rerun keeps settings keys"

# 6c2. Reinstalling saves a copy of edited permissions before replacing them.
H="$(mktemp -d)"
HOME="$H" "${INSTALL[@]}" >/dev/null
python3 -c "import json,sys; p=sys.argv[1]; d=json.load(open(p)); d['permissions']['deny'].append('Bash(my-unique-rule)'); json.dump(d,open(p,'w'))" "$H/.claude/settings.json"
HOME="$H" "${INSTALL[@]}" >/dev/null
grep -qs "my-unique-rule" "$H/.claude/settings.json.claude-kit-edited" || fail "perm-edit: edited permissions lost on reinstall"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
grep -qs "my-unique-rule" "$H/.claude/settings.json.claude-kit-edited" || fail "perm-edit: copy lost on uninstall"
ok "edited permissions kept on reinstall"

# 6d. Command frontmatter is valid YAML with string values (when ruby is available to parse it).
if command -v ruby >/dev/null 2>&1; then
  for f in "$KIT"/kit/commands/*.md; do
    ruby -ryaml -e 'h = YAML.safe_load(File.read(ARGV[0]).split(/^---$/)[1]); exit(h["description"].is_a?(String) && h["argument-hint"].is_a?(String) ? 0 : 1)' "$f" 2>/dev/null || fail "frontmatter: $f"
  done
  ok "command frontmatter parses"
fi

# 6e. A file an older kit installed but this one dropped is retired on reinstall (edits kept).
H="$(mktemp -d)"
HOME="$H" "${INSTALL[@]}" >/dev/null
echo "old" > "$H/.claude/commands/oldcmd.md"; cp "$H/.claude/commands/oldcmd.md" "$H/.claude/.claude-kit/installed/commands/oldcmd.md"
echo "old2" > "$H/.claude/commands/oldedit.md"; echo "orig" > "$H/.claude/.claude-kit/installed/commands/oldedit.md"
HOME="$H" "${INSTALL[@]}" >/dev/null
[ ! -e "$H/.claude/commands/oldcmd.md" ] || fail "retire: dropped file left behind"
grep -qs old2 "$H/.claude/commands/oldedit.md.claude-kit-edited" || fail "retire: edited dropped file lost"
[ ! -e "$H/.claude/.claude-kit/installed/commands/oldcmd.md" ] || fail "retire: marker left"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
[ ! -e "$H/.claude/.claude-kit" ] || fail "retire: leftovers after uninstall"
ok "dropped files retired on reinstall"

# 6f. Both /check agents have the frontmatter Claude Code needs; the plan reviewer is read-only.
for n in blind-checker plan-reviewer; do
  A="$KIT/kit/agents/$n.md"
  for k in "name: $n" "model: opus" "effort: medium" "omitClaudeMd: true"; do
    grep -qx "$k" "$A" || fail "$n frontmatter missing: $k"
  done
done
grep -qx "tools: Read, Grep, Glob" "$KIT/kit/agents/plan-reviewer.md" || fail "plan-reviewer is not read-only"
ok "agent frontmatter"

# 7. A relative-symlinked settings.json (dotfiles) is merged, not dropped, and restored as a link.
H="$(mktemp -d)"; mkdir -p "$H/.claude" "$H/dotfiles"
echo '{"env":{"A":"1"},"permissions":{"allow":["Bash(x)"]}}' > "$H/dotfiles/settings.json"
ln -s ../dotfiles/settings.json "$H/.claude/settings.json"
HOME="$H" "${INSTALL[@]}" >/dev/null
json_has "$H/.claude/settings.json" 'd["env"]["A"]=="1" and "Bash(x)" not in d["permissions"]["allow"]' || fail "symlink-settings: not merged"
grep -q '"A"' "$H/dotfiles/settings.json" && ! grep -q deny "$H/dotfiles/settings.json" || fail "symlink-settings: dotfile changed"
HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
[ -L "$H/.claude/settings.json" ] && grep -q '"A"' "$H/.claude/settings.json" || fail "symlink-settings: not restored"
ok "symlinked settings.json merged and restored"

# 8. No jq: python3 does the merge.
H="$(mktemp -d)"; NB="$(mktemp -d)"
IFS=: read -r -a dirs <<< "$PATH"
for d in "${dirs[@]}"; do for b in "$d"/*; do
  n="$(basename "$b")"; [ "$n" = jq ] || [ -e "$NB/$n" ] || ln -s "$b" "$NB/$n" 2>/dev/null || true
done; done
mkdir -p "$H/.claude"; echo '{"model":"m"}' > "$H/.claude/settings.json"
PATH="$NB" HOME="$H" "${INSTALL[@]}" >/dev/null
json_has "$H/.claude/settings.json" 'd["model"]=="m" and "deny" in d["permissions"]' || fail "nojq: not merged"
PATH="$NB" HOME="$H" "${INSTALL[@]}" --uninstall >/dev/null
json_has "$H/.claude/settings.json" 'd=={"model":"m"}' || fail "nojq: not restored"
ok "merge without jq"

# 9. A symlinked ~/.claude/commands is refused before anything changes.
H="$(mktemp -d)"; mkdir -p "$H/.claude" "$H/dotcmds"; ln -s ../dotcmds "$H/.claude/commands"
HOME="$H" "${INSTALL[@]}" >/dev/null 2>&1 && fail "symlink-commands: expected refusal"
[ -z "$(ls -A "$H/dotcmds")" ] && [ ! -e "$H/.claude/CLAUDE.md" ] || fail "symlink-commands: wrote files"
H="$(mktemp -d)"; mkdir -p "$H/.claude" "$H/dotagents"; ln -s ../dotagents "$H/.claude/agents"
HOME="$H" "${INSTALL[@]}" >/dev/null 2>&1 && fail "symlink-agents: expected refusal"
[ -z "$(ls -A "$H/dotagents")" ] && [ ! -e "$H/.claude/CLAUDE.md" ] || fail "symlink-agents: wrote files"
ok "symlinked commands/agents dir refused"

# 10. curl | bash path: script read from stdin, kit and installer fetched from a local tarball stand-in.
H="$(mktemp -d)"; T="$(mktemp -d)"; mkdir -p "$T/claude-kit-main"; cp -r "$KIT/kit" "$KIT/install.sh" "$T/claude-kit-main/"
tar -czf "$T/kit.tgz" -C "$T" claude-kit-main
mkdir -p "$T/bin"; printf '#!/bin/sh\ncat "%s"\n' "$T/kit.tgz" > "$T/bin/curl"; chmod +x "$T/bin/curl"
(cd "$H" && cat "$KIT/install.sh" | PATH="$T/bin:$PATH" HOME="$H" "$BASH" -s >/dev/null)
cmp -s "$H/.claude/CLAUDE.md" "$KIT/kit/CLAUDE.md" || fail "pipe: not installed"
(cd "$H" && cat "$KIT/install.sh" | PATH="$T/bin:$PATH" HOME="$H" "$BASH" -s -- --uninstall >/dev/null)
[ ! -e "$H/.claude" ] || fail "pipe: uninstall"
ok "curl | bash install / uninstall"
echo "all install tests passed"
