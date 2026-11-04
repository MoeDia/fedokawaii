# Fedokawaii — the design system

One visual language for everything the desktop draws: the bar, the panels and menus, the
launcher, the terminal screens, the windows, the notices, the level display, the lock and login
screens, the screensaver, the boot, and the books. This file is the single truth: a surface is
built from the parts below and nothing else, every number it uses is written here, and a change
of design is made here first, then in the code (`tests/static/test_design_doc.sh` reads the
numbers back against the configs of every surface already rebuilt to it, §14).
The sections keep their numbers (scripts cite them: §7 is "text screens" wherever it is named).

## 0. The world: two moods

Not one design recoloured — two places, each with its own light, art and character. The parts,
the grid and the motion are shared; the mood decides the inks, the art and the story.

| | 鬼 dark — the demon's dungeon | 天 light — the angel's temple |
|---|---|---|
| ground | sumi ink on stone: Wada's Black, warmed with Vandyke Brown | paper in daylight: Sulpher Yellow, cooled with Neutral Gray |
| words | parchment: Ecru → Ivory Buff → Sulpher Yellow | ink: Deep Slate Green → Black |
| the seal (vermilion) | Jasper Red | Brick Red (a softer, older red) |
| fire and metal | torchlight: Apricot Orange; old brass: Isabella | gold leaf: Yellow Ocher |
| lit | a cold teal: Venice Green toward Ecru | a deep porcelain teal |
| art | demons and warriors after Kuniyoshi and Hokusai, pixel-drawn | tennin (angels), clouds and lotus after Buddhist painting |
| the lock | a dungeon wall, two torches, the Hannya's open mouth | a temple in clouds — golden mist on a paper sky —, two hanging bronze lanterns, Seiōbo through a round window |
| its quote | 口は禍の門 — the mouth is the gate of misfortune | 言わぬが花 — better left unsaid |
| the head (quick settings' tile on the bar, the prompt, fetch) | a woodblock's crest (owner, 4 Nov: "more RED, monotone, classic Japanese"): an oni in the seal's red, black features, cream eyes and teeth; it roars while its panel is open and in the prompt when a command failed | a Kannon in sumi, a red nimbus, red lips and urna; she opens her eyes and smiles while the panel is open, and looks up in the prompt when a command failed |

Both quotes are proverbs about keeping words in — the right thing to read where a password is
typed (sources: kotobank — デジタル大辞泉, 精選版 日本国語大辞典; the earliest uses 1252 and 1729).

## 1. Palette (tools/wada-palette.py → tools/build-themes.py → themes/{dark,light}/*)

Every colour is one of Sanzo Wada's (*A Dictionary of Color Combinations*, 1933–34; the data:
github.com/mattdesl/dictionary-of-colour-combinations) or a stated mix of two in OKLab, chosen
in `tools/wada-palette.py` and nowhere else. Colours come only from these tokens; no literal
colour anywhere, in either mood. (`--doc` prints the hex columns of this table.)

| token | dark 鬼 | light 天 | role |
|---|---|---|---|
| `ground` | `181715` Black → Vandyke Brown 0.13 | `e8e3c2` Sulpher Yellow → Neutral Gray 0.2 | the screens' ground: terminals, panels, menus, the launcher — all at kawa-glass's see-through (0.92) |
| `surface` | `1c1916` Black → Vandyke Brown 0.2 | `ecdfb3` Sulpher Yellow → Isabella Color 0.18 | a solid ground: notices, the level display, tooltips |
| `view` | `1c1916` | `f7f1d1` Sulpher Yellow → White 0.25 | a toolkit's list or canvas ground (GTK views, FireAlpaca's panels) |
| `key` | `221e1a` Black → Pale Raw Umber 0.2 | `f8f3d8` Sulpher Yellow → White 0.35 | a tile's or key's fill at rest |
| `edge` | `2d251e` Black → Pale Raw Umber 0.32 | `dfcc9c` Sulpher Yellow → Isabella Color 0.45 | a tile's or key's 1 px frame at rest; an unlit meter segment; the terminal's black |
| `edge2` | `3c2f22` Black → Pale Raw Umber 0.48 | `d7bc8c` Sulpher Yellow → Maple 0.62 | a heading's rule (§4, §7) |
| `hi` | `4a3826` Black → Pale Raw Umber 0.62 | `ffffff` White | pixel art's light ink (stone, paper, the files' and drives' pictures) |
| `lo` | `111314` Black | `96865e` Isabella Color → Deep Slate Green 0.25 | pixel art's shadow ink; the screensaver's thread shadow (dark) |
| `faint` | `907e5d` Light Brownish Olive → Ecru 0.25 | `8b917f` text → ground 0.6 | what is not there yet ("none"), an empty workspace's numeral |
| `muted` | `cab596` Ecru → Ivory Buff 0.2 | `586459` text → ground 0.36 | secondary words: values, a key's action, the layout's mark |
| `text` | `e7cfa1` Ecru → Ivory Buff 0.9 | `122625` Deep Slate Green → Black 0.3 | names, rows, body |
| `strong` | `f5ecc2` Sulpher Yellow | `121b1b` Deep Slate Green → Black 0.7 | a heading's name, a notice's title, the time, a state that is on |
| `accent` | `eb5324` Jasper Red | `a84222` Brick Red | vermilion fill: the bar's end tiles, the workspace stamp, the focused window's hairline |
| `accent_hi` | `f47b58` Jasper Red → White 0.2 | `cb6336` Brick Red → Apricot Orange 0.45 | vermilion lit: a vermilion tile under the pointer, a key held down, a stamp's thump (§11) |
| `accent_lo` | `82241f` Vandyke Red | `953321` Brick Red → Vandyke Red 0.5 | dim vermilion: an unlit segment on a vermilion fill |
| `accent_text` | `f47b58` = `accent_hi` | `a84222` Brick Red | vermilion ink: a heading's icon, the day's kanji, the date's slashes, US, a failure's mark — never words to be read (no red on sumi reaches Lc 60: the words beside the mark are `text`) |
| `text_on_accent` | `111314` | `f8f3d8` | ink on vermilion |
| `select` | `82241f` Vandyke Red | `82241f` Vandyke Red | what is selected — the keyboard's cursor on a row, a key or a place of the dial; GTK's and Qt's selection, a default button: the lacquer (漆), one in both moods |
| `text_on_select` | `f5ecc2` | `f8f3d8` | every ink on the lacquer: words, icons, a lit segment |
| `select_lo` | `a8614d` Vandyke Red → f5ecc2 0.3 | `a96353` Vandyke Red → f8f3d8 0.3 | an unlit segment on the lacquer |
| `asagi` | `82c1b4` Venice Green → Ecru 0.25 | `00726a` Light Porcelain Green → Dusky Green 0.45 | lit: a bar tile under the pointer or open; a meter's lit segments; something asking for you |
| `flame` | `f68c50` Apricot Orange | `a84222` Brick Red | fire: the torches and lanterns, a meter's segments over 80 % |
| `gold` | `c5a56e` Isabella Color | `e2b540` Yellow Ocher | metal and leaf in art only (rod caps, a halo, a demon's eyes, the torches' brass) — never words |
| `lit` | `e7cfa1` | `122625` | an inverted chip's fill: the editor's selection, a TUI's marked items |
| `lit_text` | `181715` | `f8f3d8` | ink on `lit` |
| `paper_folder` | `fdbf68` Cream Yellow | `fdbf68` Cream Yellow | the prompt's folder block (from Wada's combination #300 — the same papers in both moods; foot's 27–29, their ink 30: §7) |
| `paper_git` | `b5decc` Turquoise Green | `b5decc` Turquoise Green | the prompt's git block |
| `paper_time` | `78cdd0` Calamine Blue | `78cdd0` Calamine Blue | the prompt's block of the time and the jobs |
| `tile` | `25201a` | `f9f5de` | the bar's paper (§8) |

