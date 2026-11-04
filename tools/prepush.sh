#!/usr/bin/env bash
# tools/prepush.sh — never again, before a push to main (owner, 26 Oct 01:48: "run them all before
# every push"): the commit, in a throw-away copy, through
#   1 the whole suite (tests/run.sh; the never-again list and its checks are its regress area)
#   2 the headless set (tools/regress/run.sh on the real GPU; no GPU here: said, not run)
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

run_all() {   # run_all COMMIT
  local sha tree tmp log rc=0 r
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
    ( cd "$tmp" && bash tools/regress/run.sh --bin bin --repo-art ) 2>&1 | tee -a "$log"; r=${PIPESTATUS[0]}
    ((r == 0)) || rc=1
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
      run_all "$sha" || rc=$?
    done
    exit "$rc" ;;
  -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -*) echo "prepush: unknown option $1 — --install, --hook or a commit" >&2; exit 2 ;;
  *) run_all "${1:-HEAD}"; exit $? ;;
esac
