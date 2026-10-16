#!/usr/bin/env bash
# shellcheck disable=SC2088  # (a ~ here is the window's own way of writing the home folder)
# tests/content/test_notes.sh — kawa-notes (Super+N) and its page (notes.lua): today's heading
# once a day, the tidy-up when the window goes, the second press that puts it away, presses
# while it opens, a folder or file that is odd or missing, a full disk, the day changing,
# locales. The window is a stand-in that writes what "you typed"; neovim itself (when this
# machine has it) runs notes.lua for real, in a terminal of its own, and is closed under it.
. "$(dirname "$0")/lib.sh"

setup() {   # setup — a fresh sandbox; the window writes $TYPED into $NOTES_FILE, as neovim
            # saves it: a fresh line opened under the end (Go), what was typed on it
  sandbox; unset LOCPATH KAWA_NOTES
  export N=$HOME/Notes/notes.md NOTES_FILE=$HOME/Notes/notes.md TYPED='\n'   # (nothing typed)
  stub kawa-float '[ -f "$NOTES_FILE" ] && printf "$TYPED" >>"$NOTES_FILE"; sleep "${WINDOW_SECS:-0}"'
  stub nvim 'exit 1'                                  # (no notes window open)
  stub date 'echo "2026-10-16 · Fri"'
}
day() { stub date "echo '$1'"; }                       # day "2026-10-17 · Sat"
bytes() { od -An -c "$1" | tr -s ' \n' ' '; }
sock() {   # sock PATH — a unix socket left there, as a running (or crashed) neovim leaves it
  python3 -I -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$1"
}
H='## 2026-10-16 · Fri'

# ── a day in the diary ───────────────────────────────────────────────────────
case_ "first time: ~/Notes made, today's heading, the window (80×25) on the notes"
setup
rc 0 kawa-notes
called "^kawa-float notes 80x25 -- $REPO/bin/kawa-notes --inside\$"
case_ "...closed without writing: no heading left behind, an empty file"
eq "$(bytes "$N")" ""; [[ -f $N ]] && _ok || _no "the notes file went"

case_ "something written: kept under today's heading, the spare blank lines tidied"
setup; export TYPED='milk\n\n\n'
kawa-notes
eq "$(cat "$N")" "$H"$'\n\nmilk'; eq "$(tail -c1 "$N" | od -An -c | tr -d ' ')" '\n' "one newline at the end"

case_ "the same day again: no second heading; it opens on the notes as they are"
TYPED='eggs\n'; kawa-notes
eq "$(cat "$N")" "$H"$'\n\nmilk\neggs'; eq "$(grep -c '^## ' "$N")" 1

case_ "the next day: a blank line, the new heading; nothing written → yesterday's notes exactly as they were"
before=$(bytes "$N"); day "2026-10-17 · Sat"; TYPED='\n'
kawa-notes
eq "$(bytes "$N")" "$before"
case_ "the next day, something written: under its own heading"
TYPED='call the bank\n'; kawa-notes
eq "$(cat "$N")" "$H"$'\n\nmilk\neggs\n\n## 2026-10-17 · Sat\n\ncall the bank'

case_ "a file that ended mid-line (written elsewhere): the heading still starts a line of its own"
setup; mkdir -p "${N%/*}"; printf 'no newline at the end' >"$N"; TYPED='new\n'
kawa-notes
eq "$(cat "$N")" $'no newline at the end\n\n'"$H"$'\n\nnew'
case_ "...and closed without writing: as it was (with a newline at its end)"
setup; mkdir -p "${N%/*}"; printf 'no newline at the end' >"$N"; TYPED='\n'
kawa-notes; eq "$(bytes "$N")" "$(printf 'no newline at the end\n' | od -An -c | tr -s ' \n' ' ')"

case_ "the window's day is the day it opened (closed after midnight: that heading tidied)"
setup; export DATE_N=$TMP/date.n
stub date 'n=$(cat "$DATE_N" 2>/dev/null || echo 0); echo $((n + 1)) >"$DATE_N"
[ "$n" = 0 ] && echo "2026-10-16 · Fri" || echo "2026-10-17 · Sat"'
kawa-notes; eq "$(bytes "$N")" ""

case_ "everything deleted in the window: an empty file, not a heading"
setup; stub kawa-float ': >"$NOTES_FILE"'; kawa-notes
eq "$(bytes "$N")" ""
case_ "only blank lines written: no heading left"
setup; TYPED='\n\n   \n\t\n'; kawa-notes; eq "$(bytes "$N")" ""

