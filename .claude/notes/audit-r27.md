# T19m (b) — the OCD audit: every surface, both moods, three passes (pass 1 started 1 Nov 19:58)

Pass 1 = render and measure · pass 2 = side by side in both moods · pass 3 = fresh eyes after the
fixes. Judge only at 1× or zoomed by whole pixels — never from a downscaled sheet (1 Nov: a halved
index showed a "blank line" in Super+U's status pane that is not there at 1×).

Renders: `bash tools/gallery.sh --out /dev/shm/r27/audit/pN --bin bin --repo-art` (27 surfaces, dark |
light sheets, boxes.json); text screens several keys deep: tools/kit.sh --tui … with
tools/kit-keys.py and --tui-wait; menus by a play (tools/kit-play.sh words).

Standing checks: every surface's box identical in both moods (gallery boxes.json; pass 1: 27 of 27).

| surface | pass 1 (measure) | pass 2 (side by side) | pass 3 (fresh) | open findings |
|---|---|---|---|---|
| bar (left: torii, workspaces, layout) | 1 Nov: 3× zoom both moods — group gaps 12 px, cell gaps 4 px, seals' numerals inside the circle | | | |
| bar (centre: the clock) | 1 Nov: 3× — the red slashes, 日, gaps date→kanji→time 14 / 14 (bar-geometry.sh checks them) | | | |
| bar (right: memory, brightness, the head) | | | | |
| launcher, launcher with a sum | 1 Nov: 1× dark sheet measured — heading icon x 43, the field's frame x 41, rows' icons x 50–52, the cursor bar from x 33: rows one cell (8 px) right of the heading's icon, the bar one cell left of it = §4's panel rule (heading icon at the content's first cell, a row's icon at cell 1, the cursor one cell beyond the content) — the same in power (2×) | | | (1) the kit's launcher listed Foot, Foot Client, Foot Server — a KIT artefact (live: Foot and Foot Server NoDisplay, footclient shown as "Terminal"): the kit now copies ~/.local/share/applications · (2) GRAMMAR: panels indent rows one cell under the heading (§4) while text screens put rows' icons under the heading's icon (§7, Super+U, restore) — pass 2 decides one rule for both, side by side |
| quick settings | 1 Nov: 1× both moods — every icon mirrored about the head's centre (x 193: corners 55/331, top and bottom centre, inner pairs 128/258) | | | owner's verdict pending (T19k) |
| sound panel, brightness, level display | 1 Nov (boxes.json): the level display's frame x 831–1089 → centred on 960 exactly (its shadow the column after) | | | |
| do not disturb, calendar, timer, drives, downloads, power | 1 Nov (boxes.json): the timer's frame 863–1057 → centred under the date (960); DND's ends at 1912 = 8 px from the screen's edge (§3); power's frame y 470–632 → centre 551, the middle of the area under the bar (553.5), x centred on 960 | | | research item (5): the optical centre (a hair above the geometric) for screen-centred popups — power, the launcher, Super+U, the level display: decide and measure in pass 2 |
| Super+/ (help) | 1 Nov: 1× dark — the keys one cell in from the heading's name (§4), descriptions on one column (x 249), 20 px rows, one blank row before the next heading, the screenshots note right-aligned on its rule with air before it: nothing off | | | |
| notices (plain, critical) | 1 Nov, px.py: each 74 px with its hairlines (inside 16 + 20 + 20 + 16 rows — the grid exactly), stacked 8 px hairline to hairline (§3's window gap), the shadow 2 rows; ink lead 20 / trail 19 = the em's own ink (descenders), not the layout; left: the icon 17 px in (16 pad + its own air column); the body under the summary's words | | | |
| Super+U — status pane | 1 Nov: 1× — rows on one column, continuation under its value (no blank line: the sheet misled) | | | |
| Super+U — backups: restore, the drive (new) | 1 Nov: kit, both moods — the list's icons under the heading's, days ending on the rule, the choice's keys in the words' ink and what they do muted; the drive's long path in pieces at / | | | |
| Super+V (clipboard), Super+W (wallpaper), Super+R (books), Super+N (notes) | | | | |
| files (yazi), the file dialog (kawa-pick) | 1 Nov: the back mode inside a backup, both moods (kit-bk) | | | |
| calculator, git, terminal + prompt, btop | | | | |
| lock, greeter, saver, boot splash, GRUB | not in the gallery: their own renders (tools/lock-shot …) | | | |
| GTK/Qt apps' themes, window borders and gaps | | | | |
| TUIs not in the gallery: torrents, downloads' list, kawa-file's parts | | | | |
