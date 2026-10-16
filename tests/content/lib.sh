#!/usr/bin/env bash
# tests/content/lib.sh — what the content helpers' tests share, on top of tests/lib/harness.sh:
# the real tools some checks need (found before the sandbox narrows PATH), a terminal of
# their own (pty_run.py), a sixel reader (sixel.py), small real books and pictures
# (make_books.py) and a stand-in clipboard history (fake_cliphist.py).
. "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"
C=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# the real programs, as the caller's PATH has them (before the sandbox's PATH): empty if missing
# shellcheck disable=SC2034  # (the test files use them)
REAL_FZF=$(command -v fzf 2>/dev/null)
# shellcheck disable=SC2034
REAL_NVIM=$(command -v nvim 2>/dev/null)
count() { local n=0 f; for f in "$@"; do [[ -e $f ]] && n=$((n + 1)); done; echo "$n"; }   # count GLOB… — files that exist

skip() { printf '  - skipped: %s\n' "$*"; }          # a check this machine cannot make

# a terminal of its own, COLS wide: tty COLS CMD… (stdout: what CMD wrote; status: CMD's)
tty_run() { local cols=$1; shift; python3 -I "$C/pty_run.py" --cols "$cols" --rows 30 -- "$@"; }

sixel_info() { python3 -I "$C/sixel.py"; }                  # JSON about a sixel on stdin
jget() { python3 -I -c 'import json,sys; d=json.load(sys.stdin)
for k in sys.argv[1:]: d = d[int(k)] if isinstance(d, list) else d.get(k)
print(json.dumps(d) if isinstance(d, (list, dict)) else d)' "$@"; }

mk() { python3 -I "$C/make_books.py" "$@"; }               # mk KIND OUT ARG… (make_books.py)

# a PATH without one program: links to the sandbox's stubs, the repository's bin and every
# program in /usr/local/bin, /usr/bin and /bin, but that one — so "missing" is missing,
# root or not (stubs made after this call are not in it)
without() {   # without NAME… — prints that PATH
  local d=$TMP/without.$$.$RANDOM x
  mkdir -p "$d"
  # (one ln for them all: where two folders have a name, the first one's stays — as in PATH)
  ln -s "$STUBS"/* "$REPO"/bin/* /usr/local/bin/* /usr/bin/* /bin/* "$d"/ 2>/dev/null
  for x; do rm -f "${d:?}/$x"; done
  printf '%s' "$d"
}
jrepr() { python3 -I -c 'import json,sys; print(repr(json.load(sys.stdin)[sys.argv[1]]))' "$1"; }   # a field, as Python writes it

# the sandbox's home moved to a path with a space, an accent and a quote in it (everything
# in it comes along); the helpers named are installed in it, as theme.sh does
odd_home() {   # odd_home [HELPER…]
  local h="$TMP/my hôme/it's"
  mkdir -p "${h%/*}"; mv "$TMP/home" "$h"
  export HOME=$h XDG_CONFIG_HOME=$h/.config XDG_CACHE_HOME=$h/.cache \
         XDG_STATE_HOME=$h/.local/state XDG_DATA_HOME=$h/.local/share
  for x; do install -m 0755 "$REPO/bin/$x" "$h/.local/bin/$x"; done
}

# a locale the system may not have built: compiled into $TMP (glibc's localedef) when needed.
# Sets LOC to the name to use with LC_ALL (and exports LOCPATH if it had to be built); fails
# if neither is possible. (Not in $(…): LOCPATH must reach this shell.)
locale_of() {   # locale_of en_US && LC_ALL=$LOC …
  LOC=$1.UTF-8
  locale -a 2>/dev/null | grep -qix "$1.utf-\?8" && return 0
  [[ -r /usr/share/i18n/locales/$1 ]] && command -v localedef >/dev/null || return 1
  mkdir -p "$TMP/locale"
  [[ -d $TMP/locale/$LOC ]] || localedef -i "$1" -f UTF-8 "$TMP/locale/$LOC" >/dev/null 2>&1 \
    || [[ -d $TMP/locale/$LOC ]] || return 1
  export LOCPATH=$TMP/locale
}
