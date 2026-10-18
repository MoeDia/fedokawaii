#!/usr/bin/env bash
# tests/lib/harness.sh — what every test file sources: a throw-away home with the desktop's
# configs, stand-ins ("stubs") for the programs and hardware a helper talks to, and a few
# assertions. Nothing outside the temporary folder is touched, nothing real is started.
#
#   . "$(dirname "$0")/../lib/harness.sh"
#   sandbox                          a fresh home, runtime folder and stub folder (PATH first),
#                                    with the icons, both themes (dark current) and ~/.config/fedokawaii/env;
#                                    KAWA_TOOLKIT (the toolkit the helpers read settings from) is
#                                    $TMP/toolkit — absent until a test makes it (toolkit, below)
#   toolkit [KEY=VALUE…]             $TMP/toolkit: fedokawaii.conf (those settings changed, as
#                                    Super+U → settings saves them) and lib/common.sh
#   config REL…                      configs/home/REL (a file or a folder) into the home, rendered
#                                    as theme.sh does (@HOME@, @UID@, fedokawaii.conf's values)
#   stub NAME [BODY]                 a stand-in: logs "NAME args" to $CALLS, then runs BODY (sh);
#                                    $TMP, $STUBS and $CALLS are exported for it
#   on_exit 'CMD'                    run CMD when the file ends (also on Ctrl+C)
#   Note: sandbox sets LC_ALL=C.UTF-8 — a locale bug only shows when a test sets another
#   case_ "what it checks"           names the checks that follow in the report
#   eq GOT WANT [MSG] · has TEXT PART [MSG] · lacks TEXT PART [MSG] · rc WANT CMD…
#   called PATTERN · not_called PATTERN    (grep -E on the stub log)
#   done_                            the summary line; exit 1 if anything failed
# Run them all: bash tests/run.sh   (one area: bash tests/run.sh drives)
set -u
HT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPO=${HT%/tests}
H_PASS=0 H_FAIL=0 H_CASE=""
# the machine's own files a careless test (or a script under test) could reach through a link:
# checked again at done_, so damage is reported at once rather than found later
host_sum() { { cat /etc/passwd /etc/group; [[ -r /etc/shadow ]] && cat /etc/shadow; } 2>/dev/null | cksum
             [[ -c /dev/null ]] || echo "/dev/null is no longer a device"; }
H_HOST=$(host_sum)
TMP="" CALLS="" STUBS=""

sandbox() {   # sandbox — every test file starts here (call again for a clean slate)
  [[ -n $TMP && -d $TMP ]] && rm -rf "$TMP"
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/kawa-test.XXXXXX")
  trap _h_cleanup EXIT; trap '_h_cleanup; exit 130' INT TERM HUP   # (a killed run leaves nothing)
  STUBS=$TMP/stubs CALLS=$TMP/calls.log
  export TMP STUBS CALLS     # (a stub's body is a shell of its own: "$TMP/x" must mean this one)
  mkdir -p "$STUBS" "$TMP/home/.local/bin" "$TMP/run" "$TMP/home/.config" "$TMP/home/.cache"
  chmod 700 "$TMP/run"; : >"$CALLS"
  export HOME=$TMP/home XDG_RUNTIME_DIR=$TMP/run XDG_CONFIG_HOME=$TMP/home/.config \
         XDG_CACHE_HOME=$TMP/home/.cache XDG_STATE_HOME=$TMP/home/.local/state \
         XDG_DATA_HOME=$TMP/home/.local/share LC_ALL=C.UTF-8 USER=${USER:-tester} \
         PYTHONDONTWRITEBYTECODE=1 KAWA_TOOLKIT=$TMP/toolkit
  # the scripts under test come straight from the repository; anything they call is a stub first
  export PATH="$STUBS:$REPO/bin:/usr/local/bin:/usr/bin:/bin"
  # the icon names, the menus' width helper and the dark theme's colours, as theme.sh installs them
  mkdir -p "$HOME/.config/fedokawaii"
  cp "$REPO/configs/home/.config/fedokawaii/icons.sh" "$REPO/configs/home/.config/fedokawaii/width.sh" "$REPO/configs/home/.config/fedokawaii/files.sh" "$HOME/.config/fedokawaii/"
  cp -r "$REPO/configs/home/.config/fedokawaii/themes" "$HOME/.config/fedokawaii/"
  ln -s themes/dark "$HOME/.config/fedokawaii/current"
  config .config/fedokawaii/env
  # the desktop's helpers poke the bar and send notices: quiet stand-ins unless a test says more
  stub notify-send; stub kawa-dwlstatus
}

