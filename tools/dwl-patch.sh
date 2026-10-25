#!/usr/bin/env bash
# tools/dwl-patch.sh — src/dwl/dwl.patch regenerated from an edited dwl tree (default
# ~/.local/src/dwl, the checkout theme.sh builds: dwl at DWL_COMMIT with the patch applied).
#   bash tools/dwl-patch.sh [DWL_TREE]
# Edit dwl.c / client.h / config.def.h there, build and test there, then run this BEFORE
# `fedokawaii apply`: apply re-checks the tree against the repo's patch and would put the old
# one back over your edits. Exit: 0 written · 1 not a dwl checkout.
set -eu
tree=${1:-$HOME/.local/src/dwl}
repo=$(cd "$(dirname "$0")/.." && pwd)
git -C "$tree" rev-parse HEAD >/dev/null 2>&1 || { echo "dwl-patch: $tree is not a git checkout of dwl" >&2; exit 1; }
out=$(mktemp)
for f in dwl.c client.h config.def.h; do
  git -C "$tree" show "HEAD:$f" >"$out.a"
  diff -u -p --label "a/$f" --label "b/$f" "$out.a" "$tree/$f" >>"$out" || true
done
rm -f "$out.a"
mv "$out" "$repo/src/dwl/dwl.patch"
echo "dwl-patch: $(grep -c '^@@' "$repo/src/dwl/dwl.patch") hunks → src/dwl/dwl.patch"
