#!/usr/bin/env bash
# tests/menus/test_hotkeys.sh — every key that opens something toggles it, however fast it is
# pressed: N presses 30 ms apart (faster than anything they open comes up) leave it open after
# an odd N, closed after an even one — no window stuck, none twice, no press lost. Each key's
# command is read from config.h and run as dwl runs it (sh -c, a session of its own), on the
# real scripts: the popups' terminal windows (kawa-term --float; footclient a stand-in whose
# window is a process), quick settings, the sound panel and every panel menu (the real
# kawa-panel's decisions, headless_panel.py, behind its real fifo), the launcher (fuzzel a
# stand-in) and the region picker (slurp a stand-in). And every key config.h binds is one of
# these, or named here as not opening anything to toggle (a new key must say which it is).
. "$(dirname "$0")/../lib/harness.sh"
command -v python3 >/dev/null || { echo "test_hotkeys: skipped — needs python3"; exit 0; }
D=$(cd "$(dirname "$0")" && pwd)
nap() { sleep "$1"; }
CH=$REPO/src/dwl/config.h

# KEY → what it opens: float (a popup terminal window), panel (quick settings, the sound panel,
# a panel menu), launcher, picker
declare -A TOGGLE=(
  [Super+x]=panel [Super+a]=panel [Super+c]=panel [Super+slash]=panel [Super+Shift+e]=panel
  [Super+Shift+u]=panel [Super+d]=panel [Super+space]=launcher
  [Super+v]=float [Super+r]=float [Super+n]=float [Super+w]=float [Super+u]=float
  [Print]=picker [Super+Print]=picker [Super+Shift+Print]=picker
)
# keys that open nothing to toggle: each press its own new window, or an action
NOT_TOGGLES=" Super+Return Super+b Super+e Super+Shift+w Super+Shift+n Super+Escape XF86Sleep
  XF86Suspend Shift+Print XF86AudioMute XF86AudioMicMute XF86AudioPlay XF86AudioNext
  XF86AudioPrev Super+Ctrl+Shift+q Super+z Super+Shift+r "
# Super+d: File tools' menu, on a PDF copied (a stand-in clipboard below; the rest: test_file).
# Super+z: a menu only when a picture was copied (test_shrink); Super+Shift+r: a recording's own
# start and stop (test_record). The held keys that repeat:
HELD=" XF86AudioRaiseVolume XF86AudioLowerVolume XF86MonBrightnessUp XF86MonBrightnessDown
  Super+bracketright Super+bracketleft "

HELD=" ${HELD//$'\n'/ } " NOT_TOGGLES=" ${NOT_TOGGLES//$'\n'/ } "   # (one line each: a key between spaces)

# every spawn binding of config.h: "FUNC<TAB>KEY<TAB>COMMAND" (KEY as Super+Shift+x)
bindings() {
  python3 -I - "$CH" <<'EOF'
import re, sys
t = open(sys.argv[1]).read()
cmds = {m.group(1): " ".join(re.findall(r'"([^"]*)"', m.group(2)))
        for m in re.finditer(r"static const char \*(\w+)\[\]\s*=\s*\{(.*?)\};", t)}
keys = t[t.index("static const Key keys[]"):]
keys = keys[:keys.index("};")]
for m in re.finditer(r'\{\s*([\w|]+),\s*XKB_KEY_(\w+),\s*(spawn\w*),\s*(SHCMD\("(.*)"\)|\{\s*\.v\s*=\s*(\w+)\s*\})\s*\}', keys):
    mods = [] if m.group(1) == "0" else m.group(1).split("|")
    name = "+".join({"MODKEY": "Super", "SHIFT": "Shift", "CTRL": "Ctrl"}[x] for x in mods)
    cmd = m.group(5).replace('\\"', '"') if m.group(5) is not None else cmds[m.group(6)]
    print(f"{m.group(3)}\t{name + '+' if name else ''}{m.group(2)}\t{cmd}")
EOF
}

case_ "every key config.h binds is a toggle here, or named as none; only the volume and the brightness repeat while held"
n=0
while IFS=$'\t' read -r f k c; do
  n=$((n + 1))
  if [[ $f == spawnheld ]]; then [[ $HELD == *" $k "* ]] && _ok || _no "$k repeats while held ($c)"; continue; fi
  [[ -n ${TOGGLE[$k]:-} || $NOT_TOGGLES == *" $k "* ]] && _ok || _no "$k ($c): neither a toggle here nor named as none"
  [[ $HELD == *" $k "* ]] && _no "$k should repeat while held, but is $f"
done < <(bindings)
((n > 30)) && _ok || _no "only $n bindings read from config.h"

