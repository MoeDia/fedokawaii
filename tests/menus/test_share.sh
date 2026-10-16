#!/usr/bin/env bash
# tests/menus/test_share.sh — kawa-share, "share what?": xdg-desktop-portal-wlr (0.8, its dmenu
# chooser) writes one line per screen and window on stdin and shares the line printed back —
# byte for byte, or nothing (cancelled). One screen, two, three (one without a refresh rate);
# no windows, many, untitled ones, odd titles; the portal's own PATH and locale.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

# wlr-randr as it prints (wlr-randr 0.4/0.5): a 4K, a 1080p, a headless output with no refresh
# rate, and one switched off
# shellcheck disable=SC2089  # (text wlr-randr prints, quotes and all)
RANDR='DP-1 "Dell Inc. DELL U2720Q 1234 (DP-1)"
  Physical size: 600x340 mm
  Enabled: yes
  Modes:
    3840x2160 px, 59.997002 Hz (preferred, current)
    2560x1440 px, 59.951000 Hz
  Position: 0,0
  Transform: normal
  Scale: 1.000000
HDMI-A-1 "LG Electronics LG ULTRAGEAR 0x0004 (HDMI-A-1)"
  Enabled: yes
  Modes:
    1920x1080 px, 60.000000 Hz (preferred)
    1920x1080 px, 143.981003 Hz (current)
  Position: 3840,0
  Transform: normal
  Scale: 1.000000
HEADLESS-1 "Headless output 1"
  Enabled: yes
  Modes:
    1280x720 px (current)
  Position: 5760,0
  Transform: normal
  Scale: 1.000000
DP-2 "BenQ GW2480 (DP-2)"
  Enabled: no
  Modes:
    1920x1080 px, 60.000000 Hz (preferred)'
# shellcheck disable=SC2090
setup() { menus_sandbox; export RANDR; stub wlr-randr 'printf "%s\n" "$RANDR"'; }
share() { printf '%s\n' "$@" | kawa-share; }
M1='Monitor: DP-1 Dell Inc. DELL U2720Q 1234 (DP-1)' M2='Monitor: HDMI-A-1 LG Electronics LG ULTRAGEAR 0x0004 (HDMI-A-1)'
M3='Monitor: HEADLESS-1 Headless output 1'
ID=4f2a9c1e0b7d4e21a3c5f6b7d8e9f0a1      # wlroots names each window by an opaque token like this

case_ "nothing to share (no lines): cancelled, exit 1, no menu"
setup; out=$(printf '' | kawa-share); rc 1 kawa-share </dev/null; eq "$out" ""; eq "$(fz_n)" 0
case_ "one screen, nothing else: shared at once, no question"
setup; eq "$(share "$M1")" "$M1"; eq "$(fz_n)" 0; not_called '^wlr-randr'
case_ "one window and nothing else (an app asking for a window only): shared at once"
setup; eq "$(share "Window: notes.md — nvim ($ID)")" "Window: notes.md — nvim ($ID)"; eq "$(fz_n)" 0

case_ "two screens: each by its name and current size; the chosen one's line comes back unchanged"
setup; answer "row 1"; out=$(share "$M1" "$M2")
eq "$out" "$M2"
eq "$(fz_rows | sed 's/^.  //')" $'DP-1       3840×2160\nHDMI-A-1   1920×1080' "the current mode, not the preferred one"
eq "$(fz_arg mesg)" "share what?"; eq "$(fz_arg width)" 48; eq "$(fz_arg lines)" 2; eq "$(fz_arg index)" set
fits
case_ "three screens, one without a refresh rate (a headless or virtual output): its size still shown"
setup; answer "row 2"; out=$(share "$M1" "$M2" "$M3")
eq "$out" "$M3"; eq "$(fz_rows | sed -n 3p | sed 's/^.  //')" "HEADLESS-1 1280×720"; fits
case_ "a screen wlr-randr does not list, or wlr-randr missing: the name alone"
setup; stub wlr-randr 'exit 1'; answer "row 0"; out=$(share "$M1" "Monitor: DP-3 Some Monitor")
eq "$(fz_rows | sed 's/^.  //; s/ *$//')" $'DP-1\nDP-3'; eq "$out" "$M1"
setup; p=$(without wlr-randr); answer "row 1"; eq "$(printf '%s\n' "$M1" "$M2" | PATH=$p kawa-share)" "$M2"
eq "$(fz_rows | sed 's/^.  //; s/ *$//')" $'DP-1\nHDMI-A-1'
case_ "the portal before 0.8 (bare screen names): still listed by name"
setup; answer "row 1"; eq "$(share DP-1 HDMI-A-1)" HDMI-A-1; has "$(fz_rows)" "HDMI-A-1   1920×1080"

