# Round 28: the final questionnaire

For the owner when he is back; Phase E applies his answers as the last edit of the repo.
Each question says what the run assumed, so no answer means the assumption stands.
New questions go at the end of their topic with the next number; `f16` began this file.
The sheets are in `~/.local/share/r28/img/`, on branch `pulse` under `img/`, captions in `captions.txt`.

## A. The options pack (plan line o01)
Nothing here is applied to this PC; a build lands in the tree and the ISO, the other options one switch away.

- A1. Window open and close (`a1-window.jpg`): the hop, seal, shoji or kasumi?
  assumed: shoji, 190/150 ms. Whole pixels and a part of the world; seal reads as a plain fade, kasumi as noise over text.
- A2. The workspace move (`b1-workspace.jpg`): the strip, hayate, kakejiku or fusuma?
  assumed: hayate, 220 ms. The move made most often gets the fastest motion, and sideways keeps the rooms' order readable.
- A3. Menus, panels and warm windows coming and going (`c1-scroll.jpg`): the rod, kakejiku, omori or makimono?
  assumed: kakejiku, 380/280 ms. It is the real hanging scroll you asked for, rods and silk edges.
- A4. The prompt (`d1-prompt.jpg`): tanzaku, obi or rakkan?
  assumed: rakkan. The carved seal says most with least.
- A5. The dark lock (`e1-lock.jpg`): hengaku, mon or hashira?
  assumed: 3, hashira, the letters cut straight into the battle reliefs.
- A6. The light lock (`e2-lock.jpg`): hengaku, mon or hashira? Need the two moods match?
  assumed: 1, hengaku, the stone beam; the moods need not match, they are two moods.
- A7. The bar (`f1-bar.jpg`): jiku, makimono or jikusaki?
  assumed: jikusaki, the boldest, though it costs 11 rows of height (windows from y 44, today y 33).
- A8. The power menu (`g1-power.jpg`): jiku, tanzaku or umebachi?
  assumed: jiku, the row you know, one family with the scroll and the bar.
- A9. Super+U (`h1-menus.jpg`): ichimai or daifuku?
  assumed: ichimai, 707 by 280.
- A10. Super+R (`h2-menus.jpg`): hon or okuzuke?
  assumed: hon, 707 by 360, as wide as Super+U's ichimai.
- A11. Helium's theme (`i1-helium.jpg`): tsuitate, mokuroku or noren?
  assumed: tsuitate. It follows the mood switch live, 2 keys each side; noren would have to be swapped.
- A11b. Helium's square address bar, its hairlines and square tab and hover cards (sa20e): Helium draws these itself (no preference, no GTK CSS reaches them); only a Helium built from source would, a Chromium build for every release (hours on this PC) and no more self-updating. Want it anyway?
  assumed: no; closed as a known limit (S27), the theme's colours and the rest of tsuitate stay.

## B. Known flaws in the sheets
Mock-ups, to be fixed in whichever option is built; say if any of them is worse than it looks.

- B1. The dark lock, options 1 and 2: mane strands still cross 禍.
  assumed: fixed if either is picked; the assumed option 3 does not have them.
- B2. The light lock: the wall gained stonework only, the pillars themselves are no richer yet.
  assumed: the build enriches the pillars too (plan line sa31).
- B3. The bar, makimono: the light rolls read slate.
  assumed: a colour slip, they would be paper.
- B4. The bar: Latin at 16 px has none of Sumi UI's repairs, and "." and ":" were kerned by hand.
  assumed: the build repairs 16 px the way Sumi UI repairs its own size.
- B5. Helium, noren: the blue ring is a slip; the ring and the "new tab" card on the third tab in all three are from the shot.
  assumed: neither is part of the design.

## C. The first login on a new install
- C1. The first report waits for the first login with no time limit, however late it comes. Right?
  assumed: yes (f06h).
- C2. The first report runs as `--quick`: no theme flip, no FreeSync round, no menu opening by itself in front of the first login, and nothing timed. The full checks stay `fedokawaii verify`'s and the report's own full run. Right?
  assumed: yes (f06j).

## D. Before the install (plan lines o02 to o06)
- D1. The RAM is still at 5600 MT/s and wrong bits were measured (ledger r27-note-flips-2). Will you set DDR5-4800 and run ram-check before installing anything built here?
  assumed: yes, before the ISO; the run touches nothing on this PC.
- D2. triad, your private repo fluvia4ai/triad: may a read-only deploy key be added, its public key posted for you?
  assumed: yes, with your OK when you are back; until then it is not in the tree.

- **d1, the Fedora logo altered (bloody, lighty).** Fedora's trademark terms for a changed mark were not read in this pass. Assumed: it is your own desktop, on your own PC, as you asked. If the ISO is ever published, read Fedora's logo rules first (since d1c it also carries the mark on the boot splash and the installer's crest).

- c1b: with the PC dark, is the cooler's display fully dark now, no 99 blinking? assumed: yes (it gets the blank once a second since 6 Nov 18:3x; nothing here can see it).

sa09: pytest is not in the manifest; tests-pytest uses 'uvx pytest -q' (works from uv's cache here). assumed: uvx is fine; if he wants pytest installed, it is a manifest row.
