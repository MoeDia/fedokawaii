# Fedokawaii — the design system

One visual language for everything the desktop draws: the bar, the panels, the dropdown menus,
the launcher, the terminal screens, the notices, the lock and login screens, and the books.
The source of truth is quick settings' sound panel (`kawa-panel --sound`), whose shapes this
file names, and the bar (`configs/home/.config/waybar/style.css`). Anything new is built from
these parts and nothing else.

## 1. Palette (tools/build-themes.py → themes/{dark,light}/*)

| token | role |
|---|---|
| `ground` | the screens' ground: terminals, panels and menus (all at the terminal's see-through: kawa-glass), the lock |
| `surface` | a notice's and the level display's ground (solid); a shade of the ground under a cursor line |
| `cloth` | the bar's cloth: kachi-iro on ink, kinari on paper |
| `key` | the fill of a tile or a key button at rest |
| `edge` | a tile's 1 px frame at rest |
| `edge2` | a seal's 1 px frame, the panels' stitched rules, an unlit square |
| `faint` | words that are not there yet ("none"); an empty workspace |
| `muted` | secondary values; the panel's outer 2 px frame |
| `text` | names and rows |
| `strong` | a lit tile's name; the bar's time; emphasis |
| `accent` | the keyboard's cursor fill; the bar's red patches (beni), under the torii and the cat — the only filled vermilion |
| `accent_text` | kanji in seals, the torii, a hovered glyph and name in a panel |
| `accent_lo` | the dim vermilion of an unlit seal on a filled row |
| `text_on_accent` | ink on vermilion: the torii and the cat cut out of their patches |
| `asagi` | lit: on the bar, under the pointer or open; lit meter squares; the patch of a workspace asking for you |
| `moegi` | the numeral of a workspace holding windows (the palette's bright green) |
| `aizome` | the indigo-dyed patch of a workspace holding windows |
| `kinari` · `kachi` | the workspace you are on: the cloth turned over — kinari (undyed) on the ink theme, kachi (indigo-black) on the paper one |
| `lo` · `blue` | the bar's sashiko: on the cloth, `muted` thread with an `lo` shadow (ink) or `blue` (indigo) thread with an `edge` shadow (paper); on a patch, the thread pale on a dark dye and indigo on a pale one |

Colours come only from these tokens; no literal colour anywhere, in either theme.

## 2. Type

- UI (bar, panels, menus, launcher, notices, lock and login): **Sumi UI** at 16 px — 東雲
  Shinonome Gothic 16 Bold (JF Dot, public domain): an 8 px column a letter, 16 a kanji or
  kana, capitals 13 px on rows 1–13 of the 16 px line, the minus on row 7. The five signs the
  face draws the old Japanese way (the tilde, the backslash, both quotes and the grave
  accent) are redrawn, the one-cell signs of the UI
  (arrows, ◆ ● ■ ✓ ✗ · …) are drawn by hand on its grid (`art/signs.txt`), and what the face
  lacks comes from GNU Unifont JP 17 (`tools/build-fonts.py` → `system/fonts/SumiUI.ttf`).
  One size; hierarchy by colour and position, never by size.
- Terminals: **Sumi Term** at 20 px — Kappa 20 Bold (the kterm face), its signs and its gaps
  made the same way: a 10 × 20 px cell, foot's lines 24 px (two pixels of air above and
  below), 188 × 42 cells in a tile filling a 1080p screen.
- Icons: **Sumi Icons**, drawn on Sumi UI's grid (`art/icons.txt`): 14 px beside words, 15 px
  ("seal-sized") where a kanji would stand — the torii, the layouts, the gamepad, the cat.
  The upright strokes 2 px, the level ones 1 px, as the letters. On the bar every icon is its
  air-less twin (`ICON_BAR_*`): its ink from the module's padding, 8 px of paper to its value.
  **Sumi Icons Term**: the same drawings on Sumi Term's 20 px grid.
- All three faces are declared bold (the weight they are drawn in): a toolkit asking for bold
  finds them as they are, and nothing is ever smeared a pixel wider by synthetic bold.
