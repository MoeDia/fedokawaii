#!/usr/bin/env bash
# shellcheck disable=SC2088  # (a ~ here is the window's own way of writing the home folder)
# tests/content/test_books.sh — kawa-books (Super+R) against a made-up library: books being
# read, finished, moved since, new; PDF, EPUB (with and without a cover), comics, odd names
# (spaces, quotes, $(…), a leading dash, Japanese, a name that is not UTF-8), corrupt files,
# 0, 1 and 500 books, and zathura's memory of where you were (a real bookmarks.sqlite).
# The covers are drawn for real (poppler, bsdtar, ImageMagick, kawa-sixel) and read back.
. "$(dirname "$0")/lib.sh"

setup() {   # setup — a fresh sandbox with an empty ~/Books; fzf, zathura, gio as stand-ins
  sandbox; unset LOCPATH
  B=$HOME/Books DB=$XDG_DATA_HOME/zathura/bookmarks.sqlite K=$XDG_CACHE_HOME/kawa-books
  mkdir -p "$B" "${DB%/*}"
  export FZF_ARGS=$TMP/fzf.args FZF_IN=$TMP/fzf.in FZF_PICK=$TMP/fzf.pick
  # fzf: the add list (--multi) answers with the lines of $FZF_PICK it was offered;
  # the main list is recorded
  stub fzf 'case " $* " in
  *" --multi "*) cat >"$FZF_IN.add"; [ -s "$FZF_PICK" ] && grep -F -f "$FZF_PICK" "$FZF_IN.add" ;;
  *) for a; do printf "%s\n" "$a"; done >"$FZF_ARGS"; cat >"$FZF_IN" ;;
esac'
  stub setsid '[ "$1" = -f ] && shift; exec "$@"'
  stub zathura; stub gio; stub kawa-float; stub kawa-cell 'echo 9x21'
  : >"$FZF_PICK"
}
MAGICK=$(command -v magick) FD=$(command -v fd fdfind 2>/dev/null | head -n1)
now() { date -u '+%Y-%m-%d %H:%M:%S'; }
ago_utc() { date -u -d "$1" '+%Y-%m-%d %H:%M:%S'; }
plain() { sed 's/\x1b\[[0-9;]*m//g'; }
row() { kawa-books --rows | grep -F -- "$B/$1"$'\t'; }             # row NAME — its line
field() { cut -f"$1"; }
# the display width of each row's text (wide characters take two columns)
widths() { python3 -I -c 'import sys, unicodedata
for l in sys.stdin.read().splitlines():
    t = l.split("\t")[1]
    import re; t = re.sub("\x1b\\[[0-9;]*m", "", t)
    print(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in t))' | sort -u | tr '\n' ' '; }
cover() {   # cover PATH [COLS LINES] — the preview, as fzf asks for it
  FZF_PREVIEW_COLUMNS=${2:-36} FZF_PREVIEW_LINES=${3:-24} KAWA_CELL=9x21 kawa-books --preview "$1" "info one" "info two"
}

library() {   # library — the made-up library, and zathura's memory of it
  mk pdf "$B/Reading Now.pdf" 120
  mk pdf "$B/Done Book.pdf" 10 3f6185
  mk epub "$B/Flow.epub" meta
  mk cbz "$B/New Comic.cbz" p001.png p002.png p003.png read-me.txt
  mkdir -p "$B/Japanese" "$B/.Trash"
  mk epub "$B/Japanese/日本語の本.epub" property
  mk pdf "$B/it's \"quoted\" \$(id) \`id\`.pdf" 3
  mk pdf "$B/-dash first.pdf" 2
  mk epub "$B/no cover.epub" none
  mk epub "$B/named cover.epub" named
  mk pdf "$B/SHOUTING.PDF" 4
  mk pdf "$B/.hidden.pdf" 1; mk pdf "$B/.Trash/thrown.pdf" 1
  printf 'notes' >"$B/notes.txt"; printf 'AT&TFORM' >"$B/scan.djvu"
  ln -s "$B/nowhere.pdf" "$B/gone.pdf"
  # (older than the rest, so its place among the new ones is known)
  touch -d '-3 days' "$B/New Comic.cbz"
  mk sqlite "$DB" "$B/Reading Now.pdf" 86 "$(now)" \
                  "$B/Done Book.pdf" 9 "$(ago_utc '-15 days')" \
                  "/old/place/Flow.epub" 36 "$(ago_utc '-3 days')"
}

