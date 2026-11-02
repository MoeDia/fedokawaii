VERDICT: FAIL
(the master, T21 re-review 3 — 2026-11-02 13:10 +04, checkout /dev/shm/r27w-suite-b2f7444 = main b2f7444 (db4bf81's notes.lua, cmp-equal to the
repo's); own probes, renders and logs in /dev/shm/r27/master/T21/own/: probe/p1c.lua + run-p1c.sh → p1c.log (36 key sequences on the 30-day diary,
the 45-item to-do, the wrapped-top-line files), probe/run-p2c.sh → p2c.log (manual scrolling in normal mode, paging keys, the wheel over wrapped
lines with the screen's rows dumped: probe/p4c.lua), old-vs-new.log (2939cc8's notes.lua against db4bf81's on the same files), check-shifts.py →
shifts-{dark,light}.log (every scroll step of the final run's kept recordings /dev/shm/regress-notes.gokuwm/*.mkv, named), sms/ (one kit render,
dark, real GPU: a page of three-row lines opened, then Ctrl-Y ×3; zoom-*.png; measure-sms.log), measure3.log (the author's 12 final shots))

## Verified (held)
- Must-fix 1 of verdict 2 at its root: the paper's mark moves inside the change (on_lines → to_end, notes.lua:253–258, its own namespace
  kawa_paper). Own probe p1c (long.md, 126 lines, topline 119, the pen on the appended line): `<Esc>o`, `<Esc>yyp`, `<Esc>Go`, `<C-o>o`,
  `<Esc>yy:$put<CR>`, `<CR>`, `:r ~/Notes/three.md`, `"ap` (3 lines), a bracketed paste of 3 lines (nvim_paste), `kJ`, `dd` `u` `<C-r>`, `:$m0`,
  `:1m$`, `V"ap`, `ggdG` `u`, `:%d` `u`, `oabc<Esc>` `u` `<C-r>`, `:g/^$/d`, `:%s/day/night/g`, `kdd`, `yyP`, `ggOtop`, `:1,3d`, `A<C-u>`, `Vjjd`,
  `:$d` ×3 — after every one: exactly ONE paper mark, at (last line, its end); exactly one rule mark on every line; topline unchanged (±1) for
  every change made at the end; the pen's row ≤ 33 (p1c.log). The commands that move the cursor far (`:$m0`, `gg`, `:1,3d`, `:g`) move the view
  as they should and leave the paper and rules right.
- Must-fix 2 of verdict 2: the pen's room after every change and move. At the foot (30 lines given at once → topline 119→124 by five pen_room
  pushes, the pen on row 33 of 38), then `o` +1 row, `yyp` +1, `"ap` +1 (the cursor on the first put line), a 3-line paste +3, `:r` +1, `kJ`/`dd`/
  `u`/`<C-r>` 0 — the pen on row 33 or 32 each time (p1c.log "at the foot"). The 45-item to-do: `<Tab>` → row 33 (five pushes), `abc<CR>` row 33,
  `<Esc>` 32, `<Space>`, `dd`, `u`, `o`, `<Tab>` back (row 8), `<Tab>` again (row 33), `G`, `<CR>`; and `gg`/`<Space>`/`G`/`O`/`yyp`/`yyP`/`u`/`u`:
  paper and rules right throughout (p1c.log "the to-do"). Kit: regress-*-todo-{tab,enter,list}.png measured (measure3.log).
- No fight with manual scrolling, no loop: in normal mode `<C-y>` ×3 / `<C-e>` ×5 each move the topline by exactly one, pen_room never pushes
  (pushes 0 = winrestview never called); `<C-u>`/`<C-d>` ±19 lines; `<C-b>`/`<C-f>` ±36; the wheel ±3 lines in insert mode with the pen's row
  rising 8→11→14→17 and back, pushes 0; `gg`, `zb`, `zt`, `zz`, `z.`, `H`, `L`, `M`, `:1`: no push. Only `G` and `:$` push (five, to row 33 — the
  intended room). Scrolled up to read old notes, nothing jumps (p2c.log). Cost: per key two extmark reads and winline() — nothing measurable.
- The three bugs found on the way: (a) one rule a line after typing with Returns — held on every sequence above (the id collision cannot recur
  with the paper in kawa_paper; the author's log test_notes-on-id-colliding-notes.lua.log shows the row biting: "6:0"); (b) one paper after a
  reload: own p_reload on the checkout's lua → "paper marks at lines 128 of 128"; a same-count reload (a line changed on disk) → 1 mark at 125/125,
  every line ruled once, tree-sitter off, syntax OFF (p_reload2.lua); (c) the two-row step — NOT fixed, misdiagnosed, and the fix tried for it
  broke the page: must-fix 1 and should-fix 3 below.
- Should-fix 3 of verdict 2 (the same-count re-lay) has its row (tests/content/test_notes.sh:289–298, "31/31 20 -"); the dead `shown` is gone.
- Geometry, the author's 12 final shots (regress-{dark,light}-{open,typed,cold,todo-tab,todo-enter,todo-list}.png, measure3.log): the heading
  rule y 17 x 0–529; 36 page rules at y 66 + 20k, x 0–529, each on its cell's 19th px; the margin x 28 rows 2–37; the winbar blank; the float
  row blank; the footer MUTED — identical to verdicts 1 and 2 in both moods. regress-dark-typed.png: the pen on row 33, three ruled rows ahead.
- Typed text as typed, after a reload too (verdict 1's must-fix 1) — unchanged code path, re-held by p_reload2 (ts off, syntax OFF).
- The suite on b2f7444 (/dev/shm/r27p/suite-b2f7444.log): 52 files "0 failed" and no failure when this was written; the verdict does not rest on it.

## Must-fix
1. `smoothscroll` (notes.lua:178–180, new in db4bf81) cuts a wrapped line at the top of the page and draws neovim's `<<<` marker over the
   margin: the first text row loses its vermilion rule and shows a line's tail. It is the page's OWN opening state on a day of long lines
   (his lines wrap: the page is 60 columns), and every other wheel notch or Ctrl-Y over wrapped lines. Proof: own/p2c.log, p4c section — a
   page of three-row lines opened by kawa_notes_shown: screen row 3 = `<<< wraps onto a second ` (the margin's `  │ ` gone), winsaveview
   skipcol 64; wheel up: `<<< and wraps onto a sec` at skip 60 on steps 2 and 4; Ctrl-Y: on steps 2 and 4 likewise. The same files on
   2939cc8's notes.lua (own/old-vs-new.log): skipcol 0 at every step, the margin whole, never a `<<<`. Kit (dark, real GPU, own/sms/): open.png
   → zoom-open.png shows `<<<` in grey at the top-left, no margin rule on the first row, "wraps onto a second ruled row of paper, and here a
   third" as the page's first line; measure-sms.log: the margin's run in open.png and ctrl-y-2.png is (28, 68, 767, 700) — it starts one cell
   lower and is 20 px shorter than in ctrl-y-1.png and ctrl-y-3.png (28, 48, 767, 720). Neovim has no switch for the marker (options.txt:
   5987–5995: "'<<<' is displayed at the start of the first line, highlighted with hl-NonText"; a 'showbreak' would indent every continuation
   row instead). And the option's stated reason is false — see should-fix 3: the page's own scrolling never used it. Fix: drop smoothscroll
   (and on_day's skipcol = 0, notes.lua:294, added for it); never-again rows that FAIL on db4bf81's lua: headless — a page of three-row lines
   opened, then wheel up ×4 (nvim_input_mouse) and `<Esc><C-y>` ×5: skipcol 0 and no screen row beginning "<<<" at any step; kit — the
   typing play's first lines long enough to wrap, so wrapped lines reach the top and check.py's margin comparison (notes-page.sh:62, the
   cells left of x0) bites on a `<<<`. §7's "head, foot and margin never move, whatever the scroll" (design-system.md:397) must then be true.

## Should-fix
2. A page command can still leave the pen under the float: `<Esc><C-f><C-f>` (the last line at the top) then `<C-b>` → the pen on row 37 of 38,
   pushes 0 (own/p2c.log: "row 37/38 NOROOM") — nvim's scrolloff is satisfied by the paper's virt rows, and no CursorMoved follows (the cursor
   line did not change), so pen_room never runs until the next key, which then jumps the page four rows. Run pen_room on WinScrolled as well
   (it only ever scrolls forward from a pen below row 33, so a wheel-up never triggers it); a headless row for `<C-f><C-f><C-b>` → row ≤ 33.
3. The two-row step: not a put's doing and not fixed — pen_room steps the topline by LINES (notes.lua:279–280, `v.topline + 1`), so a wrapped
   line at the top leaves whole and the pen drops to row 32. Own probe (p1c.log, "wrap at line 30": the two-row line as the topline, the pen
   on row 33): `<CR>` → top 34 (2 rows) → 35, pushes 1, the pen on row 32; `<Esc>yyp`, `<Esc>o`, `x<CR>`, a line typed past the edge: the same.
   With the top line one row (wrap at 32–34): every one of them a one-row step. The final run's recordings (own/shifts-dark.log, shifts-
   light.log): shifts {1: 18, 2: 1}, the two-row step at frame 3778 / 3771 = the `yyp` with line 22 (the play's wrapped line 12) on top; a Return
   there would have done the same, and nvim's own scroll never moved the page at all (its scrolloff is met by the paper). So: the comment at
   notes.lua:178–180 ("a scroll by rows, not lines") describes a fix that does not happen; the ledger (r27-21-master-2-fix: "neovim scrolls a
   put line by LINES") names the wrong cause; and the regress check (notes-page.sh:77–80) was loosened to admit the symptom ({1, 2}, "two-row
   steps ≤ 2 for the play's two wrapped lines" — only ONE of the play's wrapped lines can ever reach the top: the final topline is line 23,
   regress-dark-typed.png shows line 13 of the play on its first row; and a three-row line would fail it on a legitimate scroll). Decide and
   say it: by lines is the right choice for a notebook (a line leaves whole; the only by-rows alternative is must-fix 1's cut line), so write
   that in §7 ("the page scrolls by lines: when a wrapped line leaves the top the pen gains its rows"), in notes.lua at pen_room, and make the
   check honest — a step must equal the rows of the line that left (the recording cannot know lines, but the play can: one 2-row step at
   most, at the yyp; or compare the departing rows against the frame before) — not "one or two".

## Nits
4. The ledger's bug (c) story and the smoothscroll comment go with must-fix 1 and should-fix 3; the test row "thirty lines given at once" types
   `x<CR>` — a bracketed-paste row (nvim_paste of 3 lines, held by my probe: +3 rows, the pen on row 33) would cover the real paste path.
5. to_end (notes.lua:229–240) reads the namespace a second time on every call (`get_extmarks … limit = 2`) to guard a two-mark state that its own
   clear-then-set makes impossible, and keeps `size` in paper[b] beside rows()'s own memo of the same key — harmless, belt and braces; on_detach
   (258) clears attached/paper but not ruled[buf]. The comment at 219–220 is split across two declarations and reads as one sentence only
   with effort.
6. The regress script's header (notes-page.sh:7) says "the page scrolling forward a line at a time" while the typing check still prints "one
   row a step" wording in the test (test_notes.sh:269 "o and yy p at the foot: one row a step") — one phrase for one behaviour, once should-fix 3 is decided.
