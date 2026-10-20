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

. "$REPO/configs/home/.config/fedokawaii/icons.sh"
nm() { fz_rows | sed -n "$(( $1 + 1 ))p" | cut -f3; }    # the name on the menu's line N (0-based)
case_ "two screens: 共 share what?, each by its name and current size; the chosen one's line comes back unchanged"
setup; answer "row 2"; out=$(share "$M1" "$M2")
eq "$out" "$M2"
eq "$(fz_rows | sed -n 1p)" "part	共	share what?" "the heading"
eq "$(fz_rows | sed 1d | cut -f1,3- )" $'row\tDP-1\t\t3840×2160\nrow\tHDMI-A-1\t\t1920×1080' "the current mode, not the preferred one, as the row's value (the panel right-aligns it in a column)"
eq "$(fz_arg title)" ""; eq "$(fz_arg width)" ""; eq "$(fz_arg lines)" 2; eq "$(fz_arg index)" set; eq "$(fz_arg select)" 1
fits
case_ "three screens, one without a refresh rate (a headless or virtual output): its size still shown"
setup; answer "row 3"; out=$(share "$M1" "$M2" "$M3")
eq "$out" "$M3"; eq "$(fz_rows | sed -n 4p | cut -f3,5)" "HEADLESS-1	1280×720"; fits
case_ "a screen wlr-randr does not list, or wlr-randr missing: the name alone"
setup; stub wlr-randr 'exit 1'; answer "row 1"; out=$(share "$M1" "Monitor: DP-3 Some Monitor")
eq "$(fz_rows | sed 1d | cut -f3,5 | tr '\n' '|')" "DP-1	|DP-3	|"; eq "$out" "$M1"
setup; p=$(without wlr-randr); answer "row 2"; eq "$(printf '%s\n' "$M1" "$M2" | PATH=$p kawa-share)" "$M2"
eq "$(fz_rows | sed 1d | cut -f3,5 | tr '\n' '|')" "DP-1	|HDMI-A-1	|"
case_ "the portal before 0.8 (bare screen names): still listed by name"
setup; answer "row 2"; eq "$(share DP-1 HDMI-A-1)" HDMI-A-1; eq "$(fz_rows | sed -n 3p | cut -f3,5)" "HDMI-A-1	1920×1080"

case_ "screens and windows: windows by their title, without wlroots' token"
setup; answer "row 3"; out=$(share "$M1" "$M2" "Window: Weekly sync — Brave ($ID)")
eq "$(fz_rows | sed -n 4p)" "row	$ICON_WINDOW	Weekly sync — Brave"; eq "$out" "Window: Weekly sync — Brave ($ID)"
case_ "a title with brackets of its own: only the last (the token) goes"
setup; answer esc; share "$M1" "Window: Inbox (3) — Thunderbird ($ID)" >/dev/null
eq "$(nm 2)" "Inbox (3) — Thunderbird"
case_ "a window with no title (or only spaces): a row that says so, never blank or a raw token"
setup; answer "row 3"; out=$(share "$M1" "Window:  ($ID)" "Window:    (${ID/4f/77})")
r=$(nm 2); has "$r" "untitled"; lacks "$r" "$ID"
r3=$(nm 3); has "$r3" "untitled"; [[ $r != "$r3" ]] && _ok || _no "two untitled windows look the same: [$r]"
eq "$out" "Window:    (${ID/4f/77})" "the line comes back as it came, spaces and all"
case_ "a long title, Latin or Japanese or Arabic: shortened at the source to 40 columns, at a word's end — never with …; every row fits"
setup; answer esc
share "$M1" "Window: $(printf 'a%.0s' {1..80}) ($ID)" "Window: 夜の音楽 — 坂本龍一 Ryuichi Sakamoto async 2017 (Live at Park Avenue Armory) ($ID)" \
      "Window: مرحبا بالعالم — مشغل الموسيقى ($ID)" "Window: 🎵 ♪ emoji title 🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶🎶 ($ID)" >/dev/null