# ── the list ─────────────────────────────────────────────────────────────────
setup; library
out=$(kawa-books --rows)
case_ "the books: every kind, folders too; hidden ones, other files, DjVu and dead links not"
eq "$(wc -l <<<"$out")" 10
for n in "Reading Now.pdf" "Done Book.pdf" "Flow.epub" "New Comic.cbz" "Japanese/日本語の本.epub" \
         "it's \"quoted\" \$(id) \`id\`.pdf" "-dash first.pdf" "no cover.epub" "named cover.epub" "SHOUTING.PDF"; do
  has "$out" "$B/$n"$'\t'
done
lacks "$out" ".hidden"; lacks "$out" "thrown"; lacks "$out" "notes.txt"; lacks "$out" "scan.djvu" "(zathura here has no DjVu plugin)"
lacks "$out" "gone.pdf"

case_ "reading: page and total, a bar in tenths, read today"
r=$(row "Reading Now.pdf")
has "$(field 2 <<<"$r" | plain)" "━━━━━━━───     87/120"
eq "$(field 3 <<<"$r")" "read today" "when (the page is the list's)"
eq "$(field 4 <<<"$r")" "pdf · 25.4 KB" "the caption: no page count, the list's 87/120 says it"
eq "$(field 5 <<<"$r")" "" "found by its own path: zathura opens it where it was"
case_ "finished: 'done', a full teal bar, when"
r=$(row "Done Book.pdf")
has "$(field 2 <<<"$r" | plain)" "━━━━━━━━━━       done"; has "$(field 2 <<<"$r")" $'\e[96m━'
eq "$(field 3 <<<"$r")" "read 2 weeks ago" "when (done is the list's)"
case_ "moved since zathura saw it: found by name, the page kept, opened there (field 5)"
r=$(row "Flow.epub")
has "$(field 2 <<<"$r" | plain)" "━─────────       37/–" "no fixed pages: the same N/M, the M unknown"
eq "$(field 3 <<<"$r")" "read 3 days ago"; eq "$(field 5 <<<"$r")" 37
case_ "new: a grey bar, 'new', what it is"
r=$(row "New Comic.cbz")
has "$(field 2 <<<"$r" | plain)" "──────────        new"
has "$(field 4 <<<"$r")" "cbz · 3 pages · " "the pictures counted, not the text file"
case_ "the order: being read, most recent first; then the new ones, newest first"
eq "$(cut -f1 <<<"$out" | head -n3 | sed "s|$B/||" | tr '\n' '|')" "Reading Now.pdf|Flow.epub|Done Book.pdf|"
eq "$(cut -f1 <<<"$out" | tail -n1 | sed "s|$B/||")" "New Comic.cbz"
case_ "a one-page book: '1 page', not '1 pages'"
mk pdf "$B/Leaflet.pdf" 1
has "$(row Leaflet.pdf | field 4)" "pdf · 1 page · "
rm "$B/Leaflet.pdf"
case_ "titles: underscores read as spaces, the extension gone"
mk pdf "$B/a_long_title_here.pdf" 1
has "$(row a_long_title_here.pdf | field 2 | plain)" "a long title here "

case_ "every row is exactly the list's width, CJK counted as two (fzf 100 wide, 300, 71; the default)"
eq "$(FZF_COLUMNS=100 kawa-books --rows | widths)" "58 "
eq "$(FZF_COLUMNS=300 kawa-books --rows | widths)" "258 "
eq "$(FZF_COLUMNS=71 kawa-books --rows | widths)" "29 "
eq "$(FZF_COLUMNS=40 kawa-books --rows | widths)" "58 " "too narrow to trust: the window's own width"
eq "$(kawa-books --rows | widths)" "58 "
case_ "a title longer than its column is cut with …"
mk pdf "$B/$(printf 'word %.0s' {1..30}).pdf" 1
has "$(FZF_COLUMNS=71 kawa-books --rows | grep 'word word' | field 2 | plain)" "word…   ──" "6 columns: the word and …, never a space before it"

case_ "a name that is not UTF-8 (an old zip's), in a real UTF-8 locale: listed, the rest too"
if locale_of en_US; then L=$LOC
  mk pdf "$B/$(printf 'caf\xe9').pdf" 1
  out=$(LC_ALL=$L kawa-books --rows 2>&1); r=$?
  eq "$r" 0; eq "$(grep -c $'\t' <<<"$out")" 13 "every book still listed"
  has "$out" "$(printf 'caf\xe9').pdf"$'\t'
