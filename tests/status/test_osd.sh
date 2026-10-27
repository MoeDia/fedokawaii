#!/usr/bin/env bash
# tests/status/test_osd.sh — kawa-osd, the level display of the volume, microphone and
# brightness keys. It draws nothing and sends no notice: it asks the running panel (kawa-panel)
# through the panel's fifo, $XDG_RUNTIME_DIR/kawa-panel.in, with ONE line — `level ICON PCT`,
# or `level ICON PCT off` while muted — written whole, and is done: opened for reading and
# writing, it never waits for the panel, whatever the panel is doing. The panel here is lib.sh's
# stand-in (osd_panel holds the fifo; osd_raw and osd read what was asked of it).
# Checked: the exact line for a normal level, a muted one, one above 999, one that is no number
# and one with leading zeros; one line per call however fast the calls come (a held key: none
# lost, none merged, none torn); no panel running (no fifo, or something else at its path): a
# failure (1) that writes nothing anywhere; every kind of misuse (2), and --help (0); and,
# throughout, that no notice (notify-send) and no other program is ever called.
# (Not run here: with XDG_RUNTIME_DIR unset kawa-osd falls back to /run/user/UID — on this PC
# the live session's own fifo, which a test must never poke.)
. "$(dirname "$0")/lib.sh"
# a panel running; and stand-ins that log it if a notice were sent or a process started
setup() { box; osd_panel; stub notify-send; stub makoctl; stub kawa-panel; . "$HOME/.config/fedokawaii/icons.sh"; }
# the panel quit (it takes its fifo away): nobody to ask
nopanel() { setup; rm -f "$XDG_RUNTIME_DIR/kawa-panel.in"; }
# tree — everything in the sandbox with its kind, size and time: the same twice = nothing written
tree() { find "$TMP" -mindepth 1 -printf '%p %y %s %T@\n' | sort; }

# ── what it asks ─────────────────────────────────────────────────────────────
case_ "70 %: one line 'level ICON 70' in the panel's fifo; done (0), silent; no notice, no other program"
setup
out=$(kawa-osd "$ICON_BRI_3" brightness 70 2>&1); r=$?
eq "$r" 0; eq "$out" "" "nothing printed"
eq "$(osd_raw)" "level $ICON_BRI_3 70"
eq "$(osd)" "$ICON_BRI_3|70|"
not_called '^notify-send '
eq "$(<"$CALLS")" "" "no program of the desktop was called"

case_ "muted: 'level ICON 40 off' — the word off after the level, the icon as given"
setup
rc 0 kawa-osd "$ICON_VOL_MUTE" volume 40 off
eq "$(osd_raw)" "level $ICON_VOL_MUTE 40 off"
eq "$(osd)" "$ICON_VOL_MUTE|40|off"
kawa-osd "$ICON_MIC_OFF" microphone 0 off;  eq "$(osd)" "$ICON_MIC_OFF|0|off"
kawa-osd "$ICON_VOL_MUTE" volume 999 off;   eq "$(osd)" "$ICON_VOL_MUTE|999|off"
kawa-osd "$ICON_VOL_2" volume 40;           eq "$(osd)" "$ICON_VOL_2|40|" "not muted: no word after the level"

case_ "the label is accepted and not used: any word, an empty one, one with spaces, markup or a command in it — the same line"
setup
labels=(volume microphone brightness "" "a very long label here" '<b>x</b>' '$(id)' '%s' 明)
for lab in "${labels[@]}"; do
  rc 0 kawa-osd "$ICON_VOL_2" "$lab" 50
done
eq "$(osd_raw | sort -u)" "level $ICON_VOL_2 50" "the label is in none of them"
eq "$(osd_raw | wc -l)" "${#labels[@]}" "one line each"

case_ "the icon goes through as it is — pixel icons, a kanji, plain text, and text printf or the shell would read as something"
setup
icons=("$ICON_VOL_4" "$ICON_BRI_0" "$ICON_MIC" 明 x '%s' '%d%%' '\n' '\\' '*' '$HOME' '`id`' -- "it's" '"q"' '<b>')
for ic in "${icons[@]}"; do
  rc 0 kawa-osd "$ic" volume 5
  eq "$(osd_raw | tail -n 1)" "level $ic 5" "icon [$ic]"
done
eq "$(osd_raw | wc -l)" "${#icons[@]}"

