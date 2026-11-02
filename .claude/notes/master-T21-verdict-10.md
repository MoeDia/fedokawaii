VERDICT: PASS
(the master, T21 re-review 10 — 2026-11-02 17:57 +04, narrow: verdict 9's findings and what f0994be could have disturbed. Reviewed:
f0994be's notes.lua (= HEAD dab011a = the working tree, cmp'd; dab011a touches none of the three files), its diff, test_notes.sh's six
new rows, docs/design-system.md §7's page paragraph, the ledger's r27-21-master-9-fix line, the author's two logs beside the brief
(test_notes-f0994be.log 166/0; test_notes-v9rows-on-4c8de66.log 154/12 — 7 scenarios, each 'none' comparison counted twice).
Probes in throw-away homes under /dev/shm/r27/master/T21/own/ (home-a = HEAD's lua for the headless series, home-p its copy for the
pty series; the stub kawa-notes; nvim v0.12.6); EVERY run under `env -u WAYLAND_DISPLAY -u DISPLAY DBUS_SESSION_BUS_ADDRESS=
unix:path=/nonexistent XDG_RUNTIME_DIR=own/xdg`, nothing of his touched. Series: M (headless, probe/p16.lua = p15 + double/triple
clicks, modifier clicks, X1/X2, drags from the foot, lone release/drag, batched events, getmousepos dumps, a map listing; run-m.sh,
41 scenarios → M*-r10.log), PTF (nvim's REAL TUI in a pty, SGR mouse, pty-play2.py = pty-play.py + a TIOCSWINSZ resize step,
ptytap.lua; run-ptf.sh, 23 scenarios → PTF*-r10.log), the repo's tests/content/test_notes.sh on HEAD → own/test_notes-r10.log.
Evidence is nvim's own top/row/line/col, mode, buffer text and on_key's key/typed pairs; no kit render. Running notes: own/progress.md.)

