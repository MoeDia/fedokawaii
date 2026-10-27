#!/usr/bin/env bash
# tests/content/test_file.sh — kawa-file (Super+D, Alt+F in yazi, "File tools") with the real
# 7z, tar, qpdf, poppler, ImageMagick, Ghostscript (to make the PDFs) and tesseract: archives
# packed at each level (the last one remembered) and opened again, with and without a password;
# PDFs merged in the order chosen, split, cut to typed pages (and the typed mistakes said),
# rotated, reordered, pages deleted, their pictures and text taken out, drawn as PNG, locked and
# unlocked, made searchable; Xournal++'s runs (a stand-in: what it is asked, what it would write),
# the signature drawn once and stamped on the corner chosen. The menu is a stand-in that answers
# from $TMP/answers (a line a menu: words of the row to take, or what is typed; "esc": Esc);
# its hidden typing (--password) types $TPW. zstd and unrar, when absent here, are stand-ins too.
. "$(dirname "$0")/../lib/harness.sh"
for p in 7z qpdf pdftotext pdfimages pdftoppm pdfsig magick gs; do
  command -v "$p" >/dev/null || { printf '  – skipped: needs %s\n' "$p"; done_; exit; }
done
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
QPDF=$(command -v qpdf)   # (the real one, for the checks: the stand-in logs its arguments)

setup() {
  sandbox
  export CB=$TMP/clipboard
  stub wl-copy 't=text/plain; [ "$1" = --type ] && t=$2; cat >"$CB.data"; printf %s "$t" >"$CB.type"'
  stub wl-paste 'case "$1" in
  --list-types) [ -e "$CB.type" ] && cat "$CB.type" && echo ;;
  --no-newline) [ "$3" = "$(cat "$CB.type" 2>/dev/null)" ] && cat "$CB.data" || exit 1 ;;
esac'
  # the menu: the next line of $TMP/answers — with --index the number of the first line holding
  # it, else the words themselves (typed on its line); "esc" or none: Esc
  # hidden typing (--password, a prompt of its own: no answers line): $TPW (the second time
  # $TPW2, when set)
  stub kawa-menu 'case " $* " in *" --password "*)
  n=$(cat "$TMP/typed" 2>/dev/null || echo 0); echo $((n + 1)) >"$TMP/typed"
  if [ "$n" = 1 ] && [ -n "$TPW2" ]; then printf "%s\n" "$TPW2"; else printf "%s\n" "$TPW"; fi; exit 0 ;; esac
rows=$(cat); n=$(cat "$TMP/menus" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$TMP/menus"
printf "%s\n" "$rows" >"$TMP/menu.$n"; echo "$*" >"$TMP/menu.$n.args"
a=$(sed -n "${n}p" "$TMP/answers" 2>/dev/null)
case $a in ""|esc) exit 1 ;; esac
case " $* " in *" --index "*) printf "%s\n" "$rows" | grep -nF -- "$a" | head -n1 | cut -d: -f1 | awk "{ print \$1 - 1 }" ;;
*) printf "%s\n" "$a" ;; esac'
  # 7z and qpdf: the real ones, their arguments logged (a password must never be among them)
  stub 7z "exec $(command -v 7z) \"\$@\""
  stub qpdf "exec $(command -v qpdf) \"\$@\""
  # zstd: the real one when it is here (its calls logged), else a stand-in on gzip
  if command -v zstd >/dev/null; then stub zstd "exec $(command -v zstd) \"\$@\""
  else stub zstd 'd=0 o=""
while [ $# -gt 0 ]; do case $1 in -d|-dq) d=1 ;; -tq) exit 0 ;; -o) o=$2; shift ;; --) shift; break ;; esac; shift; done
if [ $d = 1 ]; then if [ -n "$o" ]; then gzip -dc "$1" >"$o"; else gzip -dc; fi; else gzip -c; fi'
  fi
  stub kawa-state 'f=$TMP/state; case $1 in get) v=$(sed -n "s/^$2=//p" "$f" 2>/dev/null); [ -n "$v" ] && echo "$v" || exit 1 ;;
set) grep -v "^$2=" "$f" >"$f.n" 2>/dev/null; echo "$2=$3" >>"$f.n"; mv "$f.n" "$f" ;; esac'
  stub xdg-open; stub kawa-term; stub kawa-shrink
  export TPW=secret-Pa55 TPW2="" WATCH=""
  A=$TMP/docs; mkdir -p "$A/folder/inner"
  echo "first file" >"$A/folder/one.txt"; head -c 200000 /dev/urandom | base64 >"$A/folder/inner/two.txt"
  rm -f "$TMP/answers" "$TMP/menus" "$TMP/typed"
}
answers() { printf '%s\n' "$@" >"$TMP/answers"; rm -f "$TMP/menus" "$TMP/typed"; }
kf() { kawa-file "$@" >/dev/null 2>&1; }
menu() { cat "$TMP/menu.$1"; }
textpdf() {   # textpdf FILE WORDS… — a PDF of words (a page each), letter size
  local ps="" w
  for w in "${@:2}"; do ps+="/Helvetica findfont 24 scalefont setfont 72 700 moveto ($w) show showpage "; done
  gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -sPAPERSIZE=letter -dFIXEDMEDIA -o "$1" -c "$ps" >/dev/null 2>&1
}
words() { pdftotext -layout "$1" - 2>/dev/null | tr -s ' \n\f' ' '; }
pages() { qpdf --show-npages "$1"; }
notice() { grep '^notify-send' "$CALLS" | tail -n1; }

