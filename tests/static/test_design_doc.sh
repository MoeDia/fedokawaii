#!/usr/bin/env bash
# tests/static/test_design_doc.sh — docs/design-system.md, the single truth, read back: whole
# (no open questions, every section where scripts cite it, every file it names there), its
# palette equal to tools/wada-palette.py's, its contrast table equal to the measured one — and,
# for every surface already rebuilt to it (BUILT, §14), its numbers in that surface's files.
# A task of round 27 that rebuilds a surface adds it to BUILT with a check of its own below.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
DOC=$REPO/docs/design-system.md
BUILT=(palette)

case_ "whole: no open question left in it"
grep -nE '\b(TBD|TODO|FIXME|XXX)\b|\?\?' "$DOC" >"$TMP/open" && _no "$(head -3 "$TMP/open")" || _ok

case_ "the sections, numbered as the scripts cite them (§0–§15, in order)"
eq "$(grep -oE '^## [0-9]+\.' "$DOC" | tr -dc '0-9\n' | paste -sd ' ')" "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"

case_ "every file it names is in the repository"
grep -oE '`(bin|tools|configs|system|src|art|docs|lib|tests)/[^` ]+`' "$DOC" | tr -d '`' | sort -u >"$TMP/paths"
missing=$(while read -r p; do [[ -e $REPO/$p ]] || echo "$p"; done <"$TMP/paths")
eq "$missing" "" "named but not there: $missing"
[[ -s $TMP/paths ]] && _ok || _no "no paths read (the pattern?)"

case_ "the palette (§1): every token's hex, both moods, as tools/wada-palette.py makes it"
python3 -I - "$DOC" "$REPO/tools/wada-palette.py" >"$TMP/pal" <<'PY'
import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("wp", sys.argv[2]); wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
P, kami, tile, editor = wp.palette()
want = {k: (P["dark"][k], P["light"][k]) for k in wp.DOC_TOKENS + wp.DOC_TERM}
want["tile"] = (tile["dark"], tile["light"])
got, bad = {}, []
for line in open(sys.argv[1], encoding="utf-8"):
    for tok, d, l in re.findall(r"\| `([a-z_0-9]+)` \| `([0-9a-f]{6})`[^|]*\| `([0-9a-f]{6})`[^|]*", line):
        got[tok] = (d, l)
for k, v in want.items():
    if got.get(k) != v:
        bad.append(f"{k}: doc {got.get(k)} palette {v}")
for k in got:
    if k not in want:
        bad.append(f"{k}: in the doc, not a token")
print(len(got)); print("\n".join(bad))
PY
eq "$(head -1 "$TMP/pal")" "$(( $(python3 -I -c 'import importlib.util,sys; s=importlib.util.spec_from_file_location("wp",sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(len(m.DOC_TOKENS)+len(m.DOC_TERM))' "$REPO/tools/wada-palette.py") + 1 ))" "tokens read from the doc"
eq "$(tail -n +2 "$TMP/pal")" "" "the doc and the palette differ"

case_ "the contrast table (§1) is the measured one (tools/wada-palette.py --table)"
python3 -I - "$DOC" "$REPO/tools/wada-palette.py" <<'PY' >"$TMP/con"
import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("wp", sys.argv[2]); wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
P = wp.palette()[0]
roles = ["faint", "muted", "text", "strong", "accent_text", "asagi"]
bad = []; n = 0
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"\| (dark|light) `(ground|key|surface)` \| (.*) \|$", line.strip())
    if not m: continue
    n += 1
    cells = [c.strip() for c in m.group(3).split("|")]
    for r, c in zip(roles, cells):
        meas = f"{wp.contrast(P[m.group(1)][r], P[m.group(1)][m.group(2)]):.1f}"
        if c != meas: bad.append(f"{m.group(1)} {m.group(2)} {r}: doc {c}, measured {meas}")
print(n); print("\n".join(bad))
PY
eq "$(head -1 "$TMP/con")" 4 "rows read"
eq "$(tail -n +2 "$TMP/con")" ""

# ── the surfaces rebuilt to it (§14) ───────────────────────────────────────────────────────────
built_palette() {   # the generated theme files carry the doc's inks
  local m; for m in dark light; do
    local f=$REPO/configs/home/.config/fedokawaii/themes/$m
    eq "$(sed -n 's/^ground=//p' "$f/panel.conf") $(sed -n 's/^accent=//p' "$f/panel.conf")" \
       "$(grep -oE '^\| `(ground|accent)` \| `[0-9a-f]{6}`[^|]*\| `[0-9a-f]{6}`' "$DOC" \
          | sed -E "s/.*\| \`([0-9a-f]{6})\`[^|]*\| \`([0-9a-f]{6})\`/\1 \2/" \
          | awk -v m="$m" '{print (m == "dark") ? $1 : $2}' | paste -sd ' ')" "$m: panel.conf's ground and accent"
  done
}
for s in "${BUILT[@]}"; do
  case_ "§14 $s: rebuilt to the doc — its numbers in its files"
  "built_$s"
done
done_
