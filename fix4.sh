#!/usr/bin/env bash
# fix 4 (4 Nov 21:25): stop the Helium flood at its real source (kawa-browser at login) and find out why
# your user service manager cannot start ("Failed to allocate manager object"). Prints one screen: photo it.
set +e
U=$(id -u); [ "$U" = 0 ] && { echo "run as dia, not root"; exit 1; }
B="$HOME/.local/bin/kawa-browser"; A="$HOME/.config/dwl/autostart.sh"
# 1) the flood: autostart lines that start the browser daemon are turned off; kawa-browser becomes a plain launcher
if [ -e "$A" ]; then sed -i --follow-symlinks -E '/kawa-browser|[Hh]elium/ s/^([^#])/# off (fix4): \1/' "$A"; fi
H=$(command -v helium || command -v helium-browser || ls /usr/bin/*helium* /opt/helium*/helium* 2>/dev/null | head -1)
if [ -f "$B" ] && ! grep -q 'fix4' "$B"; then cp -a "$B" "$B.flood-bak"; printf '#!/bin/sh\n# fix4: a plain launcher until lane-browser fixes its daemon (original: kawa-browser.flood-bak)\nexec %s "$@"\n' "${H:-helium}" > "$B"; chmod +x "$B"; fi
pkill -f -i helium; sleep 1; pkill -9 -f -i helium
echo "FLOOD: autostart off, kawa-browser = plain launcher ($H), helium now: $(pgrep -fci helium)"
# 2) the user service manager: what is wrong
echo "PID1: $(systemctl is-system-running 2>&1)   failed system units: $(systemctl --failed --no-legend --plain | awk '{print $1}' | tr '\n' ' ' | cut -c1-110)"
echo "runtime dir: $(ls -ld /run/user/$U 2>&1 | cut -c1-60)   runtime-dir unit: $(systemctl is-active user-runtime-dir@$U)   user@: $(systemctl is-active user@$U)"
echo "cgroup fs: $(findmnt -no FSTYPE /sys/fs/cgroup)   my cgroup: $(cut -c1-80 /proc/self/cgroup)"
echo "--- user@$U log (last boot):"; journalctl -b -u user@$U --no-pager -n 8 -o cat 2>/dev/null | cut -c1-150
echo "--- systemd/login files changed in the last 12 h:"
sudo find /etc/systemd /etc/pam.d /etc/security /usr/lib/systemd/system/user@.service.d "$HOME/.config/systemd" "$HOME/.config/environment.d" -xdev -newermt '12 hours ago' -type f 2>/dev/null | head -12
# 3) the safe repair: a fresh runtime dir, then the manager
sudo systemctl stop user@$U.service 2>/dev/null; sudo systemctl restart user-runtime-dir@$U.service; sudo systemctl start user@$U.service
sleep 3; export XDG_RUNTIME_DIR=/run/user/$U DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$U/bus
if timeout 8 systemctl --user list-units --no-legend >/dev/null 2>&1; then echo "USER MANAGER: OK now -> run fix3 again, then log in"; else echo "USER MANAGER: still broken -> send this photo to Claude"; journalctl -b -u user@$U --no-pager -n 3 -o cat | cut -c1-150; fi