The 16 terminal colours (foot, the console, every TUI) come from the same families; `ansi0` is
`edge` (the light mood's a step lighter, `e2cfa0`: the band behind a selected line, below), `ansi7`
`text`, `ansi8` `muted`, `ansi15` `strong`:

| token | dark 鬼 | light 天 | token | dark 鬼 | light 天 |
|---|---|---|---|---|---|
| `red` | `eb5324` | `a84222` | `bred` | `f58e84` | `82241f` |
| `green` | `8fa071` | `437742` | `bgreen` | `96d1aa` | `1a7444` |
| `yellow` | `e2b540` | `986f2d` | `byellow` | `fbe6a0` | `644b1e` |
| `blue` | `97acc8` | `006eb8` | `bblue` | `a7d4e4` | `005b8d` |
| `purple` | `9a72aa` | `66629c` | `bpurple` | `b5b1d8` | `4f4086` |
| `teal` | `00978d` | `004f46` | `bteal` | `62c6bf` | `064f6e` |

Contrast — by APCA first (APCA-W3 0.0.98G, its Lc: light words on a dark ground read weaker than
the WCAG 2 ratio says, so the dark mood is set by Lc), and the WCAG 2 ratio beside it. Each role
has APCA's level for what it carries, on every ground words stand on (the panels', a solid
surface, a key's fill, the bar's tile): `text` and `strong` Lc ≥ 75 (words read at length),
`muted` ≥ 60 (a label, a value), `accent_text` ≥ 45 (an icon, a mark, a large glyph), `faint` ≥ 30
(words only spotted: "none", "off"). The band a TUI lays behind a selected line or a changed word —
the terminal's black, `ansi0` — carries that row's own words (`text`, `strong` ≥ 75 on it), never
muted or faint ones; in the light mood it is a step lighter than the frames' `edge` for that
(Sulpher Yellow → Isabella Color 0.4, `e2cfa0`: text 75.6 on it, 73.9 on edge). Sources:
.claude/notes/design-research.md rule 14 (APCA in a Nutshell). APCA ties Lc 75 to 16 px at weight
500 or 14 px at 700; we hold 14 px Sumi UI at regular weight to it because a pixel face draws every
stem one whole pixel at full coverage, with no smoothing to thin it — it reads as a heavier weight
does (T19m (b) 1, 1 Nov).

The steps, so the order reads at a glance: each word ink ≥ 15 Lc below the one above it on the
ground — dark: strong 94 · text 78 · muted 63 · faint 34; light: text 86 · muted 64 · faint 43, with
`strong` (87) above `text` by its hue and its place (both are ink on paper, near black: no darker
ink is left), never by lightness. The terminal's 7 and 8 (`text`, `muted`) keep the same step: 15
(dark), 22 (light).

Vermilion is a mark's ink, never a reading one — no red on sumi reaches Lc 60: an icon, a mark, a
seal, a short value that needs you (the bar's memory when high, a running timer's digits, "1 to
fix", "due"), a link (one word or two to follow, underlined by the toolkit). Words to be read — a
failure, a message, a sentence — are `text` (or `strong`), with a vermilion ✘ or icon before them
(lib/common.sh's rows, verify, the lock's message in `strong`, Neovim's diagnostics: the sign and
the underline in the severity's ink, the message `muted` at the line's end, `text` in the float).
`accent_text` is `accent_hi` in the dark mood: Jasper Red toward white (the seal's own hue, lit),
Lc ≥ 47 on every ground.

The old masters' pictures and fetch's take three art tones besides the roles — `art_umber`
(`65583f`, Light Brownish Olive → Black 0.22), `art_olive` (`9a8767`, Light Brownish Olive → Ecru
0.4), `art_kinari` (`d4bf9a`, Ecru → Ivory Buff 0.45): the dark ramp's even steps between the stone
and the cream (tools/build-masters.py reads its ramp by name); never words.

Lc · ratio:

| on | faint | muted | text | strong | accent_text | asagi |
|---|---|---|---|---|---|---|
| dark `ground` | 34 · 4.5 | 63 · 9.0 | 78 · 11.8 | 94 · 15.1 | 49 · 6.7 | 61 · 8.7 |
| dark `key` | 33 · 4.2 | 62 · 8.3 | 77 · 10.9 | 93 · 13.9 | 48 · 6.2 | 60 · 8.1 |
| dark `tile` | 33 · 4.1 | 62 · 8.1 | 77 · 10.6 | 93 · 13.6 | 48 · 6.0 | 60 · 7.9 |
| light `ground` | 43 · 2.5 | 64 · 4.8 | 86 · 12.2 | 87 · 13.5 | 62 · 4.7 | 61 · 4.5 |
| light `key` | 52 · 2.9 | 73 · 5.6 | 95 · 14.1 | 97 · 15.7 | 72 · 5.4 | 71 · 5.2 |
| light `tile` | 53 · 3.0 | 75 · 5.7 | 96 · 14.4 | 98 · 16.0 | 73 · 5.5 | 72 · 5.3 |

Ink on vermilion (`text_on_accent` on `accent`): 5.1 dark, 5.4 light — a mark's (the bar's seal), never
a row's. What is selected is the lacquer, its words ≥ 7 : 1 (`text_on_select` on `select`: 8.0 dark,
8.5 light): `tools/contrast.py` measures every selected and highlighted state of every surface from
the files the desktop ships (words ≥ 7, icons and matched letters ≥ 4.5, a large glyph or a
meter's level ≥ 3) — and by APCA (`--apca`: the roles above, the selected states at Lc 60 for
words and 45 for marks; the workspace seal's black numeral is measured and kept by the owner's
word, Lc 41 dark, 24 light) — and tests/static/test_contrast.sh fails under any of them.

## 2. Type

