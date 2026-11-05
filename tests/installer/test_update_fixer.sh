#!/usr/bin/env bash
# shellcheck disable=SC2088  # (a ~ here is the text of a file's name, as an answer gives it)
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
  names) grep -q "does not take" "$3" || exit 3; echo foot ;;
  run) cat "$2" >"$FKH/fixer-case"
       case $(cat "$FKH/fixer-says") in
         fixed) rm -f "$FKH/cand-red"; printf '{"verdict":"fixed"}' >"$4"; echo "fixed foot.ini in 1 try, 9 s: renamed"; exit 0 ;;
         fixed-red) printf '{"verdict":"fixed"}' >"$4"; echo "fixed foot.ini in 1 try, 9 s: renamed"; exit 0 ;;
         *) printf '{"verdict":"held"}' >"$4"; echo "held: foot: the docs do not say"; exit 3 ;;
       esac ;;
  keep) mkdir -p "$4"; echo '{}' >"$4/fix-1.json"; echo kept ;;
  unapply) [[ -e $FKH/fixer-no-undo ]] && exit 1; rm -f "$2" ;;
  reapply) echo "kept fixes: 1 in place, 0 dropped" ;;
  status) echo ready ;;
esac
exit 0
EOS
  chmod 0755 "$W/usr/local/sbin/kawa-fixer"
  # (the toolkit's own copy too: the update's steps install the program again)
  cp -a "$W/usr/local/sbin/kawa-fixer" "$W$TK/system/kawa-fixer"
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
called 'kawa-fixer\] keep /var/lib/fedokawaii/update/fix/out.json --fixes /var/lib/fedokawaii/update/fixes.new'
[[ -s $U/fixes/fix-1.json && ! -e $U/fixes.new && ! -e $U/fix-new ]] && _ok || _no "the fix not in force, settled: $(ls "$U")"
not_called 'versionlock exclude foot'; [[ -s $U/holds ]] && _no "a hold was recorded: $(cat "$U/holds")" || _ok
grep -q '^foot 1.25-1.fc44$' "$FKH/evr" && _ok || _no "foot did not go in: $(cat "$FKH/evr")"
has "$(cat "$U/report")" "fixed foot.ini in 1 try"; has "$(sed -n 2p "$U/report")" "mended: foot.ini"
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
called 'kawa-fixer\] reapply --fixes /var/lib/fedokawaii/update/fixes(\.new)? --home /run/fedokawaii/top/home.cand/fkuser --root /run/fedokawaii/top/root.cand'
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

case_ "no fixer on this machine yet: held and told as before; the steps then put it in"
fixer_set fixed; rm -f "$W/usr/local/sbin/kawa-fixer"; up; eq "$RC" 0; called 'versionlock exclude foot-1.25-1.fc44'; not_called 'kawa-fixer\] (names|run)'
called 'kawa-fixer\] install --home /home/fkuser'

case_ "no home's copy (before the split): the fixer says it could not run, held"
fixer_set fixed; del mounts /home 2>/dev/null; sed -i '\|^/home$|d' "$FKH/mounts"; up; eq "$RC" 0
not_called 'kawa-fixer\] run'; called 'versionlock exclude foot-1.25-1.fc44'; has "$(cat "$U/report")" "no copy of the home"
fkh_add mounts /home

case_ "the update red on the running system after all: its fix taken out again with it"
fixer_set fixed; mkdir -p "$U"; rm -rf "$U/fixes" "$U/fix-new"
# (red on the system alone: a check that fails once the fix is in force)
cat >>"$W$TK/lib/update.sh" <<'EOS'
u_check() { up_phase check; echo "the desktop does not start: a red only the running system shows" >"$UPD/why"; return 1; }
EOS
up; eq "$RC" 0 "$(tail -n4 <<<"$OUT")"
called 'kawa-fixer\] unapply /var/lib/fedokawaii/update/fixes/fix-1.json --home /home/fkuser --root /'
[[ ! -e $U/fixes/fix-1.json && ! -e $U/fix-new ]] && _ok || _no "the fix stayed after the update was undone: $(find "$U/fixes" -type f 2>/dev/null | tr '\n' ' ')"
called 'versionlock exclude .*foot-1.25-1.fc44'

