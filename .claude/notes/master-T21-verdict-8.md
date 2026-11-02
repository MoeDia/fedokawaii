VERDICT: FAIL
(the master, T21 re-review 8 — 2026-11-02 16:05 +04, narrow: verdict 7's findings and what their fixes could have disturbed. Reviewed:
b583de2's notes.lua (= HEAD b38ad89 = the working tree, cmp'd) and the 2445edf..b583de2 diff of notes.lua and test_notes.sh. Probes in
throw-away homes under /dev/shm/r27/master/T21/own/ — the r7 archive's homes with HEAD's lua swapped in (home-h for the H-series; home-h3,
its stub kawa-notes really tidying on --tidy, for the hunt); nvim v0.12.6; EVERY run under `env -u WAYLAND_DISPLAY -u DISPLAY
DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent XDG_RUNTIME_DIR=own/xdg|run`, nothing of his touched. Reruns: probe/run-h-r7.sh → H*-r8.log
(32 scenarios, each diffed against r7's). New: probe/p13.lua (p10's tracer plus steps that are NOT keys, as the live window gets them:
HIDE/SHOW = kawa_notes_hidden()/shown() called from Lua as kawa-warm's --remote-expr does, PASTE = nvim_paste as foot's bracketed paste,
CLICKn, S-/C-wheel, WAITn, MSGS = v:errmsg + the count of on_key callbacks; a second on_key tap printing every key the mechanism is
offered) via probe/run-r8.sh → R*-r8.log, RX*-r8.log (verdict 7's X-series on HEAD's own mechanism); probe/pty-ctrlc.py → pty-ctrlc.out
(nvim's real TUI in a pty); R14-old.log (R14 on 2445edf's lua); the repo's tests/content/test_notes.sh → test_notes-r8.log. Sources read:
nvim v0.12.6 src/nvim/tui/input.c (focus → "nvim_ui_set_focus", a paste → "nvim_paste", keys → "nvim_input") and src/nvim/os/input.c
(process_ctrl_c). All evidence is nvim's own top/row/line/col, buffer text and events, no kit render.)

## Verified (held)
- Verdict 7's must-fix 1, on HEAD: two notches at the foot → `L156 |qr|`, the view back (H5a-r8: "after qr top 124 row 33 line 156 col 2
  … pushes 11"), three (H5b), ten (H5c), twenty (H5e, RX2), the fresh path (H5d, H5f); mid-page one notch → `L137 |qrx|` (H24-r8);
  after Esc's yield → `L153 |xqr|` (H25-r8); `u` after Esc removes exactly "qr" (RX1: `L156 ||`); `<Up>` after two notches → `L155 |qx|`
  (RX6). The three rows pass here (test_notes-r8.log: 148 passed, 0 failed, rc 0) and fail on 2445edf as the brief's log says.
- Should-fix 2: H16-r8 — the pause's write during the look leaves the page: "ev TextChangedI -> top 121 row 36 … pushes 6" (r7: top 124,
  pushes 9); the same with the pen dragged (R2: "ev BufWritePost … ev TextChangedI -> top 115 … pushes 6"); a 1.3 s wait then "qr" →
  `L156 |zqr|` (R10); the row "-3 0 0 0 0 0".
- Nit 3, in a real pty only: the harness cannot exercise it — nvim's process_ctrl_c (os/input.c) turns an nvim_input Ctrl-C into got_int
  before mappings, so H23-r8/R25 show on_key offered `<C-C>`, no InsertLeave, the pen left on row 36 — but nvim's own TUI in a pty gives
  "key <Esc> mode i / InsertLeave fired" (pty-ctrlc.out; maparg("<C-c>","i") = "<Esc>"). Nit 4: the titles say what the rows hold.
- No regression: H1/H1b/H1c (R, gR), H2, H3/H3b, H4a/b/c, H6/H6b, H7/H7b, H9, H11a/b, H12, H13, H23 byte-identical to r7's logs; H10
  differs only in the order of one TextChanged (the same `L155 |qx|`). Around on_key: ten notches then Enter → the new line 157 "y" (R1),
  Backspace takes the "z" on 156 (R2), `<Up>` → 155 (R3); the wheel down ×10 mid-page → `L137 |qrx|` (R5); shift-/ctrl-wheel are looks
  too (R6/R6b: `L156 |qr|`); the to-do's own `<CR>`/`<BS>` after a look there (R7: "[ ] abc" / "[ ] def"; R7b: "[ ] a"); Tab both ways
  after a look (R7c, H6, H6b); two looks in one insert (R20); Ctrl-W (R21); a 4-line page (R23); a resize during a look (R24); replace
  mode on a line with text (R13: `L155 |qr|`). The look never leaks into normal mode: after Esc the wheel and Ctrl-Y yield the pen as his
  (R15: 150 → 146, `L146 |qx|`), `i q` writes where the page is (R16: `L150 |qx|`). v:errmsg empty and our callback alive at every MSGS
  ("errmsg || on_key callbacks 2": RX1, R8, R8b, R25b); no typed key left the pen below row 33 (a sweep of every after-line in typing).
