# CLAUDE.md — working on fedokawaii (read this first, every session)

Fedokawaii turns Fedora 44 Server (minimal) into a retro-Japanese pixel desktop on **dwl**
(patched), for one owner: Mohamed Eldoush (PC user `dia`, GitHub MoeDia). His PC: Ryzen
(iGPU) + Gigabyte RX 9060 XT, one 1080p 144 Hz monitor (HDMI-A-1), XP-Pen tablet. You run
**on that PC itself**: this clone is the working copy (`~/repos/fedokawaii`), the live
install is what `fedokawaii apply` made from it.

## The owner's standing rules (never break)
- Zero fallbacks; one tool per job; TUI over GUI. Performance and RAM are paramount.
- Pixel-perfect in **both** themes (dark and light). Follow `docs/design-system.md`.
- Never truncate with "…" anywhere (cut at a word, or fit).
- Never ask the owner — decide yourself, say what you decided. (He asked for this.)
- Patch open-source software when it limits us (dwl, gtklock, yazi …), write drivers if needed.
- Keep `.claude/notes/02-LEDGER.md` accurate: every request, its status, how it was verified.
  Nothing is "done" until verified on this PC (say how: frames, measurement, screenshot).
- Concise replies to the owner. Test aggressively, visually, frame by frame.
- The Learn book (`docs/fedokawaii-learn.md` → PDF, opened from Super+U) must stay correct
  after every change; the big book update happens at the very end, when he says so.

## His taste — and your mandate to fill the gaps
He asked (2026-10-25): understand his personality and philosophy, fill in what he did not
spell out, be more creative. What a month of his requests says about him:
- **Craft over decoration.** He notices one pixel of misalignment, a double frame, a gap that is
  1 px off, a flicker for one frame. Measure everything; "almost aligned" is wrong.
- **Alive, never boring.** Static, generic, "default-looking" things annoy him (plain rectangles,
  grey visualizers, kanji used as a lazy icon). He wants motion with character (playful pixel
  animation), things that react to state (a slider going red when high, icons that move while
  something runs), and custom-made art everywhere instead of stock symbols.
- **A world, not a theme.** Retro-Japanese pixel art with a story: demon (dark) and angel
  (light), dungeon torches, old masters (Kuniyoshi, Hokusai), the red seal. Dark and light are
  two distinct moods, not one design recoloured. Extend that world wherever it fits.