# ── the stand-ins ─────────────────────────────────────────────────────────────────────────
setup() {
  sandbox; config .config/fedokawaii
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
  ln -s "$REPO/system/fedokawaii" "$STUBS/fedokawaii"
  W=$TMP/windows; mkdir -p "$W"
  # a terminal window: a process while it is open; footclient told to end (TERM) ends it
  stub footclient 'echo $$ >"'"$W"'/$$"; exec /bin/sleep 300'
  stub kawa-dwlstatus
  stub notify-send
  # the launcher: a fuzzel that stays on screen (its own name, as kawa-menu checks), and takes
  # fuzzel's lock as the real one does
  printf '#!/bin/bash\nexec 8>>"$XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock"; flock -n 8 || exit 1\necho $$ >"%s/fz.$$"\ntrap "exit 1" TERM\nwhile :; do /bin/sleep 0.2 8>&- & wait $!; done\n' "$W" >"$STUBS/fuzzel"
  chmod 755 "$STUBS/fuzzel"
  # the region picker: on screen until it is ended
  printf '#!/bin/bash\necho $$ >"%s/slurp.$$"\nexec /bin/sleep 300\n' "$W" >"$STUBS/slurp"; chmod 755 "$STUBS/slurp"
  export WAYLAND_DISPLAY=wayland-test
  # the session's panel, headless (gi stood in for: nothing is drawn)
  G=$TMP/gi; mkdir -p "$G/gi/repository"
  echo 'def require_version(*a): pass' >"$G/gi/__init__.py"
  cat >"$G/gi/repository/__init__.py" <<'EOF'
class _Any:
    def __init__(self, *a, **k): pass
    def __call__(self, *a, **k): return _Any()
    def __getattr__(self, n): return _Any()
Gtk = Gdk = Gio = GLib = GLibUnix = GtkLayerShell = Pango = PangoCairo = _Any()
EOF
  python3 -I "$D/headless_panel.py" "$REPO/bin/kawa-panel" "$G" </dev/null >"$TMP/panel.log" 2>&1 & PANEL=$!
  on_exit "kill $PANEL 2>/dev/null"
  local i; for ((i = 0; i < 200; i++)); do [[ -p $XDG_RUNTIME_DIR/kawa-panel.in && -s $XDG_RUNTIME_DIR/kawa-panel.pid ]] && break; nap 0.02; done
}
live() {   # live PREFIX — how many of the stand-ins' windows named PREFIX* are up
  local f p n=0
  for f in "$W"/$1*; do [[ -e $f ]] || continue; read -r p <"$f" && kill -0 "$p" 2>/dev/null && n=$((n + 1)); done
  echo "$n"
}
state() {   # state KIND — 1 open, 0 closed (2+: more than one window)
  case $1 in
    float)    live "[0-9]" ;;
    panel)    local s=0; read -r s _ <"$XDG_RUNTIME_DIR/panel.state"; echo "$s" ;;
    launcher) live fz. ;;
    picker)   live slurp. ;;
  esac
}
press() { setsid -f /bin/sh -c "$1" </dev/null >/dev/null 2>&1; }   # (as dwl spawns it)
settle() {   # settle KIND WANT — the state once it stops changing (WANT reached, or 5 s)
  local i s
  for ((i = 0; i < 100; i++)); do s=$(state "$1"); [[ $s == "$2" ]] && { nap 0.3; state "$1"; return; }; nap 0.05; done
  echo "$s"
}

# ── each toggle, pressed fast ─────────────────────────────────────────────────────────────
declare -A CMD=()
while IFS=$'\t' read -r _ k c; do CMD[$k]=$c; done < <(bindings)
for k in ${HOTKEYS:-Super+x Super+a Super+c Super+slash Super+Shift+e Super+Shift+u Super+d Super+space \
         Super+v Super+r Super+n Super+w Super+u Print Super+Print Super+Shift+Print}; do
  kind=${TOGGLE[$k]} cmd=${CMD[$k]:-}
  case_ "$k ($cmd, $kind): pressed fast, every press counts — open after an odd number of presses, closed after an even one"
  [[ -n $cmd ]] || { _no "not in config.h"; continue; }
  setup; got=""
  if [[ $k == Super+d ]]; then   # (a PDF copied in yazi: its file:// link on the clipboard)
    printf '%%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n' >"$TMP/a.pdf"
    stub wl-paste 'case "$1" in --list-types) echo text/uri-list ;; *) printf "file://%s\r\n" "$TMP/a.pdf" ;; esac'
  fi
  for n in 1 2 3 4; do
    for ((i = 0; i < n; i++)); do press "$cmd"; nap 0.03; done
    s=$(settle "$kind" $((n % 2)))
    got+="$n:$s "
    if ((s > 0)); then press "$cmd"; settle "$kind" 0 >/dev/null; fi   # (closed again, by its key)
  done
  eq "$got" "1:1 2:0 3:1 4:0 "   # (presses:windows open)
  for f in "$W"/[0-9]* "$W"/fz.* "$W"/slurp.*; do [[ -e $f ]] && read -r p <"$f" && kill "$p" 2>/dev/null; done
  kill "$PANEL" 2>/dev/null; wait "$PANEL" 2>/dev/null
done

done_
