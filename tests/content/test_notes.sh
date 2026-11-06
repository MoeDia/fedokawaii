#!/usr/bin/env bash
# shellcheck disable=SC2088  # (a ~ here is the window's own way of writing the home folder)
# tests/content/test_notes.sh — kawa-notes (Super+N) and its page (notes.lua): today's heading
# once a day as the warm page shows, the tidy-up as it is put away, a folder or file that is
# odd or missing, a full disk, the day changing, locales. The window is a stand-in that
# writes what "you typed"; neovim itself (when this machine has it) runs notes.lua for real,
# in a terminal of its own — put away and shown again through its socket, and closed under
# it. (The key itself, dwl's warm toggle: tests/session/test_warm.sh.)
. "$(dirname "$0")/lib.sh"
. "$REPO/configs/home/.config/fedokawaii/icons.sh"

setup() {   # setup — a fresh sandbox; the window writes $TYPED into $NOTES_FILE, as neovim
            # saves it: a fresh line opened under the end, what was typed on it
  sandbox; unset LOCPATH KAWA_NOTES
  export N=$HOME/notes/notes.md NOTES_FILE=$HOME/notes/notes.md TYPED='\n'   # (nothing typed)
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
case_ "first time: ~/notes made, today's heading"
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
setup; : >"$HOME/notes"
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
case_ "inside: neovim on the notes, notes.lua its whole configuration (not the editor's: instant), listening for kawa-warm"
setup; stub nvim 'printf "%s\n" "$@" >"$HOME/nvim.args"; env >"$HOME/nvim.env"'
export KAWA_NOTES="$HOME/notes/50% off.md"
kawa-notes --inside
eq "$(cat "$HOME/nvim.args")" "-n
-i
NONE
--listen
$XDG_RUNTIME_DIR/kawa-notes.nvim
-u
$HOME/.config/fedokawaii/notes.lua
--
$HOME/notes/50% off.md"
has "$(cat "$HOME/nvim.env")" "KAWA_NOTES_WHERE=~/notes/50% off.md"
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
  setup; rm -f "$STUBS/nvim"; config .config/fedokawaii/notes.lua; config .config/nvim/lua/config/clipboard.lua
  # (the window's neovim, on its socket — kawa-notes.nvim: keys are typed in through it)
  stub nvim "exec '$REAL_NVIM' --clean \"\$@\""     # (the page alone, without the editor's config)
  ask() {   # ask LUA-EXPR [FILE] — the value, from neovim set up as the window sets it up
    KAWA_NOTES_WHERE='~/notes/50% off.md' nvim --headless \
      -c 'luafile ~/.config/fedokawaii/notes.lua' -c "lua io.stdout:write(vim.inspect($1))" -c 'qa!' -- "${2:-$TMP/n.md}" 2>/dev/null
  }
  case_ "notes.lua: a page — no numbers, signs or spell marks, the words four columns in behind the vermilion margin rule, lines wrapped at words"
  eq "$(ask '{vim.wo.number, vim.wo.relativenumber, vim.wo.signcolumn, vim.wo.foldcolumn, vim.wo.wrap, vim.wo.linebreak, vim.wo.spell, vim.wo.cursorline}')" \
     '{ false, false, "no", "0", true, true, false, false }'
  eq "$(ask vim.wo.statuscolumn)" '"%#KawaGround#  %#KawaMargin#│%#KawaGround# "'
  case_ "notes.lua: the heading in the tabline (never scrolled: the note icon, notes, the stitch — §7) with a blank row under it; at the foot a blank row and the footer (the file, '%' as it is, and the keys) — floats over the window's last two rows, the pen kept above them"
  has "$(ask vim.o.tabline)" "%#KawaGround#  %#KawaIcon#$ICON_NOTE%#KawaGround#  %#KawaName#notes %#KawaStitch#───"
  eq "$(ask 'vim.api.nvim_strwidth(vim.api.nvim_eval_statusline(vim.o.tabline, {use_tabline = true}).str)')" 80 "(the rule to two columns short of the edge: the row full)"
  eq "$(ask '{vim.o.showtabline, vim.wo.winbar}')" '{ 2, "%#KawaGround# " }'
  eq "$(ask '(function() local t = {} for _, w in ipairs(vim.api.nvim_list_wins()) do local c = vim.api.nvim_win_get_config(w) if c.relative ~= "" then t[#t + 1] = (vim.o.lines - c.row) .. ":" .. vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] end end table.sort(t) return t end)()')" '{ "1:  ~/notes/50% off.md  ·  saved as you go  ·  super+n puts it away", "2:" }'
  eq "$(ask '{vim.o.laststatus, vim.o.cmdheight, vim.o.scrolloff}')" "{ 0, 0, 5 }"
  case_ "notes.lua: the page shows what was typed — a \"[ ]\", a link's address, \"**\" as written (markdown's own conceal off: the master, 2 Nov); a day's \"## \" alone hidden"
  printf '%s\n' '[ ] a task' '[a link](https://example.org/x)' '**bold** and `code`' '## 2026-11-01 · Sun' >"$TMP/c2.md"
  eq "$(ask '(function() vim.cmd("redraw") local t = {} for r = 3, 6 do local s = "" for c = 5, 44 do s = s .. vim.fn.screenstring(r, c) end t[#t + 1] = (s:gsub("%s+$", "")) end return table.concat(t, "|") end)()' "$TMP/c2.md")" \
    '"[ ] a task|[a link](https://example.org/x)|**bold** and `code`|2026-11-01 · Sun"'
  case_ "notes.lua: ...and after a reload (a change on disk taken in — the day's heading kawa-notes writes at each first show of a day is one): still no markdown highlighting, the page ruled to its new last line"
  printf '%s\n' '# notes' '' '## 2026-11-01 · Sun' '' 'a line' >"$TMP/r.md"
  eq "$(nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' \
    -c 'lua local f = io.open(vim.api.nvim_buf_get_name(0), "a") f:write("\n## 2026-11-02 · Mon\n") f:close() vim.cmd("checktime") local r, c = -1, 0 for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().kawa_paper, 0, -1, { details = true })) do if m[4].virt_lines then r, c = m[2], c + 1 end end io.stdout:write(tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] == nil) .. " " .. vim.bo.syntax .. " " .. tostring(r == vim.api.nvim_buf_line_count(0) - 1) .. " " .. c)' \
    -c 'qa!' -- "$TMP/r.md" 2>/dev/null)" "true OFF true 1" "(tree-sitter stopped, syntax off, ONE paper, under the new last line — a reload once stranded a second mid-page)"
  case_ "notes.lua: a line opened at the end of the last takes the paper along within the edit itself — before any re-lay (held at the line's start, the new line lay below the old one's paper and neovim scrolled to it: the page jumped, its paper drawn as diff filler; the kit's frames, 2 Nov)"
  printf '%s\n' '# notes' '' '## 2026-11-01 · Sun' '' 'the last line' >"$TMP/e.md"
  eq "$(nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' \
    -c 'lua local n = vim.api.nvim_buf_line_count(0) local l = vim.api.nvim_buf_get_lines(0, n - 1, n, false)[1] vim.api.nvim_buf_set_text(0, n - 1, #l, n - 1, #l, { "", "" }) local r = -1 for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().kawa_paper, 0, -1, { details = true })) do if m[4].virt_lines then r = m[2] end end io.stdout:write(r + 1 .. "/" .. vim.api.nvim_buf_line_count(0))' \
    -c 'qa!' -- "$TMP/e.md" 2>/dev/null)" "6/6" "(the paper under the new last line at once)"
  case_ "notes.lua: a start on a day already written (Super+N with no warm window: -c kawa_notes_shown) — the page laid under the new last line, the pen above the floats with paper ahead (the master, 2 Nov)"
  printf '%s\n' '# notes' '' "## $(LC_ALL=C date '+%Y-%m-%d · %a')" '' 'already written today' >"$TMP/w.md"
  eq "$(KAWA_NOTES_WHERE='~/notes/w.md' nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'lua kawa_notes_shown()' \
    -c 'lua vim.cmd("redraw") local r = -1 for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().kawa_paper, 0, -1, { details = true })) do if m[4].virt_lines then r = m[2] end end io.stdout:write(tostring(r == vim.api.nvim_buf_line_count(0) - 1) .. " " .. tostring(vim.fn.winline() <= vim.fn.winheight(0) - 5))' \
    -c 'qa!' -- "$TMP/w.md" 2>/dev/null)" "true true" "(the page under the last line; the pen five rows above the window's foot)"
  case_ "notes.lua: the page opens on a day's line, never mid-day (the master, 2 Nov) — the latest day that leaves the pen its five rows above: yesterday's when today is short, today's own when today fills them; a today too long for the page: the pen keeps its room below"
  { echo '# notes'; for i in $(seq 1 30); do printf '\n## 2026-10-%02d · Day\n\nline one of day %s\n' "$i" "$i"; done
    printf '\n## %s\n\nalready written today\n' "$(LC_ALL=C date '+%Y-%m-%d · %a')"; } >"$TMP/d.md"
  { cat "$TMP/d.md"; for i in $(seq 1 5); do echo "today, line $i"; done; } >"$TMP/d3.md"
  { cat "$TMP/d.md"; for i in $(seq 1 40); do echo "today, line $i"; done; } >"$TMP/d2.md"
  for f in d d3 d2; do
    KAWA_NOTES_WHERE="~/notes/$f.md" nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'lua kawa_notes_shown()' \
      -c 'lua vim.cmd("redraw") io.stdout:write(vim.fn.getline("w0") .. " " .. tostring(vim.fn.winline() > 5) .. " " .. tostring(vim.fn.winline() <= vim.fn.winheight(0) - 5) .. "|")' \
      -c 'qa!' -- "$TMP/$f.md" 2>/dev/null
  done >"$TMP/today"
  today="## $(LC_ALL=C date '+%Y-%m-%d · %a')"
  eq "$(cut -d'|' -f1 "$TMP/today")" "## 2026-10-30 · Day true true" "(a short today: the page from yesterday's line — got: $(cut -d'|' -f1 "$TMP/today"))"
  eq "$(cut -d'|' -f2 "$TMP/today")" "$today true true" "(today fills the pen's room: today's line on the first row — got: $(cut -d'|' -f2 "$TMP/today"))"
  [[ $(cut -d'|' -f3 "$TMP/today") == "today, line "*" true true" ]] && _ok || _no "a long today: the pen with its room, the page inside today — got: $(cut -d'|' -f3 "$TMP/today")"
  # the page's view after a change, as he types (the master, 2 Nov: verdict 2) — keys given as
  # input, the view read after the loop has run them (as foot's keys come)
  cat >"$TMP/view.lua" <<'VIEWLUA'
