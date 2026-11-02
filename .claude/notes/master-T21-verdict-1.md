VERDICT: FAIL
(the master, T21 — 2026-11-02 00:38 +04, checkout /dev/shm/r27w-suite-42892e1 = main 42892e1; own renders in /dev/shm/r27/master/T21/own/)

## Verified (held)
- Geometry, px.py on the evidence crops (530 × 818: frame 1 px + foot's pad 8 px, cells 8 × 20): heading rule y 18 (row 0's 10th px)
  x 97–520; page rules x 41–520 (the words' column to the page's last column — ONE right edge with the heading), one per row at
  y 67, 87, … (each cell's 19th px), rows 2–37; row 1 (the winbar) blank, unruled; rows 38–39 the blank float and the footer (its text
  at x 25, two columns in, as every footer's); the margin rule x 28 (col 2) in ACCENT. Inks = the palette (themes/*/colors.sh): dark
  text #e7cfa1 / rule #3c2f22, light text #122625 / rule #d7bc8c; the day line ACCENT_TEXT; the footer MUTED. Descenders meet the
  rule, never cross it (desc-zoom: ink to the 18th px, the rule the 19th).
- The typing play: regress-main.log rc 0 (both themes: head, foot and margin unchanged in every frame, rules whole, one-row scrolls,
  3 ruled rows ahead of the pen); regress-old.log fails on the old build ("not ruled") — the check bites. test_notes 116/0.
- An outside change of the file with the same line count keeps every rule extmark in place (headless probe, :checktime).
- The first `--shown` start of a day (kawa-notes --today appends the heading): right — own/shown/tui.png, the pen on its line, ruled paper to the foot.

## Must-fix
1. conceallevel 2 on the notes hides text he types — a regression of this change (before it the notes concealed nothing).
   notes.lua:171 `conceallevel = is_todo and 0 or 2` with tree-sitter markdown active by default (probe: TS=true, ft=markdown) and its
   conceal queries. Proven headless (vim.fn.screenstring after redraw, the frozen notes.lua): `[ ] a task typed in the notes` →
   `  a task typed in the notes` (the box vanishes), `[a link](https://example.org/x)` → `a link` (the URL gone), `**bold** and *em*
   and `code`` → `bold and em and code` — in normal mode on every line but the cursor's (concealcursor n). The page shows other text
   than the file: against his "super consistent" and the task's scope (a DAY line's "## " alone shown as the date). The author met
   exactly this on the to-do ("the box would hide two letters") and switched conceal off there instead of switching markdown's own
   conceal off; the notes kept it. Fix: the page needs no markdown highlighting — in page(): `vim.treesitter.stop(b)` and
   `vim.bo[b].syntax = ""` (or `vim.g.markdown_syntax_conceal = 0` plus the treesitter stop), conceallevel 2 kept for the KawaDay
   extmark only, the to-do then on the same settings (one page); a test row: a `[ ]` line, a link and `**x**` render as typed.
2. The second `--shown` start of a day puts the pen UNDER the footer with no paper ahead of it. Path: Super+N when the warm notes
   window is not running (after :q, a crash, before --start parked it) → kawa-warm --open → `kawa-notes --inside notes show` →
   bin/kawa-notes:35–37 `nvim … -c 'lua kawa_notes_shown()'`; today's heading already in the file, so --today changes nothing and the
   only edit is set_lines (notes.lua:335) + startinsert!. Proven: own/shown2/tui.png (long.md + today's heading + "already written
   today", that exact start): the last visible row (37) is the day heading, "already written today" lies under the blank float (row
   38), the cursor is drawn on the footer's row (39) at "~/N|otes" — his first line of the day would be typed invisibly under the
   footer. Cause: rule() runs only from TextChanged/TextChangedI (notes.lua:218); a change made by a startup `-c` precedes
   TextChanged's first baseline, so the 40 virt_lines stay on the old last line and scrolloff has nothing below the new one (the same
   with `-c 'call append("$","")'`: own/longdark/tui.png). The kit play passed only because `warm` parks the window first and shows it
   through the socket (an RPC inside the main loop, where TextChanged fires). Fix: lay the rules from the change itself —
   `nvim_buf_attach(b, false, {on_lines = …})` scheduling rule(b) (fires for every change, any mode, startup too) — or a forced
   rule(buf, true) at the end of kawa_notes_shown / notes_open / todo_open; add this start to test_notes (the virt_lines' row == the
   last line; the cursor's screen row ≤ lines − 6) and a --shown-on-a-written-day play to tools/regress/notes-page.sh.

## Should-fix
3. rule() skips a buffer whose line count did not change (notes.lua:200): a line edited into or out of a day heading in place keeps its
   old look, and typing at the end of a day line leaves the new characters outside the KawaDay extmark (end_col fixed at lay time);
   re-lay the touched line on every change (one line is cheap), the whole page on a count change.
4. The short-file open (light-open-win) shows yesterday's items with their day line scrolled off above — the "context" starts mid-day.
   When the file is shorter than the page, open with the last day line at the page's first row: one first impression, the same every day.
5. The to-do opens in normal mode with the cursor on the first item's first letter (dark-todo-win): on a page otherwise typed into,
   the first key goes to normal mode; open on the last item, typing, like the notes ("the same page").

## Nits
6. The floats' row of paper (row 38) is unruled while rows 2–37 are ruled: say so in §7 ("a row of paper" reads as ruled paper).
7. notes.lua:212 lays `vim.o.lines` virt rows (40) where the window has 38 text rows — harmless; name the window height.
8. The suite log (/dev/shm/r27p/suite-42892e1.log) was still running when this was written (no failed file so far); the verdict rests
   on test_notes 116/0, regress-main rc 0 and the renders above, not on it.
