# tests/look/lib.sh — what the look tests share, on top of tests/lib/harness.sh: a pretend
# process table (pgrep answers from it), stand-ins that keep exactly what they were given,
# pretend monitors for wlr-randr, and hiding a program as if it were not installed.
# Every process these tests start carries the sandbox's path in its command line, and the
# pretend pgrep names only those: nothing outside the sandbox is ever signalled or killed.
# shellcheck shell=bash
# shellcheck disable=SC2034   # (variables for the test files)

L_TMPDIR=${TMPDIR:-}
look() {   # look — a fresh sandbox for the look helpers (call again for a clean slate)
  look_cleanup
  # (hide, or a test's own TMPDIR, may point inside the old sandbox)
  PATH=/usr/local/bin:/usr/bin:/bin
  if [[ -n $L_TMPDIR ]]; then export TMPDIR=$L_TMPDIR; else unset TMPDIR; fi
  unhide
  sandbox
  trap 'look_cleanup; [[ -n $TMP ]] && rm -rf "$TMP"; [[ -n $L_FARM ]] && rm -rf "$L_FARM"' EXIT
  PROCS=$TMP/procs ARGS=$TMP/args
  mkdir -p "$ARGS"
  : >"$PROCS"
  export FAKE_PROCS=$PROCS FAKE_TMP=$TMP
  # pgrep [-x] [-u UID | -xu UID] NAME: this sandbox's live processes called NAME — a
  # stand-in running under that name, or one the test listed in $FAKE_PROCS ("NAME PID")
  stub pgrep 'for a; do n=$a; done; r=1
mine() { { tr "\0" " " <"/proc/$1/cmdline"; } 2>/dev/null | grep -qF "$FAKE_TMP"; }   # (it may end meanwhile)
for d in /proc/[0-9]*; do
  c=""; { read -r c <"$d/comm"; } 2>/dev/null
  [ "$c" = "$n" ] && mine "${d#/proc/}" && { echo "${d#/proc/}"; r=0; }
done
while read -r name pid; do [ "$name" = "$n" ] && mine "$pid" && { echo "$pid"; r=0; }; done <"$FAKE_PROCS"
exit $r'
  # the pixel art theme.sh draws from the repository's .xpm files (wave tile, Fuji scene, padlock)
  local x mode
  for x in "$REPO"/configs/home/.local/share/fedokawaii/{dark,light}/*.xpm; do
    mode=$(basename "$(dirname "$x")")
    mkdir -p "$HOME/.local/share/fedokawaii/$mode"
    command -v magick >/dev/null && magick "$x" "$HOME/.local/share/fedokawaii/$mode/$(basename "$x" .xpm).png" 2>/dev/null
  done
  cp "$REPO/configs/home/.local/share/fedokawaii/wallpapers.list" "$HOME/.local/share/fedokawaii/"
}

look_cleanup() {   # stop every process this sandbox started (and only those)
  [[ -n ${TMP:-} && -d $TMP ]] && ((EUID == 0)) && chattr -R -i "$TMP" 2>/dev/null   # (see ro)
  [[ -n ${TMP:-} && -s ${PROCS:-/nonexistent} ]] || return 0
  local name pid
  while read -r name pid; do
    { tr '\0' ' ' <"/proc/$pid/cmdline"; } 2>/dev/null | grep -qF "$TMP" && kill "$pid" 2>/dev/null
  done <"$PROCS"
  return 0
}

daemon() {   # daemon NAME — NAME running (a long sleep) in the process table; prints its pid
  bash -c 'exec -a "$0" /bin/sleep 300' "fake-$1-of-$TMP" >/dev/null 2>&1 &
  echo "$1 $!" >>"$PROCS"; echo "$!"
}

catcher() {   # catcher NAME SIG… — NAME running, catching SIG… (USR1, USR2): each one it gets
  local log=$TMP/sig.$1.$RANDOM i   # goes to its log. Prints "PID LOG" once it is ready
  python3 -I -c '
import signal, sys
log = sys.argv[1]
def got(s, f):
    with open(log, "a") as o: o.write(signal.Signals(s).name + "\n")
for s in sys.argv[2:]:
    signal.signal(getattr(signal, "SIG" + s), got)
open(log + ".up", "w").close()
while True: signal.pause()' "$log" "${@:2}" >/dev/null 2>&1 &
  local pid=$!
  echo "$1 $pid" >>"$PROCS"
  for i in {1..300}; do [[ -e $log.up ]] && break; /bin/sleep 0.01; done
  echo "$pid $log"
}

alive() {   # alive PID — running (a zombie is not: it was killed, only not reaped yet)
  local st=""; { read -r _ _ st _ <"/proc/$1/stat"; } 2>/dev/null; [[ -n $st && $st != Z ]]
}
got() {   # got LOG N — a catcher's log once it holds N signals (5 s at most), then printed
  local i; for i in {1..250}; do (( $(wc -l <"$1" 2>/dev/null || echo 0) >= $2 )) && break; /bin/sleep 0.02; done
  cat "$1" 2>/dev/null
}

ro() {   # ro DIR — DIR cannot be written to, not even by root (chattr +i; 1: not possible here)
  chmod 555 "$1"
  if ((EUID == 0)); then chattr +i "$1" 2>/dev/null || { chmod 755 "$1"; return 1; }; fi
  return 0
}
rw() { ((EUID == 0)) && chattr -i "$1" 2>/dev/null; chmod 755 "$1"; }   # rw DIR — writable again

stubf() { stub "$1" "$(cat)"; }   # stubf NAME <<'EOF' … — a stand-in whose body is read from stdin

argv() {   # argv NAME [BODY] — a stand-in that also keeps each call's arguments exactly (NUL
  # separated) in $ARGS/NAME.N; BODY (sh) runs after
  stub "$1" 'n=1; while [ -e "'"$ARGS/$1"'.$n" ]; do n=$((n + 1)); done
: >"'"$ARGS/$1"'.$n"; for a; do printf "%s\0" "$a" >>"'"$ARGS/$1"'.$n"; done'"${2:+
$2}"
}
args_of() { tr '\0' '\n' <"$ARGS/$1.${2:-1}" 2>/dev/null; }   # args_of NAME [N] — one per line
ncalls() { local n=0; while [[ -e $ARGS/$1.$((n + 1)) ]]; do n=$((n + 1)); done; echo "$n"; }
args_eq() {   # args_eq NAME N ARG… — call N got exactly these arguments
  local got=() want=("${@:3}")
  [[ -e $ARGS/$1.$2 ]] && mapfile -d '' -t got <"$ARGS/$1.$2"
  [[ ${#got[@]} == "${#want[@]}" && "${got[*]@Q}" == "${want[*]@Q}" ]] && _ok \
    || _no "$1 call $2: wanted ${want[*]@Q}, got ${got[*]@Q}"
}

L_FARM="" L_HIDDEN=()
hide() {   # hide NAME… — as if NAME were not installed: a PATH without it (until the next look)
  local d n
  if [[ -z $L_FARM ]]; then        # (built once per file: every program, each as a link)
    L_FARM=$(mktemp -d "${L_TMPDIR:-/tmp}/kawa-farm.XXXXXX")
    mkdir -p "$L_FARM/sys" "$L_FARM/repo" "$L_FARM/hidden"
    for d in /usr/local/bin /usr/bin /bin /usr/sbin /sbin; do
      [[ -d $d ]] && find "$d" -maxdepth 1 \( -type f -o -type l \) -printf '%p\0' 2>/dev/null \
        | xargs -0 -r ln -s -t "$L_FARM/sys" 2>/dev/null
    done
    cp -a "$REPO/bin/." "$L_FARM/repo/"      # (the repository's scripts, as they are now)
  fi
  export PATH="$STUBS:$L_FARM/repo:$L_FARM/sys"
  for n; do
    rm -f "$STUBS/$n"
    for d in sys repo; do
      [[ -e $L_FARM/$d/$n || -L $L_FARM/$d/$n ]] || continue
      mv "$L_FARM/$d/$n" "$L_FARM/hidden/$d-$n"; L_HIDDEN+=("$d/$n")
    done
  done
}
unhide() {   # every hidden program back (look does this)
  local h
  for h in "${L_HIDDEN[@]}"; do mv "$L_FARM/hidden/${h%%/*}-${h#*/}" "$L_FARM/$h"; done
  L_HIDDEN=()
}

