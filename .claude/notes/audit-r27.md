# T19m (b) — the OCD audit: every surface, both moods, three passes (pass 1 started 1 Nov 19:58)

Pass 1 = render and measure · pass 2 = side by side in both moods · pass 3 = fresh eyes after the
fixes. Judge only at 1× or zoomed by whole pixels — never from a downscaled sheet (1 Nov: a halved
index showed a "blank line" in Super+U's status pane that is not there at 1×) — and measure a
thing's whole ink box, never one row through it (1 Nov: the brightness tile read 11 px on row 14,
8 by its box — what bar-geometry.sh checks).

Renders: `bash tools/gallery.sh --out /dev/shm/r27/audit/pN --bin bin --repo-art` (27 surfaces, dark |
light sheets, boxes.json); text screens several keys deep: tools/kit.sh --tui … with
tools/kit-keys.py and --tui-wait; menus by a play (tools/kit-play.sh words).

Standing checks: every surface's box identical in both moods (gallery boxes.json; pass 1: 27 of 27).

**Pads (tools/audit-pads.py over the gallery, pass 1, 1 Nov 20:15 — paper from the hairline to the content's
ink box, L / R / T / B; /dev/shm/r27/audit/p1/pads.txt):** menus with a cursor 8 / 8 (the cursor's fill one
cell into the 16 pad — §4): launcher, dnd, power, timer · panels 16 / 16: calendar 16/16/20/16, downloads
16/16/20/16, sound 16/16/21/21, help 16/16/16/19 (the field's frame on the top row), Super+U 16/24/32/109 (the
pointer's column on the left, §7) · quick settings 18/18/20/19 (the dial's 304 square centred: the corner
pictures' own ink) · the level display 18/16/21/20, drives 18/16 (an icon's own air column) · notices
17/–/20/19 · foot windows: terminal 8/–/10/–, yazi 16/22/11/10 — the grid's leftover on the right and
bottom (pad=8x8 not centred: DELIBERATE, foot.ini says why — centred, the text jumped at every layout
change; pass 2 weighs foot's `center` against that, or whole-cell window sizes). Tops 20–21 against bottoms
16–20 are the rows' own ink (a word's x-height row 5, a key's frame on the row's last row), not the layout.
The launcher's bottom 19 dark / 18 light: an app's own icon read against two grounds (ink is "40 from the
ground"), not a geometry difference — the boxes are identical.

| surface | pass 1 (measure) | pass 2 (side by side) | pass 3 (fresh) | open findings |
|---|---|---|---|---|
| bar (left: torii, workspaces, layout) | 1 Nov: 3× zoom both moods — group gaps 12 px, cell gaps 4 px, seals' numerals inside the circle | | | |
| bar (centre: the clock) | 1 Nov: 3× — the red slashes, 日, gaps date→kanji→time 14 / 14 (bar-geometry.sh checks them) | | | |
| bar (right: memory, brightness, the head) | 1 Nov: whole-tile ink boxes — memory and brightness 8 / 8 paper to ink (a single row read 11: the bulb is wider on other rows — measure boxes, never one row), tiles 4 px hairline to hairline, 12 to the face, its hairline on x 1911; bar-geometry.sh (repo state, both moods): held | | | |
| launcher, launcher with a sum | 1 Nov: 1× dark sheet measured — heading icon x 43, the field's frame x 41, rows' icons x 50–52, the cursor bar from x 33: rows one cell (8 px) right of the heading's icon, the bar one cell left of it = §4's panel rule (heading icon at the content's first cell, a row's icon at cell 1, the cursor one cell beyond the content) — the same in power (2×) | | | (1) the kit's launcher listed Foot, Foot Client, Foot Server — a KIT artefact (live: Foot and Foot Server NoDisplay, footclient shown as "Terminal"): the kit now copies ~/.local/share/applications · (2) GRAMMAR: panels indent rows one cell under the heading (§4) while text screens put rows' icons under the heading's icon (§7, Super+U, restore) — pass 2 decides one rule for both, side by side |
| quick settings | 1 Nov: 1× both moods — every icon mirrored about the head's centre (x 193: corners 55/331, top and bottom centre, inner pairs 128/258) | | | owner's verdict pending (T19k) |
| sound panel, brightness, level display | 1 Nov (boxes.json): the level display's frame x 831–1089 → centred on 960 exactly (its shadow the column after) | | | |
| do not disturb, calendar, timer, drives, downloads, power | 1 Nov (boxes.json): the timer's frame 863–1057 → centred under the date (960); DND's ends at 1912 = 8 px from the screen's edge (§3); power's frame y 470–632 → centre 551, the middle of the area under the bar (553.5), x centred on 960 | | | research item (5): the optical centre (a hair above the geometric) for screen-centred popups — power, the launcher, Super+U, the level display: decide and measure in pass 2 |
| Super+/ (help) | 1 Nov: 1× dark — the keys one cell in from the heading's name (§4), descriptions on one column (x 249), 20 px rows, one blank row before the next heading, the screenshots note right-aligned on its rule with air before it: nothing off | | | |
| notices (plain, critical) | 1 Nov, px.py: each 74 px with its hairlines (inside 16 + 20 + 20 + 16 rows — the grid exactly), stacked 8 px hairline to hairline (§3's window gap), the shadow 2 rows; ink lead 20 / trail 19 = the em's own ink (descenders), not the layout; left: the icon 17 px in (16 pad + its own air column); the body under the summary's words | | | |
| Super+U — status pane | 1 Nov: 1× — rows on one column, continuation under its value (no blank line: the sheet misled) | | | |
| Super+U — backups: restore, the drive (new) | 1 Nov: kit, both moods — the list's icons under the heading's, days ending on the rule, the choice's keys in the words' ink and what they do muted; the drive's long path in pieces at / | | | |
| Super+V (clipboard), Super+W (wallpaper), Super+R (books), Super+N (notes) | 2 Nov (gallery t19m-p1, both moods: boxes identical; audit-pads): heading icon x 28 in all (content col 0 = x 25 from the hairline), rows' icons x 36 (col 1), names col 4, footer keys col 0. Super+V: the preview text was on col 2 and fzf's border ran 17–640 against the heading's rule to 632 — FIXED a8dfaad (under the names; our rule as its fixed first line). Super+W: the same fzf border — FIXED (the rule printed by the picker's own preview command, no fork; the picture made for one line less, its size unchanged). Super+R: the rail (border-left) from the top through the heading row, the heading's rule ending 20 px before it. Super+N: T21 (the master). | | | the search line's block cursor covers the ghost's first letter (all fzf screens: a beam?) |
| files (yazi), the file dialog (kawa-pick) | 1 Nov: the back mode inside a backup, both moods (kit-bk) | | | |
| calculator, git, terminal + prompt, btop | 2 Nov (gallery t19m-p1): calculator — "= 152.4 cm005083516811 s*c": a shorter answer kept a longer one's tail (no erase before copy's column) — FIXED 12e5b22; git — the repositories' list on the clipboard's columns; terminal — the prompt at the terminal's col 0 (x 9), the TUIs' content one cell in (x 25): T24's to settle; btop pads 11/12/11/9 (its own layout). | | | T24: the prompt's margin |
| lock, greeter, saver, boot splash, GRUB | not in the gallery: their own renders (tools/lock-shot …) | | | |
| GTK/Qt apps' themes, window borders and gaps | | | | |
| TUIs not in the gallery: torrents, downloads' list, kawa-file's parts | | | | |
