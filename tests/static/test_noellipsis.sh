#!/usr/bin/env bash
# tests/static/test_noellipsis.sh — no text of the desktop is ever cut with "…" (or "..."):
# what does not fit is said shorter where it is made, or cut at a word's end, never dotted.
#   · nothing asks a toolkit to ellipsize (Pango's set_ellipsize / ELLIPSIZE, waybar's
#     max-length, which adds "…")
#   · no program text — a bar module's JSON, a menu's rows, the panel's drawing, a notice —
#     holds "…" or "...": every non-comment line of bin/ and of the bar's, the launcher's and
#     the notices' configs (a docstring, a usage line, a message to stderr are words for a
#     terminal, not the screen's: left out)
#   · the shared cut (width.sh's cut_cols, kawa-panel's fit, kawa-nowplaying's words) cuts at a
#     word's end and adds nothing
#   · the panel's text() never draws an "…"
. "$(dirname "$0")/../lib/harness.sh"

case_ "nothing asks a toolkit to ellipsize: no set_ellipsize / ELLIPSIZE, no waybar max-length"
bad=$(grep -rnE 'set_ellipsize|EllipsizeMode|ELLIPSIZE|ellipsize *=|"max-length"' \
  "$REPO/bin" "$REPO/configs/home/.config/waybar" "$REPO/configs/home/.config/fuzzel" \
  "$REPO/configs/home/.config/mako" 2>/dev/null | grep -vE ':[0-9]+:\s*(#|//)')
[[ -z $bad ]] && _ok || _no "$bad"

case_ "no program text holds \"…\" or \"...\" (bin/, the bar's, the launcher's and the notices' configs)"
out=$(python3 -I - "$REPO" <<'EOF'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
files = [p for p in (root / "bin").iterdir() if p.is_file()]
for d in ("waybar", "fuzzel", "mako"):
    files += [p for p in (root / "configs/home/.config" / d).rglob("*") if p.is_file()]
# (pixel art drawn with dots: fetch's pictures, not text)
SKIP = {"fetch"}
dots = re.compile(r"…|\.\.\.")
for p in sorted(files):
    if p.name in SKIP:
        continue
    try:
        lines = p.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        continue
    python = bool(lines) and lines[0].startswith("#!") and "python" in lines[0]
    doc = css = False
    for n, l in enumerate(lines, 1):
        s = l.strip()
        if python:
            q = s.count('"""')
            if doc or q:
                if q % 2:
                    doc = not doc                     # (a docstring opens or closes here)
                continue
            if s.startswith("#"):
                continue
            code = re.sub(r"\s#\s.*$", "", l)
        else:
            if css:                                   # (inside a /* … */ comment)
                css = "*/" not in s
                continue
            if s.startswith("/*") and "*/" not in s:
                css = True
                continue
            if s.startswith("#") or s.startswith("//") or s.startswith("/*") or s.startswith("*"):
                continue
            code = re.sub(r"\s#\s.*$", "", l)
        if not dots.search(code):
            continue
        if re.search(r"usage|>&2|file=sys\.stderr|2>&1 \|", code):
            continue                                  # (a terminal's words)
        print(f"{p.relative_to(root)}:{n}: {s[:120]}")
EOF
)
[[ -z $out ]] && _ok || _no "$out"

case_ "the shared cuts end at a word, adding nothing"
. "$REPO/configs/home/.config/fedokawaii/width.sh"
eq "$(cut_cols "SanDisk Ultra Fit USB 3.1 Flash Drive" 20)" "SanDisk Ultra Fit"
eq "$(cut_cols "Supercalifragilistic" 10)" "Supercalif" "one word too long: its first letters"
eq "$(cut_cols "short" 10)" "short"
eq "$(cut_cols "夜の音楽 — 坂本龍一" 12)" "夜の音楽 —" "wide letters count two"
src=$(sed -n '/^words() {/,/^}/p' "$REPO/bin/kawa-nowplaying"); eval "$src"
eq "$(LC_ALL=C.UTF-8; words "Ryuichi Sakamoto — async (Live at Park Avenue Armory)" 30)" "Ryuichi Sakamoto — async (Live"
eq "$(python3 -I -B -c 'import importlib.machinery as m, importlib.util as u, sys
sys.dont_write_bytecode = True; sys.modules["gi"] = None
l = m.SourceFileLoader("kp", sys.argv[1]); k = u.module_from_spec(u.spec_from_loader("kp", l))
l.exec_module(k)
print(repr(k.fit("Home Network 5G Extended", k.MON_W - k.CELL)), repr(k.fit("Home Networking 5G", k.MON_W - k.CELL)),
      repr(k.fit("typed text here", 40, tail=True)))' \
  "$REPO/bin/kawa-panel")" "'Home Network' 'Home' 'here'" \
  "the panel: a crest's state cut to its 86 px (a cut on a space keeps the word before it; one inside a word drops it), the typed text keeps its end"
lacks "$(sed -n '/    def text(cr, x, y, s, name/,/return log.width/p' "$REPO/bin/kawa-panel" | grep -v '"""' | grep -v '^\s*#')" '"…"' "the panel's text() adds no …"

done_
