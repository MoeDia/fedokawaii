#!/usr/bin/env bash
# tests/static/test_dwlconfig.sh — never again (1 Nov 2026, found by the Fedora 45 VM: every clean
# install stopped at the dwl build since the ink wash went in): a fresh install builds dwl with the
# patched config.def.h (setup.sh s_dwl, before theme.sh installs src/dwl/config.h), so every
# setting src/dwl/config.h declares beyond dwl's own (fixtures/dwl-upstream-config.txt, the pinned
# commit's) and the patch's code reads must have its default in the patch's config.def.h too.
. "$(dirname "$0")/../lib/harness.sh"
ids() { sed -n 's/^+\{0,1\}static const [^=;(]*[ *]\([A-Za-z_][A-Za-z0-9_]*\)\(\[[^]]*\]\)*[[:space:]]*=.*/\1/p' | sort -u; }
P=$REPO/src/dwl/dwl.patch

case_ "the pin the fixture was made from is the pin in use (made again when it moves)"
pin=$(sed -n 's/^DWL_COMMIT="\([^"]*\)".*/\1/p' "$REPO/fedokawaii.conf")
grep -q "commit $pin " "$HT/static/fixtures/dwl-upstream-config.txt" && _ok || _no "the fixture is not of $pin"

case_ "every setting config.h adds, that the patch's code reads, has a default in its config.def.h"
own=$(grep -v '^#' "$HT/static/fixtures/dwl-upstream-config.txt")
def=$(awk '/^\+\+\+ b\/config.def.h/ { on = 1; next } /^\+\+\+ / { on = 0 } on && /^\+/' "$P" | ids)
code=$(awk '/^\+\+\+ b\/dwl.c/ { on = 1; next } /^\+\+\+ / { on = 0 } on && /^\+/' "$P")
miss=""
for n in $(ids <"$REPO/src/dwl/config.h"); do
  grep -qxF "$n" <<<"$own" && continue
  grep -qw "$n" <<<"$code" || continue                  # (a name only config.h's own keys use)
  grep -qxF "$n" <<<"$def" || miss+=" $n"
done
[[ -z $miss ]] && _ok || _no "config.def.h (the patch) lacks:$miss — a fresh install's dwl would not build"

done_
