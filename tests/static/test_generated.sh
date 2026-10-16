#!/usr/bin/env bash
# tests/static/test_generated.sh — what is made from something else still matches it:
#   · tools/build-themes.py, build-icons.py and build-cursors.py, run on a copy of the
#     repository, write the committed files byte for byte (nobody edited an output by hand,
#     nobody forgot to run them), and build-themes' colour check reads colours, not numbers
#   · every $ICON_… name used anywhere is one icons.sh defines; every icon written into a
#     config as its raw character (yazi's Lua, the bar) is the one its comment names
#   · every @TOKEN@ in configs/home is one theme.sh's render() fills
#   · the help sheet (keybinds.txt, Super+/) says what dwl's config.h binds
. "$(dirname "$0")/../lib/harness.sh"
S=$(cd "$(dirname "$0")" && pwd)
skipped() { printf '  – skipped: %s\n' "$1"; }
sandbox
G=$TMP/gen
copy() { rm -rf "$G"; mkdir -p "$G"; cp -r "$REPO"/{tools,art,configs,bin,src} "$G/"; }
same() {   # same — every file under configs/ of the copy is the repository's, byte for byte
  local d
  d=$(diff -rq "$REPO/configs" "$G/configs" 2>&1)
  if [[ -z $d ]]; then _ok; else while IFS= read -r l; do _no "${l//$G\//copy:}"; done <<<"$d"; fi
}

# ── the generators ───────────────────────────────────────────────────────────────────────
case_ "build-themes.py on a copy: runs, and writes exactly the committed theme files"
copy
(cd "$G" && python3 tools/build-themes.py) >"$TMP/log" 2>&1 && _ok || _no "it failed: $(tail -n 4 "$TMP/log" | tr '\n' ' ')"
same

case_ "build-themes.py's colour check: a stray colour stops it, a number is not a colour"
copy
printf '%s\n' 'C_X=c0ffee                # a colour the palettes do not have' >>"$G/bin/kawa-menu"
(cd "$G" && python3 tools/build-themes.py) >"$TMP/log" 2>&1; rc=$?
eq "$rc" 1 "a colour outside the palettes went through"; has "$(cat "$TMP/log")" "bin/kawa-menu:"
copy
# numbers in the scripts' arithmetic, sizes and sleeps: never read as colours
printf '%s\n' '((t - at < 500000)) && sleep 0.100000' 'n=$((n * 100000))' 'a=( 123456 ) b=( 654321 )' \
  >>"$G/bin/kawa-menu"
(cd "$G" && python3 tools/build-themes.py) >"$TMP/log" 2>&1 && _ok || _no "a number taken for a colour: $(tail -n 3 "$TMP/log" | tr '\n' ' ')"
copy
printf '%s\n' 'C_GROUND=0f0e0c C_X=151515 --color=000000' >>"$G/bin/kawa-menu"   # (all-digit colours too)
(cd "$G" && python3 tools/build-themes.py) >"$TMP/log" 2>&1; rc=$?
eq "$rc" 1 "an all-digit colour after = went through"; has "$(cat "$TMP/log")" "151515 is not a palette colour"

case_ "build-icons.py on a copy: the fonts and icons.sh, byte for byte"
if python3 -c 'import fontTools' 2>/dev/null; then
  copy
  (cd "$G" && python3 tools/build-icons.py) >"$TMP/log" 2>&1 && _ok || _no "it failed: $(tail -n 4 "$TMP/log" | tr '\n' ' ')"
  same
else skipped "python3-fonttools is not installed (dnf install python3-fonttools)"; fi

case_ "build-cursors.py on a copy: the pointers, byte for byte"
copy
(cd "$G" && python3 tools/build-cursors.py) >"$TMP/log" 2>&1 && _ok || _no "it failed: $(tail -n 4 "$TMP/log" | tr '\n' ' ')"
same

