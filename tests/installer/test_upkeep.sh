#!/usr/bin/env bash
# tests/installer/test_upkeep.sh — setup.sh's season's update and repair on a finished install
# (the fake machine): offline they say so within half a minute, not after minutes; a package
# transaction cut off half-way is tidied before it is tried again, and a failure never claims
# "nothing was changed"; a fighting service of yours that cannot be disabled (static: D-Bus
# starts it) is masked; your upkeep.conf counts with quotes too.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
tk() { fkrun bash "$TK/setup.sh" "$@"; }

world built; releases
keep built

case_ "update offline: said within half a minute of tries (exit 1), what to do named"
fkh net off
tk --update; eq "$RC" 1
has "$OUT" "no network — connect to one (nmtui), then run it again"
n=$(grep -c 'curl\] .*mirrors.fedoraproject.org' "$CALLS"); ((n >= 3 && n <= 7)) && _ok || _no "$n tries before giving up (wanted about 6)"
eq "$(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update")" stopped "recorded as stopped"
case_ "repair offline: about half a minute of tries, then what needs no network"
reset_calls; tk --repair
has "$OUT" "offline: only what needs no network is repaired now"
n=$(grep -c 'curl\] .*mirrors.fedoraproject.org' "$CALLS"); ((n >= 3 && n <= 7)) && _ok || _no "$n tries"
rm -f "$FKH/net"

case_ "update: a transaction cut off half-way leaves packages twice — tidied, and the next try goes through"
back built; fkh fail-dnf-upgrade 1
tk --update; eq "$RC" 0 "$(grep -E '✘|failed' <<<"$OUT" | head -n3 | tr '\n' '|')"
called 'dnf\] -y remove --duplicates'; eq "$(cat "$FKH/dups")" "" "no package left twice"
has "$OUT" "update done"
case_ "update: it fails every time — stopped, the snapshot named as the way back (never 'nothing was changed')"
back built; fkh fail-dnf-upgrade 9
tk --update; eq "$RC" 1
has "$OUT" "dnf could not update"; has "$OUT" "the snapshot taken before it is the way back"; lacks "$OUT" "nothing was changed"

case_ "the snapshot count the menu shows: recorded by an update; 0 once every snapshot is gone (never the old count)"
back built; printf '%s\n' "1,fedokawaii baseline" "2,pre" "3,post" >"$FKH/snaps"
tk --update; eq "$RC" 0; eq "$(cat "$W/var/lib/fedokawaii/snapshots")" "$(grep -c . "$FKH/snaps")" "the count snapper has (with the update's own)"
: >"$FKH/snaps"; tk --repair; eq "$(cat "$W/var/lib/fedokawaii/snapshots")" 0 "none left: 0"
touch "$FKH/snapper-fail"; printf '%s\n' "1,x" >"$FKH/snaps"; tk --repair
eq "$(cat "$W/var/lib/fedokawaii/snapshots")" 0 "snapper not answering: the record as it was"; rm -f "$FKH/snapper-fail"

case_ "repair: your dunst fighting mako — static (D-Bus starts it), so masked, not only switched off"
back built; fkh_add units "user-static dunst.service" "user-active dunst.service"
tk --repair
has "$OUT" "your dunst.service fights mako"
called 'systemctl\] --user mask dunst.service'
case_ "repair: an enabled one is switched off (and not masked)"
back built; fkh_add units "user-enabled swaync.service" "user-active swaync.service"
tk --repair; called 'systemctl\] --user disable --now swaync.service'; not_called 'mask swaync'

case_ "upkeep.conf: EVERY=\"30\" (quoted) counts as 30 days, as the menu reads it"
back built; mkdir -p "$W/home/fkuser/.config/fedokawaii"
printf 'EVERY="30"     # days\nWAIT=\x2745\x27\n' >"$W/home/fkuser/.config/fedokawaii/upkeep.conf"; fk chown -R fkuser:fkuser /home/fkuser/.config
tk --update; has "$OUT" "the next one in 30 days"
printf 'EVERY=400\n' >"$W/home/fkuser/.config/fedokawaii/upkeep.conf"
tk --update; has "$OUT" "the next one in 90 days" "out of bounds: the default"

done_