case_ "…an undo the disk refuses (full, an I/O error): said, on the list, tried again at the next start"
fixer_set fixed; mkdir -p "$U"; rm -rf "$U/fixes" "$U/fix-new"; rm -f "$U/holds"; fkh fixer-no-undo
up; eq "$RC" 0 "$(tail -n4 <<<"$OUT")"; has "$OUT" "could not be taken back: tried again at the next start"
eq "$(cat "$U/fix-new" 2>/dev/null)" "fix-1.json" "still on the list"; [[ -e $U/fixes/fix-1.json ]] && _ok || _no "its record went"
rm -f "$FKH/fixer-no-undo"; reset_calls; fkrun bash "$TK/setup.sh" --update-resume
called 'kawa-fixer\] unapply /var/lib/fedokawaii/update/fixes/fix-1.json --home /home/fkuser --root /'; [[ ! -e $U/fix-new ]] && _ok || _no "the list stayed"

case_ "a fix proven by a run that ended before its package went in: never in force, asked anew"
fixer_set fixed; mkdir -p "$U/fixes.new"; echo '{}' >"$U/fixes.new/stale.json"; pending "bash 5.2-1.fc44 5.3-1.fc44"; rm -f "$FKH/cand-red"
up; eq "$RC" 0; [[ ! -e $U/fixes.new/stale.json && ! -e $U/fixes/stale.json ]] && _ok || _no "a stale fix came into force"

case_ "a run cut with a copy of the home left: the next one removes it first"
back built; reset_calls; stand_in; fkh fixer-says fixed
fkh_add subvolumes /run/fedokawaii/top/root.cand; mkdir -p "$W/run/fedokawaii/top/root.cand"
pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh_add installed bash
up; eq "$RC" 0; grep -qx /run/fedokawaii/top/home.cand "$FKH/subvolumes" && _no "left behind" || _ok

# ── the move to the next Fedora: the same fixer, on the whole move's transaction in the copy ──────
tk() { fkrun bash "$TK/setup.sh" "$@"; }
osr() { sed -i "s/^VERSION_ID=.*/VERSION_ID=$1/" "$W/etc/os-release"; sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Fedora Linux $1 (Server Edition)\"/" "$W/etc/os-release"; }
move_set() { back built; reset_calls; stand_in; fkh fixer-says "$1"
  mkdir -p "$W/home/fkuser/.local/bin"
  printf '#!/bin/sh\necho "$*" >>"$HOME/.foryou"\n' >"$W/home/fkuser/.local/bin/kawa-foryou"; chmod 755 "$W/home/fkuser/.local/bin/kawa-foryou"
  printf '#!/bin/sh\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$W/usr/local/sbin/kawa-snap"; chmod 755 "$W/usr/local/sbin/kawa-snap"
  printf '#!/bin/sh\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$W/usr/local/bin/notify-send"; chmod 755 "$W/usr/local/bin/notify-send"
  printf 'root=UUID=1 ro rootflags=subvol=root\n' >"$W/etc/kernel/cmdline"
  echo '<repomd/>' >"$FKH/dl/repomd.xml"; echo $(( $(date +%s) - 30 * 86400 )) >"$W/var/lib/fedokawaii/release-45"
  fkh pending-move "foot 1.24-1.fc44 1.25-1.fc45" "fedora-release-common 44-1 45-1"
  fkh_add installed foot; fkh cand-red foot; fkh cand-red-why "$FOOTRED"; rm -f "$FKH/fixer-case"; }
whole() { osr 45; { echo "foot 1.25-1.fc45"; echo "fedora-release-common 45-1"; } >>"$FKH/evr"; fkh_add installed fedora-release-common; }