# ── one window ───────────────────────────────────────────────────────────────
case_ "Super+N while it is open: neovim saves and quits (the window goes), nothing else"
setup; mkdir -p "${N%/*}"; printf 'kept\n' >"$N"
sock "$XDG_RUNTIME_DIR/kawa-notes.sock"; stub nvim 'exit 0'
rc 0 kawa-notes
called "^nvim --server $XDG_RUNTIME_DIR/kawa-notes.sock --remote-expr 1"
called "^nvim --server $XDG_RUNTIME_DIR/kawa-notes.sock --remote-send <C-\\\\><C-N><Cmd>silent! wqa!<CR>"
not_called kawa-float; eq "$(cat "$N")" "kept"
case_ "a socket left by a neovim that crashed: the window opens all the same"
setup; sock "$XDG_RUNTIME_DIR/kawa-notes.sock"
rc 0 kawa-notes; called '^kawa-float'
[[ ! -e $XDG_RUNTIME_DIR/kawa-notes.sock ]] && _ok || _no "the dead socket stayed"
case_ "a neovim that hangs on the socket: given up on in about a second, the window opens"
setup; sock "$XDG_RUNTIME_DIR/kawa-notes.sock"; stub nvim 'exec sleep 30'
s=$EPOCHREALTIME; kawa-notes; e=$EPOCHREALTIME
called '^kawa-float'; (( ${e/./} - ${s/./} < 4000000 )) && _ok || _no "took $(( (${e/./} - ${s/./}) / 1000 )) ms"

case_ "a second press while it is still opening: does nothing"
setup; export WINDOW_SECS=1
kawa-notes & first=$!; sleep 0.3
rc 0 kawa-notes
wait "$first"; unset WINDOW_SECS
eq "$(grep -c '^kawa-float' "$CALLS")" 1
case_ "Super+N held (20 presses at once): one window, one heading"
setup; export WINDOW_SECS=1 TYPED='once\n'
for _ in {1..20}; do kawa-notes & done; wait; unset WINDOW_SECS
eq "$(grep -c '^kawa-float' "$CALLS")" 1; eq "$(cat "$N")" "$H"$'\n\nonce'
case_ "killed while open, then pressed again: the window opens (the lock is not stuck)"
setup; stub kawa-float 'echo $$ >"$HOME/float.pid"; exec sleep 30'
kawa-notes & first=$!
for _ in {1..40}; do [[ -s $HOME/float.pid ]] && break; sleep 0.05; done
kill -KILL "$first"; wait "$first" 2>/dev/null
setup_float=$(cat "$HOME/float.pid" 2>/dev/null)
stub kawa-float; reset_calls; kawa-notes; called '^kawa-float'
[[ -n $setup_float ]] && kill "$setup_float" 2>/dev/null

# ── where the notes are ──────────────────────────────────────────────────────
case_ "KAWA_NOTES elsewhere, its path with spaces, Arabic and Japanese: made, written, tidied"
setup; export KAWA_NOTES="$HOME/my notes/ملاحظات/日記.md" NOTES_FILE="$HOME/my notes/ملاحظات/日記.md" TYPED='شاي\n'
kawa-notes
eq "$(cat "$KAWA_NOTES")" "$H"$'\n\nشاي'
case_ "notes.md a link (kept in a synced folder): written through, still a link"
setup; mkdir -p "$HOME/Sync" "${N%/*}"; printf 'old\n' >"$HOME/Sync/notes.md"; ln -s ../Sync/notes.md "$N"
export TYPED='new\n'; kawa-notes
[[ -L $N ]] && _ok || _no "the link was replaced by a file"
eq "$(cat "$HOME/Sync/notes.md")" $'old\n\n'"$H"$'\n\nnew'
case_ "the notes' permissions are kept by the tidy-up"
setup; mkdir -p "${N%/*}"; printf 'secret\n' >"$N"; chmod 600 "$N"; TYPED='more\n\n\n'
kawa-notes; eq "$(stat -c %a "$N")" 600

