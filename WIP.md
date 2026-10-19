# Work in progress — round 22 (paused 2026-10-19 ~16:00 Dubai)

This branch (`wip`) holds everything since `main` 97ce813, mid-flight. `main` is the last
tested release; do not install from `wip`.

## Done in this round (code + tests, not yet on main)
- theme.sh: the live-session step used `find /run/user/UID`, which dies on the document
  portal's FUSE mount → the boot part, console font and wallpaper pack never ran on the real
  machine. Now a glob. (test_theme: live-session case)
- dwl: spiral redesign (golden first split, even after, 600×336 minimum, grid beyond),
  columns cap at 3, monocle removed (Super+M unbound), `$XDG_RUNTIME_DIR/dwl-pointer` written on
  bar clicks (`X Y OUTPUT OUTPUT_X OUTPUT_WIDTH`), first-frame race fixed
- kawa-panel: `--sound` (volume, outputs, inputs, mute, mixer; Super+A) and `--brightness`
  panels; hover/focus fixes; opens clean; placement under the clicked icon; friendly device
  names; kawa-audio retired
- clipboard: Super+Z shrinks the entry under the cursor in Super+V; converts again any time
- weather: Open-Meteo, 7-day `kawa-weather --menu` (feel words), bar from the same source
- wallpapers: 120 (60/60) final, owner-culled three times
- report: false positives of run 2 fixed; Spotify checks replaced; wayland-utils added
- brightness tooltip (no literal "false")
- docs/design-system.md: the design system, from the sound panel

## In flight when paused (check each agent's last state; finish, test, render)
1. bar (waybar, kawa-bar, kawa-menu interface): every icon toggles, lights while its menu is
   open, no orange boxes but workspaces, weekday back in the date ("Mon 19 Oct" on bar, lock,
   greeter), tooltips audit, volume OSD replaces in place, nowplaying leak
2. kawa-menu backend → `kawa-panel --menu` (all dropdowns in the panel's look; calendar as a
   panel grid); **menus must size to content** (the weather menu's gap before the temperature
   is far too wide — owner's last remark)
3. apps: Spotify app removed (web player entry via Brave + visualizer smooth via MPRIS/cava),
   Prowlarr no login + ready, Steam graceful quit at logout/shutdown (cloud sync), Torrents
   entry, Brave GPU (was a report false positive), nvim rocks off, snd_hda power_save=0
4. herdr (Agents) launcher entry broken — cause being found
5. terminals in small tiles: prompt adapts to width, yazi ratio by width, btop/lazygit narrow
6. wallpaper picker: cached sixel previews + 1080p pre-scaled switch (kawa-wallpaper had a
   syntax error at line 549 mid-edit — check `bash -n`)
7. design system rollout: terminal screens (Super+U, change, help, clipboard, books, notes,
   share, syncplay, status), launcher/mako/lock/greeter/GTK/Qt, the handbook PDF
8. report: Steam/Prowlarr/audio/weather/panel/monocle/clipboard checks; THEME-10 measuring fix

## Then
- full suite (`pfull.sh`), renders (kit-theme, shoot, apps), handbook, merge to main, push
- owner: update (`sudo bash fedokawaii.sh update` then `repair`), reboot, run `fedokawaii report`
- owner asked for a complete list of every issue reported and its status

## Known breakage on this branch (fix first next session)
- fzf.opts now `--border=none` (design system): every fzf screen not yet moved to `--header`
  headings loses its title — clipboard, books, Syncplay (test_syncplay 26/120 failing), the
  backup drive picker, the wallpaper picker, the shell's Ctrl+T label. Only Super+U is
  restyled (100x25 now; job windows, status). Still to restyle: kawa-clip, kawa-config,
  kawa-help, kawa-share, kawa-books, kawa-notes, kawa-together, kawa-backup (+ shoot.sh, guide).
  New: configs/home/.config/fedokawaii/screen.sh (screen_heading/row/footer), foot colours 16–23.
- launcher/notices/lock/greeter/GTK/Qt restyled but never rendered; failing tests not updated:
  look/test_launcher (round radios), session/test_bar (menu widths: calendar 1384/1680,
  launcher 808), look/test_lock, status/test_volume + test_brightness (fake_notify change).
  The OSD is now quick settings' meter row (seg glyphs added to the icon font).
- handbook.py restyled (seals, stitch, palette, Fusion Pixel) but the full build hung (>14 min,
  idle in Chromium) — suspect the stitch background on every table row; untested.
- terminals in tiles: content/test_tiles 158/6 (ble.sh resize test flaky under load); the
  4-row tile shows "(line 3) …" — drop the blank line before the prompt when rows are few.
- apps: installer tests not re-run after the Spotify removal; look/test_theme timing (2);
  content/test_configs (btop presets line) fixed, not re-run; test_report still expects
  SPOT-01b unless the report agent updated it.
- Steam: Super+Ctrl+Shift+Q (config.h) does not yet run `kawa-steam --quit`.
- docs/fedokawaii-guide.md was rewritten whole twice by agents (weather) — check that no
  other agent's guide edits were lost (grep each area's new text) before merging.