## Verified (held)
- Verdict 9's must-fix 1, on HEAD, headless and in the real TUI: three notches (top 115, the cursor dragged to 147), then a LEFT
  CLICK ON THE TABLINE / the winbar → on_key sees the press, getmousepos() says winid 0 / line 0 → pen_back: "q" → `L156 |q|`, 147
  kept (the rows at <20,0>, <20,1>; M9r2 in Replace mode; the to-do's heading row → `46=[ ] abcq`); a side button on the tabline the
  same (M5t, PTF5t: `<X1Mouse>` → top 124 line 156, `L156 |q|`); the MIDDLE BUTTON with PRIMARY held → `147=x`, PRIMARY on 156, q
  after it (the row; RN2b's values gone); the control with no look identical (the rows' 'none' halves; PTF10).
- Should-fix 3: a bare `<MouseMove>` keeps the look — headless (the row; M13: a move then a tabline press in one batch → 156) and
  in the pty (PTF16: SGR 35-motion twice during the look → `key <MouseMove>` ×2, "qr" → 156 col 2).
- Nit 5 for single clicks: a press on grid rows 38/39 is swallowed by the expr maps before on_key — on_key then sees ONE
  `<LeftRelease>` (typed `<LeftMouse><LeftRelease>`), the look stays, nothing moves, the next key puts the pen back: insert (M8f,
  M11 in the to-do, PTF1 row 40, PTF1b row 39), Replace (M9r, PTF8), normal (M9n: rows 39 and 38, nothing moves), the right button
  (M9ri, PTF7: no popup menu), after a resize to 30 rows the new foot rows 28/29 are swallowed and row 27 places (M10c, M10b;
  PTF9/9b/9c in the pty: SGR rows 30/29 swallowed, 28 → line 150). A release or a drag with no press leaves the look (M3, M3b → `L156
  |q|`); a drag FROM the foot in the real TUI is ignored by nvim whole (PTF3: press+drag+release → 147 unmoved, "q" → `L156 |q|`).
- The paper rows: a click below the last line — look or not — lands on the last line (getmousepos line = 126, screenrow 21/38 → on
  the page; nvim puts the cursor on 126 col 0; "q" → 126), the view unmoved (M8, M8n, M8b).
- getmousepos() is current for every press: in the pty each press is processed before the next event arrives (PTF1/3/5/6/9: the
  position of the press itself); when events ARE queued together (one nvim_input: M6c foot press + wheel, M7/M7n foot press + drag +
  release) the maps and on_key see the LAST event's position — and so does nvim's own do_mouse, which places the cursor at that same
  spot (M7: line 133 at the drag's row 20): the swallow and nvim's placement never disagree.
- Wheel + click: three notches and a click in one write (PTF6) / one batch (M6) → the click's line (123), "q" there; a click then a
  notch (M6b) → the look noted at the click's line, "q" → 123 with the view where the notch left it (top 112).
- Modifier and side buttons on a LINE end the look where they point, as nvim places them: ctrl (PTF4/M4c: 123 + nvim's own E433/E426
  tag messages), X2 (PTF5l/M5l: 123); on the FOOT they are not swallowed (not `<LeftMouse>`) but on_key's off-page rule puts the pen
  back first (M4cf, M5f, PTF4f, PTF5: 156, "q" → `L156 |q|`). Shift-click never reaches nvim from foot (selection-override-modifiers,
  default Shift — man 5 foot.ini; our foot.ini leaves it).
- No regression around the fix in 41 + 23 scenarios: every typed key after a look lands on 156; the to-do's Tab/abc/look/foot click →
  `46:… [ ] abcq` (M11); v:errmsg empty and both on_key callbacks alive at every MSGS except nvim's own E349/E426 after ctrl-clicks.
- tests/content/test_notes.sh on HEAD, my run: 166 passed, 0 failed, rc 0 (own/test_notes-r10.log).

## Must-fix
(none)

## Should-fix
1. "A click on the foot never places the pen" (§7, the commit, the comment) is true of ONE click only. The maps swallow `<LeftMouse>`;
   nvim counts clicks itself ('mousetime' 500 ms, input.c) and the second press arrives as `<2-LeftMouse>` — unmapped (M0's listing:
   `map i <2-LeftMouse> -> none`) — so a double click on the footer is a word selection on the line under the pointer: in typing nvim
   goes through Ctrl-O into Visual mode and his next letters are commands (d, x, c, p, J, u, U, r, ~, q …), a triple click gives
   linewise Visual. Reproductions (the diary, 30 × "x<CR>", the pen on 156):
   - headless: three notches, DCLICKAT 39 20 → `key <LeftRelease> (typed <LeftMouse><LeftRelease>)`, `key <2-LeftMouse>`, `key <C-O>`,
     "mode v" at 156 col 0 (M1-r10.log; the pen was put back first, so here the hidden line is the paper = 156); with no look the same
     (M1n), from normal mode "mode v" (M1v), three clicks "mode V" (M1t), the to-do's footer "mode v" on item 46 (M11b).
   - the real TUI: `\x1b[<0;20;40M \x1b[<0;20;40m` twice in one write (PTF2-r10.log) or 450 ms apart (PTF2b) → "ev ModeChanged … mode
     v", "ev InsertLeave … mode v", `<2-LeftMouse>`; the Esc that follows returns to typing and the probe's next keys (":lua D(…)")
     went INTO THE NOTES as text (line 157). Normal mode: PTF14 → "mode v".
   With the pen mid-page (after his own scroll in normal mode) the line under the floats is text: the second press selects a word
   there and the page scrolls to it — nit 5's case again, by a double click. Map `<2-LeftMouse>`, `<3-LeftMouse>`, `<4-LeftMouse>`
   (and the right button's) with the same expr, or swallow by position in one place; a row: a double click on row 39 after "x<CR>"×30
   → mode "i", the pen on 156, no selection (headless is fine — assert the mode and the pen, type no `q` after it: verdict 9's nit 6).

## Nits
2. The words again (verdict 9's nit 4): the comment (notes.lua 388–389) says a click on "the foot's" rows "puts the pen back", §7 says
   it "acts from the pen, the page back to it" — a foot click is swallowed whole: the look stays, nothing moves (M8f/M9ri/PTF1: top 115,
   line 147 after the click), the NEXT key brings the page back; only the heading's rows and the side buttons put it back at the
   click. Say that (or make the foot click put it back too, so one rule holds for every click that places nothing).
3. Only `<LeftMouse>`/`<RightMouse>` in n and i are swallowed on the foot: ctrl-click (M4cf/PTF4f: nvim's E349 "No identifier under
   cursor" in a ui2 message), alt-click (M4af: nvim's blockwise selection, mode "" then waiting), the middle button in normal mode
   (M9m/PTF15: PRIMARY pasted at the hidden line — a new line 157 here, mid-page into hidden text), X1/X2 (M5f/PTF5: placed via
   on_key's put-back only during a look), and Visual/Select/Operator-pending modes (M9v: a foot click in `v` places the cursor on the
   hidden line and ends the selection; M9o: `d` + a foot click deletes to it). All pre-existing nvim behaviour, all outside typing or
   rare; the maps' mode list could be `{ "n", "i", "x", "s", "o" }` and the buttons `Middle` too — or leave them and say so in §7.
4. getmousepos()'s one true limit, for the record: it is the LAST queued event's position (os/input.c sets mouse_row/col at enqueue),
   so a press that reaches the map while a drag is already queued is judged — and placed by nvim — at the drag's spot (M7: foot press,
   drag to row 20 → line 133, "q" there). Only a busy neovim (a `vim.fn.system` in --tidy/--today) can queue them; nvim's own click
   lands at the same spot, so no words go astray that nvim would not put there. Nothing to do.
5. test_notes.sh's new rows pass the 'none' control by construction for the foot rows (the look is swallowed, so the result equals
   no-look whether on_key saw the press or not); the pty logs are the evidence that nothing reached on_key (one `<LeftRelease>` with
   typed `<LeftMouse><LeftRelease>`). Fine as a regression guard; said here so no one reads them as proof of the put-back.
