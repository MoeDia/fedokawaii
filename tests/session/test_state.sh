#!/usr/bin/env bash
# tests/session/test_state.sh — what you set on the desktop is kept (kawa-state and each
# helper's own file under ~/.local/state/fedokawaii): every setting set through its helper,
# then a logout (the runtime folder emptied, mako's modes gone) and a restart (a new boot,
# bluetoothd powering the adapter again, the monitors at their own level), and each comes back
# as it was left — kawa-state restore (autostart, before the bar), kawa-night restore, the
# theme's link, the wallpaper's, the terminal's glass, the screensaver, FreeSync. The store
# itself: written whole, one writer at a time, wrong use refused. The theme ships no file at
# any of these places (fedokawaii apply copies configs/home as it is: tests/installer/
# test_state_keep.sh runs apply, repair and an update over them).
. "$(dirname "$0")/../lib/harness.sh"
ST=$HOME/.local/state/fedokawaii

setup() {
  sandbox; config .config/fedokawaii/env
  ST=$HOME/.local/state/fedokawaii W=$TMP/world; mkdir -p "$W/sys/class/bluetooth/hci0" "$W/proc/sys/kernel/random"
  export W KAWA_SYSFS=$W/sys KAWA_PROC=$W/proc
  echo boot-1 >"$W/proc/sys/kernel/random/boot_id"
  # mako: its modes in a file; "down" until it has been asked $W/mako-late times (it starts beside the bar)
  echo default >"$W/modes"; echo 0 >"$W/mako-asked"
  stub makoctl 'n=$(cat "$W/mako-asked"); echo $((n + 1)) >"$W/mako-asked"; [ "$n" -ge "$(cat "$W/mako-late" 2>/dev/null || echo 0)" ] || exit 1
case "$1 $2" in
  "mode -t") grep -qx "$3" "$W/modes" && sed -i "/^$3\$/d" "$W/modes" || echo "$3" >>"$W/modes" ;;
  "mode -a") grep -qx "$3" "$W/modes" || echo "$3" >>"$W/modes" ;;
  "mode -r") sed -i "/^$3\$/d" "$W/modes" ;;
  *) cat "$W/modes" ;;
esac'
  # bluetoothd: Powered in $W/bt (empty: not answering)
  echo 'b true' >"$W/bt"
  stub busctl '[ -s "$W/bt" ] || exit 1
case $2 in get-property) cat "$W/bt" ;; set-property) echo "b $8" >"$W/bt" ;; esac'
  stub bluetoothctl '[ "$1" = power ] && { [ "$2" = on ] && echo "b true" >"$W/bt" || echo "b false" >"$W/bt"; }; true'
  stub kawa-brightness '[ "$1" = --level ] && { cat "$W/bright"; exit; }; echo "$1" >"$W/bright"'; echo 100 >"$W/bright"
  # gammastep: running while its name is in $W/procs
  : >"$W/procs"
  stub pgrep 'grep -qx gammastep "$W/procs"'
  stub pkill ': >"$W/procs"'
  stub setsid '[ "$2" = gammastep ] && echo "gammastep $*" >>"$W/procs.log" && echo gammastep >"$W/procs"; true'
  stub gammastep; stub sleep; stub kawa-dwlstatus; stub kawa-panel; stub notify-send
  for c in nmcli wpctl kawa-drives kawa-backup kawa-display; do stub "$c" 'exit 1'; done   # (--state's other rows)
  stub kawa-theme '[ "$1" = toggle ] && cd "$HOME/.config/fedokawaii" && ln -sfn themes/light current'
}
# settle N — wait until the restore's record holds N keys (its slow parts run in the background)
settle() { local i; for ((i = 0; i < 300; i++)); do (($(grep -c $'\t' "$ST/restored" 2>/dev/null) >= $1)) && return 0; /bin/sleep 0.02; done; return 1; }
rec() { sed -n "s/^$1\t//p" "$ST/restored"; }   # rec KEY → "STATUS<TAB>VALUE"

