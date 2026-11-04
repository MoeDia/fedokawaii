#!/usr/bin/env bash
# tests/yazi/test_yazi.sh — the desktop's yazi, driven key by key in a pseudo-terminal: the
# real yazi (26.9.1, as lib/upstream.sh pins it) with the desktop's keymap.toml, init.lua,
# theme.toml and plugins. Enter (smart-enter.yazi): a folder is entered, a file opens with
# yazi's opener (the editor, xdg-open), a Xournal++ note in Xournal++ — the selection first,
# wherever the cursor is. M (drives.yazi): the drives as kawa-drives lists them — Enter opens
# one and goes there, e ejects, the list starts at the top (or on the drive you stand in) ·
# g d: ~/Drives, the open drives. kawa-drives, setsid, xdg-open, xournalpp and the editor are
# stand-ins; `file` is the real one. Skipped (not failed) where yazi is not installed.
. "$(dirname "$0")/../lib/harness.sh"
D=$(cd "$(dirname "$0")" && pwd)
YAZI=$(command -v yazi 2>/dev/null || { [[ -x $HOME/.local/bin/yazi ]] && echo "$HOME/.local/bin/yazi"; })
if [[ -z $YAZI ]]; then
  printf '  – skipped: yazi is not installed (it is the one lib/upstream.sh puts in ~/.local/bin)\n'
  done_; exit
fi
command -v file >/dev/null || { printf '  – skipped: file is not installed (yazi types files with it)\n'; done_; exit; }

# a session that went wrong (a step that timed out) is a failure of the case it belongs to —
# also when it ran inside $( ), whose counts would be lost: kept in $SF until the next case
SF=$(mktemp "${TMPDIR:-/tmp}/kawa-yazi-sessions.XXXXXX")
flush() { local l; while IFS= read -r l; do _no "$l"; done <"$SF"; : >"$SF"; }
# shellcheck disable=SC2034  # (H_CASE: the harness's name for the case, read by its _no)
case_() { H_CASE=$1; flush; }

setup() {   # setup — a home with the desktop's yazi config, a folder of files, two drives
  flush
  sandbox
  config .config/yazi
  W=$HOME/work KD=$TMP/kd MNT=$TMP/media
  # (yazi lists folders first, then files, by name: 0 empty · 1 notes.xopp · 2 sub dir ·
  #  3 a.txt · 4 b.txt · 5 LOUD.XOPP · 6 my note's (1).xopp · 7 p.png)
  mkdir -p "$W/sub dir" "$W/empty" "$W/notes.xopp" "$KD" "$MNT/KINGSTON/photos" "$MNT/WD"
  echo hello >"$W/a.txt"; echo world >"$W/b.txt"
  printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR\0\0\0\1\0\0\0\1\x08\x02\0\0\0\x90wS\xde' >"$W/p.png"
  # a Xournal++ note is gzip inside, as `file` says (yazi alone would offer to unpack it)
  python3 -c 'import gzip,sys; gzip.open(sys.argv[1],"wb").write(b"<xournal/>")' "$W/my note's (1).xopp"
  cp "$W/my note's (1).xopp" "$W/LOUD.XOPP"
  printf '/dev/sdb1\t/dev/sdb\tKINGSTON\t28.9G\tvfat\t%s\n/dev/sdc2\t/dev/sdc\tWD Elements\t431.5G\tntfs\t\n' \
    "$MNT/KINGSTON" >"$KD/list"
  export KD TMP
  # kawa-drives: list from $KD/list; open prints $KD/open (none: fails, as when it says why)
  stub kawa-drives 'case $1 in
  list) cat "$KD/list" 2>/dev/null ;;
  open) [ -s "$KD/open" ] || exit 1; cat "$KD/open" ;;
esac'
  # the others leave a mark when called, so a step can wait for it ($TMP/hit.NAME)
  for s in setsid xdg-open xournalpp editor; do stub "$s" ': >"$TMP/hit.'"$s"'"'; done
  export EDITOR=$STUBS/editor
}
y() {   # y [SIZE] — yazi in $W (or $CWD), driven by the steps on stdin; its last folder in $TMP/cwd
  rm -f "$TMP/cwd" "$TMP"/hit.*
  python3 "$D/drive.py" --size "${1:-100x30}" --cwd "${CWD:-$W}" -- "$YAZI" --cwd-file="$TMP/cwd" 2>"$TMP/drive.err"
  local r=$?
  if ((r != 0)); then
    cat "$TMP/drive.err" >&2
    if ((BASH_SUBSHELL)); then echo "the session: $(head -n 1 "$TMP/drive.err")" >>"$SF"
    else _no "the session: $(head -n 1 "$TMP/drive.err")"; fi
  fi
  return $r
}
last_dir() { cat "$TMP/cwd" 2>/dev/null; }
listed() { (cd "$W" && ls -A | tr '\n' '|'); }