# ── the menu ────────────────────────────────────────────────────────────────────────────
case_ "one PDF: its parts under their icons, what was chosen and its size at the first heading's end"
setup; textpdf "$A/report.pdf" "page one" "page two" "page three"
answers esc; rc 0 kawa-file "$A/report.pdf"
eq "$(grep '^part' "$TMP/menu.1" | cut -f2 | tr -d '\n')" "$ICON_PAGES$ICON_TAKE_OUT$ICON_SLIDERS$ICON_PEN$ICON_ARCHIVE" "pages, take out, change, sign, pack"
has "$(head -n1 "$TMP/menu.1")" "	1 PDF · "
for r in "split into pages" "take some pages" "rotate pages" "reorder pages" "delete pages" "its pictures" "its text" \
         "PNG · 150 dpi" "PNG · 300 dpi" "make it searchable" "make it smaller" "lock with a password" \
         "write or draw on it" "sign by hand" "draw your signature" "check its signatures" zip "7z · with a password" tar.zst; do
  has "$(menu 1)" "$r"
done
lacks "$(menu 1)" "stamp your signature" "(no signature drawn yet)"
lacks "$(menu 1)" "merge" "(one PDF: nothing to merge)"
has "$(cat "$TMP/menu.1.args")" "--index --select 1"
case_ "… a folder alone: only pack (the archive icon); an archive: unpack (its own icon) first"
answers esc; kf "$A/folder"; eq "$(grep '^part' "$TMP/menu.1" | cut -f2 | tr -d '\n')" "$ICON_ARCHIVE"
has "$(head -n1 "$TMP/menu.1")" "1 folder · "
(cd "$A" && 7z a -bso0 f.zip folder >/dev/null)
answers esc; kf "$A/f.zip"; eq "$(grep '^part' "$TMP/menu.1" | cut -f2 | tr -d '\n')" "$ICON_UNPACK$ICON_ARCHIVE"
has "$(menu 1)" "extract into a folder	f/"; has "$(menu 1)" "list its contents"; has "$(menu 1)" "test it"
lacks "$(menu 1)" "asks its password"

case_ "nothing chosen: a notice, no menu; --choose: the file dialog first; wrong use: 2"
setup; rc 1 kawa-file; called 'notify-send -a desktop -- .*nothing to work on'
[[ ! -e $TMP/menus ]] && _ok || _no "a menu opened"
stub kawa-pick 'printf "%s\n" "$TMP/docs/folder" >"$5"'; answers esc
rc 0 kawa-file --choose; called '^kawa-pick 1 0 0 '; eq "$(grep '^part' "$TMP/menu.1" | cut -f2)" "$ICON_ARCHIVE"
rc 2 kawa-file --bogus; rc 2 kawa-file --list

case_ "files copied in yazi (file:// links on the clipboard): those"
setup; textpdf "$A/a b.pdf" one
printf 'file://%s\r\n' "$(sed 's/ /%20/g' <<<"$A/a b.pdf")" | wl-copy --type text/uri-list
answers "its text"; rc 0 kawa-file
[[ -s "$A/a b.txt" ]] && _ok || _no "no text: $(ls "$A" | tr '\n' '|')"

