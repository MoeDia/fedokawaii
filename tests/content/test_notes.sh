#!/usr/bin/env bash
# shellcheck disable=SC2088  # (a ~ here is the window's own way of writing the home folder)
# tests/content/test_notes.sh — kawa-notes (Super+N) and its page (notes.lua): today's heading
# once a day as the warm page shows, the tidy-up as it is put away, a folder or file that is
# odd or missing, a full disk, the day changing, locales. The window is a stand-in that
# writes what "you typed"; neovim itself (when this machine has it) runs notes.lua for real,
# in a terminal of its own — put away and shown again through its socket, and closed under
# it. (The key itself, dwl's warm toggle: tests/session/test_warm.sh.)
. "$(dirname "$0")/lib.sh"

setup() {   # setup — a fresh sandbox; the window writes $TYPED into $NOTES_FILE, as neovim
            # saves it: a fresh line opened under the end, what was typed on it
  sandbox; unset LOCPATH KAWA_NOTES
  export N=$HOME/Notes/notes.md NOTES_FILE=$HOME/Notes/notes.md TYPED='\n'   # (nothing typed)
  stub kawa-warm
  stub date 'echo "2026-10-16 · Fri"'
  window() { [ -f "$NOTES_FILE" ] && printf "$TYPED" >>"$NOTES_FILE"; }
}
# shown — the warm page shown, typed in and put away (notes.lua: --today as it shows, then the
# window's typing, --tidy as it goes)
shown() { kawa-notes --today || return; window; kawa-notes --tidy; }
day() { stub date "echo '$1'"; }                       # day "2026-10-17 · Sat"
bytes() { od -An -c "$1" | tr -s ' \n' ' '; }
H='## 2026-10-16 · Fri'

# ── a day in the diary ───────────────────────────────────────────────────────
case_ "Super+N's own command (kawa-notes): the warm page shown or put away — kawa-warm's toggle, nothing else"
setup
rc 0 kawa-notes
called "^kawa-warm notes\$"; [[ ! -e $N ]] && _ok || _no "the press touched the notes"
case_ "first time: ~/Notes made, today's heading"
setup; kawa-notes --today
eq "$(cat "$N"; printf x)" "$H"$'\n\nx'
case_ "...put away without writing: no heading left behind, an empty file"
setup; shown
eq "$(bytes "$N")" ""; [[ -f $N ]] && _ok || _no "the notes file went"

case_ "something written: kept under today's heading, the spare blank lines tidied"
setup; export TYPED='milk\n\n\n'
shown
eq "$(cat "$N")" "$H"$'\n\nmilk'; eq "$(tail -c1 "$N" | od -An -c | tr -d ' ')" '\n' "one newline at the end"

case_ "the same day again: no second heading; it opens on the notes as they are"
TYPED='eggs\n'; shown
eq "$(cat "$N")" "$H"$'\n\nmilk\neggs'; eq "$(grep -c '^## ' "$N")" 1

case_ "the next day: a blank line, the new heading; nothing written → yesterday's notes exactly as they were"
before=$(bytes "$N"); day "2026-10-17 · Sat"; TYPED='\n'
shown
eq "$(bytes "$N")" "$before"
case_ "the next day, something written: under its own heading"
TYPED='call the bank\n'; shown
eq "$(cat "$N")" "$H"$'\n\nmilk\neggs\n\n## 2026-10-17 · Sat\n\ncall the bank'

case_ "a file that ended mid-line (written elsewhere): the heading still starts a line of its own"
setup; mkdir -p "${N%/*}"; printf 'no newline at the end' >"$N"; TYPED='new\n'
shown
eq "$(cat "$N")" $'no newline at the end\n\n'"$H"$'\n\nnew'
case_ "...and closed without writing: as it was (with a newline at its end)"
setup; mkdir -p "${N%/*}"; printf 'no newline at the end' >"$N"; TYPED='\n'
shown; eq "$(bytes "$N")" "$(printf 'no newline at the end\n' | od -An -c | tr -s ' \n' ' ')"

