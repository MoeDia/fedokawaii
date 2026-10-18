#!/usr/bin/env bash
# tests/status/test_osd.sh — kawa-osd, the level display of the volume, microphone and
# brightness keys: one panel that updates in place (mako's replace id, kept in
# $XDG_RUNTIME_DIR/kawa-osd-id), a 20-column wedge and a fixed-width value. The notice
# daemon is lib.sh's fake: ids handed out as mako does.
. "$(dirname "$0")/lib.sh"
setup() { box; notices; . "$HOME/.config/fedokawaii/icons.sh"; }
ID() { cat "$XDG_RUNTIME_DIR/kawa-osd-id" 2>/dev/null; }

# ── what it shows ────────────────────────────────────────────────────────────
case_ "70 %: the label, 14 of 20 columns lit, the number; app and category 'osd' (mako's rule)"
setup
rc 0 kawa-osd "$ICON_SUN" brightness 70
eq "$(osd)" "1|$ICON_SUN  brightness|70%|14/20"
called 'notify-send -a osd -c osd -u low -h int:transient:1 -p'
eq "$(ID)" 1 "the id kept for the next press"

case_ "the wedge: 0 % dark, 1–5 % one column, 96–100 % all twenty"
for p in 0:0 1:1 5:1 6:2 50:10 95:19 96:20 100:20; do
  kawa-osd "$ICON_SPEAKER" volume "${p%:*}"
  eq "$(osd | cut -d'|' -f3-)" "${p%:*}%|${p#*:}/20" "at ${p%:*} %"
done

case_ "above 100 % (only the mixer goes there): the wedge full, the real number"
kawa-osd "$ICON_SPEAKER" volume 150
eq "$(osd | cut -d'|' -f3-)" "150%|20/20"
has "$(tail -n 1 "$NOTIFY_STATE/log")" "<span color='#$(. "$HOME/.config/fedokawaii/current/colors.sh"; echo "$C_ACCENT")'>$ICON_EQ_5</span>" \
  "the top column still lit as the peak lamp"
kawa-osd "$ICON_SPEAKER" volume 1000
eq "$(osd | cut -d'|' -f3-)" "999%|20/20" "three digits at most: the panel never widens"

case_ "muted: 'off', nothing lit"
kawa-osd "$ICON_SPEAKER_OFF" volume 40 off
eq "$(osd | cut -d'|' -f2-)" "$ICON_SPEAKER_OFF  volume|off|0/20"

case_ "a level that is not a number: 0, still a well-formed panel"
for p in "" abc -5 4.5 '$(id)' '<b>'; do
  kawa-osd "$ICON_SUN" brightness "$p"
  eq "$(osd | cut -d'|' -f3-)" "0%|0/20" "level [$p]"
done

case_ "the value is always the same width: '  5%', ' 70%', '100%', ' off'"
setup
for p in 5 70 100; do kawa-osd "$ICON_SUN" brightness "$p"; done; kawa-osd "$ICON_SUN" brightness 5 off
v=$(sed -n 's/^NOTICE .*Fusion Pixel 12px Mono ja 24px.> \(.*\)<\/span>$/\1/p' "$NOTIFY_STATE/log" \
    | sed -e 's/<[^>]*>//g')
eq "$(printf '%s\n' "$v" | awk '{ print length($0) }' | sort -u)" 4 "every value 4 characters: [$(tr '\n' '|' <<<"$v")]"

case_ "the theme's colours (light); no theme set up: no panel in made-up colours, a failure"
setup; ln -sfn themes/light "$HOME/.config/fedokawaii/current"
. "$HOME/.config/fedokawaii/themes/light/colors.sh"
kawa-osd "$ICON_SUN" brightness 50
has "$(tail -n1 "$NOTIFY_STATE/log")" "color='#$C_TEAL'"
rm "$HOME/.config/fedokawaii/current"; n=$(wc -l <"$NOTIFY_STATE/log")
kawa-osd "$ICON_SUN" brightness 50 2>/dev/null && _no "exit 0 without a theme" || _ok
eq "$(wc -l <"$NOTIFY_STATE/log")" "$n" "nothing shown"

# ── one panel, updated in place ──────────────────────────────────────────────
case_ "a held key (20 presses): one panel, replaced in place — never a second one"
setup
for i in {1..20}; do kawa-osd "$ICON_SPEAKER" volume $((i * 5)); done
eq "$(cut -d' ' -f2 "$NOTIFY_STATE/log" | sort -u)" 1 "every update went to notice 1"
eq "$(grep -c -- '-r 1 ' "$CALLS")" 19 "19 replaced it"
eq "$(osd | cut -d'|' -f3)" "100%" "the last level shown"

