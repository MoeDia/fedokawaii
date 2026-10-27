#!/usr/bin/env bash
# tests/menus/test_steam.sh — kawa-steam closing Steam properly (--quit: Steam's own
# -shutdown, which sends the games' saves to Steam Cloud first, waited for and written to the
# journal) and its guard for the session (--guard: logind's delay lock on shutdown, the quit
# done when logind says the computer is about to stop). steam, pgrep, logger, gdbus and
# systemd-inhibit are stand-ins: the fake Steam runs while $TMP/steam-up exists and leaves
# $STEAM_TAKES seconds after it is asked to quit.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
setup() {
  menus_sandbox
  stub steam 'case "$1" in -shutdown) (sleep "${STEAM_TAKES:-0.3}"; [ -e "$TMP/steam-stays" ] || rm -f "$TMP/steam-up") >/dev/null 2>&1 & ;; esac'
  stub pgrep 'case "$*" in "-xu '"$UID"' steam") [ -e "$TMP/steam-up" ]; exit $? ;; esac; exit 1'
  stub logger; stub makoctl; stub notify-send 'echo 42'
  : >"$TMP/steam-up"
}
journal() { grep '^logger -t kawa-steam -- ' "$CALLS" | sed 's/^logger -t kawa-steam -- //'; }

case_ "--quit, Steam running: asked as its own Exit asks (steam -shutdown), waited for, the journal says how long"
setup; rc 0 kawa-steam --quit logout
called '^steam -shutdown$'
[[ ! -e $TMP/steam-up ]] && _ok || _no "returned before Steam was gone"
has "$(journal)" "asking Steam to quit (logout): it sends your saves to Steam Cloud first"
[[ $(journal | tail -n 1) =~ ^asked\ Steam\ to\ quit\ \(logout\),\ done\ in\ 0\.[0-9]\ s$ ]] && _ok || _no "the journal's last line: $(journal | tail -n 1)"
case_ "…a notice meanwhile, taken away once Steam is gone"
called '^notify-send -a desktop -p -t 0 -- .*Steam closing — your saves go to Steam Cloud first$'; called '^makoctl dismiss -n 42$'
case_ "--quit, Steam not running: nothing asked, nothing said"
setup; rm "$TMP/steam-up"; rc 0 kawa-steam --quit logout
not_called '^steam'; eq "$(journal)" ""
case_ "--quit, Steam still running after the wait: could not (1), the journal says so"
setup; : >"$TMP/steam-stays"; KAWA_STEAM_QUIT_WAIT=1 kawa-steam --quit shutdown; eq "$?" 1
eq "$(journal | tail -n 1)" "Steam still runs 1 s after it was asked to quit (shutdown) — left as it is"
case_ "the gamepad menu's quit Steam: the same proper close"
setup; answer "pick quit Steam"; kawa-steam --menu; called '^steam -shutdown$'; has "$(journal)" "(menu), done in"
case_ "the gamepad menu: the gamepad icon and Steam, a row a page, start with the desktop as a check, a dropdown sized to its content"
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
setup; answer esc; kawa-steam --menu
eq "$(fz_rows | tr '\n' '|')" "part	$ICON_GAMEPAD	Steam|row	$ICON_FOLDER	library|row	$ICON_DOWNLOAD	downloads|row	$ICON_USER	friends|row	$ICON_SLIDERS	settings|row	▣	start with the desktop|row	$ICON_POWER	quit Steam|"
eq "$(fz_arg drop)" set; eq "$(fz_arg select)" 1; eq "$(fz_arg width)" ""; fits
case_ "…start with the desktop picked: off now, the check empty the next time"
answer "pick start with the desktop"; kawa-steam --menu
answer esc; kawa-steam --menu; has "$(fz_rows)" "row	□	start with the desktop"
case_ "…library: Steam's own page"
answer "pick library"; kawa-steam --menu; called '^steam steam://open/games$'

case_ "--guard: a delay lock on shutdown for the session; logind's warning (PrepareForShutdown true) closes Steam, then the lock goes"
setup
stub systemd-inhibit 'while [ "${1#--}" != "$1" ]; do shift; done; exec "$@"'
stub gdbus 'printf "%s\n" "/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)" "/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForShutdown (true,)"; echo $$ >"$TMP/gdbus.pid"; exec sleep 30'
rc 0 timeout 10 kawa-steam --guard
called '^systemd-inhibit --what=shutdown --mode=delay --who=Steam --why=Steam sends your saves to Steam Cloud before the computer stops .*kawa-steam --guard-wait$'
called '^gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1$'
has "$(journal)" "asked Steam to quit (shutdown), done in"
[[ $(grep -c '^steam -shutdown' "$CALLS") == 1 ]] && _ok || _no "a sleep's warning closed Steam too"
case_ "…the wait for logind's word never outlives the guard"
waitfor() { local i; for ((i = 0; i < 40; i++)); do "$@" && return 0; /bin/sleep 0.05; done; return 1; }
# (this run's monitor by its pid: another test run's sleep is none of this one's business)
gpid=$(cat "$TMP/gdbus.pid" 2>/dev/null); [[ -n $gpid ]] && _ok || _no "the monitor never started"
waitfor eval '! kill -0 "$gpid" 2>/dev/null' && _ok || _no "gdbus monitor left running"
case_ "--guard with no Steam installed: nothing held"
setup; stub systemd-inhibit; PATH=$(without steam) kawa-steam --guard; eq "$?" 0; not_called '^systemd-inhibit'