# ── the frame ────────────────────────────────────────────────────────────────────────────
setup
out=$(y <<'EOF'
wait a.txt
settle
screen
quit
EOF
)
case_ "yazi starts with the desktop's config: no error, no warning"
has "$out" "a.txt"
lacks "$out" "rror"; lacks "$out" "arning"; lacks "$out" "eprecated"
case_ "init.lua's frame (§7's grid): the heading at column 0 (two free columns: the margin, the cursor's) — the folder icon, the path, the rule — a blank row under it; rows' icons at column 1; the footer's facts from column 0, no mode's word in the usual mode, the place in the list at its right end"
head1=$(sed -n 1p <<<"$out"); row3=$(sed -n 3p <<<"$out"); tail1=$(sed -n 30p <<<"$out")
# shellcheck disable=SC2088  # (the ~ yazi shows, not one to expand)
has "$head1" "  $(printf "\363\276\200\261")  ~/work ─" "the heading: two columns in, the icon, two columns, the path, the rule"
eq "$(sed -n 2p <<<"$out" | tr -d ' ')" "" "(the blank row under the heading)"
eq "${row3:0:3}" "   " "(the rows: the margin, the cursor's column, column 0 — the icon at column 1)"
eq "${tail1:0:2}" "  " "the footer, at column 0"; lacks "$tail1" "NOR"; [[ $tail1 == *" 1/8" ]] && _ok || _no "the footer's end: $tail1"
eq "$(python3 -I -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import drive
print(sum(drive.width(c) for c in sys.stdin.read().rstrip("\n")))' "$D" <<<"$tail1")" 98 "(the place in the list two columns short of the edge, as the heading's rule)"

# ── Enter: smart-enter.yazi ──────────────────────────────────────────────────────────────
case_ "Enter on a folder goes into it (yazi's own Enter would open it in the editor)"
y <<'EOF'
wait a.txt
settle
key <Enter>
wait 0/0
quit
EOF
eq "$(last_dir)" "$W/empty"; not_called '^editor'

case_ "Enter on a text file opens it in the editor (the edit opener, \$EDITOR)"
reset_calls
y <<'EOF'
wait a.txt
settle
key jjj
settle
key <Enter>
waitfile $TMP/hit.editor
settle
quit
EOF
called "^editor $W/a.txt$"
eq "$(last_dir)" "$W" "it stays in the folder"

case_ "Enter with files selected opens the selected ones, all at once (whatever the cursor is on)"
reset_calls
y <<'EOF'
wait a.txt
settle
key jjj
settle
key <Space>
key <Space>
settle
key <Enter>
waitfile $TMP/hit.editor
settle
quit
EOF
called "^editor $W/a.txt $W/b.txt$"
not_called '^xournalpp' "the cursor's note is not what Enter opens while files are selected"

case_ "selected notes open in Xournal++, each one; the other selected files as yazi opens them"
reset_calls
y <<'EOF'
wait a.txt
settle
key jjj
settle
key <Space>
key j
settle
key <Space>
key <Space>
settle
key gg
settle
key jjjj
settle
key <Enter>
waitfile $TMP/hit.editor
waitfile $TMP/hit.xournalpp
settle
quit
EOF
called "^xournalpp $W/LOUD.XOPP$"; called "^xournalpp $W/my note's \(1\)\.xopp$"
called "^editor $W/a.txt$"; not_called "^editor .*xopp"; not_called '^xdg-open'
eq "$(listed)" "LOUD.XOPP|a.txt|b.txt|empty|my note's (1).xopp|notes.xopp|p.png|sub dir|" \
   "nothing unpacked beside the notes (yazi's own rule for gzip)"

case_ "a selected folder named like a note is not handed to Xournal++"
reset_calls
y <<'EOF'
wait a.txt
settle
key j
settle
key <Space>
settle
key jjjj
settle
key <Space>
settle
key k
settle
key <Enter>
waitfile $TMP/hit.xournalpp
settle
quit
EOF
called "^xournalpp $W/my note's \(1\)\.xopp$"; not_called "^xournalpp $W/notes.xopp"

case_ "Enter on a picture hands it to xdg-open (the default program for it)"
reset_calls
y <<'EOF'
wait p.png
settle
key G
settle
key <Enter>
waitfile $TMP/hit.xdg-open
quit
EOF
called "^xdg-open $W/p.png$"; not_called '^editor'

case_ "Enter on a Xournal++ note opens Xournal++ — a name with a space, a quote and brackets intact"
reset_calls
y <<'EOF'
wait a.txt
settle
key jjjjjj
settle
key <Enter>
waitfile $TMP/hit.xournalpp
settle
quit
EOF
called "^xournalpp $W/my note's \(1\)\.xopp$"
not_called '^xdg-open'; not_called '^editor'
eq "$(listed)" "LOUD.XOPP|a.txt|b.txt|empty|my note's (1).xopp|notes.xopp|p.png|sub dir|" "nothing unpacked"

case_ "… LOUD.XOPP too (the name's case does not matter)"
reset_calls
y <<'EOF'
wait a.txt
settle
key jjjjj
settle
key <Enter>
waitfile $TMP/hit.xournalpp
quit
EOF
called "^xournalpp $W/LOUD.XOPP$"

case_ "… but a folder named notes.xopp is a folder: Enter goes in"
reset_calls
y <<'EOF'
wait a.txt
settle
key j
settle
key <Enter>
wait 0/0
quit
EOF
eq "$(last_dir)" "$W/notes.xopp"; not_called '^xournalpp'

