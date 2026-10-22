#!/usr/bin/env bash
# tests/status/test_osd.sh — kawa-osd, the level display of the volume, microphone and
# brightness keys: one panel that updates in place (mako's synchronous tag), drawn as quick
# settings' meter row (docs/design-system.md) — the glyph, the name in 12 columns, the
# slider drawn by the panel's own rule (its knob where kawa-panel puts it), a 4-column number. The notice daemon is lib.sh's fake.
. "$(dirname "$0")/lib.sh"
setup() { box; notices; . "$HOME/.config/fedokawaii/icons.sh"; . "$HOME/.config/fedokawaii/current/colors.sh"; }
body() { sed -n "\$s/^NOTICE [0-9]* osd | [^|]* | //p" "$NOTIFY_STATE/log"; }   # the last panel's markup
# panel_knob PCT — where kawa-panel's own slider puts its knob for PCT (its knob_of, run alone)
panel_knob() {
  python3 -I - "$REPO/bin/kawa-panel" "$1" <<'EOF'
import ast, sys
src = open(sys.argv[1]).read()
tree = ast.parse(src)
keep = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ("fill_of", "knob_of")
        or isinstance(n, ast.Assign) and any(getattr(t, "id", "") == "SPAN" for t in getattr(n.targets[0], "elts", n.targets))]
ns = {}
exec(compile(ast.Module(body=keep, type_ignores=[]), "kawa-panel", "exec"), ns)
print(ns["knob_of"](int(sys.argv[2])))
EOF
}

# ── what it shows ────────────────────────────────────────────────────────────
case_ "70 %: the glyph and name, the slider's knob at 131 of its 192 px, the number; app and category 'osd' (mako's rule), one panel in place"
setup
rc 0 kawa-osd 明 brightness 70
eq "$(osd | cut -d'|' -f2-)" "明  brightness|70%|131/192"
called '^notify-send -a osd -c osd -u low -h int:transient:1 -h string:x-canonical-private-synchronous:osd '

case_ "the slider: its knob where the panel's meter puts it, its width 192 px, at every level"
for p in $(seq 0 100); do
  kawa-osd "$ICON_VOL_2" volume "$p"
  eq "$(osd | cut -d'|' -f3-)" "$p%|$(panel_knob "$p")/192" "at $p %"
done
for p in 0 1 2 3 50 98 99 100; do
  kawa-osd "$ICON_VOL_2" volume "$p" off
  eq "$(osd | cut -d'|' -f3-)" "off|$(panel_knob "$p")/192" "muted, at $p %"
done

case_ "above 100 % (only the mixer goes there): the slider full, the real number; three digits at most"
kawa-osd "$ICON_VOL_4" volume 150
eq "$(osd | cut -d'|' -f3-)" "150%|186/192"
kawa-osd "$ICON_VOL_4" volume 1000
eq "$(osd | cut -d'|' -f3-)" "999%|186/192" "the panel never widens"

case_ "muted: the level kept, its fill hollow (a tick at each end), the knob muted; the number says 'off', faint"
kawa-osd "$ICON_VOL_MUTE" volume 40 off
eq "$(osd | cut -d'|' -f2-)" "$ICON_VOL_MUTE  volume|off|74/192"
# 40 %: fill 76 px, the knob at 74: hollow 0–72 (a tick, 64 + 4 + 2 + 1, a tick), its air, the knob
has "$(body)" "<span color='#$C_TEAL'>$ICON_LV_TICK$ICON_LV_HOLLOW_64$ICON_LV_HOLLOW_4$ICON_LV_HOLLOW_2$ICON_LV_HOLLOW_1$ICON_LV_TICK$ICON_GAP1</span><span color='#$C_MUTED'>$ICON_LV_KNOB</span>"
has "$(body)" "<span color='#$C_FAINT'> off</span>"

case_ "a level that is not a number: 0, still a well-formed panel"
for p in "" abc -5 4.5 '$(id)' '<b>'; do
  kawa-osd 明 brightness "$p"
  eq "$(osd | cut -d'|' -f3-)" "0%|0/192" "level [$p]"
done

case_ "the panel's inks: the glyph accent_text, the name text, the fill asagi, the knob strong, the track faint, the number muted"
setup
kawa-osd 明 brightness 50
b=$(body)
has "$b" "<span line_height='24576'><span color='#$C_ACCENT_TEXT'>明</span>"
has "$b" "<span color='#$C_TEXT'>brightness  </span>"
# 50 %: fill 95 px, the knob at 93 — fill 92 (64 + 16 + 8 + 4), air, the knob, air, the track
# from 98 to the third quarter's tick (at 143: 45 = 32 + 8 + 4 + 1), the tick, the rest (46: 32 + 8 + 4 + 2)
has "$b" "<span font='Sumi Icons 16px'><span color='#$C_TEAL'>$ICON_LV_FILL_64$ICON_LV_FILL_16$ICON_LV_FILL_8$ICON_LV_FILL_4$ICON_GAP1</span><span color='#$C_STRONG'>$ICON_LV_KNOB</span>"
has "$b" "<span color='#$C_FAINT'>$ICON_GAP1$ICON_LV_TRACK_32$ICON_LV_TRACK_8$ICON_LV_TRACK_4$ICON_LV_TRACK_1$ICON_LV_TICK$ICON_LV_TRACK_32$ICON_LV_TRACK_8$ICON_LV_TRACK_4$ICON_LV_TRACK_2</span>$ICON_GAP</span>"
has "$b" "<span color='#$C_MUTED'> 50%</span></span>"

