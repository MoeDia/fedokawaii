#!/usr/bin/env bash
# tests/installer/test_update_fixer.sh — the local AI fixer inside the update button's run
# (lib/fixer.sh, on a finished fake machine, kawa-fixer a stand-in; the program itself:
# test_fixer): a config the new version refuses goes to the fixer before anything is held; its
# fix proven by the whole candidate is kept and nothing held; no fix, or one the whole candidate
# refuses: held and told; a failure of another kind never reaches it; its copy of the home is
# made, bound into every candidate and gone at the end.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
up() { fkrun bash "$TK/setup.sh" --update; }
report() { head -n1 "$U/report" | cut -d' ' -f2; }
pending() { fkh pending "$@"; }

world built; releases
U=$W/var/lib/fedokawaii/update
fkh mounts /run/fedokawaii/top
fkh_add mounts /home             # (the flat layout: /home its own subvolume)
keep built

# a stand-in for the program: "run" answers by $FKH/fixer-says (fixed | fixed-red | held)
stand_in() {
  mkdir -p "$W/usr/local/sbin"
  cat >"$W/usr/local/sbin/kawa-fixer" <<'EOS'
#!/bin/bash
. /usr/local/bin/_lib.sh
fkh_log "$*"
case $1 in
  names) grep -q "does not take" "$3" ;;
  run) cat "$2" >"$FKH/fixer-case"
       case $(cat "$FKH/fixer-says") in
         fixed) rm -f "$FKH/cand-red"; printf '{"verdict":"fixed"}' >"$4"; echo "fixed foot.ini in 1 try, 9 s: renamed"; exit 0 ;;
         fixed-red) printf '{"verdict":"fixed"}' >"$4"; echo "fixed foot.ini in 1 try, 9 s: renamed"; exit 0 ;;
         *) printf '{"verdict":"held"}' >"$4"; echo "held: foot: the docs do not say"; exit 3 ;;
       esac ;;
  keep) mkdir -p "$4"; echo '{}' >"$4/fix-1.json"; echo kept ;;
  reapply) echo "kept fixes: 1 in place, 0 dropped" ;;
  status) echo ready ;;
esac
exit 0
EOS
  chmod 0755 "$W/usr/local/sbin/kawa-fixer"
}
FOOTRED='foot does not take its config — err: foot.ini:5: [main].utempter: not a valid option'
fixer_set() { back built; reset_calls; stand_in; fkh fixer-says "$1"
  pending "bash 5.2-1.fc44 5.3-1.fc44" "foot 1.24-1.fc44 1.25-1.fc44" "zlib 1.3-1.fc44 1.3.1-1.fc44"
  fkh_add installed bash foot zlib; fkh cand-red foot; fkh cand-red-why "$FOOTRED"; rm -f "$FKH/fixer-case"; }

case_ "a config refused in the copy: the fixer first; its fix proven: kept, nothing held, the whole set goes in"
fixer_set fixed; up; eq "$RC" 0 "$(tail -n4 <<<"$OUT")"
eq "$(report)" ok; has "$(sed -n 2p "$U/report")" "updated · 3 packages"; lacks "$(sed -n 2p "$U/report")" held
called 'kawa-fixer\] names --why-file /var/lib/fedokawaii/update/why foot'
called 'kawa-fixer\] run /var/lib/fedokawaii/update/fix/case.json --out /var/lib/fedokawaii/update/fix/out.json'
called 'kawa-fixer\] keep /var/lib/fedokawaii/update/fix/out.json --fixes /var/lib/fedokawaii/update/fixes'
not_called 'versionlock exclude foot'; [[ -s $U/holds ]] && _no "a hold was recorded: $(cat "$U/holds")" || _ok
grep -q '^foot 1.25-1.fc44$' "$FKH/evr" && _ok || _no "foot did not go in: $(cat "$FKH/evr")"
has "$(cat "$U/report")" "fixed foot.ini in 1 try"
has "$OUT" "the local AI fixer tries: $FOOTRED"
case_ "…what it was given: the failure, the versions, the copy's paths, the desktop's user"
C=$FKH/fixer-case
has "$(jq -r '.why[0]' "$C")" "foot does not take its config"
eq "$(jq -c '.packages[0]' "$C")" '{"name":"foot","old":"1.24-1.fc44","new":"1.25-1.fc44"}'
eq "$(jq -r '.root' "$C")" /run/fedokawaii/top/root.cand; eq "$(jq -r '.home' "$C")" /run/fedokawaii/top/home.cand/fkuser
eq "$(jq -r '.home_in' "$C")" /home/fkuser; eq "$(jq -r '.user' "$C")" fkuser; eq "$(jq -r '.user_home' "$C")" /home/fkuser; eq "$(jq -r '.old_root' "$C")" /
case_ "…its runner: a program in the copy as the desktop's user, no network, the home's copy at /home"
R=$(cat "$U/fix/run"); has "$R" "--private-network"; has "$R" "--user=fkuser"; has "$R" "--bind=/run/fedokawaii/top/home.cand:/home"; has "$R" "-D /run/fedokawaii/top/root.cand"
case_ "…the home's copy in every candidate, gone at the end; the fix on the running system after the theme"
called 'systemd-nspawn\] .*--bind=/run/fedokawaii/top/home.cand:/home .* dnf5 --disable-plugin=actions -y -C replay /tx'
called 'btrfs\] subvolume snapshot /home /run/fedokawaii/top/home.cand'
called 'btrfs\] subvolume delete .*home.cand'
grep -qx /run/fedokawaii/top/home.cand "$FKH/subvolumes" && _no "the home's copy was left behind" || _ok
called 'kawa-fixer\] reapply --fixes /var/lib/fedokawaii/update/fixes --home /home/fkuser --root /'
a=$(grep -n 'dnf\] -y -C replay' "$CALLS" | head -n1 | cut -d: -f1); b=$(grep -n 'kawa-fixer\] reapply .* --root /$' "$CALLS" | tail -n1 | cut -d: -f1)
((a < b)) && _ok || _no "the fix on the system before its packages ($a, $b)"
case_ "…the kept fix on later candidates too, before their checks"
called 'kawa-fixer\] reapply --fixes /var/lib/fedokawaii/update/fixes --home /run/fedokawaii/top/home.cand/fkuser --root /run/fedokawaii/top/root.cand'
case_ "…the next press: the kept fix in force, nothing asked of the model"
reset_calls; up; eq "$RC" 0; not_called 'kawa-fixer\] run'; called 'kawa-fixer\] reapply'