case_ "what is not there yet, said quietly where a row's name stands (§1 faint, never centred, no \"…\"): an empty folder says \"empty\" in its list and in its preview — yazi's centred \"No items\" gone"
setup
out=$(y 100x8 <<'EOF'
wait a.txt
settle
screen
key l
wait 0/0
settle
screen
quit
EOF
)
eq "$(grep -c '│      empty' <<<"$out")" 2 "(the word at the names' column: in the empty folder's preview, then in its own list)"
lacks "$out" "No items"; lacks "$out" "Loading..."
case_ "two tabs (t t): §7's tab grammar under the heading — each the folder icon, two columns, its folder's name; ▔ under the shown one's name alone; a row of paper; a long name cut, no \"…\""
setup
L="$W/a-folder-whose-name-is-much-too-long-for-its-share-of-a-narrow-window-and-more"; mkdir -p "$L"
out=$(y 60x10 <<'EOF'
wait a-folder
settle
key t
key t
settle
key l
wait 0/0
settle
screen
quit
EOF
)
rm -rf "$L"
row3=$(sed -n 3p <<<"$out"); row4=$(sed -n 4p <<<"$out")
has "$row3" "  $(printf "\363\276\200\261")  work   $(printf "\363\276\200\261")  a-folder-whose" "(two tabs, at the heading's column; the second in the long folder)"
lacks "$out" "…"
eq "$(python3 -I -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import drive
r3, r4 = sys.stdin.read().split("\n")[:2]
name = r3.split("work   ", 1)[1][3:].rstrip()
lo = r4.index("▔"); hi = r4.rindex("▔") + 1
print(len(name) == hi - lo and r4[lo:hi] == "▔" * len(name) and sum(drive.width(c) for c in r3.rstrip()) <= 56)' "$D" <<<"$row3
$row4")" True "(▔ under the shown name alone, as long as it; the row within the window's 60 less its two-column margins)"
eq "$(sed -n 5p <<<"$out" | tr -d ' ')" "" "(a row of paper under the tabs)"
case_ "Enter in an empty folder does nothing at all"
reset_calls
CWD=$W/empty y <<'EOF'
wait 0/0
settle
key <Enter>
sleep 0.3
quit
EOF
eq "$(last_dir)" "$W/empty"; not_called '^(editor|xdg-open|xournalpp)'

# a table opens in VisiData, in yazi's own window (block: the terminal is handed over, as to
# the editor); yazi's own rules would send it to the editor (text/csv is text/*). The two
# tables sort after p.png (8 and 9), so the keys above still land where they did.
printf 'city,day\nSharjah,Mon\n' >"$W/trip to Japan.csv"; printf 'city\tday\nDubai\tTue\n' >"$W/weather.tsv"
stub vd '[ -t 0 ] && : >"$TMP/vd.tty"; : >"$TMP/hit.vd"'
case_ "Enter on a .csv opens it in VisiData, in this window (a name with spaces intact); not the editor"
reset_calls
y <<'EOF'
wait a.txt
settle
key jjjjjjjj
settle
key <Enter>
waitfile $TMP/hit.vd
settle
quit
EOF
called "^vd -- $W/trip to Japan\.csv$"; not_called '^editor'; not_called '^xdg-open'
[[ -e $TMP/vd.tty ]] && _ok || _no "vd did not get the terminal (not a blocking shell)"
eq "$(last_dir)" "$W" "it stays in the folder"
case_ "a .csv and a .tsv selected: one VisiData with both; a selected text file still goes to the editor"
reset_calls
y <<'EOF'
wait a.txt
settle
key jjj
settle
key <Space>
key jjjj
settle
key <Space>
key <Space>
settle
key <Enter>
waitfile $TMP/hit.vd
waitfile $TMP/hit.editor
settle
quit
EOF
called "^vd -- $W/trip to Japan\.csv $W/weather\.tsv$"; called "^editor $W/a.txt$"; not_called "^editor .*sv$"

# ── M: the drives ────────────────────────────────────────────────────────────────────────
setup
out=$(y <<'EOF'
wait a.txt
settle
key M
wait  eject
settle
screen
lit
key j
settle
lit
key j
settle
lit
key k
settle
lit
key <Down>
settle
key <Up>
settle
key <Up>
settle
lit
key <Esc>
gone  eject
key M
wait  eject
settle
key q
gone  eject
key M
wait  eject
settle
key M
gone  eject
quit
EOF
)
case_ "M lists the drives: label, size, file system, open or closed — and the keys"
has "$out" "drives"
has "$out" "KINGSTON                           28.9G  vfat   open"
has "$out" "WD Elements                       431.5G  ntfs   closed"
has "$out" ' eject'; lacks "$out" "esc close" "its own key alone (§7)"
called '^kawa-drives list$'
case_ "the list starts on the first drive; j and k (↓ ↑) move, and not past either end"
lit() { sed -n "$((30 * $1 + 31)),$((30 * $1 + 60))p" <<<"$out" | grep -oE 'KINGSTON|WD Elements'; }
eq "$(lit 0)" "KINGSTON"; eq "$(lit 1)" "WD Elements"; eq "$(lit 2)" "WD Elements" "j at the end"
eq "$(lit 3)" "KINGSTON"; eq "$(lit 4)" "KINGSTON" "↑ at the top"
case_ "Esc, q and M each close the list (the session ran through all three)"
# (each open lists the drives; any mount change on the machine meanwhile lists them once more — yazi's
# "mount" event, the plugin's refresh: seen in a suite run beside other work, 2 Nov — so at least three)
n=$(grep -c '^kawa-drives list' "$CALLS"); ((n >= 3)) && _ok || _no "three times opened, listed only $n times"

