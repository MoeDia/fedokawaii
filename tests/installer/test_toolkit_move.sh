#!/usr/bin/env bash
# tests/installer/test_toolkit_move.sh — fedokawaii itself through the update button (lib/update.sh
# up_toolkit; update-design.md §4 phase 1, §5 row 28), in the fake machine: only a release tag, only
# forward; its own checks before it replaces anything; red → this toolkit goes on, that tag never
# again; green → the system before it is the run's snapshot, the run starts again from it, the report
# names it; a red after it takes it back, no package blamed. A toolkit from your copy stays yours.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
tk() { fkrun bash "$TK/setup.sh" "$@"; }
press() { tk --update; }

world built; releases
U=$W/var/lib/fedokawaii/update
fkh mounts /run/fedokawaii/top
printf '#!/bin/sh\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$W/usr/local/sbin/kawa-snap"; chmod 755 "$W/usr/local/sbin/kawa-snap"
fkh pending "bash 5.3-1.fc44 5.3-2.fc44"
keep built

case_ "no release on GitHub yet: this toolkit goes on, nothing asked of anyone"
press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"; called 'git\] .*ls-remote --tags --refs --sort=-version:refname https://github.com/MoeDia/fedokawaii.git v\*'; not_called 'git\] .* clone '
case_ "GitHub does not answer: said, the update goes on"
back built; fkh fail-git-ls-remote 1; press; eq "$RC" 0; has "$OUT" "GitHub does not answer: fedokawaii itself stays as it is this time"; called 'replay'
case_ "a toolkit applied from your copy: the press leaves it, GitHub not even asked"
back built; fkh release-tags v2026.11.20; touch "$W/var/lib/fedokawaii/toolkit-from-copy"; press; eq "$RC" 0
has "$OUT" "fedokawaii itself stays as your copy made it"; not_called 'ls-remote'; [[ ! -e $W/usr/local/lib/fedokawaii/FROM-RELEASE ]] && _ok || _no "replaced"

case_ "a new tag, its checks red: this toolkit stays, said in the report's words; that tag never again"
back built; fkh release-tags v2026.11.20; fkh toolkit-red 1; press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
called 'git\] .*clone --quiet --depth 1 --branch v2026.11.20 '; called 'torture'; [[ ! -e $W/usr/local/lib/fedokawaii/FROM-RELEASE ]] && _ok || _no "replaced by a red toolkit"
eq "$(cat "$U/toolkit-red")" v2026.11.20; has "$OUT" "fedokawaii v2026.11.20 failed its own checks"
[[ ! -e $U/snap-first ]] && _ok || _no "a snapshot taken for nothing"
reset_calls; press; eq "$RC" 0; not_called ' clone '; has "$OUT" "fedokawaii v2026.11.20 was refused before"
case_ "a script of it that does not parse: red the same, its checks not even run"
back built; fkh release-tags v2026.11.20; fkh toolkit-syntax 1; press; eq "$RC" 0; not_called 'torture'; eq "$(cat "$U/toolkit-red")" v2026.11.20

case_ "a new tag, green: the snapshot first (no second one), the toolkit replaced, the run from it, the report names it; settings kept"
back built; fkh release-tags v2026.11.20 v2026.10.01
sed -i 's/^TIMEZONE=.*/TIMEZONE="Asia\/Dubai"/' "$W/usr/local/lib/fedokawaii/fedokawaii.conf"
mkdir -p "$W/home/fkuser/.config/fedokawaii"; printf 'RESTIC_PASSWORD="his"\n' >"$W/home/fkuser/.config/fedokawaii/secrets.sh"
press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
eq "$(cat "$W/home/fkuser/.config/fedokawaii/secrets.sh")" 'RESTIC_PASSWORD="his"' "his secrets untouched"
[[ -e $W/usr/local/lib/fedokawaii/FROM-RELEASE ]] && _ok || _no "not replaced"
[[ ! -e $W/usr/local/lib/fedokawaii/.git ]] && _ok || _no ".git came along"
has "$(cat "$W/usr/local/lib/fedokawaii/fedokawaii.conf")" 'TIMEZONE="Asia/Dubai"'
eq "$(cat "$W/var/lib/fedokawaii/toolkit-release")" v2026.11.20; [[ ! -e $W/var/lib/fedokawaii/toolkit-from-copy ]] && _ok || _no "marked as your copy"
called 'snapper\] -c root create .*before fedokawaii v2026.11.20'; not_called 'snapper\] -c root create .*before update'
has "$(sed -n 2p "$U/report")" "fedokawaii v2026.11.20"; [[ ! -e $U/toolkit-moved && ! -e $U/snap-first ]] && _ok || _no "its marks left"
has "$OUT" "fedokawaii v2026.11.20: the rest of this update from it"; called 'replay'
keep moved
case_ "the same tag again: nothing fetched; an older tag than this one: never back"
reset_calls; press; eq "$RC" 0; not_called ' clone '
back moved; fkh release-tags v2026.10.01; reset_calls; press; eq "$RC" 0; not_called ' clone '; eq "$(cat "$W/var/lib/fedokawaii/toolkit-release")" v2026.11.20
case_ "fetched, then cut (no network for the clone): this toolkit goes on"
back built; fkh release-tags v2026.11.20; fkh fail-git-clone 5; press; eq "$RC" 0; has "$OUT" "could not be fetched"; [[ ! -e $W/usr/local/lib/fedokawaii/FROM-RELEASE ]] && _ok || _no "replaced"

case_ "a red after it (what only the running system shows): the system before it back, that tag refused, no package held"
back built; fkh release-tags v2026.11.20; fkh mounts /run/fedokawaii/top /home; fkh replay-breaks-dwl
press; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(cat "$U/toolkit-red" 2>/dev/null)" v2026.11.20; [[ ! -s $U/holds ]] && _ok || _no "packages held for fedokawaii's red: $(cat "$U/holds")"
called 'kawa-snap\] restore [0-9]+'; [[ ! -e $U/toolkit-moved ]] && _ok || _no "toolkit-moved left"
has "$OUT" "fedokawaii v2026.11.20 goes back with the rest, and is not tried again"

done_
