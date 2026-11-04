# lane-saver: task 38, the screensaver redone (owner 17:01; 19:11: from the same full-res painting, no pixels)

Branch lane-saver, worktree ~/repos/fk-saver. Scratch tools and the stand-in art: ~/.cache/r27-saver/ (/dev/shm/saver is gone after a reboot).

## State (22:02, after the reboot; the engine done, the last art lands with lane-ink)
The 20:32 art direction is built: not an empty wall but THE SAME FIGURE ASLEEP.
- The painting the saver shows = lock-scene.png itself + one patch (saver-lids.png, `patch` word): so every pixel outside the sleeper is the lock's, by construction. Dark: the mask's jaw shut, its gold eye plates painted as closed lids IN THE SOURCE PHOTOGRAPH'S TONES (tools/build-saver.py eyes_shut) and re-cut by lane-ink's own engraver (bi.dark_frame(L, 0, a)): same hand, same face. Light: her lines with both eyes shut (one fine arc + three lashes), her head bowed 8.5° on the neck (a smooth warp fading into the curls: bowed()), the halo down to a trace, no rays, scroll rolled and sealed (bi.light_frame(L, 0, a_ink=...)). Her wings are already folded in Schongauer's plate.
- world.h: the `rest` pool: the sleeper's own dim light, breathing at 86 steps (a little over 7 s); `spot` words: the seal at the thirds of the frame, clear of the figure, in turn across the frame, a little aside each minute (23-minute Vogel spiral). Seal 168 × 228 (2.7×, the art director's "about 3×", 3× looked like a placard), deep red, struck hot and cooling for 12 steps; digits cut out with 26 % of the painting showing through (a full cut was unreadable over the busy wall and waves: seal_cut ink at 74 %).
- Shade ink of the dark is now the painting's own warm black (0b0a09; the old `lo` turned the mask olive). The fires' reach 560 (was 700): the wall falls into black sooner, the seal stays readable.
- The flames: the lock's own strip (lock-flame.png, `frame`/`flame` words), each fire its own pace. No strips of the saver's own, the lock's light-l/r and eye strips are not used (the shade does their work; 10 MB each in memory).
- Tests: tools/regress/saver-keys.sh HELD now (21:52, load 30: the old failure was the broken machine), saver-lock.sh, saver-dark.sh held on stand-in art. tools/saver-review.sh: the wake's sheet and recording from render.c's frames (notes 3b).

## What main must do to merge and apply
Merge lane-saver AFTER lane-ink (its art is what tools/build-saver.py patches). If lane-ink's lock art changes after my last build, tests/look/test_saver.sh says so (the `lock` hash): run `python3 tools/build-saver.py` on the merged tree (needs ~/.cache/r27-ink/src, about 2 min), commit its saver-lids.png, saver-seal.png, saver-scene.txt. Then apply as usual: theme.sh builds kawa-saver (libpng-devel comes with cairo-devel) and installs the art. dwl needs no change. Ledger lines for main: see the end of this file.

## Open questions
none for the owner yet.

---

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

## OWNER VERDICT 2026-11-04 20:32 on your render saver-dark.png: comment
[Claude, art direction while the owner is away; his verdicts win] Two problems. (1) The removed figure left a blurred smear in the centre of both scenes (dark: a soft dark hole; light: a huge beige blur): it reads as a damaged picture. (2) The owner chose lane-ink's M1 (engraved Hannya mask) and M2 (Schongauer-style angel over Hokusai waves) as the masters at 19:25, not SD902/LA2, so the saver must follow those. Better idea than an empty wall: the SAME figure ASLEEP — the Hannya mask dimmed with its eyes closed (dark), the angel with her head bowed and wings folded (light) — so the saver is the lock's world at rest and the lock wakes it. Keep the torches breathing, embers and petals. The time seal: larger (about 3x), placed at a third of the frame, not floating mid-blur. Wait for lane-ink's finished M1/M2 locks (git fetch origin/lane-ink) and build on them.

## OWNER VERDICT 2026-11-04 20:32 on your render saver-light.png: comment
[Claude, art direction while the owner is away; his verdicts win] Same notes as saver-dark: no blurred hole; the angel (M2) asleep instead of removed; a bigger time seal at a third of the frame.

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.
