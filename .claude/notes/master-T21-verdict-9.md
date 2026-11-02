VERDICT: FAIL
(the master, T21 re-review 9 — 2026-11-02 17:32 +04, narrow: verdict 8's findings and what 4c8de66 could have disturbed. Reviewed:
4c8de66's notes.lua and test_notes.sh (= HEAD 7246d44 = the working tree, cmp'd), the 4c8de66 diff, docs/design-system.md §7 (3651d15),
the ledger's r27-21-master-8-fix line. Probes in throw-away homes under /dev/shm/r27/master/T21/own/ (home-a/b/c/d/f/h3 = the r7/r8
homes with HEAD's lua, the stub kawa-notes really tidying on --tidy; home-x = b583de2's lua for the "old" comparisons — r9a had left
HEAD's lua in it, so its "-old" logs were not b583de2's and were not used); nvim v0.12.6; EVERY run under `env -u WAYLAND_DISPLAY -u
DISPLAY DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent XDG_RUNTIME_DIR=own/xdg|run`, nothing of his touched. All logs re-run by me
(the r9a archive's were only compared against): H-series 32 (probe/run-h-r7.sh → H*-r9b.log), R-series 41 (run-r8.sh, p13 →
R*/RX*-r9b.log), RN-series 26 + 3 (run-rn.sh, run-rn2.sh, p14 → RN*-r9b.log, RN2b/2c/2e-r9.log, RN2b-old.log), PT-series 14 in a REAL
PTY (run-pt.sh, pty-play.py + ptytap.lua: nvim's own TUI, TERM=xterm-256color, SGR mouse, bracketed paste, focus in/out → PT*-r9b.log),
my own N-series 19 (run-r9new.sh, p15 = p14 + clicks at a given grid row/col, side buttons, wheel left/right → N*-r9b.log, N1/N5-old.log),
PTN1/PTN2 (the tabline/winbar click in the pty), PTK1-r9b/-old (the pause's save during a look, in the pty), pty-1003.py (nvim's mouse
mode request), the repo's tests/content/test_notes.sh → test_notes-r9.log. Evidence is nvim's own top/row/line/col, buffer text and
events; no kit render. Running notes: own/progress.md.)

## Verified (held)
- Verdict 8's must-fix 1, on HEAD: two notches, hidden and shown by a Lua call (as kawa-warm's --remote-expr), "qr" → `L157 |qr|`, 156
  kept (R8: `L156 ||`; RN8a: `L156 |hello|`, `L157 |qr|`; r8 had `L156 |qr|`); from the to-do (Tab, "abc", two notches, hidden, shown,
  "qr") → `L157 |qr|`, the notes' 45–47 untouched (R8b; r8: `L46 |qr|`, top 28); shown with no hide (R8c, H8a, H8b) → `L157 |qr|`
  (verdict 7's values back); focus lost, hidden, shown, focus gained (R9b) → `L157 |qr|`; the autosave firing while hidden (N7: "z",
  two notches, hidden, 1.3 s, shown, "qr") → `L156 |z|`, `L157 |qr|`. The rows call the functions ("lua:" steps), as asked.
- Must-fix 2: three notches at the foot (top 115, the cursor dragged to 147), a click on grid row 10 → line 123, the line the same click
  picks in normal mode (R4 vs R4d; the row: "122:1" both); mid-page one notch → 110, where the pointer was (R4c); one notch at the foot
  unchanged (R4b: 129); two notches then the click (RN9) → `L126 |xq|` = the same in nvim's real TUI (PT5: `L126 |xq|`) = normal mode
  (PT5n: `L126 |qx|`). Clicks on the margin columns (N3/N3b) and the side buttons (N5/N5b: X1/X2) place the cursor too (123).
