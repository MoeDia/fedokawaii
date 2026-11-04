# art/ink — where the two paintings come from (tools/build-ink.py, tools/ink_heads.py)

The owner's two masters (4 Nov 19:26, 21:40): M1, an engraved Hannya mask; M2, Schongauer's angel over Hokusai's waves. The sources stay
out of the repo, in `~/.cache/r27-ink/` (`src/`, `cand/`, `fonts/`), as the fonts do: the checked-in pictures are what ships. Personal use only.

## Public-domain plates (Wikimedia Commons, CC0 scans)

- `src/hannya-noh.jpg`: Noh Mask, "Hannya" type, 能面 般若.jpg. https://commons.wikimedia.org/wiki/File:Noh_Mask,_%22Hannya%22_type,_%E8%83%BD%E9%9D%A2_%E8%88%AC%E8%8B%A5.jpg (Public domain). sha256 `c0ebadb277c36a670726c64acb193aa3a38f35bc54436bd7b5da43913570640a`
- `src/schongauer-gabriel.jpg`: Martin Schongauer, The Archangel Gabriel, c. 1490-1491, NGA 3240.jpg. https://commons.wikimedia.org/wiki/File:Martin_Schongauer,_The_Archangel_Gabriel,_c._1490-1491,_NGA_3240.jpg (CC0). sha256 `d449da5f0b4f46c4dd22216af6e4c29f8bafe3b1c035e737d10b0dc0bd52e469`
- `src/hokusai-wave.jpg`: The Great Wave off Kanagawa.jpg. https://commons.wikimedia.org/wiki/File:The_Great_Wave_off_Kanagawa.jpg (Public domain). sha256 `a8d851a6c049ef310e3c13ace55fff5233b87631270e63f8c03b4143d1d8aee8`
- `src/durer-four-angels.jpg`: Albrecht Dürer, The Four Angels Holding the Winds, 1498, NGA 142354.jpg. https://commons.wikimedia.org/wiki/File:Albrecht_D%C3%BCrer,_The_Four_Angels_Holding_the_Winds,_1498,_NGA_142354.jpg (CC0). sha256 `4ef393c1bca49c4f65f9db750d3cb3c14147c0b921bb3d6da0fe4c822ceba54a`

## Settings, generated on this PC and recut

The hall and the angel's sky and sea are first drawings made here, then cut in one hand by tools/build-ink.py (the plate's own lines in one ink, our paper and washes):
stable-diffusion.cpp master-1047-984eb06 (MIT, Vulkan, the release zip), FLUX.2-klein-4B Q8 GGUF (leejet, Apache-2.0), Qwen3-4B Q4_K_M (unsloth, Apache-2.0), the flux2 VAE (Comfy-Org, Apache-2.0). No figure of the masters comes from them.

- `cand/wd-1003.png`: the dark hall, seed 1003, 1920 × 1088. sha256 `603e375bb5f15b870d174443c83851fa3edea0c7b06f133094ea8d785f63b4cd`
- `cand/bl-1103.png`: the angel's pillars, clouds and waves, seed 1103, 1920 × 1088. sha256 `ca53e9812aecc54baf4b85e97644fbffd6052770dd10fca80a1b23d53295e9de`

## The quotes' hand

- `fonts/yujiboku/YujiBoku-Regular.ttf`: Yuji Boku (google/fonts, ofl/yujiboku, SIL OFL 1.1). Only its letters of the two quotes reach the pictures. sha256 `94fda16384f3bdac24376a000c57e99abfa314961bd89ef27badfb7410322003`

## Rebuilding

`python3 tools/build-ink.py dark|light|lock` writes `configs/home/.local/share/fedokawaii/MOOD/lock-*`; `python3 tools/ink_heads.py` the heads. Needs Pillow, numpy and scipy, and the sources above.
