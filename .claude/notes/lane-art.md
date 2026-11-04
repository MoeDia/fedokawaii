
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-art".

# lane-art: state

The owner's 19:11 and 19:12 notes changed this lane's work: **lane-art now keeps only the wallpapers.** Lane-ink paints the whole lock and every demon and angel icon. (The OWNER blocks in this file were written by others. The lane acted on each only once `plan.md` or `feedback.md` on main carried it: 18:32, 18:45, 19:11.)

## Lasting: the wallpapers (art direction §4)
- 11 dark and 10 light pictures in `art/masters/out`, from `art/masters/masters.toml` and `tools/build-masters.py`. The owner's verdict is "love" on every 1× page he has marked so far; he has not marked the rest. The 4× pages he called duplicates are gone from the pack.
- No cartouche, seal or poem card left, triptych seams healed, crops moved so no face is cut. Three inks: a ramp from the mood's ink to its paper, the seal's red, and gold in the light set (new tokens in `tools/wada-palette.py`).
- A calm top for his floating bar: the first 14 rows one ink, fading in over the next 24. `--check` and `tests/static/test_masters.sh` hold it.
- The Willow Kannon replaces the Goddess on a Dragon. `wallpapers.list` is updated; `kawa-wallpaper --pack` (run by theme.sh) copies the changed pictures by hash and drops the one no longer listed.
- Review pages: `python3 tools/art-pack.py .claude/review/next` (wallpapers only now).

## Superseded: standing in until lane-ink lands, then replaced
- **The heads**: `art/heads.txt`, `tools/build-heads.py`, `tests/static/test_heads.sh`, `docs/art/heads.md`. A samurai demon and Marishiten, drawn before the 18:32 and 19:12 notes. They drive `face.png`, `face-open.png`, the prompt's glyphs (renamed `head-kannon` to `head-angel`, `ICON_HEAD_ANGEL` in the shell) and `head.six`.
- **The lock**: `tools/build-lock.py` and its `lock-*` files, pixel art. Main's module already plays them (gate, anims, sparks). The saver was rebuilt from them with `tools/build-saver.py`.
- Lane-ink has said its `tools/build-lock.py` replaces this one when the lanes merge.

## For lane-integrate: merging
- `git merge lane-art`. To take only what lasts, take: `art/masters/`, `tools/build-masters.py`, `tools/wada-palette.py`, `configs/home/.local/share/fedokawaii/wallpapers.list`, `tools/art-pack.py`, and the Art paragraph of `docs/design-system.md` §13.
- Worth keeping for lane-ink's ~300 px fetch portrait: the sixel path in `bin/fetch`, `*.six` in `theme.sh`'s byte-for-byte case, `sixel()` in `tools/build-heads.py`.
- After a merge: `python3 tools/build-masters.py` is not needed (its output is committed), the usual `fedokawaii apply` installs it all. Nothing here has been applied to the live PC.

## Handed to lane-ink
`tools/build-lock.py`: `deep()` (carved relief), `oni_fig`, `angel_fig`, `battle_left`, `battle_right`, `flicker_strip()` with `FLICKER` (the light-strip method), `smoke()`, `seigaiha()`, `raimon()`, `rope()`. Told by message on 4 Nov, with the two traps: anims draw above the figure, sparks are one scene pixel.

## How it was checked
- `tests/static/test_masters.sh`, `test_heads.sh`, `test_syntax.sh`, `test_design_doc.sh`, `tests/look/test_wallpaper.sh`, `test_lock.sh`, `test_saver.sh`, `tests/engine/test_greeter.sh`, `tests/content/test_fetch.sh`.
- Headless, nothing on his screen: `tools/regress/lock-gate.sh` held on this art in both moods before the last lock changes; fetch's sixel was checked once in a real foot in the kit.
- Not checked: the moving light in the real lock. The 0.7 % of a core is a cairo-only bench, and the installed module predates anims, so the regress run did not exercise them.

