#!/usr/bin/env bash
# fedokawaii emergency fix (4 Nov, 21:05): stop the Helium flood at login, bring the remote page back,
# restart the conductor with fewer lanes. Safe to run more than once. Run as your user (not root).
set +e
say(){ printf '\n\033[1;31m== %s\033[0m\n' "$*"; }

say "1/6 who starts Helium"
ps -eo pid,ppid,args | grep -i '[h]elium' | head -5 | while read -r pid ppid args; do
  echo "helium pid $pid, started by: $(ps -o args= -p "$ppid" 2>/dev/null | cut -c1-120)"; done

say "2/6 stop Helium starting by itself"
for f in $(grep -rli helium "$HOME/.config/systemd/user/" 2>/dev/null); do
  u=$(basename "$f"); systemctl --user disable --now "$u" 2>/dev/null && echo "turned off: $u"; done
for f in "$HOME/.config/dwl/autostart.sh" "$HOME"/.config/autostart/*.desktop; do
  [ -f "$f" ] && grep -qi helium "$f" && { sed -i '/[Hh]elium/ s/^/# off (fix.sh 4 Nov): /' "$f"; echo "turned off in: $f"; }; done
sed -i 's/^browser|/#browser|/' "$HOME/.config/fedokawaii/r27-lanes" 2>/dev/null
systemctl --user stop r27-lane-browser 2>/dev/null && echo "browser lane paused"

say "3/6 close every Helium window and forget its saved windows"
for i in 1 2 3; do pkill -f -i helium; sleep 2; done; pkill -9 -f -i helium
for P in $(find "$HOME/.config" -maxdepth 2 -type d -iname '*helium*'); do
  rm -rf "$P"/Default/Sessions "$P"/Default/"Current Session" "$P"/Default/"Current Tabs" "$P"/Default/"Last Session" "$P"/Default/"Last Tabs"
  echo "cleared saved windows: $P"; done
echo "Helium processes now: $(pgrep -fci helium)"

say "4/6 the remote page"
systemctl --user restart fk-remote; sleep 2
echo "page service: $(systemctl --user is-active fk-remote)"
curl -s -o /dev/null -w "page answers on this PC: HTTP %{http_code}\n" localhost:8737/
if sudo firewall-cmd --list-rich-rules 2>/dev/null | grep -q 8737; then echo "firewall: port 8737 open to the home network"
else net=$(ip -4 -o route show scope link | awk '!/docker|virbr/ {print $1; exit}')
  sudo firewall-cmd -q --permanent --add-rich-rule="rule family=ipv4 source address=$net port port=8737 protocol=tcp accept" && sudo firewall-cmd -q --reload && echo "firewall: port 8737 re-opened for $net"; fi
echo "this PC's address: $(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)"

say "5/6 the run, gentler (max 12 lanes), Fedora 45 upgrade: go ahead"
sed -i 's/MAXL=[0-9]*/MAXL=12/' "$HOME/.local/bin/r27-conductor" 2>/dev/null
systemctl --user enable r27-lane-conductor 2>/dev/null; systemctl --user restart r27-lane-conductor
echo "conductor: $(systemctl --user is-active r27-lane-conductor)"
N='OWNER 21:05 — URGENT, before anything else: at every login a flood of Helium windows opened and made the PC unusable (twice, also after a reboot). fix.sh turned off every Helium autostart, cleared its saved windows and paused lane-browser. Fix the cause: Helium starts with NO window at login (or not at all), never restores old windows, no test ever runs in his session or with his profile; prove it with a real login in a VM or a separate test session before lane-browser resumes. Also: the conductor is limited to 12 lanes (the kernel crashed at 19:15 and btrfs counted checksum errors under the load): keep heavy builds and VMs one at a time, . FEDORA 45: the owner decided (21:04) to GO AHEAD with the PC upgrade tonight ("the memory test will pass, it was the Helium load"): do it through the update button as planned, with the snapshot first, and run a btrfs scrub on / right after the upgrade (report its result in the inbox).'
printf '\n## %s — open\n%s\n' "$(date '+%F %H:%M')" "$N" >> "$HOME/repos/fedokawaii/.claude/inbox.md"
[ -d "$HOME/repos/fk-browser" ] && printf '\n## %s\n' "$N" >> "$HOME/repos/fk-browser/.claude/notes/lane-browser.md"
echo "the run has been told (inbox + the browser lane's notes)"

say "6/6 health"
free -h | head -2
sudo btrfs device stats / 2>/dev/null | grep -v ' 0$' || echo "disk: no error counters"
echo "kernel errors in the previous boot:"; journalctl -k -b -1 -p err --no-pager 2>/dev/null | tail -4
say "done — press Ctrl+Alt+F1 (or F2) to go back to the login screen"