case_ "the level is the real number, three digits at most: 0 to 999 as they are; 1000 to 9999 is 999"
setup
for p in 0:0 1:1 5:5 45:45 99:99 100:100 101:101 150:150 999:999 1000:999 1234:999 9999:999; do
  rc 0 kawa-osd "$ICON_VOL_4" volume "${p%:*}"
  eq "$(osd)" "$ICON_VOL_4|${p#*:}|" "level ${p%:*}"
done

case_ "a level that is not one to four digits is 0 — still a request (exit 0, one line): empty, words, signs, decimals, spaces, five digits, a newline"
setup
bad=("" abc -5 +5 -0 4.5 5.0 ' 5' '5 ' 1e3 0x10 '٣' '<b>' ';' 10000 00099 $'5\n' $'\n5')
for p in "${bad[@]}"; do
  rc 0 kawa-osd "$ICON_VOL_2" volume "$p"
  eq "$(osd)" "$ICON_VOL_2|0|" "level [$p]"
done
eq "$(osd_raw | wc -l)" "${#bad[@]}" "one line each"

case_ "a level is never run as a command, and never makes a second request (\$(…), backquotes, ;, a newline with 'close' after it)"
setup
evil=("\$(touch $TMP/pwned)" "\`touch $TMP/pwned\`" "5;touch $TMP/pwned" $'50\nclose' $'50\ntoggle quick')
for p in "${evil[@]}"; do
  rc 0 kawa-osd "$ICON_VOL_2" volume "$p"
done
eq "$(osd_raw | sort -u)" "level $ICON_VOL_2 0" "a plain 0 each"
eq "$(osd_raw | wc -l)" "${#evil[@]}" "one line each"
[[ ! -e $TMP/pwned ]] && _ok || _no "a level was run as a command"

case_ "leading zeros are read as decimal, never octal: 007 → 7, 010 → 10, 08 and 09 are fine, 0100 → 100, 0999 → 999, 0000 → 0"
setup
for p in 007:7 08:8 09:9 010:10 0100:100 0999:999 000:0 0000:0 0001:1; do
  rc 0 kawa-osd "$ICON_VOL_2" volume "${p%:*}"
  eq "$(osd)" "$ICON_VOL_2|${p#*:}|" "level ${p%:*}"
done

# ── one line per call ────────────────────────────────────────────────────────
case_ "a held key — 30 calls in a row, the panel not reading meanwhile: 30 lines in order, none merged; 30 of the same level too, no repeat is skipped"
setup
want=""
for i in {1..30}; do
  rc 0 kawa-osd "$ICON_VOL_3" volume $((i * 3))
  want+="level $ICON_VOL_3 $((i * 3))"$'\n'
done
eq "$(osd_raw)" "${want%$'\n'}" "the ramp, line for line"
for _ in {1..30}; do kawa-osd "$ICON_VOL_2" volume 50; done
eq "$(osd_raw | wc -l)" 60
eq "$(osd_raw | tail -n 30 | sort -u)" "level $ICON_VOL_2 50"
eq "$(osd 30)" "$ICON_VOL_2|50|" "the 30th from the last: the first of the repeats"
eq "$(osd 31)" "$ICON_VOL_3|90|" "… and the one before it: the ramp's last"
eq "$(osd 60)" "$ICON_VOL_3|3|" "… back to the ramp's first"
eq "$(osd 61)" "" "there is no 61st"
not_called '^notify-send '

case_ "… and 30 at once, each with a 100-character icon (a torn line would show): 30 whole lines, each its own, none interleaved"
setup
long=$(printf 'x%.0s' {1..100})
for i in {1..30}; do kawa-osd "$long$i" volume "$i" & done; wait
eq "$(osd_raw | wc -l)" 30
eq "$(osd_raw | grep -Ec '^level x{100}[0-9]+ [0-9]+$')" 30 "every line whole"
eq "$(osd_raw | awk '{ n = substr($2, 101) } n != $3 { bad++ } END { print bad + 0 }')" 0 "each icon with its own level"
eq "$(osd_raw | awk '{ print $3 }' | sort -n | tr '\n' ' ')" "$(seq 1 30 | tr '\n' ' ')" "all thirty levels, none twice"

case_ "nobody reading (the panel killed, its fifo left behind): refused at once — not shown, so a failure (1), never a wait for a reader"
box; . "$HOME/.config/fedokawaii/icons.sh"
mkfifo "$XDG_RUNTIME_DIR/kawa-panel.in"
rc 1 timeout 10 kawa-osd "$ICON_VOL_2" volume 50    # (a wait for a reader would end in 124)
eq "$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'kawa-panel.in' -type p | wc -l)" 1 "the fifo left as it was"

