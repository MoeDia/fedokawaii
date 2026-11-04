#!/usr/bin/env bash
# tests/session/test_refresh.sh — kawa-refresh and dwl's half of Super+Ctrl+R (T20r): the key, what dwl clears,
# what the script may touch, and the guard that makes mashing safe. The whole of it on a real dwl:
# tools/regress/refresh.sh (hung programs back, every window where it was, ten presses).
. "$(dirname "$0")/../lib/harness.sh"
REPO=$(cd "$(dirname "$0")/../.." && pwd)
P=$REPO/src/dwl/dwl.patch

case_ "the key: Super+Ctrl+R, dwl's own action, then the script"
grep -q 'MODKEY|CTRL,     XKB_KEY_r,                 refresh,          SHCMD("kawa-refresh")' "$REPO/src/dwl/config.h" && _ok || _no "config.h"
grep -q '^Super+Ctrl+R ' "$REPO/configs/home/.config/fedokawaii/keybinds.txt" && _ok || _no "Super+/ does not list it"

case_ "dwl's half: ghosts, rails, moves and washes gone; colours, pointer, FreeSync, every monitor arranged and drawn whole; the script last"
f=$(sed -n '/^+refresh(const Arg \*arg)$/,/^+}/p' "$P")
for w in 'ghostfree(g);' 'railfree(r);' 'animstop(c);' 'washend(m);' 'loadcolours();' 'cursorload();' 'updatevrr(m);' 'arrange(m);' \
         'wlr_damage_ring_add_whole(&m->scene_output->damage_ring);' 'wlr_output_schedule_frame(m->wlr_output);' 'spawn(arg);'; do
  has "$f" "$w"
done
[[ $(tail -n 3 <<<"$f" | head -n 1) == *'printstatus();'* || $(tail -n 2 <<<"$f" | head -n 1) == *'spawn(arg);'* ]] && _ok || _no "the script is not last"

case_ "what the script may touch: never a terminal server, the sound, a window of yours; never SIGUSR2 to the bar"
s=$(grep -v '^ *#' "$REPO/bin/kawa-refresh")
lacks "$s" "foot"; lacks "$s" "pipewire"; lacks "$s" "wireplumber"; lacks "$s" "USR2"; lacks "$s" "pkill"

case_ "what it starts does not keep its lock (fd 9): a bar started here would hold it for good, every later press a no-op"
[[ $(grep -c 'setsid -f' <<<"$s") == "$(grep -c 'setsid -f.* 9>&-' <<<"$s")" ]] && _ok || _no "$(grep 'setsid -f' <<<"$s")"

sandbox
export XDG_RUNTIME_DIR=$TMP/run; mkdir -p "$XDG_RUNTIME_DIR"
stub kawa-display; stub notify-send; stub makoctl; stub pgrep; stub systemctl; stub setsid

case_ "misuse: exit 2; --help: its own words"
rc 2 kawa-refresh bogus
has "$(kawa-refresh --help)" "Super+Ctrl+R"

case_ "pressed again within 15 s: nothing is touched"
date +%s >"$XDG_RUNTIME_DIR/kawa-refresh.last"
reset_calls; kawa-refresh; eq "$?" 0
[[ ! -s $CALLS ]] && _ok || _no "called: $(cat "$CALLS")"

case_ "another one running: this one leaves at once"
rm -f "$XDG_RUNTIME_DIR/kawa-refresh.last"; exec 8>"$XDG_RUNTIME_DIR/kawa-refresh.lock"; flock 8
reset_calls; kawa-refresh; eq "$?" 0
[[ ! -s $CALLS ]] && _ok || _no "called: $(cat "$CALLS")"
flock -u 8; exec 8>&-

done_
