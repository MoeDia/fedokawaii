#!/usr/bin/env bash
# tests/run.sh [AREA] — the desktop's own scripts against stand-ins, edge case by edge case.
# Every test file is tests/AREA/test_*.sh; each runs on its own in a throw-away home
# (tests/lib/harness.sh), so the machine itself is never touched. Needs bash, jq, python3.
#   bash tests/run.sh            all of them
#   bash tests/run.sh drives     only tests/drives/
# Exit status: 0 everything passed · 1 something failed (the lines above say what).
# A file still running after 15 minutes is stopped and counted as failed: only a guard against
# one that hangs — the longest (test_setup, test_upkeep) take three to five on a busy machine.
set -u
T=$(cd "$(dirname "$0")" && pwd)
# The tests run on a throw-away copy of the project in which every script (#!) is executable:
# a copy that lost its executable bits — a clone of what GitHub's upload page committed, a zip —
# would otherwise fail on its own stand-ins and helpers. The folder you run them from is
# never changed.
C=$(mktemp -d "${TMPDIR:-/tmp}/kawa-tests.XXXXXX") || exit 1
trap 'rm -rf "$C"' EXIT
tar -C "$T/.." --exclude=./.git -cf - . | tar -C "$C" -xf - || { echo "could not copy the project to $C" >&2; exit 1; }
find "$C" -type f ! -perm -u+x -exec sh -c 'for f; do [ "$(head -c2 "$f")" = "#!" ] && chmod +x "$f"; done; true' _ {} +
T=$C/tests
files=() failed=() n=0
for f in "$T"/*/test_*.sh; do
  [[ -e $f ]] || continue
  [[ -n ${1:-} && $f != "$T/$1/"* ]] && continue
  files+=("$f")
done
((${#files[@]})) || { echo "no tests found${1:+ for $1}" >&2; exit 1; }
for f in "${files[@]}"; do
  n=$((n + 1))
  out=$(cd "$T" && timeout 900 bash "$f" 2>&1 </dev/null); r=$?   # (a stub that reads stdin never waits on a terminal)
  printf '%s\n' "$out" | tail -n 40
  ((r == 0)) || failed+=("${f#"$T"/}")
done
echo
if ((${#failed[@]})); then
  printf '✘ %d of %d test files failed: %s\n' "${#failed[@]}" "$n" "${failed[*]}"; exit 1
fi
printf '✔ all %d test files passed\n' "$n"
