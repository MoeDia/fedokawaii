# T21 — Super+N as a notebook: the design brief (1 Nov 2026 22:58, the 21:47 pass)

## His words (round27-owner-notes.md 19, 39)
"a small spacing issue between the first note line and the header with jap icon that says 'notes' — deal with that
nicely and fully" · "make it look like a cool terminal old jap retro style notebook, lined perfectly nicely, and
opens as a rectangle for vertical space, not a box — redesign it fully, make it look like I am writing on a notebook,
TUI style, cool … the spacing on the top margin and bottom margin and all that stays consistent no matter how far I
have typed or how much scrolling is happening, super consistent." (The save flicker he names there: DONE, r27-21-bug6.)

## Today (gallery /dev/shm/r27/audit/p1/{dark,light}/notes.png; footclient -W 80x25: 660 × 521, a box)
- the heading "notes ──" on row 0, the first text row right under it: no blank line (§3 "heading, TUI: its line,
  then a blank line") — his spacing bug;
- the day heading shown raw ("## 2026-11-01 · Sun");
- no paper: a plain terminal ground; the footer on the last row, the text running into it when scrolled.

## Proven possible in the real foot + nvim (kit render /dev/shm/r27p/nb/k1-win.png, script .claude/notes/nb/rule-feasibility.lua)
- **Ruled lines on every row, full width**: a highlight with `underline = true, sp = RULE` as `line_hl_group` on
  every buffer line draws foot's 1 px underline across the WHOLE window row (past the text's end, and on wrapped
  continuation rows); the empty page below the last line ruled the same with `virt_lines` of window-wide spaces in
  that highlight (attached to the last line, as many as the window has rows) — the page is ruled to its foot
  whatever the length of the text. The rule sits on the cell's bottom rows (foot's underline offset): the words sit
  on their line, as on paper. Solid (§7: no dashed rule anywhere — no underdotted/underdashed).
- **Margins that never move** (his "super consistent"): the heading in the TABLINE (showtabline=2, one row, the
  editor's top), a blank WINBAR under it (the §3 blank line, fixed — the text can never scroll into it); at the
  foot: cmdheight=0 (ui2 shows messages elsewhere), a blank STATUSLINE as the bottom margin, the footer a one-row
  float on the last row (focusable=false, zindex under ui2's messages). Heading · blank · ruled text · blank ·
  footer — at every scroll position. (To prove: statuscolumn/virt_lines under ui2, the float on resize.)

## The design to render and grill (both moods, at 1× and zoomed; measure with px.py)
1. **Portrait, a page**: about 64 × 40 cells (530 × 818 px with foot's pads and the hairlines: a 1 : 1.54 page,
   near B5's 1 : 1.41 — try 60 × 40 too), centred with the optical centre (T19m item 5), kawa-warm's size and the
   dwl rule changed with it.
2. **The paper**: the rules in a faint ink of their own (edge2's family; dark and light each judged by eye and by
   contrast: visible as paper lines, never louder than `faint`), every 5th rule a shade stronger? (old school
   notebooks group rows; decide by render, not by taste alone) — and a vertical margin rule in vermilion at the
   text's left (statuscolumn: one glyph column, drawn on virtual lines too) — the old notebook's red margin.
3. **The header as a notebook's**: the heading (the notes icon, "notes", the rule) with the page's own fields
   right-aligned, as a printed notebook's top line: "No. 37" (the page number: days written) and the date in the
   §7 value grammar — words and figures only (kanji stays on the stamps, the lock and the clock seal).
4. **The day headings**: "## " concealed (conceal + extmark), the date in `accent_text` on its own rule — a day
   as a new heading line in the diary; the blank line before it kept by the tidy step.
5. **Typing feel**: the cursor a steady bar in `accent`; scrolloff so the line written is never on the last ruled
   row (a fixed number of rows of paper ahead of the pen).
Accept (with the master): kit renders both moods — every rule 1 px on the same row of each cell, no rule under the
heading's blank or the footer's blank, the margins identical at the top of the file, mid-way and at its end
(three renders), typing 40 lines (a play, frames) with no row jumping; test_notes rows for the tabline/winbar/
statusline/float and the virt_lines count = the window's rows; the Learn piece on Super+N corrected.

## The prototype (1 Nov 23:00): .claude/notes/nb/page-prototype.lua (MOOD=dark|light; render: tools/kit.sh --theme M
--tui "64x40:SCRIPT" where SCRIPT runs `MOOD=M nvim -u page-prototype.lua -n -i NONE FILE`)
Rendered both moods at 64 × 40 (531 × 820 px): it already reads as a notebook — the portrait page, the faint rules
(edge2) on every row to the page's foot, the vermilion margin rule (statuscolumn "  │ ", drawn on the virtual rows
too), the header "▤ notes ──── No. 37   2026 . 11 . 01" in the tabline, the fixed blank winbar, the day lines in
accent_text, the blank statusline, the footer float on the last row. Grill list for the build:
- the footer float's last cell shows NormalFloat's ground (winhighlight Normal:Normal, or width W-1);
- the header's date grammar: "2026 . 11 . 01" (a printed notebook's Date field) against the bar's DD/MM/YYYY with its
  red slash — one date grammar for the desktop (decide: the bar's);
- the margin rule's column against §7 (the heading's icon at column 0 = x 25; the rule glyph sits in that column at
  x 28) and the words' column (x 41) — measure, then decide where the paper's margin belongs;
