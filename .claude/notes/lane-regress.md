# lane-regress — T52 "never again"

Started 4 Nov 17:43. Worktree ~/repos/fk-regress, branch lane-regress. Tests only: product bugs go below for main.

## What this lane delivers
- `tools/regress/README.md`: THE LIST — every ledger item r24→r27 and every row of the master's trace → its check, word for word (or: gone / record / manual / open T..). `python3 tools/regress/items.py count`: 650 items, 412 with a check, 23 gone, 104 records, 110 open in their tasks, 1 by hand (his remote page).
- `tools/regress/items.py`: reads that list; `check` (held by tests/regress/test_list.sh) · `count` · `of NAME` · `blame LOG` (a run's ✘ lines as his items).
- `tests/regress/test_*.sh`, new stand-ins, each printing the item and what it measured: boot, bar, fonts, keys, gone, counts, lock, dwl, isolation, kept, suite, wiring, list.
- `tools/regress/*.sh`, new headless: bar-titles, tv-frames (the master's trace: the TV frame by frame), popup-fullscreen, warm-rapid, monitor-state, clipboard, glass-cells, launcher-calc, term-grid (the owner's 2 Nov 18:22: 12 programs × 18 sizes, tiled in each layout, zoom, wide names, scrollback, a theme switch, a live resize, both themes; `term-grid-known.txt` the hand-resized-popup findings), gallery, anim. Stale since the heads, brought back: bar-geometry, prompt-burst, shots.py's tile split; one-popup knows Super+/ follows the app.
- `tools/prepush.sh`: the commit in a throw-away copy, its own dwl built from its patch (6 s): the suite, the headless set, verify; a passed tree not twice; `--install` the git hook (a push to main only; other branches pass).
- `tools/selftest.sh`: under --sandbox, the toolkit's own tests/regress and, with a GPU, tools/regress on the installed dwl.
- Proof each can fail: 26 mutations of the new stand-ins, all caught (/dev/shm/r27/regress/mut/run.sh); tv-frames (order reversed, a third of the pace, other art), warm-rapid (a dwl dropping fast presses), monitor-state (back on workspace 1), glass-cells (alpha-mode=default, the old bug), launcher-calc (no settling, the old bug), bar-titles and popup-fullscreen (failed on the old product, hold on the fix), clipboard (fails today).

## PRODUCT BUGS FOR MAIN (found by the new checks; each fix proven on a scratch copy, nothing of the product changed here)
1. DONE by main 19:09 (bad3e35): the bar grew 1 px under fallback faces; bar-titles.sh.
2. DONE by main 19:09 (bad3e35): a float popup took a window out of fullscreen; popup-fullscreen.sh.
3. **Select + middle click does nothing** (copy/paste, owner 14:27): `configs/home/.config/foot/foot.ini` has `selection-target=clipboard` under the comment "selecting text also fills the clipboard" — foot(5): "one of none, primary, clipboard or both", so the primary is never filled. `tools/regress/clipboard.sh` is RED until this is in.
   Fix, one word: `selection-target=both`. Proven with the kit's --edit: all 13 cells hold.
4. Small, your call (term-grid-known.txt, only by hand-resizing a popup): Super+R under 70 columns cuts its heading ("bo"), the calculator's rule and footer wrap under 80, the clipboard's rule and count differ by a column away from 80.
5. Seen, not a bug of the desktop: while a sum is typed the launcher says "none" until it settles (250 ms); launcher-calc.sh allows it. Your eye.

## What main must do to merge
- lane-integrate merges this branch. Conflicts are unlikely: everything is under tests/regress, tools/regress, tools/prepush.sh, tools/selftest.sh, tools/gallery.sh (one line), tools/README-tools.md.
- A NEW LEDGER LINE WITH A BEHAVIOUR NEEDS A ROW in tools/regress/README.md, or tests/regress/test_list.sh goes red: `python3 tools/regress/items.py check` says which, with the row's shape. Verdicts, suite runs, pushes, applies, events and ASan runs need none (items.py RECORD). A new tools/regress/*.sh needs a row too. So does each lane merged: its tests go in its `open T..` row; a task marked DONE in plan.md with an `open` row is red until the row names its checks.
- A case reworded or removed that a row names: the same command says the line; the row's words follow.
- test_gone.sh's allowed kanji: a lane's UI with kanji (ASOBI's name?) is red by his rule (kanji only on stamps, the lock's quote, the day's seal); his word, or the list in that test.
- Surfaces redesigned on purpose: `bash tools/gallery.sh --record --bin bin --repo-art` once they settle, or tools/regress/gallery.sh is red on them (it says which and how).
- When the merge storm is over: `bash tools/prepush.sh --install` in ~/repos/fedokawaii (hooks are shared by every worktree: lane branches pass untouched, a push to main runs everything, an hour; `git push --no-verify` is the way round it). Not installed here on purpose.
- For `fedokawaii copy` to install the hook on a new copy (plan T52), one line in system/fedokawaii's copy_make after its `git init`: `(cd "$COPY" && bash tools/prepush.sh --install) >/dev/null 2>&1 || true` — product code, left to main.
- `sudo fedokawaii selftest --sandbox` once after the apply: no sudo in the lanes, so its new section ran on stand-ins here (tests/regress/test_wiring.sh runs its very lines), not as root.
- One line for CLAUDE.md's Tests bullet, yours to word: a new ledger line with a behaviour adds its row to tools/regress/README.md; `bash tools/prepush.sh` before a push to main.
- The ledger line, ready: `r27-56 (T52, lane-regress, 4 Nov 17:43–…): every item r24→r27 and every row of the trace in tools/regress/README.md, held by tests/regress/test_list.sh; 13 new stand-in files, 11 new headless checks, each shown to fail on the old behaviour; prepush, selftest --sandbox; found: the bar 1 px taller under fallback faces, a popup taking a window out of fullscreen, select + middle click dead.`

## State (keep current)
- [x] items.py + test_list.sh
- [x] the list complete
- [x] the new checks, each proven to fail on the old behaviour
- [x] wiring: selftest, prepush
- [ ] the final headless run on the merged HEAD
