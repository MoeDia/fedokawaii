#!/usr/bin/env bash
# tests/look/test_units.sh — the session's systemd user units (the dwl session target, the
# update season's reminder and its timer, the screen-sharing portal's drop-in) and the
# configs around them: the portal's own config, foot.ini and satty's config.toml.
# systemd-analyze, foot and python's TOML reader check them when this machine has them;
# what the units and configs would run is run here against stand-ins.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need python3
UNITS=$REPO/configs/home/.config/systemd/user

key() {   # key FILE KEY — every value of KEY= in a unit or ini file (one per line)
  sed -n "s/^$2=//p" "$1"
}
run_unit_cmd() {   # run_unit_cmd LINE — a unit's command line as systemd runs it: the "-"
  # prefix dropped, %h and %U filled in after the line is split into words (as systemd does)
  python3 -I - "$1" "$HOME" "$UID" <<'EOF' >"$TMP/argv0"
import shlex, sys, os
line, home, uid = sys.argv[1:]
line = line[1:] if line.startswith("-") else line
words = [w.replace("%h", home).replace("%U", uid) for w in shlex.split(line)]
sys.stdout.write("\0".join(words))
EOF
  local w=(); mapfile -d '' -t w <"$TMP/argv0"
  "${w[@]}"
}

# ── systemd's own check ─────────────────────────────────────────────────────
case_ "systemd-analyze verify: the units and the drop-in load cleanly (beside stand-in targets)"
look
if command -v systemd-analyze >/dev/null; then
  U=$TMP/units; mkdir -p "$U"
  cp "$UNITS"/*.target "$UNITS"/*.service "$UNITS"/*.timer "$U"/
  cp -r "$UNITS/xdg-desktop-portal-wlr.service.d" "$U"/
  for t in basic default sockets timers paths shutdown exit; do printf '[Unit]\nDescription=%s\n' "$t" >"$U/$t.target"; done
  for t in graphical-session graphical-session-pre; do
    printf '[Unit]\nDescription=%s\nRefuseManualStart=yes\nStopWhenUnneeded=yes\n' "$t" >"$U/$t.target"
  done
  printf '[Socket]\nListenStream=%%t/bus\n' >"$U/dbus.socket"
  # the portal's unit as xdg-desktop-portal-wlr 0.8 ships it (Fedora takes upstream's)
  cat >"$U/xdg-desktop-portal-wlr.service" <<'EOF'
[Unit]
Description=Portal service (wlroots implementation)
PartOf=graphical-session.target
After=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
Type=dbus
BusName=org.freedesktop.impl.portal.desktop.wlr
ExecStart=/bin/true
Restart=on-failure
EOF
  out=$(cd "$U" && SYSTEMD_UNIT_PATH=$U systemd-analyze verify --user --man=no \
          fedokawaii-remind.timer fedokawaii-remind.service dwl-session.target xdg-desktop-portal-wlr.service 2>&1)
  # only what it says about these units counts (as a normal user it also reports what it cannot
  # open on this machine); the engine itself is installed by setup.sh, so it may not be here
  out=$(grep -E "fedokawaii-remind|dwl-session|xdg-desktop-portal-wlr|sharing\.conf|graphical-session" <<<"$out" \
        | grep -v 'Command /usr/local/bin/fedokawaii is not executable')
  eq "$out" "" "systemd-analyze has no complaint"
  # and the drop-in really is read: a broken copy of it is noticed
  echo "Bogus=1" >>"$U/xdg-desktop-portal-wlr.service.d/sharing.conf"
  out=$(cd "$U" && SYSTEMD_UNIT_PATH=$U systemd-analyze verify --user --man=no xdg-desktop-portal-wlr.service 2>&1)
  has "$out" "sharing.conf" "(the check reads the drop-in)"
else
  echo "  (skipped: no systemd-analyze here — the checks below still read the units)"
fi

# ── the update season's reminder ─────────────────────────────────────────────
case_ "the reminder: the timer exists, starts its own service, which runs the engine's quiet check"
[[ -f $UNITS/fedokawaii-remind.timer && -f $UNITS/fedokawaii-remind.service ]] && _ok || _no "a unit is missing"
eq "$(key "$UNITS/fedokawaii-remind.timer" Unit)" "" "no Unit=: it starts fedokawaii-remind.service, beside it"
eq "$(key "$UNITS/fedokawaii-remind.timer" OnActiveSec)" 2min
eq "$(key "$UNITS/fedokawaii-remind.timer" OnUnitActiveSec)" 6h
eq "$(key "$UNITS/fedokawaii-remind.timer" PartOf)" dwl-session.target "it stops with the session"
eq "$(key "$UNITS/fedokawaii-remind.service" Type)" oneshot
eq "$(key "$UNITS/fedokawaii-remind.service" ExecStart)" "/usr/local/bin/fedokawaii remind quiet"
grep -q 'install -m 0755 "$TOOLKIT/system/fedokawaii" /usr/local/bin/fedokawaii' "$REPO/setup.sh" \
  && _ok || _no "setup.sh no longer installs the engine at /usr/local/bin/fedokawaii"
grep -A12 '^  remind)' "$REPO/system/fedokawaii" | grep -q '^ *quiet) *remind ;;' \
  && _ok || _no "the engine has no 'remind quiet'"
grep -q '^systemctl --user start fedokawaii-remind.timer' "$REPO/configs/home/.config/dwl/autostart.sh" \
  && _ok || _no "autostart.sh does not start the timer"

case_ "the session target: bound to graphical-session.target, started at login, stopped at logout"
eq "$(key "$UNITS/dwl-session.target" BindsTo)" graphical-session.target
grep -q '^systemctl --user start dwl-session.target' "$REPO/configs/home/.config/dwl/autostart.sh" && _ok || _no "not started at login"
grep -q '^systemctl --user stop dwl-session.target' "$REPO/system/start-dwl" && _ok || _no "not stopped at logout"

# ── screen sharing: the portal's config and the drop-in ──────────────────────
setup() {
  look
  config .config/xdg-desktop-portal-wlr/config
  P=$HOME/.config/xdg-desktop-portal-wlr/config
  argv makoctl
  argv kawa-dwlstatus; cp "$STUBS/kawa-dwlstatus" "$HOME/.local/bin/kawa-dwlstatus"
}
setup
case_ "the portal's config: keys xdpw 0.8 knows; the chooser is the desktop's own helper"
bad=$(sed -n 's/^\([a-z_]*\)=.*/\1/p' "$P" | grep -vxE 'output_name|max_fps|chooser_cmd|chooser_type|exec_before|exec_after|force_mod_linear')
eq "$bad" "" "unknown keys"
eq "$(key "$P" chooser_type)" dmenu
eq "$(key "$P" chooser_cmd)" "$HOME/.local/bin/kawa-share" "a full path (the portal's PATH has no ~/.local/bin)"
[[ -x $REPO/bin/kawa-share ]] && _ok || _no "no bin/kawa-share to install there"

