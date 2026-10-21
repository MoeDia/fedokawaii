# Fedokawaii — the design system

One visual language for everything the desktop draws: the panels, the dropdown menus, the
terminal screens, the launcher, the notices, the lock and login screens, and the handbook.
The source of truth is quick settings' sound panel (`kawa-panel --sound`), whose shapes
this file names. Anything new is built from these parts and nothing else.

## 1. Palette (tools/build-themes.py → themes/{dark,light}/*)

| token | role |
|---|---|
| `surface` | the ground of a panel or menu |
| `key` | the fill of a tile or a key button at rest |
| `edge` | a tile's 1 px frame at rest |
| `edge2` | a seal's 1 px frame, the stitched rules, an unlit square |
| `faint` | words that are not there yet ("none") |
| `muted` | secondary values; the panel's outer 2 px frame |
| `text` | names and rows |
| `strong` | a lit tile's name; emphasis |
| `accent` | the cursor's fill (keyboard), the workspace seal, a bar seal stamped (lit) — the only filled vermilion |
| `accent_text` | kanji in seals, a hovered glyph and name, the active state of a bar icon |
| `accent_lo` | the dim vermilion of an unlit seal on a filled row |
| `text_on_accent` | ink on the accent fill |
| `asagi` | lit meter squares (the one cool colour: levels) |

Colours come only from these tokens; no literal colour anywhere, in either theme.

## 2. Type

- UI (panels, menus, bar, launcher, notices, lock and login): **Sumi UI** at 12 px — Fusion
  Pixel 12px Mono ja with each straight upright stroke of a letter or digit doubled to two
  pixels (tools/build-ui-font.py), wherever a whole pixel of paper stays beside it: a
  one-pixel counter is never closed, so M, W, m keep their thin strokes; diagonals,
  horizontals, signs and kanji/kana are as drawn. Every glyph keeps its advance and its ink's
  left and right edges, so every width, pad, seal and gap below is the same as in Fusion Pixel
  (named after it in each font list, the fallback while Sumi UI is not built). Icons from
  **Sumi Icons** at the same size. One size; hierarchy by colour and position, never by size.
  (Chosen over a larger size — Fusion Pixel has no cut above 12 px that fits the 20 px row —
  and over stronger inks: `text` is already ~10:1 on `surface`; the strokes were the thin part.)
- Terminals: the same design in its 10 px cut, as **Sumi Term** — Fusion Pixel 10px Mono ja
  with each upright stroke half a font pixel heavier (tools/build-term-font.py: three screen
  pixels at 20 px instead of two, for reading) — at 20 px (foot:
  2× its grid, a 10 × 24 px cell on 24 px lines — two pixels of the font of air between
  lines, the heavier strokes kept apart — 188 × 43 cells on a 1080p screen), icons
  from Sumi Icons Term, built on that grid (a 10 × 10 icon: two cells, one line). Only whole
  multiples of a cut's grid are crisp (12 px: 12, 24, 36, 48 · 10 px: 10, 20, 30, 40); foot's
  zoom steps by 10 px, and a screen at scale 2 (2160p) draws it at 40.
- **Display size** — the one exception to "one size": the UI face at a whole multiple of
  its grid, ×4 (48 px) or ×5 (60 px), never smoothed (no antialiasing, no hinting:
  `system/60-fedokawaii-pixel.conf` — or a picture drawn nearest-neighbour at that multiple),
  so every pixel of the font is a sharp square. Only for the clock of the lock and login
  screens (60 on the lock, 48 on the login screen; AM/PM beside it at 12 px, on its baseline) and the boot splash. Nowhere else.
- No scaling anywhere at 1080p: dwl's monitors are at scale 1, and nothing sets GDK_SCALE,
  GDK_DPI_SCALE, QT_SCALE_FACTOR or Xft.dpi — sizes are the pixels written here.
- Words are lower case (proper names keep theirs: Steam, Bluetooth, LG ULTRAGEAR).
- Numbers are tabular and right-aligned in a column.

## 3. Grid (pixels, at 1×)