case_ "the move red in the copy for a config of ours: the fixer on the whole move's transaction, the copy again, then the move goes on"
move_set fixed; tk --upgrade --now; eq "$RC" 0 "$(tail -n4 <<<"$OUT")"
called 'kawa-fixer\] names --why-file /var/lib/fedokawaii/update/why$'
called 'kawa-fixer\] run /var/lib/fedokawaii/update/fix/case.json --out /var/lib/fedokawaii/update/fix/out.json'
called 'kawa-fixer\] keep /var/lib/fedokawaii/update/fix/out.json --fixes /var/lib/fedokawaii/update/fixes.new'
eq "$(jq -c '.packages[0]' "$FKH/fixer-case")" '{"name":"foot","old":"1.24-1.fc44","new":"1.25-1.fc45"}'
eq "$(grep -c 'systemd-nspawn\] .*--setenv=FK_MOVE=1 .* /run/fk-check$' "$CALLS")" 3 "the checks as for a move: red, the fix's whole copy, green"
called 'dnf\] -y system-upgrade reboot'
case_ "…its edit waits for the start after the move: not in force before it; the home's copy gone before the restart"
[[ -s $U/fixes.new/fix-1.json && ! -e $U/fixes/fix-1.json ]] && _ok || _no "not waiting: $(ls "$U")"
has "$(cat "$U/move-mended")" "fixed foot.ini in 1 try"
d=$(grep -n 'btrfs\] subvolume delete .*home.cand' "$CALLS" | tail -n1 | cut -d: -f1); r=$(grep -n 'system-upgrade reboot' "$CALLS" | head -n1 | cut -d: -f1)
((d < r)) && _ok || _no "the home's copy still there at the restart ($d, $r)"
keep moved
case_ "…after the restart, on Fedora 45: in force before the theme, on the system after it, said at the login"
whole; reset_calls; tk --after-upgrade; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
[[ -s $U/fixes/fix-1.json && ! -e $U/fixes.new && ! -e $U/fix-new && ! -e $U/move-mended && ! -e $U/move ]] && _ok || _no "not settled: $(ls "$U")"
called 'kawa-fixer\] reapply --fixes /var/lib/fedokawaii/update/fixes --home /home/fkuser --root /'
not_called 'kawa-snap\] restore'; has "$(cat "$W/home/fkuser/.foryou")" "mended a config of ours"
case_ "…whole, but the desktop does not start on it: the fix out again with the move"
back moved; whole; fkh session-red "not running: waybar"; reset_calls; tk --after-upgrade
called 'kawa-fixer\] unapply /var/lib/fedokawaii/update/fixes/fix-1.json --home /home/fkuser --root /'
called 'kawa-snap\] restore'; [[ ! -e $U/fixes/fix-1.json && ! -e $U/fix-new && ! -e $U/move-mended ]] && _ok || _no "the fix stayed: $(ls "$U")"
case_ "no fix for the move: Fedora 45 waits, its reasons say what the fixer said, nothing armed"
move_set held; tk --upgrade --now; eq "$RC" 0 "$(tail -n4 <<<"$OUT")"
has "$OUT" "Fedora 45 waits: foot does not take its config"; has "$(cat "$U/move-red-45")" "the fixer: held: foot: the docs do not say"
not_called 'system-upgrade'; [[ ! -e $U/move && ! -e $U/move-mended ]] && _ok || _no "armed all the same"
case_ "its fix passes its own check, not the whole move: Fedora 45 waits, said, nothing kept"
move_set fixed-red; tk --upgrade --now; eq "$RC" 0 "$(tail -n4 <<<"$OUT")"
has "$(cat "$U/move-red-45")" "passed its own check, not the whole system"; not_called 'kawa-fixer\] keep'; not_called 'system-upgrade'

