#!/usr/bin/env bash
# tools/master-brief.sh — the evidence for the master's review of one plan task (T19n), in one
# file: the task as the plan has it, the ledger's lines on it, the owner's own words (the lines
# of CLAUDE.md, his notes and the inbox that match WORDS), the commits that name it (their stat),
# and the shots and logs given — copied beside the brief, so the review reads one folder.
#   bash tools/master-brief.sh TASK [--words REGEX] [FILE…]
#     TASK    the plan's id as the ledger writes it (T19k-7 → the ledger's r27-19k-7)
#     --words a regex for the owner's words (default: the task's id)
#     FILE    shots, px.py output, test logs — evidence to look at
# Out: /dev/shm/r27/master/TASK/brief.md and the files. Exit 0 · 2 misuse.
set -u
(($#)) || { sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 2; }
repo=$(cd "$(dirname "$0")/.." && pwd)
task=$1; shift
words=$task
[[ ${1:-} == --words ]] && { words=$2; shift 2; }
out=/dev/shm/r27/master/$task
rm -rf "$out"; mkdir -p "$out"
id=${task#T}                                   # (T19k-7 → 19k-7: the ledger's r27-19k-7)
base=${task%%-*}                               # (T19k-7 → T19k: its heading in the plan)
{
  echo "# The master's brief: $task ($(date '+%F %H:%M'), $(git -C "$repo" rev-parse --short HEAD))"
  echo
  echo "## The task (.claude/plan.md)"
  awk -v h="### $base " 'index($0, h) == 1 {on = 1; print; next} on && /^### / {exit} on' "$repo/.claude/plan.md"
  echo
  echo "## The ledger's lines on it (.claude/notes/02-LEDGER.md)"
  awk -v k="r27-$id" 'index($0, "- " k) == 1 {on = 1} on && /^- / && index($0, "- " k) != 1 {on = 0} on' "$repo/.claude/notes/02-LEDGER.md"
  echo
  echo "## The owner's words (CLAUDE.md, .claude/notes/round27-owner-notes.md, .claude/inbox.md — lines matching /$words/)"
  grep -n -i -E -- "$words" "$repo/CLAUDE.md" "$repo/.claude/notes/round27-owner-notes.md" "$repo/.claude/inbox.md" 2>/dev/null | sed "s|^$repo/||"
  echo
  echo "## The commits naming it"
  git -C "$repo" log --format='%h %ad %s' --date=format:'%m-%d %H:%M' --grep="$task" | head -20
  for c in $(git -C "$repo" log --format=%h --grep="$task" | head -20); do git -C "$repo" show --stat --format="### %h" "$c" | head -30; done
  echo
  echo "## Evidence (copied here)"
  for f; do
    [[ -e $f ]] || { echo "- (missing) $f"; continue; }
    cp -a -- "$f" "$out/"; echo "- $(basename -- "$f")  (from $f)"
  done
} >"$out/brief.md"
echo "$out/brief.md"