# ── packing ─────────────────────────────────────────────────────────────────────────────
case_ "zip · fast: -mx1; beside it, named after it; the sizes and the ratio in the notice; its path copied"
setup; answers zip fast; rc 0 kawa-file "$A/folder"
z=$A/folder.zip; [[ -s $z ]] && _ok || _no "no $z"
called "^7z a -tzip -mx1 "
has "$(7z l -ba "$z")" "folder/inner/two.txt"
eq "$(grep -c '^row' "$TMP/menu.2")" 4 "fast, balanced, smallest, a level of your own"
has "$(menu 2)" "fast	quick · larger	mx1"; has "$(menu 2)" "smallest	slow · smallest	mx9"
eq "$(sed -n 1p "$TMP/menu.2" | cut -f1-3)" "part	$ICON_ARCHIVE	compression" "the compression menu's heading: the archive icon"
has "$(cat "$TMP/menu.2.args")" "--select 2" "(never chosen: balanced)"
called '^notify-send -a desktop -A default=open -- .* (KB|MB) → .* % .*folder\.zip · its path copied'
eq "$(cat "$CB.data")" "$z"
case_ "… remembered: the next zip's level menu starts on fast; again: (1), nothing overwritten"
eq "$(cat "$TMP/state")" "pack-zip=fast"
answers zip fast; rc 0 kawa-file "$A/folder"; has "$(cat "$TMP/menu.2.args")" "--select 1"
[[ -s "$A/folder (1).zip" ]] && _ok || _no "no second zip"

case_ "packing: its progress a row in the downloads' folder (the bar's percent), gone at the end; a notice"
setup; answers zip fast
stub 7z 'printf "  0M Scan\\b\\b\\b\\b  50%% 1 + x\\r"; /bin/sleep 0.6; cp "$XDG_RUNTIME_DIR"/kawa-downloads/file.* "'"$TMP"'/jobsnap" 2>/dev/null; exec '"$(type -P -a 7z | grep -v "$STUBS" | head -n1)"' "$@"'
rc 0 kawa-file "$A/folder"; tot=$(du -scb -- "$A/folder" | tail -n1 | cut -f1)
eq "$(cat "$TMP/jobsnap" 2>/dev/null)" "folder.zip	$((tot / 2))	$tot	$A/folder.zip"
eq "$(ls "$XDG_RUNTIME_DIR/kawa-downloads" 2>/dev/null)" "" "the row left after the job"
called '^notify-send -a desktop -A default=open -- .*folder\.zip'
case_ "7z · smallest with a password: -mx9, solid, AES with the names hidden — the password only on stdin"
setup; answers "7z · with a password" smallest; rc 0 kawa-file "$A/folder"
s=$A/folder.7z; [[ -s $s ]] && _ok || _no "no $s"
called '^7z a -t7z -mx9 -ms=on .*-p -mhe=on '
eq "$(grep -c -- '--password' "$CALLS")" 2 "typed twice"
called "^kawa-menu --title password --prompt $ICON_LOCK   --password --width 40\$"
called "^kawa-menu --title the same again --prompt $ICON_LOCK   --password --width 40\$"
not_called "$TPW"
grep -rqs "$TPW" "$HOME" "$XDG_RUNTIME_DIR" && _no "the password is in a file" || _ok
7z l -ba -p- "$s" >/dev/null 2>&1 && _no "its names show without the password" || _ok
printf '%s\n' "$TPW" | 7z t "$s" >/dev/null 2>&1 && _ok || _no "the password does not open it"
has "$(cat "$TMP/state")" "pack-7z=smallest"
answers 7z balanced; kf "$A/folder"; has "$(cat "$TMP/menu.2.args")" "--select 3" "(smallest, remembered for 7z)"
case_ "… the two typings differ: nothing made"
setup; TPW2=other; answers "zip · with a password" fast; rc 1 kawa-file "$A/folder"
called 'notify-send .*the passwords differ'; [[ ! -e $A/folder.zip ]] && _ok || _no "a zip was made"
TPW2=""

case_ "a level of your own, checked against the format's bounds (zip 0–9, zstd 1–19) and remembered"
setup; answers tar.zst "a level of your own" 12; rc 0 kawa-file "$A/folder"
[[ -s $A/folder.tar.zst ]] && _ok || _no "no tar.zst"
called '^zstd -T0 -12'
has "$(menu 3)" "level " ; has "$(cat "$TMP/menu.3.args")" "--prompt level "
eq "$(sed -n 1p "$TMP/menu.3" | cut -f1-3)" "part	$ICON_SLIDERS	a level of your own" "the typed question's heading: the sliders"
eq "$(cat "$TMP/state")" "pack-zst=12"
answers tar.zst balanced; kf "$A/folder"; has "$(cat "$TMP/menu.2.args")" "--select 4"; has "$(menu 2)" "level 12"
for bad in 0 20 "x"; do
  answers tar.zst "a level of your own" "$bad"; rc 1 kawa-file "$A/folder"
  called "notify-send .*not a level: $bad"
done
answers zip "a level of your own" 0; rc 0 kawa-file "$A/folder"; called '^7z a -tzip -mx0 '
answers zip "a level of your own" 10; rc 1 kawa-file "$A/folder"
answers tar.zst smallest; rc 0 kawa-file "$A/folder"; called '^zstd -T0 -19 --long'
answers tar.zst fast; rc 0 kawa-file "$A/folder"; called '^zstd -T0 -3'