vim.o.lines = 40; vim.o.columns = 64
local K, OUT = os.getenv("VKEYS"), os.getenv("VOUT")
local function say(s) local f = io.open(OUT, "a"); f:write(s .. "\n"); f:close() end
local function room() return vim.fn.winline() <= vim.fn.winheight(0) - 5 end
kawa_notes_shown(); vim.cmd("redraw")
local steps = vim.split(K, "|", { plain = true })
local function step(i, t0)
  if i > #steps then return vim.cmd("qa!") end
  vim.api.nvim_input(steps[i])
  vim.defer_fn(function()
    vim.cmd("redraw")
    local t = vim.fn.winsaveview().topline
    say(("%s %s %s"):format(steps[i], math.abs(t - t0) <= 1 and "still" or ("jumped " .. t0 .. "->" .. t), room() and "room" or ("row " .. vim.fn.winline())))
    step(i + 1, t)
  end, 250)
end
vim.defer_fn(function() step(1, vim.fn.winsaveview().topline) end, 200)
VIEWLUA
  view() {   # view FILE KEYS… — each step's line: KEY still|jumped A->B room|row N
    local f=$1; shift
    : >"$TMP/view.out"
    VKEYS=$(IFS='|'; echo "$*") VOUT=$TMP/view.out KAWA_NOTES_WHERE='~/notes/v.md' \
      nvim --headless -n -c 'luafile ~/.config/fedokawaii/notes.lua' -c "luafile $TMP/view.lua" -- "$f" >/dev/null 2>&1
    cat "$TMP/view.out"
  }
  diary() { { echo '# notes'; for i in $(seq 1 30); do printf '\n## 2026-10-%02d · Day\n\nline one of day %s\n' "$i" "$i"; done
    printf '\n## %s\n\nalready written today\n' "$(LC_ALL=C date '+%Y-%m-%d · %a')"; } >"$1"; }
  case_ "notes.lua: a new last line made below the paper — o, yy p, G o, Ctrl+O o, :\$put — leaves the page where it was (one row at most) and the pen its room (the master, 2 Nov: verdict 2's must-fix 1 — the paper moves inside the change)"
  for k in '<Esc>o' '<Esc>yyp' '<Esc>Go' '<C-o>o' '<Esc>yy:$put<CR>' '<CR>'; do
    diary "$TMP/v.md"; eq "$(view "$TMP/v.md" "$k")" "$k still room"
  done
  case_ "...and at the foot of the page: thirty lines given at once, then o and yy p — the pen keeps its five rows to the window's foot, the page one row a step"
  diary "$TMP/v.md"
  out=$(view "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<Esc>o' '<Esc>yyp')
  eq "$(cut -d' ' -f3- <<<"$out" | awk '{print $NF}' | tr '\n' ' ')" "room room room " "(the pen's room after each: $(tr '\n' '|' <<<"$out"))"
  eq "$(sed -n '2,3p' <<<"$out" | awk '{print $2}' | tr '\n' ' ')" "still still " "(o and yy p at the foot: a line a step)"
  case_ "...a paste at the foot (three lines, bracketed, as a terminal pastes) and paging (Ctrl+F twice, Ctrl+B): the pen keeps its room — the view as the page left it, the pen moved into it (the master, verdicts 3 and 4)"
  diary "$TMP/v.md"
  out=$(view "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" "<Cmd>lua vim.api.nvim_paste('one\\ntwo\\nthree', true, -1)<CR>" '<Esc><C-f>' '<C-f>' '<C-b>')
  eq "$(awk '{print $NF}' <<<"$out" | tr '\n' ' ')" "room room room room room " "($(tr '\n' '|' <<<"$out"))"
  # (each step's top line, as the steps change it: the scrolls up must move it)
  cat >"$TMP/scroll.lua" <<'SCROLLLUA'
vim.o.lines = 40; vim.o.columns = 64
local steps, OUT = vim.split(os.getenv("VKEYS"), "|", { plain = true }), os.getenv("VOUT")
kawa_notes_shown(); vim.cmd("redraw")
local dt, rows = {}, {}
local function step(i, t0)
  if i > #steps then
    local pen = ""
    if os.getenv("VDUMP") then   -- (then the pen's line:column and the lines named — where his words went)
      pen = " | " .. vim.fn.line(".") .. ":" .. vim.fn.col(".")
      for n in os.getenv("VDUMP"):gmatch("%d+") do pen = pen .. " " .. n .. "=" .. vim.fn.getline(tonumber(n)) end
    end
    if os.getenv("VMODE") then pen = pen .. " mode=" .. vim.api.nvim_get_mode().mode end   -- (and the mode it ended in)
    local f = io.open(OUT, "w"); f:write(table.concat(dt, " ") .. " | " .. table.concat(rows, " ") .. pen); f:close()
    return vim.cmd("qa!")
  end
  -- (a step "lua:CODE" is a call as kawa-warm makes one, by RPC — no key: never through a
  -- <Cmd> key, which a look would see as a key — the master, verdict 8)
  if steps[i]:sub(1, 4) == "lua:" then assert(loadstring(steps[i]:sub(5)))() else vim.api.nvim_input(steps[i]) end
  vim.defer_fn(function()
    vim.cmd("redraw")
    local t = vim.fn.line("w0")
    if i > 1 then dt[#dt + 1] = t - t0; rows[#rows + 1] = vim.fn.winline() end
    step(i + 1, t)
  end, 250)
end
vim.defer_fn(function() step(1, vim.fn.line("w0")) end, 200)
SCROLLLUA
  scrolls() {   # scrolls FILE KEYS… — the top line's change at each step after the first, then the pen's rows (VDUMP="N …": then the pen and those lines)
    local f=$1; shift
    VKEYS=$(IFS='|'; echo "$*") VOUT=$TMP/scroll.out KAWA_NOTES_WHERE='~/notes/v.md' \
      nvim --headless -n -c 'luafile ~/.config/fedokawaii/notes.lua' -c "luafile $TMP/scroll.lua" -- "$f" >/dev/null 2>&1
    cat "$TMP/scroll.out"
  }
  case_ "notes.lua: a scroll he makes is his — from the foot, Ctrl+Y and the wheel move the page up every time (a line, three a notch), the pen yields into its room; Esc after a wheel up in typing keeps the page where the wheel left it (the master, verdict 4)"
  diary "$TMP/v.md"
  eq "$(scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<Esc><C-y>' '<C-y>' '<C-y>' '<ScrollWheelUp>' '<ScrollWheelUp>' 'i<ScrollWheelUp>' '<Esc>')" \
    "-1 -1 -1 -3 -3 -3 0 | 33 33 33 33 33 33 33"
  case_ "...typing at the foot, a wheel up, Esc: the page stays where the wheel left it, the pen yields into its room (the master, verdict 5's should-fix 3: neovim's own check as typing ends scrolled back)"
  diary "$TMP/v.md"
  eq "$(scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<Esc>')" "-3 0 | 36 33"
  case_ "...a wheel up while typing in a window that has been through normal mode once (the warm window after its first Esc: neovim tells it the wheel), then two keys: they go on his line, the page back to the pen (the master, verdict 6's must-fix 1: the pen walked into line 153 and \"qr\" went there)"
  diary "$TMP/v.md"
  eq "$(VDUMP="156 153" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<Esc>' 'A' '<ScrollWheelUp>' 'q' 'r' '<Esc>')" "0 0 -3 3 0 0 | 33 33 36 33 33 33 | 156:2 156=qr 153=x"
  case_ "...a look of two notches at the foot, then two keys: neovim dragged the cursor along with the page (no key), yet the keys go on his line and the page comes back to the pen (the master, verdict 7's must-fix 1: \"qrx\" on line 150)"
  diary "$TMP/v.md"
  eq "$(VDUMP="156 150" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<ScrollWheelUp>' 'q' 'r' | cut -d'|' -f3)" " 156:3 156=qr 150=x"
  case_ "...one notch mid-page (Ctrl+U, typing at the line there): the keys on that line"
  diary "$TMP/v.md"
  eq "$(VDUMP="137 134" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<Esc>' '<C-u>' 'i' '<ScrollWheelUp>' 'q' 'r' | cut -d'|' -f3)" " 137:3 137=qrx 134=x"
  case_ "...a notch after Esc's yield (typing again at the end of the pen's line): the keys at its end"
  diary "$TMP/v.md"
  eq "$(VDUMP="153 150" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<Esc>' 'A' '<ScrollWheelUp>' 'q' 'r' | cut -d'|' -f3)" " 153:4 153=xqr 150=x"
  case_ "...a look, then Super+N away and back (calls, no key): the look is over — the next keys on the fresh line the page opens on (the master, verdict 8's must-fix 1: \"helloqr\" on 156)"
  diary "$TMP/v.md"
  eq "$(VDUMP="156 157" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))hello" '<ScrollWheelUp>' '<ScrollWheelUp>' 'lua:kawa_notes_hidden()' 'lua:kawa_notes_shown()' 'q' 'r' | cut -d'|' -f3)" " 157:3 156=hello 157=qr"
  case_ "...a look in the to-do, then Super+N away and back: the to-do's place never lands in the notes"
  for i in $(seq 1 45); do echo "[ ] thing $i"; done >"$HOME/notes/todo.md"
  diary "$TMP/v.md"
  eq "$(VDUMP="46 127" scrolls "$TMP/v.md" '<Tab>' 'abc' '<ScrollWheelUp>' '<ScrollWheelUp>' 'lua:kawa_notes_hidden()' 'lua:kawa_notes_shown()' 'q' 'r' | cut -d'|' -f3)" " 127:3 46= 127=qr" "(the notes' line 46 — the item's number in the to-do — untouched; the words on the fresh line)"
  case_ "...a look, then a click: the pen goes where the pointer is — the line the same click picks after the same scroll in normal mode (putting it back first scrolled the page under the pointer: verdict 8's must-fix 2)"
  diary "$TMP/v.md"; look=$(VDUMP="0" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<ScrollWheelUp>' '<ScrollWheelUp>' '<LeftMouse><10,9>' | cut -d'|' -f3)
  diary "$TMP/v.md"; norm=$(VDUMP="0" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<Esc><ScrollWheelUp>' '<ScrollWheelUp>' '<ScrollWheelUp>' '<LeftMouse><10,9>' | cut -d'|' -f3)
  eq "$look" "$norm" "(typing: $look · normal mode: $norm)"
  case_ "...a look, then a click that places no pen — the heading's row (the tabline), the blank row under it (the winbar), the foot's two rows: the pen back, the next key on his line, as with no look (the master, verdict 9's must-fix 1: \"qx\" on 147)"
  for at in '<20,0>' '<20,1>' '<10,38>' '<10,39>'; do
    diary "$TMP/v.md"; look=$(VDUMP="147 156" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<ScrollWheelUp>' '<ScrollWheelUp>' "<LeftMouse>$at" 'q' | cut -d'|' -f3)
    diary "$TMP/v.md"; none=$(VDUMP="147 156" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" "<LeftMouse>$at" 'q' | cut -d'|' -f3)
    eq "$look" " 156:2 147=x 156=q" "a click at $at after a look"; eq "$none" "$look" "(at $at with no look: $none)"
  done
  case_ "...a double and a triple click on the foot (neovim counts them itself: the second press is <2-LeftMouse>) are swallowed too — still typing, nothing selected, the pen where it was; after a look the next key on his line (the master, verdict 10's should-fix 1: Visual mode, his letters commands)"
  dbl='lua:for _ = 1, 2 do vim.api.nvim_input_mouse("left", "press", "", 0, 39, 20); vim.api.nvim_input_mouse("left", "release", "", 0, 39, 20) end'
  tri='lua:for _ = 1, 3 do vim.api.nvim_input_mouse("left", "press", "", 0, 38, 20); vim.api.nvim_input_mouse("left", "release", "", 0, 38, 20) end'
  for c in "$dbl" "$tri"; do
    diary "$TMP/v.md"; eq "$(VMODE=1 VDUMP="156" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" "$c" | cut -d'|' -f3)" " 156:1 156= mode=i" "${c:4:40}… with no look"
    diary "$TMP/v.md"; eq "$(VMODE=1 VDUMP="147 156" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<ScrollWheelUp>' '<ScrollWheelUp>' "$c" 'q' | cut -d'|' -f3)" " 156:2 147=x 156=q mode=i" "${c:4:40}… after a look"
  done
  diary "$TMP/v.md"; got=$(VMODE=1 VDUMP="156" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<Esc>' "$dbl" | cut -d'|' -f3)
  eq "$got" " 156:1 156= mode=n" "(normal mode, no Visual: $got)"
  case_ "...the same in the to-do: a look, a click on the heading, the next key on the item typed"
  for i in $(seq 1 45); do echo "[ ] thing $i"; done >"$HOME/notes/todo.md"
  diary "$TMP/v.md"
  eq "$(VDUMP="40 46" scrolls "$TMP/v.md" '<Tab>' 'abc' '<ScrollWheelUp>' '<ScrollWheelUp>' '<LeftMouse><20,0>' 'q' | cut -d'|' -f3)" " 46:9 40=[ ] thing 40 46=[ ] abcq"
  case_ "...a look, then the middle button (in typing neovim pastes at the cursor, not at the pointer): the words at the pen, as with no look (verdict 9: they went into line 147)"
  clip='lua:vim.g.clipboard = { name = "t", copy = { ["+"] = "cat >/dev/null", ["*"] = "cat >/dev/null" }, paste = { ["+"] = "echo PRIMARY", ["*"] = "echo PRIMARY" } }'
  diary "$TMP/v.md"; look=$(VDUMP="147 156 157" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" "$clip" '<ScrollWheelUp>' '<ScrollWheelUp>' '<ScrollWheelUp>' '<MiddleMouse><10,9>' 'q' | cut -d'|' -f3)
  diary "$TMP/v.md"; none=$(VDUMP="147 156 157" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" "$clip" '<MiddleMouse><10,9>' 'q' | cut -d'|' -f3)
  eq "$look" "$none" "(after a look: $look · with none: $none)"; has "$look" "147=x" "line 147 untouched"; has "$look" "PRIMARY"
  case_ "...a look, a bare pointer move (a plugin may ask for every move one day), then two keys: the look holds through the move, the keys on his line (verdict 9's should-fix 3)"
  diary "$TMP/v.md"
  eq "$(VDUMP="150 156" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<ScrollWheelUp>' 'lua:vim.api.nvim_input_mouse("move", "", "", 0, 10, 20)' 'q' 'r' | cut -d'|' -f3)" " 156:3 150=x 156=qr"
  case_ "...a look, then a paste (foot's is no key — nvim_paste): the text at the pen (verdict 8's must-fix 3: it went into line 150)"
  diary "$TMP/v.md"
  eq "$(VDUMP="150 156 157" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<ScrollWheelUp>' 'lua:vim.api.nvim_paste("one\ntwo", true, -1)' | cut -d'|' -f3)" " 157:4 150=x 156=one 157=two"
  case_ "...a look, then Ctrl+O and a k: from the pen, one line up (the restore's own scroll is no look: verdict 8's should-fix 4)"
  diary "$TMP/v.md"
  eq "$(VDUMP="150 155" scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))" '<ScrollWheelUp>' '<ScrollWheelUp>' '<ScrollWheelUp>' '<C-o>' 'k' 'q' | cut -d'|' -f3)" " 155:2 150=x 155=qx"
  case_ "...typing, a wheel up, then nothing for 1.25 s: the pause's save (a write counts as a change) leaves the page where the wheel left it (the master, verdict 7's should-fix 2)"
  diary "$TMP/v.md"
  eq "$(scrolls "$TMP/v.md" "$(printf 'x<CR>%.0s' $(seq 1 30))z" '<ScrollWheelUp>' '' '' '' '' '' | cut -d'|' -f1)" "-3 0 0 0 0 0 "
  case_ "...typing on a line, a wheel up, Esc: the pen yields up into its room on its own column, as Ctrl+Y's yield keeps it (the master, verdict 6's should-fix 2: Esc's yield put it at the line's start)"
  diary "$TMP/v.md"
  eq "$(VDUMP="152" scrolls "$TMP/v.md" "$(printf 'hello world<CR>%.0s' $(seq 1 29))hello world" '<ScrollWheelUp>' '<Esc>' | cut -d'|' -f3)" " 152:11 152=hello world"
  case_ "...and on a to-do longer than the page (tab, esc, then Ctrl+Y twice): the list moves up each time"
  for i in $(seq 1 45); do echo "[ ] thing $i"; done >"$HOME/notes/todo.md"
  diary "$TMP/v.md"
  eq "$(scrolls "$TMP/v.md" '<Tab>' '<Esc>' '<C-y>' '<C-y>' | cut -d'|' -f1)" "0 -1 -1 "
  case_ "...a line typed in long notes, then tab into that to-do: the pen on the fresh item, the last line, and his words go into it (the master, verdict 5's must-fix 1: the notes' remembered top walked the pen up to item 41)"
  diary "$TMP/v.md"
  eq "$(KAWA_NOTES_WHERE='~/notes/v.md' nvim --headless -n -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'lua
vim.o.lines = 40; vim.o.columns = 64
kawa_notes_shown(); vim.cmd("redraw")
vim.api.nvim_input("a line of today<CR>")
vim.defer_fn(function()
  vim.cmd("redraw")
  vim.api.nvim_input("<Tab>")
  vim.defer_fn(function()
    vim.cmd("redraw")
    local pen = vim.fn.line(".") .. "/" .. vim.fn.line("$")
    vim.api.nvim_input("new one")
    vim.defer_fn(function()
      io.stdout:write(pen .. " " .. vim.fn.getline(46) .. " | " .. vim.fn.getline(41))
      vim.cmd("qa!")
    end, 250)
  end, 250)
end, 250)' -- "$TMP/v.md" 2>/dev/null)" "46/46 [ ] new one | [ ] thing 41"
  case_ "notes.lua: the page moves by lines — smoothscroll off: it cut a wrapped line at the top and drew neovim's <<< over the margin (the master, verdict 3's must-fix 1)"
  { cat "$TMP/v.md"; for i in 1 2 3; do echo "a long line $i that runs well past the right edge of this page and wraps onto a second row, then a third row of paper"; done; } >"$TMP/w2.md"
  eq "$(KAWA_NOTES_WHERE='~/notes/w2.md' nvim --headless -n -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'lua kawa_notes_shown()' \
    -c 'lua vim.cmd("redraw") local t = "" for r = 1, 6 do for c = 1, 64 do t = t .. vim.fn.screenstring(r, c) end end io.stdout:write(tostring(vim.wo.smoothscroll) .. " " .. vim.fn.winsaveview().skipcol .. " " .. tostring(t:find("<<<", 1, true) == nil))' \
    -c 'qa!' -- "$TMP/w2.md" 2>/dev/null)" "false 0 true" "(smoothscroll off, no line cut at the top, no <<< anywhere on the first rows)"
  case_ "notes.lua: a to-do longer than the page — tab opens it with the fresh item and the pen above the floats, three rows of paper ahead; a Return and esc keep it so (the master, 2 Nov: verdict 2's must-fix 2)"
  for i in $(seq 1 45); do echo "[ ] thing $i"; done >"$HOME/notes/todo.md"
  diary "$TMP/v.md"
  eq "$(view "$TMP/v.md" '<Tab>' 'abc<CR>' '<Esc>' | awk '{print $NF}' | tr '\n' ' ')" "room room room "
  case_ "notes.lua: lines typed with Returns each keep their rule — one rule mark a line, the paper's mark of its own (a cleared namespace gave the paper's old id to a rule, and moving the paper took a typed line's rule: the kit's frames, 2 Nov)"
  printf '%s\n' '# notes' '' '## 2026-11-01 · Sun' '' 'buy rice' >"$TMP/r2.md"
  eq "$(KAWA_NOTES_WHERE='~/notes/r2.md' nvim --headless -n -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'lua
kawa_notes_shown()
vim.api.nvim_input("line one<CR>line two<CR>line three<CR>")
vim.defer_fn(function()
  local ns, per = vim.api.nvim_get_namespaces().kawa_rules, {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    if m[4].line_hl_group then per[m[2]] = (per[m[2]] or 0) + 1 end
  end
  local bad = {}
  for r = 0, vim.api.nvim_buf_line_count(0) - 1 do if per[r] ~= 1 then bad[#bad + 1] = (r + 1) .. ":" .. (per[r] or 0) end end
  io.stdout:write(#bad == 0 and "every line ruled once" or table.concat(bad, " "))
  vim.cmd("qa!")
end, 400)' -- "$TMP/r2.md" 2>/dev/null)" "every line ruled once"
  case_ "notes.lua: a line changed in place (the count the same) is laid again: a day's line typed on at its end — its date's ink to the new end; a line made a day's line gets its marks, a day's line made words loses them (the master, verdict 1's should-fix 3)"
  printf '%s\n' '# notes' '' '## 2026-11-01 · Sun' '' 'plain words' '## 2026-11-02 · Mon' >"$TMP/i.md"
  eq "$(nvim --headless -n -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'lua
local ns = vim.api.nvim_get_namespaces().kawa_rules
local function day(r) local e = "-" for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, { r, 0 }, { r, -1 }, { details = true })) do if m[4].hl_group == "KawaDay" then e = m[4].end_col end end return e end
local function at(r, keys) vim.api.nvim_win_set_cursor(0, { r + 1, 0 }) vim.api.nvim_feedkeys(vim.keycode(keys), "tx", false) vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 }) end
at(2, "A, the first<Esc>"); local a = day(2) .. "/" .. #vim.fn.getline(3)
at(4, "cc## 2026-11-03 · Tue<Esc>"); local b = day(4)
at(5, "ccwords now<Esc>"); local c = day(5)
io.stdout:write(a .. " " .. b .. " " .. c)' -c 'qa!' -- "$TMP/i.md" 2>/dev/null)" "31/31 20 -" "(the date's ink to the new end; a new day's line marked; an old one unmarked)"
  case_ "notes.lua: nothing written over the footer while typing (no mode, no keys, no 'written')"
  eq "$(ask '{vim.o.showmode, vim.o.showcmd, vim.o.ruler}')" "{ false, false, false }"
  has "$(ask vim.o.shortmess)" "WFcsS"
  case_ "notes.lua: neovim's ui2 on — with the old message grid each save blanked the footer for a frame (seen 1 Nov); the installed neovim must have it (an update that drops it is caught here)"
  eq "$(nvim --headless -c 'lua io.stdout:write(tostring((pcall(require, "vim._core.ui2"))))' -c 'qa!' 2>/dev/null)" true "vim._core.ui2 in this neovim"
  eq "$(ask 'package.loaded["vim._core.ui2"] ~= nil')" true "enabled by notes.lua"
  case_ "the clipboard (owner 14:27, copy/paste): y copies to the desktop's; x, dd, cw keep what they take in the editor — the desktop's copy and Super+V's history untouched; p puts in the newest copy, the desktop's when one came since, else the editor's (dd then p moves a line)"
  clip() {   # clip KEYS… — typed into a page of three lines, with a clipboard of its own ("from the browser"): the desktop's clipboard, then the page
    local a=() k
    for k; do a+=(-c "$k"); done
    nvim --headless -c 'lua vim.g.clipboard = { name = "test", cache_enabled = 0,
        copy = { ["+"] = function(l, t) vim.g.plus = { l, t } end, ["*"] = function(l, t) vim.g.plus = { l, t } end },
        paste = { ["+"] = function() return vim.g.plus end, ["*"] = function() return vim.g.plus end } }
        vim.g.plus = { { "from the browser" }, "v" }' \
      -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'lua vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first line", "second line", "third line" })' \
      "${a[@]}" \
      -c 'lua io.stdout:write(table.concat(vim.g.plus[1], "|") .. " / " .. table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "|"))' -c 'qa!' -- "$TMP/c.md" 2>/dev/null
  }
  eq "$(clip 'normal dd' 'normal x')" "from the browser / econd line|third line" "dd and x: the desktop's copy kept"
  eq "$(clip 'normal dd' 'normal p')" "from the browser / sfrom the browserecond line|third line" "p after a copy elsewhere: that copy (a line's part: put in after the cursor)"
  eq "$(clip 'normal yy' 'normal jdd' 'normal p')" "first line| / first line|third line|second line" "yy: to the desktop (a whole line: its end with it); dd then p: the line moved (the editor's own)"
  eq "$(clip 'normal yy' 'normal "+p')" "first line| / first line|first line|second line|third line" '"+p: the desktop'"'"'s, as asked'
  has "$(cat "$REPO/configs/home/.config/nvim/lua/config/options.lua")" 'require("config.clipboard").setup()' "the editor the same"
  case_ "notes.lua: writes without waiting for the disk"
  eq "$(ask '{vim.o.fsync}')" "{ false }"
  hl() { nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' \
    -c "lua local h = vim.api.nvim_get_hl(0, {name='$1'}); io.stdout:write(string.format('%06x %06x', h.fg or 0, h.bg or 0))" \
    -c 'qa!' -- "$TMP/n.md" 2>/dev/null; }
  case_ "notes.lua: the theme's inks — the kanji accent_text, the name text, the stitch edge2, the footer muted, on the ground"
  ink() { sed -n "s/^C_$2=\([0-9a-f]*\).*/\1/p" "$HOME/.config/fedokawaii/themes/$1/colors.sh"; }   # ink THEME NAME
  eq "$(hl KawaIcon)" "$(ink dark ACCENT_TEXT) $(ink dark GROUND)"; eq "$(hl KawaName)" "$(ink dark TEXT) $(ink dark GROUND)"
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
  setup; rm -f "$STUBS/nvim"; config .config/fedokawaii/notes.lua; config .config/nvim/lua/config/clipboard.lua
  stub nvim "exec '$REAL_NVIM' --clean \"\$@\""
  mkdir -p "${N%/*}"; printf '%s\n\n' "$H" >"$N"
  python3 -I "$REPO/tests/lib/pty_run.py" --timeout 20 --answer 'saved as you go' 'hello world' --hangup +1.6 -- kawa-notes --inside --shown >/dev/null
  eq "$(cat "$N")" "$H"$'\n\nhello world'
  case_ "...and the next Super+N asks nothing about a swap file"
  out=$(python3 -I "$REPO/tests/lib/pty_run.py" --timeout 20 --answer 'saved as you go' '' --hangup +0.3 -- kawa-notes --inside --shown | tr -d '\0')
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
    out=$(python3 -I "$REPO/tests/lib/pty_run.py" --timeout 20 --answer 'saved as you go' 'hello' --hangup +3 -- kawa-notes --inside --shown | tr -d '\0')
    wait "$bg"
    eq "$(cat "$N")" "$H"$'\n\nfirst\nhello world\nfrom the phone'
    lacks "$out" "really want to write"; lacks "$out" "changed since"
  done
  case_ "notes deleted elsewhere while open: the page stays, the next key writes it back"
  printf '%s\n\nfirst\n' "$H" >"$N"
  elsewhere 'rm "$N"' & bg=$!
  out=$(python3 -I "$REPO/tests/lib/pty_run.py" --timeout 20 --answer 'saved as you go' 'hello' --hangup +3 -- kawa-notes --inside --shown | tr -d '\0')
  wait "$bg"
  eq "$(cat "$N" 2>/dev/null)" "$H"$'\n\nfirst\nhello world'; lacks "$out" "really want to write"
  case_ "another file opened in the window (:e ~/notes/trip.md): a page too — its name in the footer, saved as you go"
  printf '%s\n\nfirst\n' "$H" >"$N"
  ( for _ in {1..200}; do [[ -S $XDG_RUNTIME_DIR/kawa-notes.nvim ]] && break; sleep 0.05; done; sleep 0.5
    "$REAL_NVIM" --server "$XDG_RUNTIME_DIR/kawa-notes.nvim" --remote-send '<Esc>:e ~/notes/trip.md<CR>ibuy a SIM card' ) & bg=$!
  out=$(python3 -I "$REPO/tests/lib/pty_run.py" --timeout 20 --answer 'saved as you go' '' --hangup +2.5 -- kawa-notes --inside --shown | tr -d '\0')
  wait "$bg"
  eq "$(cat "$HOME/notes/trip.md" 2>&1)" "buy a SIM card" "(closed by Super+Q: nothing lost)"
  eq "$(cat "$N")" "$H"$'\n\nfirst' "(the notes as they were)"
  out=$(nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' -c 'e ~/notes/trip.md' \
    -c "lua io.stdout:write(vim.inspect({vim.api.nvim_eval_statusline(vim.o.tabline, {use_tabline = true}).str, (function() local t = {} for _, w in ipairs(vim.api.nvim_list_wins()) do local c = vim.api.nvim_win_get_config(w) if c.relative ~= \"\" then t[#t + 1] = (vim.o.lines - c.row) .. \":\" .. vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] end end table.sort(t) return t end)(), vim.wo.number, vim.wo.foldcolumn, vim.wo.wrap}))" \
    -c 'qa!' -- "$N" 2>/dev/null)
  has "$out" "  $ICON_NOTE  notes ───"; has "$out" "  ~/notes/trip.md  ·  saved as you go"; has "$out" 'false, "0", true }'
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
  out=$(python3 -I "$REPO/tests/lib/pty_run.py" --timeout 20 --answer 'saved as you go' 'hello' --hangup +3 -- kawa-notes --inside --shown | tr -d '\0')
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

  # the to-do beside the notes (owner 18:48): the page drawn from ~/notes/todo.md, its keys
  todo_steps() {   # todo_steps — the steps, one line of what each shows
    cat >"$TMP/todo.lua" <<'TODOLUA'
local function out(s) io.stdout:write(s .. "\n") end
local function lines() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "|") end
local function keys(k) vim.api.nvim_feedkeys(vim.keycode(k), "tx", false) end
local ns = vim.api.nvim_create_namespace("kawa_todo")
local function marks()
  local t = {}
  for _, x in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    local vt = x[4].virt_text
    t[#t + 1] = (vt and (vt[1][1] .. vt[1][2] .. "+" .. #vt[2][1] .. "@" .. x[2] .. "." .. x[3]) or (x[4].hl_group .. "@" .. x[2] .. "." .. x[3] .. "-" .. x[4].end_col))
  end
  return table.concat(t, " ")
end
local function changed() vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 }) end
local function foot() return table.concat(vim.tbl_map(function(w) return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1] end, vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" end, vim.api.nvim_list_wins())), "") end
local function at() local r, c = unpack(vim.api.nvim_win_get_cursor(0)); return r .. "," .. c .. " " .. vim.api.nvim_get_mode().mode end
-- (keys() ends typing when its keys run out, as :normal does: what is seen while typing is taken inside the keys)
_G.seen = function(label) out(label .. ": " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") .. " " .. lines() .. " " .. marks() .. " " .. at() .. " " .. foot()) end
kawa_notes_shown()
keys("<Tab><Cmd>lua seen('first')<CR>buy rice<CR>call the bank<Esc>"); changed()
out("typed: " .. lines() .. " " .. marks())
keys("<Space>"); changed()
out("ticked: " .. lines() .. " " .. marks())
keys("<Space>"); changed(); out("unticked: " .. lines()); keys("<Space>"); changed()
keys("gg0"); vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
out("the cursor never on the box: " .. vim.inspect(vim.api.nvim_win_get_cursor(0)))
keys("A<BS><BS><BS><BS><BS><BS><BS><BS><BS><BS>tea<Esc>")
out("backspace stops at the box: " .. lines())
keys("A<CR><CR>"); out("enter on an empty one ends the list: " .. lines() .. " " .. vim.api.nvim_get_mode().mode)
keys("Go<BS>!<Esc>"); out("backspace on an empty one: " .. lines())
keys("ggA ou<Left><Left><CR><Esc>"); out("enter mid-words: " .. lines())
out("heading: " .. vim.o.tabline)
out("footer: " .. foot())
local function page() return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") end
keys("<Tab>"); out("tab: " .. page() .. " at the end: " .. tostring(vim.api.nvim_win_get_cursor(0)[1] == vim.api.nvim_buf_line_count(0)))
keys("<Esc><Tab><Cmd>lua seen('reopened')<CR>")
out("left: " .. lines() .. " " .. at() .. " " .. foot())
keys("A<Tab>"); out("typing on the to-do, tab turns it: " .. page())
keys("A<Tab>"); local to = page(); keys("<Tab>")
out("typing on the notes, tab turns it: " .. to .. ", the notes keep no tab: " .. tostring(not lines():find("\t")))
keys("<Tab>")
keys("o"); kawa_notes_hidden()
TODOLUA
    nvim --headless -n -c 'luafile ~/.config/fedokawaii/notes.lua' -c "luafile $TMP/todo.lua" -c 'qa!' -- "$N" 2>&1
  }
  case_ "the to-do: tab from the notes (its only way in) — it opens typing on a fresh item (the first key a word, never a command: the master, 2 Nov), a box drawn over each item's [ ] (its words two columns after it), the footer naming the keys of the moment"
  setup; rm -f "$STUBS/nvim"; config .config/fedokawaii/notes.lua; config .config/nvim/lua/config/clipboard.lua
  stub nvim "exec '$REAL_NVIM' --clean \"\$@\""
  out=$(todo_steps)
  has "$out" "first: todo.md [ ]  ${ICON_BOX_OFF}KawaIcon+3@0.0 1,4 i   ~/notes/todo.md  ·  esc: the list  ·  tab: the notes" "(empty: one item, its box, typing)"
  has "$out" "typed: [ ] buy rice|[ ] call the bank ${ICON_BOX_OFF}KawaIcon+3@0.0 ${ICON_BOX_OFF}KawaIcon+3@1.0"
  case_ "...space ticks: the box filled and muted, the words muted and struck through (KawaDone); space again unticks"
  has "$out" "ticked: [ ] buy rice|[x] call the bank ${ICON_BOX_OFF}KawaIcon+3@0.0 ${ICON_BOX_ON}KawaMuted+3@1.0 KawaDone@1.4-17"
  has "$out" "unticked: [ ] buy rice|[ ] call the bank"
  eq "$(nvim --headless -c 'luafile ~/.config/fedokawaii/notes.lua' -c "lua local h = vim.api.nvim_get_hl(0, {name='KawaDone'}); io.stdout:write(string.format('%06x %s', h.fg, tostring(h.strikethrough)))" -c 'qa!' -- "$TMP/n.md" 2>/dev/null)" \
     "$(sed -n 's/^C_MUTED=\([0-9a-f]*\).*/\1/p' "$HOME/.config/fedokawaii/themes/dark/colors.sh") true"
  case_ "...the keys: the cursor never on the box, backspace never into it, enter on an empty item ends the list, enter mid-words takes them along"
  has "$out" "the cursor never on the box: { 1, 4 }"
  has "$out" "backspace stops at the box: [ ] tea|[x] call the bank"
  has "$out" "enter on an empty one ends the list: [ ] tea|[x] call the bank n"
  has "$out" "backspace on an empty one: [ ] tea|[x] call the bank!"
  has "$out" "enter mid-words: [ ] tea|[ ] ou|[x] call the bank!" "(no space left either side of the cut)"
  case_ "...its heading (the tanzaku, to-do, the rule) and footer; tab turns to the notes and back"
  has "$out" "heading: %#KawaGround#  %#KawaIcon#$ICON_TODO%#KawaGround#  %#KawaName#to-do %#KawaStitch#───"
  has "$out" "footer:   ~/notes/todo.md  ·  space ticks  ·  tab: the notes"
  has "$out" "tab: notes.md at the end: true" "(the notes again at their end, as they open)"
  case_ "...with items it opens the same: a fresh one at the end, typing; esc gives the list — the fresh one, left with no words, gone — and the footer's keys change with it"
  has "$out" "reopened: todo.md [ ] tea|[ ] ou|[x] call the bank!|[ ]  ${ICON_BOX_OFF}KawaIcon+3@0.0 ${ICON_BOX_OFF}KawaIcon+3@1.0 ${ICON_BOX_ON}KawaMuted+3@2.0 KawaDone@2.4-18 ${ICON_BOX_OFF}KawaIcon+3@3.0 4,4 i   ~/notes/todo.md  ·  esc: the list  ·  tab: the notes"
  has "$out" "left: [ ] tea|[ ] ou|[x] call the bank! 3,4 n   ~/notes/todo.md  ·  space ticks  ·  tab: the notes"
  has "$out" "typing on the to-do, tab turns it: notes.md"
  has "$out" "typing on the notes, tab turns it: todo.md, the notes keep no tab: true" "(the notes open typing: a tab there turns the page, never goes into the text)"
  case_ "...saved as you go, an item left empty tidied away as the window goes"
  eq "$(cat "$HOME/notes/todo.md")" $'[ ] tea\n[ ] ou\n[x] call the bank!'
  ours
fi

case_ "kawa-notes --todo is gone (the to-do's only way in is tab, in Super+N — owner 1 Nov 22:27): a misuse, nothing shown"
setup; kawa-notes --todo 2>/dev/null; eq "$?" 2; not_called 'kawa-warm'

done_