- every 5th rule a shade stronger, or not; the rules' ink measured in both moods (paper lines: seen, never loud);
- the blank winbar and statusline rows unruled — right (a printed page's head and foot margins) — check at the end
  of a long file and mid-scroll (three renders).

## How to rule the lines — measured (1 Nov 23:03)
- REJECTED: the underline in `Normal` + `EndOfBuffer` (no extmarks): the text rows came out UNRULED, and the empty
  rows were ruled straight through the margin column (EndOfBuffer fills the statuscolumn too).
- REJECTED: a decoration provider setting `line_hl_group` ephemerally in on_line: the rows were not ruled.
- KEPT: persistent extmarks, `line_hl_group = KawaRule` on every line + one `virt_lines` block (the page below the
  last line). Cost measured headless (nvim 0.12, -u NONE): 14 000 lines (2 000 days of notes) → 3.9 ms for the
  whole pass; his notes.md has 118 lines today. So: the whole pass at open and on TextChanged, and on_lines
  (nvim_buf_attach) for the rows a keystroke touches — never a per-keystroke full pass on a long diary.

## The build on branch t21 (1 Nov 23:10–23:25, ~/repos/fk-t21) — WIP, not on main
notes.lua: the heading in the TABLINE (showtabline 2), a blank WINBAR under it; NO statusline (laststatus 0): two
floats over the window's last two rows — a blank row of paper, then the footer (muted) — and scrolloff 2, so the pen
is never under them; the margin a STATUSCOLUMN "  │ " (the rule in KawaMargin = accent; the words at the fourth column
as before); every line ruled (line_hl_group KawaRule: underline, sp = edge2) and the page below the last line ruled
(virt_lines, the window's rows), laid again only when the line count changes; a day's line ("## …") its "## " concealed
(conceallevel 2, concealcursor n) and the date in KawaDay (accent_text on its rule). kawa-warm: notes 80x25 → 64x40.
Rendered in the kit (renders and scripts: /dev/shm/r27/t21/): dark and light, a short page (opens on today's heading at
the top of the page — the history above it, as before), a long one scrolled mid-file (dark-long3: heading · blank ·
36 ruled rows · blank · footer — the same rows as at the top of the file), and at the end (dark-long2: the last line
near the top — nvim counts the ruled page below as part of the last line, so the end of the notes is always a fresh
page; the pen goes down it as he writes). Found on the way: at -u time the file is not read yet (line count 0) — rule()
skips an unloaded buffer, BufWinEnter lays the rules.
NEXT on t21: test_notes rows (the tabline/winbar heading, no statusline, the two floats and their rows on resize, the
rules' count, the concealed day mark), test_warm's 64x40, the to-do page rendered on the same paper, the header's
notebook fields (No. · the date in the bar's grammar) decided by render, the grill (both moods, zoomed: the rule's row
in the cell, its ink against faint, the margin's x against §7), a typing play (frames: no row moves while typing),
then merge into main through the suite and the master.
- 23:23–23:27 (t21, 2nd commit): the footer float shows the file's name as it is (the statusline's %-escaping
  gone with the statusline); the heading's rule drawn out in the tabline (the tabline fills %= with spaces, not
  wbr's ─ — my first build had lost the rule, the render showed "notes" with none; test_notes caught it too), again at
  each resize; test_notes 116/0 (the page's columns, the tabline heading full to its row, the blank winbar, the two
  floats' rows and words, laststatus 0 · cmdheight 0 · scrolloff 2, the to-do's heading and footer), test_warm 88/0
  (64x40). Renders both moods mid-file: /dev/shm/r27/t21/{dark,light}-long3-win.png. GRILL first: the paper's rules
  run to the window's last column while the heading's rule stops two columns short — one right edge for both.
- 23:50–23:53 (t21, 3rd commit): GRILL 1 DONE — one right edge: the heading's rule now runs to the page's edge, where the
  paper's rules end (a notebook's lines run to its edge; the left keeps its margin and the vermilion rule). Measured
  (px.py on /dev/shm/r27/t21/dark-edge-win.png, 64 × 40): the heading's rule x 97–520 on y 18 (its row's tenth pixel,
  §3); the page's rules x 41–520, every 20 px from y 67 to y 767 (rows 2–37: 36 ruled rows), each on its cell's 19th
  row; the winbar's row and the paper row above the footer unruled; 8 px of paper (foot's pad) from 520 to the hairline
  on 529. test_notes 116/0. NEXT grill: descenders (g, p, y) against the rule on the cell's 19th row, zoomed, both
  moods; the rules' ink in light (edge2 #d7bc8c on #e8e3c2) against faint.
