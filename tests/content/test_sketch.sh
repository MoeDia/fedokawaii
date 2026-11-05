#!/usr/bin/env bash
# tests/content/test_sketch.sh — kawa-sketch: a new sketch in ~/Pictures/Sketches, FireAlpaca's own
# blank page, never over an earlier one; FireAlpaca started dressed (the library, X11, the file by
# name); one running: it is asked. FireAlpaca and the library are stand-ins. tools/regress/sketch-pen.sh
# is the real thing, off the screen: the pen's pressure through to the stroke, both moods.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
stub setsid '[ "$1" = -f ] && shift; exec "$@"'
stub pgrep 'exit 1'
app=$HOME/.local/share/fedokawaii/firealpaca/app/usr/bin/FireAlpaca
mkdir -p "${app%/*}" "$HOME/.local/lib/fedokawaii"
printf '#!/bin/sh\nprintf "%%s\\n" "KAWA_FA_OPEN=$KAWA_FA_OPEN LD_PRELOAD=$LD_PRELOAD QT_QPA_PLATFORM=$QT_QPA_PLATFORM THEME=${QT_QPA_PLATFORMTHEME-unset} ARGS=$*" >>"$TMP/app.log"\n' >"$app"
chmod 755 "$app"
: >"$HOME/.local/lib/fedokawaii/kawa-firealpaca.so"
cp "$REPO/configs/home/.local/share/fedokawaii/firealpaca/blank.mdp" "${app%/usr/bin/*}/../blank.mdp"
export QT_QPA_PLATFORMTHEME=qt6ct QT_QPA_PLATFORM='wayland;xcb'
case_ "a new sketch: ~/Pictures/Sketches/sketch DATE.mdp, the blank page, opened in FireAlpaca"
rc 0 kawa-sketch
f=$(ls "$HOME/Pictures/Sketches")
[[ $f =~ ^sketch\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}\.[0-9]{2}\.mdp$ ]] && _ok || _no "named [$f]"
cmp -s "$HOME/Pictures/Sketches/$f" "$REPO/configs/home/.local/share/fedokawaii/firealpaca/blank.mdp" && _ok || _no "not the blank page"
has "$(cat "$TMP/app.log")" "KAWA_FA_OPEN=$HOME/Pictures/Sketches/$f "
case_ "it starts dressed: the library, X11 (its build has no other), no theme plugin of another Qt; nothing on its command line"
has "$(cat "$TMP/app.log")" "LD_PRELOAD=$HOME/.local/lib/fedokawaii/kawa-firealpaca.so"
has "$(cat "$TMP/app.log")" "QT_QPA_PLATFORM=xcb "
has "$(cat "$TMP/app.log")" "THEME=unset ARGS="
case_ "again within the minute: a new one beside it, (1) — never over the first"
echo drawn >"$HOME/Pictures/Sketches/$f"
rc 0 kawa-sketch; eq "$(ls "$HOME/Pictures/Sketches" | grep -c '(1)\.mdp$')" 1
eq "$(cat "$HOME/Pictures/Sketches/$f")" drawn "the first as drawn"
case_ "a file named: that file, by its whole path; none made"
n=$(ls "$HOME/Pictures/Sketches" | wc -l); : >"$TMP/app.log"
echo x >"$TMP/old one.mdp"; (cd "$TMP" && rc 0 kawa-sketch "old one.mdp")
has "$(cat "$TMP/app.log")" "KAWA_FA_OPEN=$TMP/old one.mdp "
eq "$(ls "$HOME/Pictures/Sketches" | wc -l)" "$n"
case_ "a file that is not there: said, exit 1"
kawa-sketch "$TMP/nothing.mdp"; eq "$?" 1; called 'notify-send -a desktop -- .*  sketch no such file'
case_ "one running: it is asked (the request whole, in one step); no second start"
stub pgrep 'exit 0'
: >"$TMP/app.log"; export XDG_RUNTIME_DIR=$TMP/run; mkdir -p "$XDG_RUNTIME_DIR"
rc 0 kawa-sketch "$TMP/old one.mdp"
eq "$(cat "$TMP/run/kawa-firealpaca.open")" "$TMP/old one.mdp"
[[ ! -e $TMP/run/kawa-firealpaca.open.new ]] && _ok || _no "the part-written request left"
eq "$(cat "$TMP/app.log")" "" "no second FireAlpaca"
stub pgrep 'exit 1'
case_ "FireAlpaca missing: said, exit 1"
mv "$app" "$app.gone"
kawa-sketch; eq "$?" 1; called 'notify-send -a desktop -u critical -- .*  sketch FireAlpaca is missing'
mv "$app.gone" "$app"
case_ "wrong use: exit 2"
rc 2 kawa-sketch --bogus; rc 2 kawa-sketch a b
case_ "the launcher's Sketch: our brush, a file by %f"
d=$(cat "$REPO/configs/home/.local/share/applications/kawa-sketch.desktop")
has "$d" 'Exec=@HOME@/.local/bin/kawa-sketch %f'; has "$d" 'X-Fedokawaii-Icon=brush'; has "$d" 'StartupWMClass=FireAlpaca'
case_ "the skin's inks: every token the library reads is in both moods' files, each a colour"
for m in dark light; do
  c=$REPO/configs/home/.config/fedokawaii/themes/$m/firealpaca.conf
  for t in ground view key edge edge2 faint muted text strong accent select text_on_select asagi flame; do
    grep -qE "^$t [0-9a-f]{6}\$" "$c" && _ok || _no "$m: no $t"
  done
  q=$REPO/configs/home/.config/fedokawaii/themes/$m/firealpaca.qss
  has "$(cat "$q")" '"Sumi UI"'
  for u in $(grep -oE 'KAWATHEME/[a-z0-9-]+\.png' "$q" | sort -u); do
    [[ -s $REPO/configs/home/.config/fedokawaii/themes/$m/${u#KAWATHEME/} ]] && _ok || _no "$m: $u not there"
  done
done
case_ "Super+/: the program in front is FireAlpaca, its sheet comes first"
has "$(cat "$REPO/bin/kawa-help")" 'FireAlpaca) s=sketch ;;'
[[ -s $REPO/configs/home/.config/fedokawaii/keys/sketch.txt ]] && _ok || _no "no sheet"
case_ "the seeds: Wada's 159 by name, no path of the machine it was made on, no id of its"
s=$REPO/configs/firealpaca
eq "$(grep -c '^name=' "$s/Palette.ini")" 159
has "$(cat "$s/Palette.ini")" 'name=Hermosa Pink'
if grep -qE '/dev/shm|/home/|/tmp/|^uuid=' "$s/Config.ini" "$s/Initialize.ini"; then _no "a machine's trace"; else _ok; fi
has "$(cat "$s/Config.ini")" 'showAlpacaButton=false'; has "$(cat "$s/Config.ini")" 'width=1920'
has "$(cat "$s/BrushNew.xml")" 'name="Fude"'
case_ "the masks: PNGs of the sizes the program's own have (the builder refuses others), nothing of theirs"
out=$(python3 -I "$REPO/tools/build-firealpaca.py" --sheet "$TMP/sheet.png" 2 2>&1); [[ -s $TMP/sheet.png ]] && _ok || _no "$out"
eq "$(find "$REPO/configs/home/.local/share/fedokawaii/firealpaca/icons" -name '*.png' | wc -l)" "$(grep -c '^@' "$REPO/art/firealpaca-icons.txt")"
if find "$REPO" -path "$REPO/.git" -prune -o \( -name 'FireAlpaca*.AppImage' -o -name 'fa_128.png' \) -print | grep -q .; then _no "a file of theirs in the repository"; else _ok; fi
done_
