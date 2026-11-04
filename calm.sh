#!/usr/bin/env bash
# calm.sh (4 Nov 22:40): the PC is overloaded (ping 300+ ms, the page unreachable). Keep the important lanes
# (update system, ink, pixels, appsui, integrate, asobi, iso, art, hardware) and the main run; park the rest.
set +e
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
R="$HOME/.config/fedokawaii/r27-lanes"
for n in review f45 torrents typing chess learning fixer saver nvim firealpaca regress network system; do
  sed -i "s/^$n|/#$n|/" "$R"; systemctl --user stop "r27-lane-$n" 2>/dev/null && echo "parked: $n"; done
sed -i 's/MAXL=[0-9]*/MAXL=10/' "$HOME/.local/bin/r27-conductor"; systemctl --user restart r27-lane-conductor
printf '\n## %s — open\nOWNER (calm.sh): the PC was overloaded (ping 300+ ms, the remote page unreachable). Parked: review, f45, torrents, typing, chess, learning, fixer, saver (their work is saved; resume them from the page once the sprint lands). Max 10 lanes. lane-updates: one VM at a time again.\n' "$(date '+%F %H:%M')" >> "$HOME/repos/fedokawaii/.claude/inbox.md"
sleep 5; free -h | head -2; echo "agents now: $(pgrep -fc '^claude -p')"
systemctl --user restart fk-remote; sleep 3; curl -s -o /dev/null -w "page: HTTP %{http_code}\n" localhost:8737/
