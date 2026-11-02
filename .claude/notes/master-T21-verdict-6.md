VERDICT: FAIL
(the master, T21 re-review 6 — 2026-11-02 14:14 +04. Reviewed: 45d443f's notes.lua (cmp-equal to the working tree; the d56fe4a..45d443f
diff of notes.lua and test_notes.sh), in throw-away homes under /dev/shm/r27/master/T21/own/ (home-p4/p5/p6/p9/x = the r5 archive's
home with HEAD's lua swapped in; home-old = d56fe4a's lua; nvim v0.12.6; the stub kawa-notes first on PATH). Verdict 4/5's probes rerun
unchanged: probe/run-p4.sh → p4-r6.log, run-p5.sh → p5-r6.log, run-p6.sh → p6-r6.log. New: probe/p10.lua (p9's event tracer plus TH =
nvim_win_text_height from the top line, COLS, BufWinEnter/InsertEnter traced), run by probe/run-all-r6.sh → N1–N23.log; W1–W6 + W2k.log (the
insert-mode wheel after each way into typing); probe/p12.lua → C1–C3.log (the real start: 24 rows, then the resize to 40); the repo's own
tests/content/test_notes.sh → test_notes-r6.log. No kit render: every finding is nvim's own top/row/line/col and buffer text.
Clipboard: my probes until 14:10 inherited the live session's env (the archived homes carry the real clipboard.lua), so N3's `yyp` went to
his clipboard (a wl-copy "again", pid 271039 — reported to the main agent, not killed by me). Every run after that is under
`env -u WAYLAND_DISPLAY -u DISPLAY DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent XDG_RUNTIME_DIR=own/xdg`; N3i.log and W2i.log, the yank
scenario and the must-fix scenario rerun isolated, are identical in every state line to N3/W2 ("clipboard: No provider" added) — no finding
depends on the provider. The repo's test sandbox (tests/lib/harness.sh: its own XDG_RUNTIME_DIR, WAYLAND_DISPLAY=wayland-0 under $TMP/run)
cannot reach his session.)

## Verified (held)
- Verdict 5's must-fix 1: Tab from the long notes (top 119 remembered) into the 45-item to-do → the pen on 46/46, top 14, row 33, pushes 5
  (p6-r6 scenarios 1–2; N6: "abc" → `L46 |[ ] abc|`, items 41–45 untouched; r5 had 41/46). The new test row run by me against both luas:
  HEAD "46/46 [ ] new one | [ ] thing 41", d56fe4a (home-old) "41/46 [ ]  | [ ] new onething 41" — the row catches the bug. BufWinEnter's
  reset traced (two on the first Tab: bufload + set_buf; one after). Tab back and forth in scrolled states (N7): the notes return on 156,
  row 33, top 124; the to-do on its fresh item.