case_ "several things: one archive named after their folder, beside them"
setup; textpdf "$A/x.pdf" x; answers 7z fast; rc 0 kawa-file "$A/folder" "$A/x.pdf"
has "$(7z l -ba "$A/docs.7z")" "x.pdf"; has "$(7z l -ba "$A/docs.7z")" "folder/one.txt"

# ── unpacking ───────────────────────────────────────────────────────────────────────────
case_ "extract into a folder: named after it; a folder in it already: that one, not one inside another"
setup; (cd "$A" && 7z a -bso0 f.zip folder >/dev/null && 7z a -bso0 loose.zip folder/one.txt folder/inner >/dev/null)
answers "extract into a folder"; rc 0 kawa-file "$A/f.zip"
eq "$(cat "$A/f/one.txt")" "first file"
answers "extract into a folder"; rc 0 kawa-file "$A/loose.zip"
[[ -s $A/loose/one.txt && -s $A/loose/inner/two.txt ]] && _ok || _no "$(find "$A/loose" | tr '\n' '|')"
called 'notify-send -a desktop -A default=open -- .*extracted into a folder'
case_ "extract here: beside it, nothing overwritten (a name taken: \"(1)\"); no work folder left"
answers "extract here"; rc 0 kawa-file "$A/f.zip"
[[ -s "$A/folder (1)/one.txt" ]] && _ok || _no "$(ls "$A" | tr '\n' '|')"
eq "$(find "$A" -maxdepth 1 -name '.kawa-file*' | wc -l)" 0
case_ "test it: whole · a damaged one said"
answers "test it"; rc 0 kawa-file "$A/f.zip"; called 'notify-send .*whole.*f\.zip · [0-9]+ files'
cp "$A/f.zip" "$A/bad.zip"; printf 'XXXXXXXXXXXXXXXXXXXXXXXX' | dd of="$A/bad.zip" bs=1 seek=60 conv=notrunc 2>/dev/null
answers "test it"; rc 1 kawa-file "$A/bad.zip"; called 'notify-send .*not whole.*bad\.zip'

case_ "a locked zip: the menu says so, its password asked, on stdin only; a wrong one said"
setup; (cd "$A" && printf '%s\n%s\n' "$TPW" "$TPW" | 7z a -bso0 -tzip -p -mem=AES256 locked.zip folder >/dev/null)
answers esc; kf "$A/locked.zip"; has "$(menu 1)" "asks its password"
answers "extract into a folder"; rc 0 kawa-file "$A/locked.zip"
eq "$(cat "$A/locked/one.txt")" "first file"; not_called "$TPW"
called "^kawa-menu --title locked\.zip · password --prompt $ICON_LOCK   --password --width 40\$"
TPW=wrong; answers "extract here"; rc 1 kawa-file "$A/locked.zip"; called 'notify-send .*did not open.*wrong password'
case_ "… a 7z with its names hidden: the same"
setup; (cd "$A" && printf '%s\n%s\n' "$TPW" "$TPW" | 7z a -bso0 -p -mhe=on hidden.7z folder >/dev/null)
answers "extract here"; rc 0 kawa-file "$A/hidden.7z"; [[ -s $A/folder\ \(1\)/one.txt ]] && _ok || _no "$(ls "$A" | tr '\n' '|')"

case_ "a tarball (tar with zstd): made, tested, opened again"
setup; answers tar.zst fast; rc 0 kawa-file "$A/folder"
answers "test it"; rc 0 kawa-file "$A/folder.tar.zst"; called 'notify-send .*whole'
answers "extract into a folder"; rc 0 kawa-file "$A/folder.tar.zst"
eq "$(cat "$A/folder (1)/one.txt")" "first file"
tar -czf "$A/old.tar.gz" -C "$A" folder; answers "extract here"; rc 0 kawa-file "$A/old.tar.gz"
[[ -s "$A/folder (2)/inner/two.txt" ]] && _ok || _no "$(ls "$A" | tr '\n' '|')"

case_ "list its contents: a window of its own, the screen in it (§7: the file icon, a row each, folders indented, sizes)"
answers "list its contents"; rc 0 kawa-file "$A/old.tar.gz"
called "^kawa-term --float --once kawa-file contents 80x37 -- .*kawa-file --list $A/old.tar.gz"
stub fzf 'cat >"$TMP/fzf.in"; printf "%s\n" "$@" >"$TMP/fzf.args"'
stub stty 'echo "40 80"'
python3 -I "$REPO/tests/lib/pty_run.py" --cols 80 --rows 40 --timeout 20 -- kawa-file --list "$A/old.tar.gz" >/dev/null 2>&1
has "$(cat "$TMP/fzf.in")" "  folder/"; has "$(cat "$TMP/fzf.in")" "    two.txt"
has "$(cat "$TMP/fzf.in")" "KB" "a file's size"
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
has "$(cat "$TMP/fzf.args")" "$ICON_FILE"; lacks "$(cat "$TMP/fzf.args")" "目" "no kanji (§13)"
lacks "$(cat "$TMP/fzf.args")" "esc close" "nothing obvious on its last line (§7)"

