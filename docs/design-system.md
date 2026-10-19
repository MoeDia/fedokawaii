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
| `accent` | the cursor's fill (keyboard), the workspace seal — the only filled vermilion |
| `accent_text` | kanji in seals, a hovered glyph and name, the active state of a bar icon |
| `accent_lo` | the dim vermilion of an unlit seal on a filled row |
| `text_on_accent` | ink on the accent fill |
| `asagi` | lit meter squares (the one cool colour: levels) |

Colours come only from these tokens; no literal colour anywhere, in either theme.

## 2. Type

- UI (panels, menus, bar, notices): **Fusion Pixel 12px Mono ja** at 12 px, icons from
  **Sumi Icons** at the same size. One size; hierarchy by colour and position, never by size.
- Terminals: the same face at 24 px (foot), icons from Sumi Icons Term.
- Words are lower case (proper names keep theirs: Steam, Bluetooth, LG ULTRAGEAR).
- Numbers are tabular and right-aligned in a column.

## 3. Grid (pixels, at 1×)

| name | value | use |
|---|---|---|
| frame | 2 | the panel's outer frame, `muted` |
| pad | 12 | inside the frame, all round |
| gap | 6 | between tiles, keys and a glyph and its word |
| line | 12 | a line of text |
| row | 20 | a list row, a meter's row |
| seal | 23 × 23 | a kanji in its 1 px frame (11 px kanji, 6 px all round) |
| rule | 21 | a section's rule band: 10 px, the stitch, 10 px |
| section | 18 | from a part's last row to the next seal |
| key | 24 high | a key button |
| tile | 88 × 64 | a quick-settings tile; three a row = 276, the content width |
| content | 276 | the inner width of a panel (304 with pad and frame) |

## 4. Parts

- **Panel**: `surface` ground, 2 px `muted` frame, 12 px pad, square corners. Never rounded,
  never a shadow.
- **Heading**: a seal (1 px `edge2` frame, the kanji in `accent_text`), 6 px, the name in
  `text`, 6 px, then the **stitch** — 3 px on, 2 px off, 1 px high, `edge2` — to the right edge,
  through the seal's middle. Every part of a panel or menu opens with one. Each part has its
  own kanji (音 sound · 出 output · 入 input · 明 brightness · 盤 drives · 暦 calendar · 時 time ·
  天 weather · 電 power · 系 system · 鍵 keys …), one character, meaning the part.
- **Row**: 20 px high; at x+6 a glyph (an icon, or a check: ▣ chosen, □ not), 6 px, the
  name in `text`; a detail in a column of its own (12 px after the longest
  name); a value in `muted`, right-aligned in a column 12 px after the widest words — a menu is
  as wide as its content, never stretched to put a gap before the value. A long name is shortened at its source
  (a human name), never cut with "…".
- **Key button**: 24 px, `key` fill, 1 px `edge` frame, icon + name centred. Two or three
  share a row with 6 px between.
- **Tile**: 88 × 64, `key` fill, `edge` frame; its seal top right — stamped (2 px `accent_text`
  frame, kanji `accent_text`) when on, faint outline when off; its icon top left, its name
  and state below.
- **Meter**: its glyph, its name, then 12 squares of 10 × 8 with 2 px between, lit `asagi`,
  unlit `edge2`; muted: the lit ones hollow.
- **Rule between parts**: the stitch alone, full content width.

## 5. States

| state | look |
|---|---|
| rest | as above |
| hover (pointer) | only the item's glyph and name turn `accent_text` — no box, no fill |
| cursor (keyboard) | the row or tile filled `accent`, its ink `text_on_accent`; appears only after a key |
| chosen | ▣ / a stamped seal |
| disabled / absent | `faint`, and the word says why ("none", "off") |
| active (a bar icon whose menu is open) | its glyph and text `accent_text` |

Nothing animates: no fade, no slide, no easing. Everything draws at once.

## 6. Behaviour

- A menu or panel opened from the bar opens centred under the clicked icon, 8 px inside the
  screen's edge; from a key, at its fixed place under the bar's right side.
- The same click or key again closes it; Esc and a click outside close it.
- One menu or panel at a time; opening another closes the first.
- Opening starts clean: no remembered cursor, no remembered highlight.

## 7. Text screens (terminal: fzf, foot)

The same grammar in characters, 24 px:
- **Heading**: the kanji in `accent_text`, two spaces, the name in `text`, one space, then the
  stitch as `╌` in `edge2` to the right edge — the same rhythm as the panel's.
- **Row**: two spaces indent, glyph, two spaces, name; the value right-aligned, `muted`.
- **Cursor**: the row's background `accent`, its text `text_on_accent` (fzf's `bg+`/`fg+`).
- **Gutter**: fzf's pointer and marker are spaces (the fill alone marks the cursor).
- One blank line between parts; one before the footer; the footer in `muted`.
- Window padding: foot's 10 px; the content keeps two cells from the frame.

## 8. The handbook

The PDF uses the same parts in print: headings as a seal + name + stitch, the palette's ink
and paper, Fusion Pixel for headings and labels, the same kanji per chapter, tables ruled
with the stitch, square corners everywhere.
