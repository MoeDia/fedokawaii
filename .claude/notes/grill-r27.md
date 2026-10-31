# grill-r27 — the side-by-side audit (T17)

Every surface shot headless on the real GPU in both themes (`bash tools/gallery.sh --bin bin
--repo-art`: 27 surfaces — the bar, the launcher and a sum in it, quick settings, sound,
brightness, do-not-disturb, calendar, timer, drives, downloads, power, Super+/, the level
display, a notice and a critical one, Super+U, the clipboard, Super+W, books, the file
picker, the calculator, git, the terminal, yazi, btop, notes), dark | light sheets, grilled
against docs/design-system.md.

## Measured
- Geometry: every surface the same box in dark and light, 27 of 27 (a theme is inks, never
  geometry) — kept as `tools/regress/gallery-expect.json`; `tools/gallery.sh --check` holds a
  later build to it (the calendar's height and the power menu's width follow the month and the
  uptime: their place only).
- Dropdowns hang from y 33 (the bar's 27 rows and its air), the right-hand ones end at x 1913
  (hairline 1911, shadow 1912) — quick settings, sound, brightness, do-not-disturb, drives,
  downloads, notices alike; the calendar and the timer centred under the clock.
- The headless regress set (bar-geometry, window-frame, level-display, warm-exit, calendar-middle,
  menu-first-click, one-popup) holds on the repository's state.

## Found and fixed
1. Super+/ typed into a field with a bare "> " before it; the launcher's field has none: the
   same bare field now (a prompt only where it carries words of its own — a size, an order, a
   passphrase's lock).
2. The file picker (yazi) still listed Enter and Esc on its last line and stood its heading's
   name a column further than every heading: its own keys only, name on column 3.
3. Super+U's status showed a setting's name — "not set up (BACKUP_TARGET)" — and so did the
   backup pane and the drive picker: "no drive · quick settings → backup", "your home, to the
   drive you chose", "it is remembered".
4. The kit shot the light theme on the dark root: a light surface's dark hairline vanished and
   the sheets misled — each theme's own ground now (swaybg), shots.py reads the ground from
   each shot. nvim had no plugins in the kit (the notes in nvim's default colours): its data
   linked, read only (checked: nothing written).
5. The calendar's middle half a pixel off the clock's: not a placement error but parity — the
   clock's scroll is odd (its kanji's 13 px of ink with equal sides), the calendar even (seven
   40 px days, six 8 px gaps); no layout makes both exact without a 1 px asymmetry elsewhere.
   The check now holds them within half a pixel (a real misplacement is a pixel or more).

## Seen, owned by later tasks (not left undone: each is in its task's approach)
- Notes: "~" end-of-buffer marks down the margin, the day's heading in markdown's green, the
  old footer grammar (path · saved as you go · super+n) → T21 (the lined notebook).
- Yazi's own view: a bare path for a heading, its status line → T22 (the whole UI rebuilt).
- The terminal's prompt → T24.
- Quick settings as a menu he loves, a monitor-off key → T17b (owner, 14:27).
- The lock, the greeter and the saver are not headless-shot here (gtklock and greetd need their
  own stage) → T20 shoots and grills them; the window ghosts and washes → T19.
- In the kit the brightness meter is empty (no DDC/CI monitor there); live it reads 40 %.

Nothing left for T17.

## T19k-3 — quick settings, the third time (30 Oct 02:31): three directions sketched
`.claude/notes/design-r27/quick-t19k3.py` → `quick-A-mon.png`, `quick-B-ema.png`, `quick-C-list.png`
(dark | light, Sumi UI 14 + Sumi Icons, the Wada palette, the cursor on "night light, off"; the
pictures are today's 14 px tile icons — T19k-4 draws them anew). Today's panel, grilled first:
twelve identical boxes in 1 px frames (the "plain rectangles" he dislikes), a 28 px seal per box,
two lines of words — eight of twelve tiles off, so the panel reads mostly dead grey; nothing of
the world in it (no art, no ornament, no motion but the stamp); the cursor's fill flush with the
meter's last segment on the right while the icon has 8 px of air on the left.
- **A, the mon sheet (家紋)** — no boxes: each item a crest 36 px across on a sheet of four columns
  (94 px), its name and state centred under it; on: the vermilion seal, a paper ring, the picture
  knocked out; off: the crest's outline (edge2), the picture muted. Calm, balanced, unmistakably
  Japanese (a page of family crests); each crest can be its own drawing — the "every item its own
  character, all centred to the pixel" he asked for. Against it: still a grid of toggles at heart;
  off states in faint (2.4–2.6 : 1) read dead.
- **B, the ema wall (絵馬)** — wooden votive plaques hung on rods. The most world, but twelve
  gables, strings and rods are clutter for a panel opened twenty times a day, the plaques are boxes
  again, and it is the tallest (≈ 520 px). Rejected; its rod with gold caps (the bar's scroll rod,
  KAMI) is worth keeping as the sheet's one ornament.
- **C, the list** — Super+U's grammar (a row each, a 20 px crest in the icon column, the state
  right-aligned). The cleanest alignment, but a settings page, not "a proper, beautiful menu":
  every item left-aligned in one column loses the "unique, centred" he asked for.
**Chosen: A**, refined before it is built: (1) the crests drawn anew at 28 × 28 inside a 36 px seal
(T19k-4, one drawing each — no 14 px icon scaled); (2) every name `text`, the state `muted` when
off (never faint: "off" is a state, not an absence), `strong` when on — the seal says on/off;
(3) the four keys at the foot (wallpaper, screenshot, screen off, power) on the same four columns,
as small crests — one grid for the whole panel; (4) the demon/angel head (T19k-4) at the top
in place of the plain heading icon, on the rod; (5) the cursor the lacquer cell (94 × 88, the
whole column's item), its words and crest outline cream — measured symmetric (equal air left and
right of the crest and of the longest name); (6) motion: the seal's stamp when turned on (§11),
and a crest that moves while its thing runs (record's dot, backup's arrows, the network's pulse).
Next pass: build A in kawa-panel (Layout for the sheet, crests at 36), render both themes, px.py
every gap, grill again.
**Built (30 Oct 11:30, branch r27-wip-t19k3, not on main yet):** steps (a)–(c) — the sheet of
94 × 88 cells (four columns, nothing framed, crest 36 at 6 px, name row at 46, state row at 66,
words 86 px wide so "KINGSTON 58G" stays whole), names `text`, off states `muted`; test_panel
503/0 on the branch; renders both themes (kit play, the repo's bin): at rest, cursor on an off
crest. **The grid question** (test_design_doc §3 fails: 94 × 88 is off the 8 px column / 20 px row
grid): rendered against the on-grid variant A2 (88-wide cells 8 apart, 80 tall, the crest in a
two-row band: `quick-A2-grid.png`, side by side `quick-A-built-vs-A2-grid.png`). A2's cursor cell
crowds the crest (2 px under its top edge, 5 below the state: top-heavy) and narrows the words;
the built one has balanced air (6 above the crest, 7 under the state's capitals). **Decision:
94 × 88 stays** — the sheet spans the content exactly (its outer edges on the grid), every crest
is centred on its own column, so nothing in it lines up with a text column anyway; §3 gets the
mon sheet as the grid's one stated exception and test_design_doc reads MON_W × MON_H. Then merge.
**Measured (30 Oct 11:36, the kit's shots, both themes identical):** the cursor cell 94 × 88; the
crest 36 px, x 29–64 in its cell — air 29 | 29, exact; 6 px above it, 7 under the state's ink;
crest → the name's ink 9 px, name → state 8. A word of odd ink width cannot split an even cell
(freesync, 55 px: 19 | 20) — the extra pixel goes right, the same everywhere; T19k-4's pictures and
any word can be checked against that rule.
**(d) the foot (31 Oct 11:06):** two renders on the four columns, both themes (kit, the repo's bin):
A — small crests (a 24 px outline ring round each icon, the word under: 56 px cells); B — the icon
over its word, no ring (46 px). A reads as a fourth row of switches, all off (the outline crest *is*
"off" on this sheet) — "power: off"; it also costs 10 px more. B reads as what they are, actions:
the same columns, one grid for the panel, nothing framed. **Chosen: B.** Grill of B: icons muted
at rest like every row's (an action is no state: never vermilion); the group's 16 px keeps the
foot apart from the sheet without a rule; the icon → word air (10–11 px to the ascenders) a pixel
or two above the crest → name 9 — kept: the 12 px icon is lighter than a 36 px seal and needs the
room; 7 above the icon's ink, 7 under the baseline (the crest cell's 6/7).
**T19k-4 first drawings (31 Oct 11:14) — the mood's face, multi-ink, 18 × 18** (`heads-t19k4.py`,
`heads-t19k4.png`: each at 1× on its own end tile and 8×). The 1-bit 16 × 16 oni/tennin were
"far too simple"; the tile's paper is 20 px high, so the gain is in inks, not size: sumi, ivory,
gold, lacquer on the tile's red. **Dark — the hannya** (after Hokusai's Warai Hannya, AIC 1943.605,
art/masters/SOURCES.md): gold horns from the temples, black hair parted on the brow, angry brows
falling to the nose, slanted gold eyes with the pupil at the inner corner, flared nostrils, a grin
ear to ear in lacquer with four ivory fangs, an ivory chin. Roar (quick settings open): the mouth a
row deeper, the eyes all gold (no pupil: they glow). **Light — the tennin**: a gold nimbus behind,
the hair in a bun with a gold pin, long hair to the shoulders, the urna (lacquer) on the brow,
eyes closed in single lines, small lacquer lips; open: gold irises between black lids, the lips a
smile. Grilled out on the way: draft 1's flat rectangle eyes and second "mouth" under the lip
(hannya); the tennin's brow + eye dashes reading as "≡" and nose + lips as two mouths.
Still to do (next pass): build them from tools/build-art.py (both themes' inks from build-themes),
waybar's end tile as a background picture (the module's class for open), quick settings' heading
the same face at 2×; shot on the real bar (kit bar), measured: its air in the tile, 1 px each side.
**T19k-4 (b) the heading's face — first render (31 Oct 11:22, kit play, a temp copy of kawa-panel;
`quick-head-t19k4b.png`: left the name at 24, right at 32; dark above, light below):** the face's
open frame on a 20 × 20 vermilion seal in place of the sliders icon. At 24 the name crowds the
seal (~4 px of air: reads as one blob); at 32 the name stands on the same column as the meters'
names under it ("brightness", "sound") and the seal reads as the panel's hanko — **leaning: 32**
(a stated exception to §4's heading name at cell 3, quick settings alone). Open question for the
build: the seal on the content's edge (x 0–19, as rendered) or centred on the icon column over the
meters' icons (x 6–25: the face right above the bulb and the speaker, 6 px of air to the name) —
render both, px.py, decide. The seal must stay: on the dark ground the hannya's black hair vanishes.