- **Display size** — the one exception to "one size": Sumi UI at a whole multiple of its
  16 px, never smoothed (`system/60-fedokawaii-pixel.conf`: no antialiasing, no hinting): ×4
  (64 px) for the clock of the lock and login screens, ×2 (32 px) for the boot splash and the
  boot menu at 1080p (GRUB's Sumi at 16 × its scale). Nowhere else.
- No scaling anywhere at 1080p: dwl's monitors are at scale 1, and nothing sets GDK_SCALE,
  GDK_DPI_SCALE, QT_SCALE_FACTOR or Xft.dpi — sizes are the pixels written here.
- Words are lower case (proper names keep theirs: Steam, Bluetooth, LG ULTRAGEAR).
- Numbers are tabular and right-aligned in a column. Nothing is ever cut with "…": a long
  name is shortened at its source, or its end goes with nothing in its place.

## 3. Grid (pixels, at 1×)

| name | value | use |
|---|---|---|
| frame | 2 | the panel's outer frame, `muted` |
| pad | 16 | inside the frame, all round, measured to the ink |
| gap | 8 | between tiles and keys, a glyph and its word; a letter's column |
| line | 16 | a line of text |
| row | 24 | a list row, a meter's row (its words 4 px from its top); 2 px between rows |
| seal | 26 × 26 | a kanji in its 1 px frame: the 16 px kanji, 4 px of paper all round |
| rule | 29 | a section's rule band: 14 px, the stitch, 14 px |
| section | 24 | from a part's last row to the next seal |
| key | 32 high | a key button (quick settings' foot: 164 · 164 · 32) |
| tile | 120 × 80 | a quick-settings tile; three a row = 376, the content width |
| content | 376 | the inner width of a panel (412 with pad and frame) |
| meter | 12 × (14 × 10) | its squares 2 px apart (a 16 px pitch, 190 px), lit `asagi`, unlit `edge2` |
| app icon | 22 × 22 | the launcher's: the 24 px row less a pixel above and below |
| bar | 31 high | 7 px of cloth, the 16 px line, the workspaces' threads, the hem (§8) |

## 4. Parts

- **Panel**: `ground` at the terminals' see-through (kawa-glass: the wallpaper faintly behind,
  the text never), 2 px `muted` frame, 16 px pad to the ink all round, square
  corners. Never rounded, never a shadow. Sized to its content.
- **Heading**: a seal (1 px `edge2` frame, the kanji in `accent_text`), 8 px, the name in
  `text`, 8 px, then the **stitch** — 3 px on, 2 px off, 1 px high, `edge2`, through the
  seal's middle, from a whole stitch to the last whole one that fits. Every part of a panel or
  menu opens with one, under its own kanji (音 sound · 出 output · 入 input · 明 brightness ·
  盤 drives · 受 downloads · 暦 calendar · 時 time · 天 weather · 電 power · 系 system · 鍵 keys ·
  起 launcher …), one character meaning the part.
- **Row**: 24 px high; its glyph centred in a 16 px column 8 px in (every row's glyph on one
  axis, whatever its side bearing; a wide one — the volume's 20 px speaker — stands out 2 px
  either side), 8 px, the name in `text`; a detail in a column of its own; a value in `muted`,
  right-aligned in a column two gaps after the widest words. A menu is as wide as its content.
  A row that only shows (the weather's week, a help line) is drawn in a row's inks and is
  never a choice: the cursor and the pointer pass it by.
- **Key button**: 32 px, `key` fill, 1 px `edge` frame, icon and name centred by their ink. Two
  or three share a row with 8 px between, the row the whole content width; an icon-only key is
  a 32 × 32 square.
- **Tile**: 120 × 80, `key` fill, `edge` frame; its seal top right — stamped (2 px
  `accent_text` frame) when on, a faint outline when off; its icon top left, its name and
  state below.
- **Meter**: its glyph, its name, then the 12 squares; muted: the lit ones hollow.
- **Rule between parts**: the stitch alone, the full content width.
- **The launcher** (`kawa-menu --launcher`, Super+Space or the torii: kawa-panel's own): a
  panel 412 px wide and always ten rows tall (it never jumps while you type): the heading
  起 launcher, the line you type on, then the entries — each an app's own 22 px icon, or, for
  a program without one (a terminal program, a page in Brave, a helper of ours), its kanji in
  a 22 px seal; a sum or a conversion is answered live in the first row (copied by Enter).

## 5. States

| state | look |
|---|---|
| rest | as above |
| hover (pointer) | a panel: only the item's glyph and name turn `accent_text` — no box, no fill. A menu: the cursor goes to the item under the pointer (one cursor, never two lights). The bar: `asagi` |
| cursor (keyboard) | the row or tile filled `accent`, its ink `text_on_accent`; a menu opens with it on its first choice — Enter takes it at once; a panel shows it only after a key |
| chosen | ▣ / a stamped seal |
| disabled / absent | `faint`, and the word says why ("none", "off") |

What moves is short and never holds input — a click or a key acts on where things are
going, at once: **the wash** of a theme switch and a new wallpaper (an ordered 8 × 8 dither
on the screensaver's grid of dots, 8 steps 32 ms apart, `kawa-saver --wash`), the
screensaver washing itself away as it leaves (180 ms, the same dither), and dwl's windows —
a window fades in as it rises its last 24 px to its place, and fades away sinking as much;
a workspace switch fades the windows out as they drift a little (6 % of the screen) to one
side, and the next ones in from the other. Each over 220 ms, drawn at every refresh of the
screen (144 a second here), eased out (fast, then settling), positions in whole pixels.
Nothing ever sweeps a hard edge across the screen: a moving cut reads as a tear.

## 6. Behaviour

- A menu or panel opened from the bar opens centred under the clicked icon, 8 px inside the
  screen's edge; from a key, at its fixed place under the bar's right side.
- The same click or key again closes it; Esc and a click outside close it.
- One menu or panel at a time; opening another closes the first.
- Opening starts clean: no remembered cursor, no remembered highlight.
- The pointer works the moment a menu is open: no click needed to wake it.
- A menu that pages (the calendar) pages in place: the same window redrawn at once, the
  cursor kept on the key that paged.
- Bar tooltips say the essential in a word or two: "volume 40%", "muted", "brightness 70%",
  "RAM 37% of 32 GB", "Steam" — never what a click does.

## 7. Text screens (terminal: fzf, foot)

The same grammar in characters, Sumi Term at 20 px:
- **Heading**: the kanji in `accent_text`, two spaces, the name in `text`, one space, then the
  stitch as `╌` in `edge2` to the right edge.
- **Row**: two spaces indent, glyph, two spaces, name; the value right-aligned, `muted`.
- **Cursor**: the row's background `accent`, its text `text_on_accent`.
- One blank line between parts; one before the footer; the footer in `muted`.
- Window padding: foot's 10 px; the content keeps two cells from the frame.
- Ground: `ground` at alpha 0.92 (kawa-glass): the wallpaper shows faintly through, the text
  never does. No blur.
- **The prompt**: the torii, the place, git; at the right edge the last command's ✓ or ✗ and
  code, how long it took, and the time to the minute — open paper between, no rule; then `›`
  and one space. An entry already run keeps its header without the paper between.

## 8. The bar

A strip of cloth across the top, sewn in sashiko and patched as boro is (`style.css`; every
picture drawn by `tools/build-themes.py`, per theme, exactly to its box). Every line on it is
a running stitch of one thread, 3 px on and 2 off, each pixel of thread with its shadow a
pixel down and to the right; the thread is the cloth's: pale on a dark dye, indigo on a pale
one. On the cloth itself the thread is quiet — two fifths of the way into the cloth: it
parts, it does not draw the eye. The cloth is kachi-iro, indigo dyed until it is all but black
(`cloth`; on paper kinari, undyed cotton), with a faint grain.

31 px: the hem's stitch on row 29, the bar's foot (the width of the screen, laid from its
middle); patches on rows 4–26 (23 = 4 × 5 + 3: a stitch at both ends); seams, the
separators, on the capitals' rows 9–21 (three stitches); the 16 px line on rows 8–23 —
row 15 is the middle of everything. An icon alone in a cell sits a row higher, its 15 px
centred there too.

| part | look |
|---|---|
| a **patch** | a picture of exactly its box: dyed rows 4–26, framed by a running stitch on its very edge pixels — corners stitched, each edge laid symmetrically from both corners (a length off the 5 px rhythm takes the difference in its middle gap or stitch) — and sewn all over in hitomezashi, faintly, tone on tone (a tenth toward the thread; kaki-no-hana, centred); the cloth between two patches |
| the torii (the launcher) | on a beni patch (`accent`) at the left corner, cut out of it in `text_on_accent` |
| a workspace | a cell 8 px of cloth either side of its numeral to the frame (36 px; 35 for 四 七 九): empty, the frame alone, the numeral `faint`; holding windows, aizome (`aizome`), the numeral `moegi`; the one you are on, the cloth turned over — kinari on the ink, kachi on the paper — the numeral in the other theme's `accent_text`; one asking for you, asagi, the numeral `urgent_text` |
| the clock | in the screen's middle, on the cloth itself — no patch: the date `text` · a seam · the day's kanji `accent_text` · a seam · the time `strong`, 8 px from each seam's thread to the ink beside it, centred on the screen |
| the music's wings | while something plays, its spectrum either side of the clock — the left channel left, the right right, 8 thin columns each (2 px, 2 apart, 1–13 px tall in 2 px steps), the lowest notes nearest the clock — 16 px out from the clock's ink; one warm grey by height: the floor `edge2`, low `faint`, middle `muted`, tall `text` |
| what plays | the first cell on the right: a cassette whose reels turn while there is sound, the title in `text`, two spaces, the artist in `faint` (paused: a pause sign, the title `muted`) |
| a cell on the right | a timer, recording, the mode, drives, downloads, Steam, the keyboard, memory, volume, brightness, the weather: each a cell of the cloth with a seam at its left (the capitals' rows), 8 px from the thread to its ink and from its ink to the next thread (its last glyph's air counted) |
| the cat (quick settings) | on the right corner's beni patch, as the torii on the left |
| lit | under the pointer, or while what it opened is on screen: `asagi`, at once (on beni or asagi: `strong`; on the turned-over cloth: the other theme's `asagi`/`blue`) |

## 9. Notices, the lock and login screens

- **Notice** (mako): 412 px wide as a panel, 16 px of padding, a 2 px frame; its icon (up to
  48 px) on the left; its title, then its body on 24 px lines; a critical one framed in
  vermilion.
- **Lock and login**: no panel, no box — one column on the wallpaper shaded three quarters
  into the ground (`kawa-wallpaper` draws it): the padlock and the time at 64 px with AM/PM on
  its baseline; the day (its seal, the date, the weekday in kanji); the season's line; the
  password's line — an underline, a `accent_text` ◆ for each character; three keys (sleep,
  restart, power off) as words alone, `accent_text` under the pointer and the keyboard.

- **Screensaver** (`kawa-saver`): the cloth of the bar, the screen's size — hitomezashi sewn
  line by line in the bar's own thread (`muted` on the ink, `blue` on the paper, each dot's
  shadow a dot down and right), on a grid of dots as big as a pixel of the wallpapers; seals
  (a 2-dot `accent_text` frame) stamped and lifted; the time on a `surface` patch framed in
  running stitch as the bar's clock is. Any input washes it away at once (180 ms), the lock
  coming up behind it.
- **Two families of frame**: what is sewn into the cloth — the bar, its patches and seams, the
  screensaver — is framed in running stitch with its shadow; what lies on top of it — windows,
  panels, menus, notices, tooltips — in a plain 2 px line (a window's focused one vermilion),
  the stitch inside them only as a heading's rule.

## 10. The books

The PDFs use the same parts in print: headings as a seal + name + stitch, the palette's ink
and paper, Sumi UI for headings and labels, the same kanji per chapter, tables ruled with the
stitch, square corners everywhere.
