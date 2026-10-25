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

## Facts: verified, current, from the source — never from memory
Your training data is old and has been wrong here (a past session claimed FireAlpaca had no
Linux build; it has an official one — firealpaca.com/download). So: **before any claim or
decision about software, hardware, versions, features, support or limits, check the official
source now** — the project's own site, docs, release notes, repository, man page, or the
installed program itself (`--help`, `--version`, `rpm -qi`, `dnf info`). Prefer primary sources
(vendor, upstream, Fedora) over blogs and forums; for teaching material, published books and
recognised authorities. Never write "X doesn't exist / isn't supported" without having looked.
Note the source (URL or command) in the ledger next to each such decision.

## Security (hard rules)
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
- **Visuals of the two apps** (added 19:45): typing (all in the terminal, the keyboard and hands drawn in the TUI itself with our pixel
  fonts and icons — no GUI, no window of its own) shows an on-screen keyboard with the right
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
  36+); launcher entry, XP-Pen with pressure; prove its upsides over Xournal++ first; guide in
  the Learn book. **Its looks matter enormously** (added 19:47): customise it to the limit —
  colours, palettes, UI skin/theme files, fonts where it allows, panels laid out minimal and
  smart (only what he needs visible, the rest one key away), brushes and canvas defaults, both
  themes (follow the dark/light switch) — so it looks like it was born in this desktop. Find
  out from FireAlpaca's own files/docs what it can be themed with; patch or wrap what it cannot.
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

**Update-proof, for good** (added 19:51 — core): he must be able to run the normal update
(`fedokawaii update`, dnf, Fedora releases later) for years without his configs, theme or
desktop breaking. Build on what exists (snapshot before every dnf transaction, the after-dnf
guard rebuilding dwl, private wlroots, verify) and close every gap:
- **Snapshot → update → verify → automatic rollback** if verify (or the session starting) fails,
  with a clear notice; never leave him on a broken desktop.
