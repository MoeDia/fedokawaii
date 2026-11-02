VERDICT: FAIL
(the master, T21 re-review 4 — 2026-11-02 13:32 +04, c793b14's notes.lua = the working tree's (cmp-equal), in a throw-away home
/dev/shm/r27/master/T21/own/home-new (the r3 archive's home, the lua swapped; home-old = db4bf81's lua, for comparison; nvim v0.12.6).
Own probes in /dev/shm/r27/master/T21/own/: probe/run-p4.sh (p4c.lua: a page of three-row lines, the screen's first rows and skipcol
after every key) → p4-new.log; probe/run-p5.sh, run-p6.sh (p1c.lua: the pen AT THE FOOT — 30 lines given at once, row 33 — then the
user scrolls away: Ctrl-Y, the wheel in insert and normal mode, Ctrl-B/F/U/D, gg/G, z, the 45-item to-do) → p5-new.log, p5-old.log
(db4bf81), p6-new.log; probe/p7.lua → p7-new.log (WinScrolled and CursorMoved counted per key); measure4.log (the author's twelve
final shots, the r3 measurer). No kit render: the ledger asks for nothing heavy beside the suite, and every finding here is nvim's own
screen cells and view — nothing foot would draw differently.)

## Verified (held)
- Must-fix 1 of verdict 3 is gone at its root: smoothscroll out of page() (notes.lua:175–178 now wrap/linebreak/fillchars only), the
  skipcol out of on_day (292). p4-new.log, the same file as verdict 3's p2c (30 three-row lines + today): opened by kawa_notes_shown
  the screen's row 3 is `  │ line 17 is a long on` (verdict 3: `<<< wraps onto a second `); then wheel up ×4 / down ×2, Ctrl-Y ×5 /
  Ctrl-E ×2, Ctrl-U ×2 / Ctrl-D, Ctrl-B ×2 / Ctrl-F, gg + Ctrl-E ×3 + Ctrl-D ×2 + Ctrl-F, G / Ctrl-F / Ctrl-B, and a today of 24
  three-row lines under the wheel ×2 / Ctrl-Y ×3: skipcol 0 at all 41 steps, the margin cells `  │ ` at the start of rows 3–6 every
  time, `<<<` nowhere (grep -c = 0; verdict 3's log had it at the opening and on every second notch). The never-again row
  (test_notes.sh:274–278) reads exactly those three facts and fails on db4bf81 (the author's log: 136/2).
- Verdict 3's should-fix 2 case itself: at the foot `<Esc><C-f><C-f><C-b>` → topline 156 → 124, pushes 4, the pen on row 33 (p5-new.log
  scenario 7; db4bf81: row 37 NOROOM, pushes 0 — p5-old.log). Its row (test_notes.sh:270–273) also carries the bracketed 3-line paste
  (nit 4 of verdict 3) — +3 lines, the pen's room kept.
- No loop: a push made inside WinScrolled's handler fires WinScrolled once more (p7-new.log: the second Ctrl-Y counts 2), the second run
  finds the room and stops — pushes 1 per Ctrl-Y, 3 per wheel notch, never more; no timeout in ~60 nvim runs. (A wall, not a loop —
  must-fix 1 below.)
- Nits 5–6 of verdict 3: to_end's second namespace read gone (228–236; `size` kept with its reason — a resize lays new rows — fine),
  ruled[buf] cleared on detach (253), the namespace comment whole (217–218); "a line a step" (test 269) with the header's "a line at a
  time" (notes-page.sh:7); the ledger's r27-21-master-3-fix names the cause right (pen_room's topline + 1, by lines).
- Check (3), the regress check's honesty: check.py (notes-page.sh:77–82) now holds shifts ⊂ {1, 2}, at most ONE 2-row step, at least
  five 1-row steps, and its comment names the one case — the play's line 12 (two rows) leaving the top at the yyp (verdict 3's
  shifts-{dark,light}.log: frame 3778/3771); line 27 = buffer line 37 never reaches the top (the final topline is 23). It claims only
  what it checks; regress-final.log held in both moods.
- The twelve final shots (regress-{dark,light}-{open,typed,cold,todo-tab,todo-enter,todo-list}.png) measured again: every number
  identical to verdict 3's (measure4.log vs measure3.log, diff empty): heading rule y 17, 36 rules y 66 + 20k x 0–529 in EDGE2, the
  margin x 28, winbar and float row blank, the pen with its paper ahead.
- Scrolling with the pen NOT on the last line is untouched: `<Esc>10k` then Ctrl-Y ×6 / Ctrl-E ×2, Ctrl-B then Ctrl-Y ×3, Ctrl-U/D,
  gg/G/:1/:$, zt/zz/zb: the view moves as asked, pushes 0 except G/:$ (five, the intended room) (p5-new scenarios 4–6, 8–9; p6-new 3).