case_ "Enter on a closed drive opens it (kawa-drives open) and goes there"
reset_calls; echo "$MNT/WD" >"$KD/open"
y <<'EOF'
wait a.txt
settle
key M
wait  eject
settle
key j
settle
key <Enter>
gone  eject
settle
quit
EOF
called '^kawa-drives open /dev/sdc2$'; eq "$(last_dir)" "$MNT/WD"
case_ "… and l and → do the same"
for k in l '<Right>'; do
  reset_calls
  y <<EOF
wait a.txt
settle
key M
wait  eject
settle
key $k
gone  eject
settle
quit
EOF
  called '^kawa-drives open /dev/sdb1$'; eq "$(last_dir)" "$MNT/WD"
done

case_ "a drive that will not open: the list stays (read again), yazi stays where it was"
reset_calls; rm -f "$KD/open"
out=$(y <<'EOF'
wait a.txt
settle
key M
wait  eject
settle
key <Enter>
sleep 0.4
settle
screen
key <Esc>
gone  eject
quit
EOF
)
called '^kawa-drives open /dev/sdb1$'; has "$out" ' eject'
eq "$(grep -c '^kawa-drives list' "$CALLS")" 2 "listed again after the failure"
eq "$(last_dir)" "$W"

case_ "e ejects the hovered drive in the background (setsid), and the list closes"
reset_calls
y <<'EOF'
wait a.txt
settle
key M
wait  eject
settle
key j
settle
key e
gone  eject
waitfile $TMP/hit.setsid
quit
EOF
called '^setsid -f kawa-drives eject /dev/sdc2$'; eq "$(last_dir)" "$W" "standing elsewhere: no step out"

case_ "standing in a drive: the list opens on it, and e steps out to the home first"
reset_calls
printf '/dev/sdc2\t/dev/sdc\tWD Elements\t431.5G\tntfs\t\n/dev/sdb1\t/dev/sdb\tKINGSTON\t28.9G\tvfat\t%s\n' \
  "$MNT/KINGSTON" >"$KD/list"
out=$(CWD=$MNT/KINGSTON/photos y <<'EOF'
wait 0/0
settle
key M
wait  eject
settle
lit
key e
gone  eject
waitfile $TMP/hit.setsid
settle
quit
EOF
)
has "$out" "KINGSTON"; lacks "$out" "WD Elements"
called '^setsid -f kawa-drives eject /dev/sdb1$'
eq "$(last_dir)" "$HOME" "yazi stood in the drive: it left it before the eject"

case_ "each M starts from the top again, not where the last one was left"
setup; reset_calls; echo "$MNT/KINGSTON" >"$KD/open"
y <<'EOF'
wait a.txt
settle
key M
wait  eject
settle
key j
settle
key <Esc>
gone  eject
key M
wait  eject
settle
key <Enter>
gone  eject
settle
quit
EOF
called '^kawa-drives open /dev/sdb1$'; not_called 'open /dev/sdc2'

drives_screen() {   # drives_screen [SIZE] [KEYS…] — the screen with M open (after KEYS)
  local size=${1:-100x30} k steps=$'wait a.txt\nsettle\nkey M\nwait eject\nsettle'
  shift
  for k; do steps+=$'\n'"key $k"$'\nsettle'; done
  y "$size" <<<"$steps"$'\nscreen\nkey <Esc>\ngone eject\nquit'
}
case_ "nothing plugged in: the list says so (and Enter, e do nothing)"
setup; : >"$KD/list"; reset_calls
out=$(drives_screen 100x30 '<Enter>' e)
has "$out" "nothing plugged in"; not_called 'kawa-drives open'; not_called '^setsid'
case_ "kawa-drives failing or saying nonsense: an empty list, yazi carries on"
stub kawa-drives 'echo "garbage without tabs"; echo "a	b"; exit 1'
out=$(drives_screen); has "$out" "nothing plugged in"; lacks "$out" "garbage"

case_ "odd labels: shown as they are, never run; a long one is cut to fit the frame"
setup
long="Photos from the long trip to the coast in summer twenty twenty-six"
odd='$(touch ~/pwned) "q" `id`'
printf '/dev/sdb1\t/dev/sdb\t%s\t1.9T\texfat\t\n/dev/sdc1\t/dev/sdc\t写真とビデオのバックアップ・ディスク二〇二六年夏\t64G\tvfat\t\n/dev/sdd1\t/dev/sdd\t%s\t8G\tvfat\t\n' \
  "$long" "$odd" >"$KD/list"
echo "$MNT/WD" >"$KD/open"
out=$(y <<'EOF'
wait a.txt
settle
key M
wait  eject
settle
screen
key j
settle
key j
settle
key <Enter>
gone  eject
quit
EOF
)
has "$out" "Photos from the long trip to"; lacks "$out" "coast"; lacks "$out" "…" "a long label cut, nothing in its place (master T22/1)"
has "$out" "写真とビデオのバックアップ"; lacks "$out" "二〇二六年夏" "the long Japanese label is cut too"
has "$out" "$odd"
called '^kawa-drives open /dev/sdd1$' "opening passes the drive's device, never its label"
[[ ! -e $HOME/pwned ]] && _ok || _no "a label ran as a command"
# every row of the frame ends in its border at the same column (wide characters counted right)
python3 - "$out" <<'EOF' && _ok || _no "the frame's right border is not straight"
import sys, unicodedata
BAR = "│\U000FF006\U000FF007"                          # (a rail, or the frame's sides: the patched yazi's ring of cells)
rows = [r for r in sys.argv[1].split("\n") if sum(r.count(b) for b in BAR) >= 2 and any(w in r for w in ("1.9T", "64G", "8G", " eject"))]
def last_bar(r):
    w, at = 0, None
    for ch in r:
        if ch in BAR: at = w
        w += 2 if unicodedata.east_asian_width(ch) in "WF" else 1
    return at
