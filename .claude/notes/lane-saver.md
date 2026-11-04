# lane-saver: task 38, the screensaver redone (owner 17:01; 19:11: from the same full-res painting, no pixels)

Branch lane-saver, worktree ~/repos/fk-saver. Scratch tools and the stand-in art: ~/.cache/r27-saver/ (/dev/shm/saver is gone after a reboot).

## State at 20:15 (before main's forced reboot)
Built and committed: the engine is complete. NOT DONE yet: see "Next". All numbers below were taken with load average 20-100, and main says results since the 19:15 kernel oops cannot be fully trusted: measure again after the reboot.
- src/kawa-saver/world.h: the world with no screen: shade (1/8 size, breathing round the fires), haze (1/4, smoke, dark only), air (1/2, embers or dust and petals), the seal (a worn stone atlas, digits cut out, a new place in the middle every minute), paint_open (the soft-edged opening).
- src/kawa-saver/kawa-saver.c: Wayland: each of those a subsurface, scaled up by wp_viewporter, the painting the layer surface, opaque region while asleep. The fall (1200 ms) closes over the desktop, the lock starts under it; a key: the seal lifts, the fires leap, the painting opens from the figure's place (440 ms) onto the REAL lock under it, so the saver never holds the figure. Dark screens: no steps, no frames. Screens lit by the key: 1000 ms held for the monitor. All outputs gone: it locks and leaves.
- src/kawa-saver/render.c (make O=DIR render): the same world to P6 files, for tests and renders; never installed. glyphs.h is gone (and saver_glyphs in tools/build-art.py).
- tools/build-saver.py: the bridge from the lock's art to saver-scene.txt. Uses lock-bare.png when it exists; else (today's whole-pixel lock) lane-art's bare scene scaled ×3 as saver-wall.png. Strips: `anim` words except `fig-…`. Re-run after ANY change to the lock's art: tests/look/test_saver.sh fails otherwise (the `lock` hash).
- tools/build-themes.py saver_conf: the ten inks. Themes regenerated.
- theme.sh retires a850edb's saver-scene.ppm and saver-flame.ppm. verify.sh checks the scene. design-system §9 and §11, PACKAGES.md, the guide's line, report SLP-19 updated.
- Tests: tests/look/test_saver.sh 98/0 at 19:42 (before the later small edits). tools/regress/saver-lock.sh held, with the seal checked (19:42). tools/regress/saver-dark.sh held (19:46: 0 ticks in 6 s in the dark). tools/regress/saver-keys.sh NEW: look and other-shape parts pass; see Next 1.
- Measured (tools/saver-review.sh --measure 15, stand-in painting, load about 100): saver 0.47-0.60 % of a core, dwl 1.7-2.3 %, GPU 1.0-1.4 %, 14-16 MB.
- lane-ink (fk-ink-ed) agreed 19:3x to deliver in {dark,light}/: lock-bare.png (1920x1080, identical pixels outside the figure), `fig-` prefix on figure-bound strips, `torch X Y` lines. Masters are its M1 and M2; SD902-torchlit is only the lighting reference.
- Renders on his page: only the stills .claude/review/next/saver-{dark,light}.png (a STAND-IN painting: lane-ink's candidates with the figure roughly removed). NO wake sheet and NO recording there: the last ones were wrong, see Next 3b. The wake itself has been seen working in real kit frames (19:34, the whole-pixel lock under it), and regress saver-lock.sh and saver-dark.sh pass it, but not yet over a painted lock with frames looked at.

## Next (in this order, after the reboot; rebuild the scratch first)
0. mkdir -p /dev/shm/saver/{b,bin}; cp ~/.cache/r27-saver/tools -r /dev/shm/saver/; cp -a ~/.cache/r27-saver/ink-art /dev/shm/saver/; cp src/kawa-saver/* /dev/shm/saver/b/; nice -n 10 make -s -C /dev/shm/saver/b O=/dev/shm/saver/b /dev/shm/saver/b/kawa-saver /dev/shm/saver/b/kawa-saver-render; bash /dev/shm/saver/tools/lockhome.sh. Then export PATH=$HOME/.local/bin:$PATH and LOCK_HOME=/dev/shm/saver/lockhome nice -n 10 bash tools/regress/saver-*.sh --bin /dev/shm/saver/bin. (lockhome2, the stand-in painted lock: copy lockhome, link .local/share/fedokawaii/{dark,light} to ink-art.)
1. saver-keys.sh, the last part FAILS, unexplained: `kawa-saver --idle`, a key 0.5 s in (during the fall): after 12 s gtklock had not locked, kawa-lock was in its fail path ("gtklock did not lock within 10 s") hanging in notify-send, the saver still up asleep. It came after a look and a mode change in the same kit, on the machine main says is broken. Reproduce alone after the reboot; if the saver is at fault, fix it; if notify-send can hang kawa-lock, the saver's 15 s guard must still end it (it did not within my 12 s poll: check).
2. Run the whole tests/look/test_saver.sh, tests/static/test_generated.sh and test_design_doc after the last edits; tests/session/test_dwl_anim.sh's saver lines.
3. When lane-ink's lock-bare.png lands: git fetch, merge its branch, run tools/build-saver.py, look at both moods, tune moods[] in world.h (floor, edge, gamma), REACH in build-saver.py and the `centre` (the figure's place: ask lane-ink for a `centre X Y R` word if the default is off); then re-record: LOCK_HOME=… bash tools/saver-review.sh .claude/review/next --bin /dev/shm/saver/bin. If the lock's strips hold smoke, the saver's own haze should go: not built yet (a `haze off` word).
4. Art left: petals' shape (slightly arrow-like at the tips), dust visibility, the seal's place. r27-extra idea, not built: the demon's eyes faintly opening in the dark of the middle now and then.
3b. tools/saver-review.py's wake sheet is WRONG: it picks the frame where the figure's place changes most, which was the seal's minute stamp; and wf-recorder under load dropped the wake (its encoder lags, about 90 ms a frame). Do not fix the picking: make the wake's sheet and the recording's wake from render.c's frames instead (`kawa-saver-render DIR --steps N --every 1 --wake --under lock-scene.png`: every frame at 144 a second, whatever the load), and keep the kit run as the proof that the real lock shows, its `awake` shot looked at. Look at every sheet before it goes on his page.
5. --measure 300 at a quiet time for the ledger (his acceptance: CPU and GPU over 5 min). dwl's share might fall if the subsurfaces went sync (one commit a step): try it.
6. Ledger lines are main's merge; write r27 lines here for it. The Learn piece's words at the book pass.

## What main must do to merge and apply
Merge lane-saver after lane-art/lane-ink; run python3 tools/build-saver.py on the merged tree if the lock's art differs (test_saver says so); apply. libpng-devel comes with cairo-devel (manifest, already kept). dwl needs no change: its viewporter, subcompositor and the ghost's premultiplied blending are already there. A step's dwl work is measured above.

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
