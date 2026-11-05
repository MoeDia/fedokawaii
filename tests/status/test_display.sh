#!/usr/bin/env bash
# tests/status/test_display.sh — kawa-display: every monitor at its preferred resolution and the
# highest refresh rate up to MONITOR_HZ; --hotplug (a monitor came) also draws the wallpaper
# again and drops the brightness keys' bus list, with simultaneous calls collapsed. wlr-randr is
# fake_randr.py replaying real EDID mode lists (fixtures/randr, from the display review's kit,
# review12/B) with wlr-randr's own exact refresh matching.
. "$(dirname "$0")/lib.sh"
FX=$SD/fixtures/randr
setup() {
  box; export FAKE_RANDR=$TMP/randr.json
  stub wlr-randr 'exec python3 -I '"$SD"'/fake_randr.py "$@"'
  stub kawa-wallpaper; stub sleep
}
world() { cp "$FX/$1.json" "$FAKE_RANDR"; : >"$FAKE_RANDR.log"; }   # world NAME — a fixture's monitors
hz() { sed -i "s/^MONITOR_HZ=.*/MONITOR_HZ=$1/" "$HOME/.config/fedokawaii/env"; }
sets() { cat "$FAKE_RANDR.log"; }                    # what was applied: "SET OUTPUT WxH@mHz"
current() {   # current — each enabled output's mode now, "NAME WxH@mHz"
  python3 -I -c '
import json, sys
for h in json.load(open(sys.argv[1])):
    if h.get("enabled", True) and h.get("current") is not None:
        w, ht, r = h["modes"][h["current"]]; print(h["name"], f"{w}x{ht}@{r}")' "$FAKE_RANDR"
}

# ── the mode for every monitor in the kit (MONITOR_HZ=144) ───────────────────
case_ "1440p 165 Hz monitor (preferred 59.951): 2560x1440 at 143.973 — the best not above 144"
setup; world 1440p165; rc 0 kawa-display
eq "$(sets)" "SET DP-1 2560x1440@143973"
case_ "1080p 144 Hz monitor (144.001 Hz, a hair above 144): taken"
setup; world 1080p144; kawa-display
eq "$(sets)" "SET DP-2 1920x1080@144001"
case_ "240 Hz monitor (preferred 239.76, 280 overclock): 143.855"
setup; world g240; kawa-display
eq "$(sets)" "SET DP-4 1920x1080@143855"
case_ "4K TV (4096x2160 bigger than its preferred 3840x2160): the preferred, already at 60 — left alone"
setup; world tv4k; kawa-display
eq "$(sets)" ""; eq "$(current)" "HDMI-A-1 3840x2160@60000"
case_ "no EDID, no preferred mode: the biggest one (1024x768), already set — left alone"
setup; world noedid; kawa-display; eq "$(sets)" ""
case_ "a laptop panel (60.010 Hz): left alone"
setup; world edp; kawa-display; eq "$(sets)" ""
case_ "two monitors: each its own best"
setup; world two; kawa-display
eq "$(sets)" $'SET DP-1 2560x1440@143973\nSET DP-2 1920x1080@144001'
case_ "a disabled output (switched off): untouched"
setup; world off; kawa-display
eq "$(sets)" "SET DP-2 1920x1080@144001"
case_ "three monitors (1440p, 4K TV, one without EDID)"
setup; world three; kawa-display
eq "$(sets)" "SET DP-1 2560x1440@143973"
eq "$(current)" $'DP-1 2560x1440@143973\nHDMI-A-1 3840x2160@60000\nDP-3 1024x768@60004'
case_ "run again: everything is already there — nothing set, no flicker"
: >"$FAKE_RANDR.log"; kawa-display; eq "$(sets)" ""
case_ "wlr-randr's exact matching: every refresh handed to it round-trips (never 'unknown mode')"
for w in 1440p165 g240; do setup; world "$w"; kawa-display; lacks "$(sets)" FAIL "$w"; done

