VERDICT: FAIL

# T18 — the old masters as pixel art: review 1 (the master, 2026-11-03)

## What I checked, and how

Everything ran outside his session (env -u WAYLAND_DISPLAY -u DISPLAY, a dead D-Bus address, my own
XDG_RUNTIME_DIR under /dev/shm/r27/master/T18/own/), read-only on the repo, ~/.cache, ~/.local.

1. **Licences and sources — all 21 verified on their own records, all clean.**
   - sha256: the 21 files in ~/.cache/r27-art match masters.toml and SOURCES.md (21/21); every crop
     is 16:9 (ratios 1.7773–1.7789) and inside its file.
   - The Met (7): objects 72828, 44849 (WebFetch) and 55743, 57282, 54608, 44602, 45281 (the API):
     `isPublicDomain: true`, titles/dates/artists as SOURCES.md and the credits say.
   - Art Institute of Chicago (10): 47411, 47398, 47403, 100477, 88304, 196866, 33415, 154623, 154676,
     81256 through api.artic.edu with the documented `AIC-User-Agent` header (WebFetch gets 403 without
     it, as SOURCES.md warns): `is_public_domain: true`, `info.license_links` → CC0 1.0, accession
     numbers as listed.
   - Cleveland 1951.540: `share_license_status: CC0`. Commons: the Takiyasha, Raijin and Fūjin file pages
     carry PD-Art + PD-old-100-expired + CC-PD-Mark; the 3840 px Kōrin renditions exist as stated.
   - Not clean in wording only: the credits for Takiyasha ("British Museum, London, public domain") and the
     two Kōrin screens ("Tokyo National Museum, public domain") attribute the PD status to the museums;
     it rests on Commons' PD-Art reasoning (the BM's own terms are CC BY-NC-SA, as SOURCES.md itself
     says). See SHOULD-FIX 13.
2. **Pipeline honesty and reproducibility — passes.** `python3 -I tools/build-masters.py --help` runs;
   a mirror tree (tools/build-masters.py, tools/wada-palette.py, art/masters/masters.toml under
   own/build/) rebuilt all 21 pictures in 9 s: **21/21 byte-identical** with art/masters/out. No hand
   retouching. Every output is an indexed PNG 640 × 360 whose palette is exactly the mood's RAMP +
   ACCENT from wada-palette.py (dark 14 inks, light 16; used indices ≤ 13 / ≤ 15).
3. **On screen — passes.** bin/kawa-wallpaper cover(): a picture smaller than the screen gets
   `-filter point -resize (3·640)x(3·360)!` (k = the smallest whole number that covers). The live cache's
   21 covers at 1920 × 1080 are exact np.kron 3 × 3 copies of the PNGs (21/21); the live pack's 21 .src
   match the list's hashes; wallpapers.list's 21 `toolkit:` hashes match the PNGs; the dark/light counts
   (117/120) are right. tests/look/test_wallpaper.sh reads a checkerboard back pixel by pixel.
4. **The art.** All 21 at 1× (the committed PNGs — the evidence sheets are stale, see MUST-FIX 4), the two
   crop overviews drawn on the sources (own/crops/overview-{dark,light}.png), 31 crops at 3× by whole
   pixels (own/crops/NAME-x-y.png), and numbers: OKLab L of the outer rows/columns against the band
   inside, dither busyness, stray-accent components. Findings below.

## MUST-FIX

