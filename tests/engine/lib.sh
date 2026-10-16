#!/usr/bin/env bash
# tests/engine/lib.sh — the system engine's world, made small: root's records
# (/var/lib/fedokawaii), the toolkit (/usr/local/lib/fedokawaii) and the commands root runs,
# all inside the test's own folder. The scripts under test are copied there with those
# fixed paths pointed into it (nothing else changed), so they run anywhere, as anyone.
#
#   engine_world        after sandbox: $R (root's side), `fedokawaii` (system/fedokawaii) first
#                       on PATH, a finished install of Fedora 44, sudo running the rest as you
#   front_world         $R/toolkit/fedokawaii.sh is the real front (fedokawaii.sh), with
#                       stand-ins for setup.sh, theme.sh, check.sh and verify.sh
#   rec NAME LINE       one of root's records
#   ago_s DAYS          the epoch DAYS days ago
#   tty_free CMD…       CMD with no terminal of its own (pause reads /dev/tty: never waits)
#   on_tty KEYS CMD…    CMD on a terminal of its own (script), KEYS typed into it
#   without NAME… -- CMD…  CMD on a PATH where those programs are not found (stubs gone too)
#   plain TEXT          TEXT without its colours
#   widest TEXT         the widest line of TEXT, in characters (colours left out)
. "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"
exec </dev/null                        # (nothing here reads the terminal the tests were started from)
DAY=86400
SETSID=$(command -v setsid)            # (the real one: the engine's own setsid is a stub)

# fixed paths, pointed into $R: each rewrite must match, or the fixture is out of date
pointed() {   # pointed SRC DEST SED-EXPR… — SRC copied to DEST with the rewrites (each must apply)
  local src=$1 dest=$2 e; shift 2
  cp "$src" "$dest"
  for e; do
    local before; before=$(cat "$dest")
    sed -i -e "$e" "$dest"
    [[ $(cat "$dest") != "$before" ]] || { printf 'fixture: %s — no match for: %s\n' "$src" "$e" >&2; exit 1; }
  done
  chmod 755 "$dest"
}

engine_world() {
  R=$TMP/root
  mkdir -p "$R/state" "$R/toolkit/docs" "$R/toolkit/lib" "$R/toolkit/system" "$R/toolkit/bin" "$R/toolkit/configs/home/.config/foot"
  pointed "$REPO/system/fedokawaii" "$STUBS/fedokawaii" \
    "s|^TK=/usr/local/lib/fedokawaii\$|TK=$R/toolkit|" \
    "s|^STATE=/var/lib/fedokawaii |STATE=$R/state |" \
    "s|/var/log/fedokawaii.log|$R/fedokawaii.log|g"
  # a finished install: Fedora 44, set up 30 days ago
  echo 'done' >"$R/state/phase"; touch -d "@$(ago_s 30)" "$R/state/phase"
  echo "$USER" >"$R/state/user"
  printf 'NAME="Fedora Linux"\nID=fedora\nVERSION_ID=44\nSUPPORT_END=2027-05-19\n' >"$R/os-release"
  export FEDOKAWAII_OS_RELEASE=$R/os-release
  # the toolkit: what the engine reads of it (its front is a stand-in unless front_world)
  cp "$REPO/fedokawaii.conf" "$R/toolkit/"
  printf '%%PDF-1.4 the handbook\n' >"$R/toolkit/docs/Fedokawaii-Guide.pdf"
  printf '#!/usr/bin/env bash\necho setup\n' >"$R/toolkit/setup.sh"
  printf '[main]\nfont=x\n' >"$R/toolkit/configs/home/.config/foot/foot.ini"
  # root's front, as a stand-in: says what it was asked, answers with $R/rc-ACTION (0)
  cat >"$R/toolkit/fedokawaii.sh" <<'EOF'
#!/usr/bin/env bash
R=${FK_R:?}
echo "front $*" >>"$R/front.log"
echo "(the front runs: $*)"
case $1 in
  conf) if grep -q BAD "$2"; then echo "✘ not saved — fedokawaii.conf would have: BAD is not a setting" >&2; exit 1; fi
        cat "$2" >"$R/toolkit/fedokawaii.conf"; echo "✔ fedokawaii.conf: every value is valid" ;;
esac
exit "$(cat "$R/rc-$1" 2>/dev/null || echo 0)"
EOF
  chmod 755 "$R/toolkit/fedokawaii.sh"
  export FK_R=$R TERM=xterm-256color   # (a terminal window: TERM=linux is a test of its own)
  # sudo: says it was asked, then runs the command as you (refused when $R/sudo-refused exists)
  stub sudo '[ -e "$FK_R/sudo-refused" ] && { echo "Sorry, user may not run sudo on this computer." >&2; exit 1; }
