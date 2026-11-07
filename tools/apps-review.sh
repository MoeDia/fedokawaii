#!/usr/bin/env bash
# tools/apps-review.sh — the app surfaces for the owner's verdict (T19s: yazi, btop, the calculator, books, the wallpaper
# picker): the real programs in a headless dwl (tools/kit.sh), both moods, from the repository's configs, into
# .claude/review/next/ as NN-name.png (dark | light at 1×) and NN-name-4x.png (the part that decides it, each pixel 4 × 4); the
# gaps measured in a table beside them (tools/apps-review-measure.py).
#   bash tools/apps-review.sh [--yazi BIN] [--out DIR] [--shots DIR]
#     --yazi   the patched yazi to run (default the one on PATH; before an apply: a build of src/yazi/yazi.patch)
#     --shots  reuse the screens in DIR/{dark,light}: only the sheets again
# Exit 0 · 2 the kit could not run.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
yazi="" out=$repo/.claude/review/next shots="" W=/dev/shm/r27/apps-review
while (($#)); do
  case $1 in
    --yazi) yazi=$(realpath "$2"); shift 2 ;;
    --out) out=$2; shift 2 ;;
    --shots) shots=$2; shift 2 ;;
    *) echo "usage: apps-review.sh [--yazi BIN] [--out DIR] [--shots DIR]" >&2; exit 2 ;;
  esac