1. **Paper margins, frame lines and mounts are left at the edges of six pictures** — the ledger's "every
   crop measured edge by edge … inset until none is left" is not true of the committed files (OKLab L of
   the outer columns/rows vs the next 20 inward; 1 px here = 3 px on his screen):
   - `asajigahara-hag`: columns 637–639 are paper, L 0.94 against 0.26 inside — a 9 px pale strip down the
     whole right edge (the crop ends at the file's edge, x = 1686). The blank poem card is **not** cropped
     off: a 70 × 194 px remnant (210 × 582 on screen) sits at the top-left with text in it. The two sheet
     joins show as **pale** full-height bars on the black ground: columns 114–121 and 374–378 (24 px and
     15 px on screen).
   - `benten-biwa`: left columns 0–5 at L 0.96 (paper) then the painting's edge line at column 9 (0.45);
     right: a line at 633–634 (0.71–0.75) and paper at 636–639 (0.95). Crop [45, 177, 2166, 1218] must come
     in ~30 px on both sides (a narrower 16:9 window).
   - `goddess-dragon`: a dark frame line at columns 635–638 (L 0.48–0.58 vs 0.71) — 12 px on screen.
   - `feather-robe-tennin`: the crop takes the file's full height (y 0–638): rows 0–2 (L 0.95–0.96) and
     356–359 (0.96) are the print's paper margins, with the border line above the bottom one.
   - `lotus-sutra-gateway`: the painted field ends at row ~328 of the crop; the bottom **26 rows (78 px on
     screen) are blank paper** (L 0.92–0.94); columns 636–639 (0.83 vs 0.75) and row 0 (0.71 vs 0.52) are
     the paper beside and above the field. A 16:9 window of the full field width (3040) cannot fit its
     height (1569): take a narrower window inside the field.
   - `dragon-palace-jewel`: rows 0–3 are the print's dark edge (L 0.26–0.29 vs 0.40–0.47) — 12 px on screen.
   Direction: fix the six crops in masters.toml, then make the measurement part of the build so it cannot
   come back (the owner's "never again" rule): build-masters.py refuses a picture whose outer 1–4 rows or
   columns differ from the next 20 by more than ~0.08 L, or whose outermost column/row is a flat line
   (std < 0.03, step > 0.05) — and tests/static runs it on the committed PNGs.
2. **The light ramp is not sorted by lightness, and quantise() bisects it** (tools/build-masters.py:58 and
   :146 `np.searchsorted(rl, L)`): RAMP["light"] has `faint` (8b917f, L 0.646) before `lo` (96865e,
   L 0.624). Measured on a synthetic gradient through quantise(): L 0.51–0.62 dithers muted↔faint,
   L 0.625–0.64 draws solid `lo` — **darker than the `faint` just below it** — then lo↔edge2 up to 0.80; the
   drawn lightness is non-monotonic (217 drops along one gradient) and `faint` never serves as the upper
   partner above 0.624. So every light picture's midtones carry a 0.02 L inversion with a hue flip (cool
   grey ↔ warm olive): goddess-dragon has 14.9 % faint / 13.8 % lo pixels with 10.9 k adjacent pairs,
   raigo-1668 11.1 / 22.6 %, dragon-palace-jewel 13.3 / 21.3 %, white-kannon-kyosai 8.7 / 14.8 %,
   lotus-sutra-gateway 4.6 / 16.2 %. Fix: order the light ramp by L (swap "faint" and "lo", or sort in code)
   and `assert np.all(np.diff(rl) > 0)`; rebuild the ten light pictures; new hashes in wallpapers.list.
3. **`kawa-wallpaper --pack` never refreshes a picture whose listed hash changed** (bin/kawa-wallpaper,
   pack(): `out="$PACK/$mode/$name.src"; if [[ -s $out ]]; then have=…; continue; fi`). A toolkit
   picture rebuilt under the same name — which fixes 1 and 2 require, and which T18's own three rounds
   already did — stays stale in the pack; cover() then draws the old file under the new key
   (NAME.NEWHASH.center.png) and nothing complains. The live pack is current today (21/21 hashes), which
   means it was refreshed by hand — not through the installer. Fix: for `toolkit:` entries (local, 21 small
   files) compare the existing file's SHA-256 with the list and replace it when it differs; add that case
   to tests/look/test_wallpaper.sh beside the checkerboard.
4. **The acceptance is unguarded and the evidence is stale.** Nothing reads art/masters/out: no test
   checks size, mode P, palette == the mood's inks, indices in range ("px.py confirms …" was never run by
   anything). The cited sheets (/dev/shm/r27/master/T18/t18-dark-2.png) still contain
   `taira-ghosts-crabs` (dropped) and the old asajigahara crop; the in-place shots are timed 17:48:49 and
   17:48:54, before the committed PNGs (mtimes 17:49–17:51) — the dark one shows pale strips at both edges
   of raijin-korin that the committed file does not have. Add a static test for the PNGs; regenerate the
   final sheet (`--sheet`) and both in-place shots from the committed files and cite those.

## SHOULD-FIX

5. **Sheet joins as full-height bars**: takiyasha-skeleton columns 218–221 and 467–470 (black, 12 px each
   on screen), fudo-flames two dark bars (x ≈ 215, 440), taira-ghosts-bay faint joins (x ≈ 230, 484) — the
   museum photographs' gaps between the triptych's sheets. Two black bars across a wallpaper read as a
   double frame. Compose the sheets edge to edge (a per-sheet crop list in masters.toml) or crop inside one
   sheet.
