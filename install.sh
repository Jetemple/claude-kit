#!/usr/bin/env bash
# claude-kit installer: a small "I drive, Claude assists" Claude Code setup.
#
#   ./install.sh                  install to ~/.claude (default)
#   ./install.sh --project [DIR]  install to DIR/.claude (default DIR: current directory)
#   ./install.sh --uninstall      remove the kit and restore backed-up files (same target flags)
#   ./install.sh --status         show what is installed
#
# One-liner (no clone needed; downloads the kit from GitHub):
#   curl -fsSL https://raw.githubusercontent.com/Jetemple/claude-kit/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Jetemple/claude-kit/main/install.sh | bash -s -- --uninstall
#
# Safe to rerun, and safe to rerun after a failure. Existing files are moved to
# <target>/.claude-kit/backup/ and put back by --uninstall. A copy of each installed file is kept
# in <target>/.claude-kit/installed/, so uninstall never deletes a file you edited (it is kept as
# <name>.claude-kit-edited). An existing settings.json keeps its other keys; only "permissions" is
# swapped (needs jq or python3). Needs no credentials. Hides nothing from git.
set -euo pipefail

KIT_REPO="${KIT_REPO:-Jetemple/claude-kit}"
KIT_REF="${KIT_REF:-main}"
# settings.json first: its merge is the step most likely to stop the install, so it fails
# before anything else is touched.
FILES=(settings.json CLAUDE.md commands/spec.md commands/check.md commands/implement.md commands/explain.md
       commands/critique.md commands/triage.md agents/blind-checker.md agents/plan-reviewer.md)

usage() {
  cat <<'USAGE'
claude-kit installer
  install.sh                  install to ~/.claude (default)
  install.sh --project [DIR]  install to DIR/.claude (DIR must exist; default: current dir)
  install.sh --uninstall      remove the kit and restore backups (add --project DIR if used)
  install.sh --status         show what is installed
Via curl: curl -fsSL https://raw.githubusercontent.com/Jetemple/claude-kit/main/install.sh | bash -s -- [flags]
USAGE
}

ARGS=("$@")
mode=install
target="${HOME}/.claude"
scope=user

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      scope=project
      dir="$PWD"
      if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then dir="$2"; shift; fi
      [ -d "$dir" ] || { echo "no such directory: $dir" >&2; exit 2; }
      target="$(cd "$dir" && pwd -P)/.claude" ;;
    --user) scope=user; target="${HOME}/.claude" ;;
    --uninstall|--restore) mode=uninstall ;;
    --status) mode=status ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

state="$target/.claude-kit"
installed="$state/installed"
backup="$state/backup"

say() { printf 'claude-kit: %s\n' "$*"; }
exists() { [ -e "$1" ] || [ -L "$1" ]; }
# Set aside an edited kit file without overwriting anything: name.claude-kit-edited[.N].
# keep_edit moves it; keep_edit_copy copies it (used when the file stays in use).
keep_edit() { _keep mv "$@"; }
keep_edit_copy() { _keep cp "$@"; }
_keep() {
  local op="$1" p="$2.claude-kit-edited" n=1
  while exists "$p"; do p="$2.claude-kit-edited.$n"; n=$((n+1)); done
  "$op" "$2" "$p"; say "kept your edits to $3 as ${p#"$target"/}"
}

# Kit source: alongside this script. When piped from curl there is no script file, so download
# the tarball and run the installer inside it, which keeps the script and the kit the same version.
find_src() {
  local here=""
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  if [ -n "$here" ] && [ -f "$here/kit/CLAUDE.md" ]; then
    SRC="$here/kit"; return
  fi
  local tmp; tmp="$(mktemp -d)"
  say "downloading $KIT_REPO@$KIT_REF"
  if ! curl -fsSL "https://codeload.github.com/$KIT_REPO/tar.gz/$KIT_REF" | tar -xz -C "$tmp"; then
    rm -rf "$tmp"; echo "download failed; nothing was changed" >&2; exit 1
  fi
  local inner; inner="$(echo "$tmp"/*/install.sh)"
  [ -f "$inner" ] || { rm -rf "$tmp"; echo "installer not found in download" >&2; exit 1; }
  local rc=0
  "$BASH" "$inner" ${ARGS[@]+"${ARGS[@]}"} || rc=$?
  rm -rf "$tmp"
  exit "$rc"
}

# Print $1 (the user's settings, symlinks followed) with "permissions" replaced by the kit's.
merge_settings() {
  if command -v jq >/dev/null 2>&1; then
    jq -e 'type == "object"' "$1" >/dev/null 2>&1 || return 1
    jq -s '.[0] + {permissions: .[1].permissions}' "$1" "$SRC/settings.json"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$1" "$SRC/settings.json" <<'PY'
import json, sys
mine = json.load(open(sys.argv[1]))
if not isinstance(mine, dict):
    sys.exit(1)
mine["permissions"] = json.load(open(sys.argv[2]))["permissions"]
print(json.dumps(mine, indent=2))
PY
  else
    return 2
  fi
}

# Take one installed kit file out: keep it if edited, restore the backup, drop the marker.
remove_one() {
  local f="$1" dst="$target/$1"
  if exists "$dst" && ! cmp -s "$dst" "$installed/$f"; then
    keep_edit "$dst" "$f"
  else
    rm -f "$dst"
  fi
  if exists "$backup/$f"; then mv "$backup/$f" "$dst"; say "restored $f"; fi
  rm -f "$installed/$f"   # progress is saved per file, so an interrupted run can resume
}