sys.exit(0 if len(rows) == 4 and len({last_bar(r) for r in rows}) == 1 else 1)
EOF
case_ "a narrow window (50 columns): the list fits, cut to the window"
out=$(drives_screen 50x20)
has "$out" ' eject'; has "$out" "exfat"

# ── g d ──────────────────────────────────────────────────────────────────────────────────
case_ "g d goes to ~/Drives, where each open drive is a folder by its name (kawa-drives keeps it)"
setup; reset_calls
mkdir -p "$HOME/Drives"; ln -s "$MNT" "$HOME/Drives/KINGSTON 29G"
y <<'EOF'
wait a.txt
settle
key gd
wait KINGSTON
settle
quit
EOF
eq "$(last_dir)" "$HOME/Drives"

# ── the keys' names in yazi's own help ───────────────────────────────────────────────────
case_ "~ lists the desktop's keys with their words"
out=$(y 120x40 <<'EOF'
wait a.txt
settle
key ~
wait into the folder
settle
screen
key <Esc>
key <Esc>
gone into the folder
quit
EOF
)
has "$out" "into the folder, or open the file(s)"; has "$out" "drives: open or eject one"
has "$out" "go to your drives (~/Drives: one per open drive)"

# ── a film: W watches it together ──────────────────────────────────────────────────────
case_ "W on a film: Syncplay in a terminal window of its own (kawa-term kawa-together FILE)"
setup; reset_calls
stub kawa-term ': >"$TMP/hit.kawa-term"'
mkdir -p "$TMP/films"; cp "$W/p.png" "$TMP/films/our film's night.mkv"   # (any file: W does not ask its type)
CWD=$TMP/films y <<'EOF'
wait night.mkv
settle
key W
waitfile $TMP/hit.kawa-term
settle
quit
EOF
called "^kawa-term kawa-together $TMP/films/our film's night\.mkv$"; not_called '^xdg-open'
eq "$(last_dir)" "$TMP/films" "yazi stays"
case_ "~ lists W with its words"
out=$(CWD=$TMP/films y 120x40 <<'EOF'
wait night.mkv
settle
key ~
wait watch it together
settle
screen
key <Esc>
key <Esc>
gone watch it together
quit
EOF
)
has "$out" "watch it together (Syncplay)"
# ── the file dialog (kawa-pick): its own yazi, Enter and Esc, its title ─────────────────
# (the dialog's yazi as kawa-pick runs it inside its window; the answer lands in $TMP/pk)
pick() {   # pick MODE DIR [SIZE] — driven by the steps on stdin
  rm -rf "$TMP/pk"; mkdir -p "$TMP/pk"
  python3 "$D/drive.py" --size "${3:-100x31}" --cwd "$2" -- kawa-pick --inside "$1" "$2" "$TMP/pk" 2>"$TMP/drive.err" \
    || { cat "$TMP/drive.err" >&2; echo "the session: $(head -n 1 "$TMP/drive.err")" >>"$SF"; }
}
answer() { tr '\n' '|' 2>/dev/null <"$TMP/pk/answer"; }
setup; config .config/fedokawaii/yazi-pick; ln -sf "$YAZI" "$STUBS/yazi"
case_ "the dialog: Enter on a folder goes into it, Enter on a file takes it"
pick open1 "$W" <<'EOF'
wait a.txt
settle
key jj
settle
key <Enter>
wait 0/0
settle
key h
wait a.txt
settle
key j
settle
key <Enter>
waitfile $TMP/pk/answer
EOF
eq "$(answer)" "$W/a.txt|"
case_ "the dialog's Esc: first the marks go (it stays open), then it cancels"
out=$(pick openN "$W" <<'EOF'
wait a.txt
settle
key jjj
settle
key <Space>
key <Space>
settle
key <Esc>
settle
screen
key <Esc>
sleep 1
EOF
)
has "$out" "space  mark" "(open after the first Esc)"; lacks "$out" "esc cancel" "its own keys alone (§7)"; eq "$(answer)" "" "cancelled: no answer"
case_ "a long folder in the dialog's title (§7's heading: icon, name, the folder muted, the stitch): its start cut, no ellipsis, the stitch to the edge"
L="$W/とても長い日本語のフォルダの名前がここにありますとても長い日本語のフォルダの名前/مجلد"
mkdir -p "$L"; echo x >"$L/x.txt"
out=$(pick open1 "$L" <<'EOF'
wait x.txt
settle
screen
key <Esc>
sleep 1
EOF
)
head1=$(sed -n 1p <<<"$out")
has "$head1" "$(printf "\363\276\200\261")  open file  " "the icon, two columns, the name (§7)"; lacks "$head1" "…"; has "$head1" "/مجلد ─"
eq "$(python3 -I -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import drive
print(sum(drive.width(c) for c in sys.stdin.read().rstrip("\n")))' "$D" <<<"$head1")" 98 "(the title rule: two columns short of the window's edge, as it begins)"

