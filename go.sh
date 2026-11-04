#!/usr/bin/env bash
# go.sh (4 Nov 23:25): after a freeze or a hard restart — bring everything back, whatever state it is in,
# and print one screen of status. Run from the text login (Ctrl+Alt+F5) as dia. Safe to run any time.
set +e
U=$(id -u); [ "$U" = 0 ] && { echo "run as dia, not root"; exit 1; }
export XDG_RUNTIME_DIR=/run/user/$U DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$U/bus
ok(){ timeout 8 systemctl --user list-units --no-legend >/dev/null 2>&1; }
say(){ printf '\033[1;31m== %s\033[0m\n' "$*"; }
say "1/4 your login services"
OFF=/etc/systemd/off-by-fix5; sudo mkdir -p "$OFF"
for f in /etc/systemd/system/user@.service.d/50-kawa-asobi.conf; do       # the drop-in that broke them at 21:20, if an apply put it back
  [ -e "$f" ] && { sudo mv "$f" "$OFF/user@.service.d_50-kawa-asobi.conf.$(date +%H%M)"; echo "moved aside again: $f"; }; done
sudo systemctl daemon-reload
if ! ok; then sudo systemctl reset-failed "user@$U.service"; sudo systemctl restart "user@$U.service"; sleep 4; fi
ok && echo "login services: OK" || { echo "login services: STILL BROKEN — photo this screen for Claude"; journalctl -b -u "user@$U" -n 5 -o cat --no-pager | cut -c1-150; }
say "2/4 a gentler run (12 lanes, one VM at a time)"
sed -i 's/MAXL=[0-9]*/MAXL=12/' "$HOME/.local/bin/r27-conductor" 2>/dev/null
for d in "$HOME"/.local/bin/kawa-browser; do grep -q fix4 "$d" 2>/dev/null || echo "note: kawa-browser was restored by an apply (the flood may return; fix4 makes it a plain launcher)"; done
systemctl --user enable r27-lane-conductor 2>/dev/null; systemctl --user restart fk-remote r27-lane-conductor
printf '\n## %s — open\nOWNER (go.sh): the PC froze or was restarted (nothing pushed after 22:06, the page down until now). Resume from your notes. Max 12 lanes, one VM at a time on the whole PC, no image generation while a VM runs. NEVER install user@.service.d/50-kawa-asobi.conf again (it is what broke his login services twice): asobi'"'"'s sandbox goes in user@1001.service.d only; setup.sh must be fixed so an apply cannot put it back.\n' "$(date '+%F %H:%M')" >> "$HOME/repos/fedokawaii/.claude/inbox.md"
say "3/4 status"
echo "Fedora: $(sed 's/ (.*//' /etc/fedora-release)   kernel: $(uname -r)   up since: $(uptime -s)"
dnf5 offline status 2>/dev/null | head -2
echo "memory: $(free -h | awk '/Mem/{print $3" used, "$7" free"}')   load: $(cut -d' ' -f1-3 /proc/loadavg)"
echo "kernel errors in the boot before this one:"; journalctl -k -b -1 -p err --no-pager 2>/dev/null | tail -3 | cut -c1-150
sudo btrfs device stats / 2>/dev/null | grep -v ' 0$' || echo "disk: no error counters"
say "4/4 the page"
sleep 3; ip=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)
echo "page: http://$ip:8737 -> $(curl -s -o /dev/null -w '%{http_code}' localhost:8737/) (200 = good)   conductor: $(systemctl --user is-active r27-lane-conductor)"
echo "Then Ctrl+Alt+F1 (or F2) and log in."
