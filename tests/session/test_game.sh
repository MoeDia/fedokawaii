#!/usr/bin/env bash
# tests/session/test_game.sh — quiet times and game mode: kawa-hush (notices held back during
# a screen share or a game, and the one notice after: how many, a click lists them), kawa-game
# (start and end: tuned's game profile, the game's priority, notices, night light, idle, the
# background jobs, all put back; run, auto, restore), and what setup writes for it: tuned's
# profile (tuned the one owner of CPU and card), and a polkit rule naming exactly its jobs.
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
fake_mako; kawa-hush on game; note hist 1 normal steam "friend online"; kawa-hush off game
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

# ── kawa-game ────────────────────────────────────────────────────────────────
game_world() {
  sandbox
  stub kawa-hush; stub kawa-night; stub logger; stub systemd-run; stub renice; stub ionice
  stub kawa-state '[ "$1" = get ] && [ -e "$TMP/auto" ] && { cat "$TMP/auto"; exit 0; }; [ "$1" = get ] && exit 1; exit 0'
  echo fedokawaii >"$TMP/profile"
  stub tuned-adm 'case $1 in active) echo "Current active profile: $(cat "$TMP/profile")" ;; profile) echo "$2" >"$TMP/profile" ;; esac'
  # systemctl: the timers' states from $TMP/sub.UNIT (waiting, elapsed); the report active or frozen
  stub systemctl 'case "$*" in
  *"show -p SubState --value "*)    for u; do :; done; cat "$TMP/sub.$u" 2>/dev/null ;;   # (the unit: the last word — ${*##* } strips each word on its own)
  *"show -p FreezerState --value "*) cat "$TMP/freezer" 2>/dev/null || echo running ;;
  *"is-active --quiet fedokawaii-report.service"*) [ -e "$TMP/report" ] || exit 1 ;;
esac'
  bash -c 'sleep 30 & sleep 30 & wait' & GAME=$!     # a "reaper" with two children
  on_exit "kill $GAME 2>/dev/null; pkill -P $GAME 2>/dev/null"
  sleep 0.2
}
case_ "a Steam game starts: tuned's game profile, the game and its children ahead, notices held, night light paused, idle held, waiting timers stopped, the report frozen"
game_world
echo waiting >"$TMP/sub.snapper-timeline.timer"; echo waiting >"$TMP/sub.fedokawaii-scrub.timer"
echo elapsed >"$TMP/sub.fedokawaii-kernels.timer"; touch "$TMP/report"
kawa-game start steam "$GAME"
eq "$(cat "$TMP/profile")" fedokawaii-game
called "^renice -n -5 -p $GAME [0-9]+ [0-9]+\$"; called "^ionice -c 2 -n 0 -p $GAME "
called '^kawa-hush on game$'; called '^kawa-night pause$'
called '^systemd-run --user .*--unit=kawa-game -- systemd-inhibit --what=idle .*sleep infinity$'
called '^systemctl --no-ask-password stop snapper-timeline.timer$'
called '^systemctl --no-ask-password stop fedokawaii-scrub.timer$'
not_called 'stop fedokawaii-kernels.timer'   # (done for this boot: started again it would run again)
not_called 'stop fstrim.timer'
called '^systemctl --no-ask-password freeze fedokawaii-report.service$'
eq "$(kawa-game)" "on (steam $GAME)"

case_ "a second start while on (a second bar's watch, a run): nothing more"
reset_calls; kawa-game start steam 1; kawa-game start run 1
not_called 'kawa-hush|renice|tuned'; eq "$(kawa-game)" "on (steam $GAME)"

case_ "it ends: the desktop's profile, the idle lock gone, the same timers started again, the report thawed, night light and notices back"
reset_calls; echo frozen >"$TMP/freezer"
kawa-game end
eq "$(cat "$TMP/profile")" fedokawaii
called '^systemctl --user stop kawa-game.service$'
called '^systemctl --no-ask-password start snapper-timeline.timer$'
called '^systemctl --no-ask-password start fedokawaii-scrub.timer$'
not_called 'start fstrim.timer'
called '^systemctl --no-ask-password thaw fedokawaii-report.service$'
called '^kawa-night restore$'; called '^kawa-hush off game$'
eq "$(kawa-game)" off
reset_calls; kawa-game end; not_called 'kawa-hush'   # (a second end: nothing)

case_ "auto off (kawa-state's gamemode): Steam's games get none; run still does"
game_world; echo off >"$TMP/auto"
kawa-game start steam "$GAME"; eq "$(kawa-game)" off; eq "$(cat "$TMP/profile")" fedokawaii
kawa-game auto on; called '^kawa-state set gamemode on$'

