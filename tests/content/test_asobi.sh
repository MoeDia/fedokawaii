#!/usr/bin/env bash
# tests/content/test_asobi.sh — ASOBI 遊び, the play world, against stand-ins: kawa-asobi, the desktop's
# side (its state, its screens' rows and widths, enter, bottles, close), and kawa-asobi-root, root's side
# (names refused, a snapshot read-only, a reset that closes the world first and keeps a way back, the
# network's and the input's walls up before anything and down at the end, the screen back on the desktop,
# a frozen world only with a game in it). The real walls are tried by tools/asobi-proof.sh.
. "$(dirname "$0")/../lib/harness.sh"

A=$REPO/bin/kawa-asobi R=$REPO/system/asobi/kawa-asobi-root
world() {   # a fresh home and a stand-in world: run folder, drop folder, status as root's job writes it
  sandbox
  export KAWA_ASOBI_RUN=$TMP/krun KAWA_ASOBI_DROP=$TMP/drop KAWA_ASOBI_WORLD=$TMP/world KAWA_ASOBI_ROOT=$TMP/aroot
  export KAWA_ASOBI_TTY0=$TMP/tty0 KAWA_ASOBI_TEST_PATH=$PATH KAWA_ASOBI_CGROUP=$TMP/cg
  APP=$TMP/cg/user.slice/user-$(id -u asobi 2>/dev/null).slice/user@$(id -u asobi 2>/dev/null).service/app.slice
  mkdir -p "$APP"; : >"$APP/cgroup.freeze"
  mkdir -p "$KAWA_ASOBI_RUN" "$KAWA_ASOBI_DROP" "$KAWA_ASOBI_WORLD" "$KAWA_ASOBI_ROOT/snapshots"
  echo tty1 >"$KAWA_ASOBI_TTY0"
  printf 'world\t2200000000\t14300000000\nsnap\tclean\t1793800000\t52000000\t6200000000\nsnap\t20261104-1830\t1793810000\t310000000\t14300000000\nfree\t764000000000\n' >"$KAWA_ASOBI_RUN/status"
  # (is-active: the world runs only when the test says so; everything else: logged, done)
  stub systemctl 'case "$*" in *is-active*.timer) exit 0 ;; *is-active*) [ -e "$TMP/running" ]; exit $? ;; esac; exit 0'
  stub busctl; stub notify-send; stub loginctl; stub nft 'cat >"$TMP/nft.in"'; stub udevadm; stub chvt; stub logger
  stub runuser; stub pgrep 'exit 1'; stub ionice 'shift 2; exec "$@"'
  stub btrfs '
case "$1 $2" in
  "subvolume show") [ -d "$3" ]; exit $? ;;
  "subvolume snapshot") shift 2; [ "$1" = -r ] && { shift; touch "$TMP/ro"; }; cp -a "$1" "$2" ;;
  "subvolume delete") rm -rf "$3" ;;
  "filesystem du") printf "Total Exclusive Set-shared Filename\n100 7 - x\n" ;;
  "filesystem usage") printf "Free (estimated): 999 (min: 1)\n" ;;
esac'
}
rows() { bash "$A" --rows "$1" 60; }
root() { OUT=$(bash "$R" "$@" 2>&1); RC=$?; }

world
case_ "misuse: exit 2, and a word about the use"
rc 2 bash "$A" --nonsense; rc 2 bash "$A" --rows nothing 60; rc 0 bash "$A" --help
rc 2 bash "$R" nonsense; rc 2 bash "$R" op; rc 2 bash "$R" op nosuchjob

case_ "the state: off unless the unit is active; then what root's watch says, starting until it has said"
eq "$(bash "$A" state)" off
touch "$TMP/running"; eq "$(bash "$A" state)" starting
echo frozen >"$KAWA_ASOBI_RUN/state"; eq "$(bash "$A" state)" frozen