# ── the panes by the window's size (init.lua): every tile of a 1080-p screen ─────────────
# panes — what a screen shows of the layout: the columns of the rails (│) on its third row,
# and "stitch A-B" when a row of ─ (the stacked layout's rule, solid) runs from column A to B
panes() { python3 -I -c '
import sys
rows = sys.stdin.read().split("\n")
rails = [str(i) for i, c in enumerate(rows[2]) if c == "│"] if len(rows) > 2 else []
st = [r for r in rows if r.strip() and set(r.strip()) == {"─"}]
out = " ".join(rails)
if st: out += (" " if out else "") + "stitch %d-%d" % (len(st[0]) - len(st[0].lstrip()), len(st[0].rstrip()) - 1)
print(out or "none")'; }
setup
for e in "156x40:20 77" "95x40:20 58" "77x40:20 47" "58x40:stitch 1-56" "37x40:stitch 1-35" "58x24:28" "58x14:28" "34x14:none" "20x8:none"; do
  s=${e%%:*} want=${e#*:}
  case_ "yazi at ${s}: $(case $want in *stitch*) echo "the list above the preview, the stitch between them (one free column each end)" ;; none) echo "the list alone" ;;
    *\ *) echo "parent, list and preview" ;; *) echo "the list and the preview side by side" ;; esac)"
  out=$(y "$s" <<'EOF'
wait a.txt
settle
screen
quit
EOF
)
  eq "$(panes <<<"$out")" "$want" "$out"
done
case_ "yazi's footer in a narrow window: one line, what does not fit gone (the permissions, then the size), the place in the list kept"
out=$(y 24x14 <<'EOF'
wait a.txt
settle
screen
quit
EOF
)
st=$(sed -n 14p <<<"$out")
lacks "$st" "rw"; has "$st" "/8"
eq "$(python3 -I -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import drive
print(sum(drive.width(c) for c in sys.stdin.read().rstrip("\n")) <= 24)' "$D" <<<"$st")" True "$st"
case_ "yazi follows its window as it is resized (a window opened or closed beside it): the panes chosen again each time"
out=$(y 156x40 <<'EOF'
wait a.txt
settle
resize 58x40
settle
screen
resize 34x14
settle
screen
resize 156x40
settle
screen
quit
EOF
)
eq "$(panes <<<"$(sed -n 1,40p <<<"$out")")" "stitch 1-56"
eq "$(panes <<<"$(sed -n 41,54p <<<"$out")")" "none"
eq "$(panes <<<"$(sed -n 55,94p <<<"$out")")" "20 77"
case_ "a ratio of your own (yazi.toml's [mgr] ratio) is kept at every width"
printf '[mgr]\nratio = [1, 2, 2]\n' >"$HOME/.config/yazi/yazi.toml"
out=$(y 58x40 <<'EOF'
wait a.txt
settle
screen
quit
EOF
)
eq "$(panes <<<"$out")" "12 34" "(as yazi lays 1:2:2 out)"
rm -f "$HOME/.config/yazi/yazi.toml"

case_ "hidden files shown, dotfiles too (the desktop's yazi.toml; the file dialog links the same file)"
cp "$REPO/configs/home/.config/yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"; : >"$W/.hidden-note"
out=$(y <<'EOF'
wait .hidden-note
screen
quit
EOF
)
has "$out" ".hidden-note"
rm -f "$W/.hidden-note"

# ── a RAR (bug 11, the master's T22 review 1): Fedora's 7-Zip has no RAR ────────────────────
case_ "a .rar: its entries in the preview (unrar's list, at the names' column), never 7-Zip's error; Enter opens File tools on it"
if command -v unrar >/dev/null; then
  setup
  R=$HOME/comics; mkdir -p "$R"
  python3 -I -B "$REPO/tests/lib/rar4.py" "$R/comic.rar" "page-01.txt=first page" "page-02.txt=second page" "notes.md=# hi"
  echo x >"$R/z.txt"
  stub kawa-file ': >"$TMP/hit.kawa-file"'
  out=$(CWD=$R y <<'EOF'
wait comic.rar
settle
screen
key <Enter>
waitfile $TMP/hit.kawa-file
quit
EOF
)
  has "$out" "page-01.txt"; has "$out" "notes.md"
  lacks "$out" "7-zip"; lacks "$out" "Cannot open"
  called "^kawa-file $R/comic\.rar$" "Enter: File tools on the archive"
  not_called '^7z'
else echo "  (no unrar here: the RAR case skipped)"; fi