# ── MONITOR_HZ ───────────────────────────────────────────────────────────────
case_ "MONITOR_HZ at its edges and in between (fedokawaii.conf allows 30–540)"
for t in "30 tv4k HDMI-A-1 3840x2160@30000" "30 1080p144 -" "59 1440p165 -" "60 1440p165 -" \
         "60 g240 DP-4 1920x1080@60000" "75 1080p144 DP-2 1920x1080@74973" "120 1440p165 DP-1 2560x1440@119998" \
         "143 1080p144 DP-2 1920x1080@119982" "165 1440p165 DP-1 2560x1440@165080" "240 g240 -" \
         "280 g240 DP-4 1920x1080@280000" "540 g240 DP-4 1920x1080@280000"; do
  read -r h w o m <<<"$t"
  setup; world "$w"; hz "$h"; kawa-display
  if [[ $o == - ]]; then eq "$(sets)" "" "MONITOR_HZ=$h on $w: nothing to change"
  else eq "$(sets)" "SET $o $m" "MONITOR_HZ=$h on $w"; fi
done
case_ "MONITOR_HZ missing or not a number (an env from an older install, a typo): 144"
for h in '' abc 144Hz '$(id)'; do
  setup; world 1440p165; hz "'$h'"; kawa-display 2>/dev/null
  eq "$(sets)" "SET DP-1 2560x1440@143973" "MONITOR_HZ=[$h]"
done
setup; world 1440p165; sed -i '/^MONITOR_HZ=/d' "$HOME/.config/fedokawaii/env"; kawa-display
eq "$(sets)" "SET DP-1 2560x1440@143973" "no MONITOR_HZ line"

case_ "a mode with no refresh rate (a custom mode): skipped, nothing breaks"
setup
printf '%s\n' '[{"name": "Virtual-1", "desc": "virt", "modes": [[1920, 1080, 0], [1280, 720, 60000]], "preferred": 0, "current": 1}]' >"$FAKE_RANDR"
rc 0 kawa-display; eq "$(sets)" ""
case_ "Turkish and German locales (a decimal comma): the same modes"
for loc in tr_TR.UTF-8 de_DE.UTF-8; do
  setup; world two
  locale_ok "$loc" || { skip "no $loc here"; continue; }
  LC_ALL=$loc kawa-display 2>/dev/null
  eq "$(sets)" $'SET DP-1 2560x1440@143973\nSET DP-2 1920x1080@144001' "$loc"
done

case_ "no compositor to talk to (wlr-randr fails): could not (1), nothing set"
setup; world two; FAKE_RANDR_FAIL=1 rc 1 kawa-display
case_ "a mode refused: could not (1), the other monitor still set"
setup; world two
stub wlr-randr 'case "$*" in *DP-1*) echo "unknown mode" >&2; exit 1 ;; esac; exec python3 -I '"$SD"'/fake_randr.py "$@"'
rc 1 kawa-display; eq "$(sets)" "SET DP-2 1920x1080@144001"

# ── --hotplug ────────────────────────────────────────────────────────────────
case_ "--hotplug: the modes, the brightness bus list dropped, the wallpaper drawn again"
setup; world 1080p144; echo 5 >"$XDG_RUNTIME_DIR/kawa-ddc-buses"
rc 0 kawa-display --hotplug
eq "$(sets)" "SET DP-2 1920x1080@144001"
[[ ! -e $XDG_RUNTIME_DIR/kawa-ddc-buses ]] && _ok || _no "the bus list is still there"
called 'kawa-wallpaper --restore'; called '^sleep 1$'
[[ ! -e $XDG_RUNTIME_DIR/kawa-display.again ]] && _ok || _no "the mark was left behind"

# hold — the next run of kawa-display --hotplug stops inside wlr-randr until "release"
hold() {
  : >"$TMP/hold"
  stub wlr-randr '[ $# = 0 ] && while [ -e "$TMP/hold" ]; do /bin/sleep 0.02; done
exec python3 -I '"$SD"'/fake_randr.py "$@"'
  export TMP
}
release() { rm -f "$TMP/hold"; }
runs() { grep -c 'kawa-wallpaper' "$CALLS"; }
case_ "monitors waking together (4 calls at once): the first does the work, then once more for the rest"
setup; world two; hold
kawa-display --hotplug & first=$!
waitfor 5 grep -q '^wlr-randr $' "$CALLS"
s=$EPOCHREALTIME
for _ in 1 2 3; do rc 0 timeout 5 kawa-display --hotplug; done
t=$(( ${EPOCHREALTIME/./} - ${s/./} ))
((t < 1500000)) && _ok || _no "the calls waiting on the first took $t µs"
[[ -e $XDG_RUNTIME_DIR/kawa-display.again ]] && _ok || _no "no mark left for the first to see"
release; wait "$first"
eq "$(runs)" 2 "two runs for four calls"
[[ ! -e $XDG_RUNTIME_DIR/kawa-display.again ]] && _ok || _no "a mark was left behind"

