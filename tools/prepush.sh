#!/usr/bin/env bash
# tools/prepush.sh — never again, before a push to main (owner, 26 Oct 01:48: "run them all before
# every push"): the commit, in a throw-away copy, through
#   1 the whole suite (tests/run.sh; the never-again list and its checks are its regress area)
#   2 the headless set (tools/regress/run.sh on the real GPU, with the commit's own dwl: its patch on the
#     pinned source, built in the copy; the tree in ~/.local/src/dwl may be older or ahead; no GPU here: said, not run)
#   3 fedokawaii verify, on the installed system (when sudo needs no password; else said, not run)
#     bash tools/prepush.sh [COMMIT]   (default HEAD)
#     bash tools/prepush.sh --install  the git hook of this clone (every worktree's): a push to main
#                                      runs this; other branches pass untouched
#     --hook                           git's own call: the refs on stdin
# A tree that passed is not run twice (its hash in .git/fedokawaii-prepush-ok). What failed is said,
# with the owner's items it breaks (tools/regress/items.py blame).
# Exit 0 all held · 1 broken · 2 misuse or nothing to run.
set -u
common=$(git rev-parse --git-common-dir 2>/dev/null) || { echo "prepush: not in a clone" >&2; exit 2; }
[[ $common == /* ]] || common=$PWD/$common
mark=$common/fedokawaii-prepush-ok

# build_dwl COPY → the commit's own dwl, its patch on the pinned source: its path on stdout. No source to
# build from here (a clone with no dwl, a fake one): nothing, status 0; a patch that does not build: status 1
build_dwl() {
  local c=$1 src=$HOME/.local/src/dwl d=$1/.dwl-build pin wlr args=()
  [[ -f $c/src/dwl/dwl.patch && -f $c/src/dwl/config.h && -e $src/.git ]] || return 0
  pin=$(sed -n 's/^DWL_COMMIT="\([0-9a-f]*\)".*/\1/p' "$c/fedokawaii.conf") wlr=$(sed -n 's/^DWL_WLROOTS="\([0-9.]*\)".*/\1/p' "$c/fedokawaii.conf")
  [[ -n $pin && -n $wlr && -r /usr/local/lib/fedokawaii-wlroots-$wlr/cflags ]] || return 0
  mkdir "$d" && git -C "$src" archive "$pin" | tar -x -C "$d" || return 1
  git -C "$d" init -q && git -C "$d" apply - <"$c/src/dwl/dwl.patch" || return 1
  cp "$c/src/dwl/config.h" "$d/"
  # (lib/common.sh's dwl_make_args, as setup builds it)
  mapfile -t args < <(sed -n '/^DWL_MAKE=(/s/^DWL_MAKE=(XWAYLAND=-DXWAYLAND "\(.*\)")$/\1/p' "$c/lib/manifest.sh")
  make -C "$d" -j"$(nproc)" XWAYLAND=-DXWAYLAND "${args[@]}" "WLR_INCS=$(cat "/usr/local/lib/fedokawaii-wlroots-$wlr/cflags")" \
    "WLR_LIBS=-L/usr/local/lib/fedokawaii-wlroots-$wlr/lib -lwlroots-$wlr -Wl,--disable-new-dtags,-rpath,/usr/local/lib/fedokawaii-wlroots-$wlr/lib" >&2 || return 1
  printf '%s' "$d/dwl"
}

run_all() {   # run_all COMMIT
  local sha tree tmp log rc=0 r dwl
  sha=$(git rev-parse --verify -q "$1^{commit}") || { echo "prepush: no commit $1" >&2; return 2; }
  tree=$(git rev-parse "$sha^{tree}")
  [[ $(cat "$mark" 2>/dev/null) == "$tree" ]] && { echo "prepush: this tree passed already (${sha:0:7})"; return 0; }
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/kawa-prepush.XXXXXX") || return 2
  # shellcheck disable=SC2064  # (the folder, now)
  trap "rm -rf '$tmp'" EXIT
  git archive "$sha" | tar -x -C "$tmp" || { echo "prepush: the commit could not be read" >&2; return 2; }
  log=$tmp/.prepush.log
  echo "prepush: ${sha:0:7} — 1 of 3, the whole suite"
  ( cd "$tmp" && bash tests/run.sh ) 2>&1 | tee "$log"; r=${PIPESTATUS[0]}
  ((r == 0)) || rc=1
  if compgen -G '/dev/dri/renderD*' >/dev/null; then
    echo "prepush: 2 of 3, the headless set"
    if dwl=$(build_dwl "$tmp" 2>>"$log"); then
      ( cd "$tmp" && bash tools/regress/run.sh --bin bin --repo-art ${dwl:+--dwl "$dwl"} ) 2>&1 | tee -a "$log"; r=${PIPESTATUS[0]}
      ((r == 0)) || rc=1
    else
      echo "✘ dwl          the commit's src/dwl/dwl.patch does not build (the log's end: $(tail -n 2 "$log" | tr '\n' ' ' | cut -c1-120))" | tee -a "$log"
      rc=1
    fi
  else
    echo "prepush: 2 of 3, the headless set: no GPU here, not run"
  fi
  if command -v fedokawaii >/dev/null && sudo -n true 2>/dev/null; then
    echo "prepush: 3 of 3, verify"
    fedokawaii verify 2>&1 | tee -a "$log" | tail -n 12; r=${PIPESTATUS[0]}
    ((r == 0)) || rc=1
  else
    echo "prepush: 3 of 3, verify: asks for your password or no fedokawaii here, not run (fedokawaii verify)"
  fi
  if ((rc == 0)); then
    printf '%s\n' "$tree" >"$mark"
    echo "prepush: ${sha:0:7} held"
  else
    echo "prepush: ${sha:0:7} BROKEN — not pushed; what he reported that it breaks:"
    python3 -I -B "$tmp/tools/regress/items.py" blame "$log" 2>/dev/null
  fi
  return "$rc"
}

case ${1:-} in
  --install)
    hook=$common/hooks/pre-push
    mkdir -p "${hook%/*}"
    [[ -e $hook ]] && ! grep -q 'tools/prepush.sh' "$hook" && { echo "prepush: a hook of yours is there: $hook — left alone" >&2; exit 2; }
    cat >"$hook" <<'HOOK_END'
#!/bin/sh
# fedokawaii: before a push to main, everything (tools/prepush.sh); other branches pass.
t=$(git rev-parse --show-toplevel)/tools/prepush.sh
[ -f "$t" ] || exit 0
exec bash "$t" --hook
HOOK_END
    chmod +x "$hook"; echo "prepush: installed as $hook" ;;
  --hook)
    rc=0
    while read -r _ sha ref _; do
      [[ $ref == refs/heads/main && ! $sha =~ ^0+$ ]] || continue
      run_all "$sha" </dev/null || rc=$?
    done
    exit "$rc" ;;
  -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -*) echo "prepush: unknown option $1 — --install, --hook or a commit" >&2; exit 2 ;;
  *) run_all "${1:-HEAD}"; exit $? ;;
esac