case_ "the folder cannot be made (a file in its place): fails, nothing opened"
setup; : >"$HOME/Notes"
rc 1 kawa-notes; not_called kawa-float
case_ "a full disk while tidying: the notes stay as they were saved, no stray file"
setup; mkdir -p "${N%/*}"; printf 'precious\n' >"$N"; TYPED='\n\n\n'; stub sync 'exit 1'
kawa-notes
eq "$(cat "$N")" $'precious\n\n'"$H" "(the empty heading stays: better than a half-written diary)"
eq "$(ls -A "${N%/*}")" "notes.md"
case_ "no XDG_RUNTIME_DIR: says so and fails, nothing touched"
setup
out=$(env -u XDG_RUNTIME_DIR kawa-notes 2>&1); r=$?
eq "$r" 1; has "$out" XDG_RUNTIME_DIR; [[ ! -e $N ]] && _ok || _no "the notes were made anyway"

case_ "a big diary (2 MB): tidied in reasonable time, byte for byte"
setup; mkdir -p "${N%/*}"
python3 -I -c 'import sys
with open(sys.argv[1], "w") as f:
    for d in range(4000): f.write("\n## day %d\n\n" % d + "- a note about something\n" * 20)' "$N"
before=$(sha1sum <"$N"); TYPED='\n'
s=$EPOCHREALTIME; kawa-notes; e=$EPOCHREALTIME
eq "$(sha1sum <"$N")" "$before"
(( ${e/./} - ${s/./} < 3000000 )) && _ok || _no "took $(( (${e/./} - ${s/./}) / 1000 )) ms (Super+N does nothing meanwhile)"
case_ "a big diary, written to: the new lines kept, the rest byte for byte"
TYPED='new line\n\n'; kawa-notes
eq "$(tail -n 5 "$N")" "- a note about something

$H

new line" "(tail)"
eq "$(head -c 2000000 "$N" | sha1sum)" "$(python3 -I -c 'import sys
s = "".join("\n## day %d\n\n" % d + "- a note about something\n" * 20 for d in range(4000))
sys.stdout.write(s[:2000000])' | sha1sum)"
case_ "a NUL byte at the end of the notes (pasted binary): left exactly as it is"
setup; mkdir -p "${N%/*}"; printf 'text\0more\n' >"$N"; before=$(sha1sum <"$N"); TYPED=''
stub date 'echo "2026-10-16 · Fri"'
kawa-notes 2>"$TMP/err"
eq "$(tail -c 10 "$N" | od -An -c | tr -s ' ')" "$(printf 'more\n\n%s\n\n' "$H" | tail -c 10 | od -An -c | tr -s ' ')" "(heading added, nothing cut)"
has "$(od -An -c "$N" | tr -s ' ')" '\0' "the NUL byte is still there"
eq "$(cat "$TMP/err")" "" "no warning printed"

case_ "Turkish and Arabic locales: the heading in English and Western digits"
for l in tr_TR ar_EG; do
  setup; rm -f "$STUBS/date"; stub kawa-float 'cp "$NOTES_FILE" "$HOME/while-open"'
  if locale_of $l; then
    LC_ALL=$LOC kawa-notes
    [[ $(head -n1 "$HOME/while-open") =~ ^##\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ ·\ (Mon|Tue|Wed|Thu|Fri|Sat|Sun)$ ]] && _ok \
      || _no "$l: $(head -n1 "$HOME/while-open")"
  else skip "no $l.UTF-8 locale"; fi
done

# ── inside the window ────────────────────────────────────────────────────────
case_ "inside: neovim on the notes, listening, the page set up, at the end, typing"
setup; stub nvim 'printf "%s\n" "$@" >"$HOME/nvim.args"; env >"$HOME/nvim.env"'
export KAWA_NOTES="$HOME/Notes/50% off.md"
kawa-notes --inside
eq "$(cat "$HOME/nvim.args")" "-n
--listen
$XDG_RUNTIME_DIR/kawa-notes.sock
-c
luafile ~/.config/fedokawaii/notes.lua
-c
normal! Go
-c
startinsert!
--
$HOME/Notes/50% off.md"
has "$(cat "$HOME/nvim.env")" "KAWA_NOTES_WHERE=~/Notes/50% off.md"
has "$(cat "$HOME/nvim.env")" "KAWA_NOTES_ICON=$(. "$HOME/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_NOTE")"

case_ "misuse and help"
setup
rc 2 kawa-notes --bogus; rc 2 kawa-notes notes.md; not_called kawa-float
rc 0 kawa-notes --help; has "$(kawa-notes --help)" "Super+N"

# ── notes.lua, in a real neovim ──────────────────────────────────────────────
if [[ -z $REAL_NVIM ]]; then
  skip "no neovim here: notes.lua not run"
else
  setup; rm -f "$STUBS/nvim" "$STUBS/date"; config .config/fedokawaii/notes.lua
  stub nvim "exec '$REAL_NVIM' --clean \"\$@\""     # (the page alone, without LazyVim)
  ask() {   # ask LUA-EXPR [FILE] — the value, from neovim set up as the window sets it up
    KAWA_NOTES_ICON=X KAWA_NOTES_WHERE='~/Notes/50% off.md' nvim --headless \
      -c 'luafile ~/.config/fedokawaii/notes.lua' -c "lua io.stdout:write(vim.inspect($1))" -c 'qa!' -- "${2:-$TMP/n.md}" 2>/dev/null
  }
  case_ "notes.lua: a page — no numbers, signs or spell marks, three columns in, lines wrapped at words"
  eq "$(ask '{vim.wo.number, vim.wo.relativenumber, vim.wo.signcolumn, vim.wo.foldcolumn, vim.wo.wrap, vim.wo.linebreak, vim.wo.spell, vim.wo.cursorline}')" \
     '{ false, false, "no", "3", true, true, false, false }'
  case_ "notes.lua: the title rule names the file ('%' kept as a '%'), the keys along the bottom"
  has "$(ask vim.wo.winbar)" "%#KawaIcon#X %#KawaName#notes %#KawaRule#· ~/Notes/50%% off.md"
  has "$(ask vim.wo.statusline)" "saved as you type  ·  super+n puts it away"
  eq "$(ask '{vim.o.laststatus, vim.o.cmdheight}')" "{ 2, 0 }"
  case_ "notes.lua: writes without waiting for the disk, and never reformats the page (LazyVim's autoformat off)"
  eq "$(ask '{vim.o.fsync, vim.b.autoformat}')" "{ false, false }"
  hl() { KAWA_NOTES_ICON=X nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' \
    -c "lua local h = vim.api.nvim_get_hl(0, {name='$1'}); io.stdout:write(string.format('%06x %06x', h.fg or 0, h.bg or 0))" \
    -c 'qa!' -- "$TMP/n.md" 2>/dev/null; }
  case_ "notes.lua: the theme's colours — the rule colour 8, the icon 9, the name 7, on the ground"
  eq "$(hl KawaRule)" "7a7262 0f0e0c"; eq "$(hl KawaIcon)" "e66a5f 0f0e0c"; eq "$(hl KawaName)" "cfc3a6 0f0e0c"
  ln -sfn themes/light "$HOME/.config/fedokawaii/current"
  eq "$(hl KawaRule)" "696255 e9e1cb" "on paper"
  rm "$HOME/.config/fedokawaii/current"
  eq "$(hl KawaRule)" "7a7262 0f0e0c" "no theme set up: the dark one's"
  ln -s themes/dark "$HOME/.config/fedokawaii/current"
  case_ "notes.lua: a theme switch while open (ColorScheme) brings the new colours"
  out=$(KAWA_NOTES_ICON=X nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' \
    -c "lua vim.uv.fs_unlink(vim.fn.expand('~/.config/fedokawaii/current')); vim.uv.fs_symlink('themes/light', vim.fn.expand('~/.config/fedokawaii/current'))" \
    -c 'doautocmd ColorScheme' -c "lua io.stdout:write(string.format('%06x', vim.api.nvim_get_hl(0, {name='KawaRule'}).fg))" -c 'qa!' -- "$TMP/n.md" 2>/dev/null)
  eq "$out" 696255
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"

  # the real window: kawa-notes --inside in a terminal of its own; once the page is drawn
  # (its line of keys shows), "hello world" is typed and 0.05 s later the terminal goes
  ours() { local p; for p in $(pgrep -f "$TMP" 2>/dev/null); do kill -KILL "$p" 2>/dev/null; done; }
  case_ "the window closed (Super+Q) just after typing: nothing lost"
  setup; rm -f "$STUBS/nvim" "$STUBS/date"; config .config/fedokawaii/notes.lua
  stub nvim "exec '$REAL_NVIM' --clean \"\$@\""
  mkdir -p "${N%/*}"; printf '%s\n\n' "$H" >"$N"
  python3 -I "$C/pty_run.py" --timeout 20 --answer 'saved as you type' 'hello world' --hangup +0.05 -- kawa-notes --inside >/dev/null
  eq "$(cat "$N")" "$H"$'\n\nhello world'
  case_ "...and the next Super+N asks nothing about a swap file"
  out=$(python3 -I "$C/pty_run.py" --timeout 20 --answer 'saved as you type' '' --hangup +0.3 -- kawa-notes --inside | tr -d '\0')
  has "$out" "saved as you type" "(the page came up)"
  lacks "$out" "E325"; lacks "$out" "ATTENTION"
  eq "$(find "$XDG_STATE_HOME" -name '*.sw?' 2>/dev/null)" "" "no swap file kept"
  case_ "...and no neovim is left running"
  sleep 0.3; eq "$(pgrep -f "$XDG_RUNTIME_DIR/kawa-notes.sock" 2>/dev/null)" ""
  ours
fi

done_