fits; eq "$(nm 2 | python3 -I "$MD/cols.py" --px)" 240 "40 columns (one word, cut)"
eq "$(nm 3)" "夜の音楽 — 坂本龍一 Ryuichi Sakamoto" "at a word's end"; has "$(nm 4)" "مرحبا بالعالم"
lacks "$(fz_rows)" "…"
case_ "a title of exactly 40 columns stays whole; 41 is cut to 40 (one word: no word's end to cut at)"
setup; answer esc; share "$M1" "Window: $(printf 'b%.0s' {1..40}) ($ID)" "Window: $(printf 'c%.0s' {1..41}) ($ID)" >/dev/null
eq "$(nm 2)" "$(printf 'b%.0s' {1..40})"
eq "$(nm 3)" "$(printf 'c%.0s' {1..40})"
case_ "control characters in a title (a tab, an escape): shown as spaces; the line comes back as it came"
setup; answer "row 2"; t=$'Window: a\tb\e[31mred ('"$ID)"; out=$(share "$M1" "$t")
eq "$out" "$t"; eq "$(fz_rows | sed -n 3p | awk -F'\t' '{print NF}')" 3 "no tab of its own: three fields"; lacks "$(fz_rows)" $'\e'
case_ "quotes, \$( ), backticks, backslashes in a title: text, never run"
setup; answer "row 2"; t='Window: "x" $(touch '"$TMP"'/pwned) `id` \n \ ('"$ID)"; out=$(share "$M1" "$t")
eq "$out" "$t"; [[ ! -e $TMP/pwned ]] && _ok || _no "a title ran as a command"
case_ "many windows (30): 12 lines shown, the list scrolls, the 25th window can be chosen"
setup; lines=("$M1" "$M2"); for i in {1..30}; do lines+=("Window: window number $i ($ID$i)"); done
answer "row 27"; out=$(share "${lines[@]}")
eq "$(fz_arg lines)" 12; eq "$(fz_rows | wc -l)" 33; eq "$out" "Window: window number 25 (${ID}25)"; fits

case_ "Esc, a click outside: nothing printed (cancelled), exit 1"
for a in esc lost "typed DP"; do setup; answer "$a"; out=$(share "$M1" "$M2"); r=$?; eq "$r" 1 "$a"; eq "$out" "" "$a"; done

case_ "started by the portal: systemd's PATH (no ~/.local/bin) and no UTF-8 locale"
setup; mkdir -p "$HOME/.local/bin"; ln -s "$REPO/bin/kawa-menu" "$HOME/.local/bin/kawa-menu"
answer "row 2"
long="Window: a$(printf '夜%.0s' {1..30}) ($ID)"
# (every LC_ variable gone: python's C-locale coercion, for one, leaves LC_CTYPE=C.UTF-8 behind)
mapfile -t unset_lc < <(env | sed -n 's/^\(LC_[A-Z_]*\)=.*/-u\n\1/p')
out=$(printf '%s\n' "$M1" "$long" | env "${unset_lc[@]}" LANG=C PATH="$STUBS:/usr/bin:/bin" bash "$REPO/bin/kawa-share")
eq "$out" "$long"
fz_rows | sed -n 3p | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 && _ok || _no "the cut title is not valid UTF-8 (cut inside a character)"
fits "" "C locale"
eq "$(nm 2 | python3 -I "$MD/cols.py" --px)" 234 "cut by columns (a and 18 wide letters, then …: 6 + 216 + 12 px), not by bytes"

# ── one share, one question ──────────────────────────────────────────────────
# Brave's picker opens a portal session for its preview ("Window" pane: windows only), then the
# share opens another; xdpw gives no restore token for a window, so both reach kawa-share.
MEM() { printf '%s' "$XDG_RUNTIME_DIR/kawa-share.last"; }
LOGF() { printf '%s' "$HOME/.cache/kawa-share.log"; }
# remember LINE SECONDS_AGO — the memory as a choice made that long ago left it
remember() { printf '%s\t%s\n' "$(( ${EPOCHREALTIME//[.,]/} - $2 * 1000000 ))" "$1" >"$(MEM)"; }
W1="Window: Weekly sync — Brave ($ID)" W2="Window: notes.md — nvim (${ID/4f/77})"
W3="Window: btop (${ID/4f/aa})"

