VERDICT: FAIL
(the master, T21 re-review 5 — 2026-11-02 13:50 +04. Reviewed: d56fe4a's notes.lua (git show, cmp-equal to the diff asked), in throw-away
homes under /dev/shm/r27/master/T21/own/ (home-p4/p5/p6 = the r4 archive's home with the lua swapped; nvim v0.12.6; a stub kawa-notes
first on PATH). The verdict-4 probes rerun unchanged: probe/run-p4.sh → p4-r5.log, run-p5.sh → p5-r5.log, run-p6.sh → p6-r5.log (one
home per script — my first run shared one v.md, discarded). New: probe/p9.lua + run-p9.sh, an event tracer (every WinScrolled /
CursorMoved(I) / TextChanged(I) / InsertLeave / VimResized with the state notes.lua's handler left; CLICK, RESIZE, SHOW, DUMP steps) →
A–G.log. HEAD moved during the review (a6809d4, "the remembered top forgotten on BufWinEnter"): the same three probes against HEAD's
lua → HA/HB/HE.log, cited where they change a finding. No kit render: every finding is nvim's own cursor line and buffer text.)

## Verified (held)
- Verdict 4's must-fix 1 is gone, in every scenario of p5/p6/p4: the pen at the foot (30 lines given at once, row 33), `<Esc><C-y>` ×5:
  topline 124 → 123 → 122 → 121 → 120 → 119, pushes 0, the pen on row 33 each time (p5-r5 scenario 1; verdict 4: 124 → 124 ×5, pushes 1
  each); the wheel in normal mode ×3: 124 → 121 → 118 → 115 (scenario 3); Ctrl-B ×2 / Ctrl-F ×2: 124 → 88 → 52 → 88 → 124 (4);
  Ctrl-U ×2 / Ctrl-D ×2 (5); the to-do of 45 items after Tab + Esc: Ctrl-Y ×3 → 9 → 8 → 7 → 6, the wheel → 3 → 1 (p6-r5 scenario 1);
  eight Ctrl-Ys around an `iq<Esc>`: 124 → 114, one a step (p5 scenario 10); the pen one above the last (`<Esc>k`) then Ctrl-Y ×6: 124 →
  118 (p6 scenario 5); a day of three-row lines: `<Esc><C-y>` ×5 → top 20, 19, 18 …, skipcol 0 everywhere (37 of 37 steps), `<<<` nowhere
  (p4-r5.log). winrestview is never called for a scroll he makes (pushes 0 at all 60-odd scroll steps).
- No new fight in check (2)'s list, each traced (A–G.log): scrolling DOWN to read ahead then typing — `<Esc>gg`, Ctrl-E ×2, Ctrl-D, the
  wheel down, Ctrl-F (pushes 0, the view as asked), then `Gotyped<Esc>` and `oagain<Esc>`: the pen gets its room (top 124 → 125 → 126,
  row 33) (C.log). gg then G: 1 → 124, pushes 5, row 33 (p5 scenario 6; `:1`/`:$` the same). A click on a row after two Ctrl-Ys: the
  cursor to the clicked line (130, then 150), the view untouched, typing there untouched; G after it gives the room (D.log). zt/zz/zb
  then `iq<Esc>` after each: the view stays where z left it (151 / 138 / 151), typing does not move it (G.log). Resize 40 → 30 → 40 rows
  with the view scrolled up: VimResized re-lays, pushes +1 once, then Ctrl-Y moves the view by one at each size, `iq<Esc>` stays (E.log).
  Hide/show (kawa_notes_shown again after three Ctrl-Ys): on_day puts the pen on today's line at row 33, top 125; the Ctrl-Y after it
  moves 125 → 124; the stale remembered top (121 < 125) misleads nothing (F.log).
- Should-fix 3 of verdict 4: design-system §7 now says it ("The page scrolls by lines: a wrapped line leaves the top whole. A scroll he
  makes is his …"). Nit 4: check.py's comment says the recording cannot place the one two-row step. Nit 5: "no cursor event, only a
  scroll" is gone from test_notes.sh (grep: 0).

## Must-fix
1. The to-do opens with the pen on the WRONG item and his words go into an existing one. Notes 126 lines (top 119, remembered), Tab →
   the to-do of 45 items: new_item appends line 46 and sets the pen there, then CursorMovedI fires (before TextChangedI) → keep_room sees
   top 9 < seen_top 119 (the NOTES window's top, kept per window across the buffer switch) → pen_yield walks the pen UP five lines to
   row 33 = line 41. Typing "new one" gives `[ ] new onething 41`; line 46 stays `[ ] ` (B.log, DUMP 40–46). c793b14: line 46/46 after
   Tab (the r4 archive's p6-new.log). Any to-do longer than the page, opened from notes whose top is beyond the list's — his daily case.
   HEAD's a6809d4 (seen_top forgotten on BufWinEnter) fixes this one: Tab → line 46, "new one" → `[ ] new one`, pushes 11 (HB.log). Keep
   it; and the to-do test row (test_notes.sh "tab, esc, then Ctrl+Y twice") must also assert the pen's line after Tab = the last line —
   it reads only the top line's steps and passed on d56fe4a with the pen five items off.
2. Typing after a wheel-up in insert mode leaves the pen on another line than the text. The pen at the foot (row 33, line 156, insert
   mode), one wheel notch up: no WinScrolled in insert mode (verdict 4, p7), the pen stays on 156 at row 36 — under the floats — and
   seen_top stays 124 > top 121. Then `qr`: the text lands on line 156 (DUMP: `L156 |qr|`), CursorMovedI fires → keep_room reads the
   stale "top went up" → pen_yield → the pen ends on line 153 col 1 (A.log: `after qr … line 153 col 1`; L153 still `x`). Key by key
   (foot sends one at a time) the first char goes under the float, the rest into line 153. c793b14: the view came back to 124, the pen
   and the text together on row 33 (archive p5-new.log scenario 11). Still so at HEAD (HA.log). The rule verdict 4 asked for says it:
   "a change or a pen move keeps today's rule (pen_room moves the view)" — a typed key is a change, not a scroll he made. Fix: never
   yield on CursorMovedI (in insert mode the wheel moves no cursor and nvim moves it itself when it leaves the window; every CursorMovedI
   is typing or an arrow → pen_room); yield only on WinScrolled and CursorMoved. Row: `i` at the foot, `<ScrollWheelUp>`, `q`, `r`, Esc →
   line 156 = "xqr"-shaped (the text where the pen was), the pen on it, row ≤ 33.

## Should-fix
3. Verdict 4's should-fix 2 (Esc after an insert-mode wheel-up jumps the page back) is fixed only for the row's sequence
   `i<ScrollWheelUp><Esc>` — nothing typed in that insert session. With typing first (the real case: he writes, wheels up to look, Esc):
   InsertLeave → TextChanged fires (the insert session changed the buffer) → pen_room → top 121 → 124, pushes 3 (p6-r5 scenario 4;
   traced in "Esc after insert wheel", and HE.log at HEAD). The ledger's "verdict 4 fixed" overstates it. Fix with 2: in the change
   handler, when b:changedtick equals the tick of the last change handled (InsertLeave's TextChanged brings no new change), treat it as
   keep_room would (yield, the view stays); put the typed text into the row (`x<CR>` ×30, `<ScrollWheelUp>`, `<Esc>` → step 0).

## Nits
4. The comment above seen_top ("only he scrolls it up: Ctrl+Y, Ctrl+B, the wheel") is false by must-fix 1 and 2: a buffer switch,
   on_day, VimResized and nvim's own insert-mode scrolling move the top too; say what the mechanism really assumes once it is fixed.
5. pen_yield's `for _ = 1, vim.o.lines` bound and the `math.min(c, #up)` column are fine; `seen_top` is per window but reset per
   buffer (BufWinEnter) — a table keyed by window holding a buffer's fact; key it by buffer, or keep the reset and say why.