case_ "the main screen, off: enter, bottles, snapshot, reset, disk, drop; no close, no state word"
rm -f "$TMP/running" "$KAWA_ASOBI_RUN/state"
OUT=$(rows main)
eq "$(cut -f1 <<<"$OUT" | tr '\n' ' ')" "enter bottles snapshot reset disk drop "
has "$OUT" "world 14 GB · free 764 GB"
has "$OUT" "empty"
lacks "$OUT" "…" "nothing is ever cut with an ellipsis"

case_ "running: close appears; asleep when a game is frozen behind the desktop, running when Steam works on"
touch "$TMP/running"; echo frozen >"$KAWA_ASOBI_RUN/state"; OUT=$(rows main)
eq "$(cut -f1 <<<"$OUT" | tr '\n' ' ')" "enter bottles close snapshot reset disk drop "
has "$(grep -P '^enter\t' <<<"$OUT")" asleep
echo away >"$KAWA_ASOBI_RUN/state"; has "$(rows main | grep -P '^enter\t')" running

case_ "every row is as wide as the screen: value right-aligned on the last column, at any width"
. "$HOME/.config/fedokawaii/screen.sh"
for w in 40 60 90; do
  while IFS=$'\t' read -r k r; do
    [[ $k == @(reset|disk|drop) ]] && eq "$(screen_cols "$r")" "$w" "row of width $(screen_cols "$r") at $w: $r"
  done < <(bash "$A" --rows main "$w")
done

case_ "the snapshots: newest first, each its date and the room only it holds"
OUT=$(rows snaps)
eq "$(cut -f1 <<<"$OUT" | tr '\n' ' ')" "20261104-1830 clean "
has "$OUT" "52 MB"; has "$OUT" "310 MB"
heading_=$(bash "$A" --heading snaps 60); has "$heading_" "reset to a snapshot"
heading_=$(bash "$A" --heading main 60); has "$heading_" "asobi"

case_ "no status yet: the screen still opens, its sizes not yet counted"
rm -f "$KAWA_ASOBI_RUN/status"; OUT=$(rows main); has "$OUT" "counting"

world
case_ "enter: off, the session started (it brings the screen itself); running, the seat switched to its VT"
reset_calls; rc 0 bash "$A" enter; called '^systemctl start .*--no-block kawa-asobi.service'; not_called '^busctl'
touch "$TMP/running"; echo away >"$KAWA_ASOBI_RUN/state"
reset_calls; rc 0 bash "$A" enter; called '^busctl .*Seat SwitchTo u 8'; not_called '^systemctl start'
case_ "enter that fails says so, and fails"
rm -f "$TMP/running"; stub systemctl 'case "$*" in *is-active*) exit 1 ;; esac; exit 1'
reset_calls; rc 1 bash "$A" enter; called '^notify-send .*would not start'

world
case_ "bottles: its own unit (its Conflicts= closes Steam); already in front: the seat switched"
reset_calls; rc 0 bash "$A" bottles; called '^systemctl start .*kawa-asobi-bottles.service'
touch "$TMP/running"; reset_calls; rc 0 bash "$A" bottles; called '^busctl .*SwitchTo u 8'
case_ "close: both faces stopped"
reset_calls; rc 0 bash "$A" close; called '^systemctl stop .*kawa-asobi.service kawa-asobi-bottles.service'

world
case_ "snapshot: read-only, named by the time; a name given is used; twice is refused"
root op snapshot:first; eq "$RC" 0 "$OUT"; [[ -d $KAWA_ASOBI_ROOT/snapshots/first && -e $TMP/ro ]] && _ok || _no "not read-only"
has "$(cat "$KAWA_ASOBI_RUN/last")" "ok"
root op snapshot:first; eq "$RC" 1; has "$(cat "$KAWA_ASOBI_RUN/last")" "already"
root op snapshot; eq "$RC" 0 "$OUT"
n=$(find "$KAWA_ASOBI_ROOT/snapshots" -mindepth 1 -maxdepth 1 -name '20*' | wc -l); eq "$n" 1
case_ "a bad name never reaches btrfs: slashes, dots, capitals"
reset_calls
for n in '../../etc' 'a/b' '.hidden' 'UP' 'a b'; do root op "reset:$n"; eq "$RC" 1 "reset:$n"; root op "delete:$n"; eq "$RC" 1 "delete:$n"; done
not_called '^btrfs subvolume (delete|snapshot)'
case_ "clean always stays; what is not there is said"
mkdir -p "$KAWA_ASOBI_ROOT/snapshots/clean"; root op delete:clean; eq "$RC" 1; [[ -d $KAWA_ASOBI_ROOT/snapshots/clean ]] && _ok || _no "deleted"
root op reset:nothing; eq "$RC" 1; has "$(cat "$KAWA_ASOBI_RUN/last")" "no snapshot called nothing"

