#!/usr/bin/env bash
# tools/regress/anim.sh — never again a skipped step or a wrong length in what dwl draws (r24-18,
# r26-6, r27-dec-1): every animation of dwl's own judged from its frame log (tools/anim-check.sh).
#   bash tools/regress/anim.sh [KIT OPTION…]   (of the kit's options it takes --dwl BIN)
# Exit 0 held · 1 broken (said) · 2 could not run
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
out=$(bash "$here/../anim-check.sh" "${dwl[@]}" 2>&1); rc=$?
printf '%s\n' "$out" | tail -n 8 | sed 's/^/anim: /'
exit "$rc"
