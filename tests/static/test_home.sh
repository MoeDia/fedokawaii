#!/usr/bin/env bash
# tests/static/test_home.sh — the home folders are lib/common.sh's, all lower-case: nothing the desktop
# ships names the old ones (Desktop, Documents, Downloads, Music, Pictures, Videos, Templates, Public,
# Notes, Books, ~/repos). Only kawa-tidy, which moves an old home, and that table may.
. "$(dirname "$0")/../lib/harness.sh"

case_ "no script or config names an old home folder"
hits=$(cd "$REPO" && /usr/bin/grep -rnIE '(~|\$HOME|\$\{HOME\}|%h|@HOME@|/home/[a-z]+)/(Desktop|Documents|Downloads|Music|Pictures|Videos|Templates|Public|Notes|Books|repos)\b' \
  bin configs system lib setup.sh theme.sh verify.sh fedokawaii.sh 2>/dev/null \
  | /usr/bin/grep -vE '^(bin/kawa-tidy|lib/common\.sh):' | cut -c1-160 || true)
[[ -z $hits ]] && _ok || _no "$(wc -l <<<"$hits") line(s):
$(head -n 20 <<<"$hits")"

done_
