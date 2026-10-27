# Round 27 — font facts for the new UI face and the new terminal face

Verified 2026-10-27 on this PC. Every fact comes from the project's own site, repository, release page or Google Fonts' own
metadata (URL inline), or from measuring the downloaded file with fontTools 4.62.1 under `python3 -I` (read-only; marked
"measured"). Downloads: `~/.cache/r27-fonts/<name>/`, one folder each, sha256 inline. Nothing installed, nothing executed,
nothing committed. No decision is made here.

Disclosure: once, the UI faces were also drawn through Pillow/FreeType (under `python3 -I`) to look at ASCII punctuation
and to sanity-check the numbers. No other program parsed a downloaded font (archives were unpacked with unzip, tar, 7z only).
The measuring scripts (fontfacts.py, render.py ...) are scratch files in `/tmp/r27-fontscripts/` and may vanish; every number
below can be re-derived from the downloaded files with fontTools alone.

## How "measured" columns are defined

- **native px**: the pixel size a bitmap-derived outline is drawn for = UPM / gcd of all outline coordinates (cross-checked
  with the name, README, and embedded-bitmap `EBLC` strike sizes).
- **adv**: advance width in px at the native size (ASCII / kana / kanji). "1:2" means full-width = exactly 2 x half-width.
- **touch**: pairs (a, b) of glyphs with rsb(a) + lsb(b) <= 0, i.e. ink touches ink, no kerning applied. ASCII = all 94
  printable ASCII, 8836 pairs. "zero-gutter kanji" = JIS X 0208 glyphs whose ink spans the whole advance (lsb <= 0 and
  rsb <= 0), so they touch both neighbours. JIS L1 = 2965 chars, L2 = 3390 chars (built from Python's `euc_jp` codec).
- **phase**: how far outline edges sit from the baseline's pixel lattice (0 = rows start exactly on the baseline).
- **box/ambiguous width**: advance of U+2500-259F, arrows, geometric shapes, `... -- * check` etc. in cells of the ASCII advance.
- NF sets counted by codepoint range: PL core E0A0-A2/E0B0-B3 (7), PL extra (32), Seti E5FA-E6B7 (190), Devicons E700-E7C5 (198),
  Font Awesome F000-F2E0 (737), Octicons F400-F533 (308), Codicons EA60-EBEB (396), Material Design v3 F0001-F1AF0 (6896),
  Weather E300-E3E3 (228), Font Logos F300-F375 (118), Pomicons E000-E00A (11).

## 0. Baseline: today's two faces, measured the same way (the owner's "ugly / spacing" complaint is measurable)

| face (this repo's build, `system/fonts/`) | cell | JIS L1 kanji with zero gutter | JIS L2 | kana | ASCII pairs touching |
|---|---|---|---|---|---|
| Sumi UI (Shinonome 16 Bold + Unifont fill-in) | 8x16, line 16 | 1342 of 2965 (45 %) | 2015 of 3390 (59 %) | hira 5 of 83, kata 0 | 0 |
| Sumi Term (Kappa 20 Bold + Unifont fill-in) | 10x20, line 24 | 1085 of 2965 (37 %) | 1515 of 3390 (45 %) | 0 | 0 |
| raw JF Dot Shinonome 16 Bold (before the repo's repair) | 8x16 | 2247 (76 %) | 2906 (86 %) | hira 9 | 2376 of 3844 alnum pairs |
| raw JF Dot Kappa 20 Bold | 10x20 | 2789 (94 %) | 3264 (96 %) | 1 | 814 of 3844 |

Candidates marked "pass" below keep a gutter of at least 1 px in every kana and every L1+L2 kanji, and no ASCII pair touches (0 of 8836).

---

# A. UI faces (pixel / bitmap look, Japanese)

## A.0 Summary (all measured unless a URL is given in the block below)

| id | candidate (file) | version, date | licence | native px | adv px ASCII / kana / kanji | kana, JIS L1 / L2 | touch: ASCII / kana / L1 / L2 | fit (4 rules, on paper) |
|---|---|---|---|---|---|---|---|---|
| U1 | DotGothic16 | 1.101, 2021-10-22 | OFL 1.1 | 16 (off-lattice) | 8 / 16 / 16, 1:2 | 86 / 90, 2965 / 3390 | 0 / 0 / 0 / 0 (gaps 0.06-1 px, irregular) | no: 16 px = today's size; Latin not on a pixel lattice |
| U2 | PixelMplus12 / 10 | 2013.0602, 2013-06-02 | M+ FONT LICENSE | 12 / 10 | 6 / 12 / 12 ; 5 / 10 / 10 | 84 / 86 (hira), 86 / 90 (kata); full L1 / L2 | 12: alnum 59 pairs (Q) / 0 / 6 / 5 ; 10: alnum 236 pairs (T W m w) | no: letters touch; superseded by U3 |
| U3 | Tekuplus Regular (Bold) | 2024.1212, 2024-12-12 | M+ FONT LICENSE | 12 | 6 / 12 / 12, 1:2 | 84 / 86, 86 / 90; full L1 / L2 | Regular: 74 pairs (only `}`) / 0 / 6 / 5 ; Bold: 58 alnum pairs (T etc.) | near: Regular passes except `}` and 11 kanji |
| U4 | Zpix | 3.3.0, 2026-09-24 | custom, restrictive | 12 (kanji advance 13) | proportional 3-8 / 13 / 13 | full | n/m (L1 / L2: 0 / 0) | no: licence |
| U5 | Fusion Pixel 12 mono ja | 2026.10.25 | OFL 1.1 | 12 | 6 / 12 / 12, 1:2 | 86 / 90, 2965 / 3390 | 0 / 0 / 0 / 0 | pass |
| U5 | Fusion Pixel 12 proportional ja | 2026.10.25 | OFL 1.1 | 12 | 4-10 (digits all 6) / 12 / 12 | same | 0 / 0 / 0 / 0, GPOS kern | pass |
| U5 | Fusion Pixel 10 mono ja | 2026.10.25 | OFL 1.1 | 10 | 5 / 10 / 10 | 86 / 90, full | 0 / 0 / 1 / 1 | pass (10 px, one kanji touches) |
| U5 | Fusion Pixel 8 mono ja | 2026.10.25 | OFL 1.1 | 8 | 4 / 8 / 8 | 83 / 86 (hira), 86 / 90 (kata) | n/m | no: kana incomplete, 8 px |
| U6 | Ark Pixel 12 mono ja (10 px) | 2026.10.25 | OFL 1.1 | 12 (10) | 6 / 12 / 12 | L1 2782, L2 3033 (10 px: L1 472, L2 165) | n/m | no: kanji incomplete |
| U7 | Misaki Gothic | 2021-05-05 | free, "unlimited permission" | 8 | 4 / 8 / 8, 1:2 | 83 / 86, 86 / 90; full L1 / L2; Latin-1 15 of 96 | 0 / 0 / 0 / 0 | no: 8 px |
| U8 | k8x12 | 2021-05-05 | same free licence | 12 tall (cell 8x12, portrait) | 4 / 8 / 8, 1:2 | 83 / 86, 86 / 90; full L1 / L2 | 0 / 0 / 0 / 0 | yes on paper (condensed look) |
| U8 | k12x8 | 2021-05-05 | same | 8 tall (12x8) | 8 / 16 / 16 | JIS L1 only (L2 0 of 3390) | n/m | no |
| U9 | JF Dot K12 | 20150527 | public domain | 12 (EBDT 12) | 6 / 12 / 12, 1:2 | 86 / 90, full; JIS X 0213 | ASCII 71 pairs all involving `~`; 0 / 0 / 0 | yes on paper; ASCII `\` `~` drawn the JIS X 0201 way |
| U9 | JF Dot Shinonome 12 / 14 / 16 | 20150527 | public domain | 12 / 14 / 16 | 6 / 12 ; 7 / 14 ; 8 / 16 | 83 / 86, 86 / 90; full | 12: L1 441 (14.9 %), L2 773 (22.8 %) zero-gutter; 14: 52 alnum pairs (T), L1 4 | 12 no (kanji touch); 14 near |
| U10 | Unifont JP | 18.0.01, 2026-09-16 | OFL 1.1 + GPL 2+ font exception | 16 | 8 / 16 / 16, 1:2 | 86 / 90, full; Arabic yes | 0 / 0 / 0 / 0 | no: 16 px; but only face with Arabic and 1-cell box/arrows |
| U11 | Cubic 11 | v1.500, 2026-06-27 | OFL 1.1 | 12 (11 px glyphs) | proportional 4-10 / 13 / 13 | full; no mono | alnum 62 pairs (j); L1 / L2 0 / 0 | no: not monospace |
| U12 | BestTen (CRT / DOT) | n/a | free, "commercial OK, embedding OK" | 10x10 | n/a (not downloadable without login) | "about 7200 chars" | n/m | no: unverifiable |
| U13 | MaruMinya (OFL repo) | 1.500, 2026-02-25 | OFL 1.1 | 12 | 6 / 12 / 12, 1:2 | 86 / 90, full | 0 / hira 16 (19 %), kata 20 (22 %) / 2 / 2 | no: kana touch |
| U13 | DenkiChip 8x12 | v1.000, 2026-02-19 | OFL 1.1 | 12 (cell 8x12) | 3-8 prop / 8 / 10 | L1 640 of 2965, L2 0 | n/m | no: kanji missing |
| U13 | MaruMonica / HeadUpDaisy / others | 2025 / 2025 / older | hicc "original licence" | 16 / 24 / ... | MaruMonica proportional 3-11 / 12 / 12 ; HeadUpDaisy 14 / 14 (kana as wide as ASCII) | MaruMonica full JIS; HeadUpDaisy no kanji | MaruMonica alnum 171 pairs | no |
| U14 | Mona (monafont) | 2.90, 2003; page edited 2005 | public domain | n/m | proportional (Shinonome re-spaced to MS P Gothic) | n/m | n/m | no: proportional, unmaintained |
| U15 | Galmuri Mono 11 (Mono 9, Mono 7) | 2.40.4, 2026-07-12 | OFL 1.1 (provenance caveat) | 12 (10, 8) | 6 / 12 / 12, 1:2 | 86 / 90, full | Mono 11: 0 / 0 / 0 / 0 ; Mono 9: 174 alnum pairs | pass (caveat) |
| U16 | Cozette | v1.30.0, 2025-07-30 | MIT | 13 | 6 / 12 / 12 | kana full, kanji 87 of 2965 | alnum 116 pairs | no: no kanji |
| U17 | Silver (Poppy Works) | n/a | CC BY 4.0 + budget clause | n/a | n/a | "CJK ongoing" | n/a | no: unverifiable |

Across the UI candidates: Arabic letters (42 basic): Unifont JP 42/42, every other 0 (Zpix has 3 presentation forms only). Nerd Font icons: none (Fusion and Ark carry 249 private-use glyphs incl. 6 of 7 Powerline core and 16 of 32 extra).
BDF or PCF bitmap sources officially published: Fusion Pixel (BDF, PCF), Misaki, k8x12, Galmuri, Zpix, Unifont; JF Dot, Tekuplus (Bit), MaruMinya, DotGothic16 are TTF only (JF Dot / MaruMinya / Misaki / k8x12 embed bitmap strikes too).

## A.0b Native cell and letter heights (measured, px at the native size)

| face | ASCII x line (hhea) | caps / x-height / descender (rows) | note |
|---|---|---|---|
| Fusion Pixel 12 mono | 6 x 12 | 8 / 6 / 2 | no leading; kanji ink -2..9 (11 rows) |
| Fusion Pixel 12 proportional | 4-10 x 16 (13 above, 3 below) | 9 / 6 / 2 | digits 6 wide |
| Fusion Pixel 10 mono | 5 x 10 | 7 / 5 / 1 | |
| Tekuplus Regular | 6 x 13.0 (10.61 / 2.40) | 9 / 7 / 2 | ink sits 0.4 px below the baseline |
| Galmuri Mono 11 | 6 x 16 (12 + 2 + gap 2) | 10 / 7 / 2 | |
| JF Dot K12 | 6 x 12 | 9 / 7 / 2 | |
| k8x12 | 4 x 12 | 9 / 6 / 1 | letters 3 px wide |
| Unifont JP | 8 x 16 | 10 / 8 / 2 (ascenders 11) | |
| DotGothic16 | 8 x 23.2 (typo 16) | 13 / 9 / 1.4 | |
| today Sumi UI | 8 x 16 | caps 13 | |

## A.1 Per-candidate facts and sources

### U1 DotGothic16
- Official: Fontworks Inc. https://github.com/fontworks-fonts/DotGothic16 ; Google Fonts metadata
  https://github.com/google/fonts/blob/main/ofl/dotgothic16/METADATA.pb (designer "Fontworks Inc.", licence OFL, date_added 2020-12-15,
  subsets japanese / latin / latin-ext / cyrillic). No GitHub release; file in the repo.
- Asset used: https://raw.githubusercontent.com/fontworks-fonts/DotGothic16/HEAD/fonts/ttf/DotGothic16-Regular.ttf
  sha256 155da8f318553c11d9dffc2affbc7c2114c6a46f9740bcf639ed5568af92be71 (repo HEAD 14517183ab2f, file last changed 2021-10-22
  "Version 1.101"); OFL.txt sha256 b6630c61ea078cacd7fabe37d14ffe557a0b45b06683374a9aa9e24262993e33.
- Licence: SIL OFL 1.1, no Reserved Font Name (OFL.txt starts "Copyright 2020 The DotGothic16 Project Authors"). README "Prohibited
  acts": redistribute under another licence; sell the font file itself.
- Format TTF only, Regular only. README: based on the old 16x16 Gothic bitmap font; "All glyphs in Adobe-Japan1-3" + GF Latin Core.
- Measured: not a strict pixel lattice. Kana/kanji dots fall on 62.5-unit steps but strokes are 62-74 units wide; Latin `H` stems are
  74 units = 1.18 px at 16 px; edge phase 0.4-0.6 px; under 25 % of coordinates sit on any 8-32 px lattice (grey edges at 16 px).
  9,362 glyphs; CJK 6,714; Latin-1 96/96; Greek 48, Cyrillic 66; box 87/128 (all full-width), blocks 17/32; no braille, PL, NF, Arabic.
  ASCII 500 / kana+kanji 1000 per 1000 em (exactly 1:2), digits identical, isFixedPitch 1. hhea 1160/-288 (line 23.2 px at 16)
  but OS/2 typo 880/-120 (USE_TYPO off). gasp 10 (smoothing, no gridfit). GSUB pwid hwid fwid zero vert jp78 jp90; GPOS halt vhal.
  Latin caps rise 12.6 px above the baseline (ink -0.4 to 12.6), x-height top 8.6 px, descender to -1.4 px.
- Tracker (repo search spacing/kerning/width/...): 1 hit, #3 "Font Bakery report" (closed 2021). Nothing on spacing.

### U2 PixelMplus 10 / 12
- Official: itouhiro https://github.com/itouhiro/PixelMplus (README: "TrueType outline fonts like 8-bit bitmap fonts", outline-only, no embedded
  bitmap, Regular + Bold, all JIS L1+L2 kanji, Latin-1; made by outlining M+ BITMAP FONTS 10 px and 12 px). Repo HEAD d89b95f04eeb
  (version 2013.0602, 2013-06-02). No releases.
- Assets (files in the repo root, full sha256 in the list at the end): https://raw.githubusercontent.com/itouhiro/PixelMplus/HEAD/PixelMplus12-Regular.ttf
  (02f19467ea7c...), PixelMplus12-Bold.ttf (7276753dc808...), PixelMplus10-Regular.ttf (01b5e4aea5a3...), PixelMplus10-Bold.ttf (3875ea416eff...).
  The bitmap sources it outlines are M+ BITMAP FONTS (https://mplus-fonts.osdn.jp/mplus-bitmap-fonts/, linked by the README).
- Licence: M+ FONT LICENSE, text in https://raw.githubusercontent.com/itouhiro/PixelMplus/HEAD/misc/mplus_bitmap_fonts/LICENSE_E (sha256
  907e9f5a...): "These fonts are free software. Unlimited permission is granted to use, copy, and distribute them, with or without modification,
  either commercially or noncommercially. THESE FONTS ARE PROVIDED "AS IS" WITHOUT WARRANTY." Clear redistribution right.
- Measured: 7,253 glyphs; adv 6 / 12 (12 px) and 5 / 10 (10 px), 1:2; hira 84/86, kata 86/90, L1+L2 full; Latin-1 96/96; box 32/128.
  12 px outline unit is 83.33 font units (UPM 1000), y phase 0.6 px (crisp only in 1-bit rendering); 10 px is on a clean 100-unit grid.
  Touching: 12 px 59 alnum pairs (`Q` + anything); 10 px 236 (T W m w + anything). Bold exists. No GSUB/GPOS.
- Tracker: 0 hits.

### U3 Tekuplus (PixelMplus's sibling/successor, same author)
- Official: https://github.com/itouhiro/Tekuplus , release v1.1.0 "version 2024.1212" (2024-12-12)
  https://github.com/itouhiro/Tekuplus/releases/tag/v1.1.0 ; asset https://github.com/itouhiro/Tekuplus/releases/download/v1.1.0/Tekuplus-20241212.zip
  3,016,146 B sha256 14d3e5f9dfcb351a3a01967c9a2a17e6165479b14e564fe938160ffa4caccee6 (no host digest).
- README: Latin-1 from the author's Teku font, kanji from M+ BITMAP FONTS, 12 px only; `Tekuplus-(Regular|Bold).ttf` outline only,
  `TekuplusBit-(Regular|Bold).ttf` with embedded bitmaps at 12 / 24 / 36 ppem. Licence M+ FONT LICENSE (LICENSE.md in the zip, same text).
- Measured (Regular): 7,284 glyphs; adv 6 / 12 (1:2), digits identical; hira 84/86, kata 86/90, L1+L2 full, Latin-1 96/96; hhea 10.61/-2.40
  (line 13.0 px at 12 px); y phase 0.6 px; cap 9 rows, x-height 7 rows; U+203E is drawn as a tilde. Regular: only `}` has rsb 0;
  11 kanji (6 L1 + 5 L2) have zero gutter; Bold: `# $ % & T ^ { } ~` rsb 0, 58 alnum pairs touch. Files 1.3 MB (outline), 4.9 MB (Bit).
- Tracker: 0 hits.

### U4 Zpix (最像素)
- Official: https://github.com/SolidZORO/zpix-pixel-font ; v3.3.0 2026-09-24 https://github.com/SolidZORO/zpix-pixel-font/releases/tag/v3.3.0 ;
  asset zpix.ttf 4,681,088 B sha256 a67917d94bb597acbdf3bfe1cf97047cc3e1cdd3839d21da188e35cc0737e828 (matches host digest); also zpix.bdf, zpix.woff2.
- README: "Size: 12px (11px + 1px padding), use integer multiples"; "Char Total: 22237". Licence section: personal and education use free; commercial single
  product USD 1000; "Paying for the font grants you the corresponding license". Copyright notice: modification, decompiling, conversion, splitting forbidden
  "(all licensed versions)", illegal dissemination forbidden. Not an open licence, no redistribution grant: ineligible. Measured only: proportional Latin
  (digits 4 and 7 px), kana/kanji advance 13 px at a 12 px em.

### U5 Fusion Pixel Font (TakWolf, 缝合像素字体)
- Official: https://github.com/TakWolf/fusion-pixel-font ; release 2026.10.25 (2026-10-25) https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.10.25 ;
  zips (each holds 7 locales latin, ja, ko, zh_hans, zh_hant, zh_hk, zh_tw as TTF; the Japanese file is `...-ja.ttf`, 7.2 MB at 12 px):
  `https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.10.25/fusion-pixel-font-12px-monospaced-ttf-v2026.10.25.zip`
  50,755,380 B sha256 a5ac3e97e5e1f382ed912e868ea83cdbd40ca8a200d6ecd66e13015341f4259a ;
  `.../fusion-pixel-font-12px-proportional-ttf-v2026.10.25.zip` 51,100,368 B sha256 3d9b1b1a603919efe393ac17cbbb2ec7e33d5da619da23495998b48a1a7e6d90 ;
  `.../fusion-pixel-font-10px-monospaced-ttf-v2026.10.25.zip` 28,125,764 B sha256 a07498c4b7107c62eb02a7288671f521f6c5c640885edb558b4da43ee06a0d03 ;
  `.../fusion-pixel-font-8px-monospaced-ttf-v2026.10.25.zip` 25,586,041 B sha256 710efe74f58967009d67b7fcd89bec2f13541c1259c41aa9194e9324aa84a7b9
  (all four match the digests GitHub publishes). The same release also offers OTF, BDF, PCF, WOFF, WOFF2 and `ms.bitmap.ttf` per size/width.
- Licence: SIL OFL 1.1 (font), MIT (build code); no Reserved Font Name declared in OFL.txt. README lists upstream licences: Ark Pixel (OFL), Misaki ("无类型许可证"
  = permissive free text, compatible with OFL; copy at assets/fonts/misaki/misaki.txt: "Unlimited permission is granted to use, copy, and distribute it ...
  commercially and noncommercially"), MisekiBitmap, BoutiqueBitmap 7x7/9x9, Cubic 11, Galmuri (all OFL). Zip carries the upstream licences in `LICENSES/`.
- README facts: made as a stop-gap successor of Ark Pixel ("临时过渡方案"); sizes 8, 10, 12 px; mono mode: widths fixed to half or full, height and line inside the em box,
  strictly aligned, but fewer characters and "baseline slightly high, Latin visual centre may sit high"; proportional mode: glyph-fitted widths, natural line height,
  kerning, "recommended unless special needs". Locale variants latin / zh-Hans / zh-Hant / zh-HK / zh-TW / ja / ko (Japanese kanji forms follow the Agency for Cultural Affairs
  jōyō list). An algorithmic bold lives in a separate project https://github.com/pixel-font-studio/fusion-bold-pixel-font (not downloaded).
- Measured (12 px mono ja): 37,213 glyphs (cmap 37,856); UPM 1200, lattice 100 units/px, phase 0 / 0 (exact); hhea 10/-2 (line 12); ASCII 6 px (digits identical), kana/kanji 12,
  hwkana 6; hira 86/86, kata 90/90, JIS symbols 492/524, L1 2965/2965, L2 3390/3390, CJK 19,466, Latin-1 95/96, Greek 99/144, Cyrillic 151/256; box 128/128 but 2 cells wide, arrows /
  geometric / blocks 2 cells, braille 1 cell, PL core 6/7; no Arabic, no NF. Caps 8 px, x-height 6, descender 2; ASCII gaps 1-5 px; 0 touching pairs of 8,836; every kana and
  every L1+L2 kanji keeps a >= 1 px gutter. isFixedPitch 0, fsType 4 (preview-print embedding), GSUB calt only, no hinting tables.
  Proportional 12 px: ASCII 4-10 px, digits all 6 px (tabular by default), hhea 13/-3 (line 16 px), caps 9, GPOS kern, same coverage, 0 touching pairs.
  10 px mono: 25,025 glyphs, caps 7 / x 5, L1 2965, L2 3390, no Greek/Cyrillic, one L1 kanji and one L2 kanji with zero gutter. 8 px mono: 28,050 glyphs, hira 83/86,
  kata 86/90.
- Tracker: #18 "字距显示不正常" (closed 2023-07-19): OTF glyphs overlapped in Photoshop CS6 / Edge, TTF fine, fixed in 2023.07.19; the author states for mono 12 px: half-width 6 px,
  full-width 12 px, 1 px visible gap. Open: #55 (punctuation size), #53 (locl single-file). #54 (closed): U+3031/3032 double height in mono.
- No 14 px exists (Ark Pixel issue #43 "Add a 14px version" is open).

### U6 Ark Pixel Font (TakWolf, 方舟像素字体)
- Official: https://github.com/TakWolf/ark-pixel-font ; 2026.10.25 (2026-10-24T23:38Z) https://github.com/TakWolf/ark-pixel-font/releases/tag/2026.10.25 ;
  `ark-pixel-font-12px-monospaced-ttf-v2026.10.25.zip` 36,866,334 B sha256 7d8df0c3f10c60ae89fd80acc26d1d19eba837e372c2f56998f62601a8dd961f ;
  `ark-pixel-font-10px-monospaced-ttf-v2026.10.25.zip` 3,494,954 B sha256 d8dcbab4bab763caaa6f21d170e416bf7181bbc72f2ea40e66cb3c1f8b29ad6b (both match host digests).
- Licence OFL 1.1 (no RFN). README warnings (2026): "the font is under active development and still lacks many characters; for 10 px and 12 px consider Fusion Pixel as the stop-gap";
  "the 16 px size is deprecated and removed; last build with 16 px is 2026.09.01; for 16 px consider Unifont".
- Measured (ja): 12 px: 25,264 glyphs, L1 2782/2965, L2 3033/3390 (incomplete), kana full; 10 px: 3,929 glyphs, L1 472, L2 165. Same Latin drawing and metrics as Fusion Pixel.

### U7 Misaki (美咲フォント, Little Limit / Num Kadoma)
- Official: https://littlelimit.net/misaki.htm ("8x8 dot Japanese bitmap font; JIS levels 1 and 2; every glyph except a few symbols fits in 7x7 so neighbours never touch").
  Latest 2021-05-05: https://littlelimit.net/arc/misaki/misaki_ttf_2021-05-05.zip 794,317 B sha256 c1851af85a0a010dd84f40803159c2d8a23feecb6c7e800cfeb5c6edc50da46e (no host digest).
  Variants in zip: misaki_gothic, misaki_gothic_2nd (half-width 3x7, kana 7x7), misaki_mincho. Also BDF / PNG / PC-E500 archives on the page.
- Licence (font page https://littlelimit.net/font.htm; same text in misaki.txt inside the zip): "These fonts are free software. Unlimited permission is granted to use, copy, and distribute them,
  with or without modification, either commercially or noncommercially. THESE FONTS ARE PROVIDED "AS IS" WITHOUT WARRANTY."
- Measured (gothic): 7,174 glyphs; UPM 2048, 256 units/px = native 8 px (on-lattice 8, 16, 24, 32 px); embedded bitmap strike 8 ppem (EBDT/EBLC) plus outlines; ASCII 4 px, kana/kanji 8 px;
  hira 83/86, kata 86/90, L1 2965, L2 3390, Latin-1 only 15/96, Greek 48, Cyrillic 66, box 43/128; caps 6 px, x 4; 0 touching pairs, min gutter 1.0 px everywhere.

### U8 k8x12 / k12x8 (Little Limit)
- Official: https://littlelimit.net/k8x12.htm and https://littlelimit.net/k12x8.htm ; same licence as Misaki (font.htm). 2021-05-05 builds:
  https://littlelimit.net/arc/k8x12/k8x12_ttf_2021-05-05.zip 1,170,095 B sha256 8d006e3171f4823ff1e81eaa285447129239071fc31ebafb8128696d0c1f1d17 ;
  https://littlelimit.net/arc/k12x8/k12x8_ttf_2021-05-05.zip 174,047 B sha256 7c3c707c70c97473c9b95196bfbf395346cca58752518ed3422cefc89785f6ef ;
  BDF and PNG archives also listed. k8x12 has k8x12L and k8x12S (non-kanji 8 dots high, dakuten on top).
- k8x12: "8x12 dot Japanese bitmap font, JIS levels 1 and 2 plus some symbols". Measured: portrait cells (kana/kanji 8 px wide x 12 px tall, ASCII 4 x 12), 7,173 glyphs, EBDT strike 12 ppem,
  caps 9, x 6, ASCII glyphs 3 px wide; hira 83/86, kata 86/90, L1/L2 full, Latin-1 15/96; 0 touching, gutter >= 1 px.
- k12x8: "12x8 dot ... JIS level 1 and symbols; content may change" ; measured L1 2965, L2 0.

### U9 JF Dot fonts (自家製ドットフォントシリーズ, Jikasei Font Koubou)
- Official page (served over plain http; https has a certificate hostname mismatch): http://jikasei.me/font/jf-dotfont/ ; archive (the page's own link)
  https://ftp.iij.ad.jp/pub/osdn.jp/users/8/8542/jfdotfont-20150527.zip 41,637,317 B (Last-Modified 2015-05-27) sha256 8e574faaaa7e27294aec66464aaf427447b2f0ccec8fe00c50e69bbf509f14b1
  (identical to the hash recorded in tools/build-fonts.py). 54 TTFs, outlines plus embedded bitmap strikes.
- Licences per the page: Shinonome 12/14/16, K12/K14, Kappa20, Ayu 18/20, Izumi, milkjf16, Kaname, k12x10, jiskan16s: public domain ("copyright waived; commercial, embedding, modification,
  redistribution without restriction; no credit needed"); M+10/12/H/S/Q and k6x8: M+ FONT LICENSE; jiskan24h half-width: OFL; jiskan16/24 half-width: Sony licence (notice required);
  Elisa 8, Pau 16, Naga 10 are separate zips with non-commercial / ask-first terms (not eligible).
- Measured (cell = native px x width): Shinonome12 6x12 (touch 0 alnum), Shinonome14 7x14 (52 alnum pairs, `T`), Shinonome16 8x16 (88; the Bold has 2376), K12 6x12 (0), K14 7x14 (52), Maru12 6x12 (0),
  Kanamecho12 6x12 (0; Latin-1 13/96; no box), Ayu18 9x18 (0), Ayu20 10x20 (0), Kappa20B 10x20 (814), Izumi16 8x16 (0; 11,387 glyphs), milkjf16 8x16 (0), M+12 6x12 (59), M+10 5x10 (118),
  k12x10 6x10 (0), k6x8 3x8 (3599). K12/K14: 11,382 glyphs, JIS X 0213, hira 86/86, kata 90/90, CJK 9,493. Outline phase relative to the baseline: Shinonome12 and K12 0.31 px, Shinonome14 0.03,
  Shinonome16 0.75, Kappa20 0.18-0.20 (so the outlines sit between pixel rows unless the embedded bitmap strike or 1-bit rasterising is used); fsType 8.
- Zero-gutter kanji: Shinonome12 441 of L1 (14.9 %) and 773 of L2 (22.8 %); Shinonome14 4 L1; K12 and K14 0 of L1 and L2 (kana 0 too).
- ASCII quirks (visible when drawn, JIS X 0201): in Shinonome, K12, K14 and Kappa the codepoint 0x5C `\` is drawn as the yen sign, 0x7E `~` as an overline, `'` and `` ` `` as curled quotes;
  U+00A5 draws a backslash. (Unifont, Fusion, Galmuri, k8x12, MaruMinya, DotGothic16 draw them normally.)
- No GitHub tracker; the site menu has a "不具合リスト" (bug list) page, not opened. BDF sources of the originals (Shinonome, M+ ...) are not part of this archive (TTF only).

### U10 GNU Unifont, Japanese build
- Official: https://unifoundry.com/unifont/index.html ; builds in https://unifoundry.com/pub/unifont/unifont-18.0.01/font-builds/ (all dated 2026-09-16, each with a .sig).
  Asset: unifont_jp-18.0.01.otf 5,250,304 B sha256 b411e78488d861f6b41fba514381123abb01ba7adeac8d0df8801a61891a14d3 (this repo currently uses 17.0.05).
- Licence (official page): since 13.0.04 dual-licensed SIL OFL 1.1 and GNU GPL 2+ with the GNU Font Embedding Exception; "OFL-1.1.txt" and "LICENSE.txt" on the site.
- Measured: CFF OpenType, 58,927 glyphs, UPM 64 (4 units/px), native 16 px (8x16 / 16x16), ASCII 8 / kana+kanji 16 exactly 1:2, digits identical, isFixedPitch 1;
  hira 86/86, kata 90/90, L1/L2 full, CJK 20,992; Arabic letters 42/42 (isolated forms, no shaping), Presentation Forms-B 144/144; Greek 144/144, Cyrillic 256/256;
  box 128/128, blocks, braille all 1 cell; arrows 104 of 112 one cell; geometric 95 of 96 one cell; no PL, no NF. hhea 14/-2 (line 16); caps 10, x 8, ascender 11.
  0 touching pairs (every glyph has a 1 px left margin), kana/kanji min gutter 1 px. Weight: Regular only. Also BDF / PCF official.

### U11 Cubic 11 (俐方體11號, ACh-K)
- Official: https://github.com/ACh-K/Cubic-11 ; release v1.500 (2026-06-27) has no assets; font in repo https://raw.githubusercontent.com/ACh-K/Cubic-11/HEAD/fonts/ttf/Cubic_11.ttf
  2,773,732 B sha256 0193f5f033612496df6b45ee92ac3b335bc6a5a24ff95da55ca87b33e57dcf62 (repo HEAD 4c566f7d6cc5; the TTF's own name table still says 1.451). OFL.txt sha256 2b6e5938...
- Licence OFL 1.1 (README: "Cubic" and "俐方體" reserved names; free to bundle with the OFL.txt, no sale of the file alone). Derived from M+ gothic 12r.
- Measured: proportional Latin (3-10 px), kana/kanji advance 13 px at a 12 px em, kerning table; Traditional-Chinese oriented (4808 Taiwan standard + Big5 5401 + JIS L1/L2 present, CJK 9,159); not monospace.
- Tracker: #9 (open, 2026-04): uneven stroke weight at 2x GUI scale.

### U12 BestTen (ベストテンFONT, フロップデザイン)
- Official distribution: https://booth.pm/ja/items/2747965 (free, Best10-FONT.zip 951 KB; the download sits behind BOOTH's "free download" button and a third-party directory, https://cute-freefont.flop.jp/flop_best-ten.html, says user registration is required, so not fetched).
  Page: "10x10 dot font; BestTen CRT (visually adjusted) and BestTen DOT; hiragana, katakana, Latin original, the rest from PixelMplus10; OpenType; about 7200 characters; commercial and non-commercial
  use, embedding in programs allowed; follows the M+ FONTS licence (Copyright (c) 2021 M+ FONTS PROJECT)". No explicit statement of redistributing the file itself. Unverified.

### U13 hicc's x0y0pxFreeFont fonts (patient-chief hicc)
- Official: https://hicchicc.github.io/00ff/ ; GitHub https://github.com/hicchicc (OFL repos: x12y12pxMaruMinya, x8y12pxDenkiChip, NegaPico, NegaClip, NegaTape).
  Site terms (SIL part): "SIL OFL: commercial use, embedding with OFL.txt, modification and redistribution under OFL, no sale of the font alone, no Reserved Font Name". Older fonts: "Original License"
  (free use incl. commercial and in games, modification and redistribution allowed, copyright retained, no sale of the font, credit optional); the site says all fonts are being moved to OFL in 2026.
- MaruMinya (マルミーニャ, 12x12 px, rounded gothic): OFL repo version 1.500 (2026-02-25), file https://raw.githubusercontent.com/hicchicc/x12y12pxMaruMinya/HEAD/fonts/ttf/x12y12pxMaruMinya.ttf
  2,667,128 B sha256 b05f108a3433602545f1dcb8acef167aaf744965d8d9571045d5f2cdbe12f9e5 (OFL.txt 7cb55f7f...; repo README: "Version 1.500 is a stop-gap that only moves the old licence data to OFL; 2.000 will follow").
  The site's original-licence TTF (2023-07-14) has sha256 b6923561bf3ba41c60a6d4b945c22c6e0b1e2bec77dd9272ee890cdf1d40d421. Measured: 7,536 glyphs, EBLC strike 12 ppem, ASCII 6 / 12 mono, rounded corners on a half-pixel lattice,
  hira 86/86, kata 90/90, L1/L2 full, Latin-1 96/96, Greek 48, Cyrillic 66; 0 touching ASCII pairs but 16 of 86 hiragana and 20 of 90 katakana have zero gutter. Tracker #1 (open, 2026-07-23): Latin capitals are
  9 px, kanji 11 px, and the baseline sits 1 px too high for the Latin.
- DenkiChip (x8y12px): v1.000 2026-02-19, https://github.com/hicchicc/x8y12pxDenkiChip/releases/download/v1.000/x8y12pxDenkiChip.zip 112,698 B sha256 c9acd8373b8fae7e63e2f56baa2482979e7d9b1e568ba00d338b7b29c9e8d9c5 (matches host); OFL;
  only 640 L1 kanji (L2 0), proportional-ish 3-8 px Latin.
- x14y24pxHeadUpDaisy (2025-09-19, original licence; sha256 c0b8c7ee...): 1,105 glyphs, 24 px tall; every character 14 px wide (ASCII and kana the same width, so not 1:2); no kanji (L1 0 of 2965). Embedded bitmaps since 2025-09-19.
  x12y16pxMaruMonica (2025-09-03, original licence, b9c7be04...): condensed rounded gothic, full JIS L1/L2, proportional Latin, 171 touching alnum pairs, EBLC strike 16 ppem.
  x8y12pxTheStrongGamer (2018), DonguriDuel, SolidLinker, LineLinker, ScanLine, ScoreDozer, GridGazer: no kanji (kana only or Latin only). Site list with sizes and dates: https://hicchicc.github.io/00ff/ .

### U14 Mona (モナーフォント)
- Official: https://monafont.sourceforge.net/ : Shinonome font with widths changed to match MS P Gothic (for 2ch ASCII art), i.e. proportional by design; "page last modified 2005, almost not maintained since Sep 2005";
  licence follows Shinonome (practically public domain). Not downloaded.

### U15 Galmuri (quiple)
- Official: https://github.com/quiple/galmuri ; v2.40.4 (2026-07-12) https://github.com/quiple/galmuri/releases/tag/v2.40.4 ; Galmuri-v2.40.4.zip 19,938,873 B sha256
  c8b3d9861a62ae73c8b1178091401cd79994812437ef386413f6dd54856e60e7 (matches host). Zip: TTF, bitmap-strike TTF, BDF, WOFF2, TTC for Galmuri14 (15 px), 11 (12 px; Regular, Bold, Condensed), 9 (10 px), 7 (8 px), and the Mono variants.
- Licence OFL 1.1 (zip LICENSE.txt "Copyright (c) 2019-2025 Lee Minseo", no RFN). README "Legal Stuff": glyphs other than Latin-1, kana, kanji, some symbols (and 2,355 Hangul syllables) are the author's own; "it does not mean Nintendo owns the
  rights to the glyphs I did not create" (design inspired by the Nintendo DS font); the author claims no rights in the design. Provenance caveat for kana/kanji/Latin-1.
- Measured GalmuriMono11: 20,327 glyphs, 12 px em on a 100-unit lattice (phase 0 / 0), ASCII 6 / kana+kanji 12 (1:2), digits identical, hira 86/86, kata 90/90, L1/L2 full, CJK 6,477, Latin-1 96/96, box 128/128 but 2 cells,
  PL core 7/7, caps 10 px tall (rows 1 to 11 above the em floor), x-height 7, descender 2, line = 12 + 2 + gap 2 = 16 px at 12 px; 0 touching ASCII pairs, kana/L1/L2 min gutter 1 px. Mono 9: 174 alnum pairs touch. Galmuri11 (non-mono): digits 6 and 8 px, GPOS kern.
- Tracker: #47 (closed 2023): parenthetical spacing / centering in Mono; #54 (closed): "Bitmap ttf seems to be damaged".

### U16 Cozette
- Official: https://github.com/the-moonwitch/Cozette (slavfox/Cozette redirects), v.1.30.0 2025-07-30; CozetteVector.ttf sha256 2d54a586f824f32d9d2dd01ec3b990c2a4d6445efa77e20177efe382ebe51627 (matches host). MIT licence.
  6x13 px programming bitmap font. Measured: full-width kana yes, L1 kanji 87 of 2965, NF subsets partial, Arabic none. Ineligible (no kanji).

### U17 Silver (Poppy Works)
- Official: https://poppyworks.itch.io/silver : CC BY 4.0, "free for personal and commercial use; if the production budget exceeds USD 100,000 contact hello@poppy.works"; Silver.ttf about 3.5 MB; CJK coverage "ongoing"; no pixel size,
  glyph count or direct download URL stated. Not downloaded (itch.io flow). Custom clause plus unverifiable coverage: ineligible.

---

# B. Terminal faces (coding fonts with Nerd Font glyphs and Japanese)

## B.0 Summary

NF = Nerd Font glyph sets. "1:2" = kana/kanji advance exactly twice the ASCII advance. "line" = hhea (ascent - descent + gap) in em. All JP-merged faces below have full kana, JIS L1 2965/2965 and L2 3390/3390 unless noted.

| id | candidate (asset measured) | version, date | licence (RFN) | Latin / Japanese base | half:full | ASCII adv (em) / line (em) | NF | box 2500-259F, ambiguous | ligatures | hinting | file |
|---|---|---|---|---|---|---|---|---|---|---|---|
| T1 | Fira Code (+ Nerd Fonts build) | 6.2, 2021-12-06; NF 3.5.1, 2026-08-21 | OFL 1.1 (none) | Fira Code / none | no Japanese | 0.6154 / 1.2308 | NF build: full | 160/160, 1 cell | `calt`, ss01-10, cv01-32, zero | fpgm prep cvt gasp 15 | 2.8 MB (NF Mono) |
| T2 | Firple (Slim) | 6.400, 2025-11-09 | OFL 1.1 (Firple, Plex) | Fira Code / IBM Plex Sans JP | 1:2 exact | 0.6154 (Slim 0.5231) / 1.2308 | full | 128/128, 1 cell; star U+2605/2606 2 cells | `calt` liga dlig ss01-11 cv01-33 | fpgm prep cvt gasp 15 | 8.5 MB/face |
| T3 | PlemolJP Console NF (35 Console NF) | v3.1.0, 2026-08-10 | OFL 1.1 (PlemolJP) | IBM Plex Mono / IBM Plex Sans JP | 1:2 exact (35: 3:5) | 0.528 (35: 0.600) / 1.175 | full, NF 3.5.0 | 128/128, 1 cell; arrows 1 cell | none for code (liga, dlig, ss01-09) | ttfautohint 1.8.4.16 | 8.0 MB/face |
| T4 | HackGen Console NF (35 Console NF) | v2.10.0, 2024-12-29 | OFL 1.1 (白源, HackGen) | Hack / GenJyuu Gothic | 1:2 exact (35: 3:5) | 0.5273 (35: 0.6035) / 1.121 | full, NF 3.3.0 | 128/128, 1 cell; stars 2 cells | none | ttfautohint 1.8.3 | 12.9 MB/face |
| T5 | UDEV Gothic NF (NFLG, 35NF) | v2.2.0, 2026-02-23 | OFL 1.1 (UDEV Gothic) | JetBrains Mono / BIZ UDGothic | 1:2 exact (35: 3:5) | 0.5000 (35: 0.5991) / 1.161 | full | 128/128, 1 cell; stars 2 cells | NFLG only (JetBrains `calt`) | ttfautohint 1.8.4.7 | 6.2 MB/face |
| T6 | Moralerspace HW (Neon etc.) | v2.0.0, 2025-07-28 | OFL 1.1 (Moralerspace) | Monaspace / IBM Plex Sans JP | HW 1:2 exact; default 3:5 | HW 0.525 (default 0.600) / 1.20 | full, built in, NF 3.4.0 | 104/160 present, all 2 cells wide | `calt` (texture healing, ligatures), ss01-10 | ttfautohint 1.8.4.7 | 8.0 MB/face |
| T7 | Maple Mono NF CN (stable) / NF JP (pre-release) | v7.9, 2025-12-05 / v8.0-beta.3, 2026-09-20 | OFL 1.1 | own / v7.9 CN: Resource Han Rounded; v8 beta: WenYuan Rounded SC (CN), Resource Han Rounded JP (JP) | 1:2 exact | 0.6000 / 1.32 | full, built in | 160/160, 1 cell | `calt` (NL files: none) | unhinted build (gasp only) | 20.6 MB (CN), 6.6 MB (JP) |
| T8 | JetBrains Mono (+ NF 3.5.1) | v2.304, 2023-01-14 | OFL 1.1 (none) | JetBrains Mono / none | no Japanese | 0.6000 / 1.32 | NF build full | 160/160, 1 cell | `calt`; NL builds none | ttfautohint 1.8.4.7 | 2.6 MB (NF Mono) |
| T9 | Iosevka Term | v34.9.1, 2026-10-24 | OFL 1.1 | Iosevka / none | no Japanese | 0.5000 / 1.25 | no NF (PL 7 + 13 only) | 160/160, 1 cell | `calt`; Fixed: none | fpgm prep cvt gasp 15 | n/m |
| T10 | Sarasa Fixed J | v1.0.43, 2026-10-25 | OFL 1.1 (Source) | Iosevka / Source Han Sans (J forms) | 1:2 exact | 0.5000 / 1.25 | no NF (PL 7 + 13) | 160/160, 1 cell; all ambiguous 1 cell | none (Fixed) | ttfautohint 1.8.4 | 25.7 MB/face |
| T11 | Cica | v5.0.3, 2022-03-26 | OFL 1.1 + Vera etc. (Cica) | Hack + DejaVu Sans Mono / Rounded Mgen+ | 1:2 exact | 0.5000 / 1.026 (typo 0.756, win 1.000) | old subset, no MDI v3, Codicons 0 | 160/160, 1 cell | liga only | fpgm prep cvt gasp 2 | n/m |
| T12 | Firge Nerd Console | v0.3.0, 2023-11-11 | OFL 1.1 (Firge) | Fira Mono / Genshin Gothic | 1:2 exact | 0.5273 / 1.121 | older NF | 116/160 | calt | ttfautohint 1.8.3 | n/m |
| T13 | Bizin Gothic NF | v0.0.4, 2024-06-16 | OFL 1.1 (Bizin Gothic) | Inconsolata / BIZ UDGothic | 1:2 exact | 0.5000 / 1.000 | NF (FA 679) | 160/160, 1 cell | liga dlig | ttfautohint 1.8.4.7 | n/m |
| T14 | M PLUS 1 Code (Google Fonts) | 1.100, added 2021-09-22 | OFL 1.1 | own | 1:2 exact | 0.5000 / 1.235 | none | 160/160, 1 cell; arrows/geometric missing | liga dlig | prep gasp | 3.9 MB (variable) |
| T15 | Source Han Code JP | 2.012R, 2020-11-25 | OFL 1.1 | Source Code Pro / Source Han Sans JP | 2:3 (not 1:2) | 0.667 / 1.453 (typo 1.0) | none | 160/160, 2 cells wide | n/m | CFF | n/m |
| T16 | Noto Sans Mono CJK JP | Sans2.004, 2022-01-27 | OFL 1.1 | Noto Sans Mono / Noto Sans CJK JP | 1:2 exact | 0.5000 / 1.448 (typo 1.0) | none | 160/160, 2 cells wide; arrows and geometric 2 cells | calt dlig liga (CFF) | CFF, no tables | 27.8 MB zip |

## B.1 Cell at 13 / 14 / 15 / 16 px (ASCII advance x line, px; line from hhea unless noted; advance = advance / UPM x size)

| candidate | 13 | 14 | 15 | 16 | whole sizes 12-20 px with an integer advance |
|---|---|---|---|---|---|
| Fira Code, Firple, Fira Code NF | 8.00 x 16.00 | 8.62 x 17.23 | 9.23 x 18.46 | 9.85 x 19.69 | 13 (8 px) |
| Firple Slim | 6.80 x 16.00 | 7.32 x 17.23 | 7.85 x 18.46 | 8.37 x 19.69 | none (13.4 gives 7) |
| JetBrains Mono, Maple Mono, PlemolJP35 (adv 0.6) | 7.80 x 17.16 (Plemol35 15.28) | 8.40 x 18.48 (16.45) | 9.00 x 19.80 (17.62) | 9.60 x 21.12 (18.80) | 15 (9 px), 20 (12 px) |
| PlemolJP Console NF (1:2) | 6.86 x 15.28 | 7.39 x 16.45 | 7.92 x 17.62 | 8.45 x 18.80 | none (17 gives 8.98) |
| HackGen Console NF (1:2) | 6.86 x 14.57 | 7.38 x 15.70 | 7.91 x 16.82 | 8.44 x 17.94 | none (13.3 gives 7) |
| UDEV Gothic NF (1:2) | 6.50 x 15.09 | 7.00 x 16.26 | 7.50 x 17.42 | 8.00 x 18.58 | 12, 14, 16, 18, 20 (6 to 10 px) |
| UDEV Gothic 35NF | 7.79 x 15.09 | 8.39 x 16.26 | 8.99 x 17.42 | 9.59 x 18.58 | 15 (9 px) |
| Moralerspace HW | 6.83 x 15.60 | 7.35 x 16.80 | 7.88 x 18.00 | 8.40 x 19.20 | none |
| Moralerspace default 3:5 | 7.80 x 15.60 | 8.40 x 16.80 | 9.00 x 18.00 | 9.60 x 19.20 | 15, 20 |
| Sarasa Fixed J, Iosevka Term | 6.50 x 16.25 | 7.00 x 17.50 | 7.50 x 18.75 | 8.00 x 20.00 | 12, 14, 16, 18, 20 |
| M PLUS 1 Code | 6.50 x 16.05 | 7.00 x 17.29 | 7.50 x 18.53 | 8.00 x 19.76 | 12, 14, 16, 18, 20 |
| Noto Sans Mono CJK JP | 6.50 x 18.82 (typo 13.00) | 7.00 x 20.27 (14.00) | 7.50 x 21.72 (15.00) | 8.00 x 23.17 (16.00) | 12, 14, 16, 18, 20 |
| Cica | 6.50 x 13.34 (typo 9.83, win 13.00) | 7.00 x 14.37 | 7.50 x 15.40 | 8.00 x 16.42 | 12, 14, 16, 18, 20 |
| Bizin Gothic NF | 6.50 x 13.00 | 7.00 x 14.00 | 7.50 x 15.00 | 8.00 x 16.00 | 12, 14, 16, 18, 20 |
| Source Han Code JP (adv 0.667) | 8.67 x 18.89 (typo 13.00) | 9.34 x 20.34 | 10.01 x 21.80 | 10.67 x 23.25 | none |
| today: Sumi Term (bitmap) | 10 x 20 cell, line 24 | | | | |

## B.2 Nerd Font coverage, measured (counts per range as defined at the top)

- Full 3.x set (PL core 7/7, PL extra 31/32, Seti 190/190, Devicons 198/198, Font Awesome 737/737, Octicons 308/308, Codicons 388/396, Material Design v3 6896/6896 [Maple v7.9: 6880],
  Weather 228/228, Font Logos 118/118, Pomicons 11/11): Fira Code NF, JetBrains Mono NF, Firple, PlemolJP NF, HackGen NF, UDEV Gothic NF, Moralerspace, Maple NF CN / JP.
  Nerd Fonts' own licence audit https://github.com/ryanoasis/nerd-fonts/blob/v3.5.1/license-audit.md (v3.5.1): patched fonts OFL 1.1; icon sets Codicons CC BY 4.0, Devicons MIT, Font Awesome CC BY 4.0,
  Font Awesome Extension MIT, Font Logos unlicensed, IEC Power Symbols MIT, Material Design Icons Apache 2.0, Seti-UI MIT, Octicons MIT, Pomicons SIL OFL 1.1, Powerline Extra MIT, Powerline Symbols "Free License",
  Weather Icons OFL 1.1. Nerd Fonts licence file: patched fonts OFL 1.1, scripts MIT. (Cica's README says Pomicons are excluded because of a commercial-use restriction in the older Nerd Fonts; v3.5.1 lists Pomicons as OFL.)
- Older NF subsets: Bizin NF (Seti 185, FA 679, Font Logos 115), Firge Nerd (Seti 179, FA 679, Logos 48), Cica (Seti 53, Devicons 198, FA 679, Octicons 170, Codicons 0, MDI v3 0, Pomicons 0).
- No NF: Iosevka Term and Sarasa Fixed J (Powerline 7/7 core and 13/32 extra only), Source Han Code JP, Noto Sans Mono CJK JP, M PLUS 1 Code (PL 0).
- Version stated by the project: Fira Code NF and JetBrains Mono NF 3.5.1 (also in the font's version string), PlemolJP NF v3.1.0 uses NF 3.5.0 (release notes), HackGen NF v2.10.0 uses NF 3.3.0 (release notes),
  Moralerspace v2.0.0 uses NF 3.4.0 (release notes; Monaspace 1.200 now ships NF), UDEV / Maple / Firple / Bizin: version not stated.
- Arabic letters (42 basic): 0 in every terminal face except Cica (36 of 42, plus 124 of 144 presentation forms B, from DejaVu Sans Mono). Terminal faces without it need a fallback for Arabic.

## B.3 Per-candidate facts and sources

### T1 Fira Code (+ Nerd Fonts build)
- Official: https://github.com/tonsky/FiraCode ; README download "Fira_Code_v6.2.zip - December 6, 2021 - 2.5 MB". Release 6.2 https://github.com/tonsky/FiraCode/releases/tag/6.2 is the newest tag.
  Asset https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip 2,462,987 B sha256 0949915ba8eb24d89fd93d10a7ff623f42830d7c5ffc3ecbf960e4ecad3e3e79 (no host digest). Zip: static TTF (Light, Regular, Retina, Medium, SemiBold, Bold) and variable fonts.
- Licence: https://raw.githubusercontent.com/tonsky/FiraCode/master/LICENSE : "Copyright (c) 2014, The Fira Code Project Authors ... SIL Open Font License, Version 1.1", no RFN.
- Nerd Fonts build: https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1 (2026-08-21) FiraCode.tar.xz 3,061,404 B sha256 68e3bd6164864b8b514605bc34e3a87ac401c8c48682fcce6478c70263340207 (matches host);
  FiraCode.zip 28,602,426 B; faces FiraCodeNerdFont, ...Mono (icons squeezed into one cell), ...Propo in Light, Regular, Retina, Medium, SemiBold, Bold; 12,885 glyphs; version string "Version 6.002;Nerd Fonts 3.5.1".
- Measured (Regular): TrueType, 2,030 glyphs, UPM 1950, ASCII 1200 (0.6154 em), line 2400/1950 = 1.2308 em; hinted (fpgm, prep, cvt, gasp 15); box 160/160 and arrows, geometric all 1 cell; PL core 7/7; Greek 121, Cyrillic 240; no kana, no kanji; these TUI symbols are missing: ★ ☆ ✗ ✔ ✘ ❯ ❮ ⏺. Features: calt (all ligatures), ss01-ss10, cv01-cv32, zero, onum, tnum, frac, hwid. No separate no-ligature build; turn off with `calt`.
- Tracker (searched): #1659 (open, 2025-06-27) line spacing inconsistent between weights; #1579 (open, 2024) "v2 heights were much better in a terminal with background colors"; #1557 (open) misaligned `::` ligatures. No Japanese.

### T2 Firple (negset)
- Official: https://github.com/negset/Firple ; README: Fira Code + IBM Plex Sans JP, half:full width 1:2, ligatures, Regular + Bold, own italic, Slim family, Nerd Fonts, `cv33` shows the full-width space, `ss11` emphasises the handakuten.
  Release 6.400 (2025-11-09, "IBM Plex Sans JP 1.003 -> 1.004") https://github.com/negset/Firple/releases/tag/6.400 ;
  https://github.com/negset/Firple/releases/download/6.400/Firple.zip 20,633,214 B sha256 2723183407cc5aa17f9cf4f99968cf72313cabc9137ac45e5133c1640efee4da ;
  https://github.com/negset/Firple/releases/download/6.400/FirpleSlim.zip 20,653,010 B sha256 ead98bfc27c34f3d387fa90d00bc12b151ebd2c22f41d7b690f401d098c4524a (both match host digests).
- Licence https://raw.githubusercontent.com/negset/Firple/HEAD/LICENSE : OFL 1.1; "Copyright (c) 2021 negset with Reserved Font Name Firple", Fira Code Project Authors 2014, "Copyright (c) 2017 IBM Corp. with Reserved Font Name Plex".
- Measured (Regular): 34,729 glyphs, same Latin metrics as Fira Code (UPM 1950, ASCII 1200, line 1.2308 em, 13 px gives 8.00 x 16.00 exactly), kana/kanji 2400 = 1:2, hwkana 1200; CJK 12,710, Greek 121, Cyrillic 240; NF full;
  box 128/128 one cell; arrows 25 one cell and 13 two cells; ★ ☆ two cells; ✗ ✔ ✘ ⏺ missing (✓ ❯ ❮ present, one cell). Hinted (fpgm prep cvt gasp 15). Features calt liga dlig ccmp locl ital jp78 jp90 fwid hwid pwid zero, ss01-ss11, cv01-cv33.
  Slim: ASCII 1020 (0.523 em), kana 2040. Files 8.5 MB per face.
- Tracker: #6 (closed) build question only.

### T3 PlemolJP (yuru7)
- Official: https://github.com/yuru7/PlemolJP ; README: IBM Plex Mono + IBM Plex Sans JP; families PlemolJP (1:2), Console (all Plex Mono symbols kept, arrows half-width, for consoles), 35 (3:5), 35 Console; 8 weights Thin..Bold (plus Text) normal and italic; full-width space made visible (HS = hidden).
  Release v3.1.0 (2026-08-10; IBM Plex Mono 2.005, Plex Sans JP 1.004, Nerd Fonts 3.5.0) https://github.com/yuru7/PlemolJP/releases/tag/v3.1.0 ;
  https://github.com/yuru7/PlemolJP/releases/download/v3.1.0/PlemolJP_NF_v3.1.0.zip 153,474,006 B sha256 015142b7ce4fb497ea6eb14567c435b69450eb5028fb7d29c032d1ffb3854abb (matches host). That NF zip holds only the two Console families (`PlemolJPConsoleNF-*`, `PlemolJP35ConsoleNF-*`, 16 files each).
  The plain zip (PlemolJP_v3.1.0.zip, 221,817,247 B) and the HS zip have no NF.
- Licence https://raw.githubusercontent.com/yuru7/PlemolJP/HEAD/LICENSE : OFL 1.1, "Copyright (c) 2021, Yuko OTAWARA, with Reserved Font Name PlemolJP"; scripts MIT.
- Measured (Console NF Regular): 34,726 glyphs, UPM 1000, ASCII 528 (0.528 em), kana 1056 (exact 1:2), hhea 950/-225 (1.175 em, typo identical, USE_TYPO off); isFixedPitch 1 (35: 0, panose 3). CJK 12,710, Greek 77, Cyrillic 204;
  box 128/128 one cell, arrows 109 one cell, ★ ☆ ✓ ✔ ❯ ❮ one cell, ✗ ✘ ⏺ missing; NF full. ttfautohint 1.8.4.16 (-l 6 -r 45 -G 200 -x 14 -a qsq -W -S -X "13-"). Features liga dlig ccmp locl ital jp78 jp90 fwid hwid pwid trad zero, ss01-ss09; no calt. 8.0 MB per face.
- Tracker (searched): no hits.

### T4 HackGen (yuru7)
- Official: https://github.com/yuru7/HackGen ; README: Hack + GenJyuu Gothic (Source Han Sans-derived rounded), 1:2 (3:5 included), hinted Latin, Powerline, JIS levels 1-4 kanji, visible full-width space, broken-bar pipe, enlarged dakuten, accents on ー/ヘ.
  Release v2.10.0 (2024-12-29, Nerd Fonts 3.3.0) https://github.com/yuru7/HackGen/releases/tag/v2.10.0 (still the newest, 22 months old) ;
  https://github.com/yuru7/HackGen/releases/download/v2.10.0/HackGen_NF_v2.10.0.zip 25,120,250 B sha256 f8abd483d5edfad88a78ed511978f43c83b43c48e364aa29ebe4a68217474428 (no host digest).
  NF zip holds `HackGenConsoleNF-*` (1:2) and `HackGen35ConsoleNF-*` (3:5), Regular and Bold only.
- Licence https://raw.githubusercontent.com/yuru7/HackGen/HEAD/LICENSE : OFL 1.1, Reserved Font Names "白源" and "HackGen"; scripts MIT.
- Measured (Console NF Regular): 30,182 glyphs, UPM 1024, ASCII 540 (0.5273 em), kana 1080 (exact 1:2), hhea 938/-210, typo 881/-143/80 (USE_TYPO off, so cells use hhea: 14 px gives 7.38 x 15.70); CJK 12,721; Greek 120, Cyrillic 237; box 128/128 one cell;
  arrows one cell; check, cross and star two cells; NF full; hinted (ttfautohint 1.8.3). GSUB only ccmp locl jp78 jp90 vert vrt2 (no ligatures). 6 alnum pairs overlap by 0.002 em. 12.9 MB per face.
- Tracker: #1 "Kerning Error" (closed 2019). Nothing recent.

### T5 UDEV Gothic (yuru7)
- Official: https://github.com/yuru7/udev-gothic ; README: JetBrains Mono (Latin, slashed zero) + BIZ UDゴシック (Japanese), IVS variants, visible full-width space; variants 1:2 (default) / `35` 3:5 / `JPDOC` (arrows, squares, ellipsis full-width) / `LG` (JetBrains ligatures) / `NF` / `HS`.
  Release v2.2.0 (2026-02-23) https://github.com/yuru7/udev-gothic/releases/tag/v2.2.0 ; https://github.com/yuru7/udev-gothic/releases/download/v2.2.0/UDEVGothic_NF_v2.2.0.zip 60,939,546 B
  sha256 45faeef7b5d8bc591bcc5887a2ca0c5fb9028066f18a5a52cd6f10b7d655ba37 (matches host). NF zip: UDEVGothicNF, UDEVGothicNFLG, UDEVGothic35NF, UDEVGothic35NFLG, each Regular + Bold (+ italics). (JPDOC and HS builds are separate zips.)
- Licence https://raw.githubusercontent.com/yuru7/udev-gothic/HEAD/LICENSE : OFL 1.1, "Copyright (c) 2022 Yuko OTAWARA with Reserved Font Name UDEV Gothic".
- Measured (UDEVGothicNF-Regular): 25,242 glyphs, UPM 2048, ASCII 1024 (exactly 0.5 em), kana/kanji 2048 (exact 1:2), hhea 1962/-416 (1.161 em; cell 14 px = 7.00 x 16.26, 16 px = 8.00 x 18.58), isFixedPitch 1; CJK 9,575, Greek 79, Cyrillic 122;
  box 128/128 one cell, arrows 38 one cell, ★ ☆ two cells, ✔ ✘ ⏺ missing; NF full. ttfautohint 1.8.4.7 (-l 6 -r 45 -G 200 -x 0 -D latn -a qsq -W -S -X "14-"). Non-LG: GSUB dlig liga fwid hwid jp78 jp90 vert zero (no calt); NFLG adds JetBrains calt, ss, cv.
  35NF: ASCII 1227 (0.599 em), isFixedPitch 0. 6.2 MB per face.
- Tracker (searched): no hits.

### T6 Moralerspace (yuru7)
- Official: https://github.com/yuru7/moralerspace ; README: Monaspace (texture healing) + IBM Plex Sans JP; families Argon, Neon, Xenon, Radon (Japanese based on Kiwi Maru), Krypton (based on Stick); "box-drawing pieces and some half-width symbols are merged from Hack"; default 3:5, HW 1:2, JPDOC variants (arrows, squares full-width), visible full-width space.
  Release v2.0.0 (2025-07-28; Monaspace 1.200, Plex Sans JP 1.003 = Adobe-Japan1-7, NF 3.4.0 built into every variant) https://github.com/yuru7/moralerspace/releases/tag/v2.0.0 ;
  MoralerspaceHW_v2.0.0.zip 102,017,180 B sha256 500a7774297c829265ebd472b6d8c1159cfb3e9daa4ca0570170af541b991b7d ; Moralerspace_v2.0.0.zip 101,974,524 B sha256 56175ee16373ba1a3d2fd5ec46f3b0b6bf0412be7db1481ec7dee757f2e3d557 (both match host);
  https://github.com/yuru7/moralerspace/releases/download/v2.0.0/MoralerspaceHW_v2.0.0.zip . Regular, Bold, Italic, BoldItalic per family.
- Licence https://raw.githubusercontent.com/yuru7/moralerspace/HEAD/LICENSE : OFL 1.1, "Copyright (c) 2022 Yuko Otawara, with Reserved Font Name Moralerspace".
- Measured (Neon, Neon HW): 35,093 glyphs, UPM 1000, ASCII 600 / kana 1000 (3:5, isFixedPitch 0) and HW 525 / 1050 (exact 1:2, isFixedPitch 1), hhea 950/-250 (1.2 em); NF full; Greek 77, Cyrillic 180; U+2500-259F: only 104 of 160 present and every one
  full-width (1000 / 1050; U+254C-254F, U+2551 ... missing), arrows 109 one cell, geometric 96 one cell; legacy-computing 10. Features calt (texture healing and ligatures), ss01-ss10, ital, init medi fina; no GPOS. fsType 8. ttfautohint 1.8.4.7. 8.0 MB per face.
- Tracker: #3 (closed 2024-02): Nerd Font glyphs broken in Windows Terminal.

### T7 Maple Mono (subframe7536)
- Official: https://github.com/subframe7536/maple-font (README on the `variable` branch). OFL 1.1 ("License: SIL Open Font License 1.1"; LICENSE.txt in each zip).
  Stable v7.9 (2025-12-05) https://github.com/subframe7536/maple-font/releases/tag/v7.9 : `MapleMono-NF-unhinted.zip` 20,560,550 B sha256 8248d6260660be1066b5ebe90d25131582df8383f38db1c284dd1f2dc9d2b46e (Latin + NF, no Japanese);
  `MapleMono-NF-CN-unhinted.zip` 158,916,064 B sha256 ab88522932cf4015dffeaef6dedc59a22a5fefecdcc6e583d9fcd997da5b7cac (README at tag v7.9: "CN version based on Resource Han Rounded (https://github.com/CyanoHao/Resource-Han-Rounded) provides complete character set support for Chinese development environments, including Simplified Chinese, Traditional Chinese, and Japanese", perfect 2:1 alignment); NL (no ligature), Normal (JetBrains-like zero),
  hinted ("AutoHint") and variable builds exist. Pre-release v8.0-beta.3 (2026-09-20) https://github.com/subframe7536/maple-font/releases/tag/v8.0-beta.3 : adds JP, KR, TC builds (JP from Resource Han Rounded JP), width modes default 600 / narrow 550 / slim 500;
  `MapleMono-NF-JP-unhinted.zip` 60,027,826 B sha256 8ad6bd1af3f5cd86250495e2d31bf0b3a5336781b00c2b8f7aa96f5f85e59720 (all three match host digests). README: CJK is 2:1 against Latin, "default CJK spacing is wider than in many other CJK fonts" (#211).
- Measured: CN v7.9: 33,637 glyphs, ASCII 600 / kana+kanji 1200 (exact 1:2), hira 86, kata 90, half-width katakana 0, L1/L2 full, CJK 20,976, box 160/160 one cell, hhea 1020/-300 (1.32 em), USE_TYPO on, unhinted (gasp 10);
  JP v8b3: 20,263 glyphs, hwkana 63, CJK 6,682, same metrics, gasp 15. Weights Thin, ExtraLight, Light, Regular, Medium, SemiBold, Bold, ExtraBold plus italics. Features calt, zero, ss01-ss13, cv01-cv99. 20.6 MB (CN) and 6.6 MB (JP) per face.
- Tracker (searched): #847 (open, 2026-10-08) the Thin/ExtraLight usWeightClass workaround makes the ExtraLight face unresolvable on fontconfig; #481 (closed) "isn't mono family in kali"; #562 (closed) `===` at 16 px and below;
  #518 (closed) hinting issue; #525 (open) ligature issues in the VS Code terminal.

### T8 JetBrains Mono (+ Nerd Fonts)
- Official: https://github.com/JetBrains/JetBrainsMono ; v2.304 (2023-01-14, newest) https://github.com/JetBrains/JetBrainsMono/releases/tag/v2.304 ;
  https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip 5,622,857 B sha256 6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf (no host digest). Licence https://raw.githubusercontent.com/JetBrains/JetBrainsMono/HEAD/OFL.txt : OFL 1.1, no RFN.
- NF: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz 7,284,244 B sha256 04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf (matches host): JetBrainsMono, JetBrainsMonoNL (no ligatures) in Nerd Font / Mono / Propo, 8 weights + italics.
  Already installed on this PC (user fonts, `~/.local/share/fonts/JetBrainsMonoNerd/`).
- Measured: UPM 1000, ASCII 600, line 1.32 em, ttfautohint 1.8.4.7, box 160/160 one cell, PL core 7/7, no kana; Greek 79, Cyrillic 122; GSUB calt ccmp locl zero, ss01-ss20 (4), cv01-cv99 (20); NL has no GSUB. Weights Thin ... ExtraBold + variable. NF Mono build: 12,608 glyphs.
- Tracker (searched): #484 (closed 2021) line-drawing glyphs overlap; #546 (closed 2023) cannot align with the Chinese height in MacVim/gVim; #208 (open) optimal line spacing.

### T9 Iosevka
- Official: https://github.com/be5invis/Iosevka ; v34.9.1 (2026-10-24) https://github.com/be5invis/Iosevka/releases/tag/v34.9.1 ; `PkgTTF-IosevkaTerm-34.9.1.zip` 176,905,999 B sha256 3bd57a66a7f1e429a131d3bc35f4d0f3a8eb722f2fe8f59f595e424bda9a33c9 (matches host);
  Fixed (no ligatures): PkgTTF-IosevkaFixed. Package list https://github.com/be5invis/Iosevka/blob/v34.9.1/doc/PACKAGE-LIST.md : Default (wide arrows), Term (narrow arrows, "focusing terminal uses"), Fixed (exact monospace, no ligatures).
- Licence https://raw.githubusercontent.com/be5invis/Iosevka/HEAD/LICENSE.md : OFL 1.1, "Copyright (c) 2015-2026, Renzhi Li". No Japanese, no NF in the official release (README points CJK users to Sarasa Gothic).
- Measured (Term Regular): 48,794 glyphs, ASCII 500 (0.5 em), line 1.25 em (hhea 965/-215/70; typo 965/-285), isFixedPitch 1, fpgm/prep/cvt/gasp 15, box and every ambiguous symbol one cell, PL core 7/7 extra 13/32, legacy-computing 247/256, Greek 121, Cyrillic 256;
  calt, dlig, ss01-ss20, cv01-cv99. 54 TTFs (9 weights x 3 widths x slants).
- Tracker (searched): #3218 (closed 2026-08-27) Iosevka Term and Fixed not seen as monospaced in VS Code on Linux; #3123 pointing-triangle width differs Iosevka vs Term.

### T10 Sarasa Gothic (be5invis)
- Official: https://github.com/be5invis/Sarasa-Gothic ; v1.0.43 (2026-10-25) https://github.com/be5invis/Sarasa-Gothic/releases/tag/v1.0.43 ; `SarasaFixedJ-TTF-1.0.43.7z` 67,348,260 B sha256 f43204cda9beb60b06871000b9b813929a6942ec64a7299cc3dde8693e86a4fd (matches host).
  README naming: Latin from Iosevka -> Mono (em dashes full-width) / Term (half-width) / Fixed (no ligatures, half-width dashes); Latin from Inter -> Gothic / UI; orthography CL, SC, TC, J, K, HC. Hinted and unhinted packages; TTC and SuperTTC too.
- Licence https://raw.githubusercontent.com/be5invis/Sarasa-Gothic/HEAD/LICENSE : OFL 1.1, "Copyright (c) 2015-2025 Renzhi Li; portions Inter, Source Han Sans (RFN Source), Google". No NF in the official release (README silent; measured Seti/Devicons/FA 0).
- Measured (Fixed J Regular): 55,471 glyphs, ASCII 500 / kana+kanji 1000 (exact 1:2), digits identical, hhea 965/-215/70 (1.25 em), typo 965/-285, USE_TYPO on, ttfautohint 1.8.4, isFixedPitch 1; CJK 20,992, Greek 121, Cyrillic 256; box 160/160 and all ambiguous symbols one cell;
  PL core 7/7, extra 13/32; no ligature features. Weights ExtraLight, Light, Regular, SemiBold, Bold + italics. 25.7 MB per face.
- Tracker (searched): #470 (open, 2026-07-12) request to limit maximum glyph heights (some CJK symbols push the line height); #230 (closed 2021) Term/Fixed not recognised as monospace by fontconfig; #51 (closed 2018) full-width widths.

### T11 Cica (miiton)
- Official: https://github.com/miiton/Cica ; v5.0.3 (2022-03-26, newest; the notice says earlier binaries were deleted over missing OFL copyright lines) ; https://github.com/miiton/Cica/releases/download/v5.0.3/Cica_v5.0.3.zip 23,402,716 B sha256 cbd1bcf1f3fd1ddbffe444369c76e42529add8538b25aeb75ab682d398b0506f (no host digest).
- Licence https://raw.githubusercontent.com/miiton/Cica/HEAD/LICENSE.txt : font OFL 1.1 ("Copyright (c) 2018, Takahiro Minami, Reserved Font Name Cica"), generator MIT; sources Hack, DejaVu Sans Mono (Bitstream Vera), Rounded Mgen+, Rounded M+, M+ OUTLINE, Noto Emoji, Nerd Fonts (Pomicons dropped).
- Measured: 23,853 glyphs, UPM 1024, ASCII 512 (0.5 em), kana 1024 (exact 1:2), isFixedPitch 0; Arabic 36/42 + 124/144; NF older subset; vertical metrics disagree (hhea 852/-199, typo 670/-104, win 820/204); fpgm prep cvt gasp 2; arrows and geometric one cell, star/check two cells.
- Tracker: #90 (open, 2025-10-06) some box-drawing characters not aligned.

### T12 Firge (yuru7) and T13 Bizin Gothic (yuru7)
- Firge: https://github.com/yuru7/Firge v0.3.0 (2023-11-11) FirgeNerd_v0.3.0.zip 16,284,753 B sha256 54cd76378fbc5025f42d441d95ca6ec1d3ecc4270e6107558840fed7c04cfe4f ; Fira Mono + Genshin Gothic; OFL 1.1 (RFN Firge). Measured FirgeNerdConsole: 28,687 glyphs, ASCII 0.5273 em, 1:2, hhea line 1.121 em,
  older NF (Seti 179, FA 679, Logos 48), box 116/160. Tracker: no hits.
- Bizin Gothic: https://github.com/yuru7/bizin-gothic v0.0.4 (2024-06-16) BizinGothicNF_v0.0.4.zip 13,545,087 B sha256 027982bfbd535d411f03f7bf603545493516eb51a98b49616053e926b9211215 ; Inconsolata + BIZ UDGothic; OFL 1.1 (RFN "Bizin Gothic").
  Measured NF Regular: 23,692 glyphs, 0.5 em, 1:2, hhea line exactly 1.000 em (14 px gives 7.00 x 14.00), NF FA 679 / MDI v3 6896.

### T14 M PLUS 1 Code
- Official: Google Fonts https://github.com/google/fonts/tree/main/ofl/mplus1code (METADATA.pb: designer Coji Morishita, OFL, added 2021-09-22, upstream https://github.com/coz-m/MPLUS_FONTS commit 4bf69824...). File `MPLUS1Code[wght].ttf` 3,933,000 B sha256
  ff68678c5bd7e9d9d6ab6d57e4355aabe30f6b8f8bff9bd59baf6a7807dcfd36 (https://raw.githubusercontent.com/google/fonts/main/ofl/mplus1code/MPLUS1Code%5Bwght%5D.ttf), OFL.txt 04971e3f...
- Measured: version 1.100, variable wght 100-700, ASCII 0.5 em, kana/kanji 1:2, 6,747 glyphs, L1 2965/2965 but L2 only 2266/3390, hira 84/86, no half-width katakana, no NF, no Powerline, arrows / geometric / check missing, box 160/160 one cell, hinting prep + gasp 15.

### T15 Source Han Code JP / T16 Noto Sans Mono CJK JP
- Source Han Code JP: https://github.com/adobe-fonts/source-han-code-jp 2.012R (2020-11-25) SourceHanCodeJP.ttc 30,233,664 B sha256 f430938b1056e79ff60cf422876e3bbbd348f578d38ff643074e2d6992cd95f5 (14 faces EL..H + italics); OFL 1.1.
  Measured: CFF, UPM 1000, ASCII 667 vs kana 1000 (2:3, not 1:2), hhea 1133/-320 (typo 880/-120), no NF, isFixedPitch 0, U+2500-259F 160/160 drawn 1000 wide (1.5 cells), no hinting tables. Ineligible.
- Noto Sans Mono CJK JP: https://github.com/notofonts/noto-cjk release Sans2.004 (2022-01-27) 11_NotoSansMonoCJKjp.zip 27,839,173 B sha256 6c8faf475ce78fa37486dd5d8920e4bb4450b1b0f3c497edf3ba2d25cf52ab78 (no host digest); OFL 1.1; Regular and Bold.
  Measured: OTF-CFF, 65,535 glyphs, ASCII 500 / kana 1000 (1:2), hhea 1160/-288 vs typo 880/-120, no NF, Powerline absent, U+2500-259F (160/160) and arrows, geometric, `... * x` all 2 cells wide. This PC has the variable build installed
  (`/usr/share/fonts/google-noto-sans-mono-cjk-vf-fonts/NotoSansMonoCJK-VF.ttc`; `fc-match monospace:lang=ja` returns the proportional Noto Sans CJK JP).

## B.4 Ligatures and the terminal itself (foot 1.27.0 is installed here)

- foot cannot draw ligatures at all: its CHANGELOG (https://codeberg.org/dnkl/foot/raw/branch/master/CHANGELOG.md, section 1.8.0 on grapheme shaping) says foot shapes single graphemes, not text runs, "That means e.g. ligatures are not supported";
  nothing later adds run shaping (checked up to 1.28.0). So `calt` and ligature builds only matter in other programs; "texture healing" in Moralerspace is `calt` and will not run.
- `font=` takes a comma-separated fontconfig list (so a Japanese fallback is possible: `font=JetBrainsMono Nerd Font:size=14, Noto Sans Mono CJK JP:size=14`) and per-font OpenType toggles such as `Iosevka:fontfeatures=cv01=1` (man foot.ini, 1.27.0).
- `box-drawings-uses-font-glyphs` defaults to no, so foot draws U+2500-259F, U+2800-28FF, U+1CD00-1CDE5 and U+1FB00-1FB9B itself, whatever the font does (man foot.ini); the wide box glyphs of Moralerspace, Noto Sans Mono CJK, Fusion Pixel and Galmuri then do not matter in foot,
  but matter in any other program using the face.
- Fontconfig: spacing is derived from post.isFixedPitch; the 3:5 builds (HackGen35, UDEV 35, PlemolJP35, Moralerspace default) and nearly all pixel faces (Fusion, Tekuplus, JF Dot, Galmuri, k8x12, Misaki, MaruMinya) set isFixedPitch 0; today's Sumi faces show `spacing=90`.

## B.5 Source-stated recommended sizes

None of the coding fonts' own pages states a recommended pixel size; only Maple Mono's README shows previews at 16 px with line height 1.8. Hinting is stated by HackGen ("hinting added to the Latin part") and in the files' ttfautohint strings above.

---

# Eligible, on paper (no decision)

Rules applied: (1) UI: pixel look, Japanese complete (kana + JIS L1 + L2), no spacing problem = 0 touching pairs, every kana/kanji gutter >= 1 px, digits identical, monospaced 1:2 (or tabular digits + kerning), no ASCII quirks that break code;
(2) terminal: vector or hinted coding face, Nerd Font glyphs, Japanese kana + JIS L1/L2, half:full exactly 1:2; (3) smaller than today (UI 16 px, terminal 20 px, cell 10x20); (4) licence explicitly allows redistribution and bundling.

## UI

Pass or near-pass:
- U5 Fusion Pixel 12 px (mono ja and proportional ja), also 10 px mono: OFL, zero touching pairs, every kana and L1+L2 kanji has >= 1 px gutter, full coverage, 12 px lattice phase 0 (exact), BDF/PCF official; box/arrows are 2 cells in mono, no bold, no 14 px.
- U3 Tekuplus 12 px Regular: M+ licence, 1:2, clean Latin except `}`, 11 kanji with zero gutter; Bold has T and symbols touching; y phase 0.6 px (use 1-bit rendering or the Bit file).
- U15 Galmuri Mono 11 (12 px): OFL, 0 touching everything, 1:2, caps 10 px and a 16 px line at 12 px (tall); provenance caveat on kana/kanji/Latin-1 (the author says they are not purely his; he claims no rights in the design); Mono 9 touches.
- U9 JF Dot K12 (12 px, public domain): zero touching in Latin (except `~`, drawn as an overline), kana and kanji; ASCII `\` is a yen sign and `~` an overline (JIS X 0201); outline phase 0.31 px (embedded bitmap exists). K14 (14 px) has 52 touching pairs (T); Shinonome 12 has 15 to 23 % zero-gutter kanji.
- U8 k8x12 (8x12 portrait): free licence, 0 touching, complete, but half-width glyphs are 3 px wide.
- U10 Unifont JP 18.0.01: passes everything except size (16 px = today); the only face with Arabic and with 1-cell box/arrows; useful as the fill-in again.

Fails: U1 DotGothic16 (16 px = today's size, Latin off the pixel lattice, hhea line 23 px); U2 PixelMplus (T/Q/W/m/w pairs touch; 12 px outline phase 0.6; superseded by Tekuplus); U4 Zpix (licence: personal and education only, no modification or redistribution); U6 Ark Pixel (kanji incomplete,
author recommends Fusion Pixel; 16 px removed); U7 Misaki (8 px; Latin-1 15/96); U8 k12x8 (JIS L1 only); U11 Cubic 11 (proportional, 13 px kanji); U12 BestTen (BOOTH-only download, registration said to be required; redistribution of the file not stated; 10x10); U13 hicc fonts (MaruMinya kana touch 19-22 %, DenkiChip 640 kanji,
HeadUpDaisy no kanji, MaruMonica proportional and touching, original licences custom); U14 Mona (proportional, unmaintained since 2005); U16 Cozette (no kanji); U17 Silver (budget clause, unverifiable coverage); the 14 px size has only JF Dot Shinonome 14 / K14 and Galmuri14 (15 px, proportional).

Render first: Fusion Pixel 12 mono ja, Fusion Pixel 12 proportional ja, Tekuplus Regular, Galmuri Mono 11 (then JF Dot K12 and Fusion 10 px as size variants, Unifont JP as the fill-in).

## Terminal

Pass on paper (JP complete, NF full, 1:2 exact, OFL): T2 Firple 6.400; T3 PlemolJP Console NF 3.1.0; T5 UDEV Gothic NF 2.2.0; T4 HackGen Console NF 2.10.0 (stale, 22 months); T6 Moralerspace HW 2.0.0 (box drawing 2 cells wide and 56 of 160 missing; irrelevant in foot);
T7 Maple Mono NF CN 7.9 (a "CN" build by name, so shared kanji presumably take the Chinese regional forms; the README only says Japanese is covered; glyph shapes not compared; no half-width katakana; unhinted) or NF JP 8.0-beta.3 (pre-release, Japanese forms); T11 Cica (old NF, odd metrics, stale since 2022; the only one with Arabic); T12 Firge / T13 Bizin Gothic (older, tight 1.0 em line for Bizin).
Needs a fallback or fails: T1 Fira Code NF and T8 JetBrains Mono NF (no Japanese; fall back to Noto Sans Mono CJK JP, already installed, 1:2); T9 Iosevka Term (no Japanese, no NF); T10 Sarasa Fixed J (no NF); T14 M PLUS 1 Code (L2 2266/3390, no NF);
T15 Source Han Code JP (2:3, no NF); T16 Noto Sans Mono CJK JP (no NF, box and symbols 2 cells).
The 3:5 builds (35, default Moralerspace) are not 1:2 and flag isFixedPitch 0.

Render first: Firple 6.400 (Fira Code letters, 13 px = 8 x 16 cell exactly), UDEV Gothic NF 2.2.0 (JetBrains Mono letters, 12/14/16 px give integer advances 6/7/8, line 16.26 at 14 px), PlemolJP Console NF 3.1.0 (IBM Plex Mono letters, newest), and a control: JetBrains Mono NF (or Fira Code NF) + Noto Sans Mono CJK JP fallback; Maple Mono NF CN as a fifth if a rounded face is wanted.

---

# Downloads and hashes (all in `~/.cache/r27-fonts/<folder>/`; sha256 of the file as downloaded)

```
d8dcbab4bab763caaa6f21d170e416bf7181bbc72f2ea40e66cb3c1f8b29ad6b  ark-pixel-10px-mono-ttf/ark-pixel-font-10px-monospaced-ttf-v2026.10.25.zip
7d8df0c3f10c60ae89fd80acc26d1d19eba837e372c2f56998f62601a8dd961f  ark-pixel-12px-mono-ttf/ark-pixel-font-12px-monospaced-ttf-v2026.10.25.zip
027982bfbd535d411f03f7bf603545493516eb51a98b49616053e926b9211215  bizin-gothic-nf-0.0.4/BizinGothicNF_v0.0.4.zip
cbd1bcf1f3fd1ddbffe444369c76e42529add8538b25aeb75ab682d398b0506f  cica-5.0.3/Cica_v5.0.3.zip
2d54a586f824f32d9d2dd01ec3b990c2a4d6445efa77e20177efe382ebe51627  cozette-1.30.0/CozetteVector.ttf
0193f5f033612496df6b45ee92ac3b335bc6a5a24ff95da55ca87b33e57dcf62  cubic11/Cubic_11.ttf
2b6e5938e5cffa0b9e183bd05f8c363e174e7ebed1a0556e2855fd1707fa2188  cubic11/OFL.txt
155da8f318553c11d9dffc2affbc7c2114c6a46f9740bcf639ed5568af92be71  dotgothic16/DotGothic16-Regular.ttf
b6630c61ea078cacd7fabe37d14ffe557a0b45b06683374a9aa9e24262993e33  dotgothic16/OFL.txt
0949915ba8eb24d89fd93d10a7ff623f42830d7c5ffc3ecbf960e4ecad3e3e79  firacode-6.2/Fira_Code_v6.2.zip
54cd76378fbc5025f42d441d95ca6ec1d3ecc4270e6107558840fed7c04cfe4f  firge-nerd-0.3.0/FirgeNerd_v0.3.0.zip
2723183407cc5aa17f9cf4f99968cf72313cabc9137ac45e5133c1640efee4da  firple-6.400/Firple.zip
ead98bfc27c34f3d387fa90d00bc12b151ebd2c22f41d7b690f401d098c4524a  firple-slim-6.400/FirpleSlim.zip
a07498c4b7107c62eb02a7288671f521f6c5c640885edb558b4da43ee06a0d03  fusion-pixel-10px-mono-ttf/fusion-pixel-font-10px-monospaced-ttf-v2026.10.25.zip
a5ac3e97e5e1f382ed912e868ea83cdbd40ca8a200d6ecd66e13015341f4259a  fusion-pixel-12px-mono-ttf/fusion-pixel-font-12px-monospaced-ttf-v2026.10.25.zip
3d9b1b1a603919efe393ac17cbbb2ec7e33d5da619da23495998b48a1a7e6d90  fusion-pixel-12px-prop-ttf/fusion-pixel-font-12px-proportional-ttf-v2026.10.25.zip
710efe74f58967009d67b7fcd89bec2f13541c1259c41aa9194e9324aa84a7b9  fusion-pixel-8px-mono-ttf/fusion-pixel-font-8px-monospaced-ttf-v2026.10.25.zip
c8b3d9861a62ae73c8b1178091401cd79994812437ef386413f6dd54856e60e7  galmuri/Galmuri-v2.40.4.zip
f8abd483d5edfad88a78ed511978f43c83b43c48e364aa29ebe4a68217474428  hackgen-nf-2.10.0/HackGen_NF_v2.10.0.zip
92114200d1ebc1c21a157168158bc69a3bac8a6580af7c2e551f362fc4b81f65  hicc-00ff-original/x10y12pxDonguriDuel.ttf
4236035940d5f46eae22fac213ff48819a86e10558d553c9e6b55ae4965e2ce1  hicc-00ff-original/x12y12pxMaruMinyaM.ttf
b6923561bf3ba41c60a6d4b945c22c6e0b1e2bec77dd9272ee890cdf1d40d421  hicc-00ff-original/x12y12pxMaruMinya.ttf
a67196e2f0243c71169ff5334f0c03c39dc2de0631ef8adfc52a8ed1a8842a4b  hicc-00ff-original/x12y16pxLineLinker.ttf
b9c7be0421167cba3791b5966c3bf8666d3e6972e7283fb82b6dc0667607ddd4  hicc-00ff-original/x12y16pxMaruMonica.ttf
d84e7e5b244e10f80382af19626092f77d18ab5b4aa92431d243b0142486ba4d  hicc-00ff-original/x12y16pxSolidLinker.ttf
ec5034984ab951497a26efb69addf473171e9a00003926313a95f0da52ea7d03  hicc-00ff-original/x12y20pxScanLine.ttf
190af4e826fe85c47b75d5d9838ff39f69ebfefabd64a931ffad4feca1e92021  hicc-00ff-original/x14y20pxScoreDozer.ttf
c0b8c7ee9367a43d8184a65629a8bd867f68671af72678a5350f2eaed6e103b3  hicc-00ff-original/x14y24pxHeadUpDaisy.ttf
dc905aaec416696aed207d1a7769e93301d3dd4496c936e8f743300f8085b632  hicc-00ff-original/x16y32pxGridGazer.ttf
a2960f48398aaba9fb10f33aec60ddbb4e4244c813a5fd1cf13916abe7349850  hicc-00ff-original/x8y12pxTheStrongGamer.ttf
c9acd8373b8fae7e63e2f56baa2482979e7d9b1e568ba00d338b7b29c9e8d9c5  hicc-denkichip-ofl/x8y12pxDenkiChip.zip
b05f108a3433602545f1dcb8acef167aaf744965d8d9571045d5f2cdbe12f9e5  hicc-marumina-ofl-repo/x12y12pxMaruMinya.ttf
7cb55f7f2e9c9585669c4e58de6caab92648fdf03abfefafff93cfd01094f6cc  hicc-marumina-ofl-repo/OFL.txt
3bd57a66a7f1e429a131d3bc35f4d0f3a8eb722f2fe8f59f595e424bda9a33c9  iosevka-term-34.9.1/PkgTTF-IosevkaTerm-34.9.1.zip
6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf  jetbrainsmono-2.304/JetBrainsMono-2.304.zip
8e574faaaa7e27294aec66464aaf427447b2f0ccec8fe00c50e69bbf509f14b1  jfdotfont/jfdotfont-20150527.zip
7c3c707c70c97473c9b95196bfbf395346cca58752518ed3422cefc89785f6ef  k12x8/k12x8_ttf_2021-05-05.zip
8d006e3171f4823ff1e81eaa285447129239071fc31ebafb8128696d0c1f1d17  k8x12/k8x12_ttf_2021-05-05.zip
8248d6260660be1066b5ebe90d25131582df8383f38db1c284dd1f2dc9d2b46e  maple-v7.9-nf/MapleMono-NF-unhinted.zip
ab88522932cf4015dffeaef6dedc59a22a5fefecdcc6e583d9fcd997da5b7cac  maple-v7.9-nf-cn/MapleMono-NF-CN-unhinted.zip
8ad6bd1af3f5cd86250495e2d31bf0b3a5336781b00c2b8f7aa96f5f85e59720  maple-v8.0-beta3-nf-jp/MapleMono-NF-JP-unhinted.zip
c1851af85a0a010dd84f40803159c2d8a23feecb6c7e800cfeb5c6edc50da46e  misaki/misaki_ttf_2021-05-05.zip
56175ee16373ba1a3d2fd5ec46f3b0b6bf0412be7db1481ec7dee757f2e3d557  moralerspace-2.0.0/Moralerspace_v2.0.0.zip
500a7774297c829265ebd472b6d8c1159cfb3e9daa4ca0570170af541b991b7d  moralerspace-hw-2.0.0/MoralerspaceHW_v2.0.0.zip
ff68678c5bd7e9d9d6ab6d57e4355aabe30f6b8f8bff9bd59baf6a7807dcfd36  mplus1code-gf/MPLUS1Code%5Bwght%5D.ttf
04971e3fcee60b247395150d93b3616f6a0b092572332c96187b472976553abc  mplus1code-gf/OFL.txt
68e3bd6164864b8b514605bc34e3a87ac401c8c48682fcce6478c70263340207  nerdfonts-firacode-3.5.1/FiraCode.tar.xz
04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf  nerdfonts-jetbrainsmono-3.5.1/JetBrainsMono.tar.xz
6c8faf475ce78fa37486dd5d8920e4bb4450b1b0f3c497edf3ba2d25cf52ab78  noto-sans-mono-cjk-jp-2.004/11_NotoSansMonoCJKjp.zip
907e9f5ac24cba6ce2523cd2a66d6ba143e082c685344dfa8d30ef12f67410a0  pixelmplus/LICENSE_E
3875ea416eff4a8ef1647fb6eb33ec908b32ce1e65451590029d2ade3f568ffe  pixelmplus/PixelMplus10-Bold.ttf
01b5e4aea5a3bbe80463c178e7868d5a34cd75e8ed7bc4d97097ebb1a71af7c7  pixelmplus/PixelMplus10-Regular.ttf
7276753dc80861e2f45257b7b1a54c967c160065f5d40e10fb48aabd5648a2a6  pixelmplus/PixelMplus12-Bold.ttf
02f19467ea7cc235cc06c570b7f6c3b0a12a6f682bc8d74c43f2d323d97bcd12  pixelmplus/PixelMplus12-Regular.ttf
015142b7ce4fb497ea6eb14567c435b69450eb5028fb7d29c032d1ffb3854abb  plemoljp-nf-3.1.0/PlemolJP_NF_v3.1.0.zip
f43204cda9beb60b06871000b9b813929a6942ec64a7299cc3dde8693e86a4fd  sarasa-fixed-j-1.0.43/SarasaFixedJ-TTF-1.0.43.7z
f430938b1056e79ff60cf422876e3bbbd348f578d38ff643074e2d6992cd95f5  source-han-code-jp-2.012R/SourceHanCodeJP.ttc
14d3e5f9dfcb351a3a01967c9a2a17e6165479b14e564fe938160ffa4caccee6  tekuplus/Tekuplus-20241212.zip
45faeef7b5d8bc591bcc5887a2ca0c5fb9028066f18a5a52cd6f10b7d655ba37  udev-gothic-nf-2.2.0/UDEVGothic_NF_v2.2.0.zip
b411e78488d861f6b41fba514381123abb01ba7adeac8d0df8801a61891a14d3  unifont-jp-18.0.01/unifont_jp-18.0.01.otf
a67917d94bb597acbdf3bfe1cf97047cc3e1cdd3839d21da188e35cc0737e828  zpix/zpix.ttf
```

Not downloaded: BestTen (BOOTH-only), Silver (itch.io), Mona (nothing to measure), Firple/Maple non-NF builds, Iosevka Fixed, Sarasa Term, the plain PlemolJP/HackGen/Moralerspace JPDOC zips.

---

# Decision (main agent, 2026-10-27 04:45) — T07

Rendered in the real surfaces (tools/kit.sh + tools/font-try.sh: the bar, notices, foot with the
prompt; both themes) beside today's faces: `.claude/notes/fonts-r27/ui-candidates-dark.png`,
`term-candidates-dark.png` (1:1 crops; full sheets under /dev/shm/r27/fonts/try/ while they last).

**UI — JF Dot Shinonome 14, the regular weight, repaired** (public domain, jfdotfont-20150527.zip,
sha256 8e574faa…; 14 px, 7 px cells, 1:2, JIS L1 + L2 complete).
- "A little smaller than today": the only clean candidate between 12 and 16 px. At 1:1 the 12 px
  faces (Fusion Pixel 12 mono/proportional, Tekuplus 12, Galmuri Mono 11 — all spotless on paper)
  read at about half of today's text in the bar and the notices, and a size below the terminal's
  16 px: "a lot smaller", and the UI would look weaker than the terminal beside it.
- The spacing faults are measured and repairable, not designed in: 52 Latin pairs touch (all the
  `T` bar) → the repo's own air-column pass (tools/build-fonts.py, as it repaired Shinonome 16 B's
  2376 pairs to 0); 4 L1 kanji with no gutter → one column taken off each. Target: 0 touching
  pairs, every kana/kanji gutter ≥ 1 px (the research's measure, re-run on the built face).
- What made today's face ugly is gone: the bold (heavy, smeared at 16 px), 45 % of L1 kanji
  touching their neighbours (today's build) → 4 before repair, 0 after; and its size.
- The JIS-roman signs (\ ~ and the quotes) redrawn the Western way, as today (art/signs.txt, on the
  7 × 14 grid); what Shinonome 14 lacks (box drawing, arrows, the UI's one-cell signs, Arabic)
  drawn or taken onto the 14 px grid in T10 — Unifont JP 18 (16 px) can no longer fill in as is.
- Fallback if the owner rejects the look: Fusion Pixel 12 proportional ja (OFL, zero faults) —
  the whole grid then at 12 px.

**Terminal — UDEV Gothic NF 2.2.0 (the NF build, no ligatures), 16 px, cell 8 × 19**
(OFL; JetBrains Mono letters + BIZ UDGothic Japanese, 1:2 exact, Nerd Fonts full set, ttfautohint).
- Integer advance at 16 px (8.00): a crisp 8-px cell; line 18.58 → 19 (foot line-height=19px).
  Today 10 × 24 → 8 × 19: about 25 % more columns and rows ("more on screen"), still the
  comfortable size for long work at 1080p (JetBrains Mono's tall x-height).
- Ligatures off (the NF build has none): `==`, `->` stay what they are — he is learning to code.
- Firple (Fira Code letters, the face he named) was rendered too: its only whole-pixel cell is
  13 px (8 × 16) — too small for long work; at 16 px it rounds to a 10 × 20 cell, today's size.
  PlemolJP Console NF reads well but has no whole-pixel cell (7.92 at 15 px).
- T11 confirms it with yazi, nvim, btop, lazygit and the prompt in both themes, and sets hinting.
