#!/usr/bin/env bash
# tools/regress/run.sh — every "never again" check here, one after another (each a headless kit on
# the real GPU: nothing of the session touched), and what each said. tools/prepush.sh runs it before a
# push, fedokawaii selftest --sandbox on the installed system.
#   bash tools/regress/run.sh [KIT OPTION…]     (e.g. --bin bin --repo-art: the repository, before an apply)
# Exit 0 all held · 1 one or more broken (named) · 2 a kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
export PATH=$HOME/.local/bin:$PATH             # (the desktop's own commands, as the session has them)
broken=() blind=() dwl="" prev=""
for o; do [[ $prev == --dwl ]] && dwl=$o; prev=$o; done
for t in "$here"/*.sh; do
  [[ $t == "$here/run.sh" ]] && continue
  n=$(basename "$t" .sh)
  # (the kit's options only for the checks that take them; a dwl binary for those that take only that)
  a=(); if grep -q 'KIT OPTION' "$t"; then a=("$@"); elif [[ -n $dwl ]] && grep -q '\[DWL\]' "$t"; then a=("$dwl"); fi
  out=$(timeout "${KAWA_REGRESS_LIMIT:-2600}" bash "$t" "${a[@]}" 2>&1); rc=$?
  case $rc in 0) mark=✔ ;; 2|124) mark='?' ;; *) mark=✘ ;; esac    # (?: it could not run, or could not judge: no verdict)
  printf '%s %-18s %s\n' "$mark" "$n" "$(grep . <<<"$out" | tail -n 1)"
  ((rc == 0)) || printf '    guards: %s\n' "$(python3 -I -B "$here/items.py" of "$n" | cut -c1-160)"
  ((rc == 0)) || { ((rc == 2 || rc == 124)) && blind+=("$n") || broken+=("$n"); }
done
((${#broken[@]})) && { echo "regress: broken — ${broken[*]}"; exit 1; }
((${#blind[@]})) && { echo "regress: could not run — ${blind[*]}"; exit 2; }
echo "regress: all held"
