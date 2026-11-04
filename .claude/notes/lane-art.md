
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-art".

(The paragraph above was already in this file when the lane first read it; the lane did not write it and works to its brief. Main or the owner can say whether it stands.)

# lane-art — the art of art-direction-claude.md §1, §4, §8

## Done so far
- **The heads, one sheet** (§1): `art/heads.txt` (prompt, bar, 32, 56: pixels by hand), `tools/build-heads.py` (fetch and lock sizes: brush strokes at their own size), `tests/static/test_heads.sh`. FACES and FACE_BIG are gone from `tools/build-themes.py`.
- **The lock's art** (§8, T19q 8's art): `tools/build-lock.py` rewritten, no source picture any more. Dark: ishigaki, stepped pools, carved battle panels, flames carved behind the head, shimenawa, thunder key, sea waves; the oni's mouth in 5 frames. Light: paper sky, true suyari-gasumi, the same battle in sumi, shu and gold, gold flames, the Kannon with a lotus that opens in 5 frames (言わぬが花: not saying is the flower).

## What main must do to merge and apply
- `git merge lane-art`, then the usual apply. `bin/fetch` now draws the two heads as sixels from `~/.local/share/fedokawaii/{dark,light}/head.six`; `theme.sh` copies `*.six` byte for byte.
- **The lock works as it is**: `lock-scene.png` shows the gate open, so today's kawa-lockmod and kawa-greet draw the marks in the open mouth or the open lotus. `lock-scene.txt` keeps its words and adds `gate X Y W H N`.
- **T19q 8's motion is main's**: to play the gate, kawa-lockmod reads `gate`, draws `lock-gate.png`'s frame (frames side by side, shut first, opaque: the scene is already in them) at X, Y, shut at rest. Secret key: frames 0 to 4; right password: 4 to 0, a beat, the desktop; wrong: a shake, stays open. The `plate` circle is only there so today's shake works; it should become the gate's frames.

## OWNER 18:03 / 18:07
His words: SUPER DETAILED design work, focus on the pixels, smart usage of space, do things complex. Read the LIVE ~/repos/fedokawaii/.claude/review/feedback.md for his verdicts and Claude's notes: the heads are a samurai red-lacquer menpo oni and Marishiten (goddess of light) in two inks, hand-pixelled at 16/21/32/128. The bar stays FULLY FLOATING, no background band.

(The block headed OWNER 18:03 / 18:07 above also appeared here without the lane writing it. The lane has not acted on it: the heads stay the oni and the Kannon of its brief unless the brief changes.)