case_ "RAR (unrar, its own tool): asked on stdin through setsid, the password never an argument"
setup
command -v unrar >/dev/null && { printf '  – the real unrar is here: its stand-in skipped\n'; } || {
printf 'Rar!\x1a\x07\x01\x00LOCKED' >"$A/comic.rar"
stub unrar 'cmd=$1; shift; pw=0; [ "$1" = -p ] && pw=1
case $cmd in
  lt) [ "$1" = -p- ] && { echo "        Name: page1.png"; echo "       Flags: encrypted"; exit 0; } ;;
  x)  [ $pw = 1 ] || exit 11; read -r p; [ "$p" = secret-Pa55 ] || exit 11; for d; do :; done; echo img >"${d}page1.png" ;;
esac'
answers esc; kf "$A/comic.rar"; has "$(menu 1)" "asks its password"
answers "extract into a folder"; rc 0 kawa-file "$A/comic.rar"
eq "$(cat "$A/comic/page1.png" 2>/dev/null)" img; called '^unrar x -p -idq -o- -- '; not_called "$TPW"
TPW=no; answers "extract here"; rc 1 kawa-file "$A/comic.rar"; called 'notify-send .*did not open'
}
case_ "… unrar missing: said, critical (repair puts it back)"
setup; printf 'Rar!\x1a\x07\x01\x00' >"$A/c.rar"
if ! command -v unrar >/dev/null; then answers esc; rc 1 kawa-file "$A/c.rar"; called 'notify-send -a desktop -u critical -- .*unrar is missing'; fi

# ── PDFs ────────────────────────────────────────────────────────────────────────────────
pdfs() { textpdf "$A/b.pdf" "bee one" "bee two"; textpdf "$A/a.pdf" "ay one"; textpdf "$A/c.pdf" "cee one"
         magick -size 400x300 xc:skyblue -fill black -draw 'circle 200,150 200,60' "$A/pic.png"; }
case_ "merge: as chosen (b, a, c), by name, or an order typed; pictures as pages; beside the first"
setup; pdfs
answers "merge into one PDF" "as chosen"; rc 0 kawa-file "$A/b.pdf" "$A/a.pdf" "$A/c.pdf"
m=$A/b-merged.pdf; eq "$(pages "$m")" 4; eq "$(words "$m")" "bee one bee two ay one cee one "
has "$(menu 2)" "first: b.pdf"
eq "$(sed -n 1p "$TMP/menu.2" | cut -f1-3)" "part	$ICON_ORDER	order" "the order question's heading: the order icon"
answers "merge into one PDF" "by name"; rc 0 kawa-file "$A/b.pdf" "$A/c.pdf" "$A/a.pdf"
eq "$(words "$A/a-merged.pdf")" "ay one bee one bee two cee one "
answers "merge into one PDF" "an order of your own" "3 1 2"; rc 0 kawa-file "$A/b.pdf" "$A/a.pdf" "$A/c.pdf"
eq "$(words "$A/c-merged.pdf")" "cee one bee one bee two ay one "
has "$(menu 3)" "note	1  b.pdf"
eq "$(sed -n 1p "$TMP/menu.3" | cut -f1-3)" "part	$ICON_ORDER	an order of your own"
answers "merge into one PDF" "an order of your own" "4 1"; rc 1 kawa-file "$A/b.pdf" "$A/a.pdf" "$A/c.pdf"
called 'notify-send .*not an order: 4 1.*1 to 3'
answers "merge into one PDF" "an order of your own" "1 1"; rc 1 kawa-file "$A/b.pdf" "$A/a.pdf"; called 'there twice'
answers "merge into one PDF" "as chosen"; rc 0 kawa-file "$A/a.pdf" "$A/pic.png"
eq "$(pages "$A/a-merged (1).pdf")" 2
answers "make it a PDF"; rc 0 kawa-file "$A/pic.png"; eq "$(pages "$A/pic.pdf")" 1
read -r w h < <(pdfinfo "$A/pic.pdf" | awk '/^Page size/ { print int($3 + 0.5), int($5 + 0.5) }')
eq "$w $h" "842 631" "the longer side as A4's (842 pt)"