- 23:51 GRILL 2 DONE — descenders against the rule (zoom ×6, /dev/shm/r27/t21/desc-zoom.png, "line one of day 4"): the
  ink on y 172–186 (the y's tail lowest, on the cell's 18th row), the rule on y 187 (the 19th): they meet, never overlap;
  the baseline 4 px above the rule — the words stand on their line, as on paper. Light: the same geometry (one font).
- 23:53–23:58 the to-do on the paper (renders /dev/shm/r27/t21/{dark,light}-todo-win.png): the heading "to-do ───", the margin
  rule, the ruled page, its footer — right. FOUND and FIXED: with conceallevel 2 (for the day lines) markdown's own
  tree-sitter conceal folded each "[ ]" into one cell, and the box overlay (4 cells) then hid each item's first two
  letters ("new the passport") — conceallevel is now 2 on the notes only, 0 on the to-do.
  OPEN (next pass, before the merge): in the LIGHT kit the open items' words are #e7cfa1 — the DARK theme's text — on the
  light ground, barely readable; the done item (KawaDone: explicit muted fg) is right; the SAME in main's live notes.lua
  (light-todo-main-win.png, 80 × 25). vim.inspect_pos on the word: only @spell; Normal's fg = #122625 (light text). So
  the cells reach foot as "default foreground" and foot draws its own default — dark in the kit's light run? Check: the
  kit's foot colours for --theme light (a kit artefact) vs the live PC in light (his screen): a bug only if the live one
  shows it. Either way make the words explicit: give the to-do's text (and the notes') an explicit fg (KawaText from
  C_TEXT) so no cell depends on the terminal's default — t21's notes text already renders right (each line carries
  KawaRule, so its cells are never "default").