case_ "a share starting and ending: mako's sharing mode on, then off, the bar poked each time"
sh -c "$(key "$P" exec_before)"
args_eq makoctl 1 mode -a sharing
args_eq kawa-dwlstatus 1 --poke 12
sh -c "$(key "$P" exec_after)"
args_eq makoctl 2 mode -r sharing
args_eq kawa-dwlstatus 2 --poke 12

case_ "the mode and the poke land: mako knows [mode=sharing], waybar's 共有 seal listens on 12"
grep -q '^\[mode=sharing\]' "$REPO/configs/home/.config/mako/config" && _ok || _no "mako has no sharing mode"
python3 -I - "$REPO/configs/home/.config/waybar/config.jsonc" <<'EOF' && _ok || _no "waybar's custom/mode does not show sharing on signal 12"
import json, re, sys
text = re.sub(r"^\s*//.*$", "", open(sys.argv[1]).read(), flags=re.M)
mode = json.loads(text)["custom/mode"]
sys.exit(0 if mode["signal"] == 12 and "sharing" in mode["exec"] else 1)
EOF

case_ "the portal crashing mid-share (mako running): the drop-in clears the sharing mode and pokes the bar"
setup
D=$UNITS/xdg-desktop-portal-wlr.service.d/sharing.conf
eq "$(sed -n '/^\[/p' "$D")" "[Service]" "one section: [Service]"
mapfile -t posts < <(key "$D" ExecStopPost)
((${#posts[@]} == 2)) && _ok || _no "two ExecStopPost lines expected, found ${#posts[@]}"
for l in "${posts[@]}"; do [[ $l == -* ]] && _ok || _no "not optional ('-'): $l — a failure would mark the portal failed"; done
daemon mako >/dev/null
for l in "${posts[@]}"; do run_unit_cmd "$l"; done
args_eq makoctl 1 mode -r sharing
args_eq kawa-dwlstatus 1 --poke 12

case_ "the portal stopped at logout (mako already gone): mako is not started again just to clear a mode"
setup
for l in "${posts[@]}"; do run_unit_cmd "$l"; done
eq "$(ncalls makoctl)" 0 "makoctl would start mako by D-Bus activation"
args_eq kawa-dwlstatus 1 --poke 12

case_ "a home folder with a space: the poke still reaches kawa-dwlstatus"
setup
mkdir -p "$TMP/my home/.local/bin"; cp "$STUBS/kawa-dwlstatus" "$TMP/my home/.local/bin/"; export HOME="$TMP/my home"
for l in "${posts[@]}"; do run_unit_cmd "$l"; done
args_eq kawa-dwlstatus 1 --poke 12

# ── foot ─────────────────────────────────────────────────────────────────────
case_ "foot.ini: foot itself accepts it, in both themes (and the palettes it switches between)"
FOOT=""
for f in /opt/f44/bin/foot "$(command -v foot)"; do
  [[ -x $f ]] || continue
  v=$(LD_LIBRARY_PATH=/opt/f44/lib "$f" --version 2>/dev/null | sed -n 's/^foot version: \([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
  read -r ma mi <<<"$v"; [[ -n $ma ]] && ((ma > 1 || mi >= 24)) && { FOOT=$f; break; }
done
look; config .config/foot/foot.ini
if [[ -n $FOOT ]]; then
  for m in dark light; do
    ln -sfn "themes/$m" "$HOME/.config/fedokawaii/current"
    out=$(LD_LIBRARY_PATH=/opt/f44/lib "$FOOT" --check-config 2>&1); r=$?
    eq "$r" 0 "$m: $(grep -v 'not a UTF-8 locale' <<<"$out" | head -n 3)"
  done
else
  echo "  (skipped foot --check-config: no foot ≥ 1.24 here)"
fi
eq "$(key "$HOME/.config/foot/foot.ini" include)" "~""/.config/fedokawaii/current/foot.ini" "the theme's include (foot expands the ~)"
for m in dark light; do
  eq "$(key "$REPO/configs/home/.config/fedokawaii/themes/$m/foot.ini" initial-color-theme)" "$m"
done
for s in colors-dark colors-light; do
  n=$(awk -v s="[$s]" '$0 == s { on = 1; next } /^\[/ { on = 0 } on && /^(regular|bright)[0-7]=/' "$HOME/.config/foot/foot.ini" | wc -l)
  eq "$n" 16 "[$s]: all 16 colours"
done

# ── satty ────────────────────────────────────────────────────────────────────
case_ "satty's config: valid TOML, only keys satty 0.22 knows, Enter copies, Esc closes"
python3 -I - "$REPO/configs/home/.config/satty/config.toml" <<'EOF' >"$TMP/satty.out" 2>&1
import sys
try:
    import tomllib
except ImportError:
    print("SKIP"); sys.exit(0)
c = tomllib.load(open(sys.argv[1], "rb"))
# (satty 0.22's own names, as its release binary lists them: ConfigurationFile and its parts)
known = {
    "general": {"fullscreen", "resize", "floating-hack", "early-exit", "corner-roundness", "initial-tool",
                "copy-command", "annotation-size-factor", "save-after-copy", "auto-copy", "output-filename",
                "actions-on-enter", "actions-on-escape", "actions-on-right-click", "default-hide-toolbars",
                "focus-toggles-toolbars", "default-fill-shapes", "default-round-caps", "primary-highlighter",
                "disable-notifications", "no-window-decoration", "brush-smooth-history-size", "zoom-factor",
                "pan-step-size", "text-move-length", "input-scale", "title", "app-id", "notification-thumbnail",
                "action-on-enter", "right-click-copy"},
    "font": {"family", "style", "fallback"},
    "color-palette": {"palette", "custom"},
    "keybinds": None,
}
bad = [f"[{s}]" for s in c if s not in known]
bad += [f"{s}.{k}" for s, v in c.items() if known.get(s) for k in v if k not in known[s]]
print(" ".join(bad) if bad else "OK")
g = c["general"]
print(g["actions-on-enter"], g["actions-on-escape"], g["copy-command"], g["early-exit"])
EOF
if [[ $(head -n1 "$TMP/satty.out") == SKIP ]]; then echo "  (skipped: python has no tomllib)"
else
  eq "$(head -n1 "$TMP/satty.out")" OK "unknown keys"
  eq "$(sed -n 2p "$TMP/satty.out")" "['save-to-clipboard'] ['exit'] wl-copy ['all']"
fi

done_
