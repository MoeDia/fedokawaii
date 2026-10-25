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
command -v claude >/dev/null || { echo "start: claude is not installed" >&2; exit 1; }
sudo -n true 2>/dev/null || { echo "start: passwordless sudo is not set up yet — run the sudoers line first (see CLAUDE.md, START)" >&2; exit 1; }
loginctl show-user "$USER" -p Linger | grep -q yes || sudo loginctl enable-linger "$USER"
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
echo "started — watch it with: tail -f $log"
