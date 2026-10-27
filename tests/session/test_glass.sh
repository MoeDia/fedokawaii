#!/usr/bin/env bash
# tests/session/test_glass.sh — kawa-glass, the terminal's see-through ground (Super+U →
# transparency): the setting saved where foot.ini's last include reads it, every open
# terminal told at once (OSC 11 with an alpha on each pseudo-terminal foot has a program on),
# a new shell told as it starts, and the parts that carry it (foot.ini, theme.sh, kawa-theme,
# kawa-config). A real pseudo-terminal stands in for a foot window (script(1)): what is
# written to it is what foot would read.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

G=.local/state/fedokawaii/foot-glass.ini
setup() {
  session_sandbox
  mkdir -p "$HOME/.config/fedokawaii/current"
  printf 'THEME=dark\nC_GROUND=0f0e0c\n' >"$HOME/.config/fedokawaii/current/colors.sh"
}
seen() { local i; for ((i = 0; i < 250; i++)); do [[ $(tr -d '\0' <"$TMP/pty.out") == *"0c/$1"* ]] && return 0; nap 0.02; done; }   # (up to 5 s)
alpha_of() { sed -n 's/^alpha=//p' "$HOME/$G" | sort -u | tr '\n' ' '; }

case_ "nothing saved: on, as the theme first sets it — ensure makes the file so (foot refuses its config without it), and leaves a saved one be"
setup
eq "$(kawa-glass)" on
rc 0 kawa-glass ensure; eq "$(alpha_of)" "0.92 "; eq "$(kawa-glass)" on
kawa-glass off >/dev/null; rc 0 kawa-glass ensure; eq "$(alpha_of)" "1 " "a saved off stays off"
case_ "on: 0.92 for both palettes, saved where foot.ini reads it"
rm -f "$HOME/$G"; rc 0 kawa-glass on; eq "$(alpha_of)" "0.92 "; eq "$(kawa-glass)" on
grep -qx '\[colors-dark\]' "$HOME/$G" && grep -qx '\[colors-light\]' "$HOME/$G" && _ok || _no "both palettes: $(cat "$HOME/$G")"
case_ "off: 1 (opaque); toggle: the other one, each time"
rc 0 kawa-glass off; eq "$(alpha_of)" "1 "; eq "$(kawa-glass)" off
kawa-glass toggle; eq "$(kawa-glass)" on; kawa-glass toggle; eq "$(kawa-glass)" off
case_ "misuse: the usage, exit 2"
rc 2 kawa-glass sideways

case_ "every open terminal told at once: OSC 11, the theme's ground with the alpha (0.92 → eb), on each pseudo-terminal foot has a program on"
setup; kawa-glass on >/dev/null
python3 -I "$REPO/tests/lib/pty_run.py" --flush --timeout 40 -- sleep 31.73 >"$TMP/pty.out" 2>/dev/null & BG_PIDS+=($!)
for ((i = 0; i < 200; i++)); do kid=$(/usr/bin/pgrep -f '^sleep 31\.73$' | head -n1); [[ -n $kid ]] && break; nap 0.02; done
echo "$kid" >"$TMP/kid"
stub pgrep 'case "$*" in *"-x foot"*) echo 4242 ;; "-P 4242") cat "'"$TMP"'/kid" ;; *) exit 1 ;; esac'
rc 0 kawa-glass apply; seen eb
has "$(tr -d '\0' <"$TMP/pty.out")" $'\e]11;rgba:0f/0e/0c/eb\e\\'
case_ "… and off: alpha ff (opaque again)"
: >"$TMP/pty.out"; rc 0 kawa-glass off; seen ff
has "$(tr -d '\0' <"$TMP/pty.out")" $'\e]11;rgba:0f/0e/0c/ff\e\\'
kill_bg

case_ "a new shell in foot is told as it starts (the server read the setting at login); elsewhere, nothing"
setup; config .bashrc.d/fedokawaii.sh .config/readline/inputrc
printf '%s\n' 'for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done; unset rc' >"$HOME/.bashrc"
stub zoxide; kawa-glass on >/dev/null
has "$(TERM=foot bash -ic true 2>/dev/null)" $'\e]11;rgba:0f/0e/0c/eb\e\\'
lacks "$(TERM=xterm-256color bash -ic true 2>/dev/null)" $'\e]11;'

case_ "foot.ini's last include is the saved file (after both palettes: its alpha has the last word)"
f=$REPO/configs/home/.config/foot/foot.ini
eq "$(tail -n 1 "$f")" "include=~/$G"
(( $(grep -n '^include=~/\.local/state' "$f" | cut -d: -f1) > $(grep -n '^\[colors-light\]' "$f" | cut -d: -f1) )) && _ok || _no "the include comes before a palette"
case_ "theme.sh makes the file once (on, 0.92) and never writes it again; kawa-theme tells the windows after a switch; Super+U has the switch"
grep -q '\[\[ -f \$GLASS \]\] || uinstall 0644' "$REPO/theme.sh" && _ok || _no "theme.sh"
grep -q 'kawa-glass apply' "$REPO/bin/kawa-theme" && _ok || _no "kawa-theme"
grep -q 'glass)     kawa-glass toggle' "$REPO/bin/kawa-config" && _ok || _no "kawa-config"

done_