- menus: kawa-menu's backend is now `kawa-panel --menu` (socket to the session panel; line
  format: part/row/cell/gap, TAB-separated; filter line; sized to content). NOT rendered yet.
  Callers not ported to the line format (they send fuzzel-style lines, shown as plain rows):
  power, calendar (grid via `cell`), timer, drives, steam, config, shrink, share, help — and
  their tests still check fuzzel args. shoot.sh closes menus with `pkill -x fuzzel` (wrong
  now). test_bar: launcher x-margin 840 vs 808; a flaky day-poke case. Backup of the old
  kawa-menu: the fuzzel version is on main. design-system.md: unlit squares are edge2.
- sound panel device names done (test fixture pw-owner.json modelled on the owner's machine).
- bar: toggles + lit state via bin/kawa-bar (pid markers, per-button signals: torii 20, date/day
  19, drives 13, steam 17, weather 18, layout 9; cat only for quick settings), openers via
  `setsid -f`, no filled boxes but workspaces, "Mon 19 Oct" (bar, lock, greeter), new volume
  module `kawa-volume bar` (pw-mon), osd replaces in place (mako synchronous). test_bar 243/3
  (backend swap: two poke/open-count checks + launcher x-margin), test_timer's menu cases fail
  (fake fuzzel never called) — port to the panel backend. Guide bar table + help text and the
  final bar render not done (probe: scratch real/probe-bar.sh).
- Agents (herdr): works; entry is footclient -N -a kawa-agents -T Agents -D ~/repos -- herdr,
  readable colours, verify launches it on a pty (python). test_verify not re-run since;
  report HERDR-01 text still says "kawa-term herdr".
- report: still to add — weather (BAR-18/18b for Open-Meteo), Steam rows, Prowlarr login rows,
  audio modprobe file, UI-04/UI-10 must read kawa-menu's state file (menus are kawa-panel now),
  the "tooltip":false run, dwl-pointer, kawa-clip --held, layouts = spiral/columns/floating.
- wallpaper picker speed work was stopped mid-way: check bin/kawa-wallpaper and its tests
  first; the preview cache / 1080p pre-scale may be half in.

## Owner's request for next session
- Full bash review for stability: bash/ble.sh, eza, fd, zoxide, lazygit, neovim — each
  100 % installed and working, no errors or warnings at shell start or in use (aliases,
  completions, ble.sh hooks, zoxide init, fzf keys, LazyVim :checkhealth clean).
- A complete list of every issue reported across the project, each with its status.
- A WhatsApp web entry in the launcher, made like Spotify's: brave-origin
  --app=https://web.whatsapp.com, official icon where one exists, its notifications through
  mako (Brave's web notifications), tests and the guide.