- **Smart, not chatty.** Things should do the obvious right thing (Steam's icon shows/hides
  Steam; DND's icon shows DND; Super+/ knows the app you are in). Minimal UI, no clutter, no
  text that explains what a good design makes obvious.
- **Fast and solid underneath.** Performance, RAM use, zero glitches and robustness against
  updates matter as much as looks; he tests by breaking things.
- **Density on one monitor**, TUI over GUI, keyboard first.
- **Learning is personal** (chess, typing, the Learn book, coding): make those experiences
  rigorous, motivating and beautiful.
So: when a choice is open, pick the bolder, more crafted, more alive option that stays
consistent with the design system and costs no performance; propose and build small delights
he did not ask for (in the same spirit), list them in the ledger as r27-extra so he can veto.


- Never type, store or repeat any password; never unlock his lock screen. (Restarting his session
  for a new dwl is allowed — see START below — but never by typing a password.)
- API keys only in `~/.config/fedokawaii/secrets.sh` (mode 600).
- Never redraw the Steam logo. Keep `~/blasphemous-save-backup-20261022`.
- Commits: author "Mohamed Eldoush" <49558059+MoeDia@users.noreply.github.com>; end messages with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (plus a Claude-Session line if given).

## Layout
| Path | What |
|---|---|
| `fedokawaii.sh` | the menu / `fedokawaii` command (setup, theme, apply, update, repair, verify) |
| `setup.sh` | software, 3 phases, resumes after reboots · `theme.sh` configs/colours · `verify.sh` checks |
| `lib/` | `common.sh` (shared values: BOOT_ARGS, palette roles …), `manifest.sh` (every package, why) |
| `bin/kawa-*` | the desktop's own scripts (bar modules, panel, OSD, lock, saver wrapper, menus …) |
| `src/dwl/` | `dwl.patch` + `config.h` against dwl v0.9 @ 98bea2c (wlroots 0.20); `src/kawa-saver`, `src/kawa-lockmod`, … C helpers |
| `configs/` | home and system files theme.sh installs · `system/` fonts, plymouth, greeter, report |
| `art/` | `icons.txt` (pixel icons → `tools/build-icons.py`), `signs.txt` (hand-drawn glyphs → `tools/build-fonts.py`) |
| `tools/` | font/icon/theme/cursor builders, selftest, package audit |
| `tests/` | `bash tests/run.sh [area]` — every script against stand-ins in a throw-away home |
| `docs/` | design system, the Guide and Learn sources + PDFs, `docs/build/` (how the PDFs are made) |
| `.claude/notes/` | the ledger, round notes, the owner's raw notes — your memory between sessions |

## How to work here
- **Apply a change to the live system:** `sudo FEDOKAWAII_COPY=$PWD /usr/local/bin/fedokawaii apply`
  (rebuilds dwl from `src/dwl/dwl.patch` into `~/.local/src/dwl`, runs theme, verify).
  A new dwl binary only takes effect in a **new session** (log out/in; the owner does that).
- **dwl work:** edit `~/.local/src/dwl/dwl.c` (= pinned dwl + patch), rebuild there with
  `make WLR_INCS="$(cat /usr/local/lib/fedokawaii-wlroots-0.20/cflags)" WLR_LIBS="-Wl,-rpath,/usr/local/lib/fedokawaii-wlroots-0.20/lib -L/usr/local/lib/fedokawaii-wlroots-0.20/lib -lwlroots-0.20 -lpixman-1 -ldrm" XWAYLAND=-DXWAYLAND XLIBS="xcb xcb-icccm"`,
  test it, then **`bash tools/dwl-patch.sh`** (writes `src/dwl/dwl.patch` from that tree) —
  always before `fedokawaii apply`, which otherwise re-applies the repo's old patch over your edits.
- **Fonts/icons:** after editing `art/icons.txt` → `python3 tools/build-icons.py`; after
  `art/signs.txt` / `tools/build-fonts.py` →
  `python3 tools/build-fonts.py JF-Dot-Shinonome16B.ttf JF-Dot-Kappa20B.ttf unifont_jp-17.0.05.otf`
  (the three sources: URLs in the script's header — jfdotfont-20150527.zip, unifont_jp 17.0.05;
  keep them in a scratch folder, not the repo) — it also rewrites `configs/home/.config/fedokawaii/width.sh`.
- **Tests:** `bash tests/run.sh` (all, ~15 min) or one file `bash tests/<area>/test_x.sh`.
  Update tests with every behaviour change; all must pass before pushing.
- **Headless visual testing on the real GPU** (no disturbance to the live session):
  `XDG_RUNTIME_DIR=/tmp/hsrtX WLR_BACKENDS=headless WLR_RENDERER=gles2 WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 dwl -s script.sh`
  (own runtime dir; `wlr-randr --output HEADLESS-1 --custom-mode 1920x1080@144Hz` inside;
  input with `wtype` — use `wtype -s 1000 -k …` so the virtual keyboard exists before the key).
  Frame timing: log dwl's own commits (an env-guarded fprintf in rendermon) — **wf-recorder
  perturbs timing** (screencopy readback) and must not be used to judge stutter; use it to
  *look* at frames (`ffmpeg -fps_mode passthrough`, else ffmpeg duplicates frames forever).
  Raw recordings are huge: write them to `/dev/shm`, delete after.
- **Live screenshots:** `grim` with the session's env from `/proc/$(pgrep -x waybar)/environ`.
- **Never** `pkill -f PATTERN` where PATTERN is in your own command line (kills your shell);
  never kill every `gtklock` (the owner's lock) — select by runtime dir / parent pid.
- **Push:** commit here and `git push origin main` (owner's machine has the credentials).

## Current state (2026-10-25)
GitHub main = c5798a9 + this handoff. Live PC built from it; `fedokawaii verify` 234/234.
Last verified: clean VM install (229/229, no "interrupted"), snapshot undo, restic backup/restore.

## Round 27 — the owner's notes of 2026-10-25 (`.claude/notes/round27-owner-notes.md`)
Read the raw notes in full; this is the digest plus his answers (asked 2026-10-25 18:30).

**His decisions**
- Animations: **playful pixel** style (dissolves, stamps, scrolls unrolling), **400–450 ms** for
  window open/close and workspace switch; menus, Super+N etc., lock→desktop, first login after
  boot (greeter → session has none today) all redone. Wallpaper + theme ink wash: **1.2 s**.
- Fonts: terminal **20 → 16 px**, UI **16 → 14 px** (pick/derive proper pixel faces; rebuild
  width tables; everything re-aligned). Bar height **27 px** (now 31).
- Kanji stays only on: workspace stamps (numeral **black**, small, fully inside the red circle,
  1–9), the lock quote, the bar's day-of-week clock seal. Everywhere else in TUIs and menus: real
  custom pixel icons instead of kanji.
- Lock screen: new art, **no** date/time/power buttons; password typed inside a demon's mouth
  (dark) / Japanese angel (light), two retro torches, dungeon feel; one Japanese quote, no
  translation, display lettering (**you pick the quote**). Art: **pixel-art versions of
  public-domain old masters** (Kuniyoshi, Hokusai demons; Buddhist angel paintings) — also for
  ~10 demon wallpapers (dark) and ~10 angel wallpapers (light), and the quick-settings icon
  (demon dark / angel light) on the bar's far right, the fetch art.
- Yazi: **keep the engine, rebuild the whole UI** (layout, contrast in dark, alignment at many sizes).
- Prompt: **rebuild ours** in a pastel-powerline style (with his terminal icon in it), palette from Sanzo Wada's *A Dictionary of
  Color Combinations* (data: github.com/mattdesl/dictionary-of-colour-combinations); let the
  Wada palette inform the whole design system.
- Theme switch: the **mouse cursor** changes instantly today — animate it with the rest of the
  dark↔light transition.
- Wallpaper auto-change (4 h): a toggle key **inside Super+W**, shown at the bottom.
- **A full chess app** (a complete TUI program of our own — board, play, review, lessons,
  puzzles, progress — not just a course), classy retro-Japanese, in a new **Learning section of
  Super+U**. It takes him from zero to **1800 chess.com rapid** in one year: **730 games**
  (2 a day) vs **built-in Stockfish** at lesson-matched levels, each game a deliberate, critical
  lesson, plus **~10 min of puzzles a day**. Reverse-engineer and study chess.com (lessons,
  analysis, ratings) and research how complete beginners are best taught (Steps method,
  Heisman …); argue with yourself, criticise, keep it super minimal and super effective.
- **A full typing app** (TUI, same Learning section) modelled on EdClub/TypingClub — reverse-
  engineer how it teaches quickly; **English, 100+ WPM** target; proper speed (WPM) and accuracy
  measurement; test it rigorously.
- **Learning, done properly** (added 19:41): chess and typing apps tested to destruction —
  every screen, key, window size, both themes, odd input, interrupted lessons, resume after a
  reboot — beautiful and fully working everywhere. Ground both in deep research from reputable
  sources, cited in the apps' docs: chess — the Steps Method (Brunia & van Wijgerden), Yusupov's
  *Build Up Your Chess*, Heisman's *Everyone's 2nd Chess Book*, Chernev's *Logical Chess: Move
  by Move*, Seirawan's *Winning Chess* series, Silman's *Complete Endgame Course*, Polgár's
  *Chess: 5334 Problems*, the Woodpecker Method, chess.com's own lessons; typing — EdClub /
  TypingClub's progression, keybr's adaptive letters, deliberate-practice research (Ericsson),
  accuracy-first touch typing, standard WPM (5 characters a word) and accuracy as Monkeytype
  measures them. Minimal, alive, on theme.
- **Visuals of the two apps** (added 19:45): typing shows an on-screen keyboard with the right
  finger for every next key at all times (EdClub style: hands/finger colours, the key lit,
  errors shown), alive; chess has a custom-made pixel board and custom-drawn pieces — all TUI,
  beautiful and magical, with move animation, last move, threats and hints drawn on the board.
- **The Learning section of Super+U**: the Learn book **cut into ordered pieces** — short
  lessons he does one by one, in the sequence that teaches best (dependencies first), each
  with its place shown (lesson n of N, done ✓), beautifully organised and following the
  alignment/spacing/theme rules — next to the chess and typing apps. **The old Guide PDF goes:**
  delete `docs/Fedokawaii-Guide.pdf` and its build and every menu entry or test that points to
  it (keep `fedokawaii-guide.md` in the repo only as the technical reference). The learning
  material is just: the Learn pieces, chess, typing.
- Drawing: **FireAlpaca has an official Linux build** (2.16.3, firealpaca.com/download — Fedora
  36+); theme it, launcher entry, XP-Pen with pressure; prove its upsides over Xournal++ first;
  guide in the Learn book.
- RGB: write it all yourself — OpenRGB where supported, reverse-engineer/drivers otherwise:
  darkFlash case fans (+ hub, connection unknown — find out: `lsusb`, `dmidecode -t baseboard`,
  i2c), Jungle Leopard CPU cooler (incl. its display), Gigabyte 9060 XT logo RGB.
- Repo: cleaned; this handoff.

**Bugs to fix (verify each on the PC)**
1. Screen saver → lock after a **long** absence (screens dark, 30 min+), key press: **frozen
   picture then a sudden cut**. Still seen after 00:16 Oct 25. Fix in dwl `saverinput()`:
   `saverwake()` lights outputs, `saverkeys()` gives the keyboard back to the saver, guard +4 s.
   That fix was built ~00:55; if he still sees it after a fresh login, reproduce for real:
   `kawa-lock --screens off` while the saver runs, wait, press a key, record frames.
2. Notes (Super+N): black areas around text while typing; flicker on save; spacing between the
   header and first line; redesign as a vertical lined notebook, margins constant while scrolling.
3. Bar dropdowns (calendar, timer): highlighted rows inactive until first click — fix for good.
4. Lock: blinking cursor sometimes missing; wrong password takes long to report — make it fast.
5. Wallpaper change: a black box flashes first.
6. Flicker in terminal apps: notes save, launcher calculations/conversions; clipboard exit shows
   "terminated" briefly.
7. Super+C calendar must open centred under the date.
8. Only one menu/popup open at a time — test every combination (bar dropdowns, Super+U/W/V/…).
9. Popups (Super+V …) must show over fullscreen windows.
10. Locked PDFs etc.: proper password prompt; wrong password → says so in place, no new window.
11. .rar in yazi errors (Fedora's 7-Zip has no RAR; use `unrar`, already installed).
12. Torrents: slow, "failed to resolve" when **starting a download**; notice on every open for
    already-finished downloads; stress/measure it.
13. Brave download: no % progress, an odd link icon in the notice.
14. Steam may think it is a Steam Deck — investigate (client config, env, gamepad UI).
15. Super+U: headings too close to their first item (status, upkeep …).
16. Super+R (books): tear down and redo alignment/spacing.
17. Dashed separator lines in TUIs: remove; refine spacing and alignment everywhere.

**Bar redesign**: 27 px; no inner cream second frame on any cell (incl. the red end buttons);
active window title lighter weight; date `DD/MM/YYYY` with a custom red pixel slash; US red /
AR blue and clickable; red separator between video title and channel/episode; visualizer in
our red; DND bar icon → small DND-only menu; Steam: tooltip "Steam show/hide", click brings it
to the current workspace / hides it; animated icons: a retro antenna TV while video plays,
joystick moving while Steam runs, downloads icon while downloading; weather "sunny" icon
different from brightness; window borders get the bar's 3D shadow look. Sliders (volume,
brightness): not a plain rectangle, alive — turning red when high. Re-measure all spacing, alignment and fit — every icon and section, and the bar's distance from
the window borders.

**Added 18:48**: a **to-do list beside the notes (Super+N), reachable from Super+U too** — dead simple: items with a checkbox,
done items struck through; no reminders, no dates, nothing else. And a **design coherence pass
over everything**, above all the menus (quick settings, Super+W, Super+U, Super+V, every
popup): one colour use, one frame, one spacing and alignment grammar, one philosophy.
And a **rigorous performance test** of the whole desktop at the end of the round: frame times
measured inside dwl (not via screen recording) during heavy real use across many apps, every
animation's frames checked at 144 Hz, input-to-screen latency for keys, menus and the bar,
app start times, RAM/CPU/GPU tracked, crashes hunted; numbers before and after in the ledger.

**Everything trickles into the installer** (added 19:45): every change must be made by
setup/theme/apply from a clean Fedora 44 (VM-proven at the end, as before), never by hand on the
PC. Use what kernel 7.2 and Fedora 44 offer for performance and stability (scheduler, memory,
I/O and GPU features, sensible sysctls and boot arguments — each measured, none on faith).
Neovim: faster start-up and editing (measure `nvim --startuptime`, lazy-load, cut plugins that
cost more than they give). Finally **harden and optimise the repo once more**: dead code out,
duplication folded into `lib/`, ShellCheck clean, every script's errors handled, tests for
every path, `fedokawaii selftest --sandbox` clean.

**Also**: RAM caching of apps (preload aggressively; most RAM is idle); Super+/ much more
comprehensive, fuzzy search, context-aware (shows the active TUI app's keys first — detect the
app in the focused foot); performance and visual bug hunt everywhere.

## How round 27 is run (owner's choice, 2026-10-25)
Best possible result, fewest tokens; time does not matter (30 hours is fine).
1. **Planning (Fable, max effort):** a planner subagent (model `fable`, effort `max` — the
   owner asked for exactly this) reads this file, the notes and the code that matters, and
   writes `.claude/plan.md` — every item above as a numbered task with: files touched, approach,
   acceptance test (how it is measured/verified on the PC), dependencies, and which model does
   it. Order: foundations that move everything first (font sizes 14/16 px, bar 27 px, palette),
   then the design-coherence pass and the bar, then lock/animations/art, then apps (notes,
   to-do, yazi, Super+/, chess, typing, FireAlpaca, RGB), then bugs left, the performance test,
   and the books last (on his word).
2. **Then the main agent works the plan** one task at a time, and keeps all design-critical and
   cross-cutting work (bar, animations, lock, dwl, design pass) for itself.
3. **Subagents only for well-fenced grunt work** (writing/updating tests, research digests,
   chess curriculum content, icon drafts, package/driver investigation): one at a time (no
   parallel agents on the same files), a tight brief naming exact files and the acceptance
   test, told to read only what it needs and return a short result; cheaper models for
   mechanical work. The main agent verifies every result itself before marking it done.
4. **Token discipline:** long output to files, never into the context; reusable test scripts
   kept in `tools/` (headless dwl runs, frame logs, analysers) instead of retyping them; the
   ledger updated after each task so a /compact or a new session resumes from the files.
5. **The owner is not needed.** He types START and goes about his day (see START below).

## START — one command, then you run to the end on your own
The owner runs `bash tools/start.sh` and leaves. That installs a user service (survives
session restarts **and reboots**: linger starts it at boot) which runs
`claude -p START --dangerously-skip-permissions --model opus --effort max` in a loop
(`tools/claude-loop.sh`) until `.claude/DONE` exists. Each pass is a fresh session: **all
state lives in the repo** — `.claude/plan.md`, the ledger, git. Log: `~/.cache/claude-r27.log`.
On "START" (each pass):
1. If `.claude/plan.md` does not exist: spawn the planner (Agent, model `fable`, effort `max`)
   to write it as described above; read it; critique it hard; fix it; commit.
   Otherwise resume at the first task not marked done.
2. Work the plan task by task; never ask, never wait; every decision is yours (his taste
   section). Blocked → best alternative, why in the ledger, move on. End a pass only at a clean
   point (task committed, ledger updated) — the loop starts the next pass at once. A pass that
   changes nothing three times in a row stops the loop, so never end a pass without progress.
3. **Idle inhibitor** for the whole run, so the saver/lock never comes up (you can never unlock
   it): `systemd-run --user --unit=r27-inhibit systemd-inhibit --what=idle --who=claude --why=round27 sleep infinity`
   (start it if `systemctl --user is-active r27-inhibit` says no). If the lock is up anyway,
   work headless until the session is back.
4. **The live session** (WAYLAND env from `/proc/$(pgrep -x waybar)/environ`). To load a new dwl
   or after a reboot: never with a password — check nothing of his is unsaved (if an editor
   with changes is open, do other tasks first), then: back up `/etc/greetd/fedokawaii.toml`,
   append `[initial_session]` / `command = "/usr/local/bin/start-dwl"` / `user = "dia"`,
   `sudo rm -f /run/greetd.run; sudo systemctl restart greetd`, wait 9 s, restore the file.
   Before a **reboot**, leave that `[initial_session]` in place and restore the file after the
   session is up again (the service resumes you at boot).
5. Commit and **push** after each finished task; ledger updated after each task.
6. **Design is the heart of this round** (see "Design: an artwork" below).
7. **After the plan is done:** (a) a **research round** — go to the official docs and upstream
   sources of everything touched (dwl/wlroots, foot, waybar, gtklock, greetd, plymouth, yazi,
   mako, pipewire, Steam, FireAlpaca, OpenRGB, Stockfish, Fedora 44 notes …), find what you
   missed or did against the grain, fix it; (b) **maniac testing**: every app, menu, key,
   combination and edge case, both themes, aggressive load, try to crash everything; reboots
   (`sudo systemctl reboot`, as in 4) and a cold boot — power-off test last of all, with
   `sudo rtcwake -m off -s 180` so the PC powers itself back on (only after everything is
   pushed: if it does not come back, nothing is lost); (c) the performance test; fix all found;
   (d) full test suite + `fedokawaii verify`; push.
8. **Finish:** stop the inhibitor; `sudo rm /etc/sudoers.d/90-claude-temp`; a short summary for
   him at the top of the ledger (what changed, what to look at, numbers before/after); then
   `touch .claude/DONE` (the loop ends). The books wait for his word — leave that task open.

**What the owner does — once, then never again** (he will not watch logs or check on you):
log in, open a terminal (Super+Enter), run
`cd ~/repos/fedokawaii && git fetch -q && git reset -q --hard origin/main && bash tools/start.sh`,
type his password once when asked (and sign in to Claude Code only if it asks), wait for
"✔ round 27 is running", leave. Everything after that — restarts, reboots, limits, recovery —
is yours. (`bash tools/start.sh status|stop` exist, but do not count on him using them.)

## Design: an artwork
He cares about the design more than anything: accuracy, beauty, alignment, spacing, motion.
The goal is work that would impress millions — an artwork. Spend the time. For every visual
change: sketch alternatives, render them (both themes, real fonts, at 1× and zoomed), measure
every gap and edge in pixels, compare against the design system and the rest of the desktop,
then **grill it**: list everything an exacting art director would criticise, fix it, render
again; repeat until nothing is left to criticise. Animations: inspect frame by frame at 144 Hz
(timing curve, overshoot, every intermediate frame clean, no tearing or stray pixels).
Keep `docs/design-system.md` the single truth and update it as the design grows.

## Notes folder
`.claude/notes/02-LEDGER.md` (all past requests and status — continue it as r27-N lines),
`round27-owner-notes.md` (his words), `00-README.md`/`03-LOG.md` (history of how things were
done; paths there refer to the old cloud sandbox — use this file's procedures instead).
