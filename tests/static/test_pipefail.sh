#!/usr/bin/env bash
# tests/static/test_pipefail.sh — under `set -o pipefail` a reader that stops early (grep -q,
# grep -m, head) can end its writer with SIGPIPE, and the whole pipeline then fails though the
# match was found: the boot splash read as missing from every boot image (lsinitrd | grep -q).
# In every script that sets pipefail, and the libraries setup.sh sources under it, such a
# reader takes its input from < <(…) instead (or reads it all: sed -n 1p, grep -c). A shell of
# its own (bash -c '…', sh -c '…') has no pipefail and is not looked at.
. "$(dirname "$0")/../lib/harness.sh"

case_ "no early-stopping reader at the end of a pipe under pipefail"
bad=$(python3 -I - "$REPO" <<'EOF'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
files = [p for p in root.rglob("*") if p.is_file() and "tests" not in p.parts and "docs" not in p.parts and ".git" not in p.parts
         and p.suffix in ("", ".sh") and not p.name.endswith((".md", ".txt"))]
early = re.compile(r"(?<!\|)\|(?!\|)\s*(grep\s+-[A-Za-z]*[qm]|grep\s+--quiet|head\s+(-n\s*)?-?1\b|head\s+-c)")
out = []
for p in files:
    try:
        t = p.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    if not t.startswith("#!") and p.parent.name != "lib":
        continue
    if not (re.search(r"(?m)^set -[A-Za-z]*o pipefail", t) or p.parent.name == "lib"):
        continue
    for n, line in enumerate(t.splitlines(), 1):
        code = line.split(" # ")[0].strip()
        if not code or code.startswith("#") or "bash -c" in code or "sh -c" in code:
            continue
        if early.search(code) and "|| true" not in code:
            out.append(f"{p.relative_to(root)}:{n}: {code[:120]}")
print("\n".join(out))
EOF
)
eq "$bad" "" "early-stopping readers in pipes under pipefail:
$bad"

done_