| face | built from | licence | size | cell | line | where |
|---|---|---|---|---|---|---|
| **Sumi UI** | JF Dot 東雲 Shinonome Gothic 14, the regular weight, repaired; Latin Extended-A composed from its own letters; Cozette 1.30.0 for Greek, Cyrillic and the rarer signs (`tools/build-fonts.py`) | public domain + MIT | 14 px | 7 px a letter, 14 a kanji or kana | 20 (a row) | the bar, panels, menus, the launcher, notices, the level display, lock, login, saver, boot |
| **Sumi Term** | UDEV Gothic NF 2.2.0, regular, no ligatures (JetBrains Mono's letters, BIZ UDGothic's Japanese, Nerd Fonts) | OFL 1.1 | 16 px | 8 × 20 | 20 | foot: every terminal screen, the TUIs, Neovim |
| **Sumi Icons** | ours: `art/icons.txt` → `tools/build-icons.py` | ours | Sumi UI's grid | — | — | beside Sumi UI |
| **Sumi Icons Term** | the same drawings, pixel for pixel, centred in two cells | ours | — | 16 × 20 | — | beside Sumi Term |

**Sumi UI's em** (14 rows, 0–13; the baseline under row 11):

| rows | what |
|---|---|
| 0–13 | kanji and kana (a column of air at their left) |
| 2–11 | capitals, digits, ascenders (10 rows) |
| 5–11 | the x-height (7 rows) |
| 12–13 | descenders |
| 7 | the minus — and every rule drawn beside words (§4) |