done
mkdir -p "$W" "$out"
if [[ -z $shots ]]; then
  shots=$W/shots
  bin=$W/bin; mkdir -p "$bin"
  for f in "$repo"/bin/*; do ln -sf "$f" "$bin/"; done
  [[ -n $yazi ]] && ln -sf "$yazi" "$bin/yazi"
  cat >"$W/play.sh" <<'PLAY'
REPO=@REPO@; REAL=@REAL@
rm -rf "$HOME/.config/yazi"; cp -a "$REPO/configs/home/.config/yazi" "$HOME/.config/yazi"
cp "$REPO/configs/home/.config/fedokawaii/screen.sh" "$HOME/.config/fedokawaii/screen.sh"
rm -rf "$HOME/.config/btop"; mkdir -p "$HOME/.config/btop/themes"
sed -e 's/@BTOP_BOXES@/cpu gpu0 mem proc/' -e 's/@BTOP_GPU@/gpu0/g' "$REPO/configs/home/.config/btop/btop.conf" >"$HOME/.config/btop/btop.conf"
cp "$HOME/.config/fedokawaii/current/btop.theme" "$HOME/.config/btop/themes/fedokawaii.theme"
# books, three begun
mkdir -p "$HOME/Books" "$HOME/.local/share/zathura"
for b in "Logical Chess, Move by Move" "The Elements of Typographic Style" "Designing Design" "Hokusai: The Great Picture Book" "Grid Systems in Graphic Design" "Build Up Your Chess 1"; do cp "$REPO/docs/Fedokawaii-Learn.pdf" "$HOME/Books/$b.pdf"; done
python3 -I - "$HOME/.local/share/zathura/bookmarks.sqlite" "$HOME/Books" <<'PY'
import sqlite3, sys, os, time
db, books = sys.argv[1:]
c = sqlite3.connect(db)
c.execute("CREATE TABLE IF NOT EXISTS fileinfo (file TEXT PRIMARY KEY, page INTEGER, offset INTEGER, scale FLOAT, rotation INTEGER, pages_per_row INTEGER, first_page_column TEXT, position_x FLOAT, position_y FLOAT, time TIMESTAMP)")
for name, page, ago in (("Build Up Your Chess 1", 119, 3600), ("Grid Systems in Graphic Design", 311, 86400 * 3), ("Designing Design", 399, 86400 * 30)):
    t = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(time.time() - ago))
    c.execute("INSERT OR REPLACE INTO fileinfo (file, page, time) VALUES (?, ?, ?)", (os.path.join(books, name + ".pdf"), page, t))
c.commit()
PY
# the wallpapers as the PC has them
mkdir -p "$HOME/.cache/fedokawaii" "$HOME/.local/share/fedokawaii"
ln -sfn "$REAL/.local/share/fedokawaii/wallpapers" "$HOME/.local/share/fedokawaii/wallpapers"
cp "$REAL/.local/share/fedokawaii/wallpapers.list" "$HOME/.local/share/fedokawaii/wallpapers.list"
ln -sfn "$REAL/.cache/fedokawaii/wallpaper-screens" "$HOME/.cache/fedokawaii/wallpaper-screens"
# a folder with a bit of everything
D=$HOME/demo/fedokawaii; mkdir -p "$D"/{art/masters,bin,configs,docs,lib,src/dwl,system,tests,tools,.git,.claude}
( cd "$D" || exit
  for i in 1 2 3 4 5 6; do echo x >art/$i.txt; done; echo x >art/masters/a
  for f in kawa-bar kawa-calc kawa-books kawa-menu kawa-panel; do printf '#!/bin/sh\n' >bin/$f; chmod +x bin/$f; done
  head -c 3000 /dev/urandom >docs/guide.pdf; magick -size 595x842 xc:white docs/learn.pdf; echo hello >.gitignore; echo x >.shellcheckrc
  head -c 40000 /dev/urandom >blob.bin; : >empty.txt; printf '#!/bin/sh\necho hi\n' >setup.sh; chmod +x setup.sh
  cp "$REPO/README.md" README.md; cp "$REPO/CLAUDE.md" CLAUDE.md; cp "$REPO/fedokawaii.conf" fedokawaii.conf; cp "$REPO/theme.sh" theme.sh
  printf 'x' >"a file with a rather long name that goes on and on and on and on and on and on and on and on and on and on and on.txt"
  touch -d "3 days ago" README.md; touch -d "2 months ago" CLAUDE.md; touch -d "2 years ago" fedokawaii.conf; touch -d "5 hours ago" theme.sh; touch -d "20 minutes ago" setup.sh; touch -d "2 weeks ago" art lib bin )
panel; nap 0.5
chord logo r; nap 3.5; shot books; key Escape; nap 1
chord logo w; nap 4; key Home; nap 1; key Down Down; nap 6; shot wall; key r; nap 0.4; key o; nap 0.4; key s; nap 0.8; shot wall-set; key Escape; nap 1
setsid -f kawa-calc; nap 1; shot calc-empty
text '5 ft to cm'; nap 1; shot calc-typed; key Return; nap 0.6; shot calc-copied
text '15% of 2400'; nap 0.8; key Return; nap 0.4; text '120 usd to aed'; nap 1; key Return; nap 0.4; text '2^64'; nap 0.8; key Down; nap 0.3; shot calc-row; key Escape; nap 0.5
setsid -f kawa-term --float --once btop btop 140x41 -- btop; ( for i in 1 2; do timeout 18 sh -c 'while :; do :; done' & done; wait ) >/dev/null 2>&1 &
nap 22; shot btop; chord logo q; nap 0.6
footclient -a float -T yazi -W 235x51 -- yazi "$D" >/dev/null 2>&1 &
nap 2.5
key j j; nap 1; shot y-folder
key j j j j j j j j j j j; nap 0.8; shot y-card
key K; nap 0.3; key g g; nap 0.3; key j j j j j j j j j j j j j j j j j j; nap 0.4; key Tab; nap 1; key j; nap 0.3; shot y-spot; key Escape; nap 0.5
key K; nap 0.3; key g g; nap 0.2; key j j j j j j j j j j j j; nap 0.3
key r; nap 0.7; shot y-rename; key Escape; nap 0.3; key Escape; nap 0.5
key space; nap 0.2; key space; nap 0.3; key d; nap 0.7; shot y-trash; key n; nap 0.5; key Escape; nap 0.3
key a; nap 0.5; text 'notes/plan.pdf'; nap 0.4; shot y-create; key Escape; nap 0.3; key Escape; nap 0.5
key asciitilde; nap 0.8; shot y-help; key Escape; nap 0.3; key Escape; nap 0.5
key g; nap 0.7; shot y-which; key Escape; nap 0.5
key w; nap 0.5; shot y-tasks; key Escape; nap 0.5
key O; nap 0.6; shot y-pick; key Escape; nap 0.5
chord logo q; nap 0.6
footclient -a float -T yazi -W 117x51 -- yazi "$D" >/dev/null 2>&1 &
nap 2; key j j; nap 0.8; shot y-half; chord logo q; nap 0.6
footclient -a float -T yazi -W 58x25 -- yazi "$D" >/dev/null 2>&1 &
nap 2; key j j; nap 0.8; shot y-third; chord logo q; nap 0.6
PLAY
  sed -i "s|@REPO@|$repo|; s|@REAL@|$HOME|" "$W/play.sh"
  for th in dark light; do
    PATH=$HOME/.local/bin:$PATH nice -n 10 bash "$here/kit.sh" --theme "$th" --bin "$bin" --repo-art --themes "$repo/configs/home" \
      --time 300 --out "$shots/$th" --play "$W/play.sh" play >"$W/kit-$th.log" 2>&1 \
      || { echo "apps-review: the kit failed ($th): $(tail -n 2 "$W/kit-$th.log")" >&2; exit 2; }
  done
fi
python3 -I "$here/apps-review-measure.py" "$shots" "$out"