world
case_ "reset: the world closed first; a way back kept; the world exactly that snapshot; nothing heaped up"
mkdir -p "$KAWA_ASOBI_ROOT/snapshots/good" "$KAWA_ASOBI_ROOT/snapshots/before-reset-old"; echo old >"$KAWA_ASOBI_ROOT/snapshots/good/saved"
echo now >"$KAWA_ASOBI_WORLD/made-later"
stub pgrep 'exit 1'
reset_calls; root op reset:good; eq "$RC" 0 "$OUT"
[[ -e $KAWA_ASOBI_WORLD/saved && ! -e $KAWA_ASOBI_WORLD/made-later ]] && _ok || _no "the world is not the snapshot"
called '^systemctl stop kawa-asobi.service kawa-asobi-bottles.service'; called '^loginctl terminate-user asobi'
first_stop=$(grep -n '^systemctl stop kawa-asobi' "$CALLS" | head -n1 | cut -d: -f1); first_snap=$(grep -n '^btrfs subvolume snapshot' "$CALLS" | head -n1 | cut -d: -f1)
((first_stop < first_snap)) && _ok || _no "a snapshot before the world was closed"
b=$(find "$KAWA_ASOBI_ROOT/snapshots" -mindepth 1 -maxdepth 1 -name 'before-reset-*' -printf '%f\n')
[[ $b == before-reset-2* && $(wc -l <<<"$b") == 1 ]] && _ok || _no "before-reset: [$b]"
[[ -e $KAWA_ASOBI_ROOT/snapshots/$b/made-later ]] && _ok || _no "what it replaced was not kept"
[[ ! -e $KAWA_ASOBI_ROOT/.new && ! -e $KAWA_ASOBI_ROOT/.old ]] && _ok || _no "left beside it"
case_ "reset: a process that will not end: nothing changes"
stub pgrep 'exit 0'
echo keep >"$KAWA_ASOBI_WORLD/keep"
root op reset:good; eq "$RC" 1; [[ -e $KAWA_ASOBI_WORLD/keep ]] && _ok || _no "changed anyway"
has "$(cat "$KAWA_ASOBI_RUN/last")" "nothing changed"

world
case_ "prestart: the world's walls before it starts; the network's rules as they must be; the jobs held back"
reset_calls; root prestart; eq "$RC" 0 "$OUT"
n=$(cat "$TMP/nft.in")
has "$n" 'socket cgroupv2 level 2 != "user.slice/user-'; has "$n" 'th dport 53 accept'
has "$n" '10.0.0.0/8'; has "$n" '192.168.0.0/16'; has "$n" 'fc00::/7'
called '^systemctl start user@'; called '^systemctl stop snapper-timeline.timer'
eq "$(cat "$KAWA_ASOBI_RUN/state")" starting
case_ "prestart: a timer you switched off is not touched, and does not come back"
stub systemctl 'case "$*" in *is-active*fstrim*) exit 1 ;; *is-active*.timer) exit 0 ;; *is-active*) exit 1 ;; esac; exit 0'
reset_calls; root prestart; not_called '^systemctl stop fstrim'; has "$(cat "$KAWA_ASOBI_RUN/held")" snapper-timeline; lacks "$(cat "$KAWA_ASOBI_RUN/held")" fstrim
case_ "prestart: the wall will not load: the world stays closed, and says why"
stub nft 'exit 1'; root prestart; eq "$RC" 1; has "$(cat "$KAWA_ASOBI_RUN/last")" "stays closed"
case_ "prestart: no world (a subvolume missing): no start"
rm -rf "$KAWA_ASOBI_WORLD"; root prestart; eq "$RC" 1; has "$(cat "$KAWA_ASOBI_RUN/last")" "not there"

