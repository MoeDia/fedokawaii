# tools/kit-play.sh — the words a kit play (tools/kit.sh --play FILE) is written in: sourced
# inside the kit's headless dwl, before FILE. A play drives the desktop as a person does —
# the pointer through wlroots' virtual pointer (wlrctl), the keys through wtype's virtual
# keyboard — and shoots what the screen shows at each step, into the kit's OUT folder.
#   at X Y        the pointer to X Y (screen pixels, absolute: to the corner first, then there)
#   by DX DY      the pointer moved by DX DY
#   click [BTN]   a click (left, right or middle; default left)
#   key KEY…      each key pressed and let go (wtype's names: Down, Return, Escape, Tab …)
#   chord MOD KEY  KEY with MOD held (logo, shift, ctrl, alt): dwl's own keys — chord logo u
#   text TEXT     the text typed
#   shot NAME [X,Y WxH]   the screen (or that part of it) → OUT/NAME.png
#   nap S         S seconds of nothing
#   panel         kawa-panel started, hidden, as autostart starts it (the menus and quick
#                 settings answer through it); waits until its fifo is there (3 s at most)
#   warm          the warm windows started put away, as autostart starts them (Super+U, N, V)
#   say WORDS     a line in OUT/play.log (what the play saw: a file's state, a count …)
# shellcheck shell=bash
at()    { wlrctl pointer move -8000 -8000 && wlrctl pointer move "$1" "$2"; sleep 0.05; }
by()    { wlrctl pointer move "$1" "$2"; sleep 0.05; }
click() { wlrctl pointer click "${1:-left}"; sleep 0.05; }
key()   { local k; for k; do wtype -s 300 -k "$k"; sleep 0.05; done; }   # (-s: the virtual keyboard there before its key)
text()  { wtype -s 300 -- "$1"; }
chord() { wtype -s 300 -M "$1" -k "$2" -m "$1"; sleep 0.05; }
warm()  { kawa-warm --start >/dev/null 2>&1 & sleep 1.5; }
shot()  { if (($# > 1)); then grim -g "${*:2}" "$KIT_OUT/$1.png"; else grim "$KIT_OUT/$1.png"; fi; }
nap()   { sleep "$1"; }
say()   { printf '%s\n' "$*" >>"$KIT_OUT/play.log"; }
panel() {
  kawa-panel >/dev/null 2>>"$KIT_OUT/panel.log" &   # (what it says wrong: beside the shots)
  local _; for _ in $(seq 60); do [[ -p $XDG_RUNTIME_DIR/kawa-panel.in ]] && return 0; sleep 0.05; done
  say "panel: no fifo after 3 s"; return 1
}