- The face is drawn in 1 px strokes, both ways; nothing is ever drawn heavier beside it (icons
  too, §13), and nothing smears it: no antialiasing, no hinting, no synthetic bold
  (`system/60-fedokawaii-pixel.conf`). Its repair: no pair of letters touches (0 of the 8836
  ASCII pairs), every kana and kanji keeps a column of air; the JIS signs it draws the old way
  (`\` `~` both quotes and the grave accent) are redrawn the Western way; the desktop's signs
  and the common punctuation (‘ ’ “ ” – — … • → ◆ ● ✓ ° ± × ÷ € …) are drawn on its grid in
  `art/signs.txt`; Latin Extended-A (ā č ę ł ő ř ş ž) is composed from its own letters and
  accents; Greek, Cyrillic and the rarer signs are Cozette's 6 × 13 drawings on its baseline
  (their capitals 8 rows); Arabic comes from Noto Kufi Arabic through the toolkit.
- **One size** for words. Hierarchy by ink and place, never by size.
- **The legibility floor** (Legge & Bigelow, *Does print size matter for reading?*, Journal of
  Vision 11(5):8, 2011: fluent reading needs an x-height of about 0.2° or more; angle = 57.3 ×
  size ÷ distance). On this 24-inch 1080p panel (EDID 53 × 30 cm: 0.275 mm a pixel), at a desk's
  50–60 cm (his own distance is not measured — no one can measure it from here; both ends are
  stated): Sumi UI's 7-row x-height, 1.92 mm, is 0.22° at 50 cm, 0.20° at 55 cm, 0.18° at 60 cm;
  Sumi Term's 8.7 px (1115/2048 em at 16 px), 2.39 mm, is 0.27° / 0.25° / 0.23°. So **14 px is
  the floor for words** — nothing is ever set smaller (no "small print", no smaller second size);
  what is read at length (help, the Learn pieces, a notice's body over two lines) is set in Sumi
  Term or stays at 14 px; and a desk farther than 55 cm calls for the next whole step of Sumi UI
  (×2 is display only, so that step is a larger face, chosen and drawn, never a scaled one).
- **Display size** — the one exception: Sumi UI at a whole multiple of 14 px, never smoothed:
  ×2 (28 px) for the boot splash, the boot menu (GRUB) and the installer's screens. The lock's
  quote is not set in a font at all: it is lettered by hand, pixel by pixel (§9).
- **Sumi Term** is UDEV Gothic NF installed as it comes (`lib/upstream.sh`, its files pinned by
  SHA-256; "UDEV Gothic" is its licence's reserved name) and named "Sumi Term" by fontconfig's
  alias (`system/60-fedokawaii-pixel.conf`), drawn smoothed in grey with light hinting. In
  foot's 20 px line (`line-height=20px`) its ascent and descent round to 16 + 4: the baseline
  16 px down, capitals on rows 4–15 (their middle the line's); foot draws box drawing itself,
  so `─` is one pixel on the line's row 10, the same row as a panel's rule (§4).
- No scaling anywhere at 1080p: dwl's monitors at scale 1; nothing sets GDK_SCALE,
  GDK_DPI_SCALE, QT_SCALE_FACTOR or Xft.dpi — sizes are the pixels written here.
- Words are lower case (proper names keep theirs: Fedora, Bluetooth, LG ULTRAGEAR).
- Numbers are tabular, right-aligned in a column. Nothing is ever cut with "…": a long name is
  shortened at its source, or its end goes with nothing in its place.

## 3. Grid (pixels, at 1×)

**The cell is the terminal's: 8 × 20.** Every surface — panels drawn in pixels and screens drawn
in characters alike — lays its columns on 8 px and its rows on 20 px, so a menu, a terminal
screen and the bar's paper share one rhythm.

| name | px | cells | use |
|---|---|---|---|
| cell | 8 × 20 | 1 | a column and a row |
| row | 20 | 1 row | a list row; a line of words in a panel or a notice; a terminal line; the bar's paper |
| words in a row | — | — | the em on the row's rows 3–16: capitals on 5–14 (5 rows of air above and below), the rule on 10 |
| gap | 8 | 1 | between tiles and keys; an icon's column and its words; between windows; windows from the screen's edges |
| pad | 16 | 2 | inside a panel, from its hairline to the content, all round (a terminal screen: foot's 8 + the screen's own margin of one cell) |
| hairline | 1 | — | the frame of everything that floats (§4) |
| shadow | 2 | — | two rows under a hairline (each a pixel further right), one column beside it (§4) |
| icon | 12 × 12 | — | beside words, on the em's rows 1–12 (centred on the capitals) |
| icon alone | 14 × 14 | — | where no words follow: the layouts, an icon-only key |
| emblem | 16 × 16 | — | the bar's torii and workspace stamp (glyphs) |
| face | 18 × 18 | — | quick settings' face on the bar's end tile: a picture in four inks (sumi, ivory, gold, lacquer — tools/build-themes.py FACES), a pixel of paper above and below, the odd pixel of air right |
| icon column | 16 | 2 | an icon centred in it (2 px either side) |
| indent | 8 | 1 | a heading's rows start one cell further in than the heading |
| heading, GUI | 20 + 8 | — | its row, then 8 px of air; 20 px above it (none at the top of a panel) |
| heading, TUI | 1 + 1 lines | — | its line, then a blank line; two blank lines above it (none at the top) |
| content | 376 | 47 | a panel's inner width: the sound panel, a notice, the launcher (410 with pad and hairlines) |
| key | 20 high | 1 row | a key button: its 1 px frame inside the row |
| meter | 160 × 10 | 20 | 20 segments, each 6 × 10 px with 2 px of air (one a cell): 5 % a segment |
| stamp | 16 Ø | — | the workspace's vermilion seal on the bar (an emblem), its numeral 10 × 10 inside |
| app icon | 16 × 16 | — | the launcher's: an app's own icon at its native 16 px, centred in the row |
| bar | 27 | — | 3 air, hairline, 20 paper, hairline, 2 shadow (§8) |
| window gap | 8 | 1 | 8 px between hairlines: window and window, window and the screen's edge, the bar and a window (the windows' tops on y 33) |

## 4. Parts

- **Frame** — one for everything that floats on the screen: the bar's tiles, windows, panels,
  menus, notices, tooltips, the level display. A 1 px hairline round it, its four corner
  pixels left out (the corner is not a sharp square), and the shadow the bar's tiles have always
  had (light from the top left): under the bottom hairline two rows — the first, deeper, from a
  pixel in to under the right hairline, the second, lighter, a pixel further right — and one
  column, lighter, right of the right hairline from its second row down. The hairline's ink: dark — `text` at 50 %; light — `strong` at 84 %; the shadow's: dark —
  Black at 67 % then 31 %; light — umber at 43 % then 19 % (`KAMI` in `tools/wada-palette.py`).
  Never rounded, never a second frame inside (no inner rule, no bevel).
- **Panel**: `ground` at the terminals' see-through (kawa-glass, the owner's transparency: what
  lies under it — the wallpaper, a window and its words — shows faintly, at 4 %; everything the
  panel draws is opaque), the frame, 16 px of pad, content on the grid. Sized to its content in
  whole cells.
- **Heading**: its icon (12 px) in `accent_text` in the icon column at the content's first cell,
  its name in `strong` from cell 3 (x 24), 8 px, then the **rule** — 1 px `edge2`, solid, on the
  row's row 10 (the minus's), to the content's right edge. Air: §3. Every part of a panel opens
  with one.
- **Row**: 20 px; its icon in the icon column at cell 1 (x 8–23, the icon on x 10–21), its name in
  `text` from cell 4 (x 32); a value in `muted`, right-aligned to the content's edge, two cells or
  more after the widest name. A row that only shows (a week of weather, a help line) is never a
  choice: the cursor and the pointer pass it by.
- **Cursor** (the keyboard's place): the row filled `select` (the lacquer), one cell beyond the content
  either side (into the pad), its inks `text_on_select`.
- **Key**: one row high, `key` fill, 1 px `edge` frame inside the row; its icon and name centred
  by their ink. Two or three share a row, 8 apart, the row the content's width; an icon-only key
  is 20 × 20.
- **Quick settings** (Super+X, the head on the bar — the owner, 4 Nov: "over-engineered, break it down, a simpler way;
  forget this circle"): a plain menu, the panels' own parts and nothing else. A heading, the two meters (brightness,
  sound), then rows in three groups, half a row of air between groups: in place (theme, night light, do not disturb,
  screensaver, freesync), connections (network, Bluetooth, devices while it is on, drives, backup), the screen
  (wallpaper, screenshot, record, read text, screen off, power). Each row its own picture and its state at the right; a
  thing that is on: its icon `accent`, its state `strong`. Enter or a click switches it in place or opens its own menu.
- **Meter**: its icon and name as a row's, then 20 segments (§3), right-aligned before the value.
  Lit segments `asagi`; over 80 % the 17th–18th `flame` and the 19th–20th `accent` (it reddens
  as it rises); unlit `edge`. A level between two segments lights the last one partly, from the
  bottom, two rows a percent: every level has its own pixels. Muted: the lit segments hollow
  (their 1 px outline). On the cursor's lacquer: lit `text_on_select`, unlit `select_lo`.
  A click or a drag anywhere on it sets the level. The level display (kawa-osd) draws the same
  segments to the pixel.
- **Stamp** (the bar's workspace seal): a round vermilion seal 16 px across, clean-edged, its
  numeral (一 to 九, drawn 10 × 10 for it) in Black, wholly inside the circle.
- **Chosen** (one of several: an output, a mode): a vermilion dot, 6 px round, in the row's
  value column — the hanko's mark.
- **Tooltip**: a panel one row high on the solid `surface`, pad 8, words only (the bar's: GTK's
  tooltip window keeps a border of its own, so `style.css` pads the label by what is left).
- **The launcher** (Super+Space or the torii): a panel 47 cells wide and always ten rows tall (it
  never jumps while you type): the line you type on, then the entries — each an app's own 16 px
  icon, or ours for what has none (a terminal program, a page, a helper); a sum or a conversion
  is answered live in the first row and copied by Enter.
- **A menu typed into** (Super+/, a size, an order) keeps the size it opened with, and its details'
  column where it stood: what is found fills it from the top, cut under its last whole row.
  Super+/ finds by letters in order too ("lck": the lock screen), the best first, each under
  its part; it opens on the keys of the program in front, then the desktop's, then every other's.

## 5. States

| state | a panel or menu (GUI) | a terminal screen (TUI) | the bar |
|---|---|---|---|
| rest | §4 | §7 | §8 |
| hover (the pointer) | the cursor goes to the row under it — one light, never two | the same (a mouse click acts as Enter) | the tile lit: icon and words `asagi`; a vermilion tile's fill `accent_hi` |
| cursor (the keyboard) | the row filled `select` (the lacquer), every ink on it `text_on_select`; a menu opens with it on its first choice, Enter acts at once | the same (fzf: bg+ 24, fg+ 25, `:strip`) | — |
| chosen | the vermilion dot (§4) | `●` in `accent_text`, in the value column | — |
| on · off | §4 quick settings (a row's icon `accent` on, `muted` off); a row's value `strong` "on" · `faint` "off" | the same words, the same inks | — |
| absent | `faint`, and the word says why ("none", "no DDC/CI") | the same | the tile is not there |
| busy | its icon moves (§13) | the same icon's frames | its icon moves |
| asking for you | — | — | the workspace's numeral `asagi`; the window's hairline `asagi` |
| high | a meter's top segments `flame`, then `accent` | the same | — |
| failed | its mark (✘) `accent_text` in the icon column, the words `text` (§1: red carries no words) — a wrong password asked again: the title `MARK⇥words` | the same | — |

Motion — how any of these changes over time — is §11.

## 6. Behaviour

- **One at a time**: opening any menu, panel or popup (the bar's dropdowns, quick settings, the
  launcher, Super+U/V/W/N/C/R//) closes whichever is open.
- **Where it opens**: from a bar tile — centred under it, its top hairline on y 33 (the windows'
  tops), kept 8 px inside the screen; the date's own (the calendar, the timer) centred under the
  bar's middle, a click or a key alike (`kawa-menu --drop --middle`); from a key — at its own
  place: quick settings and the bar's right-hand dropdowns under the right end (their right
  hairline on x 1911), the launcher under the torii (left hairline on x 8), Super+U, N, V, W, R
  and / centred on the screen.
- **Over everything**: a popup shows over a fullscreen window too.
- The same click or key again closes it; Esc and a click outside close it.
- **Opens clean**: no remembered cursor, no remembered highlight; the pointer works the moment it
  is open (no click to wake it).
- A menu that pages (the calendar) pages in place, the cursor kept on the key that paged. A
  password asked (a locked PDF, an archive) is checked where it was typed: a wrong one keeps the
  window, its title saying "wrong password", the field empty for the next try — never a notice,
  never a second window; the right one closes it at once (`kawa-menu --stay`, then `--done`).
- Bar tooltips say the state in a word or two: "volume 40%", "muted", "brightness 70%",
  "RAM 37% of 32 GB", "do not disturb" — never what a click does.
- The lock: 5 s with nothing happening and the screens go off; any key or move lights them
  straight onto the lock, the key not lost.
- Nothing ever waits for an animation: a click or a key acts at once on where things are going.

## 7. Text screens (terminal: foot, fzf, the TUIs)

The same grammar in characters (Sumi Term, 8 × 20 cells); columns counted from the screen's
content, inside its margin of one cell:
- **Heading**: its icon (Sumi Icons Term, two cells) at column 0 in `accent_text`, its name from
  column 3 in `strong`, a space, then `─` in `edge2` to the content's last column. A blank line
  under it; two blank lines above it (none at the top of a pane). No dashed rule anywhere.
- **Row**: its icon at column 1, its name from column 4 in `text`; a value right-aligned to the
  content's last column, `muted`.
- **Text** under a heading (a statement, a question, a message) is a paragraph: at the heading's
  column (0). What it lists — the files it copied, the outcome's row (`✓ finished`) — is a list:
  one cell in (column 1), as rows; the key that closes or goes back, at column 0 again.
- **Facts** (a key and its value: status, the backup's and the drive's panes): the key from the
  heading's name (column 3) in `muted`, padded to the longest, two columns, the value in `text`.
- **Search line** (a list long enough to filter): the chevron in `accent_text` at the rows' icon
  column (1), what is typed — or the ghost words saying what the list holds, `faint` — at their
  names' (4); the count right-aligned to the last column, `muted`. A short list has none (Super+U,
  Super+W): its letters are free for its own keys.
- **Meter** (a quantity in a row: Super+R's reading, a torrent's progress): ten segments, a cell each
  (Sumi Icons' `read` and `read-off`, 6 × 10 on the cell's 8 px pitch — the panel's meter in
  characters) — done solid in `accent_text` (`muted` once complete), to do hollow in `edge2`; the
  segment part-way (`read-1` … `read-7`) keeps `read-off`'s frame and comes in by the Bayer matrix of
  every dissolve (§11), a seventh more with each; the cursor's row strips the inks, the shapes still
  say it. Nothing yet: no meter at all.
- **Torrents** (`kawa-torrents`, its two tabs): the list in parts (downloading, paused, finished: a
  heading each, how many and how much at the end of its rule; at the tabs' right end what comes and goes,
  the last 16 seconds of it in the music's columns, §8), newest first; each row its state's icon (§5: it moves while bytes come; the
  antenna television while it plays; the hourglass while it is looked for, asked of a site or
  checked; ✘ with what stopped it, in words), its name as words (a torrent's dots read as spaces, never "…"), then
  right-aligned, two columns apart, each one edge down its part so the digits stack: the meter, the percent, the
  speed, the time left (its unit a letter: 45 s, 12 m, 3.2 h, 2 d), the size — the size last on every row. Words
  that stand instead of numbers end in the time's place; a finished row keeps only what it sends, in the speed's
  column, and its size.
  Fewer columns as the window narrows: the size goes first (under 104 columns), then the time left (84), the meter
  (62), the speed (44); the percent stays. From 132 columns its details stand beside the list (a
  rail, a free column, 60 wide; the keyboard in them leaves a band of `edge` on the list's row, as
  Files does); narrower, they fill the window. Its pieces a cloth of meter segments, three lines on a
  tall window, one on a small. What could be added stands over the list in the
  magnet's icon (the clipboard's link, a .torrent just downloaded). Find: the Search line, then a
  row a result: its kind's icon, its name, then as they fit the site, its age and its size, last the
  seedling (`sprout`) and how many share it; none: `faint`, last. Opened again while its window stands
  elsewhere, the window asks for you (§5: a bell, its workspace `asagi` on the bar).
- **Cursor**: the row's cells filled `select` (the lacquer, §4) from the cursor's column to the
  one beyond the content, its inks `text_on_select` — every ink, the row's own colours stripped
  (fzf's `bg+ 24`, `fg+ 25`, `:strip`).
- **Files** (yazi, Super+E, and the file dialog): the heading — the folder icon, the folder's
  path in `strong` (the dialog: its name in `strong`, then the folder `muted`), the rule — and a
  blank row; then the panes, each its own column of rows on this grid, one free column after
  each rail (`edge2`). The cursor's row as above; a place in another folder — the one you are
  in, in the parent column, and where you would land, in the preview's — a band of `edge`, its
  words `strong`. At rest a row keeps its kind's colour (folders `ansi4`, bold). The footer: the
  hovered file's facts, `muted` — its size, its permissions — from column 0, its place in the
  list at the right, ending where the heading's rule does; the mode's word only when it is not
  the usual one; a narrow window drops the permissions, then the size. The dialog's last line
  is its own keys instead. What is not there yet — an empty folder, one still being read, a
  filter that finds nothing — one word in `faint` where a row's name would stand ("empty",
  "loading", "nothing matches"), in the list and in a folder's preview; never centred. Two
  folders or more open (yazi's tabs): the tabs under the heading as **Tabs** above — each the
  folder icon and its folder's name, the shown one `strong` with `▔` under its name, the others
  `muted` — then a row of paper.
- **Tabs** (a screen of several sections: Super+U): three lines heading the list, at a
  heading's column (one cell out from the rows, §3 indent) — the tabs, the line under the one
  shown, a row of paper. The tab shown: its icon in `accent_text`, two columns, its name in
  `strong`, and under the name alone `▔` in `accent`, its ends flush with the letters'; the
  others their icon alone in `muted`. Every icon two columns, every gap three: 26–28 px of air
  between any two tabs. Tab / Shift+Tab, ← / → and a click change it. A pane beside the list
  starts its heading level with the tabs and its first line level with the list's first row.
- **No footer** of the obvious (Enter, Esc, arrows): the keys of the app in front are in
  Super+/ (it knows the app). A screen with a key of its own shows that one on its last line —
  the key in `text`, what it does in `muted`, its state in `strong` (Super+W: `r  change every
  4 h  on`).
- Ground: `ground` at kawa-glass's 0.96 — the wallpaper faintly through, the words never. No blur.
- Window padding: foot's 8 px; the screen keeps one cell of margin, then the cursor's column
  (fzf's pointer; two spaces where no fzf draws): the cursor's fill starts 16 px inside the
  window's hairline (x 17), column 0 one cell further (x 25), rows' icons at x 33 — a panel's pad,
  cursor and indent (§3, §4), measured in Super+U, Super+W and the job windows.
- **The page** (Super+N's notes and to-do — a notebook, T21): portrait, 64 × 40. The heading on
  the editor's top row (the tabline), its rule running to the page's edge; under it a blank row
  that never scrolls. Every text row ruled on its cell's 19th pixel row in `edge2`, from the
  words' column to the page's edge — the page below the last line ruled to its foot, so the end
  of the notes is always a fresh page; the margin a 1 px rule in `accent` at the cursor's column,
  the old notebook's red line. At the foot an unruled row of paper (the page's bottom margin, as
  the blank row under the heading is its top), then the footer (`muted`). A day's line shows its
  date alone, in `accent_text`; everything else exactly as typed (no markdown styling, nothing
  hidden). The pen keeps three ruled rows of fresh paper ahead of it — typing, after a Return, an
  `o`, a `p`, a `:put`, a paste. The page scrolls by lines: a wrapped line leaves the top whole.
  A scroll he makes is his — Ctrl+Y, Ctrl+B, the wheel move the page and the pen yields into its
  room; a wheel while typing is a look: the page moves, the pen stays where he typed, and the
  next key — any: a letter, Return, Backspace, an arrow, a paste, a middle-button paste — acts
  from the pen, the page back to it; a click on the heading's rows puts it back at once, a click on
  a line ends the look where it points, Esc where the page is, Super+N and the page turned where
  they put the pen; a click on the foot — one or several — is swallowed whole, the look stays — and
  head, foot and margin never move, whatever the scroll
  (`tools/regress/notes-page.sh` checks every frame of 40 typed lines with an `o` and a `yy p`,
  a cold start and a to-do longer than the page). It opens on a day's line, never mid-day: the
  latest day whose line leaves the pen its rows above it too (the same five as below) on the
  page's first row — today's own when today fills them, else the day before — and a today
  longer than the page opens as the pen needs. The to-do opens typing, on a fresh item at its
  end (the first key is a word, never a command), the pen's room kept as the notes' however
  long the list; esc gives the list, where space ticks, and an item left with no words goes;
  its footer names the keys of the moment.
- **The prompt**: the mood's head, then one short line of paper blocks, a strip of stamps. The head (§0's crest in one
  ink, the terminal's whole 20 rows, three cells: two glyphs of `art/icons.txt`, 16 px and 8, foot letting a glyph
  spill into one blank cell only): the demon in the vermilion ink (`accent_text`, foot's slot 20) in the dark mood, the angel in the words' ink in the
  light; the demon roars, the angel looks up, when the last command failed; a switch of mood reaches an open terminal
  at its next prompt. The blocks: three papers of Wada's combination #300 (Cream Yellow, Turquoise Green, Calamine Blue:
  `tools/wada-palette.py`'s paper_* tokens, foot's colours 27–29, their ink 30, the same papers in both moods), words
  at 9.5 : 1 and more (APCA Lc 68 and more): the folder (the one above it too), the branch and its changes, the time of a
  long command and the background jobs (one block); a failure's code a block of its own on the lacquer, cream words
  (7.9 : 1). Between two blocks and at both ends the stamp edge — a cell of its own, the left paper reaching into the
  next in round tongues every 5 rows (`art/icons.txt` cap-stamp, cap-stamp-start: 8 × 20, the terminal's cell exactly)
  — then a space, `›` and a space. A narrow window gives up the time, the jobs, the branch, the folder above, then the
  folder's end (`tools/build-themes.py` writes the papers; `configs/home/.bashrc.d/` draws it).

## 8. The bar

紙 kami: no bar — tiles of washi floating along the top of the wallpaper (the owner, 4 Nov 18:07: fully floating, no band
behind them, ever; `style.css`; every picture drawn by `tools/build-themes.py`, per mood, exactly to its box). Each mood has
its own paper (`tile`): ink-dyed on the dark, kinari on the light. A tile is the frame (§4) round the paper and a faint
fibre in it — one frame, nothing inside it. Between tiles: 4 px inside a group, 12 between groups, whatever the group. The
workspaces: one tile each; its numeral (一–九) faint while empty, the words' ink while it holds windows, `asagi` while it
asks; the one you are on stamped with the red seal, its numeral black inside it. The clock shows the date, the day's kanji
and the time to the minute.

27 rows, every tile alike:

| rows | what |
|---|---|
| 0–2 | air (the wallpaper) |
| 3 | the hairline (its corners left out) |
| 4–23 | the paper: one row of 20 |
| 24 | the hairline |
| 25–26 | the shadow, a pixel further right each row |
| 7–20 | the em: kanji 7–20, capitals 9–18 — five rows of paper above them and five below |
| 8–19 | an icon beside words (12 px, centred on the capitals) |
| 7–20 | an icon alone (14 px) |
| 6–21 | the emblems (16 × 16): the torii, the stamp (its numeral on 9–18); quick settings' face, a picture 18 × 18 on 5–22 (§3 face) |

Across: the outer tiles' hairlines on x 8 and x 1911 — the windows' edges (§12); 8 px from the
paper's edge to the ink on both sides of every tile (words that change carry their first and
last letters' own air, `width.sh`'s `air`, so the 8 px holds whatever the words); 4 px between
the tiles of a group, 12 px between groups.

| part | look |
|---|---|
| the torii (the launcher) | on a vermilion tile (`accent`), its emblem in `text_on_accent` |
| a workspace | a tile each, its numeral (10 × 10) `faint` when empty, `text` holding windows; the one you are on: the stamp, its numeral Black; one asking for you `asagi` |
| the layout and the title | one tile: the layout's mark (an icon alone) `muted`, the window's name `text` |
| the clock | a hanging scroll (`kami-scroll.png`: the paper between two lacquered rods, gold caps) centred on the screen: the date `DD/MM/YYYY` in `text` with slashes of our own in `accent_text` (`art/signs.txt`), the day's kanji `accent_text` exactly on the screen's centre line, the time `strong`; 14 px between them, the shorter side padded so the kanji stays centred |
| the music's wings | while something plays, inside the scroll either side of the clock: 8 columns a side (2 px wide, 4 apart, 1–10 px tall on the capitals' rows), the lowest notes nearest the clock; inked by height from `accent_lo` to `accent` — our red, rising |
| what plays | the first tile on the right: its icon moving (§13: a television with its antenna for a video, the cassette for sound), the title `text`, a red rule (1 × 10 px, `accent_text`, on the capitals' rows, 8 px either side), the channel or episode `faint`; paused: still, the title `muted` |
| the keyboard | `us` in `accent_text`, `ar` in `blue` — capitals while Caps Lock is on (dwl's `kbcaps`); a click switches |
| do not disturb | its icon (the quiet bell) only while on; a click opens its own dropdown — off · for an hour · until the morning · on, the one in force marked (§4 chosen); a timed one ends by itself |
| downloads | while something downloads: its icon moving |
| the others | timer, recording, drives, memory, volume, brightness, the weather — each its own tile, icon and value; the weather's icon is a picture of its sky (14 × 14, a few inks: the sun vermilion with gold rays, the moon gold with its star, clouds in two tones, rain and snow blue, lightning gold — clear and partly cloudy by day and by night, cloud, fog, rain, snow, storm), laid on the paper 8 px in on the line's rows, the temperature 8 px after it |
| quick settings | the right end's vermilion tile: the demon's head (dark) or the angel's face (light), its emblem |
| lit | under the pointer, or while what it opened is on screen: `asagi` at once (a vermilion tile: `accent_hi`) |

## 9. Notices, the level display, the lock, login, screensaver, boot

- **Notice** (mako): a panel 47 cells wide (410 px), at the top right — its right hairline on
  x 1911, its top on y 33 — the next one 8 below; solid `surface`; its first row the app's icon
  (12 px, `accent_text`) and the title in `strong`, then the body in `text` on 20 px lines,
  aligned with the title; progress: the meter (§4). Critical: the hairline `accent`.
- **Level display** (kawa-osd): a panel of one row — the icon, the meter, the value — centred low
  on the screen; it comes with the key at once and leaves 1.2 s after the last one.
- **Lock** (gtklock + kawa-lockmod; one scene per mood, never the wallpaper): dark — a dungeon
  wall of stone (`edge`, `edge2`, `hi`, mortar `lo`), two torches flickering (`flame`, brass
  `gold`, 8 frames a second, out of step), the Hannya after the old masters on a round stone plate,
  its mouth open on a dark gate: the password glows inside it, each character an ember — a mark of
  the scene's own pixels (arms `flame`, middle `strong`, corners `accent_lo`; the arms `asagi`
  while Caps Lock is on), the newest seven in sight — and the caret a bar as tall as a mark in
  `flame`, blinking once a second, always there while the line has the keyboard. The scene is
  drawn at whole pixels (×3 on 1080p), centred, its edges' own colour round it (kawa-lockmod).
  Light — a temple in clouds: golden mist (suyari-gasumi, the stepped gold bands of the old
  screens) on a paper sky lit by two hanging bronze lanterns (tsuri-dōrō, verdigris here and there,
  a small flame in each fire box, 8 frames a second), and through a round window in a wooden ring
  Seiōbo (Kōgyo's Noh print) offering her peach; the password in her sky beside it, each character
  a gold mote (arms `yellow`, middle `gold`). One quote per mood (§0) in Sumi UI's own pixels on a plaque over the
  art, as a temple's hall carries its name (gilded on the dark's stone lintel), no translation; no
  date, no time, no buttons, no hint. A wrong password says so at once (the embers scatter, the face shakes 3 px
  twice — §11), and the line is empty again.
- **Login** (greetd + kawa-greet): the same scene as the lock — the first lock of the day — and
  into the desktop by the greeter → session motion (§11).
- **Screensaver** (kawa-saver): a cloth the screen's size on the mood's ground — hitomezashi sewn
  line by line in a quiet thread (`muted` on the dark, `blue` on the light, each dot's shadow a dot
  down and right), on a grid of dots as big as a pixel of the wallpapers; the time on a `surface`
  patch framed in running stitch. Away (`--idle`) it lies over the lock, which comes up under it
  as it starts: any input dissolves it off the lock screen at once.
- **Boot**: GRUB's menu and the boot splash (plymouth) in Sumi UI ×2 on the mood's ground, the
  vermilion seal and the same frame; the installer's screens likewise.

## 10. The books and the Learn pieces

The PDFs and the Learning section's pieces use the same parts in print: headings as icon + name
+ rule, the palette's ink and paper, Sumi UI for headings and labels at whole multiples, tables
ruled with the solid rule, square corners everywhere; each piece shows its place (piece n of N,
done ✓).

## 11. Motion

Fluid like water, calm, Japanese, with movement in it (the owner, 4 Nov 17:48, 18:12): **springs**, never a bezier: a thing
starts at no speed, flows, passes its rest a little and settles. A window **rises**, a workspace **moves** like a fusuma on its
track, a menu **unrolls** like a hanging scroll behind its rod, a quiet thing **dissolves** (an ordered dither at the wallpapers'
3 px pixel), a choice is **stamped**. Each kind means one thing: a rise is a window arriving, the strip is a place left for
another, a scroll is something opened and put away, a dissolve is a message passing.

| what | how | ms |
|---|---|---|
| a window opens | rises from 120 px below its place on a spring (7.5 rad, damping 0.72), past it by a few px, and settles; 82 % of its size at first, whole with the same spring; clear within its first 18 % | 450 |
| a window closes | sinks 64 px, gathering speed, 11 % smaller at the end, fading | 400 |
| a workspace move | both workspaces on one strip, the screen and a rail long: to a higher one the strip moves left, to a lower one right; a spring (8 rad, damping 0.84), past its place a little; a wave split round the rail (leaving windows, the rail, coming windows, 48 ms in all); the rail (5 of the wallpapers' pixels wide: ink, lacquer, ink, the screen's whole height, under the bar) between them in every frame; the bar's stamp lifts and stamps down on the new numeral; the wallpaper stays; all of the strip one body: a switch during a move goes on from where it stands at the strip's speed, by the same way, a move back on the rail already at that seam | 450 |
| tiled windows making room | flow to their new places on a spring, no overshoot | 300 |
| a menu, panel or popup, a warm window (Super+U, N, V), a floating terminal (Super+R, W …) shown · put away | unrolls from its top edge down, behind a rod (a lacquer bar 4 px high, 2 px wider than the scroll either side, ink caps; it fades in the last 30 %) on its frame's foot · rolls up into its top edge | 300 · 240 |
| a notice | its frame at once, its words dissolving in; dissolves away | 240 · 200 |
| the level display | at once with the key; dissolves away | 0 · 300 |
| the lock comes | at once | 0 |
| the gate opens (the secret key: Tab) · shuts (Enter, on the marks; Esc, the line cleared) | the mouth, the lotus: its five frames, gentle at both ends; shut at rest, and every other key is nothing | 340 |
| the lock goes (the right password) | shut, a beat while PAM answers, then dwl dissolves the scene off the desktop | 420 |
| a wrong password | the gate opens again, the embers (motes) scatter and fade, the gate shakes 3 px twice | 240 |
| login → desktop | the scene dissolves into the desktop; the bar's tiles stamp in from left to right, 30 ms apart | 900 |
| a theme switch · a new wallpaper | the wash (dwl's own, asked through kawa-wash: the screen as it was laid over everything, the change made under it): five drops of the new mood's darkest ink land on the old picture and bleed out along a paper grain in 3 px pixels, a wet rim at their edge; the pointer's picture changes the moment the wash reaches it | 1200 |
| the screensaver leaves | dissolves off | 180 |
| a screen back (switched on at its button, or woken after it dropped off the cable asleep) | its first picture is the whole desktop: black (the monitor is finding the signal) until its wallpaper and its bar are back and done drawing — 100 ms without a new frame of theirs — never seen being built | 1000 at most |
| a stamp (the workspace seal) | down: the seal 1 px larger all round in `accent_hi`; then as it was, in `accent` | 60 |
| icons that move (§13) | their frames in a loop, only while the state holds | 6–8 a second |

- Every frame is drawn at every refresh of the screen (144 a second here) for the moment it
  reaches the glass (the last frame's presentation time and the refresh), so each step is
  exactly a refresh apart. Movement is in whole pixels; a dissolve's threshold follows a smoothstep
  (no pop at either end).
- No hard edge sweeps across the screen without an object drawn on it — a moving cut reads as a tear: an
  unrolling scroll's edge is its rod, a moving workspace's its rail.
- Nothing holds input (§6). Only what changed is drawn again each frame.
- The dissolve is a threshold against a 4 × 4 Bayer matrix in 3 px blocks, done in the private
  wlroots' GLES2 texture shader (a flag on the scene node), so any window, panel or layer can
  dissolve at no cost.

## 12. Windows

- The frame (§4): the hairline round the window, corners left out, the shadow under and right.
  The focused window's hairline `accent`; the others' the hairline ink; one asking for you
  `asagi`; a fullscreen window none.
- Gaps: 8 px between hairlines — window and window, window and the screen's edge, the bar's
  hairline and a window's (the shadows fall inside them): the windows' tops on y 33, their outer
  hairlines on x 8 and x 1911 — exactly the bar's tiles' outer edges: the windows are as wide as
  the bar.
- No title bars, no client-side decorations, no rounded corners.

## 13. Icons and art

- Every icon is ours, drawn in `art/icons.txt` on Sumi UI's grid in its weight: 1 px strokes both
  ways. **12 × 12** beside words, on the em's rows 1–12, centred on the capitals (§2);
  **14 × 14** alone; the torii **16 × 16**; the mood's head is a picture on the bar's end tile, 20 rows. Sumi Icons Term draws the same pixels,
  centred in two terminal cells.
- One ink: an icon takes its words' ink (state colours from §5); art pieces (the demon, the angel,
  the seals' numerals, the weather's pictures on the bar: tools/build-themes.py SKY) may use more,
  from the palette only.
- **Kanji appear in three places only**: the workspace stamps (一–九), the bar's day kanji, and
  the lock's quote. Everywhere else — headings, menus, TUIs, the launcher — a pixel icon.
- Each thing its own picture: no two icons alike (the weather's sun is not brightness's).
- Icons that move (frames `name-0` … in icons.txt, at the rate given): the television with its
  antenna while a video plays (4 frames, 6 a second), the cassette's reels while sound plays,
  the downloads arrow dropping into its tray (6 frames, 8 a second), recording's red dot (once a
  second), the hourglass on Super+U's row of the job that runs (`hg-0` … `hg-4`: the sand
  falls, lies a beat, the glass turns; 6 a second while the menu shows — fzf told each frame,
  the pane kept meanwhile, never made again at every frame); at rest, their first frame (the
  hourglass: the plain one).
- **Art** — pixel versions of public-domain old masters, drawn in the palette's inks at the
  wallpapers' 3 px pixel: demons and warriors after Kuniyoshi and Hokusai (dark), tennin after
  Buddhist painting (light) — about ten wallpapers each, the lock's scenes, quick settings' face
  (the heads, §0: on the bar's end tile, in the prompt, the fetch art).

## 14. Surfaces and their owners

Every surface, what draws it, and the task of round 27 that rebuilds it to this file. A surface
rebuilt is listed in `BUILT` in `tests/static/test_design_doc.sh`, which from then on checks its
numbers here against its files.

| surface | opened by | drawn by | rebuilt in |
|---|---|---|---|
| the palette, every theme file | `kawa-theme` | `tools/wada-palette.py`, `tools/build-themes.py` | T08 |
| Sumi UI, Sumi Icons, the signs, the width tables | — | `tools/build-fonts.py`, `tools/build-icons.py` | T10 |
| Sumi Term, foot, the TUIs' columns | Super+Enter | `configs/home/.config/foot/foot.ini`, `bin/kawa-term` | T11 |
| the system menu | Super+U | `system/fedokawaii` in `bin/kawa-warm` | T12 |
| quick settings, sound, the bar's dropdowns | the right end, Super+X, Super+A | `bin/kawa-panel` (state: `bin/kawa-quick`) | T13 |
| the bar | — | `configs/home/.config/waybar/`, `bin/kawa-bar` | T14 |
| windows' frames; notices; the level display; tooltips | — | `src/dwl/`; `src/mako/mako.patch` (the desktop's mako: the frame, the title's icon ink, the hanging indent, no "…") + mako's `config`; `bin/kawa-osd` | T15 |
| books, wallpapers, clipboard, the launcher | Super+R, W, V, Space | `bin/kawa-books`, `bin/kawa-wallpaper`, `bin/kawa-clip`, `bin/kawa-menu` | T16 |
| art: wallpapers (the old masters as pixel art), the lock's scenes, quick settings' face | — | `tools/build-masters.py` (art/masters), `tools/build-art.py`, art/icons.txt (oni, tennin) | T18 |
| motion | — | `src/dwl/`, the private wlroots, `src/kawa-saver` | T19 |
| lock, login, screensaver | idle, Super+Escape, boot | `bin/kawa-lock`, `src/kawa-lockmod`, `system/kawa-greet`, `src/kawa-saver` | T20 |
| notes and the to-do list | Super+N | `bin/kawa-notes` | T21 |
| files | Super+E | yazi (`configs/home/.config/yazi/`) | T22 |
| help | Super+/ | `bin/kawa-help` | T23 |
| torrents | the launcher, a magnet link, the bar's mark | `bin/kawa-torrents` (`.local/lib/fedokawaii/kawa-torrents`) | T29 |
| the prompt | every terminal | `configs/home/.bashrc.d/` | T24 |

## 15. The grill list

What an exacting art director checks on every surface, in both moods, before it is done:
1. Every gap, pad and centre measured (`tools/px.py`) equals §3 — to the pixel.
2. Words: the capitals on their rows (§3), no letters touching, nothing cut, no "…", lower case.
3. Icons: 12 px beside words on one axis down a list, 14 alone, 16 the emblems; no kanji outside §13's three
   places; no two icons alike.
4. Inks: tokens only (§1); vermilion only where §1 gives it a role; contrast as measured.
5. Frame: one hairline and its shadow; no double frame, no inner rule, no rounded corner.
6. States: hover, cursor, chosen, absent, busy drawn; one light at a time; opens clean.
7. Motion, frame by frame at 144 Hz: the timing of §11 within a frame, eased, whole pixels, no
   stray pixel, no hard edge sweeping, input never held.
8. Sizes: a narrow tile to fullscreen, none to a thousand items, the longest name — nothing cut
   or misaligned.
9. The two moods side by side: each its own world (§0), the parts identical.
10. Cost: no new process or polling where an event exists; RAM and frame time measured.
