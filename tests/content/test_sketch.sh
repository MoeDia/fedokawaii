#!/usr/bin/env bash
# tests/content/test_sketch.sh — kawa-sketch: a new sketch in ~/Pictures/Sketches, a blank
# landscape page Xournal++ reads, never over an earlier one; Xournal++ is a stand-in.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
stub xournalpp; stub setsid '[ "$1" = -f ] && shift; exec "$@"'
case_ "a new sketch: ~/Pictures/Sketches/sketch DATE.xopp, opened in Xournal++"
rc 0 kawa-sketch
f=$(ls "$HOME/Pictures/Sketches")
[[ $f =~ ^sketch\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}\.[0-9]{2}\.xopp$ ]] && _ok || _no "named [$f]"
called "^xournalpp -- $HOME/Pictures/Sketches/$f\$"
case_ "the page: Xournal++'s gzipped XML, one plain white page, 1280 × 720 (the screen's shape)"
x=$(gzip -dc "$HOME/Pictures/Sketches/$f")
python3 -I -c 'import sys, xml.etree.ElementTree as E; r = E.fromstring(sys.stdin.read()); p = r.find("page"); b = p.find("background")
print(r.tag, r.get("fileversion"), len(r.findall("page")), p.get("width"), p.get("height"), b.get("type"), b.get("style"), b.get("color"))' <<<"$x" >"$TMP/p"
eq "$(cat "$TMP/p")" "xournal 4 1 1280.00 720.00 solid plain #ffffffff"
case_ "again within the minute: a new one beside it, (1) — never over the first"
echo drawn >"$TMP/mark"; cp "$TMP/mark" "$HOME/Pictures/Sketches/$f.keep"
rc 0 kawa-sketch; eq "$(ls "$HOME/Pictures/Sketches" | grep -c '(1)\.xopp$')" 1
case_ "Xournal++ missing: said, exit 1"
rm -f "$STUBS/xournalpp"
if command -v xournalpp >/dev/null; then _ok; else
  kawa-sketch; eq "$?" 1; called 'notify-send -a desktop -u critical sketch Xournal\+\+ is missing'; fi
case_ "wrong use: exit 2"
rc 2 kawa-sketch --bogus
case_ "the launcher's Sketch"
has "$(cat "$REPO/configs/home/.local/share/applications/kawa-sketch.desktop")" 'Exec=@HOME@/.local/bin/kawa-sketch'
done_
