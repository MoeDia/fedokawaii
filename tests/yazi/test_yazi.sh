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
case_ "init.lua's frame: one free column at the left of the header and of the status line"
head1=$(sed -n 1p <<<"$out"); tail1=$(sed -n 30p <<<"$out")
eq "${head1:0:1}" " " "the header"
# shellcheck disable=SC2088  # (the ~ yazi shows, not one to expand)
has "$head1" "~/work"
eq "${tail1:0:2}" "  " "the status line (a free column, then the mode's key)"; has "$tail1" "NOR"

# ── Enter: smart-enter.yazi ──────────────────────────────────────────────────────────────
case_ "Enter on a folder goes into it (yazi's own Enter would open it in the editor)"
y <<'EOF'
wait a.txt
settle
key <Enter>
wait No items
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
wait No items
quit
EOF
eq "$(last_dir)" "$W/notes.xopp"; not_called '^xournalpp'

case_ "Enter in an empty folder does nothing at all"
reset_calls
CWD=$W/empty y <<'EOF'
wait No items
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
wait enter open
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
gone enter open
key M
wait enter open
settle
key q
gone enter open
key M
wait enter open
settle
key M
gone enter open
quit
EOF
)
case_ "M lists the drives: label, size, file system, open or closed — and the keys"
has "$out" "drives"
has "$out" "KINGSTON                          28.9G  vfat   open"
has "$out" "WD Elements                      431.5G  ntfs   closed"
has "$out" "enter open  ·  e eject  ·  esc close"
called '^kawa-drives list$'
case_ "the list starts on the first drive; j and k (↓ ↑) move, and not past either end"
lit() { sed -n "$((30 * $1 + 31)),$((30 * $1 + 60))p" <<<"$out" | grep -oE 'KINGSTON|WD Elements'; }
eq "$(lit 0)" "KINGSTON"; eq "$(lit 1)" "WD Elements"; eq "$(lit 2)" "WD Elements" "j at the end"
eq "$(lit 3)" "KINGSTON"; eq "$(lit 4)" "KINGSTON" "↑ at the top"
case_ "Esc, q and M each close the list (the session ran through all three)"
eq "$(grep -c '^kawa-drives list' "$CALLS")" 3 "three times opened, three times listed"

case_ "Enter on a closed drive opens it (kawa-drives open) and goes there"
reset_calls; echo "$MNT/WD" >"$KD/open"
y <<'EOF'
wait a.txt
settle
key M
wait enter open
settle
key j
settle
key <Enter>
gone enter open
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
wait enter open
settle
key $k
gone enter open
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
wait enter open
settle
key <Enter>
sleep 0.4
settle
screen
key <Esc>
gone enter open
quit
EOF
)
called '^kawa-drives open /dev/sdb1$'; has "$out" "enter open"
eq "$(grep -c '^kawa-drives list' "$CALLS")" 2 "listed again after the failure"
eq "$(last_dir)" "$W"

case_ "e ejects the hovered drive in the background (setsid), and the list closes"
reset_calls
y <<'EOF'
wait a.txt
settle
key M
wait enter open
settle
key j
settle
key e
gone enter open
waitfile $TMP/hit.setsid
quit
EOF
called '^setsid -f kawa-drives eject /dev/sdc2$'; eq "$(last_dir)" "$W" "standing elsewhere: no step out"

case_ "standing in a drive: the list opens on it, and e steps out to the home first"
reset_calls
printf '/dev/sdc2\t/dev/sdc\tWD Elements\t431.5G\tntfs\t\n/dev/sdb1\t/dev/sdb\tKINGSTON\t28.9G\tvfat\t%s\n' \
  "$MNT/KINGSTON" >"$KD/list"
out=$(CWD=$MNT/KINGSTON/photos y <<'EOF'
wait No items
settle
key M
wait enter open
settle
lit
key e
gone enter open
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
wait enter open
settle
key j
settle
key <Esc>
gone enter open
key M
wait enter open
settle
key <Enter>
gone enter open
settle
quit
EOF
called '^kawa-drives open /dev/sdb1$'; not_called 'open /dev/sdc2'

drives_screen() {   # drives_screen [SIZE] [KEYS…] — the screen with M open (after KEYS)
  local size=${1:-100x30} k steps=$'wait a.txt\nsettle\nkey M\nwait enter open\nsettle'
  shift
  for k; do steps+=$'\n'"key $k"$'\nsettle'; done
  y "$size" <<<"$steps"$'\nscreen\nkey <Esc>\ngone enter open\nquit'
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
wait enter open
settle
screen
key j
settle
key j
settle
key <Enter>
gone enter open
quit
EOF
)
has "$out" "Photos from the long trip to"; lacks "$out" "coast"; has "$out" "…"
has "$out" "写真とビデオのバックアップ"; lacks "$out" "二〇二六年夏" "the long Japanese label is cut too"
has "$out" "$odd"
called '^kawa-drives open /dev/sdd1$' "opening passes the drive's device, never its label"
[[ ! -e $HOME/pwned ]] && _ok || _no "a label ran as a command"
# every row of the frame ends in its border at the same column (wide characters counted right)
python3 - "$out" <<'EOF' && _ok || _no "the frame's right border is not straight"
import sys, unicodedata
rows = [r for r in sys.argv[1].split("\n") if r.count("│") >= 3 and any(w in r for w in ("1.9T", "64G", "8G", "enter open"))]
def last_bar(r):
    w, at = 0, None
    for ch in r:
        if ch == "│": at = w
        w += 2 if unicodedata.east_asian_width(ch) in "WF" else 1
    return at
sys.exit(0 if len(rows) == 4 and len({last_bar(r) for r in rows}) == 1 else 1)
EOF
case_ "a narrow window (50 columns): the list fits, cut to the window"
out=$(drives_screen 50x20)
has "$out" "enter open"; has "$out" "exfat"

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
wait Into the folder
settle
screen
key <Esc>
key <Esc>
gone Into the folder
quit
EOF
)
has "$out" "Into the folder, or open the file(s)"; has "$out" "Drives: open or eject one"
has "$out" "Go to your drives (~/Drives: one per open drive)"

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
wait Watch it together
settle
screen
key <Esc>
key <Esc>
gone Watch it together
quit
EOF
)
has "$out" "Watch it together (Syncplay)"
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
wait No items
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
has "$out" "space mark  ·  enter open" "(open after the first Esc)"; eq "$(answer)" "" "cancelled: no answer"
case_ "a long folder in the dialog's title: cut at its start with …, the '· ' before it kept, the rule to the edge"
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
has "$head1" "open file · …"; has "$head1" "/مجلد ─"
eq "$(python3 -I -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import drive
print(sum(drive.width(c) for c in sys.stdin.read().rstrip("\n")))' "$D" <<<"$head1")" 99 "(the title rule: the window less its free column)"

flush; rm -f "$SF"
done_