case_ "a hung panel (its pipe full, nobody draining it): the line dropped (1) at once — never this process stuck, holding the volume key's lock"
box; . "$HOME/.config/fedokawaii/icons.sh"
mkfifo "$XDG_RUNTIME_DIR/kawa-panel.in"
exec 7<>"$XDG_RUNTIME_DIR/kawa-panel.in"           # (a reader that never reads: the hung panel)
python3 -c 'import os, sys
fd = os.open(sys.argv[1], os.O_WRONLY | os.O_NONBLOCK)
try:
    while True: os.write(fd, b"x" * 4096)
except BlockingIOError: pass' "$XDG_RUNTIME_DIR/kawa-panel.in"
rc 1 timeout 10 kawa-osd "$ICON_VOL_2" volume 50
rc 1 timeout 10 kawa-osd "$ICON_VOL_MUTE" volume 50 off
exec 7<&-

# ── no panel running ─────────────────────────────────────────────────────────
case_ "no panel (no fifo): not shown, a failure (1) — silent, and nothing written anywhere (no file, no log, no notice)"
nopanel
before=$(tree)
out=$(kawa-osd "$ICON_VOL_2" volume 50 2>&1); r=$?
eq "$r" 1; eq "$out" "" "silent"
out=$(kawa-osd "$ICON_VOL_MUTE" volume 40 off 2>&1); eq "$?" 1
out=$(kawa-osd "$ICON_VOL_2" volume abc 2>&1);       eq "$?" 1 "a level that is no number is no reason to answer otherwise"
eq "$(tree)" "$before" "the sandbox is as it was: not a file made, not a byte written"
eq "$(osd_raw)" ""
not_called '^notify-send '
case_ "… something at the panel's path that is no fifo (a file, a folder, a link to nothing, a link to a file): 1 as well, and nothing written to it"
nopanel
f=$XDG_RUNTIME_DIR/kawa-panel.in
: >"$f";                      rc 1 kawa-osd "$ICON_VOL_2" volume 50; eq "$(wc -c <"$f")" 0 "the file stays empty"
rm "$f"; mkdir "$f";          rc 1 kawa-osd "$ICON_VOL_2" volume 50; eq "$(ls -A "$f")" "" "the folder stays empty"
rmdir "$f"; ln -s "$TMP/nowhere" "$f"; rc 1 kawa-osd "$ICON_VOL_2" volume 50
[[ ! -e $TMP/nowhere ]] && _ok || _no "a link to nothing was followed, and made"
rm "$f"; : >"$TMP/plain"; ln -s "$TMP/plain" "$f"; rc 1 kawa-osd "$ICON_VOL_2" volume 50; eq "$(wc -c <"$TMP/plain")" 0 "the file behind the link stays empty"
case_ "… the panel starts later: from then on the calls arrive, nothing kept for it from before"
nopanel
rc 1 kawa-osd "$ICON_VOL_2" volume 30
osd_panel
rc 0 kawa-osd "$ICON_VOL_2" volume 31
eq "$(osd_raw)" "level $ICON_VOL_2 31"
case_ "… and goes away again (its fifo taken away): back to 1, nothing more written"
rm -f "$XDG_RUNTIME_DIR/kawa-panel.in"
rc 1 kawa-osd "$ICON_VOL_2" volume 32
eq "$(osd_raw)" "level $ICON_VOL_2 31"

# ── misuse ───────────────────────────────────────────────────────────────────
case_ "wrong number of arguments (none, one, two, five, six): misuse (2) with the usage line on stderr, nothing on stdout, nothing asked of the panel"
setup
rc 2 kawa-osd
rc 2 kawa-osd "$ICON_VOL_2"
rc 2 kawa-osd "$ICON_VOL_2" volume
rc 2 kawa-osd "$ICON_VOL_2" volume 50 off extra
rc 2 kawa-osd "$ICON_VOL_2" volume 50 off off off
has "$(kawa-osd 2>&1 >/dev/null)" "usage: kawa-osd ICON LABEL PERCENT [off]"
eq "$(kawa-osd "$ICON_VOL_2" volume 50 off extra 2>/dev/null)" "" "nothing on stdout"
eq "$(osd_raw)" ""
case_ "an empty icon, or one with a space, tab, newline, return or form feed in it (an icon is one word; a newline would be a second request): 2"
setup
for ic in "" " " "a b" " a" "a " $'a\tb' $'a\nb' $'a\rb' $'a\vb' $'a\fb' $'x\ntoggle quick' $'x\nclose'; do
  rc 2 kawa-osd "$ic" volume 50
  rc 2 kawa-osd "$ic" volume 50 off
