#!/usr/bin/env bash
# tools/start.sh — round 27 runs by itself: Claude Code in a loop under your own systemd
# (a user service), so it survives the desktop session being restarted and the PC rebooting
# (linger starts your systemd at boot, no login needed). Each pass is `claude -p START`
# (CLAUDE.md, "START"); state lives in the repo (.claude/plan.md, the ledger), so a new pass
# continues where the last one stopped. It ends by itself when .claude/DONE exists.
#   bash tools/start.sh          install and start it
#   bash tools/start.sh stop     stop it (the work done so far is committed and pushed)
#   bash tools/start.sh status   is it running, and the last lines of its log
# Watch it: tail -f ~/.cache/claude-r27.log
set -eu
repo=$(cd "$(dirname "$0")/.." && pwd)
unit=claude-r27.service
log=$HOME/.cache/claude-r27.log
case ${1:-start} in
  stop)   systemctl --user disable --now "$unit"; exit 0 ;;
  status) systemctl --user --no-pager status "$unit" | sed -n 1,5p; tail -n 20 "$log" 2>/dev/null; exit 0 ;;
  start)  ;;
  *) echo "usage: bash tools/start.sh [stop|status]" >&2; exit 2 ;;
esac
command -v claude >/dev/null || { echo "start: claude is not installed (fedokawaii repair puts it back)" >&2; exit 1; }
# 1. sudo for the run, asked once (your password, typed by you, here): the run removes it at its end
if ! sudo -n true 2>/dev/null; then
  echo "▸ your password, once — the run needs sudo while it works and removes this rule at the end"
  echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/90-claude-temp >/dev/null
  sudo chmod 440 /etc/sudoers.d/90-claude-temp
fi
sudo -n true || { echo "start: sudo is still not passwordless — nothing started" >&2; exit 1; }
loginctl show-user "$USER" -p Linger | grep -q yes || sudo loginctl enable-linger "$USER"
# 2. Claude Code signed in? (a one-line test; if not: sign in now, then /exit)
if ! timeout 120 claude -p "Reply with the single word OK." 2>/dev/null | grep -q OK; then
  echo "▸ Claude Code needs you to sign in once: it opens now — sign in, then type /exit"
  claude
  timeout 120 claude -p "Reply with the single word OK." 2>/dev/null | grep -q OK \
    || { echo "start: Claude Code still does not answer — nothing started" >&2; exit 1; }
fi
mkdir -p "$HOME/.config/systemd/user" "${log%/*}"
cat >"$HOME/.config/systemd/user/$unit" <<UNIT
[Unit]
Description=fedokawaii round 27: Claude Code, on its own until done (tools/start.sh)
After=default.target

[Service]
Type=simple
WorkingDirectory=$repo
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/bin/bash $repo/tools/claude-loop.sh
Restart=on-failure
RestartSec=60

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now "$unit"
# 3. it really runs: a pass has begun and Claude is working
for _ in $(seq 1 30); do
  systemctl --user is-active -q "$unit" && grep -q '=== pass' "$log" 2>/dev/null && pgrep -u "$USER" -f 'claude -p START' >/dev/null && break
  sleep 2
done
if systemctl --user is-active -q "$unit" && pgrep -u "$USER" -f 'claude -p START' >/dev/null; then
  echo "✔ round 27 is running on its own — through restarts and reboots — until it is done. You can go."
else
  echo "✘ it did not start — the last lines of $log:" >&2; tail -n 15 "$log" >&2; exit 1
fi