# ── icons ────────────────────────────────────────────────────────────────────────────────
ICONS=$REPO/configs/home/.config/fedokawaii/icons.sh
case_ "every \$ICON_… used anywhere is defined in icons.sh"
mapfile -t used < <(cd "$REPO" && grep -rhoE '\bICON_[A-Z0-9_]*[A-Z0-9]\b' bin system lib configs src setup.sh theme.sh \
  verify.sh check.sh fedokawaii.sh --exclude=icons.sh | sort -u)
((${#used[@]} > 30)) && _ok || _no "only ${#used[@]} icon names found"
for n in "${used[@]}"; do
  [[ $n == ICON_CHEVRON_RIGHT ]] && grep -q '@ICON_CHEVRON_RIGHT@' "$REPO/theme.sh" && { grep -q "^ICON_CHEVRON_RIGHT=" "$ICONS" && _ok || _no "$n"; continue; }
  grep -q "^$n=" "$ICONS" && _ok || _no "$n is used but icons.sh does not define it"
done

case_ "an icon written as its raw character is a Sumi Icons one, and the one its comment names"
out=$(python3 - "$REPO" <<'EOF'
import pathlib, re, sys
repo = pathlib.Path(sys.argv[1])
icons = {}
for ln in (repo / "configs/home/.config/fedokawaii/icons.sh").read_text().splitlines():
    m = re.match(r"(ICON_\w+)=\$'((?:\\x[0-9a-f]{2})+)'", ln)
    if m:
        icons[m.group(1)] = ord(bytes.fromhex(m.group(2).replace("\\x", "")).decode())
by_cp = {v: k for k, v in icons.items()}
bad = []
def pua(cp): return 0xF0000 <= cp <= 0xFFFFD
for f in sorted((repo / "configs").rglob("*")):
    if not f.is_file() or f.suffix in (".ttf", ".png", ".xpm") or "/cursors/" in str(f) or f.name == "icons.sh":
        continue
    text = f.read_text(errors="replace")
    rel = f.relative_to(repo)
    for n, ln in enumerate(text.splitlines(), 1):
        cps = [ord(c) for c in ln if pua(ord(c))]                               # raw UTF-8
        cps += [0x10000 + ((int(a, 16) - 0xD800) << 10) + (int(b, 16) - 0xDC00)   # JSON's \uD8xx\uDCxx
                for a, b in re.findall(r"\\u(D[89AB][0-9A-F]{2})\\u(D[C-F][0-9A-F]{2})", ln, re.I)]
        for esc in re.findall(r'"((?:\\\d{1,3}){4})"', ln):                      # Lua's "\243\190\128\178"
            cps.append(ord(bytes(int(x) for x in esc.split("\\")[1:]).decode()))
        for cp in cps:
            if pua(cp) and cp not in by_cp:
                bad.append(f"{rel}:{n}: U+{cp:X} is no icon of icons.sh")
        # "Sumi Icons: drive (U+FE049)": that name, that character
        for name, cp in re.findall(r"Sumi Icons: ([\w -]+?) \(U\+([0-9A-F]+)\)", ln):
            key = "ICON_" + name.strip().upper().replace(" ", "_").replace("-", "_")
            if icons.get(key) != int(cp, 16):
                bad.append(f"{rel}:{n}: {name} is U+{icons.get(key, 0):X} in icons.sh, the comment says U+{cp}")
            if cps and cps[0] != int(cp, 16):
                bad.append(f"{rel}:{n}: the character is U+{cps[0]:X}, the comment says U+{cp}")
print("\n".join(bad))
EOF
)
eq "$out" ""
case_ "the bar's icons are the ones its comments name"
bar() { python3 -B -c 'import json,sys; sys.path.insert(0,sys.argv[1]); import parsecheck as p
c=json.loads(p.strip_jsonc(open(sys.argv[2]).read())); print(eval(sys.argv[3]))' "$S" "$REPO/configs/home/.config/waybar/config.jsonc" "$1"; }
# shellcheck source=/dev/null
icon() { (. "$ICONS"; printf '%s' "${!1}"); }
eq "$(bar 'c["custom/torii"]["format"]')" "$(icon ICON_TORII)" "the torii key"
eq "$(bar 'c["custom/menu"]["format"]')" "$(icon ICON_CHEVRON)" "the quick-settings chevron"
eq "$(bar 'c["wireplumber"]["format-muted"]')" "$(icon ICON_SPEAKER_OFF) ---" "muted: speaker-off"
eq "$(bar '" ".join(c["wireplumber"]["format-icons"])')" "$(icon ICON_SPEAKER_LOW) $(icon ICON_SPEAKER)" "speaker-low, speaker"

# ── tokens ───────────────────────────────────────────────────────────────────────────────
case_ "every @TOKEN@ in configs/home is one theme.sh's render() fills"
fills=$(sed -n '/^render() {/,/^}/p' "$REPO/theme.sh" | grep -oE '@[A-Z][A-Z0-9_]*@' | sort -u)
for t in @HOME@ @UID@ @MONITOR_HZ@; do has "$fills" "$t" "render() does not fill $t"; done
# (@DEFAULT_AUDIO_SINK@ and its kin are wpctl's own names, not tokens)
while IFS=: read -r f n tok; do
  [[ $tok == @DEFAULT_AUDIO_SINK@ || $tok == @DEFAULT_AUDIO_SOURCE@ || $tok == @DEFAULT_SINK@ || $tok == @DEFAULT_SOURCE@ ]] && continue
  grep -qxF -- "$tok" <<<"$fills" && _ok || _no "${f#"$REPO"/}:$n: $tok is never filled in"
done < <(grep -rnoE '@[A-Z][A-Z0-9_]*@' "$REPO/configs/home" --exclude='*.ttf' --exclude='*.png')
case_ "@MPV_SCALING@ stands on a line of its own (render() replaces only a whole line)"
while IFS=: read -r f n line; do
  [[ $line == @MPV_SCALING@ ]] && _ok || _no "${f#"$REPO"/}:$n: $line"
done < <(grep -rn '@MPV_SCALING@' "$REPO/configs/home")
case_ "the tests' render (harness config) fills the same tokens as theme.sh"
hf=$(sed -n '/^config() {/,/^}/p' "$REPO/tests/lib/harness.sh" | grep -oE '@[A-Z][A-Z0-9_]*@' | sort -u)
eq "$hf" "$fills"

# ── the help sheet ───────────────────────────────────────────────────────────────────────
case_ "keybinds.txt (Super+/) says what src/dwl/config.h binds, and nothing it does not"
out=$(python3 "$S/keybinds.py" "$REPO")
while IFS= read -r ln; do [[ -n $ln ]] && _no "$ln"; done <<<"$out"
eq "$out" ""
case_ "… and the check is not blind: a key the sheet promises but dwl lacks is caught"
mkdir -p "$TMP/kb/src/dwl" "$TMP/kb/configs/home/.config/fedokawaii" "$TMP/kb/configs/home/.config/MangoHud"
cp "$REPO/fedokawaii.conf" "$TMP/kb/"; cp "$REPO/configs/home/.config/MangoHud/MangoHud.conf" "$TMP/kb/configs/home/.config/MangoHud/"
grep -v 'XKB_KEY_Print,             spawn,            SHCMD("kawa-screenshot full")' "$REPO/src/dwl/config.h" >"$TMP/kb/src/dwl/config.h"
cp "$REPO/configs/home/.config/fedokawaii/keybinds.txt" "$TMP/kb/configs/home/.config/fedokawaii/"
has "$(python3 "$S/keybinds.py" "$TMP/kb")" "Shift+Print"
cp "$REPO/src/dwl/config.h" "$TMP/kb/src/dwl/config.h"
grep -v '^Super+Q ' "$REPO/configs/home/.config/fedokawaii/keybinds.txt" >"$TMP/kb/configs/home/.config/fedokawaii/keybinds.txt"
has "$(python3 "$S/keybinds.py" "$TMP/kb")" "config.h binds Super+q, the help sheet never says so"

done_