# Steam Cloud: the owner's log (Blasphemous, 774361: its cloud saves made on Windows, skipped
# "to our platform" by the Linux build; its upload failing on a file of the Windows folders)
cloud_fixture() {
  D=$HOME/.local/share/Steam
  mkdir -p "$D/logs" "$D/config" "$D/steamapps" "$D/compatibilitytools.d/GE-Proton10-9" "$D/compatibilitytools.d/GE-Proton10-25" "$D/userdata/433254525/774361"
  cat >"$D/logs/cloud_log.txt" <<'E'
[2026-10-20 04:20:54] [AppID 620] Upload complete, result OK
[2026-10-20 04:22:53] [AppID 774361] Skipping download of file TheGameKitchen/Blasphemous/Savegames/76561198393520253/savegame_0.save to our platform
[2026-10-20 04:22:53] [AppID 774361] Need to upload file .config/unity3d/TheGameKitchen/Blasphemous/Savegames/76561198393520253/app_settings
[2026-10-20 04:22:54] [AppID 774361] Upload complete, result I/O Operation Failed
[2026-10-20 04:23:52] [Roaming Config] PerformSyncCloud - all sync'd up
E
  printf '"AppState"\n{\n\t"appid"\t\t"774361"\n\t"name"\t\t"Blasphemous"\n}\n' >"$D/steamapps/appmanifest_774361.acf"
  printf '"InstallConfigStore"\n{\n\t"Software"\n\t{\n\t\t"Valve"\n\t\t{\n\t\t\t"Steam"\n\t\t\t{\n\t\t\t\t"BaseInstallFolder_1"\t\t"C:\\\\x"\n\t\t\t\t"CompatToolMapping"\n\t\t\t\t{\n\t\t\t\t\t"0"\n\t\t\t\t\t{\n\t\t\t\t\t\t"name"\t\t"proton_experimental"\n\t\t\t\t\t\t"config"\t\t""\n\t\t\t\t\t\t"priority"\t\t"75"\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n}\n' >"$D/config/config.vdf"
  echo cache >"$D/userdata/433254525/774361/remotecache.vdf"
}
case_ "--cloud: a line a game from Steam's cloud_log — the last upload, and saves made on Windows that the Linux build never reads; 1 on either"
setup; cloud_fixture; out=$(kawa-steam --cloud); eq "$?" 1
has "$out" "AppID 620 (620): last upload 2026-10-20 04:20:54: OK"
has "$out" "Blasphemous (774361): last upload 2026-10-20 04:22:54: FAILED (I/O Operation Failed) · its cloud saves were made on Windows and it runs here as its Linux build: they never cross"
case_ "--cloud-fix, Steam running: refused (Steam rewrites its config as it closes)"
rc 1 kawa-steam --cloud-fix; lacks "$(cat "$D/config/config.vdf")" GE-Proton
case_ "--cloud-fix, Steam closed: the game runs with the newest GE-Proton (config.vdf), its sync state starts afresh, the journal says so"
rm "$TMP/steam-up"; rc 0 kawa-steam --cloud-fix
v=$(cat "$D/config/config.vdf")
has "$v" $'\t\t\t\t\t"774361"\n\t\t\t\t\t{\n\t\t\t\t\t\t"name"\t\t"GE-Proton10-25"\n\t\t\t\t\t\t"config"\t\t""\n\t\t\t\t\t\t"priority"\t\t"250"\n\t\t\t\t\t}'
has "$v" $'"name"\t\t"proton_experimental"'; has "$v" $'"BaseInstallFolder_1"\t\t"C:\\\\x"'
[[ ! -e $D/userdata/433254525/774361/remotecache.vdf ]] && compgen -G "$D/userdata/433254525/774361/remotecache.vdf.fedokawaii-*" >/dev/null && _ok || _no "remotecache.vdf not moved aside"
has "$(journal)" "cloud: Blasphemous (774361) keeps its cloud saves in Windows' folders — set to run with GE-Proton10-25"
case_ "…--cloud then: fine (0) — the failure was before the fix, the saves are used"
out=$(kawa-steam --cloud); eq "$?" 0; has "$out" "it runs with GE-Proton10-25, so it uses them"
case_ "…once: set back to native by hand, it stays; a retired GE-Proton moves to the newest"
cp "$D/config/config.vdf" "$TMP/cfg"; : >"$CALLS"; rc 0 kawa-steam --cloud-fix; eq "$(journal)" ""; cmp -s "$D/config/config.vdf" "$TMP/cfg" && _ok || _no "config rewritten for nothing"
rm -r "$D/compatibilitytools.d/GE-Proton10-25"; rc 0 kawa-steam --cloud-fix
has "$(journal)" "cloud: Blasphemous (774361) moved from GE-Proton10-25 (gone) to GE-Proton10-9"
case_ "--quit: the uploads Steam made while it closed go to the journal, then the fix"
setup; cloud_fixture
stub steam 'case "$1" in -shutdown) (sleep 0.3; printf "[%s] [AppID 620] Upload complete, result OK\n" "$(date "+%Y-%m-%d %H:%M:%S")" >>"$HOME/.local/share/Steam/logs/cloud_log.txt"; rm -f "$TMP/steam-up") >/dev/null 2>&1 & ;; esac'
rc 0 kawa-steam --quit logout
has "$(journal)" "cloud: AppID 620 (620) upload OK"
lacks "$(journal)" "upload failed"
has "$(journal)" "cloud: Blasphemous (774361) keeps its cloud saves in Windows' folders"

