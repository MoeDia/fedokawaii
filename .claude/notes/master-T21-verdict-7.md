VERDICT: FAIL
(the master, T21 re-review 7 — 2026-11-02 14:40 +04, narrow: verdict 6's findings and what their fixes could have disturbed. Reviewed:
2445edf's notes.lua (= HEAD 04b1c09 = the working tree, cmp'd) and the 45d443f..2445edf diff of notes.lua and test_notes.sh. Probes in
throw-away homes under /dev/shm/r27/master/T21/own/ — the r6 archive's homes with HEAD's lua swapped in (home-p4/p5/p6/p9/x/h/h2),
home-old45/home-w45 with 45d443f's lua for the negatives; nvim v0.12.6, the stub kawa-notes first on PATH; EVERY run under
`env -u WAYLAND_DISPLAY -u DISPLAY DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent XDG_RUNTIME_DIR=own/run|xdg` (the three older
runners patched so before use: probe/run-p4/p5/p6.sh), nothing of his touched. Reruns: probe/run-p4.sh → p4-r7.log, run-p5.sh → p5-r7.log,
run-p6.sh → p6-r7.log, run-all-r6.sh → N*.log (the r6 logs kept in own/r6/), run-w-r7.sh → W1–W6 + W2k.log on HEAD and *-old45.log on
45d443f. New: run-h-r7.sh → H*.log (the hunt: replace/virtual-replace, Ctrl-O, completion, the wheel down, 2/3/10/20 notches on both start
paths, Tab round trips, Esc then Ctrl-Y, hidden/shown, a pending autosave, Ctrl-C, Up/BS/CR after the wheel, a shorter target line);
probe/p11x.lua + p11y.lua via run-p10x.sh → X1–X6, Y1 (the feasibility of must-fix 1's cure); the repo's tests/content/test_notes.sh →
test_notes-r7.log. All evidence is nvim's own top/row/line/col, buffer text and events (p10 tracer), no kit render.)

## Verified (held)
- Verdict 6's must-fix 1, as stated (one notch at the foot, the window through normal mode once): W2 (`<Esc>` `i`), W3 (`A`), W4 (`o`),
  W5 (`i` `x`), W2k (`<ScrollWheelUp>`) — "ev WinScrolled -> top 121 row 36 line 156 mode i": the pen stays on its line through the wheel,
  `qr` → `L156 |qr|`, the view back to 124 on the first key (follow), pushes 6 → 9. W1 (never through normal mode) gives the same —
  the two paths agree now. The negatives on 45d443f (W2/W3/W5/W2k-old45.log): "WinScrolled -> … row 33 line 153" and `L153 |qrx|`,
  as in verdict 6. The new row holds on HEAD and fails on 45d443f exactly as the brief's log says ("153:2 156= 153=qrx"). Replace
  mode (H1 `R`, H1b `R` on a line with text, H1c `gR` mode Rv): inert too, the words on the pen's line. The to-do: W6 `L46 |[ ] abcde|`.
- Should-fix 2: N21 — thirty "hello world", the wheel, Esc → "line 152 col 10" (r6: col 0); the kept column on a shorter target line
  (H9: 155 col 11 → 152 "ab", col clamped to 1 by neovim, no error in the log); the test row's " 152:11".
- Nits 3–5: the InsertLeave walk's reason is right (winline() validates the cursor = neovim's scrolloff check); `ticks` beside seen_top,
  dropped in on_detach; VimResized records its look — N17 (14 rows, the wheel in typing, Esc): "InsertLeave -> top 147 row 7 line 153"
  (r6: the view jumped 147 → 150 with the pen on 156).