case_ "20 at once (overlapping runs): still one panel"
setup
for i in {1..20}; do kawa-osd "$ICON_SPEAKER" volume $((i * 5)) & done; wait
eq "$(cut -d' ' -f2 "$NOTIFY_STATE/log" | sort -u)" 1 "every update went to notice 1"

case_ "mako restarted (the kept id is gone): a new panel, and that id kept"
setup
kawa-osd "$ICON_SUN" brightness 10; kawa-osd "$ICON_SUN" brightness 20
: >"$NOTIFY_STATE/live"                                   # the daemon forgot every notice
kawa-osd "$ICON_SUN" brightness 30
eq "$(ID)" 2 "the new id"; eq "$(osd | cut -d'|' -f1,3)" "2|30%"
kawa-osd "$ICON_SUN" brightness 40
eq "$(osd | cut -d'|' -f1)" 2 "the next press replaces the new one"

case_ "a corrupt id file: a fresh panel, and the file is good again"
for junk in "" abc -1 "12 34" 0 007 99999999999 4294967296 2147483648 $'5\n6' "$(printf 'x%.0s' {1..5000})"; do
  setup; printf '%s' "$junk" >"$XDG_RUNTIME_DIR/kawa-osd-id"
  kawa-osd "$ICON_SUN" brightness 60
  eq "$(osd | cut -d'|' -f3)" "60%" "shown with id file [${junk:0:20}]"
  [[ $(ID) =~ ^[1-9][0-9]*$ ]] && _ok || _no "id file [${junk:0:20}] became [$(ID)]"
done

case_ "a stale lock from a run that was killed: no wait, no hang"
setup; : >"$XDG_RUNTIME_DIR/kawa-osd-id.lock"
s=$EPOCHREALTIME; kawa-osd "$ICON_SUN" brightness 60
eq "$(osd | cut -d'|' -f3)" "60%"
(( ${EPOCHREALTIME/./} - ${s/./} < 900000 )) && _ok || _no "took over 0.9 s"

case_ "mako not running: nothing shown, the id file left alone (not the '0' notify-send prints)"
setup; echo 7 >"$XDG_RUNTIME_DIR/kawa-osd-id"
NOTIFY_DOWN=1 kawa-osd "$ICON_SUN" brightness 60
eq "$(ID)" 7
eq "$(osd)" "" "no notice"
case_ "… and once it runs again, the panel comes back"
kawa-osd "$ICON_SUN" brightness 70
eq "$(osd | cut -d'|' -f3)" "70%"

case_ "a slow notice daemon: a run waits at most a second for the one before, then gives up"
setup; echo 1 >"$NOTIFY_STATE/n"; echo 1 >"$NOTIFY_STATE/live"; echo 1 >"$XDG_RUNTIME_DIR/kawa-osd-id"
NOTIFY_SLOW=3 kawa-osd "$ICON_SUN" brightness 10 & slow=$!
waitfor 2 grep -q 'notify-send' "$CALLS"
s=$EPOCHREALTIME; rc 0 kawa-osd "$ICON_SUN" brightness 20
(( ${EPOCHREALTIME/./} - ${s/./} < 1600000 )) && _ok || _no "the second run waited past 1.6 s"
kill "$slow" 2>/dev/null; wait "$slow" 2>/dev/null

# ── misuse, environment ──────────────────────────────────────────────────────
case_ "--help: what it does, nothing shown; too few arguments: misuse"
setup
out=$(kawa-osd --help); r=$?
eq "$r" 0; has "$out" "kawa-osd ICON LABEL PERCENT"; eq "$(osd)" ""
rc 2 kawa-osd
rc 2 kawa-osd "$ICON_SUN" brightness
eq "$(osd)" "" "nothing shown for misuse"

case_ "XDG_RUNTIME_DIR unset: could not (1), nothing written elsewhere"
setup
( unset XDG_RUNTIME_DIR; kawa-osd "$ICON_SUN" brightness 50 ) 2>/dev/null; eq "$?" 1

case_ "HOME with a space in it: the theme's colours still found"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"
kawa-osd "$ICON_SUN" brightness 50
has "$(tail -n 1 "$NOTIFY_STATE/log")" "color='#$(. "$HOME/.config/fedokawaii/current/colors.sh"; echo "$C_TEAL")'"
eq "$(osd | cut -d'|' -f3)" "50%"

case_ "Turkish and Arabic locales: the same panel"
setup
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  locale_ok "$loc" || { skip "no $loc here"; continue; }
  LC_ALL=$loc kawa-osd "$ICON_SUN" brightness 45 2>/dev/null
  eq "$(osd | cut -d'|' -f3-)" "45%|9/20" "$loc"
done

done_