case_ "no fix: held at the version that broke it, the report says so and why, the rest goes in"
fixer_set held; up; eq "$RC" 0 "$(tail -n4 <<<"$OUT")"
eq "$(report)" ok; has "$(sed -n 2p "$U/report")" "held: foot 1.25-1.fc44"
called 'versionlock exclude foot-1.25-1.fc44'; not_called 'kawa-fixer\] keep'
has "$(cat "$U/report")" "the fixer: held: foot: the docs do not say"
grep -q '^zlib 1.3.1-1.fc44$' "$FKH/evr" && _ok || _no "the rest did not go in"
[[ -z $(compgen -G "$U/fixes/*.json") ]] && _ok || _no "a fix was kept"

case_ "its fix passes its own check but not the whole candidate: not kept, held, said, the home's copy made anew"
fixer_set fixed-red; up; eq "$RC" 0 "$(tail -n4 <<<"$OUT")"
not_called 'kawa-fixer\] keep'; called 'versionlock exclude foot-1.25-1.fc44'
has "$(cat "$U/report")" "passed its own check, not the whole system"
eq "$(grep -c 'btrfs\] subvolume snapshot /home ' "$CALLS")" 2 "a clean copy after a fix that was not kept"

case_ "a failure of another kind never reaches it: no model, no extra copy, held as ever"
back built; reset_calls; stand_in; fkh fixer-says fixed; pending "bash 5.2-1.fc44 5.3-1.fc44" "mesa 26.0-1.fc44 26.1-1.fc44"
fkh_add installed bash mesa; fkh cand-red mesa; rm -f "$FKH/cand-red-why"
up; eq "$RC" 0; called 'kawa-fixer\] names'; not_called 'kawa-fixer\] run'; called 'versionlock exclude mesa-26.1-1.fc44'

case_ "no fixer on this machine: held and told as before"
fixer_set fixed; rm -f "$W/usr/local/sbin/kawa-fixer"; up; eq "$RC" 0; called 'versionlock exclude foot-1.25-1.fc44'; not_called 'kawa-fixer'

case_ "no home's copy (before the split): the fixer says it could not run, held"
fixer_set fixed; del mounts /home 2>/dev/null; sed -i '\|^/home$|d' "$FKH/mounts"; up; eq "$RC" 0
not_called 'kawa-fixer\] run'; called 'versionlock exclude foot-1.25-1.fc44'; has "$(cat "$U/report")" "no copy of the home"
fkh_add mounts /home

case_ "a run cut with a copy of the home left: the next one removes it first"
back built; reset_calls; stand_in; fkh fixer-says fixed
fkh_add subvolumes /run/fedokawaii/top/root.cand; mkdir -p "$W/run/fedokawaii/top/root.cand"
pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh_add installed bash
up; eq "$RC" 0; grep -qx /run/fedokawaii/top/home.cand "$FKH/subvolumes" && _no "left behind" || _ok

case_ "the toolkit puts the program in place, and the kept edits go over what theme.sh renders"
back built
has "$(cat "$REPO/setup.sh")" 'install -m 0755 "$REPO_DIR/system/kawa-fixer" "$FIXER"'
has "$(cat "$REPO/theme.sh")" 'fix_kept "$dst" "$tmp"'
done_