- No regression: p4-r7/p5-r7/p6-r7 byte-identical to r6's (verdicts 2–4's 25 scenarios); N2/N4/N8/N10a/N12–N15/N22/N23 identical; the
  rest differ only in the fixed lines or in the autosave's timing (below). Esc after the wheel then Ctrl-Y/Ctrl-Y/`iq` (H7: 153 → 152
  → 151, `L151 |qx|`), `j` after the yield follows (H7b), Tab to the to-do and back after a wheel in typing (H6, H6b: `L156 |qr|`),
  SHOW and hidden+SHOW between (H8a/b/c: the fresh line 157, `qr` on it), `<Up>`/`<BS>`/`<CR>` after the wheel (H10/H11a/H11b: on the
  pen's line, the view back), insert-mode completion (H3/H3b: no WinScrolled with the pum, the pen stays, Esc yields), the wheel DOWN at
  the foot and mid-page (H4a/b/c: the view his, the words on the pen's line), Ctrl-O then the wheel (H2: inert, `L156 |qr|`).
- test_notes.sh in my run: 144 passed, 0 failed, rc 0 (test_notes-r7.log).

## Must-fix
1. The look holds for ONE notch at the foot only; from the second notch — and from the FIRST anywhere else — his words still go into an
   older line. Not ours this time: neovim's own cursor-in-window rule with scrolloff 5 drags the pen with the view (a CursorMovedI with no
   key and pushes unchanged), and the next keys land where it was dragged. Foot, through normal mode: two notches → "CursorMovedI -> top
   118 row 33 line 150 mode i pushes 6", `qr` → `L150 |qrx|` (H5a); three → 147 (H5b); ten → 126 (H5c); twenty → 96 (H5e). The fresh
   path the same (H5d: 150, H5f: 147). Mid-page (`<C-u>`, `i`, ONE notch): the pen 137 → 134, `L134 |qrx|` (H24). After Esc's yield (the
   pen on 153, `A`, one notch): 153 → 150, `L150 |xqr|` (H25). One notch at the foot works only because the paper's 40 virt rows under the
   last line satisfy scrolloff there. So the comment above the WinScrolled handler ("a look: nothing moves and nothing is noted — the next
   key brings the page back to the pen") and the ledger's claim are true of one notch at the foot and false of the gesture itself (two
   or three notches to look, or any notch while editing an older line) — from his seat the same splice as verdict 6's must-fix 1. The
   cure is proven feasible in ~12 lines (X1–X6, Y1): remember the pen at InsertEnter and every TextChangedI; a wheel in typing flags a
   look; the first typed key after it puts the cursor back on the pen before the key is processed — in vim.on_key (p11x.lua) or
   InsertCharPre (p11y.lua): nvim_win_set_cursor is allowed in both ("set_cursor(156,0) true nil"), `qr` → `L156 |qr|` after two and
   twenty notches, `L137 |qrx|` mid-page, `L153 |xqr|` after a yield, the view back to the pen (pushes 6 → 11), and `u` after Esc removes
   exactly "qr" (`L156 ||`, X1/Y1). Esc keeps yielding (X4). Choice to state in §7: with on_key every key after a look acts from the pen
   (`<Up>` → 155, X6, as it does after one notch today — H10); with InsertCharPre only typed characters do, `<Up>`/clicks stay vanilla.
   Never via CursorMovedI (it also fires for his own `<Up>` and clicks). Rows: two notches at the foot then `q` `r` → 156 = "qr", 150 =
   "x", the view back; `<C-u>` `i` one notch `q` `r` → on the pen's line; `<ScrollWheelUp>` `<Esc>` `A` `<ScrollWheelUp>` `q` `r` → 153 =
   "xqr". All three fail on 2445edf.

## Should-fix
2. The autosave undoes the look within a second of his last key: `:update` with something to write bumps b:changedtick (probe: 4 → 5
   after a change + :update, unchanged by a no-op update), so the write's TextChangedI arrives with a tick ≠ ticks[] → follow() → pen_room
   pushes the page back to the pen with no key from him. H16: `z`, the wheel (top 121, row 36), then nothing for 1.25 s → "TextChangedI
   -> top 124 row 33 … pushes 9"; N18 r7 the same (r6's run only lost the race). The same bump makes the InsertLeave→TextChanged pair a
   follow(), not the "look" the ticks comment promises, whenever Esc had something to save (harmless there: the yield comes first).
   Record the written tick (BufWritePost, or after each `update`) and let its TextChanged/I do nothing after rule() — NOT keep_room: in
   typing that would pen_yield and bring must-fix 1 of verdict 6 back by the autosave's road. One row: typing, a wheel, 1.2 s of nothing →
   the top line unchanged. Pre-existing since 89345d6; it is the one case the fix under review handles, undone by a timer.

## Nits
3. Ctrl-C ends typing without InsertLeave: after a wheel in typing it leaves the pen on row 36, outside its room, when nothing was changed
   since the last save (H23: "after <C-c> top 121 row 36 line 156 mode n"); a `k` then yields it two lines more than the key moved. Esc is
   his key (foot sends it); note only, unless the same-tick TextChanged path is meant to cover it (it did in N12, where a change was pending).
4. The must-fix-1 row's title says "two keys: they go on his line" without "one notch": once must-fix 1 is done the title can mean it.