6. **oiwa-lantern's crop cuts the face through the eyes** (rows 320–360 at the bottom edge; the crop is
   y 13–53 % of the print). The ghost's face is the subject: lower the window ~250 source px (y ≈ 24–64 %),
   the lantern's top is the cheaper loss (the bar covers the top 9 rows anyway).
7. **Calm fields.** Busyness (share of pixels whose right or lower neighbour is another ink) is 43–74 % in
   every picture — dragon-palace 74 %, benten 73 %, white-kannon-cleveland 73 % (its blank paper is a Bayer
   mottle of ground/key), raigo 71 %. quantise()'s margin = 0.1 dithers 80 % of every lightness interval;
   crafted pixel art has flat fields and dithers only transitions. Try margin ≈ 0.3 and compare sheets;
   paper and gold grounds should snap to one ink.
8. **Stray accents**: isolated vermilion components of ≤ 3 px — fujin-korin 17 (in its brown left field,
   visible at 3×), raijin-korin 20, takiyasha 22, taira 13. Drop accent components under 4 px (or raise the
   chroma per picture).
9. **white-kannon-kyosai**: the gold accent lands in patches on the face (forehead, cheeks, chin) — a
   jaundiced mask at 3×. Either `chroma = 0.12` for this picture (as raigo) so the face stays in the ramp,
   or the whole gilded face gold — not half.
10. **The weakest, as art** (name them, fix or replace): light — `raigo-1668`, `lotus-sutra-gateway`,
    `dragon-palace-jewel` read as posterised photographs of busy paintings (small figures in a three-grey
    mottle, no drawing survives); `goddess-dragon`'s ground is a mottle. Dark — `taira-ghosts-bay` is murky
    (the Taira ghosts, the demons, are invisible; the seals are vermilion blobs); `yawata-beings`' crop
    (y 4–41 %) drops the ghouls — the demons — entirely (take y 37–79 %); `fujin-korin`'s left half is a brown
    mottle. What works is the flat-colour print and the ink drawing: seigen-skeleton, warai-hannya,
    kohada-koheiji, raijin-korin; hagoromo-noh, yoshino-tennin, white-kannon-cleveland. Replace the three
    light paintings with prints of that kind (Kōgyo's Nōgaku hyakuban celestial roles — `seiobo-noh` is
    already fetched and verified; the "considered" list in SOURCES.md).
11. **Cartouches as flat vermilion pills**: takiyasha's two title cartouches (bottom, x ≈ 195 and 265) and
    taira's seals are the most saturated marks on screen and carry no drawing. Crop them out, or let them
    keep their text (accent_lo fill, the lines kept).
12. **Docstring honesty**, tools/build-masters.py: lines 24–28 still describe the abandoned "nearest
    colour in OKLab (lightness counted twice)" method; lines 13–18 omit `chroma` and `hue`, which
    masters.toml uses and line 170 reads; `--help` gives no text for `--sheet`/`--spec`.
13. **Credits**, configs/home/.local/share/fedokawaii/wallpapers.list: lines 19, 28, 29 — say "via
    Wikimedia Commons (PD-Art)" instead of attributing public domain to the British Museum / Tokyo
    National Museum; lines 21, 149, 150 cut the title inside its quotation mark (`"One Hundred Ghost
    Tales, 1831-32` — unbalanced).
14. **SOURCES.md**: both e-Museum links (www.emuseum.jp, lines 32–33) no longer resolve (DNS); the record is
    at emuseum.nich.go.jp (…content_base_id=100321&content_part_id=001 answers 200). The header's "14
    candidates each" is 15 light now (seiobo-noh).
15. **wallpapers.list header** (lines 3–5): "never enlarged: every one is at least as large as a 1080p
    screen" is no longer true; say what cover() does with the desktop's own pictures.

## NITS

- warai-hannya: the four corners outside the tondo are raw paper; painting outside the circle with the
  mood's `lo` would make it a round window in the dungeon wall — more of the world.
- All masters have pair "-"; a few hand pairs (Hokusai's warai-hannya ↔ Hokusai's benten-biwa) would give
  the ◐ feature something to show — an r27-extra.
- `tools/build-masters.py --sheet` lays tiles on a 60-grey gutter; fine, but the sheet should be made from
  the committed set after every change (see MUST-FIX 4).

## What is good

The pipeline is honest and reproducible to the byte; every licence holds on the museum's own record; the
palette discipline is total; the whole-pixel path from toolkit to screen is proven on the live cache. The
best pieces — seigen-skeleton, warai-hannya, kohada-koheiji, raijin-korin, hagoromo-noh, yoshino-tennin,
white-kannon-cleveland — are genuinely the world the owner asked for.