case_ "the real program as root: its server runs as the desktop's user with no network, a home's file written as its owner"
back built
HH=$W/home/fkuser; RT=$HH/.local/lib/fedokawaii/llama-b12110; MD=$HH/.local/share/fedokawaii/models
mkdir -p "$RT/answers" "$MD" "$HH/.config/foot" "$W/var/tmp/fxcase/root" "$W/var/tmp/fxcase/log"
cp "$REPO/tests/installer/fixer-stub-server.py" "$RT/llama-server"; chmod 755 "$RT/llama-server"
printf 'tiny model' >"$MD/tiny.gguf"; SUM=$(sha256sum "$MD/tiny.gguf" | cut -d' ' -f1)
printf '[main]\nutempter=none\n' >"$HH/.config/foot/foot.ini"
cat >"$W/usr/local/bin/foot" <<'FOOTEOF'
#!/bin/sh
if grep -q ^utempter "$HOME/.config/foot/foot.ini"; then echo " err: $HOME/.config/foot/foot.ini:2: [main].utempter: not a valid option: utempter" >&2; exit 230; fi
FOOTEOF
chmod 755 "$W/usr/local/bin/foot"
printf 'stuff utmp-helper more' >"$W/var/tmp/fxcase/root/foot.bin"
printf '{"verdict":"fix","reason":"renamed","edits":[{"file":"~/.config/foot/foot.ini","search":"utempter=none","replace":"utmp-helper=none"}]}' >"$RT/answers/1"
mkdir -p "$W/var/tmp/fxsys/card0/device"; echo 17095983104 >"$W/var/tmp/fxsys/card0/device/mem_info_vram_total"; echo 500000000 >"$W/var/tmp/fxsys/card0/device/mem_info_vram_used"; echo 0x1002 >"$W/var/tmp/fxsys/card0/device/vendor"; echo 0x7590 >"$W/var/tmp/fxsys/card0/device/device"
printf '#!/bin/sh\nexec runuser -u fkuser -- env HOME=/home/fkuser PATH=/usr/local/bin:/usr/bin:/bin "$@"\n' >"$W/var/tmp/fxcase/runner"; chmod 755 "$W/var/tmp/fxcase/runner"
jq -n '{why: ["foot does not take its config"], packages: [{name: "foot", old: "1", new: "2"}], runner: ["/var/tmp/fxcase/runner"], home: "/home/fkuser", home_in: "/home/fkuser", root: "/var/tmp/fxcase/root", root_in: "/var/tmp/fxcase/root", old_root: "/var/tmp/fxcase/root", user: "fkuser", user_home: "/home/fkuser", budget_s: 60, stall_s: 5}' >"$W/var/tmp/fxcase/case.json"
cat >"$W/var/tmp/fxcase/pinned" <<PINEOF
import importlib.machinery, importlib.util, sys
sys.dont_write_bytecode = True
s = importlib.util.spec_from_loader("kf", importlib.machinery.SourceFileLoader("kf", "/var/tmp/fxcase/kawa-fixer"))
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
m.MODEL.update({"file": "tiny.gguf", "sha": "$SUM", "size": 10, "vram_mib": 100, "ctx": 4096})
m.PROGRAMS["foot"]["binary"] = "/foot.bin"
m.LOAD_S = 10
sys.argv = ["kawa-fixer"] + sys.argv[1:]
sys.exit(m.main())
PINEOF
cp "$REPO/system/kawa-fixer" "$W/var/tmp/fxcase/kawa-fixer"
fk chown -R fkuser:fkuser /home/fkuser/.local /home/fkuser/.config
fkrun env KAWA_FIXER_SYSFS=/var/tmp/fxsys python3 -B -I /var/tmp/fxcase/pinned run /var/tmp/fxcase/case.json --out /var/tmp/fxcase/out.json --log /var/tmp/fxcase/log
eq "$RC" 0 "$OUT"; eq "$(jq -r .verdict "$W/var/tmp/fxcase/out.json")" fixed "$(jq -r .reason "$W/var/tmp/fxcase/out.json")"
fkrun stat -c '%U' /home/fkuser/.config/foot/foot.ini; has "$OUT" fkuser "its owner kept"
has "$(cat "$HH/.config/foot/foot.ini")" utmp-helper=none
eq "$(grep -c : "$RT/netdev")" 1 "its loopback alone"; has "$(cat "$RT/netdev")" "lo:"
fkrun stat -c '%U' /home/fkuser/.local/lib/fedokawaii/llama-b12110/argv; has "$OUT" fkuser "the server ran as the desktop's user"
eq "$(find "$W/run/fedokawaii" -maxdepth 1 -name 'fixer.*' 2>/dev/null | wc -l)" 0 "its socket's folder gone"

case_ "the toolkit puts the program in place, and the kept edits go over what theme.sh renders"
back built
has "$(cat "$REPO/setup.sh")" 'install -m 0755 "$REPO_DIR/system/kawa-fixer" "$FIXER"'
has "$(cat "$REPO/theme.sh")" 'fix_kept "$dst" "$tmp"'
done_