- Completion with a look (R14 vs R14-old): the drag ends the completion in both; Ctrl-Y then copies the char above — on HEAD onto the
  pen's line (`L156 |hello |`), on 2445edf into line 150 (`L150 |hello  world|`). Better now; neovim's own.

## Must-fix
1. A look outlives the window. `look` is dropped only by a key, and Super+N moves the pen with none: kawa-warm --hidden/--shown call
   kawa_notes_hidden()/shown() by --remote-expr (bin/kawa-warm:70,81), the focus change arrives as nvim_ui_set_focus (tui/input.c:
   handle_focus_event → rpc "nvim_ui_set_focus"; my FOCUSLOST/FOCUSGAINED steps reached neither on_key nor an autocmd — R9, R9b), so
   nothing passes vim.on_key between hide and show. Notes: "hello", two notches, hidden, shown (the fresh line 157, the pen on it), the
   first key puts the pen back on 156 col 5: `L156 |helloqr|`, `L157 ||`, the pen on row 32 (R8d-r8.log, the stub tidying the file; R8,
   R8c, H8a-r8, H8b-r8 the same with "" on 156: `L156 |qr|`, `L157 ||` — verdict 7 held H8a/H8b with `L157 |qr|`: a regression of this
   fix). The to-do: Tab, "abc", two notches (the look {46,7} in the to-do's numbers), hidden, shown → the notes, "qr" → `L46 |qr|` INSIDE
   day 11 of the diary, the view jumped to top 28 row 19, the fresh 157 empty (R8b-r8.log). The pen placed by the program —
   kawa_notes_shown, notes_open, todo_open (or BufWinEnter and InsertLeave) — must drop the look. Rows: both cases, calling the functions
   from Lua as kawa-warm does, never through a <Cmd> key (H8c: a key clears it, such a row passes blind).
2. "a click then goes where it points" (the comment above on_key, the ledger) is false past one notch at the foot: the restore's
   nvim_win_set_cursor runs update_topline before the click resolves, so the click lands on the restored view. Three notches (top 115),
   a click on grid row 10 → line 127 (R4-r8: "after CLICK10 top 119 row 9 line 127"; the same click on the same view in normal mode →
   line 123, R4d); mid-page one notch (top 102) → 113 where the pointer was on 110 (R4c); only one notch at the foot is right (R4b:
   129). His next keys go there ("q" on 127). A mouse key must end the look without the restore: the click sets the pen itself.
3. A paste during a look goes into the dragged line: foot's paste is nvim_paste (tui/input.c: tinput_flush → rpc "nvim_paste" while
   pasting; only keys go through nvim_input), no key passes on_key, and follow() is silenced by the look. Two notches, then a paste of
   "one\ntwo" → `L150 |one|`, `L151 |twox|`, 156 untouched (R17-r8.log). vim.paste (the hook neovim gives for exactly this) must put the
   pen back first — or end the look — before the text goes in. Row: nvim_paste from Lua during a look, the text on the pen's line.

## Should-fix
4. Ctrl-O after a look acts from a yielded pen: on_key restores it (top 119), then Ctrl-O's InsertLeave sees top < seen_top (124, the
   look's start) and yields the pen five lines up before the command runs — three notches, `<C-o>`, `k`, `q` → `L150 |qx|` (R11-r8.log:
   "ev InsertLeave -> top 119 row 33 line 151 … mode niI"); without a look `k` gives 155; `<C-o>dd` would take line 151. The restore's
   scroll is not his: seen_top must follow the restore (or follow() run as the pen is put back).
5. §7 (docs/design-system.md 404–413) still says only "A scroll he makes is his — Ctrl+Y, Ctrl+B, the wheel move the page and the pen
   yields into its room": nothing of the look in typing (the pen kept, any key acting from it, Esc ending it where the page is). Verdict
   7 asked for the choice stated there; the design system is the single truth, and that sentence now describes normal mode only.

## Nits
6. The restore splits the insert's undo block: "ab", two notches, "cd", Esc, `u` → `L156 |ab|` (R12); without the look `u` → `L156 ||`
   (R12b). As an arrow key would; say so, or join the blocks.
7. Ctrl-C's mapping cannot be held by a row written with nvim_input (process_ctrl_c); the ledger should say it is proven in a pty
   (probe/pty-ctrlc.py), or hold it with one.
8. Completion ends when a look drags the cursor, and Ctrl-Y then copies the char above (R14: `L156 |hello |`). Neovim's own; a word in
   the comment at most.
