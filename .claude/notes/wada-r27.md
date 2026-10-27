# The Wada palette — groundwork for T08 (2026-10-27)

Source: Sanzo Wada, *A Dictionary of Color Combinations* (1933–34), as data:
github.com/mattdesl/dictionary-of-colour-combinations — `colors.json` (159 colours, 348
combinations; name, swatch group, CMYK, Lab, RGB, hex), fetched 2026-10-27, sha256 555f11c32eb81330….
Measured with ΔE2000 (tools: /tmp script, kept below as output).

## Where today's palette already sits in Wada's world
Our tokens are near Wada colours already (dark: ground ≈ Black ΔE 2.3, accent ≈ Red Orange 4.5,
blue ≈ Olympic Blue 3.5, purple ≈ Light Mauve 4.0, green ≈ Rainette Green 4.7; light: accent ≈
Brick Red 5.4, ground ≈ Sulpher Yellow 6.4). The farthest: edge2 (Vandyke Brown 10.9) and the light
asagi (Dusky Green 10.8) — the greys and the teal are ours, not Wada's.

## Combinations that carry the two moods (candidates)
- dark / demon / the dungeon: **#328** Brick Red #a84222 · Apricot Orange #f68c50 · Vandyke Brown
  #4b3317 · Light Porcelain Green #00908a — earth, a torch's flame, the red, and a teal that can take
  asagi's role; **#340** Peach Red #f15a30 · Sea Green #00b49b · Neutral Gray #b6bfc1 · Black #111314
  (today's system almost exactly: vermilion, teal, grey on ink); **#298** Raw Sienna · Lemon Yellow ·
  Peach Red · Black (fire).
- light / angel / gold leaf on paper: **#325** Eugenia Red B #da525d · Naples Yellow #fbe6a0 · Yellow
  Ocher #e2b540 · Deep Slate Green #112f2c — a soft red, paper, gold and a deep green ink; **#303**
  Naples Yellow · Peach Red · Deep Slate Olive · Neutral Gray.
- the prompt's pastels (T24) come from Wada's light, low-chroma swatches (to pick by contrast with
  ink text: ≥ 4.5 : 1).

## The measurement
```
== dark: our token → nearest Wada (ΔE2000)
  ground   #0f0e0c → Black                        #111314  ΔE   2.3
  surface  #161411 → Black                        #111314  ΔE   3.1
  edge2    #3d372f → Vandyke Brown                #4b3317  ΔE  10.9
  faint    #5f584c → Deep Grayish Olive           #635a3a  ΔE   7.7
  muted    #877f6f → Light Grayish Olive          #848061  ΔE   6.5
  text     #cfc3a6 → Ecru                         #c2ae93  ΔE   6.5
  strong   #ece3cc → Sulpher Yellow               #f5ecc2  ΔE   6.0
  accent   #d0583a → Red Orange                   #dd4027  ΔE   4.5
  asagi    #7fb8b0 → Venice Green                 #62c6bf  ΔE   6.1
  green    #8e9a5b → Rainette Green               #8fa071  ΔE   4.7
  yellow   #d29f45 → Sulphine Yellow              #c19f2c  ΔE   6.7
  blue     #5f7fa0 → Olympic Blue                 #5a82b3  ΔE   3.5
  purple   #9079a9 → Light Mauve                  #9a72aa  ΔE   4.0
== light: our token → nearest Wada (ΔE2000)
  ground   #e9e1cb → Sulpher Yellow               #f5ecc2  ΔE   6.4
  surface  #dcd2b8 → Ivory Buff                   #ebd3a2  ΔE   7.2
  edge2    #b1a688 → Ecru                         #c2ae93  ΔE   5.5
  faint    #9b927e → Warm Gray                    #a1a39a  ΔE   8.1
  muted    #5f594d → Deep Grayish Olive           #635a3a  ΔE   7.6
  text     #2b2721 → Black                        #111314  ΔE   8.3
  accent   #c0462a → Brick Red                    #a84222  ΔE   5.4
  asagi    #2f6e67 → Dusky Green                  #004f46  ΔE  10.8
== darkest 12 Wada colours (L*)
  L   5.7  #111314  Black
  L   6.1  #051230  Deep Indigo
  L   8.6  #1e0e3f  Dull Violet Black
  L  17.2  #112f2c  Deep Slate Green
  L  18.4  #501345  Cotinga Purple
  L  18.8  #253122  Deep Slate Olive
  L  20.1  #4e1d4c  Dusky Madder Violet
  L  20.9  #12354e  Dark Tyrian Blue
  L  23.4  #4b3317  Vandyke Brown
  L  25.2  #59256a  Red Violet
  L  27.1  #7d133a  Pansy Purple
  L  27.7  #653514  Mars Brown Tobacco
== lightest 10
  L 100.0  #ffffff  White
  L  94.3  #ffefae  Pale Lemon Yellow
  L  93.8  #fff200  Yellow
  L  93.1  #f5ecc2  Sulpher Yellow
  L  92.1  #f8ed43  Lemon Yellow
  L  91.5  #fbe6a0  Naples Yellow
  L  88.4  #ffdd00  Apricot Yellow
  L  87.9  #bce4e5  Nile Blue
  L  87.8  #fdd4bd  Seashell Pink
  L  85.4  #ebd3a2  Ivory Buff
== vermilions (hue 15–45°, chroma > 45, L 40–65): Eugenia Red | A #e2625e, Eugenia Red | B #da525d, Jasper Red #eb5324, Spectrum Red #e31f26, Red Orange #dd4027, Etruscan Red #c55347, Scarlet #cb2f43, Carmine #cc1236, Hydrangea Red #a94151, Brick Red #a84222, Peach Red #f15a30
== combinations with a vermilion and a near-black (L < 25):
  #117: Carmine #cc1236 · Black #111314
  #155: Jasper Red #eb5324 · Benzol Green #00978d · Deep Indigo #051230
  #216: Jasper Red #eb5324 · Green #489b6e · Black #111314
  #232: Carmine #cc1236 · Pinkish Cinnamon #eeb480 · Deep Indigo #051230
  #298: Raw Sienna #bb7125 · Lemon Yellow #f8ed43 · Peach Red #f15a30 · Black #111314
  #303: Naples Yellow #fbe6a0 · Peach Red #f15a30 · Deep Slate Olive #253122 · Neutral Gray #b6bfc1
  #307: Carmine #cc1236 · Grayish Lavender - A #b5b1d8 · Aconite Violet #a36aa5 · Cotinga Purple #501345
  #313: Carmine #cc1236 · Yellow #fff200 · Diamine Green #1a7444 · Black #111314
  #325: Eugenia Red | B #da525d · Naples Yellow #fbe6a0 · Yellow Ocher #e2b540 · Deep Slate Green #112f2c
  #328: Brick Red #a84222 · Apricot Orange #f68c50 · Vandyke Brown #4b3317 · Light Porcelain Green #00908a
  #332: Coral Red #f58e84 · Scarlet #cb2f43 · Deep Slate Olive #253122 · Dusky Green #004f46
  #340: Peach Red #f15a30 · Sea Green #00b49b · Neutral Gray #b6bfc1 · Black #111314
```

## Today's contrast (WCAG 2.x ratio, 2026-10-27) — T08's bar: text ≥ 4.5, muted ≥ 3
dark — on ground: faint 2.7 · muted 4.9 · text 11.0 · strong 15.1 · accent_text 4.8 · asagi 8.6;
on surface: faint 2.6 · muted 4.6 · text 10.5 · strong 14.4 · accent_text 4.6 · asagi 8.2;
on key: faint 2.4 · muted 4.3 · text 9.7 · strong 13.3 · **accent_text 4.3 (fails)** · asagi 7.6;
text_on_accent on accent 4.7.
light — on ground: faint 2.4 · muted 5.3 · text 11.4 · strong 14.8 · accent_text 5.3 · asagi 4.5;
on surface: faint 2.1 · muted 4.6 · text 9.9 · strong 12.8 · accent_text 4.6 · asagi 3.9;
on key: faint 2.5 · muted 5.7 · text 12.1 · strong 15.8 · accent_text 5.7 · asagi 4.8;
text_on_accent on accent 4.7. (faint is meant dim — "not there yet" — but 2.1 on paper surface
is the lowest: judge it in renders, not by the number alone.)
