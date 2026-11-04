# lane-regress — T52 "never again"

Started 4 Nov 17:43. Worktree ~/repos/fk-regress, branch lane-regress. Tests only: product bugs go below for main.

## What this lane delivers
- `tools/regress/README.md`: the list — every ledger item r24→r27 and every row of the master's trace → its check (or: gone / record / manual / open T..).
- `tools/regress/items.py`: reads that list; `check` (held by tests/regress/test_list.sh) · `count` · `of NAME` · `blame LOG`.
- `tests/regress/test_*.sh`: the stand-in checks that did not exist: boot, bar, fonts, keys, gone, counts, lock, dwl, isolation, kept, suite, wiring, list.
- `tools/regress/*.sh`, new headless: bar-titles, tv-frames, popup-fullscreen, warm-rapid, monitor-state, clipboard, term-grid, gallery, anim.
- `tools/prepush.sh` (the commit in a throw-away copy: suite, headless set, verify; `--install` the git hook, main only), `tools/selftest.sh`'s section under --sandbox.
- Every new stand-in proven to fail on the old behaviour: 26 mutations, all caught (/dev/shm/r27/regress/mut/run.sh).

## PRODUCT BUGS FOR MAIN (found by the new checks; each fix proven on a scratch copy, nothing of the product changed here)
1. DONE by main 19:09 (bad3e35): the bar grew 1 px under fallback faces; bar-titles.sh.
2. DONE by main 19:09 (bad3e35): a float popup took a window out of fullscreen; popup-fullscreen.sh.
3. **Select + middle click does nothing** (copy/paste, owner 14:27): `configs/home/.config/foot/foot.ini` has `selection-target=clipboard` under the comment "selecting text also fills the clipboard" — foot(5): "one of none, primary, clipboard or both", so the primary is never filled. `tools/regress/clipboard.sh` is RED until this is in.
   Fix: `selection-target=both`. Proven with the kit's --edit: all 13 cells hold.

## What main must do to merge
- lane-integrate merges this branch. Conflicts are unlikely: everything is under tests/regress, tools/regress, tools/prepush.sh, tools/selftest.sh, tools/README-tools.md.
- A NEW LEDGER LINE WITH A BEHAVIOUR NEEDS A ROW in tools/regress/README.md, or tests/regress/test_list.sh goes red (it says which, with the row's shape). Verdicts, suite runs, pushes, applies and events need none (items.py RECORD).
- A case reworded or removed that a row names: test_list.sh says the line; fix the row's words. A task marked DONE in plan.md with an `open T..` row: the row must name its checks (test_list.sh says so). The lanes' own tests (chess, typing, torrents, updates, ISO …) go into their rows then.
- After Super+X and the other surfaces settle: `bash tools/gallery.sh --record --bin bin --repo-art` once, or tools/regress/gallery.sh stays red on those surfaces.
- When the merge storm is over: `bash tools/prepush.sh --install` in ~/repos/fedokawaii (hooks are shared by every worktree: lane branches pass untouched, a push to main runs everything; `git push --no-verify` is the way round it). Not installed here on purpose: a push to main would wait an hour tonight.
- For `fedokawaii copy` to install the hook on a new copy (plan T52), one line in system/fedokawaii's copy_make after its `git init`: `(cd "$COPY" && bash tools/prepush.sh --install) >/dev/null 2>&1 || true` — product code, left to main.

## State (keep current)
- [x] items.py + test_list.sh
- [x] the list complete
- [x] the new checks, each proven to fail on the old behaviour
- [x] wiring: selftest, prepush
- [ ] whole suite + regress on HEAD
