#!/usr/bin/env bash
# tools/regress/anim.sh — never again a skipped step or a wrong length in what dwl draws (r24-18,
# r26-6, r27-dec-1): every animation of dwl's own judged from its frame log (tools/anim-check.sh).
# A step a busy machine skipped is no fault of dwl's: three tries, one clean run holds; a fault
# every try on a machine with room is broken, on a loaded one (load over half its cores) unjudged.
#   bash tools/regress/anim.sh [KIT OPTION…]   (of the kit's options it takes --dwl BIN)
# Exit 0 held · 1 broken (said) · 2 could not run, or too busy to judge
set -u
here=$(cd "$(dirname "$0")" && pwd)
dwl=()
while (($#)); do
  case $1 in
    --dwl) dwl=(--dwl "$2"); shift 2 ;;
    --bin|--theme|--out|--edit|--font|--fontdir|--themes|--tui|--play|--time|--tui-wait) shift 2 ;;
    *) shift ;;
  esac
done
for try in 1 2 3; do
  out=$(bash "$here/../anim-check.sh" "${dwl[@]}" 2>&1); rc=$?
  ((rc == 0)) && { echo "anim: held (try $try) — $(tail -n 1 <<<"$out")"; exit 0; }
  ((rc == 2)) && break
  sleep 15
done
grep '^anim-check' <<<"$out" | sed 's/^anim-check/anim/' >&2
read -r load _ </proc/loadavg
if ((rc != 2 && ${load%.*} * 2 >= $(nproc))); then
  echo "anim: too busy to judge (load $load on $(nproc) cores)"; exit 2
fi
echo "anim: broken in three tries"
exit "$rc"