case_ "the store: set, get, unset, list; a value with = and spaces; never set: exit 1"
setup
rc 1 kawa-state get dnd
rc 0 kawa-state set dnd on; eq "$(kawa-state get dnd)" on
rc 0 kawa-state set weather-note 'a = b  c'; eq "$(kawa-state get weather-note)" 'a = b  c'
rc 0 kawa-state set dnd off; eq "$(kawa-state get dnd)" off "set again: replaced"
eq "$(kawa-state list)" $'dnd=off\nweather-note=a = b  c' "each in its first place"
rc 0 kawa-state unset weather-note; rc 1 kawa-state get weather-note; eq "$(kawa-state list)" dnd=off
eq "$(find "$ST" -name 'settings.*' ! -name settings.lock)" "" "no half-written file left beside it"
case_ "wrong use (exit 2): a key not a-z 0-9 -, a value of two lines, missing arguments"
rc 2 kawa-state set 'Bad Key' x; rc 2 kawa-state set a=b x; rc 2 kawa-state set dnd $'on\noff'
rc 2 kawa-state get; rc 2 kawa-state set dnd; rc 2 kawa-state frob; eq "$(kawa-state list)" dnd=off
case_ "a hand edit with the key twice: the last wins, and the next write leaves one"
printf 'dnd=on\nbrightness=30\ndnd=off\n' >"$ST/settings"; eq "$(kawa-state get dnd)" off
kawa-state set brightness 35; eq "$(grep -c '^dnd=' "$ST/settings")" 1
case_ "twenty helpers writing at once: every one kept"
setup; for i in $(seq 1 20); do kawa-state set "k$i" "$i" & done; wait
eq "$(kawa-state list | grep -c '^k[0-9]*=')" 20

# ── every setting set through its helper, then a logout and a restart ───────────────
case_ "set through the helpers: do not disturb, Bluetooth off, brightness 40, night light on warmer, screensaver off, FreeSync always, glass off, the light theme, a wallpaper"
setup
kawa-quick --do dnd; eq "$(cat "$W/modes")" $'default\ndo-not-disturb'
kawa-state set bluetooth off; echo 'b false' >"$W/bt"   # (kawa-quick --do bluetooth keeps it: test_quick.sh)
kawa-state set brightness 40; echo 40 >"$W/bright"       # (kawa-brightness keeps it: test_brightness.sh)
kawa-night on; kawa-night warmer; eq "$(kawa-night)" 3500K
kawa-quick --do saver; kawa-quick --do vrr
kawa-glass off >/dev/null 2>&1
kawa-quick --do theme
printf '%s\n' pack:sakura-07 >"$ST/wallpaper-light"
kawa-state set gamemode on                               # (a key of another helper's own)
eq "$(kawa-state list | sort | tr '\n' ' ')" "bluetooth=off brightness=40 dnd=on gamemode=on "
eq "$(cat "$ST/night")" "on 3500"; eq "$(cat "$ST/saver")" off; eq "$(cat "$HOME/.config/fedokawaii/vrr")" always
has "$(cat "$ST/foot-glass.ini")" "alpha=1"; eq "$(readlink "$HOME/.config/fedokawaii/current")" themes/light
before=$(cd "$HOME" && find .local/state/fedokawaii .config/fedokawaii/vrr -maxdepth 1 \( -type f -o -type l \) ! -name '*.lock' -print0 | sort -z | xargs -0 sha256sum; readlink .config/fedokawaii/current)