case_ "screens and windows: windows by their title, without wlroots' token"
setup; answer "row 2"; out=$(share "$M1" "$M2" "Window: Weekly sync — Brave ($ID)")
eq "$(fz_rows | sed -n 3p | sed 's/^.  //')" "Weekly sync — Brave"; eq "$out" "Window: Weekly sync — Brave ($ID)"
case_ "a title with brackets of its own: only the last (the token) goes"
setup; answer esc; share "$M1" "Window: Inbox (3) — Thunderbird ($ID)" >/dev/null
eq "$(fz_rows | sed -n 2p | sed 's/^.  //')" "Inbox (3) — Thunderbird"
case_ "a window with no title (or only spaces): a row that says so, never blank or a raw token"
setup; answer "row 2"; out=$(share "$M1" "Window:  ($ID)" "Window:    (${ID/4f/77})")
r=$(fz_rows | sed -n 2p | sed 's/^.  //'); has "$r" "untitled"; lacks "$r" "$ID"
r3=$(fz_rows | sed -n 3p | sed 's/^.  //'); has "$r3" "untitled"; [[ $r != "$r3" ]] && _ok || _no "two untitled windows look the same: [$r]"
eq "$out" "Window:    (${ID/4f/77})" "the line comes back as it came, spaces and all"
case_ "a long title, Latin or Japanese or Arabic: cut to 40 columns with …, every row fits"
setup; answer esc
share "$M1" "Window: $(printf 'a%.0s' {1..80}) ($ID)" "Window: 夜の音楽 — 坂本龍一 Ryuichi Sakamoto async 2017 (Live at Park Avenue Armory) ($ID)" \
      "Window: مرحبا بالعالم — مشغل الموسيقى ($ID)" "Window: 🎵 ♪ emoji title 🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶 ($ID)" >/dev/null
fits; eq "$(fz_rows | sed -n 2p | python3 -I "$MD/cols.py")" 44 "icon (2) + 2 + 40"
has "$(fz_rows | sed -n 3p)" "…"; has "$(fz_rows | sed -n 4p)" "مرحبا بالعالم"
case_ "a title of exactly 40 columns stays whole; 41 is cut (to 39 and …)"
setup; answer esc; share "$M1" "Window: $(printf 'b%.0s' {1..40}) ($ID)" "Window: $(printf 'c%.0s' {1..41}) ($ID)" >/dev/null
eq "$(fz_rows | sed -n 2p | sed 's/^.  //')" "$(printf 'b%.0s' {1..40})"
eq "$(fz_rows | sed -n 3p | sed 's/^.  //')" "$(printf 'c%.0s' {1..39})…"
case_ "control characters in a title (a tab, an escape): shown as spaces; the line comes back as it came"
setup; answer "row 1"; t=$'Window: a\tb\e[31mred ('"$ID)"; out=$(share "$M1" "$t")
eq "$out" "$t"; lacks "$(fz_rows)" $'\t'; lacks "$(fz_rows)" $'\e'
case_ "quotes, \$( ), backticks, backslashes in a title: text, never run"
setup; answer "row 1"; t='Window: "x" $(touch '"$TMP"'/pwned) `id` \n \ ('"$ID)"; out=$(share "$M1" "$t")
eq "$out" "$t"; [[ ! -e $TMP/pwned ]] && _ok || _no "a title ran as a command"
case_ "many windows (30): 12 lines shown, the list scrolls, the 25th window can be chosen"
setup; lines=("$M1" "$M2"); for i in {1..30}; do lines+=("Window: window number $i ($ID$i)"); done
answer "row 26"; out=$(share "${lines[@]}")
eq "$(fz_arg lines)" 12; eq "$(fz_rows | wc -l)" 32; eq "$out" "Window: window number 25 (${ID}25)"; fits

case_ "Esc, a click outside: nothing printed (cancelled), exit 1"
for a in esc lost "typed DP"; do setup; answer "$a"; out=$(share "$M1" "$M2"); r=$?; eq "$r" 1 "$a"; eq "$out" "" "$a"; done

case_ "started by the portal: systemd's PATH (no ~/.local/bin) and no UTF-8 locale"
setup; mkdir -p "$HOME/.local/bin"; ln -s "$REPO/bin/kawa-menu" "$HOME/.local/bin/kawa-menu"
answer "row 1"
long="Window: a$(printf '夜%.0s' {1..30}) ($ID)"
# (every LC_ variable gone: python's C-locale coercion, for one, leaves LC_CTYPE=C.UTF-8 behind)
mapfile -t unset_lc < <(env | sed -n 's/^\(LC_[A-Z_]*\)=.*/-u\n\1/p')
out=$(printf '%s\n' "$M1" "$long" | env "${unset_lc[@]}" LANG=C PATH="$STUBS:/usr/bin:/bin" bash "$REPO/bin/kawa-share")
eq "$out" "$long"
fz_rows | sed -n 2p | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 && _ok || _no "the cut title is not valid UTF-8 (cut inside a character)"
fits "" "C locale"
eq "$(fz_rows | sed -n 2p | python3 -I "$MD/cols.py")" 44 "cut to 40 columns (a and 19 wide letters, then …), not to 39 bytes"

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-share --help </dev/null)" "what to share"; rc 0 kawa-share --help </dev/null
rc 2 kawa-share now </dev/null; eq "$(fz_n)" 0

done_