case_ "run: the game with game mode around it, its own exit status; Steam's game mode is not ended by it"
game_world
rc 3 kawa-game run sh -c 'exit 3'
called '^kawa-hush on game$'; called '^kawa-hush off game$'; eq "$(kawa-game)" off
kawa-game start steam "$GAME"; reset_calls
kawa-game run true; not_called 'kawa-hush off'; eq "$(kawa-game)" "on (steam $GAME)"

case_ "restore at login: a session that ended mid-game left the game's profile — the desktop's back; otherwise nothing"
game_world; echo fedokawaii-game >"$TMP/profile"; kawa-game restore; eq "$(cat "$TMP/profile")" fedokawaii
echo balanced >"$TMP/profile"; kawa-game restore; eq "$(cat "$TMP/profile")" balanced "a profile set by hand is left"

case_ "wrong use"
rc 2 kawa-game stop; rc 2 kawa-game start steam; rc 2 kawa-game start x 1; rc 2 kawa-game auto maybe; rc 2 kawa-game run

# ── what setup writes for game mode ──────────────────────────────────────────
fn=$(sed -n '/^game_mode() {/,/^}$/p' "$REPO/setup.sh")
case_ "tuned's game profile: the desktop's own (the CPU as it is), the AMD card's level by its PCI address; no gamemode anywhere"
has "$fn" "include=fedokawaii"; has "$fn" '/sys/bus/pci/devices/$pci/power_dpm_force_performance_level=high'
lacks "$fn" "gamemode.ini"; lacks "$fn" "governor"
grep -q '^PKG_GAMING=(.*gamemode' "$REPO/lib/manifest.sh" && _no "gamemode still in the manifest" || _ok
grep -qE '^ +gamemode +#' "$REPO/lib/manifest.sh" && _ok || _no "gamemode not retired"
grep -rq 'gamemoded\|gamemoderun' "$REPO/bin" "$REPO/setup.sh" "$REPO/configs" && _no "gamemode still called: $(grep -rl 'gamemoded\|gamemoderun' "$REPO/bin" "$REPO/setup.sh" "$REPO/configs")" || _ok

case_ "the polkit rule: the owner alone — tuned's profile switch, and exactly kawa-game's timers and report, start and stop"
rule=$(sed -n '/60-fedokawaii-game.rules <<RULES$/,/^RULES$/p' "$REPO/setup.sh")
mine=$(grep -oE '"[a-z-]+\.(timer|service)"' <<<"$rule" | tr -d '"' | sort | paste -sd' ')
want=$( { sed -n 's/^TIMERS=(\(.*\))$/\1/p' "$REPO/bin/kawa-game" | tr ' ' '\n'; sed -n 's/^REPORT=//p' "$REPO/bin/kawa-game"; } | sort | paste -sd' ')
eq "$mine" "$want" "the rule's units and kawa-game's"
command -v node >/dev/null && {
  js=$(sed '1d;$d' <<<"$rule" | sed 's/\$TARGET_USER/you/g')
  out=$(node -e '
var rules = [], polkit = { Result: { YES: "yes", NO: "no", NOT_HANDLED: "none" }, addRule: function (f) { rules.push(f); } };
'"$js"'
function ask(id, d, user) { return rules[0]({ id: id, lookup: function (k) { return d[k]; } }, { user: user }) || "none"; }
var M = "org.freedesktop.systemd1.manage-units";
console.log([ask("com.redhat.tuned.switch_profile", {}, "you"), ask("com.redhat.tuned.switch_profile", {}, "guest"),
  ask(M, { unit: "fstrim.timer", verb: "stop" }, "you"), ask(M, { unit: "fstrim.timer", verb: "stop" }, "guest"),
  ask(M, { unit: "sshd.service", verb: "start" }, "you"), ask(M, { unit: "fstrim.timer", verb: "restart" }, "you"),
  ask("org.freedesktop.login1.reboot", {}, "you")].join(" "));' 2>&1)
  eq "$out" "yes none yes none none none none" "profile switch and a held timer: the owner only; nothing else"
}

case_ "Steam's games: the session's watch (kawa-steam --watch) starts game mode once a game, ends it when none is left"
w=$(sed -n '/^  --watch)/,/^  --warm)/p' "$REPO/bin/kawa-steam")
has "$w" 'kawa-game start steam "$k" &'; has "$w" 'kawa-game end &'
has "$w" '<"$XDG_RUNTIME_DIR/kawa-game.on"'

done_