case_ "misuse (2); --help (0)"
setup; rc 2 kawa-steam --frobnicate
has "$(kawa-steam --help)" "kawa-steam --quit [WHY]"
case_ "--bar-watch (what the bar runs): off, starting, ready, in a game — read from /proc, no process started; lit while its dropdown is open"
setup; rm -f "$STUBS/pgrep"; mkdir -p "$TMP/fs"
cp /bin/sleep "$TMP/fs/steamwebhelper"; printf '#!/bin/bash\nsleep 20\n' >"$TMP/fs/reaper"; chmod 755 "$TMP/fs/reaper"
printf '#!/bin/bash\n%s/steamwebhelper 20 & wait\n' "$TMP/fs" >"$TMP/fs/steamwebhelper.sh"; chmod 755 "$TMP/fs/steamwebhelper.sh"
printf '#!/bin/bash\nif [ "$1" = deep ]; then %s/steamwebhelper.sh & elif [ "$1" != bare ]; then %s/steamwebhelper 20 & fi\nif [ "$1" = game ]; then %s/reaper SteamLaunch AppId=42 & fi\nsleep 20 & wait\n' "$TMP/fs" "$TMP/fs" "$TMP/fs" >"$TMP/fs/steam"; chmod 755 "$TMP/fs/steam"
watch1() { timeout 3 kawa-steam --bar-watch 2>/dev/null | head -n 1; }
up() {   # up PID N — the fake Steam named so, with N children of its own (a loaded machine: up to 10 s)
  for _ in $(seq 100); do [[ $(cat "/proc/$1/comm" 2>/dev/null) == steam && $(cat /proc/"$1"/task/*/children 2>/dev/null | wc -w) -ge $2 ]] && return; sleep 0.1; done; }
rm -f "$HOME/.steampid"; eq "$(watch1)" '{"text":""}' "no Steam: hidden"
for m in bare ready game deep; do   # (deep: the web helper under a wrapper — the Steam Runtime's — as on Fedora)
  n=2; [[ $m == bare ]] && n=1; [[ $m == game ]] && n=3
  "$TMP/fs/steam" "$m" & sp=$!; echo "$sp" >"$HOME/.steampid"; up "$sp" "$n"; [[ $m == deep ]] && sleep 0.5
  o=$(watch1); kill "$sp" 2>/dev/null; pkill -P "$sp" 2>/dev/null; pkill -x steamwebhelper 2>/dev/null; wait "$sp" 2>/dev/null
  case $m in bare) has "$o" '"class":"starting"' ;; ready|deep) has "$o" '"class":"ready"' ;; game) has "$o" '"class":"game"' ;; esac
done
"$TMP/fs/steam" ready & sp=$!; echo "$sp" >"$HOME/.steampid"; up "$sp" 2; sleep 30 & dp=$!
printf '%s kawa-steam\n' "$dp" >"$XDG_RUNTIME_DIR/kawa-drop.open"
o=$(watch1); has "$o" '"class":["ready","active"]'; lacks "$o" tooltip "lit: no tooltip"
rm -f "$XDG_RUNTIME_DIR/kawa-drop.open"; kill "$dp" "$sp" 2>/dev/null; pkill -P "$sp" 2>/dev/null
echo 99999999 >"$HOME/.steampid"; eq "$(watch1)" '{"text":""}' "a pid file left by a Steam gone: hidden"

done_