- Verdict 5's must-fix 2 in the sequence I gave: the window's own typing, the wheel, `qr`, Esc → `L156 |qr|`, the pen on 156, row 33, the
  view back to 124 (W1 = the A/HA sequence; r5: the pen on 153). CursorMovedI only follows (N4: wheel up, <Up> → pen_room +2, `q` on 155 =
  the pen's line; N13: Enter after a wheel up → line 157 on row 33).
- Verdict 5's should-fix 3: typing at the foot, the wheel (typing), Esc → InsertLeave moves the pen 156 → 153 onto row 33 while the top
  stays 121 (N18, N21, C2; p6-r6 scenario 4: "<Esc> 121 → 121 still, pushes 0" — r5: 121 → 124, pushes 3). The "ev InsertLeave" line already
  shows top 121 / line 153: it runs before neovim's own check. The TextChanged after it (same changedtick) goes through keep_room: no push.
  The row's "-3 0 | 36 33" holds. nvim_win_text_height with end_row given does not count the paper's 40 virt_lines (N1/N10b TH: "top..last
  all 33 fill 0"; end_row omitted: all 73 fill 40), so the walk is right on the last line too (N1: wheel down, `a`, wheel up, Esc → the pen
  stays on 156, row 33, no move).
- No regression of verdicts 2–4: p4-r6.log identical to p4-r5.log (37 steps, skipcol 0, no <<<); p5-r6.log identical to p5-r5 except the
  fixed scenario 11; p6-r6 differs only in the fixed lines. o / yy p after yields: one row a line, the pen on row 33 (N3: 122 → 123 → 124);
  Ctrl-Y/E/U/D/B/F, gg/G, zt/zz/zb, undo (N15: `u` after two Ctrl-Ys → the view to the pen, row 6, no push), Ctrl-O Ctrl-Y in typing (N11:
  the pen yields a line each, `q` lands on it), Ctrl-C after a wheel up (N12: the page stays, the pen 153 on row 33 via the same-tick
  TextChanged), hide/show (N9), a resize to 30 rows and back in typing (N8), wrapped lines (N16), the real start — 24 rows, kawa_notes_shown,
  then the resize (C1: the long today's pen on row 29, the wheel → 32, Esc moves nothing; C2: typing after, the wheel, Esc → 153 on row 33).
- Nits 4–5 of verdict 5: the comments say what seen_top assumes and why it is the window's, reset on BufWinEnter — right for normal mode
  (but see must-fix 1 for the typing claim). test_notes.sh: 142 passed, 0 failed, rc 0 (test_notes-r6.log).

## Must-fix
1. A wheel notch WHILE TYPING moves his insertion point into an older line — in every window that has once been in normal mode, i.e. the
   warm window after its first Esc, his daily case. W2 (`<Esc>`, `i`, wheel up, `qr`), W3 (`A`), W5 (`i`, `x`, wheel), W2k (the test's own
   `<ScrollWheelUp>` notation after `A`): "ev WinScrolled -> top 121 row 33 line 153 mode i" — WinScrolled DOES fire in insert mode there →
   keep_room → pen_yield → the pen 156 → 153 while he types; `qr` then gives `L153 |qrx|` (his words spliced into the start of an older
   line), line 156 stays empty, the view stays at 121. The same keys in a window that never left typing since its start (W1 = the test
   rows' path) give `L156 |qr|` and the view back to 124. Two opposite results for one action; the splicing one is the common one: the
   insert-mode wheel fires WinScrolled once the main loop has taken its initial snapshot, which happens only in normal mode (W1/N1/N6/N18
   never see it; W2–W5/N2/N14/N23 always do). So the comment above the InsertLeave handler ("the wheel moves no pen in typing, nor tells
   anyone") and the ledger's "the insert-mode wheel fires no event" hold only for a window not yet through normal mode, and both rows
   (verdict 4's and should-fix 3's) run only that path — their "36" after the wheel is its signature. A typed key is a change and the
   wheel in typing a look (verdict 5, must-fix 2; vanilla neovim keeps the cursor on its line until it would leave the window). Fix: a
   WinScrolled while the mode is insert does nothing (no yield, no pen_room, no look recorded) — the next key brings the view back to
   the pen (follow), Esc yields it (InsertLeave): W1's path, which the rows already assert. Row: the foot, `<Esc>`, `A`, `<ScrollWheelUp>`,
   `q`, `r`, `<Esc>` → line 156 = "qr", line 153 = "x", the pen on 156, row ≤ 33 (at 45d443f: "qrx" on 153, W2k.log).

## Should-fix
2. The InsertLeave yield lands the pen on column 0 (`nvim_win_set_cursor(0, { r, 0 })`): N21 — thirty "hello world" lines, the wheel, Esc →
   "line 152 col 0"; pen_yield keeps the column (`math.min(c, #up)`), so one yield gives two columns by its path (after Ctrl-Y the end of
   the line, after Esc its start). Keep the column as pen_yield does.

## Nits
3. The InsertLeave handler and pen_yield are two walks of one rule (rows to the pen > room → up a line, the column aside); once must-fix 1
   makes the insert-mode WinScrolled inert, one walk taking its row-counter (winline vs text_height) would do — only if it stays as short.
4. `ticks` and `seen_top` are never dropped for a wiped buffer or closed window (two buffers, one window, for the session: harmless; say so,
   or clear them in on_detach).
5. VimResized records no look: N17 — a resize to 12 rows, a wheel up in typing, Esc → the view back +3 to the pen (top 147 → 150), the
   page not his. Unreachable in the warm window (its size never changes after the first; C1–C3 clean), but one line after on_day/pen_room
   (`seen_top[w] = line("w0")`) leaves the rule without an exception.