case_ "split · take some pages · rotate · reorder · delete"
setup; textpdf "$A/r.pdf" p1 p2 p3 p4 p5
answers "split into pages"; rc 0 kawa-file "$A/r.pdf"
eq "$(ls "$A/r-pages" | tr '\n' ' ')" "r-1.pdf r-2.pdf r-3.pdf r-4.pdf r-5.pdf "
answers "take some pages" "2-3,5"; rc 0 kawa-file "$A/r.pdf"; eq "$(words "$A/r.pages-2-3,5.pdf")" "p2 p3 p5 "
answers "take some pages" "4 - 5"; rc 0 kawa-file "$A/r.pdf"; eq "$(words "$A/r.pages-4-5.pdf")" "p4 p5 "
for bad in "9|page 9 is past the end: it has 5 pages" "4-2|4-2 runs backwards: say 2-4" "two|not a page list" "0|pages count from 1"; do
  answers "take some pages" "${bad%%|*}"; rc 1 kawa-file "$A/r.pdf"; called "notify-send .*no pages taken.*${bad#*|}"
done
answers "rotate pages" "a quarter right" "2,4"; rc 0 kawa-file "$A/r.pdf"
eq "$(sed -n 1p "$TMP/menu.2" | cut -f1-3)" "part	$ICON_RESTART	rotate" "the rotate menu's heading: the restart arrow"
eq "$(sed -n 1p "$TMP/menu.3" | cut -f1-3)" "part	$ICON_PAGES	which pages" "… and the question after it: the pages icon"
eq "$(pdfinfo -f 1 -l 5 "$A/r.rotated.pdf" | awk '/ rot:/ { printf "%s ", $4 }')" "0 90 0 90 0 "
answers "rotate pages" "upside down" "all pages"; rc 0 kawa-file "$A/r.pdf"
eq "$(pdfinfo -f 1 -l 5 "$A/r.rotated (1).pdf" | awk '/ rot:/ { printf "%s ", $4 }')" "180 180 180 180 180 "
answers "reorder pages" "5-4,1"; rc 0 kawa-file "$A/r.pdf"; eq "$(words "$A/r.reordered.pdf")" "p5 p4 p1 "
answers "delete pages" "2,4-5"; rc 0 kawa-file "$A/r.pdf"; eq "$(words "$A/r.without-2,4-5.pdf")" "p1 p3 "
answers "delete pages" "1-5"; rc 1 kawa-file "$A/r.pdf"; called 'notify-send .*nothing deleted.*every page'
[[ -s $A/r.pdf ]] && eq "$(pages "$A/r.pdf")" 5 "the original as it was"

case_ "take out: text (again: (1)), pictures, pages as PNG at 150 and 300 dpi"
answers "its text"; rc 0 kawa-file "$A/r.pdf"; has "$(cat "$A/r.txt")" "p3"
answers "its text"; rc 0 kawa-file "$A/r.pdf"; [[ -s "$A/r (1).txt" ]] && _ok || _no "the second text"
answers "its pictures"; rc 1 kawa-file "$A/r.pdf"; called 'notify-send .*no pictures in r\.pdf'; [[ ! -e $A/r-images ]] && _ok || _no "an empty folder left"
magick -size 400x300 xc:skyblue -fill black -draw 'circle 200,150 200,60' "$A/pic.png"
magick "$A/pic.png" "$A/pic.png" "$A/photos.pdf" 2>/dev/null
answers "its pictures"; rc 0 kawa-file "$A/photos.pdf"; (($(find "$A/photos-images" -name '*.png' | wc -l) >= 2)) && _ok || _no "$(ls "$A/photos-images" | tr '\n' '|')"
answers "its text"; rc 1 kawa-file "$A/photos.pdf"; called 'notify-send .*no text in photos\.pdf.*searchable'
answers "PNG · 150 dpi"; rc 0 kawa-file "$A/r.pdf"; eq "$(ls "$A/r-150dpi" | wc -l)" 5
eq "$(magick "$A/r-150dpi/$(ls "$A/r-150dpi" | head -n1)" -format '%w' info:)" 1275 "8.5 in × 150"
answers "PNG · 300 dpi"; rc 0 kawa-file "$A/r.pdf"; eq "$(magick "$A/r-300dpi/$(ls "$A/r-300dpi" | head -n1)" -format '%w' info:)" 2550
called 'notify-send -a desktop -A default=open -- .*pages as pictures · 300 dpi'

case_ "lock: AES-256, the password typed twice and handed over on qpdf's stdin; unlock; a wrong one said"
answers "lock with a password"; rc 0 kawa-file "$A/r.pdf"
l=$A/r.locked.pdf; rc 0 qpdf --requires-password "$l"; called '^qpdf @-'; not_called "$TPW"
has "$("$QPDF" --show-encryption --password-file=- "$l" <<<"$TPW" 2>&1)" "AESv3"
answers esc; kf "$l"; has "$(menu 1)" "unlock"; lacks "$(menu 1)" "split into pages" "(a locked PDF: only what it allows)"
answers unlock; rc 0 kawa-file "$l"; eq "$(words "$A/r.locked.unlocked.pdf")" "p1 p2 p3 p4 p5 "
called '^qpdf --password-file=- --decrypt '; not_called "$TPW"
grep -rqs "$TPW" "$HOME" "$XDG_RUNTIME_DIR" && _no "the password is in a file" || _ok
TPW=nope; answers unlock; rc 1 kawa-file "$l"; called 'notify-send .*wrong password.*stays locked'

