#!/usr/bin/env bash
# lib/common.sh — shared by every script: output, reporting, retries, steps,
# user context, hardened downloads, config validation, locking, temp cleanup.
umask 022

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m' C_GOLD=$'\e[33m' C_RED=$'\e[31m' C_OK=$'\e[32m' C_DIM=$'\e[2m' C_BOLD=$'\e[1m'
else
  C_RESET='' C_GOLD='' C_RED='' C_OK='' C_DIM='' C_BOLD=''
fi
LOG_FILE=${LOG_FILE:-/var/log/fedokawaii.log}
# the logs record every command with its output: root's alone
if [[ $EUID -eq 0 && $LOG_FILE == /var/log/* ]]; then
  [[ -e $LOG_FILE ]] || : >"$LOG_FILE"
  chmod 600 "$LOG_FILE" 2>/dev/null || true
fi

_ts()  { date '+%H:%M:%S'; }
# (each joins its words with spaces: the scripts' IFS is newline + tab)
# (a log that cannot be written — a full disk — never stops a run: the line still shows, so
# the run gets as far as saying why, such as need_space's "only … free")
_out() { printf '%s\n' "$1" | tee -a "$LOG_FILE" 2>/dev/null || true; }
log()  { local IFS=' '; _out "${C_DIM}$(_ts)${C_RESET} ${C_GOLD}▸${C_RESET} $*"; }
ok()   { local IFS=' '; _out "${C_DIM}$(_ts)${C_RESET} ${C_OK}✔${C_RESET} $*"; }
die()  { local IFS=' '; _out "${C_DIM}$(_ts)${C_RESET} ${C_RED}✘ $*${C_RESET}" >&2; exit 1; }   # (stderr: never swallowed by a $( ))
hdr()  { local IFS=' '; _out ""; _out "${C_BOLD}${C_GOLD}── $* ${C_RESET}"; }

# A command that run or retry saw fail is remembered (FAILED_CMD, with where it was called
# from: FAILED_AT), so the scripts' error report names it: the line the report would see is
# the helper's own last one — its return — never the command that failed.
FAILED_CMD="" FAILED_AT="" FAILED_SHOW=""
# failed_what FUNCTION:LINE — for an ERR trap, where it fired: the command to name (FAILED_SHOW)
# shellcheck disable=SC2034  # FAILED_SHOW is read by the scripts' ERR traps
failed_what() {
  FAILED_SHOW=$BASH_COMMAND
  if [[ $BASH_COMMAND == return* && -n $FAILED_CMD && $1 == "$FAILED_AT" ]]; then FAILED_SHOW=$FAILED_CMD; fi
  return 0
}

# run CMD… — echo + log the command; its status is the command's status (the log is never
# what stops a run: a log that cannot be written is no failure of the command)
run() {
  local IFS=' ' rc=0
  FAILED_CMD=""
  _out "${C_DIM}$(_ts) \$ $*${C_RESET}"
  { RUN_SHOWN=1 "$@" 2>&1 | tee -a "$LOG_FILE"; rc=${PIPESTATUS[0]}; } || true
  ((rc == 0)) || FAILED_CMD=$* FAILED_AT=${FUNCNAME[1]:-main}:${BASH_LINENO[0]}
  return "$rc"
}

# retry N PAUSE CMD… — for network-bound commands
retry() {
  local n=$1 pause=$2 i IFS=' '; shift 2
  FAILED_CMD=""
  for ((i = 1; i <= n; i++)); do
    "$@" && return 0
    ((i < n)) || break                  # (the last try: given up at once, no pause for nothing)
    log "attempt $i/$n failed: $* — retrying in ${pause}s"; sleep "$pause"
  done
  log "attempt $n/$n failed: $*"
  FAILED_CMD=$* FAILED_AT=${FUNCNAME[1]:-main}:${BASH_LINENO[0]}
  return 1
}

# HTTPS only, TLS ≥ 1.2, bounded connect time, retries on transient errors, and a transfer
# that stalls (under 1 KB/s for a minute) given up rather than waited on for ever
# shellcheck disable=SC2034  # used by setup.sh and lib/upstream.sh
CURL=(curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 15 --retry 3 --retry-delay 5 --speed-limit 1024 --speed-time 60)

dnf_install()   { retry 3 10 dnf -y install "$@"; }
pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }                # installed under exactly this name
pkg_provided()  { rpm -q --whatprovides "$1" >/dev/null 2>&1; }  # …or by a package renamed since (Fedora keeps the old name as a Provides)

# ── report helpers (check.sh, verify.sh) ────────────────────────────────────
PASS=0 FAILS=() WARNS=()
section() { _out ""; _out "${C_BOLD}${C_GOLD}$1${C_RESET}"; }
pass()    { PASS=$((PASS + 1)); _out "  ${C_OK}✔${C_RESET} $1"; }
fail()    { FAILS+=("$1${2:+ — $2}"); _out "  ${C_RED}✘ $1${2:+ — $2}${C_RESET}"; }
warn()    { WARNS+=("$1${2:+ — $2}"); _out "  ${C_GOLD}! $1${2:+ — $2}${C_RESET}"; }
info()    { _out "  ${C_DIM}·${C_RESET} $1"; }
check()   { local label=$1; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }
summary() {                     # summary VERB → prints the verdict; returns 1 on any failure
  _out ""
  if ((${#FAILS[@]} == 0)); then
    _out "${C_BOLD}${C_OK}✔ $1 — $PASS checks passed${WARNS:+, ${#WARNS[@]} warning(s)}${C_RESET}"; return 0
  fi
  _out "${C_BOLD}${C_RED}✘ ${#FAILS[@]} of $((PASS + ${#FAILS[@]})) checks failed:${C_RESET}"
  printf '    %s\n' "${FAILS[@]}" | tee -a "$LOG_FILE"; return 1
}

# ── idempotent steps: completion recorded in $STATE_DIR, re-runs skip them ──
STATE_DIR=${STATE_DIR:-/var/lib/fedokawaii}
step() {
  local name=$1 fn=$2 mark
  mark="$STATE_DIR/done.${name//\//-}"          # a "/" in a label must not become a folder
  if [[ -f $mark ]]; then log "skip (done): $name"; return 0; fi
  hdr "$name"
  "$fn"
  mkdir -p "$STATE_DIR"; touch "$mark"
  ok "$name"
}

# ── target user (exported by the caller: TARGET_USER/HOME/UID/GID) ───────────
as_user() {
  runuser -u "$TARGET_USER" -- env -i \
    HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" SHELL=/bin/bash LANG="${LANG:-C.UTF-8}" \
    PATH="$TARGET_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
    "$@"
}

# prune_theme_backups [AS…] — theme.sh's backup folders (one per run that replaced something,
# named for its time: YYYYMMDD-HHMMSS) past the newest ten removed, by AS (as_user from root:
# in your home root never deletes through a path you could have made a link; nothing when the
# caller is you already). Only folders named so: anything else there is left alone.
# → how many were removed
THEME_BACKUPS_KEPT=10
prune_theme_backups() {
  local f=$TARGET_HOME/.local/state/fedokawaii/backup d n=0
  if [[ -d $f && ! -L $f ]]; then
    while IFS= read -r d; do
      "$@" rm -rf --one-file-system -- "$f/$d" && n=$((n + 1))
    done < <("$@" find "$f" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended \
               -regex '.*/[0-9]{8}-[0-9]{6}' -printf '%f\n' | sort -r | tail -n +$((THEME_BACKUPS_KEPT + 1)))
  fi
  echo "$n"
}

# pw_steady — PipeWire and WirePlumber run, and keep running: the same PipeWire process 3 s
# later (one that crashes at every start is "active" for a moment between crashes; verify and
# repair both ask this). 0 steady · 1 not
pw_steady() {
  local a b
  as_user systemctl --user start pipewire.socket pipewire.service wireplumber.service >/dev/null 2>&1
  a=$(as_user systemctl --user show -p MainPID --value pipewire.service 2>/dev/null)
  [[ $a =~ ^[1-9][0-9]*$ ]] || return 1
  sleep 3
  b=$(as_user systemctl --user show -p MainPID --value pipewire.service 2>/dev/null)
  [[ $b == "$a" ]] && as_user systemctl --user is-active --quiet pipewire.service wireplumber.service
}

# The files repair set aside because they broke something (one PipeWire crashed on at every
# start): "SHA256 PATH-IN-HOME" lines. theme.sh leaves such a file out while the repo carries
# that very version of it — a new version is tried again.
set_aside_list() { echo "$TARGET_HOME/.local/state/fedokawaii/set-aside.list"; }
set_aside() {   # set_aside REL REPO-FILE → 0 when that version of REL was set aside
  local l; l=$(set_aside_list)
  [[ -r $l ]] && grep -qxF "$(sha256sum <"$2" | cut -c1-64) $1" "$l"
}

# user_put MODE DEST < CONTENT — a file in the user's home, written by the user: never by
# root, so a link planted there can never steer root's write to a file of the system's.
# Written beside it, then renamed over it in one step (a link in its place is replaced, not
# followed). The content arrives on stdin, read by cat — reopening /dev/stdin as the user
# would be refused, root's pipe or file not being the user's to open.
# shellcheck disable=SC2016  # expanded by the inner bash
USER_PUT_SH='t=$(mktemp "${2%/*}/.${2##*/}.XXXXXX") || exit 1
  if cat >"$t" && chmod "$1" "$t" && mv -fT -- "$t" "$2"; then exit 0; fi
  rm -f -- "$t"; exit 1'
user_put() { as_user bash -c "$USER_PUT_SH" _ "$1" "$2"; }

write_file() {                      # write_file PATH [MODE] < content — never half-written:
  local t                           # beside it first, then renamed over it in one step
  # (a folder that is missing is made; one that is there keeps its mode — install -d would reset it)
  [[ -d $(dirname "$1") ]] || install -d -m 0755 "$(dirname "$1")"
  t=$(mktemp "$(dirname "$1")/.${1##*/}.XXXXXX") || return 1
  if cat >"$t" && chmod "${2:-0644}" "$t" && mv -fT -- "$t" "$1"; then return 0; fi
  rm -f -- "$t"; return 1
}

# ── dwl's own copy of wlroots ─────────────────────────────────────────────────
# dwl is built for one wlroots (DWL_WLROOTS). Fedora moves to newer ones over the years and
# its package of the old one goes — which would leave dwl unable to start. So the first
# build keeps Fedora's own build of it in /usr/local/lib/fedokawaii-wlroots-VERSION: the
# library, its headers, and the young libraries it uses that may change their names between
# releases (libdisplay-info, libliftoff, xcb-errors); dwl is linked to that copy. A later
# Fedora's wlroots never touches dwl, and dwl can still be built again (Theme) against the
# copy. Everything else it uses keeps its name for years (Wayland, libinput, Mesa,
# xkbcommon, pixman, libseat, udev, xcb) — and before a move to a new Fedora, the move
# checks that the new release has every one of them (setup.sh, libs_ready).
# the project's own top level: what a clone or download of it holds (tests/static checks it
# against the repository), so that setup's end can tell the project's files from yours
# shellcheck disable=SC2034  # (setup.sh reads it)
PROJECT_TOP=(PACKAGES.md README.md art bin check.sh configs docs fedokawaii.conf fedokawaii.sh
             lib setup.sh src system tests theme.sh tools verify.sh .git .gitignore .gitattributes)
# the boot's own arguments, on every boot entry (setup.sh's s_quiet_boot puts them there,
# verify.sh checks them): the splash (rhgb), and nothing else on the screen from the power
# button to the login — the kernel's messages only when they are critical (quiet loglevel=3;
# the initramfs' udev likewise), no systemd status lines, no blinking cursor on the console
# the login screen shares (tty1); and no console-size wait at boot. The journal keeps it all
# shellcheck disable=SC2034  # (setup.sh and verify.sh read it)
BOOT_ARGS=(rhgb quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=false vt.global_cursor_default=0
           systemd.tty.term.console=dumb)
# an AMD card's: LACT's clocks, voltages and fan curves need OverDrive (bit 14), which amdgpu
# leaves off: its default mask (0xfff7bfff) plus that bit. Not 0xffffffff — that also switches
# on GFX DCS (bit 19), which amdgpu keeps off as unstable (flicker, hangs on some cards).
# (setup.sh puts it on every boot entry, verify.sh checks this exact value)
# shellcheck disable=SC2034  # (setup.sh and verify.sh read it)
AMDGPU_ARG=amdgpu.ppfeaturemask=0xfff7ffff
wlr_home() { echo "/usr/local/lib/fedokawaii-wlroots-$DWL_WLROOTS"; }   # (beside the toolkit, never inside: a new toolkit replaces that folder whole)
wlr_kept() {
  local h; h=$(wlr_home)
  [[ -s $h/lib/libwlroots-$DWL_WLROOTS.so && -s $h/cflags && -d $h/include/wlroots-$DWL_WLROOTS ]]
}
wlr_keep() {   # (root) Fedora's wlroots copied, once — 1: neither the copy nor the package is there
  local v=$DWL_WLROOTS h inc lib tmp so path
  wlr_kept && return 0
  h=$(wlr_home)
  pkg-config --exists "wlroots-$v" || return 1
  inc=$(pkg-config --variable=includedir "wlroots-$v")/wlroots-$v
  lib=$(pkg-config --variable=libdir "wlroots-$v")/libwlroots-$v.so
  [[ -d $inc && -e $lib ]] || return 1
  mkdir -p "${h%/*}"
  tmp=$(mktemp -d "${h%/*}/.wlroots.XXXXXX") || return 1
  mkdir -p "$tmp/lib" "$tmp/include"
  if ! { cp -a "$inc" "$tmp/include/" && cp -L "$lib" "$tmp/lib/"; }; then rm -rf "$tmp"; return 1; fi
  while IFS=' ' read -r so path; do
    cp -L "$path" "$tmp/lib/$so" || { rm -rf "$tmp"; return 1; }
  done < <(ldd "$lib" | awk '$1 ~ /^lib(display-info|liftoff|xcb-errors)\.so/ && $3 ~ /^\// { print $1, $3 }')
  # its compile flags (the other libraries' headers stay the system's), pointing at the copy
  pkg-config --cflags "wlroots-$v" | sed -E "s#-I$inc( |\$)#-I$h/include/wlroots-$v\1#" >"$tmp/cflags"
  grep -qF -- "-I$h/include/wlroots-$v" "$tmp/cflags" || { rm -rf "$tmp"; return 1; }
  chmod -R u=rwX,go=rX "$tmp"
  rm -rf "$h"; mv "$tmp" "$h"
  restorecon -R "$h" 2>/dev/null || true
}
# dwl_make_args → make's arguments for every dwl build: XWayland on, and the kept wlroots,
# linked so that dwl looks there first (an rpath that also serves wlroots' own libraries)
dwl_make_args() {
  local h; h=$(wlr_home)
  printf '%s\n' "${DWL_MAKE[@]}" "WLR_INCS=$(<"$h/cflags")" \
    "WLR_LIBS=-L$h/lib -lwlroots-$DWL_WLROOTS -Wl,--disable-new-dtags,-rpath,$h/lib"
}

# ── what the user built, installed for the system ────────────────────────────
# Root never runs a build in the user's folders, never executes what was built there and
# never reads a path the user could swap for a link: the user reads the file out (cat, as
# the user), root writes it in place in one step. Its version is asked as the user too.
take_built() {   # take_built SRC DEST MODE — 1 (nothing changed) if it cannot be read
  local t
  [[ -d $(dirname "$2") ]] || install -d -m 0755 "$(dirname "$2")"
  t=$(mktemp -p "$(dirname "$2")" ".${2##*/}.XXXXXX") || return 1
  if as_user cat -- "$1" >"$t" && [[ -s $t ]] && chmod "$3" "$t" && chown root:root "$t" && mv -fT -- "$t" "$2"; then
    restorecon "$2" 2>/dev/null || true
    return 0
  fi
  rm -f -- "$t"; return 1
}

# ── one run at a time; temp files always cleaned up ──────────────────────────
take_lock() {                       # take_lock FILE|DIR (a few seconds' grace: the menu looks at it too)
  if [[ -d $1 ]]; then exec 9<"$1"; else exec 9>"$1"; fi   # a folder of yours is only ever read, never truncated
  flock -w 5 9 || die "another Fedokawaii run (an update, a repair, setup or Theme) is going on — wait for it to finish"
}
KAWA_TMP="" FOLLOWER=""
make_tmp() {                        # private temp dir, removed on any exit (and dnf's follower stopped)
  KAWA_TMP=$(mktemp -d "${TMPDIR:-/var/tmp}/fedokawaii.XXXXXX")
  trap 'rm -rf "$KAWA_TMP"; [[ -n ${FOLLOWER:-} ]] && kill "$FOLLOWER" 2>/dev/null; true' EXIT
}

# ── fedokawaii.conf: every value validated before anything runs ───────────────
validate_conf() {                   # prints one line per problem; empty = valid
  [[ $GPU =~ ^(auto|amd|intel)$ ]]              || echo "GPU must be auto, amd or intel (is '$GPU')"
  [[ $STEAM =~ ^(yes|no)$ ]]                    || echo "STEAM must be yes or no (is '$STEAM')"
  [[ $SSH_SERVER =~ ^(yes|no)$ ]]               || echo "SSH_SERVER must be yes or no (is '$SSH_SERVER')"
  [[ $THEME =~ ^(dark|light)$ ]]                || echo "THEME must be dark or light (is '$THEME')"
  [[ $WALLPAPER_PACK =~ ^(yes|no)$ ]]           || echo "WALLPAPER_PACK must be yes or no (is '$WALLPAPER_PACK')"
  [[ $BOOT_MENU_SECONDS =~ ^([0-9]|10)$ ]]      || echo "BOOT_MENU_SECONDS must be 0–10 (is '$BOOT_MENU_SECONDS')"
  [[ $MONITOR_HZ =~ ^[1-9][0-9]*$ ]] && ((MONITOR_HZ >= 30 && MONITOR_HZ <= 540)) \
                                                || echo "MONITOR_HZ must be a number 30–540 (is '$MONITOR_HZ')"
  [[ $DNF_PARALLEL =~ ^[1-9][0-9]*$ ]] && ((DNF_PARALLEL >= 1 && DNF_PARALLEL <= 20)) \
                                                || echo "DNF_PARALLEL must be 1–20, dnf5's maximum (is '$DNF_PARALLEL')"
  [[ $TIMEZONE =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ && -f /usr/share/zoneinfo/$TIMEZONE ]] \
                                                || echo "TIMEZONE '$TIMEZONE' is not a known zone (see timedatectl list-timezones)"
  # where you are, for gammastep's sunset and the weather's forecast: a latitude short of the
  # poles and a longitude short of the date line, either way (north and east positive)
  [[ $NIGHT_LIGHT =~ ^-?([0-9]{1,2})(\.[0-9]+)?:-?([0-9]{1,3})(\.[0-9]+)?$ ]] \
    && ((10#${BASH_REMATCH[1]} < 90 && 10#${BASH_REMATCH[3]} < 180)) \
                                                || echo "NIGHT_LIGHT must be latitude:longitude like 25.35:55.40, latitude within ±90, longitude within ±180 (is '$NIGHT_LIGHT')"
  [[ $KB_LAYOUTS =~ ^[a-z]+(,[a-z]+)*$ ]]       || echo "KB_LAYOUTS must look like us,ara (is '$KB_LAYOUTS')"
  [[ $KB_TOGGLE =~ ^[a-z0-9_]+:[a-z0-9_]+$ ]]   || echo "KB_TOGGLE must be an XKB option like grp:alt_shift_toggle (is '$KB_TOGGLE')"
  local city_re="^[[:alnum:] .,'-]+$"           # letters of any script, digits, space . , ' -
  [[ $WEATHER_CITY =~ $city_re ]]               || echo "WEATHER_CITY must be a plain city name: letters, digits, spaces, . , ' - (is '$WEATHER_CITY')"
  # a drive's name, a folder's path or a restic address: letters of any script, digits and
  # . _ - : / @ + = , spaces — nothing a shell or sed would read as more (it reaches ~/.config/fedokawaii/env)
  local target_re="^[[:alnum:]/][[:alnum:] ._:/@+=,-]*$"
  [[ -z $BACKUP_TARGET || $BACKUP_TARGET =~ $target_re ]] \
                                                || echo "BACKUP_TARGET must be a drive's name, a folder's path or a restic address like sftp:you@nas:/backups (is '$BACKUP_TARGET')"
  [[ $BACKUP_REMIND_DAYS =~ ^(0|[1-9][0-9]*)$ ]] && ((BACKUP_REMIND_DAYS <= 365)) \
                                                || echo "BACKUP_REMIND_DAYS must be 0–365 (0 = no reminder) (is '$BACKUP_REMIND_DAYS')"
  [[ $DWL_TAG =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || echo "DWL_TAG must look like v0.9 (is '$DWL_TAG')"
  [[ $DWL_COMMIT =~ ^[0-9a-f]{40}$ ]]           || echo "DWL_COMMIT must be the 40-character commit of $DWL_TAG"
  [[ $DWL_WLROOTS =~ ^0\.[0-9]+$ ]]             || echo "DWL_WLROOTS must look like 0.20 (is '$DWL_WLROOTS')"
  [[ $TFC_TAG =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || echo "TFC_TAG must look like v1.4.3 (is '$TFC_TAG')"
  [[ $TFC_COMMIT =~ ^[0-9a-f]{40}$ ]]           || echo "TFC_COMMIT must be the 40-character commit of $TFC_TAG"
  if [[ -z $USERNAME ]]; then :
  elif [[ ! $USERNAME =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ || $USERNAME =~ ^[0-9]+$ ]]; then echo "USERNAME '$USERNAME' is not a user name"
  elif [[ $USERNAME == root ]]; then echo "USERNAME cannot be root — name the desktop's own user, or leave it empty"
  elif ! id -- "$USERNAME" >/dev/null 2>&1; then echo "USERNAME '$USERNAME' does not exist"; fi
  return 0
}
# fedokawaii.conf is read as data, never run as code: KEY="value" lines (a value in double or
# single quotes, or a bare word; a # comment after it), only the settings below. Anything
# else in it is reported as a problem, and the values are checked before anything runs.
CONF_KEYS=(USERNAME GPU STEAM SSH_SERVER MONITOR_HZ KB_LAYOUTS KB_TOGGLE TIMEZONE WEATHER_CITY
           NIGHT_LIGHT THEME WALLPAPER_PACK BOOT_MENU_SECONDS DNF_PARALLEL BACKUP_TARGET
           BACKUP_REMIND_DAYS DWL_TAG DWL_COMMIT DWL_WLROOTS TFC_TAG TFC_COMMIT)
# settings an earlier version had, gone since: read past in a file not yet merged (update's
# conf_merge takes their lines out) — SPOTIFY (Spotify's app, built here; its web player now)
CONF_RETIRED=(SPOTIFY)
CONF_PROBLEMS=() CONF_SAID=() CONF_SEEN=()
# one setting line: KEY="value", KEY='value' or KEY=value, then an optional # comment
# (the value: BASH_REMATCH[3], [4] or [5], whichever matched)
CONF_RE='^[[:space:]]*([A-Z_]+)=("([^"]*)"|'"'"'([^'"'"']*)'"'"'|([^[:space:]#"'"'"']*))[[:space:]]*(#.*)?$'
# The file is often edited by hand, and on Windows too: a byte-order mark and CRLF line ends
# are read past. A line that is not a setting is named with what to write instead; its
# setting is then "said" (CONF_SAID), so no second line about an empty value follows.
read_conf() {                       # read_conf FILE — sets the settings; CONF_PROBLEMS lists what is not one
  local line k v n=0 IFS=' ' re=$CONF_RE
  local q1='“' q2='”' q3="‘" q4="’"       # typographic quotes, as a word processor or a phone types them
  local -A at=()
  for k in "${CONF_KEYS[@]}"; do printf -v "$k" '%s' ""; done
  CONF_PROBLEMS=() CONF_SAID=() CONF_SEEN=()
  # (missing: that one line says it all — every setting counts as said)
  [[ -r $1 ]] || { CONF_PROBLEMS+=("cannot read $1"); CONF_SAID=("${CONF_KEYS[@]}"); return 0; }
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    ((n > 1)) || line=${line#$'\xef\xbb\xbf'}
    line=${line%$'\r'}
    [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if ! [[ $line =~ $re ]]; then conf_slip "$line"; continue; fi
    k=${BASH_REMATCH[1]} v=${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}
    [[ " ${CONF_RETIRED[*]} " == *" $k "* ]] && continue
    if [[ " ${CONF_KEYS[*]} " != *" $k "* ]]; then CONF_PROBLEMS+=("$k is not a setting of fedokawaii.conf"); continue; fi
    if [[ -n ${at[$k]:-} ]]; then
      CONF_PROBLEMS+=("$k is set twice — on line ${at[$k]} and on line $n; keep one"); CONF_SAID+=("$k")
    fi
    at[$k]=$n
    # (substrings, not a bracket expression: right in any locale)
    if [[ $v == *"$q1"* || $v == *"$q2"* || $v == *"$q3"* || $v == *"$q4"* ]]; then
      v=${v//"$q1"/}; v=${v//"$q2"/}; v=${v//"$q3"/\'}; v=${v//"$q4"/\'}
      CONF_PROBLEMS+=("$k has curly quotes ($q1 $q2 $q3 $q4) — type straight ones: $k=\"$v\""); CONF_SAID+=("$k"); continue
    fi
    printf -v "$k" '%s' "$v"
  done <"$1"
  CONF_SEEN=("${!at[@]}")
}
conf_slip() {   # conf_slip LINE — a line that is not KEY="value": what it most likely is, said plainly
  local l=$1 k K sp v
  if [[ $l =~ ^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)= ]]; then
    k=${BASH_REMATCH[1]}; CONF_SAID+=("${k^^}"); v=${l#*export}; v=${v#"${v%%[![:space:]]*}"}
    v=${v%%[[:space:]]#*}; v=${v%"${v##*[![:space:]]}"}
    CONF_PROBLEMS+=("$k is written with export in front — leave that out: $v"); return 0
  fi
  if ! [[ $l =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)([[:space:]]*)=([[:space:]]*)(.*)$ ]]; then
    CONF_PROBLEMS+=("not a setting (KEY=\"value\"): ${l:0:60}"); return 0
  fi
  k=${BASH_REMATCH[1]} sp=${BASH_REMATCH[2]}${BASH_REMATCH[3]} v=${BASH_REMATCH[4]}; K=${k^^}
  if [[ " ${CONF_KEYS[*]} " != *" $K "* ]]; then CONF_PROBLEMS+=("not a setting (KEY=\"value\"): ${l:0:60}"); return 0; fi
  CONF_SAID+=("$K")
  if [[ $k != "$K" ]]; then CONF_PROBLEMS+=("$k is not a setting — the names are in capitals: $K"); return 0; fi
  # the value as meant — a quoted one up to its closing quote, else up to a # comment — and
  # whether it was quoted
  local q=0
  case $v in
    \"*\"*) v=${v:1}; v=${v%%\"*}; q=1 ;;
    \'*\'*) v=${v:1}; v=${v%%\'*}; q=1 ;;
    \"*|\'*) CONF_PROBLEMS+=("$k has a quote that is not closed: ${l:0:60}"); return 0 ;;
    *) v=${v%%#*}; v=${v%"${v##*[![:space:]]}"} ;;
  esac
  if [[ -n $sp ]]; then CONF_PROBLEMS+=("$k has spaces around the = — write it $k=\"$v\"")
  elif ((q == 0)) && [[ $v == *[[:space:]]* ]]; then CONF_PROBLEMS+=("$k has spaces in its value — put it in quotes: $k=\"$v\"")
  else CONF_PROBLEMS+=("not a setting (KEY=\"value\"): ${l:0:60}"); fi
}
conf_report() {                     # the settings read last → one line per problem; empty = valid
  local IFS=' '
  local said=" ${CONF_SAID[*]} " seen=" ${CONF_SEEN[*]} " k l
  {
    ((${#CONF_PROBLEMS[@]} == 0)) || printf '%s\n' "${CONF_PROBLEMS[@]}"
    # a setting with no line at all (USERNAME may go: it is whoever ran sudo)
    for k in "${CONF_KEYS[@]}"; do
      [[ $k == USERNAME || $seen == *" $k "* || $said == *" $k "* ]] && continue
      echo "$k is missing — add its line: $k=\"…\""; said+="$k "
    done
    # the values' rules; a setting already named above is not named twice (each rule's line
    # starts with its setting's name)
    while IFS= read -r l; do [[ $said == *" ${l%% *} "* ]] || printf '%s\n' "$l"; done < <(validate_conf)
  } | sed '/^$/d'
}
# conf_base BASE → the fedokawaii.conf a working copy's settings are measured against when
# it becomes the toolkit: the newer of what the last apply took from a copy, and BASE — what
# `fedokawaii copy` kept when it made this copy (the toolkit's file at that moment, in the
# copy's .git/fedokawaii-conf-base). A key the copy holds as there was not changed in the
# copy: the toolkit's own value stays.
conf_base() {
  local a=$STATE_DIR/conf-from-copy.conf b=$1
  [[ -f $b && ! -L $b ]] || b=""
  [[ -f $a ]] || a=""
  if [[ -n $a && -n $b ]]; then [[ $b -nt $a ]] && echo "$b" || echo "$a"
  else echo "${b:-$a}"; fi
}
conf_problems() {                   # conf_problems FILE → one line per problem; empty = valid
  read_conf "$1"; conf_report
}
load_conf() {                       # load_conf REPO_DIR — read + validate, die with every problem listed
  local problems
  read_conf "$1/fedokawaii.conf"
  problems=$(conf_report)
  [[ -z $problems ]] || die "fedokawaii.conf:"$'\n'"$(sed 's/^/    /' <<<"$problems")"
}