| name | value | use |
|---|---|---|
| frame | 2 | the panel's outer frame, `muted` |
| pad | 12 | inside the frame, all round — measured to the ink: 12 px of paper between the frame and the first and last pixel drawn, above and below too (a row's text sits 4 px inside its 20 px row: the panel's height is cut to its ink) |
| gap | 6 | between tiles, keys and a glyph and its word |
| line | 12 | a line of text |
| row | 20 | a list row, a meter's row |
| seal | 23 × 23 | a kanji in its 1 px frame (11 px kanji, 6 px all round) |
| rule | 21 | a section's rule band: 10 px, the stitch, 10 px |
| section | 18 | from a part's last row to the next seal |
| key | 24 high | a key button |
| tile | 88 × 64 | a quick-settings tile; three a row = 276, the content width |
| wide tile | 135 × 64 | two a row (6 gap = 276): a short last row of tiles, never a lone one |
| content | 276 | the inner width of a panel (304 with pad and frame) |
| lock | 464 | the lock screen's panel, the one large panel: five tiles wide (5 × 88 + 4 × 6), 24 px of pad (two pads), 516 with the frame; its clock at 60 px |

## 4. Parts

- **Panel**: `surface` ground, 2 px `muted` frame, 12 px pad to the ink all round, square
  corners. Never rounded, never a shadow. Sized to its content (a slider: its glyph's ink and
  its last square on the content's edges).
- **Heading**: a seal (1 px `edge2` frame, the kanji in `accent_text`), 6 px, the name in
  `text`, 6 px, then the **stitch** — 3 px on, 2 px off, 1 px high, `edge2`, through the
  seal's middle. The stitch starts at name+6 with a whole dash and ends on the last whole
  dash; it may stop up to 4 px short of the edge (the content's edge, or 6 px before a value,
  whose ink ends on that edge). Every heading starts alike; the same rule wherever a stitch
  is drawn (the rule between parts starts at the content's left edge). Every part of a panel
  or menu opens with one. Each part has its
  own kanji (音 sound · 出 output · 入 input · 明 brightness · 盤 drives · 受 downloads · 暦 calendar · 時 time ·
  天 weather · 電 power · 系 system · 鍵 keys …), one character, meaning the part.
- **Row**: 20 px high; at x+6 a glyph (placed by its ink: every row's glyph starts on the same
  pixel, whatever its side bearing) (an icon, or a check: ▣ chosen, □ not), 6 px, the
  name in `text`; a detail in a column of its own (12 px after the longest
  name); a value in `muted`, right-aligned in a column 12 px after the widest words — a menu is
  as wide as its content, never stretched to put a gap before the value. A long name is shortened at its source
  (a human name), never cut with "…".
- **Key button**: 24 px, `key` fill, 1 px `edge` frame, icon + name centred by their ink. Two or
  three share a row with 6 px between, the row the whole content width. An icon-only key (the
  glyph alone, no name) is a square, 24 × 24, its glyph centred by its ink; the named keys of
  its row share the rest (quick settings' bottom row: 120 · 120 · 24).
- **Tile**: 88 × 64, `key` fill, `edge` frame; its seal top right — stamped (2 px `accent_text`
  frame, kanji `accent_text`) when on, faint outline when off; its icon top left, its name
  and state below.
- **Meter**: its glyph, its name, then 12 squares of 10 × 8 with 2 px between, lit `asagi`,
  unlit `edge2`; muted: the lit ones hollow.
- **Rule between parts**: the stitch alone, full content width.
- **The launcher's heading** (fuzzel, which draws its prompt as one run of text in one
  colour): the same heading, as two glyphs of a colour font that keep their own inks in any
  run — the seal (frame `edge2`, kanji `accent_text`) as the prompt, the name (`text`) and
  the stitch (`edge2`) as the placeholder; one font per theme (Sumi Seal Ink and Paper,
  `tools/build-seal.py`, its letters Fusion Pixel's). Seal at the content's corner, the first
  row 6 px under it, 12 px of pad all round. Where fuzzel cannot follow: the stitch ends at
  its text margin, 6 px short of the content's edge; while you type, the name and stitch give
  way to the typed words (Fusion's own, a pixel higher than the drawn name).
- **Launcher icons**: 18 × 18 in a column at x 20 (row's x + 6). A window program with an
  icon of its own (Brave, LibreOffice, Xournal++, Steam, LocalSend, Syncplay, OpenRGB, LACT)
  shows that icon, its ink the artwork's own — a project's margin is kept, never
  trimmed. Every other entry — a program in a terminal, a page in Brave, a helper of ours —
  shows an **app seal**: the 18 × 18 square, a 1 px `edge2` frame, one kanji meaning the
  entry in `accent_text` (Fusion Pixel 12, its ink centred: 2 px of air left and above, 3
  right and below), the ground `key` as a tile's (on the chosen row's `accent` fill a clear
ground would hide the kanji, and fuzzel cannot swap an icon). One set, one grid, per
  theme (`tools/build-appicons.py` → `themes/<theme>/apps/`, named through `current`), each
  exactly 18 × 18, shown 1:1 (fuzzel filters what it resizes: a 2× picture halved blurs).
  Never a project's logo for a
  terminal program, never foot's or neovim's icon for something that is not them.

## 5. States

| state | look |
|---|---|
| rest | as above |
| hover (pointer) | quick settings and the sound panel: only the item's glyph and name turn `accent_text` — no box, no fill. A menu: the cursor goes to the item under the pointer (one cursor, never two lights) |
| cursor (keyboard) | the row or tile filled `accent`, its ink `text_on_accent`; a menu opens with it on its first choice (or its `--select` line) — Enter takes it at once; a panel shows it only after a key |
| chosen | ▣ / a stamped seal |
| disabled / absent | `faint`, and the word says why ("none", "off") |
| active (a bar icon whose menu is open) | its glyph and text `accent_text` |
| stamped (a vermilion bar seal — the torii, the day's kanji, a game's gamepad, 共有 — hovered or active) | the seal inverted: its 23 × 23 button filled `accent`, its ink `text_on_accent`, 6 px of fill round the 11 px ink on every side — the selected workspace's own look (measured: dark and light, torii and 水 each 23 × 23, pads 6 · 6 · 6 · 6) |
| workspace holding windows | its numeral `text`, hemmed: a running stitch under it (3 on, 2 off, three stitches = 13 px, from the button's 5th column — one past the ink each side — 2 px of paper under the ink; `muted`; current/hem.png). Empty: the numeral `faint`, nothing under it. No rings anywhere on the bar |

Nothing animates: no fade, no slide, no easing. Everything draws at once — with one designed
exception, **the wash**: a theme switch and a new wallpaper (by hand or every 4 hours) show the
screen as it was washed away as the screensaver washes its cloth — an ordered dither (8 × 8
Bayer) on the screensaver's grid of dots (3 px at 1080p), 8 steps 32 ms apart (~1/4 s), each
step clearing an eighth of the dots: stepped, never eased, never a fade (`kawa-saver --wash`).
It never holds input (every click goes through), and a press during it jumps to its end.

## 6. Behaviour

- A menu or panel opened from the bar opens centred under the clicked icon, 8 px inside the
  screen's edge; from a key, at its fixed place under the bar's right side.
- The same click or key again closes it; Esc and a click outside close it.
- One menu or panel at a time; opening another closes the first.
- Opening starts clean: no remembered cursor, no remembered highlight (a menu's cursor on its
  first choice, as above).
- A menu that pages (the calendar: kawa-menu `--stay`) pages in place: the same window
  redrawn at once, the cursor kept on the key that paged; clicks made while the next page is
  on its way are done on it, none lost.
- Bar tooltips say the essential in a word or two: "volume 40%", "muted", "brightness 70%",
  "RAM 37% of 32 GB", "Steam", "Steam starting", "do not disturb" — never what a click does.

## 7. Text screens (terminal: fzf, foot)

The same grammar in characters, 20 px (Fusion Pixel 10, §2):
- **Heading**: the kanji in `accent_text`, two spaces, the name in `text`, one space, then the
  stitch as `╌` in `edge2` to the right edge — the same rhythm as the panel's.
- **Row**: two spaces indent, glyph, two spaces, name; the value right-aligned, `muted`.
- **Cursor**: the row's background `accent`, its text `text_on_accent` (fzf's `bg+`/`fg+`).
- **Gutter**: fzf's pointer and marker are spaces (the fill alone marks the cursor).
- One blank line between parts; one before the footer; the footer in `muted`.
- Window padding: foot's 10 px; the content keeps two cells from the frame.
- Ground: `ground` at alpha 0.92 (kawa-glass; Super+U → transparency turns it off): the
  wallpaper shows faintly through, the text never does. No blur.
- Width changes: the prompt's header is laid out again for the new width and drawn over
  itself (nothing left above it); a finished entry keeps its header without the stitch.

## 8. The handbook

The PDF uses the same parts in print: headings as a seal + name + stitch, the palette's ink
and paper, Fusion Pixel for headings and labels, the same kanji per chapter, tables ruled
with the stitch, square corners everywhere.
