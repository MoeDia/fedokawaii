# tests/menus/lib.sh — what the menu tests share, on top of tests/lib/harness.sh: fuzzel as a
# stand-in that answers as told (fake_fuzzel), and the checks that every row fits its menu.
#   menus_sandbox            sandbox + the fake fuzzel (WAYLAND_DISPLAY set: it takes the lock)
#   answer A…                what the next menus answer, in order (fake_fuzzel lists them)
#   fz_n                     how many menus opened so far
#   fz_rows [N] · fz_args [N]   the rows / the arguments (one a line) of menu N (default: the last)
#   fz_arg KEY [N]           the value of --KEY=… of menu N ("" when absent; "set" for a bare flag)
#   fits [N] [WHY]           every row of menu N fits its width (fuzzel keeps the last column
#                            for its "…"), and its title stays on one line (FITS_WRAP=1: may
#                            wrap at its spaces, as fuzzel does, but no word is too long)
#   cols TEXT                the columns TEXT takes (cols.py)
#   without CMD…             prints a PATH on which CMD… are not found (the stubs, the repo's
#                            bin, and links to every other program of the system)
#   forget                   the menus' record of the last menu goes (as after a while)
#   ns SETUP CMD…            CMD in a mount namespace of its own (unshare -rm: no root needed),
#                            after the shell lines SETUP (mounting a tmpfs over /sys/class, a
#                            file over /proc/uptime…); NS=1 when the system allows that
#   locale_ NAME             prints LOCPATH=… for a command run with LC_ALL=NAME: the locale
#                            compiled into $TMP when the system has its sources (else glibc
#                            falls back to C, and LOCPATH= is harmless)
# shellcheck shell=bash
MD=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

menus_sandbox() {
  sandbox
  export FZ=$TMP/fz WAYLAND_DISPLAY=wayland-test CALLS
  mkdir -p "$FZ"; : >"$FZ/answers"
  cp "$MD/fake_fuzzel" "$STUBS/fuzzel"; chmod 755 "$STUBS/fuzzel"
}
answer() { printf '%s\n' "$@" >>"$FZ/answers"; }
fz_n() { cat "$FZ/n" 2>/dev/null || echo 0; }
fz_rows() { cat "$FZ/in.${1:-$(fz_n)}" 2>/dev/null; }
fz_args() { cat "$FZ/args.${1:-$(fz_n)}" 2>/dev/null; }
fz_arg() {
  local a
  while IFS= read -r a; do
    case $a in --"$1"=*) printf '%s' "${a#*=}"; return ;; --"$1") printf set; return ;; esac
  done < <(fz_args "${2:-}")
}
without() {
  local d=$TMP/without c
  rm -rf "$d"; mkdir -p "$d"
  cp -s /usr/local/bin/* /usr/bin/* "$d"/ 2>/dev/null
  [[ /bin -ef /usr/bin ]] || cp -sn /bin/* "$d"/ 2>/dev/null
  for c; do rm -f "$d/$c" "$STUBS/$c"; done
  printf '%s' "$STUBS:$REPO/bin:$d"
}
if unshare -rm true 2>/dev/null; then NS=1; else NS=0; fi; export NS
ns() {
  local setup=$1; shift
  unshare -rm bash -c "$setup"$'\nexec "$@"' ns "$@"
}
locale_() {
  local d=$TMP/locale
  if [[ ! -d $d/$1 ]] && command -v localedef >/dev/null; then
    mkdir -p "$d"; localedef -i "${1%%.*}" -f UTF-8 "$d/$1" >/dev/null 2>&1
  fi
  printf 'LOCPATH=%s' "$( [[ -d $d/$1 ]] && printf '%s' "$d")"
}
forget() { rm -f "$XDG_RUNTIME_DIR"/kawa-menu-*.state; }
cols() { printf '%s\n' "$1" | python3 -I "$MD/cols.py"; }

fits() {
  local n=${1:-$(fz_n)} why=${2:-} w t bad
  w=$(fz_arg width "$n"); t=$(fz_arg mesg "$n")
  [[ -n $w ]] || { _no "menu $n has no --width"; return; }
  # fuzzel draws a row whole up to its width × 6 − 10 px (the rest is kept for its "…")
  bad=$(fz_rows "$n" | python3 -I "$MD/cols.py" --px | paste - <(fz_rows "$n") |
        awk -F'\t' -v w="$w" '$1 > w * 6 - 10 { printf "%s px: %s | ", $1, $2 }')
  [[ -z $bad ]] && _ok || _no "${why:+$why: }rows wider than $((w * 6 - 10)) px: $bad"
  if [[ -n $t && ${FITS_WRAP:-0} == 1 ]]; then
    bad=$(tr ' ' '\n' <<<"$t" | python3 -I "$MD/cols.py" | sort -n | tail -n1)
    ((bad <= w)) && _ok || _no "${why:+$why: }title [$t] has a word of $bad columns: wider than $w"
  elif [[ -n $t ]]; then
    # fuzzel wraps a title longer than the width in characters (not columns) at a space
    ((${#t} <= w && $(cols "$t") <= w)) && _ok || _no "${why:+$why: }title [$t] is ${#t} characters, $(cols "$t") columns: wider than $w"
  fi
}