world
case_ "close: thawed, then closed from the world's own manager, as its user"
echo 1 >"$APP/cgroup.freeze"; reset_calls; root close; eq "$RC" 0 "$OUT"
eq "$(cat "$APP/cgroup.freeze")" 0 "thawed first"; called '^runuser -u asobi .*systemctl --user stop kawa-asobi-world.service'
case_ "poststop: the screen back only when the world had it; walls down; every process gone; jobs back; off"
echo snapper-timeline.timer >"$KAWA_ASOBI_RUN/held"
echo tty8 >"$KAWA_ASOBI_TTY0"; reset_calls; root poststop; eq "$RC" 0 "$OUT"
called '^chvt 1$'; called '^nft delete table inet kawa_asobi'; called '^loginctl terminate-user asobi'
called '^systemctl start snapper-timeline.timer'; eq "$(cat "$KAWA_ASOBI_RUN/state")" off
echo tty1 >"$KAWA_ASOBI_TTY0"; reset_calls; root poststop; not_called '^chvt'

world
case_ "the watch: in front, thawed, the desktop's idle held and its notices hushed; behind with a game: frozen"
stub python3 'printf "tty8\ntty1\n"'
stub systemd-inhibit 'exec sleep 60'
bash -c 'exec -a "reaper SteamLaunch AppId=7" sleep 30' & g=$!
stub pgrep "echo $g"
reset_calls; root watch; eq "$RC" 0 "$OUT"
kill "$g" 2>/dev/null; wait "$g" 2>/dev/null
eq "$(cat "$APP/cgroup.freeze")" 1 "the world's slice frozen"
called '^systemd-inhibit --what=idle'
called 'set-property --runtime user-[0-9]*.slice CPUWeight=400'; called 'set-property --runtime user-[0-9]*.slice CPUWeight=50'
eq "$(cat "$KAWA_ASOBI_RUN/state")" frozen
case_ "the watch: behind with Steam alone: it goes on working (a download)"
stub pgrep 'echo 1'
echo 1 >"$APP/cgroup.freeze"
reset_calls; root watch; eq "$RC" 0 "$OUT"; eq "$(cat "$APP/cgroup.freeze")" 0 "thawed in front, and left so behind"
eq "$(cat "$KAWA_ASOBI_RUN/state")" away

case_ "the unit files: the world's user, its VT, its PAM file; the walls whole; polkit's rule the two units"
S=$REPO/system/asobi
for l in User=asobi TTYPath=/dev/tty8 PAMName=kawa-asobi ExecStop=+/usr/local/sbin/kawa-asobi-root ExecStopPost=+/usr/local/sbin/kawa-asobi-root 'After=' kawa-asobi-bottles.service; do has "$(cat "$S/kawa-asobi.service")" "$l"; done
for l in ProtectHome=tmpfs PrivateTmp=yes PrivateIPC=yes ProtectProc=invisible RestrictSUIDSGID=yes; do has "$(cat "$S/walls.conf")" "$l"; done
has "$(cat "$S/kawa-asobi.rules")" 'kawa-asobi-bottles.service'; has "$(cat "$S/kawa-asobi.rules")" 'polkit.Result.NO'
lacks "$(grep -v '^#' "$S/kawa-asobi.pam")" 'auth' "the world's PAM file has no way to log in"
case_ "Super+G comes back: the world's keyboard has the VT's key under Super, on its own rules, the desktop's untouched"
has "$(cat "$S/xkb-symbols")" 'XF86Switch_VT_1'
has "$(cat "$S/xkb-rules")" '! include %S/evdev'
has "$(cat "$REPO/src/dwl/config.h")" 'kawa-asobi enter'
has "$(cat "$S/kawa-asobi-world")" 'XKB_DEFAULT_RULES=kawa-asobi'
done_
