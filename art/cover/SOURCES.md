# The Learn book's cover: what it is made of

`tools/build-cover.py` makes `docs/learn/cover.jpg` and `cover-thumb.png`. Everything below is out of copyright or free to use.

| Part | Work | File, where from | Licence |
|---|---|---|---|
| the demon | lane-ink's M1: an engraver's cut of a Hannya Noh mask (Tokyo National Museum C-1555; Deme Yoshimitsu, Ueda collection) | `demon-m1.png` (here); the masks: commons.wikimedia.org/wiki/File:Hannya_(Noh_mask),_Tokyo_National_Museum_C-1555.jpg | CC0 |
| the angel | Martin Schongauer, *The Archangel Gabriel*, c. 1490–91, National Gallery of Art 3240 | `schongauer-gabriel.jpg`, sha256 d449da5f0b4f46c4dd22216af6e4c29f8bafe3b1c035e737d10b0dc0bd52e469, commons.wikimedia.org/wiki/File:Martin_Schongauer,_The_Archangel_Gabriel,_c._1490-1491,_NGA_3240.jpg | CC0 |
| the sea | Katsushika Hokusai, *The Great Wave off Kanagawa*, c. 1831 | `hokusai-wave.jpg`, lane-ink's `~/.cache/r27-ink/src/record.json` has its URL and sha256 | public domain |
| the title | EB Garamond (Georg Duffner, Octavio Pardo), SIL OFL | github.com/google/fonts: `ofl/ebgaramond/EBGaramond[wght].ttf`, `EBGaramond-Italic[wght].ttf` | OFL 1.1 |
| the hanko's 学 | Shippori Mincho Bold (FONTDASH), SIL OFL | github.com/google/fonts: `ofl/shipporimincho/ShipporiMincho-Bold.ttf` | OFL 1.1 |

The sources and faces are read from `~/.cache/r27-ink/src` and `~/.cache/r27-learning-cover/fonts` at build time and do not ship: the picture does.
