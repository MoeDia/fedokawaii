# The programming font (r28, f21): UDEV Gothic NF v2.2.0 stays, at 16 px, cell 8 x 20

Executive choice, by render trials in real foot (headless kit, both moods, the same code,
Japanese and Nerd glyph sample): `r28-font-sheet.png`, 1:1, dark left, light right.

| face, release checked 6 Nov (gh release list) | px | cell measured | x-height | Japanese | Nerd glyphs | 4 faces |
|---|---|---|---|---|---|---|
| **UDEV Gothic NF v2.2.0** (JetBrains Mono's letters, BIZ UDGothic) | 16 | 8 x 20 | 8.7 | in the file | in the file, drawn large | 25.2 MB |
| Iosevka Term NF (Nerd Fonts 3.5.1; Iosevka v34.9.1 is the latest) | 16 | 8 x 20 | 8.3 | second font | shrunk to one cell | 58.8 MB + a second font |
| JetBrains Mono NF (v2.304, NF 3.5.1) | 13.33 / 15 | 8 / 9 x 20 | 7.3 / 8.2 | second font | one cell | 10.3 MB + a second font |
| Maple Mono NF JP (v8.0-beta.3, a pre-release) | 13.33 / 15 | 8 / 9 x 20 | 7.3 / 8.2 | in the file | in the file | 27.0 MB |
| Commit Mono NF (v1.143, NF 3.5.1) | 13.33 / 15 | 8 / 9 x 20 | 7.2 / 8.1 | second font | one cell | 9.7 MB + a second font |
| Monaspace Neon NF (Monaspice, NF 3.5.1; Monaspace v1.400 is the latest) | 13.33 / 15 | 8 / 9 x 20 | 6.8 / 7.7 | second font | one cell | 11.1 MB + a second font |

Why:
- **The grid decides first.** Every screen is drawn on the 8 x 20 cell (design system §2, §3).
  The 0.6 em faces only fit it at 13.33 px, too small to read well (x-height 7 px against 8.7).
  At 15 px they are lovely but 9 px wide: 213 columns on his monitor instead of 240, against
  "density on one monitor", and every TUI's measured layout would have to move.
- **One file, no fallback.** Japanese two cells wide and every Nerd glyph in one face; a second
  font for Japanese is what his zero-fallbacks rule forbids. Only UDEV and Maple have that;
  Maple's JP build exists only as a pre-release, and a pin should not be a beta.
- **Iosevka Term was the real rival**: the same cell, sharp, more character in its braces. It
  loses on a smaller x-height, its icons (a folder or a warning sign shrunk into one cell
  in the Mono build, plainly smaller on the sheet than UDEV's) and on needing a second font. Sarasa Fixed J
  (Iosevka with Japanese in one file) has no Nerd glyphs and is 25.7 MB a face (fonts-r27.md).
- **Readable**: 0 O o, i l 1 | I, r n m, `'"`, ;: and ,. stay apart at 1:1 in both moods.
- No ligatures, as before: `==` and `->` stay what they are.

Not tried: Iosevka's and the others' non-Mono Nerd builds (larger icons); the Japanese and the
grid would still decide. Commit Mono and Monaspace were tried as Nerd Fonts' patched builds, not
their own files. RAM was not measured: the sizes above are file sizes.
So f22 pins nothing new: v2.2.0 is already pinned in lib/upstream.sh, and the latest release.