## Must-fix
1. The WinScrolled hook (notes.lua:309) makes scrolling UP from the foot dead in normal mode — the view the user scrolls is pushed
   straight back. With the pen on the last line at row 33 (where pen_room leaves it after every line typed: the page's state at the end
   of every entry), `<Esc><C-y>` ×5: topline 124 → 124 → 124 → 124 → 124, pushes 1 each (p5-new.log scenario 1; scenario 10: eight dead
   Ctrl-Ys around an `iq<Esc>`); the wheel in normal mode ×3: 124 → 124, pushes 3 each (scenario 3; p6-new 4); the to-do list (45 items,
   Tab, Esc): the first Ctrl-Y moves (the pen 32 → 33), every Ctrl-Y and wheel notch after it dead (p6-new 1); a day of long lines:
   `<Esc><C-y>` ×5 at topline 21 → 21 (p4-new.log), the long today 17 → 17; the pen one line above the last (`<Esc>k`): one Ctrl-Y, then
   dead (p6-new 5). Counted (p7-new.log): Ctrl-Y → WinScrolled 1 → pen_room sees row 34 > 33 (nvim leaves the cursor there: its scrolloff
   is met by the paper's virt rows) → topline + 1 → the view exactly where it was. On db4bf81 the same keys moved the view every time
   (p5-old.log: 124 → 123 → 122 → 121 → 120 → 119, the pen down to row 38 under the floats; the wheel 124 → 121 → 118 → 115): this
   commit's regression, and check (2)'s very case — the page is dragged back when the user scrolls away on purpose. Insert mode is
   spared only because nvim 0.12.6 does not fire WinScrolled there (p7: 0 on both wheel notches; nvim moves the cursor itself to row 33
   on the second) — so the page scrolls before Esc and not after it, and the to-do's list (normal mode) is the dead one.
   Honesty: verdict 3's should-fix 2 proposed this hook on the premise "it only ever scrolls forward from a pen below row 33, so a
   wheel-up never triggers it" — false for the pen at the foot, where a wheel-up starts. My premise; the author's duty was to test it
   (CLAUDE.md: nothing is done until verified) — every scrolling probe so far, the author's and verdict 3's p2c, started with the pen on
   row 8; the foot was never tried by either of us.
   Fix (one rule — nvim's own scrolloff philosophy): on a scroll the user made, the VIEW is his and the PEN yields. In WinScrolled never
   winrestview; if winline() > winheight − ROOM, move the cursor up by lines until the pen is on row winheight − ROOM (nvim does this
   itself for the wheel in insert mode — p7: line 156 → 150 — and for Ctrl-B when the pen would leave the window — p5-new 4: 156 → 120).
   Then Ctrl-F Ctrl-F Ctrl-B still ends with the pen visible with its room (on line 152 at row 33, the view as Ctrl-B left it), and
   Ctrl-Y / the wheel move the view by exactly what was asked. A change or a pen move keeps today's rule (pen_room moves the view).
   Never-again rows, failing on c793b14: the pen at the foot (30 lines given at once) then `<Esc><C-y>` ×3 → topline −1 each; the wheel
   ×2 in normal mode → −3 each; winrestview never called; the pen's row ≤ 33 after each; the same in the 45-item to-do after Tab + Esc.
   And the kit: the archived play-sms.sh (Esc, `chord ctrl y` ×3, a shot each) with the frames compared — the page one row further each.

## Should-fix
2. After a wheel-up in insert mode (the pen at row 36, visible) Esc jumps the page back three rows: p6-new.log scenario 4 — WHEELUP
   124 → 121 pushes 0, `<Esc>` 121 → 124 pushes 3 — CursorMoved fires for Esc's one-column step and pen_room reads it as the pen moving.
   Pre-existing (db4bf81: p5-old scenario 10, `iq<Esc>` 122 → 124), the same root as must-fix 1: a cursor event that is not the user
   moving the pen. Decide and say it: either the pen yields on CursorMovedI/CursorMoved too when the topline went UP since the last key
   (the user scrolled; then the pen goes to row 33 and the view stays), or document the jump in §7; a row either way (wheel-up typing,
   Esc: the topline as the wheel left it, or the documented row).
3. docs/design-system.md §7 (396–407) still says nothing of the page moving by lines — verdict 3's should-fix 3 asked for the sentence
   there, the design system being the single truth (CLAUDE.md); it lives in notes.lua:267 and the ledger only. One sentence: "the page
   scrolls by lines — a wrapped line leaves the top whole, the pen gaining its rows".

## Nits
4. check.py (notes-page.sh:81) accepts ONE 2-row step anywhere in the recording — it cannot tie it to the yyp frame, so a 2-row jump
   elsewhere passes once if the yyp's step were ever one. Say so in the comment ("once, anywhere: the recording cannot place it"), or
   compare the two departing rows of that step with the frame before (one wrapped line: its second row carries no first-row glyphs).
5. The new paging row's description (test_notes.sh:270) says "no cursor event, only a scroll" — with must-fix 1's rule the scroll
   WILL move the cursor; reword with the fix.