do_install() {
  local d
  for d in commands agents; do
    if [ -L "$target/$d" ]; then
      echo "$target/$d is a symlink; refusing to write kit files into its target." >&2
      echo "Use --project DIR instead, or replace the symlink with a real directory." >&2
      exit 1
    fi
  done
  find_src
  mkdir -p "$target" "$installed" "$backup"
  NEW=""; trap 'rm -f "$NEW"' EXIT
  for f in "${FILES[@]}"; do
    local dst="$target/$f" mark="$installed/$f" bak="$backup/$f" new
    mkdir -p "$(dirname "$dst")" "$(dirname "$mark")" "$(dirname "$bak")"
    new="$(mktemp "$target/.claude-kit-new.XXXXXX")"; NEW="$new"
    cp "$SRC/$f" "$new"
    if exists "$mark"; then
      # Already ours from an earlier run. settings.json: re-merge into the active file so keys
      # added since (model, env) stay. Other files: refresh, keeping any edits made since.
      if [ "$f" = settings.json ] && exists "$dst" && merge_settings "$dst" > "$new" 2>/dev/null; then
        # Other keys carry over, but edits to "permissions" are about to be replaced: save a copy.
        if ! cmp -s "$dst" "$mark"; then keep_edit_copy "$dst" "$f"; fi
      else
        cp "$SRC/$f" "$new"
        if exists "$dst" && ! cmp -s "$dst" "$mark"; then keep_edit "$dst" "$f"; fi
      fi
    elif exists "$dst" && ! exists "$bak"; then
      # The user's own file: build the merged settings from it before moving it (this follows
      # symlinks, including relative ones), then back it up.
      if [ "$f" = settings.json ]; then
        local rc=0
        merge_settings "$dst" > "$new" || rc=$?
        if [ "$rc" = 2 ]; then
          rm -f "$new"
          echo "need jq or python3 to merge your settings.json; nothing was changed" >&2; exit 1
        elif [ "$rc" != 0 ]; then
          cp "$SRC/$f" "$new"
          say "note: your settings.json is not a JSON object, so it is replaced until --uninstall"
        fi
      fi
      mv "$dst" "$bak"; say "backed up $f"
    elif [ "$f" = settings.json ] && exists "$bak"; then
      # A backup exists from an interrupted run: merge from it.
      merge_settings "$bak" > "$new" 2>/dev/null || cp "$SRC/$f" "$new"
    fi
    mv "$new" "$dst"; NEW=""
    cp "$dst" "$mark"
  done
  # Files an older version of the kit installed but this one doesn't ship (a renamed command):
  # remove them like --uninstall would, keeping edits and restoring backups.
  local m
  while IFS= read -r m; do
    m="${m#"$installed"/}"
    case " ${FILES[*]} " in *" $m "*) continue ;; esac
    remove_one "$m"
  done < <(find "$installed" -type f)
  local undo="--uninstall"
  [ "$scope" = project ] && undo="--uninstall --project $(printf '%q' "$(dirname "$target")")"
  say "installed to $target ($scope). Start a new claude session to load it."
  # The /check agents' omitClaudeMd needs Claude Code 2.1.271+; older versions ignore it silently.
  local v
  v="$(claude --version 2>/dev/null | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')" || true
  if [ -n "$v" ] && [ "$(printf '%s\n' 2.1.271 "$v" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" != 2.1.271 ]; then
    say "warning: Claude Code $v is older than 2.1.271, so /check's agents would see CLAUDE.md. Update: claude update"
  fi
  [ "$scope" = project ] && say "note: the files show up in git status; allow rules apply once Claude Code trusts the folder."
  say "commands: /spec /check /implement /explain /critique /triage; agents: blind-checker, plan-reviewer (used by /check)"
  say "undo: install.sh $undo"
}

do_uninstall() {
  if [ ! -d "$installed" ] && [ ! -d "$backup" ]; then say "nothing installed at $target"; exit 0; fi
  local f
  if [ -d "$installed" ]; then
    while IFS= read -r f; do
      f="${f#"$installed"/}"
      remove_one "$f"
    done < <(find "$installed" -type f)
  fi
  # Backups with no installed copy (an install interrupted right after backing up).
  if [ -d "$backup" ]; then
    while IFS= read -r f; do
      f="${f#"$backup"/}"
      if exists "$target/$f"; then
        say "left $backup/$f in place: $target/$f exists"
      else
        mkdir -p "$(dirname "$target/$f")"; mv "$backup/$f" "$target/$f"; say "restored $f"
      fi
    done < <(find "$backup" \( -type f -o -type l \))
  fi
  if [ -z "$(find "$backup" \( -type f -o -type l \) 2>/dev/null)" ]; then rm -rf "$state"; fi
  rmdir "$target/commands" "$target/agents" 2>/dev/null || true
  rmdir "$target" 2>/dev/null || true
  say "uninstalled from $target"
}

case "$mode" in
  install) do_install ;;
  uninstall) do_uninstall ;;
  status)
    if [ -d "$installed" ] && [ -n "$(find "$installed" -type f)" ]; then
      say "installed at $target:"; find "$installed" -type f | sed "s|^$installed/|  |" | sort
    else say "not installed at $target"; fi ;;
esac
