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
- The daily lessons (Super+U's Learning) must stay correct after every change.

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
- **Apply a change to the live system (never in round 28: its rules below):** `sudo FEDOKAWAII_COPY=$PWD /usr/local/bin/fedokawaii apply`
  (rebuilds dwl from `src/dwl/dwl.patch` into `~/.local/src/dwl`, runs theme, verify).
  A new dwl binary only takes effect in a **new session** (log out/in; the owner does that).
- **dwl work:** edit `~/.local/src/dwl/dwl.c` (= pinned dwl + patch), rebuild there with
  `make WLR_INCS="$(cat /usr/local/lib/fedokawaii-wlroots-0.20/cflags)" WLR_LIBS="-Wl,-rpath,/usr/local/lib/fedokawaii-wlroots-0.20/lib -L/usr/local/lib/fedokawaii-wlroots-0.20/lib -lwlroots-0.20 -lpixman-1 -ldrm" XWAYLAND=-DXWAYLAND XLIBS="xcb xcb-icccm pixman-1 glesv2"` (dwl draws its dissolve with GLES 2: lib/manifest.sh DWL_MAKE),
  test it, then **`bash tools/dwl-patch.sh`** (writes `src/dwl/dwl.patch` from that tree) —
  always before `fedokawaii apply`, which otherwise re-applies the repo's old patch over your edits.
- **Fonts/icons:** after editing `art/icons.txt` → `python3 tools/build-icons.py`; after
  `art/signs.txt` / `tools/build-fonts.py` →
  `python3 tools/build-fonts.py ui JF-Dot-Shinonome14.ttf CozetteVector.ttf` (Sumi UI; the
  sources: URLs and sha256 in the script's header; kept in `~/.cache/r27-fonts/`, not the repo)
  — it also rewrites the air tables of `configs/home/.config/fedokawaii/width.sh`. Sumi Term is
  UDEV Gothic NF as it comes (lib/upstream.sh), an alias in system/60-fedokawaii-pixel.conf.
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
- **Live screenshots (never in round 28):** `grim` with the session's env from `/proc/$(pgrep -x waybar)/environ`.
- **Never** `pkill -f PATTERN` where PATTERN is in your own command line (kills your shell);
  never kill every `gtklock` (the owner's lock) — select by runtime dir / parent pid.
- **Push:** commit here and `git push origin main` (owner's machine has the credentials).

## Round 28 — how every pass runs (owner, 6 Nov 2026; the brief in full: `.claude/inbox.md`, "ROUND 28")
A 100-hour unattended run, Fri 6 Nov 00:30 to Tue 10 Nov 04:30 Dubai, on a very small token budget. He looks at nothing and answers nothing until he says he is back; Claude watches through GitHub (branch `pulse`) and steers through the inbox: "CLAUDE (monitoring the run for the owner, S<n>)" blocks are his voice.

**On START, one small task, nothing else:**
1. `.claude/inbox.md`: a block headed "— open" becomes lines in the plan; its heading becomes "— in the plan: IDS".
2. `.claude/notes/r28-plan.tsv` (tabs: id, day, status, task, when, note; status now, todo, done, blocked, owner; exactly one `now`): do the `now` row. Read only what it needs; tail or grep logs; no long research.
3. Verify it. Then: `done` with the time from `date` in "when", the next row `now`, a one-line note where useful, a ledger line (`r28-<id>`, how verified). Failed twice: roll back, `blocked` with why and what would unblock it, next row. Needs him: `owner`, and a question goes into `.claude/notes/r28-questionnaire.md` with "assumed: …", and you carry on. New work found: a new line.
4. Commit the task and the plan by name (never `git add -A`; `tools/claude-loop.sh` stays uncommitted), `git branch -f r27 HEAD`, push. A pass ends there: the conductor starts the next (`--effort medium`).
`systemctl --user is-active r27-inhibit`, or start it: `systemd-run --user --unit=r27-inhibit systemd-inhibit --no-ask-password --what=idle --who=claude --why=round27 sleep infinity` (an idle lock suspends the PC after 90 s).

**Nobody can rescue this PC.** No reboot, no Fedora 45 on it, no `fedokawaii apply` or anything else system-level, no change to its boot, login, display, network or disks: the installed desktop stays as it is, older than the repo. Fedora 45 is built and proven in VMs and the ISO only (one VM at a time, never image generation while a VM runs). User-level configs only where they undo without a screen. A snapshot before any system change.
**Screen and RGB stay off:** never wake the screen or light the RGB; never reach his session. Renders headless (below) or in a VM.
**No lanes, no parallel subagents.** Sequential work only. Fail smart: at most 3 tries for any one image, never loop on a failure. A usage limit: wait for the reset.
**Design picks:** option sheets are small JPEGs in `~/.local/share/r28/img/` (300 KB and 16 files at most, named like `a1-prompt.jpg`), captions in `captions.txt` there ("file caption", one per line); clear a set once decided. No pick when a build comes up: build the strongest, keep the others one switch away, note "provisional".
**To rest** (only owner lines left, or a steer says hold): `.claude/notes/r28-handover.md`, push, `touch ~/.local/share/r28/hold`, stop the conductor and the `r27-nonstop-*` unit. r28-track, r28-pulse, r28-dark: leave them alone; removed at T62, never in the ISO. `fk-remote` is retired: never restore it.

Older decisions, research, bug lists and the owner's words of round 27: `.claude/notes/r27-digest.md` (read the part a task needs), `.claude/plan.md` (232 KB: grep it), `.claude/notes/02-LEDGER.md` (grep it; add lines at its end, a new `r28-*` id with a behaviour needs a row in `tools/regress/README.md`, or use `r28-note-*`).

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
`.claude/notes/02-LEDGER.md` all requests and status · `round27-owner-notes.md` his words of round 27 · `r27-digest.md` round 27's digest · `r28-plan.tsv` this round's plan.
