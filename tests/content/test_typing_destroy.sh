#!/usr/bin/env bash
# tests/content/test_typing_destroy.sh — kawa-typing tested to destruction (typing_fuzz.py): everything a person, a
# terminal or a broken file can feed it, in every size and on every screen. FUZZ_MINUTES as long as you like (30 is the
# task's own bar: T26c; the everyday run takes one).
. "$(dirname "$0")/lib.sh"
sandbox
case_ "${FUZZ_MINUTES:-1} minute(s) of it: no traceback, no hang, no exit that was not asked for"
out=$(python3 -IB "$C/typing_fuzz.py" --minutes "${FUZZ_MINUTES:-1}" --seed "${FUZZ_SEED:-$RANDOM}" 2>&1); r=$?
((r == 0)) && _ok || _no "$(tail -n 8 <<<"$out")"
done_