[ "$1" = -v ] && exit 0
exec "$@"'
  stub rpm 'case "$*" in *"--last kernel-core"*) printf "kernel-core-%s  Thu 01 Oct 2026 10:00:00 AM +04\n" "$(cat "$FK_R/newest-kernel" 2>/dev/null || echo 6.17.1-300.fc44.x86_64)" ;; esac'
  stub uname 'echo 6.17.1-300.fc44.x86_64'
  # df -B1 --output=size,avail / → the fixture's disk (2 TB, 641 GB free unless told)
  stub df 'printf "        1B-blocks          Avail\n%s\n" "$(cat "$FK_R/df" 2>/dev/null || echo "2000000000000 641000000000")"'
  stub snapper 'printf " # | Type   | Pre # | Date | User | Cleanup | Description\n---+--------+-------+------+------+---------+------------\n0  | single |       |      | root |         | current\n1  | single |       | Thu  | root |         | fedokawaii baseline\n"'
  stub findmnt 'cat "$FK_R/fstype" 2>/dev/null || echo btrfs'
  stub setsid; stub zathura; stub less 'case " $* " in *" -- "*) ;; *) cat >"$FK_R/less.out" ;; esac'; stub nvim; stub kawa-float; stub kawa-config
  stub curl 'exit 6'                         # (offline, unless a test says otherwise)
  stub shellcheck
}
without() {   # without NAME… -- CMD… — as if those programs were not installed at all
  local gone=() d
  while (($#)) && [[ $1 != -- ]]; do gone+=("$1"); shift; done; shift
  d=$TMP/path-without-$(IFS=-; echo "${gone[*]}")
  # (one folder of links to everything else on PATH, first found first — made once, in one go)
  [[ -d $d ]] || python3 - "$d" "$STUBS:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" "${gone[@]}" <<'PY'
import os, sys
d, path, gone = sys.argv[1], sys.argv[2], set(sys.argv[3:])
os.makedirs(d)
for p in path.split(":"):
    try: names = os.listdir(p)
    except OSError: continue
    for n in names:
        if n in gone or os.path.lexists(os.path.join(d, n)): continue
        os.symlink(os.path.join(p, n), os.path.join(d, n))
PY
  PATH=$d "$@"
}
front_world() {   # the real front in the toolkit, with the scripts it runs as stand-ins
  pointed "$REPO/fedokawaii.sh" "$R/toolkit/fedokawaii.sh" \
    "s|^STATE_DIR=/var/lib/fedokawaii\$|STATE_DIR=$R/state|" \
    "s|^LOG_FILE=/var/log/fedokawaii.log\$|LOG_FILE=$R/fedokawaii.log|" \
    "s|^TOOLKIT=/usr/local/lib/fedokawaii\$|TOOLKIT=$R/toolkit|" \
    's|\[\[ \$EUID -eq 0 \]\]|[[ ${FK_EUID:-$EUID} -eq 0 ]]|'
  cp "$REPO/lib/common.sh" "$R/toolkit/lib/"
  stand_ins "$R/toolkit"
  # root's own: runuser and getent, as for a desktop user of this name
  stub runuser 'while [ $# -gt 0 ]; do case $1 in -u) shift 2 ;; --) shift; break ;; *) break ;; esac; done; exec "$@"'
}
stand_ins() {   # stand_ins DIR — setup.sh, theme.sh, check.sh, verify.sh there: they log, answer $R/rc-NAME
  local s
  for s in setup theme check verify; do
    printf '#!/usr/bin/env bash\necho "%s $* (from ${0%%/*})" >>"%s/front.log"\necho "(%s runs)"\nexit "$(cat "%s/rc-%s" 2>/dev/null || echo 0)"\n' \
      "$s" "$R" "$s.sh" "$R" "$s" >"$1/$s.sh"
    chmod 755 "$1/$s.sh"
  done
}

rec() { printf '%s\n' "$2" >"$R/state/$1"; }
ago_s() { echo $(( $(date +%s) - $1 * DAY )); }
tty_free() { "$SETSID" -w "$@"; }     # (stdin as given: the plain menu reads it)
plain() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g' <<<"$1"; }      # (colours, and the screen-clearing codes)
widest() {
  local l w=0
  while IFS= read -r l; do ((${#l} > w)) && w=${#l}; done < <(plain "$1")
  echo "$w"
}
front_calls() { cat "$R/front.log" 2>/dev/null; }
on_tty() {   # on_tty KEYS CMD… — the keys a person would type, the screen they would see
  local keys=$1 q; shift; printf -v q '%q ' "$@"
  # (bounded: a screen still waiting for a key after its keys ran out must not hang the test)
  printf '%s' "$keys" | timeout 20 script -qec "$q" /dev/null 2>&1 | tr -d '\r'
}
has_script() { command -v script >/dev/null; }