case_ "make it smaller: kawa-shrink's own menu, on these PDFs (no second way)"
answers "make it smaller"; rc 0 kawa-file "$A/r.pdf"; called "^kawa-shrink $A/r.pdf\$"

case_ "check its signatures (pdfsig): none here, said"
answers "check its signatures"; rc 0 kawa-file "$A/r.pdf"; called 'notify-send .*no digital signature.*r\.pdf'

if command -v tesseract >/dev/null && tesseract --list-langs 2>/dev/null | grep -qx ara; then
case_ "make it searchable: a scan (no text) read by tesseract, English and Arabic, a page each, merged"
setup; magick -size 1275x1650 xc:white -fill black -pointsize 90 -draw "text 120,400 'INVOICE 2026'" -draw "text 120,800 'PAID IN FULL'" \
  -units PixelsPerInch -density 150 "$A/scan.pdf" 2>/dev/null
cp "$A/scan.pdf" "$A/s2.pdf"; qpdf --empty --pages "$A/scan.pdf" "$A/s2.pdf" -- "$A/scan2.pdf"
eq "$(words "$A/scan2.pdf" | tr -d ' ')" "" "(a scan: no words)"
answers "make it searchable"; rc 0 kawa-file "$A/scan2.pdf"
o=$A/scan2.searchable.pdf; eq "$(pages "$o")" 2; has "$(words "$o")" "INVOICE 2026"; has "$(words "$o")" "PAID IN FULL"
called 'notify-send .*reading scan2\.pdf.*2 pages'
fi

# ── Xournal++ (a stand-in): on a copy, the PDF made from it when it was saved ─────────────
xpp() {   # what Xournal++ is asked: --save writes the document, the window (--) saves when $DRAW,
  stub xournalpp 'case "$1" in   # --create-pdf a PDF, --create-img the ink on transparency
  --save=*) printf "xopp of %s\n" "$3" >"${1#--save=}" ;;
  --create-pdf=*) cp "$TMP/drawn.pdf" "${1#--create-pdf=}" ;;
  --create-img=*) magick -size 1667x625 xc:none -stroke black -strokewidth 12 -draw "line 300,500 1300,150" "${1#--create-img=}" ;;
  --) [ -n "$DRAW" ] && echo "a stroke" >>"$2" ;;
esac'
}
case_ "write or draw on it: --save to a document of its own, the window, then --create-pdf beside it"
setup; xpp; textpdf "$A/form.pdf" "form"; textpdf "$TMP/drawn.pdf" "form with ink"
export DRAW=1; answers "write or draw on it"; rc 0 kawa-file "$A/form.pdf"
called "^xournalpp --save=$XDG_RUNTIME_DIR/kawa-file\.[^/]*/edit\.xopp -- $A/form\.pdf\$"
called "^xournalpp -- $XDG_RUNTIME_DIR/kawa-file\.[^/]*/edit\.xopp\$"
called "^xournalpp --create-pdf=$A/form\.annotated\.pdf -- "
eq "$(words "$A/form.annotated.pdf")" "form with ink "; eq "$(words "$A/form.pdf")" "form " "the original untouched"
answers "sign by hand"; rc 0 kawa-file "$A/form.pdf"; [[ -s $A/form.signed.pdf ]] && _ok || _no "no signed copy"
case_ "… closed without saving: nothing made, said"
DRAW=""; answers "write or draw on it"; rc 0 kawa-file "$A/form.pdf"
[[ ! -e "$A/form.annotated (1).pdf" ]] && _ok || _no "a PDF made"; called 'notify-send .*nothing saved'