# ── the desktop's yazi: the list's columns, the breadcrumb, the cards, the pop-ups ─────────
setup
# (zz.bin: the same bytes each run: urandom can look like something to file(1))
touch -d "3 days ago" "$W/a.txt"; touch -d "5 hours ago" "$W/b.txt"; : >"$W/nothing.bin"; python3 -Ic 'import random, sys; open(sys.argv[1], "wb").write(random.Random(7).randbytes(3000))' "$W/zz.bin"; echo x >"$W/.hidden"; echo x >"$W/sub dir/inner.txt"
mkdir -p "$W/deep/er"
out=$(CWD=$W/deep/er y 120x30 <<'EOF'
wait empty
settle
screen
quit
EOF
)
case_ "the heading a breadcrumb: the folders above, the one you are in — nothing cut, no \"…\"; an empty folder says so"
# shellcheck disable=SC2088  # (the ~ yazi shows)
has "$out" "~/work/deep/er ─" "the whole path, then the rule"
out=$(y 180x30 <<'EOF'
wait a.txt
settle
screen
quit
EOF
)
case_ "the list's columns: a file's size and age, right-aligned, their units after them"
has "$(grep -F a.txt <<<"$out" | head -n1)" "6 B     3 d" "a.txt's size and age"
has "$(grep -F b.txt <<<"$out" | head -n1)" "6 B     5 h" "b.txt's size and age"
out=$(y 160x30 <<'EOF'
wait a.txt
settle
key G
settle
screen
quit
EOF
)
case_ "what has no picture: a card of its facts — its name, what it is, its size, when it changed, its rights"
has "$out" "rights" "the card's last fact"; has "$out" "what     data" "the card's first"; lacks "$out" "File Type Classification" "yazi's own words gone"
out=$(y 120x30 <<'EOF'
wait a.txt
settle
key <Down><Down><Down>
wait inner.txt
screen
quit
EOF
)
case_ "a folder's preview: its rows (the override of yazi's folder recursed and the pane stood empty: never again)"
has "$out" "inner.txt" "sub dir's file in the preview"

# Tab's pop-up: the card's facts in the pop-ups' frame (kawa-card's spot), never yazi's table of its own plugins
if "$YAZI" --version 2>/dev/null | grep -q 'Patch  : fedokawaii'; then   # (the ring's cells, the band's edge: the patched build's)
out=$(y 120x30 <<'EOF'
wait a.txt
settle
key <Tab>
wait owner
settle
screen
key j
wait ▎ size
screen
key <Tab>
settle
quit
EOF
)
case_ "Tab on a folder: a card in the pop-ups' frame — the ring, the name's heading, its facts, none of yazi's plugin rows"
has "$out" $'\U000FF003' "the ring's corner cell"; has "$out" "what     folder" "says folder, not folder/local"
for w in size changed created rights owner; do has "$out" "$w" "the fact: $w"; done
for w in Plugins Previewer Spotter Mimetype Base; do lacks "$out" "$w" "yazi's own rows gone: $w"; done
lacks "$out" "…" "nothing cut with an ellipsis"
case_ "the band starts on the first fact, j moves it down (the row's 2 px edge, §1)"
has "$(grep -F 'what     folder' <<<"$out" | head -n1)" "▎" "the first drawing: on what"
has "$(grep -E ' size  ' <<<"$out" | tail -n1)" "▎" "after j: on size"
case_ "the frame's two sides stand in one column on every row of the card"
python3 - "$out" <<'PY' && _ok || _no "a row of the card is wider than its ring"
import sys, unicodedata
L, R = "\U000FF006", "\U000FF007"
def col(r, ch):
    w = 0
    for c in r:
        if c == ch: return w
        w += 2 if unicodedata.east_asian_width(c) in "WF" else 1
    return None
