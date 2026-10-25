#!/usr/bin/env bash
# tools/claude-loop.sh — what tools/start.sh's service runs: `claude -p START` again and again
# until .claude/DONE exists. A pass that fails (a usage limit, the network) waits 10 minutes;
# three passes in a row that change nothing in git stop the loop (a note in the log says so),
# so it can never spin and burn tokens for nothing.
cd "$(dirname "$0")/.." || exit 1
log=$HOME/.cache/claude-r27.log
idle=0
while [[ ! -e .claude/DONE ]]; do
  before=$(git rev-parse HEAD 2>/dev/null)$(git status --porcelain 2>/dev/null | md5sum)
  printf '\n=== pass %(%F %T)T ===\n' -1 >>"$log"
  if claude -p "START" --dangerously-skip-permissions --model opus --effort max >>"$log" 2>&1; then
    after=$(git rev-parse HEAD 2>/dev/null)$(git status --porcelain 2>/dev/null | md5sum)
    if [[ $after == "$before" ]]; then
      idle=$((idle + 1))
      ((idle >= 3)) && { printf '=== stopped: three passes changed nothing — see the ledger ===\n' >>"$log"; break; }
    else idle=0; fi
    sleep 5
  else
    printf '=== pass failed (limit or network?) — again in 10 minutes ===\n' >>"$log"
    sleep 600
  fi
done
[[ -e .claude/DONE ]] && printf '=== done ===\n' >>"$log"
systemctl --user disable claude-r27.service >/dev/null 2>&1
exit 0
