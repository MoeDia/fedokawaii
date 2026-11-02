VERDICT: FAIL
(the master, T21 re-review 2 — 2026-11-02 12:05 +04, checkout /dev/shm/r27w-suite-2939cc8 = main 2939cc8; own renders, probes and
logs in /dev/shm/r27/master/T21/own/: measure.log, c/*.png (kit, dark), probe/*.lua + home/ (headless, a throw-away home))

## Verified (held)
- Geometry, every render of the evidence re-measured (own/measure.log; both themes; sf-*-open/todo/list, regress-*-cold/typed):
  heading rule abs y 161, x 792–1215; 36 page rules at y 210 + 20k (each cell's 19th px), x 736–1215 — ONE right edge with the
  heading; the margin rule x 723 in ACCENT, rows 2–37; the winbar row blank; the foot's float row blank; the footer's ink from
  crop x 25 (two columns in) in MUTED. Inks = colors.sh: text #e7cfa1 / #122625, rules #3c2f22 / #d7bc8c, day lines
  ACCENT_TEXT (#f47b58 / #a84222), footer #cab596 / #586459; the to-do's box-off in ACCENT_TEXT, box-on and the done words in
  MUTED, the strike on text row 11 of 18 (the x-height centre); the box 10 px (crop x 44–53) on the cap band (y 5–14 against
  caps 4–15), the words at col 6. Identical to verdict 1's numbers to the pixel.
- Must-fix 1 (typed text shown as typed, after a reload too): page() → plain(b) (tree-sitter stopped, syntax OFF) and the same on
  FileChangedShellPost (bugB-events.log: the reload's FileType restarts tree-sitter). Own probe (probe/p5.lua): ts_active=false,
  syntax=OFF, conceallevel 2, the paper on the last line — at open, after :e!, after :e, after :e other.md. The test rows (c2.md,
  r.md) fail on the old notes.lua (test_notes-on-HEAD-notes.lua.log). Held.
- Must-fix 2 (the notes' cold start on a written day): regress-dark/light-cold.png — "2026-10-30 · Day" on the first text row,
  the pen on row 9 under "already written today", 28 ruled rows ahead; the cold scene in tools/regress/notes-page.sh (rc 0,
  regress-final.log); the w.md row. Held — for the notes (see must-fix 1 and 2 below for the same symptom elsewhere).
- The dwl fix: applyrules() runs at the xdg surface's first commit and at its map (the built tree, dwl.c:1381 and :2781); the
  press is now consumed only when client_surface(c)->mapped (true inside mapnotify: wlroots sets mapped before emitting map,
  never at the initial commit). A press between the first commit and the map toggles warmpend.want (warmclient() finds nothing
  until the map) → parked, as warm()'s comment promises; the first commit's setmon is undone by upstream's setmon(c, NULL, 0);
  nothing maps twice; no X11 warm windows. Evidence: cold-press-new-dwl.png (the 80 × 25 page at 631,294–1288,809, ruled) vs
  cold-press-old-dwl.png (nothing). test_warm 90/0.
- Bug A: pen_room() asks winline() before winsaveview() (notes.lua:245). Bug B: plain() on FileChangedShellPost + the r.md row.
  Bug C: the paper's mark at the line's END (lay(), notes.lua:224) keeps it with a line split at the end; the e.md row fails
  with the mark at the start (test_notes-paper-at-line-start.log) — but it is the split path only (must-fix 1 below).
- Should-fix 4, on the merits: ACCEPTED. The rule "the latest day line that leaves the pen ROOM rows above it, on the first
  row; never mid-day; a day too long for the page as the pen needs" keeps scrolloff whole, needs no window-local tricks, and
  the owner's words (margins constant, nothing jumping) are better served than by my literal ask. Renders: sf-*-open (yesterday
  on top, today's line mid-page, the pen on row 9); own probe/p3 (a 40-line today: pen on row 33 of 38 = winheight − ROOM, the
  page inside today). The test rows d/d3/d2 check getline("w0") and the pen's rows, and fail on the old lua.
- Should-fix 5 on a list shorter than the page: sf-*-todo.png — a fresh "[ ] " item at the end, the bar cursor at the words'
  column, footer "esc: the list"; sf-*-list.png — esc: the empty item gone, the block cursor on the first letter of the last
  item, footer "space ticks"; the reopened/left/tab rows. Held for short lists only (must-fix 2).
- test_notes 125/0 and test_warm 90/0 on the checkout (the author's logs); the suite on 2939cc8 was 45 files in with no failure
  when this was written (12:02) — the verdict does not rest on it.

## Must-fix
1. Any new last line made BELOW the paper — everything except a split of the old last line — jumps the page and puts the pen
   under the floats, and the page stays wrong while he types. Kit (own/c, dark, the 30-day diary, after `Esc` `o`): after-o.png —
   the page jumped seven days up (row 2 blank, "2026-10-23 · Day" on row 3, "already written today" on row 37), the new line
   under the floats, the cursor drawn through the footer; after-o-typed.png — "typed after o" is invisible (under the floats)
   while typed; after-o-return.png — a Return does not recover it ("a line typed at the end" on row 37, the typed line still
   under the blank float). Headless (probe/p1b.lua, long.md, topline 119 before): `<Esc>o`, `<Esc>yyp`, `<Esc>Go`, `<C-o>o`,
   `:$put` all give topline 90 with screen row 3 drawn blank; `<CR>` and `x<CR>` at the end (bug C's split) stay at 119.
   Cause: the 40 virt_lines hang on the last line (lay(), notes.lua:218–225); `o`, `p`, `:put` append a line after it (the mark
   stays), the command's own update_topline sees the pen 40 rows below and scrolls to it, and only then TextChanged's rule()
   moves the paper — moving an extmark does not invalidate the window's topline, so the stale view is drawn and kept until the
   cursor changes line (the same mechanism as bug A's "stale view" and verdict 1's must-fix 2). Root fix: lay the paper inside
   the change, before the cursor moves — `nvim_buf_attach(b, false, { on_lines = … })` moving the paper's mark to the new last
   line synchronously (verify the marktree order for `o` and `p` with the probe's keys) — and after any lay that moved the
   paper, re-validate the view (pen_room(), or winrestview with the topline that keeps the pen's room). Tests: the probe's key
   list as headless rows (topline unchanged ± 1, the pen ≤ winheight − ROOM), failing on 2939cc8; an `Esc` `o` and a `yyp` step
   in tools/regress/notes-page.sh's typing play (its frame check already catches the jump).
2. The same root in the to-do's own code: a list longer than the page opens, and goes on, with the pen under the footer.
   todo_open() (notes.lua:535–540) calls new_item() — set_lines, then nvim_win_set_cursor (update_topline with the paper still
   above the new line) — and rule(todo) only after; kawa_todo.enter() (483–493) the same, its lay left to TextChangedI.
   Kit (own/c, 45 items): todo-long.png — items 9–44 on rows 2–37, item 45 under the blank float, the fresh "[ ] " and the pen
   under the footer (zoom-todo-long-footer.png: the bar cursor drawn through the footer under "Notes"); todo-enter.png — after
   "new item" + Return: "new item" under the blank float, the next fresh item under the footer; todo-list.png — after esc: the
   item he just typed and the cursor under the blank float. Headless (probe/p2.lua, p2b.lua): winline 38 of 38 after todo_open
   and after enter; 37 after esc. Fix: rule(todo) before the cursor is set (new_item/todo_open/enter), or must-fix 1's on_lines
   lay, then pen_room() (the to-do relies on scrolloff alone, which a stale topline defeats); tests: a headless row (winline()
   ≤ winheight(0) − ROOM after todo_open and after enter on 45 items, failing on 2939cc8) and a 45-item scene in
   tools/regress/notes-page.sh (tab → the fresh item on a ruled row with three rows of paper ahead; Return; esc).

## Should-fix
3. Should-fix 3 (a same-count change re-lays the typed line) has no test row — grep "in place|re-laid|same count" in
   tests/content/test_notes.sh finds none. Add one that fails on 42892e1's notes.lua: "## 2026-11-01 · Sun" typed on at its
   end (the KawaDay mark's end_col follows), and a line changed into / out of a day line in place (its marks come and go).
4. The must-fixes need their never-again checks in the same commit (CLAUDE.md "Never again"): the key list of must-fix 1 and the
   45-item scene of must-fix 2 — headless rows and kit steps — and §7's "the pen keeps three ruled rows of fresh paper ahead of
   it" must then hold for `o`, `p`, `:put` and the to-do's Return, not only for typing.

## Nits
5. `shown` (notes.lua:371, written at 383 and 393) is never read — dead state.
6. tools/regress/notes-page.sh's cold scene runs the kit's dwl (default ~/.local/src/dwl/dwl, the edited tree), not a binary
   built from src/dwl/dwl.patch: before a push it proves the tree; say so in the header (the guard's `--dwl /usr/local/bin/dwl`
   after an apply, lib/guard.sh:181, is the one that proves the patch).
7. §7 and the ledger (r27-21-sf) say the to-do "opens the same way, typing, on a fresh item at its end" — true only for a list
   shorter than the page until must-fix 2; and §7 could say in one line what the opening rule means day to day: the day before
   on top until today has three lines, then today's own.
8. The suite on 2939cc8 (/dev/shm/r27p/suite-2939cc8.log) was still running when this was written (45 files, no failure);
   the verdict rests on the author's test logs, the evidence renders, and my own probes and kit renders above.