case_ "Brave's two requests for one window share: one menu; the second answered at once, unchanged"
setup; answer "row 2"
eq "$(share "$W2" "$W1" "$W3")" "$W1" "the preview's request: asked"
eq "$(fz_n)" 1
eq "$(share "$W2" "$W1" "$W3")" "$W1" "the share's own request: the same window"
eq "$(fz_n)" 1 "no second menu"
eq "$(share "$W3" "$W1")" "$W1" "a third request (an Electron app's), a moment later: the same"
eq "$(fz_n)" 1
case_ "the window's title changed in between (a call's timer, a page loading): found by its token"
setup; answer "row 1"; share "$W1" "$W2" >/dev/null
out=$(share "$W2" "Window: Weekly sync (2) — Brave ($ID)")
eq "$out" "Window: Weekly sync (2) — Brave ($ID)" "the line as offered now (the portal matches today's title)"
eq "$(fz_n)" 1
case_ "a title with brackets, tabs, escapes: remembered and given back byte for byte"
setup; t=$'Window: Inbox (3)\t\e[1m — Thunderbird ('"$ID)"; answer "row 2"
eq "$(share "$W2" "$t")" "$t"; eq "$(share "$W2" "$t")" "$t"; eq "$(fz_n)" 1
case_ "a screen: remembered by its name (the line from this request)"
setup; answer "row 2"; eq "$(share "$M1" "$M2" "$W1")" "$M2"
eq "$(share "$M1" "Monitor: HDMI-A-1 LG Electronics LG ULTRAGEAR 0x0004 (HDMI-A-1) ")" \
   "Monitor: HDMI-A-1 LG Electronics LG ULTRAGEAR 0x0004 (HDMI-A-1) "; eq "$(fz_n)" 1
setup; answer "row 2"; eq "$(share DP-1 HDMI-A-1)" HDMI-A-1; eq "$(share DP-1 HDMI-A-1)" HDMI-A-1
eq "$(fz_n)" 1 "the portal before 0.8 (bare names) too"
case_ "a window and a screen of the same name are different choices"
setup; remember "Window: x (DP-1)" 1; answer "row 1"; eq "$(share "$M1" "$M2")" "$M1"; eq "$(fz_n)" 1 "asked"