- Must-fix 3: two notches, then nvim_paste "one\ntwo" → `L156 |one|`, `L157 |two|`, `L150 |x|` (R17; r8: 150/151); in the real TUI a
  bracketed paste (PT2: one call, phase -1, "before: top 118 line 150 → after: line 157") → one/two on 156/157; streamed phases 1-2-3
  (PT3, RN5) → one/two/three on 156–158; replace mode, the pen on 155 (RN13) → `L155 |ab|`; `u` after it takes the paste whole (RN14,
  PT10: n 156); in the to-do (N8) → `L46 |[ ] abcdef|`. The no-look pastes unchanged (RN6, RN6b, RN6c, RN6d, RN6e: `L156 |zzzz|` by `.`).
- Should-fix 4: three notches, `<C-o>` → the pen back on 156 with the page (top 124), `k` → 155, "q" → `L155 |qx|` (R11; r8: 150);
  `<C-o> dd` takes the pen's own line (RN10: n 155, 150–155 intact).
- Should-fix 5: §7 carries the look (3651d15) — but see should-fix 2. Nits 6–8: the comment says the undo split and the completion's end
  (notes.lua 382–384; RN15/R14 unchanged: `L156 |hello |`); Ctrl-C's proof named as the pty's; a real Ctrl-C in the pty (PT4: `key <Esc>
  (typed <C-C>)`, InsertLeave) = Esc (PT4e) → `L150 |qx|` after `iq` (the yield's line, as designed).
- No regression found around the fix: the 32 H, 41 R and 26 RN scenarios are byte-identical to r9a's runs; against r8's logs only the
  five fixed scenarios changed their text (above); H10/H11a/H16/H6/H23, R1/R3/R7/R7c/R20/R25/R25b/RX6 differ in the pushes count or the
  view alone (the put-back now brings the page to the pen: top 124 instead of 123/121), the text the same. The look survives a focus
  change in the real TUI (PT1: FocusLost/FocusGained during the look, then "qr" → `L156 |qr|`; RN7/RN7b by autocmd, with the autosave
  between: `L156 |zqr|`), a resize (RN8 → `L156 |q|`), the pause's save IN THE REAL TUI (PTK1: "z", two notches, 1.6 s — BufWritePost
  at top 118 line 150, no event key through on_key, the page unmoved — then "qr" → `L156 |zqr|`, the page back on the q; b583de2 the
  same), a horizontal notch (N6/N6b: ScrollWheelLeft/Right keep it → `L156 |q|`), Ctrl-O then a wheel (N10 → `L156 |q|`), Tab round
  trips (RN11/RN12 → `L156 |qr|`), a look in the to-do then a click (RN12b: item 16, where it points), the to-do's Enter/Backspace
  (R7/R7b), completion (R14/R14b/RN15), replace mode (R13), the short page (R23). v:errmsg empty and both on_key callbacks alive at
  every MSGS (the one E353 is nvim's own: a middle click on an empty register, below).
- tests/content/test_notes.sh on HEAD, my run: 153 passed, 0 failed, rc 0 (own/test_notes-r9.log).

## Must-fix
1. A mouse key that places no pen ends the look without the put-back, and his next key lands in the older line neovim dragged the
   cursor to — verdict 7's bug again, by the mouse. notes.lua 400 drops `look` for any key named Mouse/Drag/Release and trusts the
   click to place the pen; a click on the heading row (the tabline) or the blank row under it (the winbar) places nothing, and so does a
   middle click (in typing nvim pastes the primary selection AT THE CURSOR, not at the pointer — RN2c with no look: the click on row 10,
   "PRIMARY" on 156 — or raises E353 when it is empty and moves nothing). Reproductions (the diary, 30 × "x<CR>" at the end: the pen on
   156, top 124; Esc, A):
   - three notches (top 115, the cursor dragged to 147, row 33), a LEFT CLICK ON THE TABLINE (grid row 0, col 20): "after CLICKAT 0 20
     top 115 row 33 line 147 col 0 mode i" (nothing moved), then "q" → `L147 |qx|`, `L156 ||` (N1-r9b.log); the winbar (grid row 1):
     the same (N2); ten notches → `L126 |qx|` beside "already written today", 156 empty (N1b); in nvim's REAL TUI the same three notches
     and an SGR click on row 1 or 2 (`\x1b[<0;20;1M`/`m`) → `key <LeftMouse> … top 115 row 33 line 147`, "q" → `L147 |qx|` (PTN1,
     PTN2). On b583de2 the same click → "top 124 row 33 line 156 … pushes 11", "q" → `L156 |q|` (N1-old): a regression of 4c8de66.
     The control with no look (N11): `L156 |q|`. The to-do: Tab, "abc" (item 46), two notches (dragged to item 40), the tabline click,
     "q" → `L40 |[ ] thiqng 40|`, `L46 |[ ] abc|` (N9).
   - three notches, a MIDDLE CLICK with a primary selection (vim.g.clipboard whose * holds "PRIMARY"): `L147 |PRIMARY|`, then "q" →
     `L148 |qx|` (RN2b-r9.log: the words of the clipboard in day 30's lines); b583de2: `L156 |PRIMARY|`, `L157 |q|` (RN2b-old); with no
     look: `L156 |PRIMARY|`, `L157 |q|` (RN2c). An empty primary: E353, nothing moves, "q" into 147 (RN2) / 150 (PT7, the real TUI).
   A click on the heading to bring the window back after a look is an everyday gesture; a middle-click paste belongs on his line. End
   the look only once the mouse key has placed the pen (the cursor moved by the click, or getmousepos() on a text row of the page);
   a mouse key that placed nothing must leave the look in place (the next key then puts the pen back) or put it back itself. Rows: a
   tabline click and a winbar click after three notches, then "q" → `156:2 156=q` (as the scrolls harness prints), the same in the
   to-do (`46:… 46=[ ] abcq`), and a middle click with vim.g.clipboard holding words → the words on 156, the next key after them.

## Should-fix
2. §7 (docs/design-system.md 406–408) says "the next key — any: a letter, Return, Backspace, an arrow — acts from the pen, the page back
   to it (Esc ends the look where the page is)". Written at 15:36, before 4c8de66 changed the rule at 15:53: a click now ends the look
   where it points (not from the pen), a paste acts from the pen, and Super+N (shown, hidden) and the page turned end it. The single
   truth should say the three in one sentence — with must-fix 1's rule as it ends up.
3. The on_key rule decides by the key's NAME ("Mouse"): a bare pointer move would end the look too — RN16 and PT12 (two notches, a
   `<MouseMove>`, "qr") → `L150 |qrx|`. Latent today: nvim's TUI asks for ?1002h, not ?1003h (pty-1003.py: `[?1002h YES`, `[?1003h no`),
   so foot sends no motion without a button; 'mousemoveevent' on — a plugin, a future default — would make it live. Deciding by the
   pen's placement (must-fix 1) closes it; say so in the comment.

## Nits
4. The commit, the ledger (r27-21-master-8-fix) and the comment at notes.lua 385–386 say "a mouse key ends it where it points (no
   put-back)": true only of a key that points at the page's text. Fix the words with the rule.
5. A click on the footer's rows (grid rows 38/39) falls through the non-focusable floats to the lines under them: the pen lands on a
   hidden line and pen_room scrolls five lines (N4: `L152 |xq|`, top 115 → 120) — the same with or without a look, pre-existing, out of
   this review; worth a row of its own some day (a click on the footer should place nothing).
6. Headless rows cannot hold a right click or a double click: both wait for input (the popup menu; `q` after a word selection waits for
   a register) and the 90 s timeout killed nvim (RN1/RN4: "Caught deadly signal SIGTERM"); their evidence is the real pty (PT6: the right
   click places the cursor where it points, 126; PT9: the double click selects the word, nvim's own). Write such rows against a pty.
7. r9a's last chase (E803 "ID not found: 1000" in v:errmsg after a `:lua D()` in the pty): not 4c8de66's; with plain `:echo` commands
   around an insert nothing is raised or drawn (e803-cap.bin, the TUI's bytes); seen only after the probes' own `:lua D()` calls. Dropped.
