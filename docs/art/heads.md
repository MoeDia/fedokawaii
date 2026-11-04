# The two heads: one character, cut at every size

The mood's head is the desktop's face: the engraved Hannya by night, the engraved Renaissance angel by day, the
owner's two masters of 4 Nov (M1, M2; "for the demon I want THIS, for the angel THIS"), the same two figures as the
lock's. No pixel art (19:12); `tools/ink_heads.py` cuts each size at that size, because a line right at 300 px is
wrong at 22: never a downscale.

![The demon at every size: teeth locked, roaring](heads-oni.png)

![The angel at every size: eyes closed, open](heads-angel.png)

Each sheet, left to right: the prompt's glyphs, the bar's coins, the menus' 48 and 56 px, fetch's portrait; 1× above, 4× below.

| size | file | how |
|---|---|---|
| fetch, 288 × 300 (36 cells × 15 lines) | `.local/share/fedokawaii/MOOD/head.six` | demon: the lock's figure from `tools/build-ink.py`, cut anew at this size; angel: Schongauer's Gabriel, his own lines, the ai wash, the gold ring. Whole pixels, 24 inks |
| menus, 56 and 48 px | `themes/MOOD/head-56*.png`, `head-48*.png` | demon: the mask's own lacquer under lines cut by hand; angel: her face, locks, wreath and halo cut by hand after the print |
| the bar, 22 × 20 | `themes/MOOD/face*.png` | a coin, drawn in its own whole shapes, its ink on rows 1–18 |
| the prompt, 24 × 20 | `art/icons.txt` @head-* (the table in the tool) | a woodcut, one ink: the only size with no shading |

States: at rest the demon's teeth are locked and the angel's eyes are closed; open (its panel open, a command failed), the
demon roars, its throat the one shu, and the angel looks.

Inks: the demon is sumi on the paper the torch lights, plus that one shu; the angel is the print's sumi, its paper, the ai of its
wash and a gold ring. Sources and licences: public-domain plates, listed with the lock's in `art/ink/SOURCES.md`.