case_ "one row on the panel's grid: the name 24 px after the glyph's pen (any glyph two columns, 16 px, then a space, 8), 12 columns of name, 12 squares, 8 px, 4 columns of number"
setup
kawa-osd 明 brightness 70
has "$(body)" "明</span> <span color='#$C_TEXT'>brightness  </span>"
kawa-osd "$ICON_VOL_3" volume 70
has "$(body)" "$ICON_VOL_3</span> <span color='#$C_TEXT'>volume      </span>"
kawa-osd "$ICON_MIC" microphone 70
has "$(body)" "$ICON_MIC</span> <span color='#$C_TEXT'>microphone  </span>"
lacks "$(body)" "font='Fusion" "no face but Sumi's"
v=$(for p in 5 70 100; do kawa-osd 明 brightness "$p"; body | sed -e "s/.*<span color='#$C_MUTED'>//" -e 's/<.*//'; done
    kawa-osd 明 brightness 5 off; body | sed -e "s/.*<span color='#$C_FAINT'>//" -e 's/<.*//')
eq "$(printf '%s\n' "$v" | awk '{ print length($0) }' | sort -u)" 4 "every value 4 columns: [$(tr '\n' '|' <<<"$v")]"
has "$(body)" "$ICON_GAP</span> <span color='#$C_FAINT'>" "8 px (a space) after the slider's 2 px of air, then the number"
case_ "where mako puts it: the glyph's pen where the panel's meter row has its glyph, the slider where the panel's starts; 412 × 60"
eq "$(python3 -I -B - "$REPO" <<'EOF' 2>&1
import importlib.machinery as m, importlib.util as u, re, sys
sys.modules["gi"] = None
l = m.SourceFileLoader("kp", sys.argv[1] + "/bin/kawa-panel"); k = u.module_from_spec(u.spec_from_loader("kp", l)); l.exec_module(k)
conf = open(sys.argv[1] + "/configs/home/.config/mako/config").read()
top, osd = conf.split("[category=osd]")[0], conf.split("[category=osd]")[1].split("\n[")[0]
get = lambda part, key: (re.findall(rf"^{key}=(.*)$", part, re.M) or [None])[-1]
pad = [int(x) for x in (get(osd, "padding") or get(top, "padding")).split(",")]
pad = pad * 2 if len(pad) == 1 else pad
border = int(get(top, "border-size")); width = int(get(osd, "width") or get(top, "width"))
pen = border + pad[1]
squares = pen + 2 * k.COL + k.COL + 12 * k.COL           # (the glyph, a space, the name's 12 columns)
x0 = k.BORDER + k.PAD                                      # (the panel's meter: a row of the panel's inner width)
print(pen == x0 + k.GAP, squares == x0 + k.INNER - k.TRAIL - k.SPAN, width, 2 * border + 2 * pad[0] + 24,
      squares + k.SPAN + 2 + k.COL + 4 * k.COL <= width - border - pad[1])
EOF
)" "True True 412 60 True"
eq "$(kawa-osd 明 "a very long label here" 50; osd | cut -d'|' -f2)" "明  a very long label here" "the title is whole…"
has "$(body)" "<span color='#$C_TEXT'>a very long </span>" "… the row's name cut to its 12 columns: the slider never moves"

case_ "the theme's colours (light); no theme set up: no panel in made-up colours, a failure"
setup; ln -sfn themes/light "$HOME/.config/fedokawaii/current"
. "$HOME/.config/fedokawaii/themes/light/colors.sh"
kawa-osd 明 brightness 50
has "$(body)" "color='#$C_TEAL'"
rm "$HOME/.config/fedokawaii/current"; n=$(wc -l <"$NOTIFY_STATE/log")
kawa-osd 明 brightness 50 2>/dev/null && _no "exit 0 without a theme" || _ok
eq "$(wc -l <"$NOTIFY_STATE/log")" "$n" "nothing shown"

# ── one panel, updated in place ──────────────────────────────────────────────
case_ "a held key (20 presses), and 20 at once: every one the same synchronous panel"
setup
for i in {1..20}; do kawa-osd "$ICON_VOL_2" volume $((i * 5)); done
for i in {1..20}; do kawa-osd "$ICON_VOL_2" volume $((i * 5)) & done; wait
eq "$(grep -c '^notify-send ' "$CALLS")" 40
eq "$(grep '^notify-send ' "$CALLS" | grep -vc -- '-h string:x-canonical-private-synchronous:osd ')" 0 "each one takes the panel's place"

case_ "mako not running: nothing shown, a failure (1)"
setup
NOTIFY_DOWN=1 kawa-osd 明 brightness 60; eq "$?" 1
eq "$(osd)" "" "no notice"
case_ "… and once it runs again, the panel comes back"
kawa-osd 明 brightness 70
eq "$(osd | cut -d'|' -f3)" "70%"

# ── misuse, environment ──────────────────────────────────────────────────────
case_ "--help: what it does, nothing shown; too few arguments: misuse"
setup
out=$(kawa-osd --help); r=$?
eq "$r" 0; has "$out" "kawa-osd ICON LABEL PERCENT"; eq "$(osd)" ""
rc 2 kawa-osd
rc 2 kawa-osd 明 brightness
eq "$(osd)" "" "nothing shown for misuse"

case_ "HOME with a space in it: the theme's colours still found"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"
kawa-osd 明 brightness 50
has "$(body)" "color='#$(. "$HOME/.config/fedokawaii/current/colors.sh"; echo "$C_TEAL")'"
eq "$(osd | cut -d'|' -f3)" "50%"

case_ "Turkish and Arabic locales: the same panel"
setup
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  locale_ok "$loc" || { skip "no $loc here"; continue; }
  LC_ALL=$loc kawa-osd 明 brightness 45 2>/dev/null
  eq "$(osd | cut -d'|' -f3-)" "45%|84/192" "$loc"
  has "$(body)" "<span color='#$C_TEXT'>brightness  </span>" "$loc: the name in its 12 columns"
done

done_