case_ "notes written on Windows (CR LF line ends): closed without writing, exactly as they were"
setup; mkdir -p "${N%/*}"; printf 'from windows\r\nsecond\r\n' >"$N"; before=$(bytes "$N")
shown; eq "$(bytes "$N")" "$before"
case_ "...something written: the heading and the tidy-up end their lines in CR LF too"
export TYPED='typed\r\n'; shown
eq "$(bytes "$N")" "$(printf 'from windows\r\nsecond\r\n\r\n%s\r\n\r\ntyped\r\n' "$H" | od -An -c | tr -s ' \n' ' ')"
case_ "...and the same day again: no second heading"
TYPED='\r\n'; shown; eq "$(grep -c '^## ' "$N")" 1

case_ "put away after midnight: the heading of the day it showed tidied too"
setup; export DATE_N=$TMP/date.n
stub date 'n=$(cat "$DATE_N" 2>/dev/null || echo 0); echo $((n + 1)) >"$DATE_N"
[ "$n" = 0 ] && echo "2026-10-16 · Fri" || echo "2026-10-17 · Sat"'
shown; eq "$(bytes "$N")" ""

case_ "everything deleted in the window: an empty file, not a heading"
setup; window() { : >"$NOTES_FILE"; }; shown
eq "$(bytes "$N")" ""
case_ "only blank lines written: no heading left"
setup; TYPED='\n\n   \n\t\n'; shown; eq "$(bytes "$N")" ""

# ── where the notes are ──────────────────────────────────────────────────────
case_ "KAWA_NOTES elsewhere, its path with spaces, Arabic and Japanese: made, written, tidied"
setup; export KAWA_NOTES="$HOME/my notes/ملاحظات/日記.md" NOTES_FILE="$HOME/my notes/ملاحظات/日記.md" TYPED='شاي\n'
shown
eq "$(cat "$KAWA_NOTES")" "$H"$'\n\nشاي'
case_ "notes.md a link (kept in a synced folder): written through, still a link"
setup; mkdir -p "$HOME/Sync" "${N%/*}"; printf 'old\n' >"$HOME/Sync/notes.md"; ln -s ../Sync/notes.md "$N"
export TYPED='new\n'; shown
[[ -L $N ]] && _ok || _no "the link was replaced by a file"
eq "$(cat "$HOME/Sync/notes.md")" $'old\n\n'"$H"$'\n\nnew'
case_ "the notes' permissions are kept by the tidy-up"
setup; mkdir -p "${N%/*}"; printf 'secret\n' >"$N"; chmod 600 "$N"; TYPED='more\n\n\n'
shown; eq "$(stat -c %a "$N")" 600