case_ "10 seconds after the choice: asked again (a new share)"
setup; remember "$W1" 11; answer "row 1"; eq "$(share "$W2" "$W1")" "$W2"; eq "$(fz_n)" 1
setup; remember "$W1" 9; eq "$(share "$W2" "$W1")" "$W1"; eq "$(fz_n)" 0 "9 s: still the same share"
case_ "the ten seconds count from the choice, not from the menu opening (it may stay open long)"
setup; answer "row 2"; share "$W2" "$W1" >/dev/null
read -r t0 _ <"$(MEM)"; now=${EPOCHREALTIME//[.,]/}
((now - t0 >= 0 && now - t0 < 2000000)) && _ok || _no "remembered at $t0, now $now"
case_ "remembered answers do not stretch the ten seconds"
setup; remember "$W1" 8; before=$(cat "$(MEM)"); share "$W2" "$W1" >/dev/null
eq "$(cat "$(MEM)")" "$before"
case_ "the remembered window not offered (it closed; or the screens-only pane): asked"
setup; remember "$W1" 1; answer "row 2"; eq "$(share "$M1" "$M2")" "$M2"; eq "$(fz_n)" 1
eq "$(cut -f2 "$(MEM)")" "$M2" "the new choice is the one remembered"
case_ "Esc forgets: the next request asks"
setup; remember "$W2" 1; answer esc "row 2"
eq "$(share "$W1" "$W3")" "" "W2 not offered: asked, Esc"
[[ ! -e $(MEM) ]] && _ok || _no "Esc kept the memory"
eq "$(share "$W2" "$W1")" "$W1" "W2 offered again, after Esc: asked again"; eq "$(fz_n)" 2
case_ "an old memory goes at the next request"
setup; remember "$W1" 30; answer esc; share "$W2" "$W1" >/dev/null
[[ ! -e $(MEM) ]] && _ok || _no "an expired memory stayed"
case_ "one choice is taken without asking, and not remembered over a real choice"
setup; remember "$W1" 1; eq "$(share "$W3")" "$W3"; eq "$(fz_n)" 0
eq "$(cut -f2 "$(MEM)")" "$W1" "the memory is the user's choice"
case_ "a memory from the future (the clock went back) or garbage: asked, and it goes"
setup; printf '%s\t%s\n' "$(( ${EPOCHREALTIME//[.,]/} + 60000000 ))" "$W1" >"$(MEM)"; answer "row 1"
eq "$(share "$W2" "$W1")" "$W2"; eq "$(fz_n)" 1
setup; printf 'yesterday\t%s\n' "$W1" >"$(MEM)"; answer "row 1"; eq "$(share "$W2" "$W1")" "$W2"
setup; printf 'garbage' >"$(MEM)"; answer "row 1"; eq "$(share "$W2" "$W1")" "$W2"
case_ "no runtime folder (never under the portal): it says so (into the portal's journal), no share"
setup; out=$(printf '%s\n' "$W1" "$W2" | env -u XDG_RUNTIME_DIR kawa-share 2>&1); r=$?
eq "$r" 1; has "$out" "XDG_RUNTIME_DIR"; eq "$(fz_n)" 0

case_ "the log: one line per run — when, how, what was offered, what was shared"
setup; answer "row 2" esc
share "$M1" "$W1" "$W2" >/dev/null; share "$W1" "$W2" >/dev/null; share "$M1" >/dev/null
share "$M1" "$M2" >/dev/null; printf '' | kawa-share >/dev/null
mapfile -t L <"$(LOGF)"
eq "${#L[@]}" 5 "five runs, five lines"
re=$'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}\t'
for l in "${L[@]}"; do [[ $l =~ $re ]] && _ok || _no "no time (YYYY-MM-DD HH:MM:SS.mmm) at the start: [$l]"; done
eq "$(cut -f2- <<<"${L[0]}")" $'asked\tscreens 1, windows 2\t'"$W1"
[[ $(cut -f2 <<<"${L[1]}") =~ ^remembered\ \(0\.[0-9]\ s\ ago\)$ ]] && _ok || _no "second: [${L[1]}]"
eq "$(cut -f3- <<<"${L[1]}")" $'screens 0, windows 2\t'"$W1"
eq "$(cut -f2- <<<"${L[2]}")" $'one choice\tscreens 1, windows 0\t'"$M1"
eq "$(cut -f2- <<<"${L[3]}")" $'cancelled\tscreens 2, windows 0\t-'
eq "$(cut -f2- <<<"${L[4]}")" $'nothing offered\tscreens 0, windows 0\t-'
case_ "the log keeps the last 500 runs once it passes 1000; a missing ~/.cache is made"
setup; for i in $(seq 1 1000); do echo "old $i"; done >"$(LOGF)"; share "$M1" >/dev/null
eq "$(wc -l <"$(LOGF)")" 500; eq "$(head -n1 "$(LOGF)")" "old 502"; has "$(tail -n1 "$(LOGF)")" "one choice"
setup; rm -rf "$HOME/.cache"; share "$M1" >/dev/null; [[ -s $(LOGF) ]] && _ok || _no "no log"
case_ "a log that cannot be written (a read-only ~/.cache): the share still goes ahead"
setup; chmod 500 "$HOME/.cache"; answer "row 2"
if [[ -w $HOME/.cache ]]; then echo "  (skipped: root writes anywhere)"; else
  eq "$(share "$M1" "$M2" 2>/dev/null)" "$M2"; fi
chmod 700 "$HOME/.cache"

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-share --help </dev/null)" "what to share"; rc 0 kawa-share --help </dev/null
rc 2 kawa-share now </dev/null; eq "$(fz_n)" 0

done_