screens() {   # screens "NAME WxH[@HZ|@none] [turned|off]"… — what wlr-randr shows (none: no monitor)
  local s name mode hz rest
  : >"$TMP/randr"
  for s; do
    read -r name mode rest <<<"$s"
    hz=${mode#*@}; [[ $hz == "$mode" ]] && hz=60.000000; mode=${mode%@*}
    {
      printf '%s "Pretend %s"\n  Make: Pretend\n  Model: %s\n  Serial: 1\n  Physical size: 600x340 mm\n' "$name" "$name" "$name"
      if [[ $rest == *off* ]]; then
        printf '  Enabled: no\n  Modes:\n    %s px, %s Hz (preferred)\n' "$mode" "$hz"
      else
        printf '  Enabled: yes\n  Modes:\n'
        if [[ $hz == none ]]; then printf '    %s px (current)\n' "$mode"
        else printf '    %s px, %s Hz (preferred, current)\n    1280x720 px, 60.000000 Hz\n' "$mode" "$hz"; fi
        printf '  Position: 0,0\n  Transform: %s\n  Scale: 1.000000\n  Adaptive Sync: disabled\n' \
          "$([[ $rest == *turned* ]] && echo 90 || echo normal)"
      fi
    } >>"$TMP/randr"
  done
  stub wlr-randr "cat '$TMP/randr'"
}

size_of() { magick "$1" -format '%wx%h' info: 2>/dev/null; }   # size_of PNG → WxH

gate() {   # gate NAME — a stand-in can wait at "$TMP/gate.NAME" (wait_gate) until open_gate NAME
  rm -f "$TMP/gate.$1" "$TMP/gate.$1.in"
}
open_gate() { : >"$TMP/gate.$1"; }
at_gate() {   # at_gate NAME — wait (up to 10 s) until something is waiting at the gate
  local i; for i in {1..1000}; do [[ -e $TMP/gate.$1.in ]] && return 0; /bin/sleep 0.01; done; return 1
}
# (sh, for stand-in bodies) wait at gate NAME until it opens
wait_gate() { printf ': >"%s.in"; while [ ! -e "%s" ]; do /bin/sleep 0.02; done' "$TMP/gate.$1" "$TMP/gate.$1"; }

need() {   # need CMD… — skip the rest of this file (passing) when a tool the checks need is missing
  local c
  for c; do command -v "$c" >/dev/null || { echo "$(basename "$0" .sh): skipped — needs $c"; exit 0; }; done
}
