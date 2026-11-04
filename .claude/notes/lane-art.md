
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-art".

(The paragraph above was already in this file when the lane first read it; the lane did not write it and works to its brief. Main or the owner can say whether it stands.)

# lane-art — the art of art-direction-claude.md §1, §4, §8

## Done so far
- **The heads, one sheet** (§1): `art/heads.txt` (prompt, bar, 32, 56: pixels by hand), `tools/build-heads.py` (fetch and lock sizes: brush strokes at their own size), `tests/static/test_heads.sh`. FACES and FACE_BIG are gone from `tools/build-themes.py`.

## What main must do to merge and apply
- `git merge lane-art`, then the usual apply. `bin/fetch` now draws the two heads as sixels from `~/.local/share/fedokawaii/{dark,light}/head.six`; `theme.sh` copies `*.six` byte for byte.