else skip "no en_US.UTF-8 locale here and none can be built"; fi

case_ "a name with a tab or a newline (it would break the list's columns): left out, the rest kept"
n0=$(kawa-books --rows | wc -l)
mk pdf "$B/$(printf 'tab\there').pdf" 1; mk pdf "$B/$(printf 'new\nline').pdf" 1
eq "$(kawa-books --rows | wc -l)" "$n0"
lacks "$(kawa-books --rows)" "tab"$'\t'"here"

case_ "emoji and accents in a title: padded as foot draws them, so the bars still line up"
setup
# (a cluster takes the sum of its characters' columns, two at most, as foot counts it —
# 👨‍👩‍👧 two, 👍🏽 two, ❤️ two with its emoji selector; an accent written apart adds none)
for t in "family 👨‍👩‍👧 photos:16" "thumbs 👍🏽 up:12" "❤️ heart:8" "1️⃣ one:6" "runner 🏃‍♀️ x:11" \
         "$(printf 'cafe\xcc\x81') au lait:12" "🇯🇵 trip:7"; do
  mk pdf "$B/${t%:*}.pdf" 1
  r=$(FZF_COLUMNS=100 kawa-books --rows | grep -F -- "$B/${t%:*}.pdf"$'\t' | field 2 | plain)
  pad=${r#"${t%:*}"}; pad=${pad%%[!\ ]*}
  eq "${#pad}" $((35 + 2 - ${t##*:})) "${t%:*}: its padding (title column 35, then 2 spaces)"
done

case_ "no books, ~/Books missing: an empty list, the folder made"
setup; rmdir "$B"
eq "$(kawa-books --rows)" ""; [[ -d $B ]] && _ok || _no "~/Books not made"
case_ "one book"
mk epub "$B/Only.epub" meta
eq "$(kawa-books --rows | wc -l)" 1

case_ "zathura's memory missing, empty, corrupt or locked: the books, all new"
setup; library; rm -f "$DB"
eq "$(kawa-books --rows | grep -c '  new')" 10
printf 'not a database' >"$DB"
eq "$(kawa-books --rows 2>&1 | grep -c '  new')" 10
rm -f "$DB"; mk sqlite "$DB" "$B/Reading Now.pdf" 86 "$(now)"
python3 -I -c 'import sqlite3, sys, time
c = sqlite3.connect(sys.argv[1]); c.execute("BEGIN EXCLUSIVE"); c.execute("UPDATE fileinfo SET page = 1"); time.sleep(4)' "$DB" & held=$!
sleep 0.5; s=$EPOCHREALTIME
eq "$(kawa-books --rows 2>&1 | wc -l)" 10 "zathura writing it right now"
e=$EPOCHREALTIME; (( ${e/./} - ${s/./} < 3000000 )) && _ok || _no "waited $(( (${e/./} - ${s/./}) / 1000 )) ms on a locked database"
kill "$held" 2>/dev/null; wait "$held" 2>/dev/null
case_ "zathura's memory under a folder with '#', '%' and a space"
setup; mk pdf "$B/Reading Now.pdf" 120
export XDG_DATA_HOME="$TMP/data #1 100%"; DB=$XDG_DATA_HOME/zathura/bookmarks.sqlite; mkdir -p "${DB%/*}"
mk sqlite "$DB" "$B/Reading Now.pdf" 86 "$(now)"
has "$(kawa-books --rows | plain)" "87/120"

case_ "the cache cannot be written (a full disk, a file in its place): the books still listed"
setup; mk pdf "$B/One.pdf" 5
rm -rf "$XDG_CACHE_HOME"; : >"$XDG_CACHE_HOME"
out=$(kawa-books --rows 2>"$TMP/err"); r=$?
eq "$r" 0; has "$out" "One.pdf"$'\t'; eq "$(cat "$TMP/err")" "" "nothing printed behind the list"
case_ "the page counts are kept, and counted again when a book changes"
setup; mk pdf "$B/One.pdf" 5
stub pdfinfo 'exec /usr/bin/pdfinfo "$@"'
kawa-books --rows >/dev/null; kawa-books --rows >/dev/null
eq "$(grep -c '^pdfinfo' "$CALLS")" 1 "counted once"
mk pdf "$B/One.pdf" 7; touch -d '+1 minute' "$B/One.pdf"
has "$(kawa-books --rows)" "pdf · 7 pages"
eq "$(grep -c '^pdfinfo' "$CALLS")" 2
case_ "a corrupt page-count cache: counted again"
printf '{not json' >"$K/pages.json"
has "$(kawa-books --rows)" "pdf · 7 pages"
case_ "corrupt books: listed by kind and size, without a page count"
printf '%%PDF-1.4 broken' >"$B/corrupt.pdf"; printf 'xx' >"$B/corrupt.cbz"; printf 'not a zip' >"$B/corrupt.epub"
out=$(kawa-books --rows 2>&1)
has "$out" $'\t\tpdf · 15 B\t'; has "$out" $'\t\tcbz · 2 B\t'; has "$out" $'\t\tepub · 9 B\t'

case_ "500 books (150 PDF, 100 comics, 250 EPUB): listed in reasonable time the first time, at once after that"
setup
python3 -I - "$B" "$C" <<'EOF'
import sys, zipfile
sys.dont_write_bytecode = True; sys.path.insert(0, sys.argv[2]); import make_books as m
pdf = m.pdf_bytes(30)
for i in range(150): open(f"{sys.argv[1]}/book {i:03d}.pdf", "wb").write(pdf)
for i in range(100):
    with zipfile.ZipFile(f"{sys.argv[1]}/comic {i:03d}.cbz", "w") as z:
        for p in range(20): z.writestr(f"{p:03d}.png", b"x")
for i in range(250): m.epub(f"{sys.argv[1]}/novel {i:03d}.epub", "meta")
EOF
s=$EPOCHREALTIME; n=$(kawa-books --rows | wc -l); e=$EPOCHREALTIME
eq "$n" 500; t1=$(( (${e/./} - ${s/./}) / 1000 ))
((t1 < 30000)) && _ok || _no "first listing took $t1 ms"
s=$EPOCHREALTIME; n=$(kawa-books --rows | wc -l); e=$EPOCHREALTIME
eq "$n" 500; t2=$(( (${e/./} - ${s/./}) / 1000 ))
((t2 < 2000)) && _ok || _no "second listing took $t2 ms"
eq "$(kawa-books --rows | widths)" "58 "
printf '    (500 books: %d ms the first time, %d ms after)\n' "$t1" "$t2"

# ── the cover ────────────────────────────────────────────────────────────────
setup; library
case_ "covers: the first page (PDF), the declared cover (EPUB 2 and 3), a cover-named picture, the first page (comic)"
for n in "Reading Now.pdf" "Flow.epub" "Japanese/日本語の本.epub" "named cover.epub" "New Comic.cbz"; do
  info=$(cover "$B/$n" | sixel_info)
  [[ $(jget p2 <<<"$info") == 1 ]] && _ok || _no "$n: no picture"
  lacks "$(jget colours <<<"$info")" "17,15,13" "$n drew the plain card (C_EDGE) instead of its cover"
done
has "$(cover "$B/Reading Now.pdf" | sixel_info | jget colours)" "82,35,23" "the PDF's red page"
has "$(cover "$B/Flow.epub" | sixel_info | jget colours)" "37,50,63" "the EPUB's blue cover"
case_ "an EPUB whose cover's address has %20 for a space (an href is a URL): its cover"
mk epub "$B/encoded.epub" encoded
info=$(cover "$B/encoded.epub" | sixel_info)
lacks "$(jget colours <<<"$info")" "17,15,13" "the plain card instead of its cover"
has "$(jget colours <<<"$info")" "37,50,63" "the EPUB's blue cover"
case_ "no picture in it, or corrupt: a plain card with its kind"
printf '%%PDF-1.4 broken' >"$B/corrupt.pdf"; printf 'xx' >"$B/corrupt.cbz"
for n in "no cover.epub" corrupt.pdf corrupt.cbz; do
  out=$(cover "$B/$n" 2>"$TMP/err")
  has "$(sixel_info <<<"$out" | jget colours)" "17,15,13" "$n: the card"
  eq "$(cat "$TMP/err")" "" "$n: nothing on stderr"
done
case_ "a comic whose pages have glob characters in their names: its first page"
mk cbz "$B/glob.cbz" 'p[1].png' 'q*2.png' 'r?3.png'      # (as a pattern, p[1].png would be p1.png)
lacks "$(cover "$B/glob.cbz" | sixel_info | jget colours)" "17,15,13"

case_ "the pane: cover centred between the rule and the pane's end (where the title's rule ends), the words under it, inside the pane"
for size in "36 24" "36 26" "50 30" "21 9" "40 12"; do
  read -r cols lines <<<"$size"
  out=$(cover "$B/Reading Now.pdf" "$cols" "$lines"); info=$(sixel_info <<<"$out")
  w=$(jget width <<<"$info"); h=$(jget raster 3 <<<"$info"); bb=$(jget bbox <<<"$info")
  read -r x0 _ x1 _ < <(tr -d '[],' <<<"$bb")
  a=$(( 2 * 9 - (9 - 1) / 2 - 1 ))                       # the rule's right edge → the first column
  ((w <= cols * 9 - a)) && _ok || _no "$size: the picture ($w px) is wider than the pane"
  L=$(( a + x0 )) R=$(( cols * 9 - x1 ))
  (( L - R <= 1 && R - L <= 1 )) && _ok || _no "$size: the paper left ($L px) and right ($R px) of the cover"
  (( x1 <= cols * 9 - a )) && _ok || _no "$size: the cover passes the pane's edge"
  after=$(jrepr after <<<"$info")
  text=$(python3 -I -c 'import sys,ast; print(ast.literal_eval(sys.argv[1]))' "$after" | plain)
  rows=$(( (h + 20) / 21 + $(wc -l <<<"$text") - 1 ))
  ((rows <= lines)) && _ok || _no "$size: $rows rows in a pane of $lines"
  python3 -I -c 'import sys, unicodedata
for l in sys.stdin.read().splitlines():
    w = sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in l)
    if w > int(sys.argv[1]): sys.exit(1)' "$cols" <<<"$text" && _ok || _no "$size: a line of words wider than the pane"
done
case_ "a long Japanese title (the list cut it, so the caption names it): two lines at most, cut with …, inside the pane"
mk epub "$B/$(printf '長い題名%.0s' {1..12}).epub" meta
long=$(printf '長い題名%.0s' {1..12})
whole=$(kawa-books --rows | grep -F -- "$B/$long.epub"$'\t' | field 6)
eq "$whole" "$long" "the list cuts it: its whole title goes to the caption (field 6)"
text=$(FZF_PREVIEW_COLUMNS=36 FZF_PREVIEW_LINES=24 KAWA_CELL=9x21 kawa-books --preview "$B/$long.epub" "info one" "info two" "$whole" \
       | sixel_info | jrepr after | python3 -I -c 'import sys,ast; print(ast.literal_eval(sys.stdin.read()))' | plain)
eq "$(grep -c '長' <<<"$text")" 2; has "$text" "…"
case_ "a title the list shows whole: the caption does not repeat it"
text=$(cover "$B/Reading Now.pdf" | sixel_info | jrepr after | python3 -I -c 'import sys,ast; print(ast.literal_eval(sys.stdin.read()))' | plain)
lacks "$text" "Reading Now"; eq "$(kawa-books --rows | grep -F -- "$B/Reading Now.pdf"$'\t' | field 6)" ""
case_ "a pane too narrow or too short for a cover, or a book gone: nothing, quietly"
eq "$(cover "$B/Reading Now.pdf" 20 24 2>&1)" ""; eq "$(cover "$B/Reading Now.pdf" 36 8 2>&1)" ""
eq "$(cover "$B/nothing here.pdf" 2>&1)" ""; rc 0 cover "$B/nothing here.pdf"

case_ "covers are kept: a second look draws nothing"
setup; mk pdf "$B/One.pdf" 3
stub pdftoppm 'exec /usr/bin/pdftoppm "$@"'
c1=$(cover "$B/One.pdf"); c2=$(cover "$B/One.pdf")
eq "$(grep -c '^pdftoppm' "$CALLS")" 1; eq "$c1" "$c2"
case_ "a changed book, another window size, the other theme: drawn again"
mk pdf "$B/One.pdf" 3 7fb8b0; touch -d '+1 minute' "$B/One.pdf"
has "$(cover "$B/One.pdf" | sixel_info | jget colours)" "50,72,69" "the new teal first page"
eq "$(grep -c '^pdftoppm' "$CALLS")" 2
cover "$B/One.pdf" 40 24 >/dev/null; eq "$(grep -c '^pdftoppm' "$CALLS")" 3
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
info=$(cover "$B/One.pdf" | sixel_info); eq "$(grep -c '^pdftoppm' "$CALLS")" 4
lacks "$(jget colours <<<"$info")" "91,88,80" "the paper ground is not drawn"
case_ "old covers (90 days) are cleared when the window opens; recent ones kept"
ls "$K"/*.six >/dev/null 2>&1 && _ok || _no "no covers kept"
n=$(ls "$K"/*.six | wc -l)
old=$(ls "$K"/*.six | head -n1); touch -d '-100 days' "$old" "${old%.six}.lay"
month=$(ls "$K"/*.six | tail -n1); touch -d '-30 days' "$month" "${month%.six}.lay"
kawa-books --tui
eq "$(ls "$K"/*.six | wc -l)" $((n - 1))
[[ -e $month ]] && _ok || _no "a cover drawn a month ago was cleared"
case_ "a cover killed half-way (fzf kills a preview you moved on from): its half-made files cleared"
setup; mk pdf "$B/One.pdf" 3
stub magick 'sleep 30'
/usr/bin/setsid bash -c 'KAWA_CELL=9x21 FZF_PREVIEW_COLUMNS=36 FZF_PREVIEW_LINES=24 exec kawa-books --preview "$1" a b' _ "$B/One.pdf" >/dev/null 2>&1 & pg=$!
for _ in {1..80}; do (($(count "$K"/cover.*))) && break; sleep 0.05; done
sleep 0.3; kill -KILL -- -"$pg" 2>/dev/null; wait "$pg" 2>/dev/null
(($(count "$K"/cover.*))) && _ok || _no "(the test itself: no leftover to clean)"
touch -d '-2 minutes' "$K"/cover.*
kawa-books --tui
eq "$(ls -A "$K")" "pages.json" "nothing but the page counts left"

# ── read, remove, add ────────────────────────────────────────────────────────
case_ "enter: zathura opens the book (where it was, or on the page found by name)"
setup; library; reset_calls
rc 0 kawa-books --open "$B/Reading Now.pdf" ""
called "^setsid -f zathura -- $B/Reading Now.pdf\$"
rc 0 kawa-books --open "$B/Flow.epub" 37
called "^setsid -f zathura --page=37 -- $B/Flow.epub\$"
reset_calls; rc 0 kawa-books --open "$B/-dash first.pdf" "1;rm"
called "^setsid -f zathura -- $B/-dash first.pdf\$" "a page that is not a number is ignored"
case_ "enter on a book gone meanwhile: nothing"
reset_calls; rc 0 kawa-books --open "$B/gone away.pdf" ""; not_called zathura
case_ "zathura missing: a notice says so"
reset_calls; rc 1 env PATH="$(without zathura)" kawa-books --open "$B/Reading Now.pdf" ""
called 'notify-send -a desktop .*zathura'

case_ "ctrl+d: to the trash; a trash that refuses: a notice"
reset_calls; rc 0 kawa-books --remove "$B/it's \"quoted\" \$(id) \`id\`.pdf"
called "^gio trash -- $B/it's \"quoted\" \\\$\\(id\\) \`id\`\\.pdf\$" "the name reached gio as it is"
stub gio 'exit 1'
rc 0 kawa-books --remove "$B/Done Book.pdf"
called 'notify-send -a desktop books could not move Done Book.pdf to the trash'

case_ "ctrl+a: books in Downloads, Documents, Desktop listed; the marked ones moved in; a taken name gets (2)"
setup; mk pdf "$B/Taken.pdf" 1
mkdir -p "$HOME/Downloads/sub" "$HOME/Documents" "$HOME/Desktop"
mk pdf "$HOME/Downloads/Taken.pdf" 2; mk epub "$HOME/Downloads/sub/Deep.epub" meta
mk pdf "$HOME/Documents/a.b.c.pdf" 1; printf x >"$HOME/Desktop/not a book.txt"
if [[ -z $FD ]]; then skip "no fd here: Ctrl+A not tried"; else
stub fd "exec '$FD' \"\$@\""
printf '%s\n' "~/Downloads/Taken.pdf" "~/Downloads/sub/Deep.epub" >"$FZF_PICK"
kawa-books --add
offered=$(cut -f2 "$FZF_IN.add" | sort | tr '\n' '|')
eq "$offered" "~/Documents/a.b.c.pdf|~/Downloads/Taken.pdf|~/Downloads/sub/Deep.epub|"
[[ -f "$B/Taken (2).pdf" && -f $B/Deep.epub && -f $B/Taken.pdf && ! -e $HOME/Downloads/Taken.pdf ]] && _ok \
  || _no "moved wrong: $(ls "$B" | tr '\n' '|')"
[[ -f $HOME/Documents/a.b.c.pdf ]] && _ok || _no "an unmarked book was moved"
[[ -s $FZF_ARGS ]] && _ok || _no "the library did not come back"
case_ "ctrl+a, a third of the same name: (3); a name with dots keeps its extension"
mk pdf "$HOME/Downloads/Taken.pdf" 3; mk pdf "$B/a.b.c.pdf" 1
printf '%s\n' "~/Downloads/Taken.pdf" "~/Documents/a.b.c.pdf" >"$FZF_PICK"; kawa-books --add
[[ -f "$B/Taken (3).pdf" && -f "$B/a.b.c (2).pdf" ]] && _ok || _no "$(ls "$B" | tr '\n' '|')"
case_ "ctrl+a, Esc: nothing moved"
mk pdf "$HOME/Downloads/Keep.pdf" 1; : >"$FZF_PICK"; kawa-books --add
[[ -f $HOME/Downloads/Keep.pdf ]] && _ok || _no "moved on Esc"
fi

# ── the window ───────────────────────────────────────────────────────────────
case_ "Super+R: the floating window, once"
setup; reset_calls; kawa-books
called "^kawa-float --once books books 104x29 -- $REPO/bin/kawa-books --tui\$"
case_ "inside: the list, its count in the title, the keys"
library; kawa-books --tui
eq "$(cat "$FZF_IN")" "$(kawa-books --rows)"
has "$(cat "$FZF_ARGS")" "· ~/Books"; lacks "$(cat "$FZF_ARGS")" "10 in" "the count is fzf's, beside the search"
has "$(cat "$FZF_ARGS")" "--bind=enter:become($REPO/bin/kawa-books --open {1} {5})"
case_ "inside, no books yet: the title says how to add some"
setup; kawa-books --tui; has "$(cat "$FZF_ARGS")" "none in ~/Books yet — ctrl+a adds some"
case_ "a home with a space, an accent and a quote: the keys' commands still find the script and the book"
setup; odd_home kawa-books; B=$HOME/Books; mk pdf "$B/One.pdf" 3
"$HOME/.local/bin/kawa-books" --tui
pcmd=$(grep -F -- "--preview=" "$FZF_ARGS"); pcmd=${pcmd#--preview=}
q=$(printf '%q' "$B/One.pdf")
out=$(FZF_PREVIEW_COLUMNS=36 FZF_PREVIEW_LINES=24 KAWA_CELL=9x21 bash -c "${pcmd//\{1\}/$q} 2>&1")
[[ $out == *$'\e'P0\;1\;* ]] && _ok || _no "no cover: ${out:0:120}"
case_ "a held Super+R (20 presses): one window"
setup; stub kawa-float; rm -f "$STUBS/kawa-float"
stub footclient 'while [ "$1" != -- ]; do shift; done; shift; sleep 1; exec "$@"'
for _ in {1..20}; do kawa-books & done; wait
eq "$(grep -c '^footclient' "$CALLS")" 1; eq "$(grep -c '^fzf' "$CALLS")" 1

case_ "Turkish and Arabic locales: the same list, the card says MOBI (not MOBİ)"
setup; mk pdf "$B/One.pdf" 3; printf 'x' >"$B/Book.mobi"
want=$(kawa-books --rows)
for l in tr_TR ar_EG; do
  if locale_of $l; then L=$LOC
    eq "$(LC_ALL=$L kawa-books --rows)" "$want" "$l"
  else skip "no $l.UTF-8 locale"; fi
done
if locale_of tr_TR; then L=$LOC; export ANNOT=$TMP/annotate
  stub magick 'case "$*" in *-annotate*) printf "%s\n" "$*" >>"$ANNOT";; esac; exec '"$MAGICK"' "$@"'
  LC_ALL=$L cover "$B/Book.mobi" >/dev/null
  has "$(cat "$ANNOT" 2>/dev/null)" "-annotate +0+0 MOBI "
fi

case_ "misuse and help"
rc 2 kawa-books --bogus; rc 2 kawa-books list
rc 0 kawa-books --help; has "$(kawa-books --help)" "Super+R"

done_