case_ "a call while the lock is held elsewhere: returns at once, leaving the mark"
setup; world two
exec {held}>"$XDG_RUNTIME_DIR/kawa-display.lock"; flock "$held"
rc 0 timeout 5 kawa-display --hotplug                   # (one that waited for the lock would hang)
[[ -e $XDG_RUNTIME_DIR/kawa-display.again ]] && _ok || _no "no mark"
eq "$(runs)" 0
exec {held}>&-
case_ "… the next call after that one ends does the work, and clears the mark"
rc 0 kawa-display --hotplug; eq "$(runs)" 1
[[ ! -e $XDG_RUNTIME_DIR/kawa-display.again ]] && _ok || _no "the mark stayed"

case_ "a mark and a lock file left by a run that was killed: the next call works, once"
setup; world two; : >"$XDG_RUNTIME_DIR/kawa-display.again"; : >"$XDG_RUNTIME_DIR/kawa-display.lock"
rc 0 kawa-display --hotplug; eq "$(runs)" 1
[[ ! -e $XDG_RUNTIME_DIR/kawa-display.again ]] && _ok || _no "the mark stayed"

case_ "many calls at odd moments (a flaky cable): none is lost — the last one's request is always served"
setup; world two
stub kawa-wallpaper 'echo "run $(date +%s%N)" >>"$TMP/order"'
stub wlr-randr '/bin/sleep 0.05; exec python3 -I '"$SD"'/fake_randr.py "$@"'
export TMP
for _ in {1..12}; do
  { echo "req $(date +%s%N)" >>"$TMP/order"; kawa-display --hotplug; } &
  /bin/sleep "0.0$((RANDOM % 9))"
done
wait
lr=$(grep '^req' "$TMP/order" | sort -k2n | tail -n 1 | cut -d' ' -f2)
lw=$(grep '^run' "$TMP/order" | sort -k2n | tail -n 1 | cut -d' ' -f2)
((lw > lr)) && _ok || _no "the last request ($lr) came after the last run's wallpaper ($lw)"
[[ ! -e $XDG_RUNTIME_DIR/kawa-display.again ]] && _ok || _no "a mark was left behind"
(( $(runs) < 12 )) && _ok || _no "$(runs) runs for 12 calls: nothing collapsed"

case_ "--hotplug without XDG_RUNTIME_DIR: could not (1); plain kawa-display does not need it"
setup; world two
( unset XDG_RUNTIME_DIR; kawa-display --hotplug ) 2>/dev/null; eq "$?" 1
( unset XDG_RUNTIME_DIR; kawa-display ) 2>/dev/null; eq "$?" 0

# ── misuse ───────────────────────────────────────────────────────────────────
case_ "--help (0); an unknown option (2) — nothing set"
setup; world two
out=$(kawa-display --help); r=$?; eq "$r" 0; has "$out" "kawa-display --hotplug"
rc 2 kawa-display --hotplugg
rc 2 kawa-display 144
eq "$(sets)" ""