- **Pin or vendor what breaks between versions** (dwl + wlroots already; check yazi, waybar,
  foot, mako, gtklock + its module ABI, greetd, cava, nvim plugins via lazy-lock.json, Steam
  bits …): either pinned to a tested version, or its config validated against the new version
  (each program's own config check, e.g. `--check`/dry run) before the switch.
- **Configs owned by theme.sh, his own settings kept apart** (fedokawaii.conf, secrets.sh,
  *.local overrides), so an update re-applies the theme without touching his choices.
- **Prove it:** in the VM, install, then apply every pending Fedora update and the next
  release's packages where possible (Fedora 45 / rawhide repos), and show the desktop still
  starts and verify stays green; keep that as a repeatable test (`tools/`), and document in the
  Learn pieces what to do in the rare case an update needs him.

**Self-maintaining updates, no AI, no tokens** (added 19:56 — core): updates run and repair
themselves with plain deterministic tooling, he never has to step in:
- (superseded by the FINAL decision below: one click, no timer) snapshot → `dnf upgrade` → verify
  → session start check (headless dwl smoke test) → keep, or roll back.
- **Hold the culprit:** on a failure, roll back, then find the package(s) that broke it by
  bisection (update halves of the set, verify each), `dnf versionlock` just those, apply the
  rest; re-try the held ones every week and release the lock once they pass. Security updates
  of held packages: notify him plainly.
- **Release upgrades, pre-flighted:** when a new Fedora has settled (as now), the timer builds
  it in a VM first (the proven VM harness: install, setup, theme, verify, desktop start); only a
  green VM lets the real machine upgrade (snapshot first, rollback on failure). A red VM: stay,
  re-try monthly, notify once with the failing checks; warn well before the old release's EOL.
- A short report after each run (notice + log), nothing else asked of him. All of it in the
  installer, tested in the VM (inject a deliberately broken package to prove bisect + lock +
  rollback), and a Learn piece explaining it in one page.

**A free AI fixer on top, $0** (added 20:00): when the deterministic layer above can only hold
a package back (a renamed config option, a changed default, an EOL deadline), a **local
open-weight model on his own GPU** (RX 9060 XT — check its VRAM; llama.cpp/Ollama with ROCm or
Vulkan, whichever the official docs and a measurement say is best on this card) gets the failing
check, the log and the diff, proposes a fix, and the fix is tried **only inside the snapshot**:
verify green → kept and reported, red → rolled back. No cloud, no keys, no cost but power.
Research current models and runtimes from official sources at the time; pick by measured
results, not by name. Prove it in the VM with injected breakages of growing difficulty and
report honestly what it can and cannot fix; if it cannot beat "hold and wait", leave it out.

**FINAL decision on updates (20:05 — overrides the two sections above where they differ):**
- He will **never run dnf himself** — no updates, no installs outside this system. Everything
  goes through **one item in Super+U: "update"**. He clicks it; it does everything A to Z and
  he never has to step in: snapshot → refresh → update (packages, Flatpaks/tools we ship, nvim
  plugins pinned via lock, firmware listed) → verify → desktop smoke test → keep, or roll back →
  hold the culprit by bisection → **local AI fixer** (below) → retry → a short, clear report.
  Release upgrades are part of the same button once the VM pre-flight is green.
  No background auto-updates (his choice); a quiet notice when updates have waited 2+ weeks
  or a release is near EOL.
- **The local AI fixer is required, not optional** — he will depend on it. His card is the
  **16 GB** RX 9060 XT: choose runtime + model by official sources and measurement on this
  card (ROCm vs Vulkan, quantisation, context size, speed), install it via the installer,
  runs fully offline, loads only during an update run (no RAM/VRAM held otherwise). Prove it
  in the VM with a graded set of injected breakages, fix its weaknesses (better prompts,
  structured context: failing check + logs + package diff + config schema docs), and test
  until it is dependable; whatever it still cannot fix ends safely in "held + told".
- **Snapshots, backups, rollback, Btrfs — simplified and hardened**: one clear model he can
  understand (snapshot = undo on this disk, backup = copy on another drive), automatic
  snapshots before every update and on a sane schedule with cleanup, rollback of the whole
  system from Super+U and from the boot menu (grub-btrfs) even when the desktop will not start,
  restore of single files, the backup drive flow, all in Super+U with few, obvious choices.
  Harden: scrub, space checks, read-only snapshot boots, nothing that can leave him unbootable.
  Test every path in the VM (including a deliberately broken boot).
- **Learning section**: a thorough, clear piece explaining all of it — what update does step by
  step, what the AI fixer can and cannot do, snapshots vs backups, how to roll back from the
  menu and from the boot menu, what to do if a notice asks for him.

**The update system must be bulletproof (20:11):** its whole point is that nothing breaks
easily, everything stays current, and it actually works when it matters. Before writing it:
- **Deep research, 300+ sources**, logged with links in `.claude/notes/update-research.md`:
  official docs (dnf5 + its actions plugin, `dnf system-upgrade`, rpm, snapper, grub-btrfs,
  btrfs, systemd, Fedora release notes and upgrade guides, Fedora's known-issues), how others
  solve it (openSUSE transactional-update + snapper rollback, Fedora Atomic/bootc/rpm-ostree,
  Universal Blue/Bazzite, NixOS generations, Arch snap-pac/timeshift-autosnap, ABRoot …), their
  repos and bug trackers, and real failure stories (Fedora Discussion, Reddit, forums, GitHub
  issues): what goes wrong in practice and why automated updaters end up useless.
- **A written design first** (`.claude/notes/update-design.md`): every failure mode and its
  answer — power loss or crash mid-transaction, network drop, disk full, rpmdb damage, a kernel
  or initramfs that will not boot, **/boot outside the Btrfs root** (a root rollback must not
  leave kernels and modules mismatched — handle it), SELinux relabels, firmware, third-party
  repos (RPM Fusion, Steam, Brave, Claude Code) lagging a release, the AI fixer making things
  worse, a rollback of a rollback, /home vs / snapshots, space for snapshots. Argue against it
  as a skeptic; fix the design until no case is left open.
- **Prove every failure mode in the VM** by injecting it (cut power mid-update, fill the disk,
  break a package, break the boot, kill the network), and keep those tests as `tools/` scripts.
  It is done only when every injected failure ends in a working system and a clear message.

**The last phase: a real installer ISO (20:17)** — only after everything above is tested
ruthlessly and solid. One bootable `.iso`, like Omarchy's: boot it, answer the bare minimum
(user, password, disk, maybe hostname/timezone/keyboard), and it installs the **newest stable
Fedora at install time** and the whole fedokawaii system to a finished, working desktop — no
other step. First study how Omarchy's ISO works from its own repo and docs (and how Fedora
builds custom media: Kickstart, `mkksiso`, lorax/livemedia-creator, Anaconda text mode,
Secure Boot with the signed shim), then design ours: our own minimal, on-theme first screen
for the questions; Kickstart doing the base install (UEFI, GPT, Btrfs layout we rely on);
setup + theme running unattended to the end, through their reboots, with clear progress on
screen and a final "ready" with the login screen. Checks: it refuses a too-small disk or no
network with a clear message; nothing ever asks twice. Prove it end to end in the VM (several
runs, wiped disks, slow network, a reboot pulled mid-install), measure install time, keep the
build reproducible (`tools/build-iso.sh`), and put the ISO and its checksum in a GitHub release.
Never run it on his real disk.
The ISO is **fully themed** too, as one piece with the desktop: boot menu, splash, the
question screens, progress and every message — minimal, retro-Japanese pixel style, both the
craft and the calm of Omarchy's installer or better. All of this is part of the same
unattended run started by `tools/start.sh`: zero help from him, take hours or days, be precise
and slow, spend tokens carefully — and deliver the best possible result.

**Fonts — a new selection, decided by you (2026-10-26 00:46; replaces the Sumi faces):** he
looked closely and finds the current font ugly. Choose the whole set yourself, coherent as one
family of choices:
- **UI** (bar, menus, notices, lock, greeter, saver, ISO): Japanese-retro, cool, but genuinely
  readable, with **no letter-spacing problems at all** (every pair, digits and symbols, Latin
  and Japanese). Research current options from their official sources (pixel and bitmap
  families with Japanese coverage, e.g. DotGothic16, PixelMplus, Zpix, Fusion Pixel, Misaki,
  k8x12 — verify each: licence, glyph coverage, sizes it is drawn for, hinting) and render the
  candidates in our real surfaces before choosing.
- **Terminal, Neovim, TUIs**: a professional-grade coding font with Nerd Font glyphs and
  Japanese coverage that reads well for long work (he named "Fira Code"; also weigh e.g.
  PlemolJP, HackGen, Moralerspace, Maple Mono, JetBrains Mono, Iosevka — verify each), tuned
  for 1080p (size, hinting, ligatures on/off, line height), fitting the UI font.
- The earlier "UI 14 / terminal 16 px" decision becomes: **a little smaller than today, more on
  screen**, at whatever sizes the chosen faces are drawn/hinted best. Rework every width table,
  icon size and layout that depended on the old cells; our icon font keeps working with the new
  faces. Refine until it looks right everywhere it appears.

**RGB, all in our red, and the keyboard too (00:46):** every light — case fans, CPU cooler and
its display, the GPU logo, and his **Redragon K617 Fizz** keyboard — set to our red palette
with one tasteful, slow, matching motion (e.g. a dim ember breathe, synced across devices),
and following dark/light if that looks good. K617: use OpenRGB if it supports it (check its
current device list); if not, write the driver: identify its USB IDs, capture the vendor
software's HID protocol (e.g. Redragon's Windows tool in a VM with USB passthrough, usbmon /
Wireshark on the host), implement it (OpenRGB plugin/device or our own small tool), restore
on boot and resume. No excuses — a full solution.

