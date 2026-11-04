# lane-regress — T52 "never again"

Started 4 Nov 17:43. Worktree ~/repos/fk-regress, branch lane-regress. Tests only: product bugs go below for main.

## What this lane delivers
- `tools/regress/README.md`: the list — every ledger item r24→r27 and every row of the master's trace → its check (or: gone / record / manual / open T..).
- `tools/regress/items.py`: reads that list; `check` (held by tests/regress/test_list.sh) · `count` · `of NAME` · `blame LOG`.
- `tests/regress/test_*.sh`: the stand-in checks that did not exist: boot, bar, fonts, keys, gone, counts, lock, dwl, isolation, kept, suite, wiring, list.
- `tools/regress/*.sh`, new headless: bar-titles, tv-frames, popup-fullscreen, warm-rapid, gallery, anim.
- `tools/prepush.sh` (the commit in a throw-away copy: suite, headless set, verify; `--install` the git hook, main only), `tools/selftest.sh`'s section under --sandbox.
- Every new stand-in proven to fail on the old behaviour: 26 mutations, all caught (/dev/shm/r27/regress/mut/run.sh).

## PRODUCT BUGS FOR MAIN (found by the new checks; each fix proven on a scratch copy, nothing of the product changed here)
1. **The bar grows 1 px** (r26-fu-4 back: 28 rows, the windows 1 px lower) under Arabic and emoji window titles, and under Arabic, emoji and Thai in what plays. `tools/regress/bar-titles.sh` is RED until this is in.
   Fix, one rule in `configs/home/.config/waybar/style.css`, at the end:
   `#custom-title, #custom-nowplaying { padding-top: 0; padding-bottom: 0; min-height: 20px; }`
   Proven with the kit's --edit: 27 rows under all five titles, both themes, window and what plays; 0 pixels differ from today for plain and Japanese titles (the words stay on their rows). (Smaller line heights also hold the 27 rows but move the plain title's ink up a row: not those.) test_bargaps may need to read the new padding.
2. **A float popup knocks a fullscreen window out of fullscreen** (bug 9 half done): Super+W, Super+R and every `kawa-term --float` window: dwl's mapnotify un-fullscreens for any new window on the tag. The warm windows and panel menus are fine. `tools/regress/popup-fullscreen.sh` is RED until this is in.
   Fix, two lines in dwl.c (then tools/dwl-patch.sh, a session restart):
   - mapnotify's end: `if (w != c && w != p && !ispopup(c) && w->isfullscreen && m == w->mon && (w->tags & c->tags))`
   - focustop: `if (c->isfullscreen || ispopup(c))   /* (a popup over it keeps the keys) */ return c;`
   (The first alone is not enough: the fullscreen window takes the focus back and the popup closes.) Proven on a scratch build: 10 popups over a fullscreen terminal, each shows, closing gives it back pixel for pixel. Run tools/hl-dwl.sh --asan with it before applying; test_dwl_anim's focustop case words may want a touch.

## What main must do to merge
- lane-integrate merges this branch. Conflicts are unlikely: everything is under tests/regress, tools/regress, tools/prepush.sh, tools/selftest.sh, tools/README-tools.md.
- A NEW LEDGER LINE WITH A BEHAVIOUR NEEDS A ROW in tools/regress/README.md, or tests/regress/test_list.sh goes red (it says which, with the row's shape). Verdicts, suite runs, pushes, applies and events need none (items.py RECORD).
- A case reworded or removed that a row names: test_list.sh says the line; fix the row's words. A task marked DONE in plan.md with an `open T..` row: the row must name its checks (test_list.sh says so). The lanes' own tests (chess, typing, torrents, updates, ISO …) go into their rows then.
- After Super+X and the other surfaces settle: `bash tools/gallery.sh --record --bin bin --repo-art` once, or tools/regress/gallery.sh stays red on those surfaces.
- When the merge storm is over: `bash tools/prepush.sh --install` in ~/repos/fedokawaii (hooks are shared by every worktree: lane branches pass untouched, a push to main runs everything; `git push --no-verify` is the way round it). Not installed here on purpose: a push to main would wait an hour tonight.
- For `fedokawaii copy` to install the hook on a new copy (plan T52), one line in system/fedokawaii's copy_make after the clone: `bash "$COPY/tools/prepush.sh" --install >/dev/null 2>&1 || true` — product code, left to main.

## State (keep current)
- [x] items.py + test_list.sh
- [x] the list complete
- [x] the new checks, each proven to fail on the old behaviour
- [x] wiring: selftest, prepush
- [ ] whole suite + regress on HEAD
