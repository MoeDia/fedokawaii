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
| `key` | the fill of a tile or a key button at rest |
| `edge` | a tile's 1 px frame at rest |
| `edge2` | a seal's 1 px frame, the panels' stitched rules |
| `faint` | words that are not there yet ("none", the password's hint); an empty workspace; a slider's track |
| `muted` | secondary values; the panel's outer 2 px frame |
| `text` | names and rows |
| `strong` | a lit tile's name; the bar's time; a slider's knob; emphasis |
| `accent` | the keyboard's cursor fill — with the bar's vermilion tiles (§8), the only filled vermilion |
| `accent_text` | kanji in seals, the torii, a hovered glyph and name in a panel |
| `accent_lo` | the dim vermilion of an unlit seal on a filled row |
| `text_on_accent` | ink on vermilion: the torii and the cat on their tiles |
| `asagi` | lit: on the bar, under the pointer or open; a slider's fill; a workspace asking for you |
| `lo` · `blue` | the screensaver's sashiko: `muted` thread with an `lo` shadow (ink) or `blue` (indigo) thread with an `edge` shadow (paper) |
| `tile` | the bar's washi (§8) and the lock and login screens' scroll (§9): ink-dyed paper on the ink theme, cream paper on the paper one |

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
| meter | 190 × 14 | a slider: the track 2 px `faint`, the fill 6 px `asagi` to the level (190 px for 100 %: every level its own pixels), the knob — an ink rod, 4 × 14, `strong` — on the fill's end with a pixel of air either side, a 1 × 6 tick at each quarter of the track |
| app icon | 22 × 22 | the launcher's: the 24 px row less a pixel above and below |
| bar | 31 high | washi tiles: hairline, paper, rule, the 16 px line, rule, paper, hairline, shadow (§8) |

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
- **Meter**: its glyph, its name, then the slider; muted: the fill hollow (1 px), the knob `muted`;
  on the keyboard's vermilion fill, everything in `text_on_accent` and the track in `accent_lo`;
  a meter that only shows (the clean mic's level) has no knob. The level display (kawa-osd) is the
  same slider, spelled in the icon font's slider parts (lv-*) to the pixel.
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
going, at once: **the wash** of a theme switch and a new wallpaper (the screen as it was,
faded away over 320 ms on a smootherstep, `kawa-saver --wash`: the picture sent once, only
its opacity changed — the compositor blends it), the screensaver fading as it leaves
(180 ms, the same curve), and dwl's windows — a window fades in as it rises its last 24 px to
its place (240 ms), and fades away sinking as much (180 ms: quicker, out of the way); a
workspace switch fades the windows out as they drift a little (6 % of the screen) to one
side, and the next ones in from the other (240 ms); a warm window put away (Super+U, Super+N,
Super+V) goes as a closed one does, and shows again at once (a press is one frame). The lock
comes at once — and goes softly: the right password fades the lock screen off the desktop
(320 ms). The screensaver lies over a lock already up (kawa-saver --idle locks as it starts;
dwl keeps that one program's cloth above the lock), so a key fades the cloth off the lock
screen at once: no wait for a lock to start, no frame held. Every one is drawn at every refresh of
the screen (144 a second here) for the moment that frame reaches the glass (the last frame's
presentation time and the refresh: each step exactly a refresh apart), the movement eased
out (fast, then settling) in whole pixels, the opacity on a smootherstep (no pop at either
end).
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
- Windows tile 8 px apart and 5 px from the screen's edges, so a window's outer edge falls
  on the bar's tiles' hairline (x 5 and 1914): the windows are exactly as wide as the bar.
- Window padding: foot's 10 px; the content keeps two cells from the frame.
- Ground: `ground` at alpha 0.92 (kawa-glass): the wallpaper shows faintly through, the text
  never does. No blur.
- **The prompt**: one short line — the torii (`bgreen` when the last command worked,
  `accent_text` when it failed), one space, the folder above in the faint ink and the one you
  are in in `strong`, two spaces, the branch mark faint and the branch muted (`*` in yellow
  when not committed), the code in `accent_text` when it failed, the time muted when 3 s or
  more, two spaces, `›` in `accent_text`, one space. An entry already run keeps its line.

## 8. The bar

紙 kami: no bar — tiles of washi floating along the top of the wallpaper (`style.css`; every
picture drawn by `tools/build-themes.py`, per theme, exactly to its box). Each theme has its
own paper: on the ink, paper dyed in ink (墨染め sumizome, `tile`) with pale words; on the
paper, the paper as it comes (生成り kinari) with words in sumi. Every tile carries a printer's
rule a pixel inside its edge, a hairline round it (pale on the ink, dark on the paper), a
two-row shadow under it and a faint fibre in the paper — so it stands on any wallpaper.

31 rows, every tile alike: the hairline on 2, the paper 3–27 with its rules on 5 and 25, the
hairline on 28, the shadow 29–30; the 16 px line on 8–23, the capitals on 9–21 — row 15 is the
middle of everything. An icon alone on a tile sits a row higher, its 15 px centred there too.
Spacing is symmetric: 8 px from the paper's edge to the ink on both sides — words that change (the title, what plays) carry their first and last letters' own air as classes (`width.sh`'s `air`, measured from Sumi UI) so the 8 px holds whatever the words — 4 px between the
tiles of a group, 10 px between groups, 6 px from the screen's edges.

| part | look |
|---|---|
| a **tile** | `kami-tile.png` as a border-image (sliced 6 5 6 4: the edges stay, the middle stretches under the words), the paper and its fibres inside the rule |
| the torii (the launcher) | on a vermilion tile with a gold rule (`kami-red.png`) at the left corner, in `text_on_accent` |
| a workspace | a tile each, its numeral `faint` when empty, `text` holding windows; the one you are on stamped with a round vermilion seal drawn to the tile's inside and centred on the numeral to the pixel (`kami-seal.png`, `kami-seal-narrow.png` for 四 七 九), its numeral `seal-ink`; one asking for you `asagi` |
| the layout and the title | one tile between them, the layout's mark `muted`, the title `text` |
| the clock | a hanging scroll (`kami-scroll.png`: the paper between two lacquered rods with gold caps), centred on the screen: the date `text`, the day's kanji `accent_text` exactly on the screen's centre line, the time `strong`; 14 px between them, the date side 8 px more so the kanji stays centred |
| the music's wings | while something plays, inside the scroll either side of the clock: its spectrum, the left channel left and the right right, 8 columns a side (2 px wide, 4 apart, 1–13 px tall a pixel at a time: 13 heights), the lowest notes nearest the clock; one warm grey by height, `edge2` to `text`. Ready before you press play (cava kept warm for a paused player): it rises with the music's first sound |
| what plays | the first tile on the right: a cassette whose reels turn while there is sound, the title `text`, two spaces, the artist `faint` (paused: a pause sign, the title `muted`) |
| a tile on the right | a timer, recording, the mode, drives, downloads, Steam, the keyboard, memory, volume, brightness, the weather: each its own tile, 8 px from the paper to its ink both sides (its last glyph's air counted) |
| the cat (quick settings) | on the right corner's vermilion tile, as the torii on the left |
| lit | under the pointer, or while what it opened is on screen: `asagi`, at once (on vermilion: `strong`) |

## 9. Notices, the lock and login screens

- **Notice** (mako): 412 px wide as a panel, 16 px of padding, a 2 px frame; its icon (up to
  48 px) on the left; its title, then its body on 24 px lines; a critical one framed in
  vermilion.
- **Lock and login**: on the wallpaper shaded three quarters into the ground (`kawa-wallpaper`
  draws it), the bar's clock grown into a hanging scroll — the same washi, rule and lacquered,
  gold-capped rods at twice the bar's pixels — and on it one column: the padlock and the time
  at 64 px with AM/PM on its baseline; the day (its seal, the date, the weekday in kanji); the
  season's line; the password's line — a line of the rule's colour under it, a `accent_text`
  ◆ for each character at 32 px (Sumi UI at twice its pixels, 8 px apart), no caret, the hint
  (パスワード · password) `faint` at 16 px over the empty line; three keys (sleep, restart, power off) as words alone, `accent_text`
  under the pointer and the keyboard.

- **Screensaver** (`kawa-saver`): a cloth the screen's size on the theme's ground — hitomezashi
  sewn line by line in a quiet thread (`muted` on the ink, `blue` on the paper, each dot's
  shadow a dot down and right), on a grid of dots as big as a pixel of the wallpapers; seals
  (a 2-dot `accent_text` frame) stamped and lifted; the time on a `surface` patch framed in
  running stitch. Away (`--idle`) it lies over the lock, which comes up under it as it
  starts: any input washes it off the lock screen at once (180 ms).
- **Two families of frame**: paper laid on the wallpaper — the bar's tiles, the lock's scroll — is
  framed by its printer's rule, a hairline and a shadow; what is drawn on the screen itself —
  windows, panels, menus, notices, tooltips — in a plain 2 px line (a window's focused one
  vermilion), the stitch inside them only as a heading's rule; the screensaver is sewn, in
  running stitch with its shadow.

## 10. The books

The PDFs use the same parts in print: headings as a seal + name + stitch, the palette's ink
and paper, Sumi UI for headings and labels, the same kanji per chapter, tables ruled with the
stitch, square corners everywhere.