# config REL… — as theme.sh's render(): the values are fedokawaii.conf's defaults
config() {
  local rel src f
  for rel; do
    src=$REPO/configs/home/$rel
    [[ -e $src ]] || { printf 'harness: no configs/home/%s\n' "$rel" >&2; return 1; }
    while IFS= read -r -d '' f; do
      mkdir -p "$(dirname "$HOME/${f#"$REPO/configs/home/"}")"
      case $f in
        *.ttf|*.otf|*.png) cp "$f" "$HOME/${f#"$REPO/configs/home/"}" ;;
        *) sed -e "s|@HOME@|$HOME|g" -e "s|@MONITOR_HZ@|144|g" -e "s|@WEATHER_CITY@|Sharjah|g" \
               -e "s|@NIGHT_LIGHT@|25.35:55.40|g" -e "s|@ICON_CHEVRON_RIGHT@|>|g" \
               -e "s|^@MPV_SCALING@\$|# scaling: mpv's own defaults|" -e "s|@UID@|$UID|g" \
               "$f" >"$HOME/${f#"$REPO/configs/home/"}"
           [[ -x $f ]] && chmod +x "$HOME/${f#"$REPO/configs/home/"}" ;;
      esac
    done < <(find "$src" -type f -print0)
  done
  return 0
}

# toolkit [KEY=VALUE…] — the toolkit's settings as the helpers read them (never the machine's own)
toolkit() {
  local kv
  mkdir -p "$KAWA_TOOLKIT/lib"
  cp "$REPO/lib/common.sh" "$KAWA_TOOLKIT/lib/"
  cp "$REPO/fedokawaii.conf" "$KAWA_TOOLKIT/"
  for kv; do conf_set "${kv%%=*}" "${kv#*=}" "$KAWA_TOOLKIT/fedokawaii.conf"; done
}
conf_set() {  # conf_set KEY VALUE FILE — that setting's line, KEY="VALUE" (its comment kept)
  python3 -I - "$@" <<'PY'
import re, sys
k, v, f = sys.argv[1:]
t = open(f, encoding="utf-8").read()
t, n = re.subn(r'(?m)^%s=("[^"]*"|\S*)' % re.escape(k), lambda m: '%s="%s"' % (k, v), t)
if n != 1: sys.exit("conf_set: no %s line in %s" % (k, f))
open(f, "w", encoding="utf-8").write(t)
PY
}

# on_exit 'COMMAND' — run at the end, before the throw-away folder goes (sandbox sets the traps)
H_CLEANUP=()
on_exit() { H_CLEANUP+=("$1"); }
_h_cleanup() { local c; for c in "${H_CLEANUP[@]}"; do eval "$c"; done; [[ -n $TMP ]] && rm -rf "$TMP"; }

stub() {      # stub NAME [BODY] — BODY is sh, run with the stub's arguments ("$@"). Its exit
  local f=$STUBS/$1   # status is BODY's own "exit N", else 0 (exit 0 follows BODY)
  rm -f -- "$f"       # (never write through a link a test left there: it could point into the repo)
  { printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >>"%s"\n' "$1" "$CALLS"
    [[ -n ${2:-} ]] && printf '%s\n' "$2"; printf 'exit 0\n'; } >"$f"
  chmod 755 "$f"
}

case_() { H_CASE=$1; }
_ok()  { H_PASS=$((H_PASS + 1)); }
_no()  { H_FAIL=$((H_FAIL + 1)); printf '  ✘ %s — %s\n' "${H_CASE:-?}" "$1"; }
eq()    { [[ $1 == "$2" ]] && _ok || _no "${3:-expected [$2], got [$1]}"; }
has()   { [[ $1 == *"$2"* ]] && _ok || _no "${3:-[$2] not in: ${1:0:300}}"; }
lacks() { [[ $1 != *"$2"* ]] && _ok || _no "${3:-[$2] should not be in: ${1:0:300}}"; }
rc()    { local want=$1 got; shift; "$@" >/dev/null 2>&1; got=$?; [[ $got == "$want" ]] && _ok || _no "exit $got, wanted $want: $*"; }
called()     { grep -Eq -- "$1" "$CALLS" && _ok || _no "no call matching [$1] — calls: $(tail -n 5 "$CALLS" | tr '\n' '|')"; }
not_called() { grep -Eq -- "$1" "$CALLS" && _no "unexpected call matching [$1]" || _ok; }
reset_calls() { : >"$CALLS"; }

done_() {
  [[ $(host_sum) == "$H_HOST" ]] || { H_CASE="the machine itself"
    _no "/etc/passwd, /etc/group, /etc/shadow or /dev/null changed while this file ran — check them now"; }
  printf '%s: %d passed, %d failed\n' "$(basename "$0" .sh)" "$H_PASS" "$H_FAIL"
  ((H_FAIL == 0))
}