**Monitor — LG 24G411A-B (00:46):** in the performance review, prove **FreeSync/VRR really
works** (EDID range, `vrr_capable`, dwl's adaptive sync on, the refresh actually varying in a
game/video), and use an **optimised colour profile**: research this exact model's panel and
measured settings (reviews, LG's own specs), **set the monitor's own menu settings yourself over DDC/CI** (ddcutil, already
used for brightness: read its capabilities, its VCP codes incl. LG's own, set picture mode,
colour temperature/gains, contrast, sharpness, FreeSync/response options where exposed; re-apply
at boot/wake; he does nothing — the Learn piece only explains what was set and why), and apply a correct profile/LUT through dwl's gamma path if it improves accuracy —
measured, not guessed.

**One design, one unit (20:08 — top priority with the design work):** **Super+U is fully
redesigned** — its structure, sections (system/update/snapshots/backups/learning …), states,
spacing and art — rock solid. Then **every menu and popup is redesigned to match**: quick
settings, Super+W/V/N/R/C, bar dropdowns, Super+/, launcher, notices, OSD, lock, greeter,
saver, the TUI apps. The goal is a single, strong, perfect design system that reads as one
work, not many screens. Write it into `docs/design-system.md` first (grid, type sizes 14/16,
frames, colour roles from the Wada palette, icon grammar, motion), then rebuild every surface
from it, then audit them side by side in both themes until they are indistinguishable in grammar.

Release upgrades (Fedora 44 → 45 → 46 …) go through the same single **update** item: VM
pre-flight first, then the real machine, rollback on failure, AI fixer for what breaks. Be
honest in the Learning piece: a release that changes something big (wlroots for dwl, say) may
be beyond the local model; then the PC safely stays on the working release and tells him well
before its end of support, so he can have it ported.

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