- On this branch after merging main at b2de0d0 or later (load average 40 to 89 from the other lanes), all passing but one: `test_masters` 3, `test_heads` 4, `test_syntax` 814, `test_design_doc` 54, `test_tools` 24, `test_generated` 276, `test_contrast` 21, `test_fetch` 105, `test_shell` 187, `test_bar` 265, `test_panel` 650, `test_lock` 181, `test_greeter` 50, `test_saver` 83.
- **Failing: one case of `tests/look/test_wallpaper.sh`** (272 passed, 1 failed): "15 restores at once ... one swaybg is left". This lane changed neither `bin/kawa-wallpaper` nor that test, the file passed 273/0 earlier at lower load, and under load the same run also failed a 3 s timing case once. It looks load-related, but that is not proven: re-run it on a quiet machine.
- The full suite (`tests/run.sh`) was not run, only the files above.

## OWNER 18:03 / 18:07
His words: SUPER DETAILED design work, focus on the pixels, smart usage of space, do things complex. Read the LIVE ~/repos/fedokawaii/.claude/review/feedback.md for his verdicts and Claude's notes: the heads are a samurai red-lacquer menpo oni and Marishiten (goddess of light) in two inks, hand-pixelled at 16/21/32/128. The bar stays FULLY FLOATING, no background band.

