#!/usr/bin/env bash
# fedokawaii emergency fix 3 (4 Nov, 21:25) = fix 2, plus: repairs the user service manager first
# ("Failed to connect to user scope bus via local transport"). Run as your user, from a text login.
set +e
say(){ printf '\n\033[1;31m== %s\033[0m\n' "$*"; }
[ "$(id -u)" = 0 ] && { echo "Run this as dia, not as root (no sudo in front)."; exit 1; }
say "0/6 the user service manager"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
if ! timeout 10 systemctl --user is-system-running >/dev/null 2>&1 && ! timeout 10 systemctl --user list-units --no-legend >/dev/null 2>&1; then
  echo "it is stuck or gone: restarting it (this also stops every agent and every Helium)"
  sudo loginctl enable-linger "$(id -un)"
  sudo systemctl restart "user@$(id -u).service"; sleep 5
  for i in 1 2 3 4 5 6; do timeout 10 systemctl --user list-units --no-legend >/dev/null 2>&1 && break; sleep 3; done
fi
if timeout 10 systemctl --user list-units --no-legend >/dev/null 2>&1; then echo "user service manager: OK"
else echo "user service manager STILL not answering. Reboot (sudo reboot), then run this again from the text login."; exit 1; fi
say "1/6 stopping every agent for a moment"
systemctl --user stop r27-lane-conductor 2>/dev/null
systemctl --user stop 'r27-lane-*' 'r27-nonstop-*' 'r27-bulk-*' claude-r27.service 2>/dev/null
pkill -f '^claude -p'; sleep 2
echo "agents left: $(pgrep -fc '^claude -p')"

say "2/6 every way Helium starts by itself"
mkdir -p "$HOME/.config/systemd/user.off"
for f in $(grep -rlRi helium "$HOME/.config/systemd/user/" 2>/dev/null | sort -u); do
  u=$(basename "$f"); systemctl --user disable --now "$u" 2>/dev/null
  mv -f "$HOME/.config/systemd/user/$u" "$HOME/.config/systemd/user.off/" 2>/dev/null && echo "moved aside: $u"; done
systemctl --user daemon-reload
systemctl --user list-units --all --plain --no-legend 2>/dev/null | grep -iE 'helium|browser' | sed 's/^/still known: /'
for f in "$HOME/.config/dwl/autostart.sh" "$HOME"/.config/autostart/*.desktop; do
  [ -e "$f" ] && grep -qi helium "$f" && { sed -i --follow-symlinks '/[Hh]elium/ s/^/# off (fix2 4 Nov): /' "$f"; echo "turned off in: $f"; }; done
echo "other places that start it (for the run to fix):"; grep -rlRi 'helium' "$HOME/.config/dwl" "$HOME/.local/bin" 2>/dev/null | grep -v '\.off' | head -10

say "3/6 closing Helium and forgetting its windows"
for i in 1 2 3; do pkill -f -i helium; sleep 1; done; pkill -9 -f -i helium
for P in $(find -L "$HOME/.config" -maxdepth 2 -type d -iname '*helium*' 2>/dev/null); do
  rm -rf "$P"/Default/Sessions "$P"/Default/"Current Session" "$P"/Default/"Current Tabs" "$P"/Default/"Last Session" "$P"/Default/"Last Tabs"; done
echo "Helium processes: $(pgrep -fci helium)"

say "4/6 no agent may ever open a window on your screen"
L="$HOME/.local/bin/r27-lane-loop"; C="$HOME/.local/bin/r27-conductor"
grep -q 'unset WAYLAND_DISPLAY' "$L" || sed -i '0,/^export PATH/s//unset WAYLAND_DISPLAY DISPLAY XDG_SESSION_TYPE; export BROWSER=true\nexport PATH/' "$L"
grep -q 'unset WAYLAND_DISPLAY' "$C" || sed -i "s|bash -c 'cd ~/repos/fedokawaii;|bash -c 'unset WAYLAND_DISPLAY DISPLAY; export BROWSER=true; cd ~/repos/fedokawaii;|" "$C"
sed -i 's/^browser|/#browser|/' "$HOME/.config/fedokawaii/r27-lanes" 2>/dev/null
grep -c 'unset WAYLAND_DISPLAY' "$L" "$C" | sed 's/^/display cut off in: /'

say "5/6 the remote page"
systemctl --user restart fk-remote; sleep 2
ip=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)
if=$(ip -4 -o addr show scope global | awk '{print $2}' | head -1)
net=$(ip -4 -o route show scope link | awk '!/docker|virbr/ {print $1; exit}')
zone=$(sudo firewall-cmd --get-zone-of-interface="$if" 2>/dev/null); zone=${zone:-$(sudo firewall-cmd --get-default-zone)}
sudo firewall-cmd -q --zone="$zone" --permanent --add-rich-rule="rule family=ipv4 source address=$net port port=8737 protocol=tcp accept" 2>/dev/null
sudo firewall-cmd -q --reload
echo "firewall zone $zone on $if: $(sudo firewall-cmd --zone="$zone" --list-rich-rules | grep -c 8737) rule(s) for the page"

say "6/6 restarting the run (max 12 lanes, none can touch your screen)"
sed -i 's/MAXL=[0-9]*/MAXL=12/' "$C"
systemctl --user enable r27-lane-conductor 2>/dev/null; systemctl --user restart r27-lane-conductor
N='OWNER 21:20 — URGENT: the Helium flood came back after fix.sh. fix2.sh stopped every agent mid-pass (resume from your notes), moved every Helium user unit to ~/.config/systemd/user.off, turned off Helium in dwl autostart, cleared its windows, paused lane-browser, and CUT THE DISPLAY for every lane and for main (WAYLAND_DISPLAY/DISPLAY unset, BROWSER=true): no agent may ever open a window or a browser in his session again. If main truly needs the display for an apply, export WAYLAND_DISPLAY for that one command only and never start a browser or open a URL. lane-browser stays paused until its login behaviour is fixed and proven in a VM. The page'"'"'s firewall rule now sits in the interface'"'"'s own zone (lane-network: keep it there). Fedora 45 on the PC: still go ahead (owner 21:04), snapshot first, scrub after.'
printf '\n## %s — open\n%s\n' "$(date '+%F %H:%M')" "$N" >> "$HOME/repos/fedokawaii/.claude/inbox.md"
for n in browser network; do [ -d "$HOME/repos/fk-$n" ] && printf '\n## %s\n' "$N" >> "$HOME/repos/fk-$n/.claude/notes/lane-$n.md"; done

printf '\n\033[1;32m================ RESULT ================\033[0m\n'
echo "Helium running now:   $(pgrep -fci helium) processes (should be 0)"
echo "the page:             http://$ip:8737  -> $(curl -s -o /dev/null -w '%{http_code}' localhost:8737/) (200 = good)"
echo "the run:              conductor $(systemctl --user is-active r27-lane-conductor)"
printf '\033[1;32m========================================\033[0m\n'
echo "Now press Ctrl+Alt+F1 (or F2) and log in to the desktop."