rows = [r for r in sys.argv[1].split("\n") if L in r and R in r]
sys.exit(0 if len(rows) >= 7 and len({col(r, L) for r in rows}) == 1 and len({col(r, R) for r in rows}) == 1 else 1)
PY
out=$(y 120x30 <<'EOF'
wait a.txt
settle
key G
settle
key <Tab>
wait owner
settle
screen
key <Tab>
settle
quit
EOF
)
case_ "Tab on a file: its name in the heading, what file(1) says, its size in the list's words"
has "$out" "zz.bin ─" "the heading: the name, the rule"; has "$out" "what     data" "what it is"; has "$out" "2.9 KB" "its size, with its unit apart"
printf '#!/bin/sh\ncat >"%s/copied"\n' "$TMP" >"$STUBS/wl-copy"; chmod +x "$STUBS/wl-copy"
export COPIED=$TMP/copied
out=$(y 120x30 <<'EOF'
wait a.txt
settle
key G
settle
key <Tab>
wait owner
settle
key j
wait ▎ size
key cc
waitfile $COPIED
key <Tab>
settle
quit
EOF
)
rm -f "$STUBS/wl-copy"
case_ "c c on the card: the value the band is on, on the clipboard"
eq "$(cat "$TMP/copied" 2>/dev/null)" "2.9 KB" "the size's words"
out=$(y 120x30 <<'EOF'
wait a.txt
settle
key <Space>
settle
key <Space>
settle
key <Tab>
wait 2 marked ─
settle
screen
key <Tab>
settle
quit
EOF
)
case_ "Tab with marks: how many, of what, their size together"
has "$out" "2 marked ─" "the heading"; has "$out" "2 folders" "what they are"; lacks "$out" "Count:" "yazi's own rows gone"
out=$(y 50x25 <<'EOF'
wait a.txt
settle
key <Tab>
wait owner
settle
screen
key <Tab>
settle
quit
EOF
)
case_ "a window narrower than the card narrows it: the ring stays whole"
has "$out" $'\U000FF003' "its left corner"; has "$out" $'\U000FF005' "its right corner"; has "$out" "owner" "its last fact"
ln -s a.txt "$W/zzz-link"
out=$(y 120x30 <<'EOF'
wait a.txt
settle
key G
settle
screen
key <Tab>
wait owner
settle
screen
key <Tab>
settle
quit
EOF
)
rm -f "$W/zzz-link"
case_ "Tab on a link: where it points, under what it is; the list says it after an arrow"
has "$out" "points to" "the row"; has "$(grep -F 'points to' <<<"$out")" "a.txt" "its target"
has "$out" "zzz-link → a.txt" "the list's row"; lacks "$out" " -> " "yazi's own arrow gone"
long=zzzz$(printf '日本語%.0s' {1..24})
: >"$W/$long"
out=$(y 120x30 <<'EOF'
wait a.txt
settle
key G
settle
key <Tab>
wait owner
settle
screen
key <Tab>
settle
quit
EOF
)
rm -f "$W/$long"
case_ "Tab on a very long Japanese name: cut by whole characters to its column, the rule's end still there, never a broken byte"
has "$out" "zzzz日本語" "the name's start"; lacks "$out" "�" "no broken character"; has "$out" "owner" "the card whole"
fi
out=$(y 120x30 <<'EOF'
wait a.txt
settle
key <Space>
settle
key <Space>
settle
screen
quit
EOF
)
case_ "marks: a muted fact at the rule's end, no block of colour"
has "$(sed -n 1p <<<"$out")" "2 marked" "the count at the rule's end"
if "$YAZI" --version 2>/dev/null | grep -q 'Patch  : fedokawaii'; then
  RING_TL=$(printf '\363\277\200\203') RING_T=$(printf '\363\277\200\204') KEY_L=$(printf '\363\277\200\201') KEY_R=$(printf '\363\277\200\202')
  key_of() { local i o=$KEY_L c n; for ((i = 0; i < ${#1}; i++)); do printf -v n %d "'${1:i:1}"; printf -v c '\\363\\277\\%03o\\%03o' $((0x80 + (n >> 6))) $((0x80 + (n & 63))); printf -v c '%b' "$c"; o+=$c; done; printf '%s%s' "$o" "$KEY_R"; }
  out=$(y 120x30 <<'EOF'
wait a.txt
settle
key r
wait rename
settle
screen
key <Esc>
settle
key <Esc>
settle
key d
wait trash
settle
screen
key n
settle
key a
wait new file
settle
key plan.pdf
settle
screen
key <Esc>
settle
key <Esc>
settle
key ~
wait a key or a word
settle
screen
key <Esc>
settle
key <Esc>
settle
key g
settle
screen
key <Esc>
settle
key w
wait tasks
settle
screen
key <Esc>
settle
quit
EOF
  )
  case_ "the pop-ups: the ring of cells, never rounded, nothing in its rule, a heading inside"
  has "$out" "$RING_TL$RING_T" "the ring's corner and top"
  for c in ╭ ╮ ╰ ╯; do lacks "$out" "$c" "no rounded corner"; done
  has "$out" "  rename ─" "rename's heading: its name, the rule"
  lacks "$out" "Rename:" "yazi's own word gone"; lacks "$out" "[Y]es" "yazi's button gone"
  case_ "trash: the folder said once, the name, the choices as keys; n keeps it"
  has "$out" "  trash 1 file? ─"; has "$out" "$(key_of y) trash"; has "$out" "$(key_of n) keep"
  [[ -e $W/a.txt ]] && _ok || _no "n: the file kept"
  # shellcheck disable=SC2088  # (the ~ yazi shows)
  has "$out" "~/work" "the folder"
  case_ "create: what is typed on the row's columns, its heading"
  has "$out" "plan.pdf"; has "$out" "new file ─"
  case_ "help: keys as tiles, what they do lower case, a search line with its ghost and its count; its layer in plain words"
  has "$out" "keys  files ─"; has "$out" "a key or a word"; has "$out" "$(key_of enter)" "a key's tile"; lacks "$out" "mgr.help"
  has "$out" "into the folder" "what it does, lower case"
  case_ "which (g): the same ring, each key its tile"
  has "$out" "$(key_of h)" "g h"
  case_ "tasks: none, said quietly under its heading"
  has "$out" "tasks ─"; has "$out" " none"
  case_ "tasks: the panel fits what it says — the heading, its paper, one row (never a big empty frame), inside its ring"
  eq "$(sed -n '/tasks ─/,$p' <<<"$out" | grep -cF $'\U000FF006')" 3 "three rows between the ring's top and bottom"
else echo "  (the installed yazi has not the desktop's patch yet: its pop-ups' cases skipped)"; fi

# The size column's counts (plugins/kawa-count.yazi): every folder on the page, before the cursor has been over it
setup
mkdir -p "$W/sub dir/x" "$W/many"; : >"$W/sub dir/y"; (cd "$W/many" && seq 1 10001 | xargs touch)
out=$(y 120x30 <<'EOF'
wait a.txt
settle
screen
key k
screen
quit
EOF
)
case_ "a folder says how many it holds at once, the cursor never been over it; more than the fetcher reads: 10k+; nothing left running (quit asks nothing)"
has "$(grep -F 'sub dir' <<<"$out" | head -n1)" " 2 " "sub dir: two"
has "$(grep -F 'notes.xopp' <<<"$out" | head -n1)" " 0 " "notes.xopp, a folder with nothing in it: 0"
has "$(grep -F 'many' <<<"$out" | head -n1)" "10k+" "many: at most the fetcher's limit read"
lacks "$out" "quit?" "no task of its own to ask about"

flush; rm -f "$SF"
done_
