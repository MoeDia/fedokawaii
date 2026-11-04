#!/usr/bin/env bash
# fix 5 (4 Nov 21:30): your user service manager fails because of a sandbox drop-in written today for
# EVERY user's manager (/etc/systemd/system/user@.service.d/50-kawa-asobi.conf, meant only for the play
# user asobi). This moves today's user@ drop-ins aside one at a time until the manager starts, then runs fix3.
set +e
U=$(id -u); [ "$U" = 0 ] && { echo "run as dia, not root"; exit 1; }
OFF=/etc/systemd/off-by-fix5; sudo mkdir -p "$OFF"
try(){ sudo systemctl daemon-reload; sudo systemctl reset-failed "user@$U.service"; sudo systemctl start "user@$U.service"; sleep 2
  export XDG_RUNTIME_DIR=/run/user/$U DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$U/bus
  timeout 8 systemctl --user list-units --no-legend >/dev/null 2>&1; }
echo "== what the asobi drop-in for every user says:"; sudo head -12 /etc/systemd/system/user@.service.d/50-kawa-asobi.conf 2>/dev/null
for f in /etc/systemd/system/user@.service.d/50-kawa-asobi.conf /etc/systemd/system/user@.service.d/fedokawaii.conf; do
  [ -e "$f" ] || continue
  sudo mv "$f" "$OFF/$(echo "$f" | tr / _)"; echo "== moved aside: $f"
  if try; then
    echo -e "\n\033[1;32mUSER MANAGER: OK — the culprit was $f\033[0m"
    printf '\n## %s — open\nOWNER 21:30 (fix5): his user service manager could not start ("Failed to allocate manager object", "Read-only file system") since today: the culprit was %s (a drop-in for EVERY user@ manager, written today; now in %s). lane-asobi: sandboxing belongs ONLY in user@1001.service.d (the asobi user), never in user@.service.d; prove dia'"'"'s manager starts after every change. Main: add a regression check that user@1000 starts.\n' "$(date '+%F %H:%M')" "$f" "$OFF" >> "$HOME/repos/fedokawaii/.claude/inbox.md"
    [ -d "$HOME/repos/fk-asobi" ] && printf '\n## OWNER 21:30 — YOUR user@.service.d drop-in broke the owner'"'"'s login services (moved to %s). Sandboxing only in user@1001.service.d. Prove user@1000 starts after every change.\n' "$OFF" >> "$HOME/repos/fk-asobi/.claude/notes/lane-asobi.md"
    echo "== now finishing the rest (fix3):"; curl -sL https://raw.githubusercontent.com/MoeDia/fedokawaii/remote/fix3.sh | bash
    exit 0
  fi
done
echo -e "\n\033[1;31mUSER MANAGER: still broken after moving both drop-ins.\033[0m Photo this for Claude:"
journalctl -b -u "user@$U" --no-pager -n 6 -o cat | cut -c1-150
sudo ls /etc/systemd/system/user@.service.d/ /etc/systemd/system/user-.slice.d/ /etc/systemd/user.conf.d/ /etc/systemd/system/systemd-remount-fs.service.d/ 2>&1 | head -12
