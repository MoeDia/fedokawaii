#!/usr/bin/env bash
# tests/static/test_release.sh — never again (his decision, 4 Nov 2026 21:40): fedokawaii is made for one
# Fedora, FEDORA_RELEASE in lib/common.sh. No code path, package name, repository URL, image or word for
# the release before it comes back in with a change (.claude's notes, the ledger and the plan are history:
# not read). The pattern is made from the number, so a move to the next release asks for the same sweep.
. "$(dirname "$0")/../lib/harness.sh"

case_ "one release: check.sh, verify.sh and setup.sh read it, and none of them names a number of its own"
rel=$(sed -n 's/^FEDORA_RELEASE=\([0-9]*\)$/\1/p' "$REPO/lib/common.sh")
[[ $rel =~ ^[0-9]+$ ]] && _ok || _no "no FEDORA_RELEASE=N in lib/common.sh"
grep -q 'VERSION_ID < FEDORA_RELEASE' "$REPO/check.sh" && _ok || _no "check.sh does not read FEDORA_RELEASE"
grep -q 'VERSION_ID >= FEDORA_RELEASE' "$REPO/verify.sh" && _ok || _no "verify.sh does not read FEDORA_RELEASE"
grep -q 'install Fedora \$FEDORA_RELEASE' "$REPO/setup.sh" && _ok || _no "setup.sh does not read FEDORA_RELEASE"

case_ "nothing tracked names the release before it"
p=$((rel - 1))
pat="\\bfc$p\\b|\\bF$p[a-z]?\\b|\\bf$p[a-z]?\\b|Fedora( Linux)? $p\\b|FEDORA $p\\b|[Ff]edora[-:/]$p\\b|releases/$p/|VERSION_ID=$p\\b|VERSION=\"$p\\b|--release $p\\b|--releasever=$p\\b|-$p-[0-9.]+\\.iso"
hits=$(git -C "$REPO" ls-files -z | grep -zvE '^\.claude/|^tests/static/test_release\.sh$' \
  | (cd "$REPO" && xargs -0 grep -nIE -- "$pat" 2>/dev/null) | cut -c1-160 || true)
[[ -z $hits ]] && _ok || _no "$(wc -l <<<"$hits") line(s) name Fedora $p:
$(head -n 20 <<<"$hits")"

done_
