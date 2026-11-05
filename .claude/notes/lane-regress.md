# lane-regress — T52 "never again"

Started 4 Nov 17:43. Worktree ~/repos/fk-regress, branch lane-regress. Tests only: product bugs go below for main.

## What this lane delivers
- `tools/regress/README.md`: THE LIST — every ledger item r24→r27 and every row of the master's trace → its check, word for word (or: gone / record / manual / open T..). `python3 tools/regress/items.py count`: 650 items, 412 with a check, 23 gone, 104 records, 110 open in their tasks, 1 by hand (his remote page).
- `tools/regress/items.py`: reads that list; `check` (held by tests/regress/test_list.sh) · `count` · `of NAME` · `blame LOG` (a run's ✘ lines as his items).
- `tests/regress/test_*.sh`, new stand-ins, each printing the item and what it measured: boot, bar, fonts, keys, gone, counts, lock, dwl, isolation, kept, suite, wiring, list.
- `tools/regress/*.sh`, new headless: bar-titles, tv-frames (the master's trace: the TV frame by frame), popup-fullscreen, warm-rapid, monitor-state, clipboard, glass-cells, launcher-calc, term-grid (the owner's 2 Nov 18:22: 12 programs × 18 sizes, tiled in each layout, zoom, wide names, scrollback, a theme switch, a live resize, both themes; `term-grid-known.txt` the hand-resized-popup findings), gallery, anim. Stale since the heads, brought back: bar-geometry, prompt-burst, shots.py's tile split; one-popup knows Super+/ follows the app.
- `tools/prepush.sh`: the commit in a throw-away copy, its own dwl built from its patch (6 s): the suite, the headless set, verify; a passed tree not twice; `--install` the git hook (a push to main only; other branches pass).
- `tools/selftest.sh`: under --sandbox, the toolkit's own tests/regress and, with a GPU, tools/regress on the installed dwl.
- Proof each can fail: 26 mutations of the new stand-ins, all caught (~/.cache/lane-regress/mutations.sh); tv-frames (order reversed, a third of the pace, other art), warm-rapid (a dwl dropping fast presses), monitor-state (back on workspace 1), glass-cells (alpha-mode=default, the old bug), launcher-calc (no settling, the old bug), bar-titles and popup-fullscreen (failed on the old product, hold on the fix), clipboard (fails today).

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

## State (keep current) — written 4 Nov 20:15, before main's forced reboot at about 20:25
The PC was degraded from 19:51: PID 1 and the user manager in D state, a group lookup 90 s, 27,000 zombies (main's message 20:15; my numbers sent to it 20:07). Every kit since then is NOT evidence: waybar needed 90 s to start, so "no bar measured", "the bar's middle not found" and the like from that time mean nothing. Nothing of /dev/shm survives the boot.

Held before the stall (real runs, on the tree of that moment):
- tests/regress: all 13 files green at 19:32 (printing items and measures); test_kept rc 0; test_list 21/0.
- Headless, by hand on main's bad3e35 and later: bar-titles and popup-fullscreen with the commit's own dwl (19:45–19:49), tv-frames, warm-rapid, monitor-state, glass-cells, launcher-calc; one-popup, lock-*, menu-*, notes-page, notice-unplug, level-display, window-frame, wash, wheel-notch, warm-exit, tile-widths, term-burst, session-start in the run of 18:48.
- term-grid: 454 screens, both themes, 18:50–19:15: held but for term-grid-known.txt. Its tiled scenes were added after and seen in one dark run at 19:13 only.
- static area: green but for this lane's own ShellCheck notes, fixed since (19:21); not re-run on the last commits.

## NEXT, after the boot (in this order; run everything with nice -n 10; `export PATH=$HOME/.local/bin:$PATH` first)
1. `git merge main`; `python3 tools/regress/items.py check`: a row for each new ledger line.
2. tools/regress/bar-layout.sh: written during the stall and NEVER SEEN TO PASS (the bar was not drawn yet, each time). Run it, look at a shot, prove it fails (a --bin with kawa-dwlstatus's classes swapped). Fix or drop it, and its row.
3. Is the kit's wait for 'Bar configured' (tools/kit.sh) right on a free machine? Same for KAWA_HL_NODE (tools/hl-dwl.sh): it never got a clean run either.
4. clipboard.sh once more: its closed-window cell now waits. It stays red on the primary until main takes fix 3.
5. The whole set on the commit's own dwl: `dwl=$(bash -c 'eval "$(sed -n "/^build_dwl()/,/^}/p" tools/prepush.sh)"; build_dwl "$PWD/COPY"')` from a frozen `git archive` copy, then `bash tools/regress/run.sh --bin bin --repo-art --dwl "$dwl"`, in the background with a long timeout. Never edit a script while it runs from the same tree: bash reads it as it goes.
6. `bash tests/run.sh static`, `bash tests/run.sh regress`, then tests/installer/test_torture.sh alone (the selftest section's file; it was stopped waiting on the shared lock).
7. gallery-expect.json: `bash tools/gallery.sh --record --bin bin --repo-art` if main's surfaces have settled; else leave it to main (quick, help, notes and the critical notice differed at 18:50, each from a redesign).
8. Say in this note what is red and whose it is (known at 19:53, main's and not this lane's: content/test_tiles 16, content/test_fetch 4), then end the file with the one-word line, by 21:30.

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.
