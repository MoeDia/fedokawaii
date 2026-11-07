# r28 pass brief — read this at a pass's start instead of the long notes (S11)
Keep under 150 lines. Big files: grep or line ranges only, never whole.

## What a pass is
One small task from `.claude/notes/r28-plan.tsv` (tabs: id, day, status, task, when, note, model).
1. `.claude/inbox.md`: a block headed "— open" becomes lines in the plan; heading becomes "— in the plan: IDS".
   "CLAUDE (monitoring the run for the owner, S<n>)" blocks are the owner's voice.
2. Do the row with status `now` (exactly one). Read only what it needs.
3. Verify it on this PC (frames, measurement, test output); say how in the ledger.
4. Row -> `done`, "when" from `date`, next row -> `now`, one-line note where useful.
   Ledger line at the end of `.claude/notes/02-LEDGER.md`: `r28-note-<id>` (or `r28-<id>` with a row in tools/regress/README.md).
   Failed twice: roll back, `blocked` with why and what would unblock it. Needs him: `owner`, question into
   `.claude/notes/r28-questionnaire.md` with "assumed: ...", carry on. New work found: new plan line.
5. Commit the task + plan files by name (never `git add -A`; `tools/claude-loop.sh` stays uncommitted),
   `git branch -f r27 HEAD`, `git push origin main`. The pass ends there; the conductor starts the next.
   Two or three tiny related rows may share a pass, never a big one.
   Never end a pass just to look again; wait for a long job inside the pass (Bash run_in_background + until loop).

## Models (S11)
Column `model` of the plan row: opus = design he judges, dwl/C, lock, ISO/installer, security, anything that failed once
cheaper; sonnet = ordinary code/configs/apps/tests/docs; haiku = mechanical (renames, sweeps, doc follow-ups, check runs).
Effort medium (low for haiku). A cheaper pass that fails: the row goes back to opus. Check `~/.cache/r28-swap.log`.

## Tests (S11)
Per task: only the checks for what changed (`bash tests/<area>/test_x.sh`). Full suite (`bash tests/run.sh`, ~15 min)
and a full VM install once a day and before the ISO is cut (daily rows dsun2, dmon2, dtue2 in the plan, each only on its own day), not after every task.

## Hard rules (the owner's)
- Fedora 45 only (`FEDORA_RELEASE` in lib/common.sh); this PC stays on 44. Zero fallbacks, one tool per job, TUI over GUI.
- Pixel-perfect in dark AND light; follow docs/design-system.md. Never truncate with an ellipsis. Never ask him: decide, say what.
- No demon/angel head anywhere except wallpapers: the head is the Fedora logo (bloody dark, bright gentle light). Keycap style
  (ctrl + a) everywhere keys are shown. Home folders: exactly ~/downloads ~/captures ~/notes ~/books ~/dojo (never ~/Projects).
- Daily lessons (Super+U Learning) must stay correct after every change.
- Facts from the official source now (--help, rpm -qi, upstream docs), noted in the ledger; never from memory.
- Security: never type/store a password, never unlock his lock; keys only in ~/.config/fedokawaii/secrets.sh (600);
  never redraw the Steam logo; keep ~/blasphemous-save-backup-20261022.
- Commits: author "Mohamed Eldoush" <49558059+MoeDia@users.noreply.github.com>
  (`git -c user.name=... -c user.email=... commit`); message ends with the Co-Authored-By line the session gives.

## Nobody can rescue this PC (round 28, until Tue 10 Nov 04:30 Dubai)
- No reboot, no `fedokawaii apply`, nothing system-level; no change to boot, login, display, network, disks.
  Installed desktop stays older than the repo. Fedora 45 is proven in VMs/ISO only (one VM at a time; no image build while a VM runs).
  Snapshot before any system change. User-level configs only where they undo without a screen.
- Screen and RGB stay off: never wake the screen, never light RGB, never reach his session. No live grim, no probes into his env.
  Render headless (dwl with WLR_BACKENDS=headless, own XDG_RUNTIME_DIR) or in a VM.
- No lanes, no parallel subagents; sequential. At most 3 tries per image; never loop on a failure. Usage limit: wait for the reset.
- Idle inhibit: `systemctl --user is-active r27-inhibit`, else
  `systemd-run --user --unit=r27-inhibit systemd-inhibit --no-ask-password --what=idle --who=claude --why=round27 sleep infinity`.
- Leave alone: r28-track, r28-pulse, r28-dark, r28-cooler (removed at T62, never in the ISO). `fk-remote` is retired.
- Never `pkill -f PATTERN` matching your own command line; never kill all gtklock; kill only own pids. Never kill a computed list.
- Tests never under nohup (use `setsid -f`); heredocs: quoted unique terminators. Shell `grep` is ugrep; use /usr/bin/grep for GNU.

## Design picks
Option sheets: small JPEGs in `~/.local/share/r28/img/` (300 KB, 16 files max, `a1-prompt.jpg`), captions in `captions.txt`
there ("file caption" per line); `hi/` is the picker pack. Never wait for picks: build the strongest, keep the others one
switch away, note "provisional". Clear a set once decided. Design = artwork: render both themes, measure px, grill, re-render.

## Where things are
| Path | What |
|---|---|
| `fedokawaii.sh`, `setup.sh`, `theme.sh`, `verify.sh` | menu/command, software, configs/colours, checks |
| `lib/common.sh`, `lib/manifest.sh` | shared values (BOOT_ARGS, palette), every package and why |
| `bin/kawa-*` | the desktop's scripts (bar modules, panel, OSD, lock, menus) |
| `src/dwl/` | `dwl.patch` + config.h (dwl v0.9 @ 98bea2c, wlroots 0.20); C helpers beside it |
| `configs/`, `art/`, `tools/`, `tests/`, `docs/` | home/system files; icons.txt, signs.txt; builders; `tests/run.sh [area]`; design-system.md, Guide, Learn |
| `.claude/notes/` | 02-LEDGER.md (append only; grep it), r28-plan.tsv, r28-questionnaire.md, r27-digest.md |
| `.claude/plan.md` | 232 KB: grep it. `.claude/inbox.md`: owner/monitor blocks (round 28 brief at "ROUND 28") |

## dwl work (the live ~/.local/src/dwl is STALE: never run dwl-patch.sh from it)
Work in a scratch tree from the pinned dwl + `src/dwl/dwl.patch`, `--dwl` option of tools, read the patch diff after.
Build flags: see lib/manifest.sh DWL_MAKE. After editing run `bash tools/dwl-patch.sh` only from the scratch tree you edited.
Headless test: `XDG_RUNTIME_DIR=/tmp/hsrtX WLR_BACKENDS=headless WLR_RENDERER=gles2 WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 dwl -s script.sh`
(wlr-randr --output HEADLESS-1 --custom-mode 1920x1080@144Hz; input via `wtype -s 1000 -k ...`). wf-recorder perturbs timing: use it to look, not to time.
Raw recordings to /dev/shm, delete after.

## Fonts/icons
`art/icons.txt` -> `python3 tools/build-icons.py`. `art/signs.txt` / `tools/build-fonts.py` ->
`python3 tools/build-fonts.py ui JF-Dot-Shinonome14.ttf CozetteVector.ttf` (sources cached in ~/.cache/r27-fonts/).
The loop's PATH lacks ~/.local/bin: export it before tools/kit.sh / gallery.sh.

## Rest
Only owner rows left, or a steer says hold: `.claude/notes/r28-handover.md`, push, `touch ~/.local/share/r28/hold`,
stop the conductor and the `r27-nonstop-*` unit.
