> Historical notes from the cloud sessions. Paths (S=/tmp/claude-0/…, the Mac relay, /opt/dwltest) no longer exist — CLAUDE.md has the current procedures.

# Notes for myself — fedokawaii (read this first after any context loss)

Files here (persistent, scratchpad/notes/):
- 00-README.md   this index + how to work (paths, PC access, kit)
- 01-GOAL.md     the end goal and standing rules (never violate)
- 02-LEDGER.md   EVERY issue/request the owner ever raised, with status + evidence. The single
                 source of truth for "is anything left". Update after each fix (status + how verified).
- 03-LOG.md      dated progress log (one line per step done)
- 04-BAR-V10.md  the bar v10 spec (geometry, colours, files)
- src-*.md       raw earlier lists (r24 owner requests, r25 plan) — the ledger cites them

## Paths
- S = /tmp/claude-0/-home-claude/6d31fcd7-1ae3-5468-8ff5-715a71fb37a1/scratchpad
- Repo work copy: M = $S/review14/merge/repo (git base a69b1c7; uncommitted work — commit at the end)
- Kit (render sandbox): `bash $S/round18/kit-theme.sh` (sync M → /opt/kit-repo + theme), then
  `cd $S/real && SHOOT_ONLY="bar" ./shoot.sh dark|light` → $S/real/shots/<theme>/; apps: ./apps.sh
  (run long jobs with run_in_background, never `( … ) &` inside a bg task — it gets killed)
- Measure: $S/r25/gaps.py PNG
- Test-suite agent: id ae25c05a1300b8002 (SendMessage to it; it edits M/tests)

## PC access (owner's Fedora PC, dia@10.62.79.106) — via the Mac VM device_bash
- `$HOME/pc 'cmd'` ssh (170 s timeout) · `$HOME/pcput NAME /tmp/NAME` (from deploy dir) · `$HOME/pcget REMOTE NAME`
- deploy dir: ~/mnt/Downloads/.fedokawaii-deploy-key; push a file: write to /mnt/user-data/outputs/UNIQUE-NAME →
  device_commit_files → pcput. device_commit_files CACHES by name: always a new unique name. Files >~10 MB: split.
- Session env: `/tmp/sess env WAYLAND_DISPLAY=wayland-0 CMD` (recreate after reboot); grim with
  XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0; input: `sudo -n ydotool` (ydotool.service)
- PC copy: ~/repos/fedokawaii (git clone); apply: `sudo -n FEDOKAWAII_COPY=/home/dia/repos/fedokawaii
  /usr/local/bin/fedokawaii apply` (detached: setsid bash -c "… > /tmp/x.log 2>&1" </dev/null &)
- Sync whole repo to PC: tar M (exclude .git) → split parts → commit → cat → pcput → extract to /tmp/rsN →
  delete files not in it (comm) → cp -a; then restore SSH_SERVER="yes" in the copy's fedokawaii.conf
- PC fresh session: [initial_session] trick in /etc/greetd/fedokawaii.toml (see LOG)
- NEVER: enter passwords; kill with patterns matching my own ssh command (use ^anchored pgrep -f)

## End-of-work cleanup (owner 21:57 wants ssh integration "once and for all" — see LEDGER r26-12)
- PUSH: Mac VM, key ~/mnt/Downloads/.fedokawaii-deploy-key/id_ed25519 (deploy key, write) → git@github.com:MoeDia/fedokawaii. Ship repo as tarball via outputs+device_commit_files.
