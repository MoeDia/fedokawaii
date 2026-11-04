#!/usr/bin/env bash
# fk-remote installer — run on the PC: the live remote page for the round-27 run, on the LAN only.
set -eu
src=$(cd "$(dirname "$0")" && pwd)
dst=$HOME/.local/share/fedokawaii/remote
mkdir -p "$dst" "$HOME/.config/fedokawaii" "$HOME/.config/systemd/user"
install -m644 "$src/server.py" "$src/index.html" "$dst/"
tok=$HOME/.config/fedokawaii/remote-token
[ -s "$tok" ] || { head -c 18 /dev/urandom | base64 | tr -d '/+=' > "$tok"; }
chmod 600 "$tok"
cat > "$HOME/.config/systemd/user/fk-remote.service" <<UNIT
[Unit]
Description=fedokawaii remote: the round-27 run, live in a browser on the LAN
[Service]
ExecStart=/usr/bin/python3 -I $dst/server.py
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
Restart=always
RestartSec=3
[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable fk-remote.service && systemctl --user restart fk-remote.service
# the firewall: port 8737, from this home network only
net=$(ip -4 -o route show scope link | awk '!/docker|virbr/ {print $1; exit}')
if systemctl is-active -q firewalld && [ -n "$net" ]; then
  sudo firewall-cmd -q --permanent --add-rich-rule="rule family=ipv4 source address=$net port port=8737 protocol=tcp accept"
  sudo firewall-cmd -q --reload
fi
# the run reads the inbox at every pass
grep -q "DESIGN REVIEW (remote)" "$HOME/repos/fedokawaii/CLAUDE.md" || cat >> "$HOME/repos/fedokawaii/CLAUDE.md" <<'NOTE'
- DESIGN REVIEW (remote, owner 2026-11-04): the owner reviews design on his remote page. To ask
  him (T19p, and whenever a design decision is his): put a pack in `.claude/review/current/`:
  one PNG per surface/state named `NN-short-name.png` (both moods, real renders), an optional
  `NN-short-name.md` beside it (what changed, what to judge), and `questions.md` (the questions,
  numbered). Replace the pack each time (move the old one to `.claude/review/YYYY-MM-DD/`).
  His answers arrive in `.claude/review/feedback.md` as "## time — item — love|ok|change|redo|comment — open":
  read them at the start of EVERY pass, turn each into plan work (redo = start that surface
  over), then mark the heading "— done: <commit>". Never finalise a design he marked change/redo.
NOTE
grep -q "INBOX FILE" "$HOME/repos/fedokawaii/CLAUDE.md" || cat >> "$HOME/repos/fedokawaii/CLAUDE.md" <<'NOTE'
- INBOX FILE (owner 2026-10-31): at the start of EVERY pass read `.claude/inbox.md`. Each entry
  headed "— open" is the owner's raw request: rewrite it into clean, precise task(s) in
  .claude/plan.md (right phase and order, acceptance test, files), then change its heading to
  "— in the plan: T.." with the task id(s). Same hard rules as everything else.
  `~/.local/share/fedokawaii/remote` + `fk-remote.service` (port 8737, LAN only, token in
  ~/.config/fedokawaii/remote-token) are the owner's remote page: keep them working through
  every change; you may bring them into the repo's structure and design, never remove them.
NOTE
sleep 1
ip=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)
if systemctl --user is-active -q fk-remote; then
  echo "✔ fk-remote is running"
  echo "  on the Mac open:  http://$ip:8737"
  echo "  token:            $(cat "$tok")"
else
  echo "✘ fk-remote did not start:"; journalctl --user -u fk-remote -n 15 --no-pager
fi