case_ "logout and restart: the runtime folder empty, mako's modes gone, the adapter powered, the monitors at 100, gammastep not running, a new boot"
rm -rf "${XDG_RUNTIME_DIR:?}"/*; echo default >"$W/modes"; echo 'b true' >"$W/bt"; echo 100 >"$W/bright"; : >"$W/procs"
echo boot-2 >"$W/proc/sys/kernel/random/boot_id"; echo 0 >"$W/mako-asked"; echo 3 >"$W/mako-late"   # (mako answers on the 4th ask)
after=$(cd "$HOME" && find .local/state/fedokawaii .config/fedokawaii/vrr -maxdepth 1 \( -type f -o -type l \) ! -name '*.lock' -print0 | sort -z | xargs -0 sha256sum; readlink .config/fedokawaii/current)
eq "$after" "$before" "every record as it was left"

case_ "login: kawa-state restore and kawa-night restore put each back"
SECONDS=0; rc 0 kawa-state restore; ((SECONDS < 2)) && _ok || _no "the restore held the login ${SECONDS}s (its waits belong in the background)"
settle 4 || _no "the restore did not finish: $(cat "$ST/restored")"
eq "$(head -n1 "$ST/restored")" "boot boot-2" "noted for this boot"
eq "$(rec dnd)" $'ok\ton'; eq "$(cat "$W/modes")" $'default\ndo-not-disturb' "do not disturb, once mako answered"
eq "$(rec bluetooth)" $'ok\toff'; eq "$(cat "$W/bt")" 'b false' "the adapter off again"
eq "$(rec brightness)" $'ok\t40'; eq "$(cat "$W/bright")" 40 "the monitors at 40 again"
eq "$(rec gamemode)" $'kept\ton' "another helper's key: noted, left to it"
kawa-night restore; eq "$(kawa-night)" 3500K "the night light on, as warm"
called 'kawa-dwlstatus --poke 12'
case_ "…and what the programs read themselves stands as left"
eq "$(kawa-quick --state | sed -n 's/^saver\t//p')" off; eq "$(kawa-quick --state | sed -n 's/^vrr\t//p')" always
eq "$(kawa-quick --state | sed -n 's/^theme\t//p')" light; eq "$(kawa-quick --state | sed -n 's/^wallpaper\t//p')" sakura-07
eq "$(kawa-glass)" off

case_ "restore: mako or bluetoothd never answering — failed, noted; no adapter — kept; a value spoiled by hand — failed"
setup; kawa-state set dnd on; kawa-state set bluetooth on; kawa-state set brightness 170
echo 99 >"$W/mako-late"; : >"$W/bt"
rc 0 kawa-state restore; settle 3
eq "$(rec dnd)" $'failed\ton'; eq "$(rec bluetooth)" $'failed\ton'; eq "$(rec brightness)" $'failed\t170'
setup; rm -rf "$W/sys/class/bluetooth/hci0"; kawa-state set bluetooth off; kawa-state restore; settle 1
eq "$(rec bluetooth)" $'kept\toff'; eq "$(cat "$W/bt")" 'b true' "no adapter: nothing asked"
case_ "a setting the desktop no longer has (cleanmic, the clean mic's): taken out of the store at login, quietly — no record, no failure; the others put back in their places"
setup
rc 0 kawa-state set dnd on; rc 0 kawa-state set cleanmic off; rc 0 kawa-state set brightness 40
rc 0 kawa-state restore; settle 2
for _ in {1..300}; do grep -q '^cleanmic=' "$ST/settings" || break; /bin/sleep 0.02; done
eq "$(kawa-state list)" $'dnd=on\nbrightness=40' "the line gone, the others in their places"
eq "$(rec cleanmic)" "" "no record of it: not ok, not failed, not kept"
lacks "$(cat "$ST/restored")" cleanmic
eq "$(rec dnd)" $'ok\ton'; eq "$(rec brightness)" $'ok\t40'
case_ "…alone in an old store (with its comment): the store keeps the comment, the record says this boot and nothing else"
setup; mkdir -p "$ST"; printf '%s\n' '# ~/.local/state/fedokawaii/settings — what you set on the desktop' 'cleanmic=on' >"$ST/settings"
rc 0 kawa-state restore
for _ in {1..300}; do grep -q '^cleanmic=' "$ST/settings" || break; /bin/sleep 0.02; done
eq "$(kawa-state list)" "" "nothing kept now"; eq "$(head -n1 "$ST/settings")" '# ~/.local/state/fedokawaii/settings — what you set on the desktop (kawa-state; kawa-state --help)'
eq "$(cat "$ST/restored")" "boot boot-1"
case_ "…a hand edit with the key twice: both gone"
setup; mkdir -p "$ST"; printf 'cleanmic=on\nbluetooth=off\ncleanmic=off\n' >"$ST/settings"
rc 0 kawa-state restore; settle 1
for _ in {1..300}; do grep -q '^cleanmic=' "$ST/settings" || break; /bin/sleep 0.02; done
eq "$(kawa-state list)" "bluetooth=off"; eq "$(rec bluetooth)" $'ok\toff'; eq "$(rec cleanmic)" ""

case_ "restore with nothing set: the record says this boot, nothing else"
setup; rc 0 kawa-state restore; eq "$(cat "$ST/restored")" "boot boot-1"

case_ "the theme ships no file where your settings live (apply copies configs/home as it is)"
for p in .local/state .config/fedokawaii/vrr .config/fedokawaii/current .config/fedokawaii/steam-warm; do
  [[ -e $REPO/configs/home/$p ]] && _no "configs/home/$p would be written over yours" || _ok
done
case_ "autostart puts it back before the bar draws"
a=$(grep -n '^kawa-state restore' "$REPO/configs/home/.config/dwl/autostart.sh" | cut -d: -f1)
b=$(grep -n '^keep waybar' "$REPO/configs/home/.config/dwl/autostart.sh" | cut -d: -f1)
[[ -n $a && -n $b ]] && ((a < b)) && _ok || _no "kawa-state restore (line ${a:-none}) must come before waybar (${b:-none})"
done_
