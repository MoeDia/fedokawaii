#!/usr/bin/env bash
# tests/session/test_hush.sh — quiet times: kawa-hush (notices held back during a screen share
# or while the play world is in front, and the one notice after: how many, a click lists them).
. "$(dirname "$0")/../lib/harness.sh"

# mako, pretended: its modes in $TMP/mako.modes; makoctl list / history print the notices of
# $TMP/mako.list / mako.hist as makoctl's text form does
fake_mako() {
  sandbox
  : >"$TMP/mako.list"; : >"$TMP/mako.hist"; printf 'default\n' >"$TMP/mako.modes"
  stub makoctl 'M=$TMP/mako.modes
case $1 in
  list)    cat "$TMP/mako.list" ;;
  history) cat "$TMP/mako.hist" ;;
  mode)    case ${2:-} in
             -a) grep -qxF "$3" "$M" || echo "$3" >>"$M" ;;
             -r) grep -vxF "$3" "$M" >"$M.n"; mv "$M.n" "$M" ;;
             *)  cat "$M" ;;
           esac ;;
esac'
  stub pgrep 'exit 0'                                  # (mako runs)
  stub setsid '[ "$1" = -f ] && shift; "$@"'          # (the notice at once, in this test's time)
  stub notify-send 'echo "$*" >>"$TMP/notices"; [ -e "$TMP/click" ] && echo default; exit 0'
  stub kawa-menu 'cat >"$TMP/menu"'
}
# note FILE ID URGENCY APP TITLE [CATEGORY] — a notice as makoctl prints it
note() {
  { printf 'Notification %s: %s\n  App name: %s\n' "$2" "$5" "$4"
    [[ -n ${6:-} ]] && printf '  Category: %s\n' "$6"
    printf '  Urgency: %s\n' "$3"; } >>"$TMP/mako.$1"
}
modes() { paste -sd' ' "$TMP/mako.modes"; }

case_ "a share: the sharing mode on; at its end, the notices that came meanwhile counted — critical and level ones not"
fake_mako
note hist 7 normal brave "before the share"
kawa-hush on sharing; eq "$(modes)" "default sharing"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-hush.sharing")" 7 "the mark: the highest notice so far"
note hist 8 normal brave "a message"; note list 9 normal discord "a ping"
note hist 10 critical desktop "a drive pulled out"; note hist 11 normal osd "volume" osd
kawa-hush off sharing
eq "$(modes)" "default"
has "$(cat "$TMP/notices")" "2 notices while you shared"
[[ -e $XDG_RUNTIME_DIR/kawa-hush.sharing ]] && _no "the mark is left behind" || _ok

case_ "nothing came: no notice; one came: \"1 notice\""
fake_mako; kawa-hush on sharing; kawa-hush off sharing
[[ -e $TMP/notices ]] && _no "a notice about nothing: $(cat "$TMP/notices")" || _ok
fake_mako; kawa-hush on game; note hist 1 normal discord "friend online"; kawa-hush off game
has "$(cat "$TMP/notices")" "1 notice while you played"

case_ "a click on it lists them: a heading (the quiet bell, when), an info row each (title, app) — only read, nothing to choose"
fake_mako; touch "$TMP/click"
kawa-hush on sharing; note hist 3 normal brave "lunch?"; note list 4 normal discord "call me"; kawa-hush off sharing
m=$(cat "$TMP/menu")
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
has "$m" $'part\t'"$ICON_BELL_OFF"$'\twhile you shared'
has "$m" $'info\t'"$ICON_BELL"$'\tlunch?\t\tbrave'
has "$m" $'info\t'"$ICON_BELL"$'\tcall me\t\tdiscord'
eq "$(grep -c '^info	' <<<"$m")" 2 "each notice an info row (the cursor and the pointer pass it)"
eq "$(grep -vc -e '^part	' -e '^info	' <<<"$m")" 0 "no choice in it"

case_ "a share during a game: one quiet time — told once, at the end of the last, counting from the first"
fake_mako
kawa-hush on game; note hist 1 normal a "one"; kawa-hush on sharing; note hist 2 normal b "two"
kawa-hush off sharing
eq "$(modes)" "default game"; [[ -e $TMP/notices ]] && _no "told while the game still runs" || _ok
note hist 3 normal c "three"; kawa-hush off game
eq "$(modes)" "default"; has "$(cat "$TMP/notices")" "3 notices while you played"

case_ "an \"off\" without its \"on\" (the portal restarted): the mode cleared, nothing told"
fake_mako; note hist 5 normal a "old"; printf 'default\nsharing\n' >"$TMP/mako.modes"
kawa-hush off sharing; eq "$(modes)" default; [[ -e $TMP/notices ]] && _no "told of old notices" || _ok

case_ "wrong use"
fake_mako
rc 2 kawa-hush on; rc 2 kawa-hush on work; rc 2 kawa-hush tell game x

done_