# ── the monitor's own menu ──────────────────────────────────────────────────
# lg BUS — a monitor on a DRM connector with this EDID head (GSM, product 0x5CDD), and the conf
lg() {
  setup; export DDC=$TMP/ddc KAWA_SYSFS=$TMP/sys DDC_BUSES=$1; mkdir -p "$DDC"
  stub ddcutil 'exec bash '"$SD"'/fake_ddcutil "$@"'; stub logger; stub kawa-brightness
  local c=$TMP/sys/class/drm/card0-HDMI-A-1
  mkdir -p "$c" "$TMP/sys/class/i2c-$1"; echo connected >"$c/status"; ln -s "../../i2c-$1" "$c/ddc"
  printf '\0\377\377\377\377\377\377\0\036\155\335\134' >"$c/edid"
  : >"$DDC/log"
  cat >"$HOME/.config/fedokawaii/monitor.conf" <<'EOF'
# a comment
GSM5CDD 12 70
GSM5CDD 14 x01 xde
XXX0000 87 99
EOF
  echo 70 >"$DDC/c$1.12"; echo xde >"$DDC/c$1.14"; echo 50 >"$DDC/c$1.87"
}
sets_ddc() { grep -c ' setvcp ' "$DDC/log"; }
case_ "--monitor: everything as it should be: read, not written, nothing in the journal; the level goes to the bar"
lg 5; rc 0 kawa-display --monitor
eq "$(sets_ddc)" 0; not_called '^logger'; called '^kawa-brightness --reread'
case_ "--monitor: a value that differs is written, read back and said once"
lg 5; echo 50 >"$DDC/c5.12"; rc 0 kawa-display --monitor
eq "$(sets_ddc)" 1; eq "$(cat "$DDC/c5.12")" 70; called '^logger -t kawa-display -- monitor.s menu: GSM5CDD 12: 50 → 70$'
case_ "--monitor: a preset that reads back as something else (the LG's sRGB: x01 reads xde): settled, then quiet"
lg 5; echo x0b >"$DDC/c5.14"; echo 'x01 xde' >"$DDC/reads.14"; rc 0 kawa-display --monitor
eq "$(sets_ddc)" 1; eq "$(cat "$DDC/c5.14")" xde; called 'GSM5CDD 14: x0b → xde$'
: >"$DDC/log"; : >"$CALLS"; rc 0 kawa-display --monitor; eq "$(sets_ddc)" 0; not_called '^logger'
case_ "--monitor: it does not take: said so, in the journal"
lg 5; echo 50 >"$DDC/c5.12"; printf '70 50\n' >"$DDC/reads.12"; rc 0 kawa-display --monitor
called 'GSM5CDD 12: 50 → 50, wanted 70$'
case_ "--monitor: a code that does not answer: said, and the others still looked at"
lg 5; rm "$DDC/c5.12"; echo x0b >"$DDC/c5.14"; echo 'x01 xde' >"$DDC/reads.14"; rc 0 kawa-display --monitor
called 'GSM5CDD 12: no answer'; eq "$(cat "$DDC/c5.14")" xde
case_ "--monitor: a monitor just woken, answering after a moment: asked again, not given up on"
lg 5; echo 50 >"$DDC/c5.12"
stub sleep 'n=$(cat "$TMP/slept" 2>/dev/null || echo 0); echo $((n + 1)) >"$TMP/slept"; [ "$n" = 1 ] && echo 50 >"$DDC/c5.12"; :'
rm "$DDC/c5.12"; rc 0 kawa-display --monitor; eq "$(cat "$DDC/c5.12")" 70; not_called 'no answer'

case_ "--monitor: another model's lines never touch this one; another monitor: nothing written"
lg 5; rc 0 kawa-display --monitor; eq "$(grep -c ' getvcp 87' "$DDC/log")" 0
sed -i 's/^GSM5CDD/GSM0000/' "$HOME/.config/fedokawaii/monitor.conf"; : >"$DDC/log"; rc 0 kawa-display --monitor; eq "$(cat "$DDC/log")" ""
case_ "--monitor: no conf: nothing; a disconnected connector: nothing asked"
lg 5; rm "$HOME/.config/fedokawaii/monitor.conf"; rc 0 kawa-display --monitor; eq "$(cat "$DDC/log")" ""; not_called '^kawa-brightness'
lg 5; echo disconnected >"$TMP/sys/class/drm/card0-HDMI-A-1/status"; rc 0 kawa-display --monitor; eq "$(cat "$DDC/log")" ""
case_ "--hotplug: the monitor back: its menu looked at too, in the background"
lg 5; world 1080p144; echo 50 >"$DDC/c5.12"; rc 0 kawa-display --hotplug
waitfor 5 grep -q ' setvcp 12 70' "$DDC/log" && _ok || _no "the menu was not looked at: $(cat "$DDC/log")"
case_ "--monitor: the repo's conf: this LG's model, codes the monitor offers, and never a factory reset or a private code"
bad=$(grep -vE '^(#|$)' "$REPO/configs/home/.config/fedokawaii/monitor.conf" | awk '$1 != "GSM5CDD" || $2 !~ /^(12|14|16|18|1A|6C|6E|70)$/')
eq "$bad" ""
done_
