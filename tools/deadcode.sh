#!/usr/bin/env bash
# tools/deadcode.sh — shell functions nothing calls (T53: dead code out). Every function defined
# in the shell the desktop ships (bin/, lib/, system/, the root scripts, tools/) is looked for in
# the whole repository — code, tests, configs (a binding, a waybar click) — past its own
# definition. A name found nowhere else is listed; one called through a name built at run time
# (do_"$x", "$1"_check) is listed too, and kept by a line in KEEP below with the reason.
#   bash tools/deadcode.sh        the uncalled functions, FILE:LINE NAME a line
# Exit 0 none · 1 some (listed) · 2 no shell files to read
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo" || exit 2
# called through a name made at run time — each with where it is made
KEEP=(
)
mapfile -t files < <(python3 tests/static/parsecheck.py shell . | grep -vE '^configs/')
((${#files[@]})) || { echo "deadcode: no shell files found here ($repo)" >&2; exit 2; }
found=0
while IFS=: read -r file line name; do
  [[ " ${KEEP[*]} " == *" $name "* ]] && continue
  # (every word-match of the name in the repository but its definition line)
  n=$(grep -rnIwF --exclude-dir=.git --exclude-dir=.claude --exclude='*.md' -- "$name" . | grep -vcF -- "./$file:$line:")
  ((n == 0)) && { printf '%s:%s %s\n' "$file" "$line" "$name"; found=1; }
done < <(grep -nE '^[[:space:]]*([A-Za-z_][A-Za-z0-9_-]*)[[:space:]]*\(\)[[:space:]]*\{' "${files[@]}" </dev/null \
           | sed -E 's/^([^:]+):([0-9]+):[[:space:]]*([A-Za-z_][A-Za-z0-9_-]*).*/\1:\2:\3/')
exit "$found"
