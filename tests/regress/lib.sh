# shellcheck shell=bash
# tests/regress/lib.sh — what the never-again checks share (tools/regress/README.md is the list):
# each leaves a line naming the owner's items and what it measured, on top of the harness's cases.
. "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

# item "ID…" WORDS — the line a check leaves: whose report it guards, what it measured
item() { printf '  %s · %s\n' "$1" "$2"; }

# code_lines — the lines of the desktop's own files as words on a screen could come from them:
# what a person reads, comments out. One "FILE:LINE:TEXT" a line.
code_lines() {
  python3 -I - "$REPO" <<'PY'
import os, re, sys
root = sys.argv[1]
for top in ("bin", "system", "lib", "configs/home"):
    for d, _, fs in os.walk(os.path.join(root, top)):
        for f in fs:
            p = os.path.join(d, f)
            try:
                lines = open(p, encoding="utf8").read().split("\n")
            except (OSError, UnicodeDecodeError):
                continue
            doc = False
            for n, l in enumerate(lines, 1):
                s = l.strip()
                q = s.count('"""')
                if doc or q:
                    if q % 2:
                        doc = not doc
                    continue
                if s.startswith(("#", "//", "/*", "*", "--", ";")):
                    continue
                print(f"{os.path.relpath(p, root)}:{n}:{re.sub(r'\s#\s.*$', '', l)}")
PY
}
