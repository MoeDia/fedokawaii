#!/usr/bin/env bash
# lib/common.sh — shared by every script: output, reporting, retries, steps,
# user context, hardened downloads, config validation, locking, temp cleanup.
umask 022

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m' C_GOLD=$'\e[33m' C_RED=$'\e[31m' C_OK=$'\e[32m' C_DIM=$'\e[2m' C_BOLD=$'\e[1m'
else
  C_RESET='' C_GOLD='' C_RED='' C_OK='' C_DIM='' C_BOLD=''
fi
LOG_FILE=${LOG_FILE:-/var/log/fedokawai.log}
# the logs record every command with its output: root's alone
if [[ $EUID -eq 0 && $LOG_FILE == /var/log/* ]]; then
  [[ -e $LOG_FILE ]] || : >"$LOG_FILE"
  chmod 600 "$LOG_FILE" 2>/dev/null || true
fi

_ts()  { date '+%H:%M:%S'; }
# (each joins its words with spaces: the scripts' IFS is newline + tab)
_out() { printf '%s\n' "$1" | tee -a "$LOG_FILE"; }
log()  { local IFS=' '; _out "${C_DIM}$(_ts)${C_RESET} ${C_GOLD}▸${C_RESET} $*"; }
ok()   { local IFS=' '; _out "${C_DIM}$(_ts)${C_RESET} ${C_OK}✔${C_RESET} $*"; }
die()  { local IFS=' '; _out "${C_DIM}$(_ts)${C_RESET} ${C_RED}✘ $*${C_RESET}" >&2; exit 1; }   # (stderr: never swallowed by a $( ))
hdr()  { local IFS=' '; _out ""; _out "${C_BOLD}${C_GOLD}── $* ${C_RESET}"; }

# run CMD… — echo + log the command; its status is the command's status
run() {
  local IFS=' '
  _out "${C_DIM}$(_ts) \$ $*${C_RESET}"
  "$@" 2>&1 | tee -a "$LOG_FILE"
  return "${PIPESTATUS[0]}"
}

# retry N PAUSE CMD… — for network-bound commands
retry() {
  local n=$1 pause=$2 i IFS=' '; shift 2
  for ((i = 1; i <= n; i++)); do
    "$@" && return 0
    log "attempt $i/$n failed: $* — retrying in ${pause}s"; sleep "$pause"
  done
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
STATE_DIR=${STATE_DIR:-/var/lib/fedokawai}
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
  install -d -m 0755 "$(dirname "$1")"
  t=$(mktemp "$(dirname "$1")/.${1##*/}.XXXXXX") || return 1
  if cat >"$t" && chmod "${2:-0644}" "$t" && mv -fT -- "$t" "$1"; then return 0; fi
  rm -f -- "$t"; return 1
}

# ── dwl's own copy of wlroots ─────────────────────────────────────────────────
# dwl is built for one wlroots (DWL_WLROOTS). Fedora moves to newer ones over the years and
# its package of the old one goes — which would leave dwl unable to start. So the first
# build keeps Fedora's own build of it in /usr/local/lib/fedokawai-wlroots-VERSION: the
# library, its headers, and the young libraries it uses that may change their names between
# releases (libdisplay-info, libliftoff, xcb-errors); dwl is linked to that copy. A later
# Fedora's wlroots never touches dwl, and dwl can still be built again (Theme) against the
# copy. Everything else it uses keeps its name for years (Wayland, libinput, Mesa,
# xkbcommon, pixman, libseat, udev, xcb) — and before a move to a new Fedora, the move
# checks that the new release has every one of them (setup.sh, libs_ready).
wlr_home() { echo "/usr/local/lib/fedokawai-wlroots-$DWL_WLROOTS"; }   # (beside the toolkit, never inside: a new toolkit replaces that folder whole)
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
  install -d -m 0755 "$(dirname "$2")"
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
  flock -w 5 9 || die "another Fedokawai run is active (lock: $1)"
}
KAWA_TMP="" FOLLOWER=""
make_tmp() {                        # private temp dir, removed on any exit (and dnf's follower stopped)
  KAWA_TMP=$(mktemp -d "${TMPDIR:-/var/tmp}/fedokawai.XXXXXX")
  trap 'rm -rf "$KAWA_TMP"; [[ -n ${FOLLOWER:-} ]] && kill "$FOLLOWER" 2>/dev/null; true' EXIT
}

# ── fedokawai.conf: every value validated before anything runs ───────────────
validate_conf() {                   # prints one line per problem; empty = valid
  [[ $GPU =~ ^(auto|amd|intel)$ ]]              || echo "GPU must be auto, amd or intel (is '$GPU')"
  [[ $STEAM =~ ^(yes|no)$ ]]                    || echo "STEAM must be yes or no (is '$STEAM')"
  [[ $SSH_SERVER =~ ^(yes|no)$ ]]               || echo "SSH_SERVER must be yes or no (is '$SSH_SERVER')"
  [[ $THEME =~ ^(dark|light)$ ]]                || echo "THEME must be dark or light (is '$THEME')"
  [[ $WALLPAPER_PACK =~ ^(yes|no)$ ]]           || echo "WALLPAPER_PACK must be yes or no (is '$WALLPAPER_PACK')"
  [[ $BOOT_MENU_SECONDS =~ ^([0-9]|10)$ ]]      || echo "BOOT_MENU_SECONDS must be 0–10 (is '$BOOT_MENU_SECONDS')"
  [[ $MONITOR_HZ =~ ^[0-9]+$ ]] && ((MONITOR_HZ >= 30 && MONITOR_HZ <= 540)) \
                                                || echo "MONITOR_HZ must be a number 30–540 (is '$MONITOR_HZ')"
  [[ $DNF_PARALLEL =~ ^[0-9]+$ ]] && ((DNF_PARALLEL >= 1 && DNF_PARALLEL <= 20)) \
                                                || echo "DNF_PARALLEL must be 1–20, dnf5's maximum (is '$DNF_PARALLEL')"
  [[ $TIMEZONE =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ && -f /usr/share/zoneinfo/$TIMEZONE ]] \
                                                || echo "TIMEZONE '$TIMEZONE' is not a known zone (see timedatectl list-timezones)"
  [[ $NIGHT_LIGHT =~ ^-?[0-9]+(\.[0-9]+)?:-?[0-9]+(\.[0-9]+)?$ ]] \
                                                || echo "NIGHT_LIGHT must be latitude:longitude like 25.35:55.40 (is '$NIGHT_LIGHT')"
  [[ $KB_LAYOUTS =~ ^[a-z]+(,[a-z]+)*$ ]]       || echo "KB_LAYOUTS must look like us,ara (is '$KB_LAYOUTS')"
  [[ $KB_TOGGLE =~ ^[a-z0-9_]+:[a-z0-9_]+$ ]]   || echo "KB_TOGGLE must be an XKB option like grp:alt_shift_toggle (is '$KB_TOGGLE')"
  local city_re="^[[:alnum:] .,'-]+$"           # letters of any script, digits, space . , ' -
  [[ $WEATHER_CITY =~ $city_re ]]               || echo "WEATHER_CITY must be a plain city name: letters, digits, spaces, . , ' - (is '$WEATHER_CITY')"
  [[ $DWL_TAG =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || echo "DWL_TAG must look like v0.9 (is '$DWL_TAG')"
  [[ $DWL_COMMIT =~ ^[0-9a-f]{40}$ ]]           || echo "DWL_COMMIT must be the 40-character commit of $DWL_TAG"
  [[ $DWL_WLROOTS =~ ^0\.[0-9]+$ ]]             || echo "DWL_WLROOTS must look like 0.20 (is '$DWL_WLROOTS')"
  [[ $TFC_TAG =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || echo "TFC_TAG must look like v1.4.3 (is '$TFC_TAG')"
  [[ $TFC_COMMIT =~ ^[0-9a-f]{40}$ ]]           || echo "TFC_COMMIT must be the 40-character commit of $TFC_TAG"
  [[ -z $USERNAME ]] || id "$USERNAME" >/dev/null 2>&1 || echo "USERNAME '$USERNAME' does not exist"
  return 0
}
# fedokawai.conf is read as data, never run as code: KEY="value" lines (a value in double or
# single quotes, or a bare word; a # comment after it), only the settings below. Anything
# else in it is reported as a problem, and the values are checked before anything runs.
CONF_KEYS=(USERNAME GPU STEAM SSH_SERVER MONITOR_HZ KB_LAYOUTS KB_TOGGLE TIMEZONE WEATHER_CITY
           NIGHT_LIGHT THEME WALLPAPER_PACK BOOT_MENU_SECONDS DNF_PARALLEL DWL_TAG DWL_COMMIT
           DWL_WLROOTS TFC_TAG TFC_COMMIT)
CONF_PROBLEMS=()
# one setting line: KEY="value", KEY='value' or KEY=value, then an optional # comment
# (the value: BASH_REMATCH[3], [4] or [5], whichever matched)
CONF_RE='^[[:space:]]*([A-Z_]+)=("([^"]*)"|'"'"'([^'"'"']*)'"'"'|([^[:space:]#"'"'"']*))[[:space:]]*(#.*)?$'
read_conf() {                       # read_conf FILE — sets the settings; CONF_PROBLEMS lists what is not one
  local line k v IFS=' ' re=$CONF_RE
  for k in "${CONF_KEYS[@]}"; do printf -v "$k" '%s' ""; done
  CONF_PROBLEMS=()
  [[ -r $1 ]] || { CONF_PROBLEMS+=("cannot read $1"); return 0; }
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ $line =~ $re ]]; then
      k=${BASH_REMATCH[1]} v=${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}
      if [[ " ${CONF_KEYS[*]} " == *" $k "* ]]; then printf -v "$k" '%s' "$v"
      else CONF_PROBLEMS+=("$k is not a setting of fedokawai.conf"); fi
    else
      CONF_PROBLEMS+=("not a setting (KEY=\"value\"): ${line:0:60}")
    fi
  done <"$1"
}
conf_report() {                     # the settings read last → one line per problem; empty = valid
  { ((${#CONF_PROBLEMS[@]} == 0)) || printf '%s\n' "${CONF_PROBLEMS[@]}"; validate_conf; } | sed '/^$/d'
}
conf_problems() {                   # conf_problems FILE → one line per problem; empty = valid
  read_conf "$1"; conf_report
}
load_conf() {                       # load_conf REPO_DIR — read + validate, die with every problem listed
  local problems
  read_conf "$1/fedokawai.conf"
  problems=$(conf_report)
  [[ -z $problems ]] || die "fedokawai.conf:"$'\n'"$(sed 's/^/    /' <<<"$problems")"
}