case_ "draw your signature: a blank page, then --create-img without paper, trimmed, kept — and stamped at once"
setup; xpp; textpdf "$A/deal.pdf" one two three; export DRAW=1
answers "draw your signature" "last page" "bottom right"; rc 0 kawa-file "$A/deal.pdf"
called "^xournalpp -- $XDG_RUNTIME_DIR/kawa-file\.[^/]*/signature\.xopp\$"
called '^xournalpp --create-img=.*/sig\.png --export-range=1 --export-no-background --export-no-ruling --export-png-dpi=300 -- '
S=$HOME/.local/share/fedokawaii/signature.png
read -r w h c < <(magick "$S" -format '%w %h %[channels]' info:)
((w > 1000 && w < 1030 && h > 345 && h < 375)) && _ok || _no "trimmed to the ink: ${w}×$h"
[[ ${c%% *} == *a ]] && _ok || _no "no transparency: $c"   # (ImageMagick 7.1.2: "graya 2.0" — the channels, then their count)
has "$(menu 2)" "last page"; has "$(cat "$TMP/menu.2.args")" "--prompt page "
eq "$(sed -n 1p "$TMP/menu.2" | cut -f1-3)" "part	$ICON_PAGES	page" "the page question's heading: the pages icon"
eq "$(sed -n 1p "$TMP/menu.3" | cut -f1-3)" "part	$ICON_CORNER	corner" "the corner menu's heading: the corner icon"
eq "$(grep '^row' "$TMP/menu.3" | cut -f3 | tr '\n' '|')" "bottom right|bottom left|top right|top left|"
# where the ink went: page 3 drawn before and after, the difference's box (612 × 792 pt at 72 dpi)
ink() { pdftoppm -f "$2" -l "$2" -r 72 -png "$1" "$TMP/i1"; pdftoppm -f "$2" -l "$2" -r 72 -png "$A/deal.pdf" "$TMP/i0"
        magick "$TMP"/i1-*.png "$TMP"/i0-*.png -compose difference -composite -threshold 10% -format '%@' info:; rm -f "$TMP"/i[01]-*.png; }
g=$(ink "$A/deal.signed.pdf" 3); [[ $g =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]
x=${BASH_REMATCH[3]} y=${BASH_REMATCH[4]} w=${BASH_REMATCH[1]} h=${BASH_REMATCH[2]}
((x > 306 && y > 600 && 612 - x - w >= 30 && 612 - x - w <= 45 && 792 - y - h >= 30 && 792 - y - h <= 45)) && _ok || _no "bottom right, half an inch in: $g"
((w <= 123 && w >= 100)) && _ok || _no "a fifth of the page's width: $g"
eq "$(ink "$A/deal.signed.pdf" 1)" "0x0+612+792" "the other pages untouched"
has "$(words "$A/deal.signed.pdf")" "three" "the page's own words kept"
called 'notify-send -a desktop -A default=open -- .*signed · page 3, bottom right'
case_ "… stamped again, top left of page 1: the signature kept is offered, no drawing"
reset_calls; answers "stamp your signature" "first page" "top left"; rc 0 kawa-file "$A/deal.pdf"
not_called '^xournalpp'
g=$(ink "$A/deal.signed (1).pdf" 1); [[ $g =~ \+([0-9]+)\+([0-9]+)$ ]]
((BASH_REMATCH[1] >= 30 && BASH_REMATCH[1] <= 45 && BASH_REMATCH[2] >= 30 && BASH_REMATCH[2] <= 45)) && _ok || _no "top left: $g"
answers "stamp your signature" "7" ; rc 1 kawa-file "$A/deal.pdf"; called 'notify-send .*no page "7".*pages 1 to 3'
case_ "… a page with nothing drawn on it: no signature kept"
setup; xpp; textpdf "$A/deal.pdf" one; export DRAW=1
stub xournalpp 'case "$1" in --create-img=*) magick -size 50x50 xc:none "${1#--create-img=}" ;; --) echo x >>"$2" ;; esac'
answers "draw your signature"; rc 1 kawa-file "$A/deal.pdf"; called 'notify-send .*no signature on the page'
[[ ! -e $HOME/.local/share/fedokawaii/signature.png ]] && _ok || _no "an empty signature kept"
DRAW=""

case_ "a click on the notice opens the result"
setup; textpdf "$A/k.pdf" k; stub notify-send 'case "$*" in *default=open*) echo default ;; esac'
answers "its text"; rc 0 kawa-file "$A/k.pdf"; for _ in {1..40}; do grep -q '^xdg-open' "$CALLS" && break; sleep 0.05; done
called "^xdg-open $A/k\.txt\$"

case_ "its keys: Super+D (dwl), Alt+F in yazi; File tools in the launcher (--choose)"
has "$(cat "$REPO/src/dwl/config.h")" 'XKB_KEY_d,                 spawn,            SHCMD("kawa-file")'
has "$(cat "$REPO/configs/home/.config/yazi/keymap.toml")" 'on = "<A-f>",      run = "shell --orphan -- kawa-file %s"'
has "$(cat "$REPO/configs/home/.local/share/applications/kawa-file.desktop")" 'Exec=@HOME@/.local/bin/kawa-file --choose'
has "$(cat "$REPO/configs/home/.config/fedokawaii/keybinds.txt")" 'Super+D                 archives and PDFs'
done_