done
eq "$(osd_raw)" "" "nothing asked of the panel"
case_ "a fourth word that is not 'off' (another word, other case, a space around it, a newline and a request after it): 2 — 'off' itself the only one"
setup
for w in on OFF Off 'off ' ' off' yes 1 -off off1 $'off\nclose'; do
  rc 2 kawa-osd "$ICON_VOL_2" volume 50 "$w"
done
eq "$(osd_raw)" "" "nothing asked of the panel"
rc 0 kawa-osd "$ICON_VOL_2" volume 50 off
eq "$(osd)" "$ICON_VOL_2|50|off"
case_ "misuse is judged before the panel is looked for: 2 with no panel too (a level that is no number is not misuse: 1)"
nopanel
rc 2 kawa-osd
rc 2 kawa-osd "" volume 50
rc 2 kawa-osd "$ICON_VOL_2" volume 50 on
rc 1 kawa-osd "$ICON_VOL_2" volume 50
rc 1 kawa-osd "$ICON_VOL_2" volume abc
case_ "--help and -h: what it does (the level line it sends), on stdout, done (0) — no panel needed, nothing asked of one"
setup
out=$(kawa-osd --help 2>/dev/null); r=$?
eq "$r" 0; has "$out" "kawa-osd ICON LABEL PERCENT [off]"; has "$out" "level"; lacks "$out" "set -u" "the comment only, not the script"
eq "$(kawa-osd --help 2>&1 >/dev/null)" "" "nothing on stderr"
eq "$(kawa-osd -h)" "$out" "-h the same"
rc 0 kawa-osd --help "$ICON_VOL_2" volume 50
eq "$(osd_raw)" "" "nothing asked of the panel"
rm -f "$XDG_RUNTIME_DIR/kawa-panel.in"; rc 0 kawa-osd --help

# ── environment ──────────────────────────────────────────────────────────────
case_ "a runtime folder with a space, brackets, a star and a dollar in its name: the request still arrives"
setup
export XDG_RUNTIME_DIR="$TMP/my run [1] * \$x"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"; osd_panel
rc 0 kawa-osd "$ICON_VOL_2" volume 45
eq "$(osd)" "$ICON_VOL_2|45|"
case_ "it needs nothing of the desktop's set-up (it draws nothing): no home, no locale, no theme, no icons — only PATH and the runtime folder"
setup
rc 0 env -i PATH="$PATH" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" kawa-osd "$ICON_VOL_2" volume 45 off
eq "$(osd_raw)" "level $ICON_VOL_2 45 off"
case_ "Turkish and Arabic locales: the same lines"
setup
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  locale_ok "$loc" || { skip "no $loc here"; continue; }
  LC_ALL=$loc kawa-osd "$ICON_VOL_2" volume 45;     eq "$(osd)" "$ICON_VOL_2|45|" "$loc"
  LC_ALL=$loc kawa-osd "$ICON_VOL_MUTE" volume 007 off; eq "$(osd)" "$ICON_VOL_MUTE|7|off" "$loc: leading zeros"
  LC_ALL=$loc kawa-osd "$ICON_VOL_2" volume 1500;   eq "$(osd)" "$ICON_VOL_2|999|" "$loc: above 999"
done

# ── no notice, ever ──────────────────────────────────────────────────────────
case_ "whatever the request — good, muted, a nonsense level, misuse, --help, no panel — no notice (notify-send, makoctl) and no process of the desktop: bash alone"
setup
kawa-osd "$ICON_VOL_2" volume 50; kawa-osd "$ICON_VOL_MUTE" volume 50 off; kawa-osd "$ICON_VOL_2" volume abc
kawa-osd 2>/dev/null; kawa-osd "" volume 50 2>/dev/null; kawa-osd --help >/dev/null
rm -f "$XDG_RUNTIME_DIR/kawa-panel.in"; kawa-osd "$ICON_VOL_2" volume 50
not_called '^notify-send'; not_called '^makoctl'; not_called '^kawa-panel'
eq "$(<"$CALLS")" "" "no program of the desktop was called at all"

done_