case_ "the folder cannot be made (a file in its place): fails"
setup; : >"$HOME/Notes"
rc 1 kawa-notes --today
case_ "a full disk while tidying: the notes stay as they were saved, no stray file"
setup; mkdir -p "${N%/*}"; printf 'precious\n' >"$N"; TYPED='\n\n\n'; stub sync 'exit 1'
shown
eq "$(cat "$N")" $'precious\n\n'"$H" "(the empty heading stays: better than a half-written diary)"
eq "$(ls -A "${N%/*}")" "notes.md"
case_ "no XDG_RUNTIME_DIR: says so and fails, nothing touched"
setup
out=$(env -u XDG_RUNTIME_DIR kawa-notes --today 2>&1); r=$?
eq "$r" 1; has "$out" XDG_RUNTIME_DIR; [[ ! -e $N ]] && _ok || _no "the notes were made anyway"

case_ "a big diary (2 MB): tidied in reasonable time, byte for byte"
setup; mkdir -p "${N%/*}"
python3 -I -c 'import sys
with open(sys.argv[1], "w") as f:
    for d in range(4000): f.write("\n## day %d\n\n" % d + "- a note about something\n" * 20)' "$N"
before=$(sha1sum <"$N"); TYPED='\n'
s=$EPOCHREALTIME; shown; e=$EPOCHREALTIME
eq "$(sha1sum <"$N")" "$before"
(( ${e/./} - ${s/./} < 3000000 )) && _ok || _no "took $(( (${e/./} - ${s/./}) / 1000 )) ms (the page waits on it as it shows)"
case_ "a big diary, written to: the new lines kept, the rest byte for byte"
TYPED='new line\n\n'; shown
eq "$(tail -n 5 "$N")" "- a note about something

$H

new line" "(tail)"
eq "$(head -c 2000000 "$N" | sha1sum)" "$(python3 -I -c 'import sys
s = "".join("\n## day %d\n\n" % d + "- a note about something\n" * 20 for d in range(4000))
sys.stdout.write(s[:2000000])' | sha1sum)"
case_ "a NUL byte at the end of the notes (pasted binary): left exactly as it is"
setup; mkdir -p "${N%/*}"; printf 'text\0more\n' >"$N"; before=$(sha1sum <"$N"); TYPED=''
stub date 'echo "2026-10-16 · Fri"'
shown 2>"$TMP/err"
eq "$(tail -c 10 "$N" | od -An -c | tr -s ' ')" "$(printf 'more\n\n%s\n\n' "$H" | tail -c 10 | od -An -c | tr -s ' ')" "(heading added, nothing cut)"
has "$(od -An -c "$N" | tr -s ' ')" '\0' "the NUL byte is still there"
eq "$(cat "$TMP/err")" "" "no warning printed"

case_ "Turkish and Arabic locales: the heading in English and Western digits"
for l in tr_TR ar_EG; do
  setup; rm -f "$STUBS/date"; window() { cp "$NOTES_FILE" "$HOME/while-open"; }
  if locale_of $l; then
    LC_ALL=$LOC shown
    [[ $(head -n1 "$HOME/while-open") =~ ^##\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ ·\ (Mon|Tue|Wed|Thu|Fri|Sat|Sun)$ ]] && _ok \
      || _no "$l: $(head -n1 "$HOME/while-open")"
  else skip "no $l.UTF-8 locale"; fi
done

# ── inside the window ────────────────────────────────────────────────────────
case_ "inside: neovim on the notes, notes.lua its whole configuration (not LazyVim: instant), listening for kawa-warm"
setup; stub nvim 'printf "%s\n" "$@" >"$HOME/nvim.args"; env >"$HOME/nvim.env"'
export KAWA_NOTES="$HOME/Notes/50% off.md"
kawa-notes --inside
eq "$(cat "$HOME/nvim.args")" "-n
-i
NONE
--listen
$XDG_RUNTIME_DIR/kawa-notes.nvim
-u
$HOME/.config/fedokawaii/notes.lua
--
$HOME/Notes/50% off.md"
has "$(cat "$HOME/nvim.env")" "KAWA_NOTES_WHERE=~/Notes/50% off.md"
lacks "$(cat "$HOME/nvim.env")" "KAWA_NOTES_ICON=" "(the heading is the kanji's: no icon handed over)"
case_ "inside, shown as it starts (its key started it: kawa-warm --open): today's note at once"
kawa-notes --inside --shown
has "$(cat "$HOME/nvim.args")" $'-c\nlua kawa_notes_shown()\n--'
case_ "inside: neovim ended (:q, the window closed) — the end of the file tidied"
setup; mkdir -p "${N%/*}"; printf 'kept\n\n%s\n\n\n' "$H" >"$N"; stub nvim
kawa-notes --inside; eq "$(cat "$N")" "kept"

case_ "misuse and help"
setup
rc 2 kawa-notes --bogus; rc 2 kawa-notes notes.md; not_called 'kawa-warm'
rc 0 kawa-notes --help; has "$(kawa-notes --help)" "Super+N"

# ── notes.lua, in a real neovim ──────────────────────────────────────────────
if [[ -z $REAL_NVIM ]]; then
  skip "no neovim here: notes.lua not run"
else
  setup; rm -f "$STUBS/nvim"; config .config/fedokawaii/notes.lua
  # (the window's neovim, on its socket — kawa-notes.nvim: keys are typed in through it)
  stub nvim "exec '$REAL_NVIM' --clean \"\$@\""     # (the page alone, without LazyVim)
  ask() {   # ask LUA-EXPR [FILE] — the value, from neovim set up as the window sets it up
    KAWA_NOTES_WHERE='~/Notes/50% off.md' nvim --headless \
      -c 'luafile ~/.config/fedokawaii/notes.lua' -c "lua io.stdout:write(vim.inspect($1))" -c 'qa!' -- "${2:-$TMP/n.md}" 2>/dev/null
  }
  case_ "notes.lua: a page — no numbers, signs or spell marks, four columns in, lines wrapped at words"
  eq "$(ask '{vim.wo.number, vim.wo.relativenumber, vim.wo.signcolumn, vim.wo.foldcolumn, vim.wo.wrap, vim.wo.linebreak, vim.wo.spell, vim.wo.cursorline}')" \
     '{ false, false, "no", "4", true, true, false, false }'
  case_ "notes.lua: the heading (記, notes, the stitch: §7); the footer names the file ('%' kept as a '%') and the keys"
  has "$(ask vim.wo.winbar)" "%#KawaGround#  %#KawaKanji#記%#KawaGround#  %#KawaName#notes %#KawaStitch#%="
  has "$(ask "vim.opt_local.fillchars:get().wbr")" "╌"
  has "$(ask vim.wo.statusline)" "%#KawaMuted#~/Notes/50%% off.md  ·  saved as you go  ·  super+n puts it away"
  eq "$(ask '{vim.o.laststatus, vim.o.cmdheight}')" "{ 2, 0 }"
  case_ "notes.lua: nothing written over the footer while typing (no mode, no keys, no 'written')"
  eq "$(ask '{vim.o.showmode, vim.o.showcmd, vim.o.ruler}')" "{ false, false, false }"
  has "$(ask vim.o.shortmess)" "WFcsS"
  case_ "notes.lua: writes without waiting for the disk, and never reformats the page (LazyVim's autoformat off)"
  eq "$(ask '{vim.o.fsync, vim.b.autoformat}')" "{ false, false }"
  hl() { nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' \
    -c "lua local h = vim.api.nvim_get_hl(0, {name='$1'}); io.stdout:write(string.format('%06x %06x', h.fg or 0, h.bg or 0))" \
    -c 'qa!' -- "$TMP/n.md" 2>/dev/null; }
  case_ "notes.lua: the theme's inks — the kanji accent_text, the name text, the stitch edge2, the footer muted, on the ground"
  ink() { sed -n "s/^C_$2=\([0-9a-f]*\).*/\1/p" "$HOME/.config/fedokawaii/themes/$1/colors.sh"; }   # ink THEME NAME
  eq "$(hl KawaKanji)" "$(ink dark ACCENT_TEXT) $(ink dark GROUND)"; eq "$(hl KawaName)" "$(ink dark TEXT) $(ink dark GROUND)"
  eq "$(hl KawaStitch)" "$(ink dark EDGE2) $(ink dark GROUND)"; eq "$(hl KawaMuted)" "$(ink dark MUTED) $(ink dark GROUND)"
  [[ $(ink dark EDGE2) =~ ^[0-9a-f]{6}$ && $(ink dark EDGE2) != "$(ink light EDGE2)" ]] && _ok || _no "the themes' C_EDGE2 (read: a name with a digit)"
  ln -sfn themes/light "$HOME/.config/fedokawaii/current"
  eq "$(hl KawaMuted)" "$(ink light MUTED) $(ink light GROUND)" "on paper"
  eq "$(hl KawaStitch)" "$(ink light EDGE2) $(ink light GROUND)" "on paper: the stitch"
  rm "$HOME/.config/fedokawaii/current"
  eq "$(hl KawaMuted)" "$(ink dark MUTED) $(ink dark GROUND)" "no theme set up: the dark one's, from its file"
  ln -s themes/dark "$HOME/.config/fedokawaii/current"
  case_ "notes.lua: a theme switch while open (ColorScheme) brings the new colours"
  out=$(nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' \
    -c "lua vim.uv.fs_unlink(vim.fn.expand('~/.config/fedokawaii/current')); vim.uv.fs_symlink('themes/light', vim.fn.expand('~/.config/fedokawaii/current'))" \
    -c 'doautocmd ColorScheme' -c "lua io.stdout:write(string.format('%06x', vim.api.nvim_get_hl(0, {name='KawaMuted'}).fg))" -c 'qa!' -- "$TMP/n.md" 2>/dev/null)
  eq "$out" "$(sed -n 's/^C_MUTED=\([0-9a-f]*\).*/\1/p' "$HOME/.config/fedokawaii/themes/light/colors.sh")"
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"

  # the real window: kawa-notes --inside in a terminal of its own; once the page is drawn
  # (its line of keys shows), "hello world" is typed and 0.05 s later the terminal goes
  ours() { local p; for p in $(pgrep -f "$TMP" 2>/dev/null); do kill -KILL "$p" 2>/dev/null; done; }
  case_ "the window ended (the session ending) a pause after typing: nothing lost — written once a second passes without a change (Super+Q puts a warm window away: dwl)"
  setup; rm -f "$STUBS/nvim"; config .config/fedokawaii/notes.lua
  stub nvim "exec '$REAL_NVIM' --clean \"\$@\""
  mkdir -p "${N%/*}"; printf '%s\n\n' "$H" >"$N"
  python3 -I "$C/pty_run.py" --timeout 20 --answer 'saved as you go' 'hello world' --hangup +1.6 -- kawa-notes --inside --shown >/dev/null
  eq "$(cat "$N")" "$H"$'\n\nhello world'
  case_ "...and the next Super+N asks nothing about a swap file"
  out=$(python3 -I "$C/pty_run.py" --timeout 20 --answer 'saved as you go' '' --hangup +0.3 -- kawa-notes --inside --shown | tr -d '\0')
  has "$out" "saved as you go" "(the page came up)"
  lacks "$out" "E325"; lacks "$out" "ATTENTION"
  eq "$(find "$XDG_STATE_HOME" -name '*.sw?' 2>/dev/null)" "" "no swap file kept"
  case_ "...and no neovim is left running"
  sleep 0.3; eq "$(pgrep -f "$XDG_RUNTIME_DIR/kawa-notes.nvim" 2>/dev/null)" ""

  # the notes changed elsewhere while the window is open: once "hello" is saved, a line is
  # added from outside (a sync tool, a shell), then " world" typed — through neovim's own
  # socket, so it comes after the change whatever the machine's speed
  elsewhere() {   # elsewhere 'SHELL CODE' — run on $N once "hello" is in it
    for _ in {1..200}; do grep -q hello "$N" 2>/dev/null && break; sleep 0.05; done
    N=$N sh -c "$1"; sleep 0.5
    "$REAL_NVIM" --server "$XDG_RUNTIME_DIR/kawa-notes.nvim" --remote-send ' world' 2>/dev/null
  }
  for how in 'printf "from the phone\n" >>"$N"' \
             '{ cat "$N"; echo "from the phone"; } >"$N.new" && mv "$N.new" "$N"'; do
    case_ "notes changed elsewhere while open ($how): taken in, no write-anyway question, typing goes on"
    printf '%s\n\nfirst\n' "$H" >"$N"
    elsewhere "$how" & bg=$!
    out=$(python3 -I "$C/pty_run.py" --timeout 20 --answer 'saved as you go' 'hello' --hangup +3 -- kawa-notes --inside --shown | tr -d '\0')
    wait "$bg"
    eq "$(cat "$N")" "$H"$'\n\nfirst\nhello world\nfrom the phone'
    lacks "$out" "really want to write"; lacks "$out" "changed since"
  done
  case_ "notes deleted elsewhere while open: the page stays, the next key writes it back"
  printf '%s\n\nfirst\n' "$H" >"$N"
  elsewhere 'rm "$N"' & bg=$!
  out=$(python3 -I "$C/pty_run.py" --timeout 20 --answer 'saved as you go' 'hello' --hangup +3 -- kawa-notes --inside --shown | tr -d '\0')
  wait "$bg"
  eq "$(cat "$N" 2>/dev/null)" "$H"$'\n\nfirst\nhello world'; lacks "$out" "really want to write"
  case_ "another file opened in the window (:e ~/Notes/trip.md): a page too — its name in the footer, saved as you go"
  printf '%s\n\nfirst\n' "$H" >"$N"
  ( for _ in {1..200}; do [[ -S $XDG_RUNTIME_DIR/kawa-notes.nvim ]] && break; sleep 0.05; done; sleep 0.5
    "$REAL_NVIM" --server "$XDG_RUNTIME_DIR/kawa-notes.nvim" --remote-send '<Esc>:e ~/Notes/trip.md<CR>ibuy a SIM card' ) & bg=$!
  out=$(python3 -I "$C/pty_run.py" --timeout 20 --answer 'saved as you go' '' --hangup +2.5 -- kawa-notes --inside --shown | tr -d '\0')
  wait "$bg"
  eq "$(cat "$HOME/Notes/trip.md" 2>&1)" "buy a SIM card" "(closed by Super+Q: nothing lost)"
  eq "$(cat "$N")" "$H"$'\n\nfirst' "(the notes as they were)"
  out=$(nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'e ~/Notes/trip.md' \
    -c "lua io.stdout:write(vim.inspect({vim.api.nvim_eval_statusline(vim.wo.winbar, {winid = 0, use_winbar = true}).str, vim.api.nvim_eval_statusline(vim.wo.statusline, {winid = 0}).str, vim.wo.number, vim.wo.foldcolumn, vim.wo.wrap}))" \
    -c 'qa!' -- "$N" 2>/dev/null)
  has "$out" "  記  notes ╌╌╌"; has "$out" "  ~/Notes/trip.md  ·  saved as you go"; has "$out" 'false, "4", true }'
  # the warm page: put away (kawa-warm --hidden) and shown again the next day (--shown),
  # through its socket as kawa-warm does — saved and tidied as it goes, today's note as it shows
  case_ "warm: put away — saved and tidied; shown the next day — its heading, the cursor under it, typing"
  printf '%s\n\nfirst\n' "$H" >"$N"
  ( for _ in {1..200}; do grep -q hello "$N" 2>/dev/null && break; sleep 0.05; done; sleep 0.3
    "$REAL_NVIM" --server "$XDG_RUNTIME_DIR/kawa-notes.nvim" --remote-expr 'v:lua.kawa_notes_hidden()' >"$TMP/hid" 2>&1
    cp "$N" "$TMP/away"
    printf '#!/bin/sh\necho "2026-10-17 · Sat"\n' >"$STUBS/date"
    "$REAL_NVIM" --server "$XDG_RUNTIME_DIR/kawa-notes.nvim" --remote-expr 'v:lua.kawa_notes_shown()' >>"$TMP/hid" 2>&1
    sleep 0.3; "$REAL_NVIM" --server "$XDG_RUNTIME_DIR/kawa-notes.nvim" --remote-send 'tea' 2>/dev/null ) & bg=$!
  out=$(python3 -I "$C/pty_run.py" --timeout 20 --answer 'saved as you go' 'hello' --hangup +3 -- kawa-notes --inside --shown | tr -d '\0')
  wait "$bg"
  eq "$(cat "$TMP/away")" "$H"$'\n\nfirst\nhello' "(away: saved, the fresh line tidied)"
  eq "$(cat "$N")" "$H"$'\n\nfirst\nhello\n\n## 2026-10-17 · Sat\n\ntea'
  eq "$(cat "$TMP/hid")" "" "(no error through the socket)"
  stub date 'echo "2026-10-16 · Fri"'
  case_ "a change elsewhere in the very moment of a key: no question; the file's version stays, the page follows it"
  printf 'one\n' >"$N"
  out=$(timeout 10 nvim --headless -n -c 'luafile ~/.config/fedokawaii/notes.lua' -c "lua vim.defer_fn(function()
      vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'the key' })
      local f = io.open(vim.api.nvim_buf_get_name(0), 'a'); f:write('from the phone\n'); f:close()
      vim.cmd('doautocmd <nomodeline> TextChangedI')
      vim.defer_fn(function() io.stdout:write(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '|')); vim.cmd('qa!') end, 300)
    end, 100)" -- "$N" 2>&1); r=$?
  eq "$r" 0 "(neovim did not stop to ask)"; eq "$out" "one|from the phone"
  eq "$(cat "$N")" $'one\nfrom the phone'
  ours
fi

done_