## OWNER 18:32
The demon and the angel FIGURES (heads at every size, fetch, the lock's central figures) move to lane-ink: detailed engraved ink illustrations, not pixel art. You keep the lock backgrounds (walls, carved friezes, clouds, lamps, rope) and the wallpapers; leave space for lane-ink's figure and agree the composition through your notes. Deepen the dark friezes' relief shading so they read as carved stone.

## OWNER 18:45 — THE LOCK SCREEN EVEN MORE INTENSE
On top of 18:37: push the drama. Low camera angles, the figure towering and breaking past the frame's edges, hard chiaroscuro (light from the torches carving faces out of black), the torches really flickering and throwing moving light and shadow on stone and carvings, embers rising, smoke drifting, the demon's eyes glowing faintly, the angel's halo turning slowly with petals falling, density of detail everywhere, nothing calm or empty. Still one painting between lane-ink's figures and lane-art's settings. Animate within the lock's frame budget (light, embers, smoke, eyes, halo, petals), and keep it cheap on the GPU.

## OWNER VERDICT 2026-11-04 19:06 on your render 72-wall-yoshino-tennin.png: love


## OWNER VERDICT 2026-11-04 19:06 on your render 73-wall-yoshino-tennin-4x.png: change
no need remove it we already have the same one yea

## OWNER VERDICT 2026-11-04 19:06 on your render 74-wall-feather-robe-tennin.png: love


## OWNER VERDICT 2026-11-04 19:06 on your render 77-wall-raigo-1668-4x.png: change
remove duplicate

## OWNER VERDICT 2026-11-04 19:06 on your render 76-wall-raigo-1668.png: love


## OWNER VERDICT 2026-11-04 19:07 on your render 75-wall-feather-robe-tennin-4x.png: change
looks like duplocate

## OWNER VERDICT 2026-11-04 19:07 on your render 80-wall-dragon-palace-jewel.png: love


## OWNER VERDICT 2026-11-04 19:07 on your render 78-wall-lotus-sutra-gateway.png: love


## OWNER VERDICT 2026-11-04 19:07 on your render 82-wall-willow-kannon.png: love


## OWNER VERDICT 2026-11-04 19:07 on your render 63-wallpapers-light.png: love


## OWNER VERDICT 2026-11-04 19:07 on your render 66-wall-white-kannon-kyosai.png: love


## OWNER 19:11 — THE LOCK: DROP THE PIXEL ART COMPLETELY
His words: "still not serious enough. DROP this whole pixelated act. Focus on the images I showed you, the torch idea, the style, the open and closed mouth, and the wall carvings. Super serious, super detailed, ancient, proper."
- The lock and its twin the greeter become a full-resolution 1920x1080 PAINTING, not pixel art, never upscaled pixels. Style = his two references: engraved ink / irezumi, fine hatching and cross-hatching, sculpted shading, aged paper, Renaissance depth with Japanese line.
- DARK: a Hannya at the centre, facing him, in engraved ink (horns, scrollwork on brow and cheeks, wild hair, staring eyes). Mouth states painted from the SAME face (inpaint only the mouth, so the identity never shifts): closed → open after the secret key → the bite on Enter (it eats the password) → in.
- LIGHT: a Renaissance winged angel in Japanese tattoo ink among Hokusai waves and sakura, indigo wash. Her states: scroll closed → unrolled after the secret key, each typed character a brush mark → rolled and sealed with a hanko on Enter → in.
- WALLS: ancient carved stone reliefs of demons and angels at war, in the same engraved technique, weathered and cracked, deep relief that reads at 1x.
- TORCHES: kept and painted, giving real light on stone, carvings and face; live in the lock: flame flicker, light that moves with it, rising embers, all as light layers over the painting.
- Serious and ancient: nothing cute, flat or empty; detail everywhere.
- Ownership: lane-ink paints the WHOLE lock artwork for both moods (figures, walls, carvings, torches, light layers) from public-domain masters and local generation as in its task, cleaned by hand into one style. lane-art stops lock work, hands over anything useful through its notes, and keeps the wallpapers. Main: the lock engine and the greeter show full-res painted layers (smooth scaling, never pixel scaling), the state images, and the animated light layers within the frame budget. lane-saver builds the saver from the same painting.
- Candidates on his page (.claude/review/next/) before finishing: both moods, every state.

## NOT DONE: a second look at the wallpapers (4 Nov, from 19:56), repairs in progress
The lock and the icons are lane-ink's by the owner's 19:11 and 19:12 notes. The wallpapers were called finished at 4c86af4, but a look at screen size found real defects:
- Raijin, Fujin: a flat ink slab with a straight, mask-like edge (the god centred past the painting's edge). Now inside the painting, as Kōrin laid them out; false gold-leaf accents at the edges cleaned.
- Oiwa: the chin cut by the crop. Close-up kept, shifted down. (Widening past the print looked worse: its margins and a dark rectangle of sky.)
- Fudō: a tonal seam at x 462 (the third sheet), the print's margin along the bottom row, the god's face a dark blob. New ops `even`, `dodge`; crop moved up.
- Yoshino: a pale rectangle with straight edges where the title was. New op `marks` takes only the ink of the characters.
- Seigen: Danjūrō's crest on the arm reads as a smudge (`fields`). Hag, Benten, Noh, Cleveland, feather robe, Willow: specks, a stray stroke, the fan's smudge. Willow's `fade` edge now uneven (`wander`), not a straight line.

**State at this commit:** `tools/build-masters.py` and `art/masters/masters.toml` are changed; `art/masters/out` and the hashes in `wallpapers.list` are NOT rebuilt yet, so the committed pictures are still 4c86af4's and the tests still hold. Safe to merge, but nothing visible has changed yet.

**Next, after the reboot (main's message, 4 Nov ~20:10: forced reboot ~20:25, no builds before it):**
1. Build each changed picture to scratch and look at it at 3×. Raijin, Oiwa, Fujin and Fudō were seen once (20:15) and their specs changed after it without a rebuild, so see them again; check: Fujin no pale strip at the left edge and bottom-left; Oiwa no pale-orange flecks (`chroma = 0.1`) and the eye's red kept; Fudō no line at x 1380 on screen (`even` is now two-sided), his eyes and face readable, no noise from `dodge`; Raijin clean corners. Seigen, hag, Benten, Cleveland, Hagoromo (the fan's outline intact after its `fields`), Yoshino (the cloud contour unbroken after `marks`), feather robe, Willow (the uneven fade): not seen yet. Scratch tools are copied to `~/.cache/r27-art-scratch/` (`variant.py NAME TAG 'toml overrides' --x3`, writes to /dev/shm/lane-art/var, make that folder first).
2. `nice -n 10 python3 tools/build-masters.py NAME…` for those that pass; put their new sha256 in `wallpapers.list`.
3. `tests/static/test_masters.sh`, `test_syntax.sh`, `test_design_doc.sh`, `tests/look/test_wallpaper.sh`; `python3 tools/art-pack.py .claude/review/next` for the changed pages.
4. Update this file, commit, push, tell lane-integrate (a small follow-up merge), end this file with a bare DONE line.
