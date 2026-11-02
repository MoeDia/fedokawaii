# LEDGER — every owner issue/request, status, evidence
Status: OPEN · WIP · DONE(code) · VERIFIED(on PC/kit, how) · WAIT(owner input)
Rule: nothing is "done" until VERIFIED on the real PC (or kit for visuals) — say how.

## r26 — 2026-10-21 21:41–21:57 (current round)
- r26-1 Bar: more stitches; stitching exact to the pixel — VERIFIED kit dark+light and PC (r26/measure.py: every thread→ink gap 8, clock/wings 12, layout 16; patches framed on their edge pixels, corners stitched; hems top+bottom)
- r26-2 Bar: music visualiser — DONE: wings either side of the clock (L/R channel, fifo from kawa-nowplaying); VERIFIED kit; PC: verify while music plays
- r26-3 Bar: workspaces not the launcher's orange — VERIFIED (current = kinari on ink / kachi on paper, vermilion numeral)
- r26-4 Bar: stitch-separate right icons — VERIFIED (seam per cell, 8/8)
- r26-5 Bar: middle colours — DONE (nezumi warm grey, date text, kanji vermilion, time strong); timer moved to its own cell
- r26-6 Animations — DONE: frame-driven (every refresh), eased out, 220 ms; held screens wait; VERIFIED sandbox stress (ASan clean, RSS flat) + PC stress (30 rapid opens/closes, RSS flat, nothing left). Owner to judge feel. (First deploy OOM'd dwl → fixed)
- r26-7 Prompt: full drastic rework, better; FIX misalignment when many terminals open quickly — VERIFIED PC: left-only heading redesign; dup heading cause = foot's ED2 pushes the screen into scrollback, so \e[3J must come AFTER the clear; 8-window bursts 0/17 dup (was ~40%) (r26/dups.py). Tests → test agent
- r26-8 Busy cursor after unlock — DONE(code): dwl destroylock re-asks the pointer after the lock leaves the scene (was before: GTK's busy cursor stayed); deployed; needs owner's unlock to confirm (I can't type the password)
- r26-9 Design consistency upgrade — DONE: PC gallery in dark and light (launcher, quick, calendar, weather, timer, notice, lock, saver) all on one grammar (seal heading plus stitch rule, 2 px frames, glass). Saver moved onto the bar's cloth thread. design-system.md: §5 motion rewritten (220 ms eased, frame-driven; was 'nothing eases, 96 ms'), §9 saver plus a 'two families of frame' rule. Still to look at: greeter, OSD, boot (with #180)
- r26-10 Screensaver: delay when pressing a key to exit; design upgrade — VERIFIED PC: the first input starts kawa-lock at once (it locks in ~110 ms) and washes the cloth into the ground (180 ms); the saver leaves when the lock is up (fake-lock test: it left the moment the lock returned; real key: gone in 175 ms). Design: thread = the bar's cloth thread plus a shadow dot (saver.conf thread/shade replace faint/muted); the clock patch is framed in running stitch. r24-45 follows the theme (saver.conf per theme)
- r26-11 Full sweep of the whole history; notes; 0% issues; script TUI visuals; guide + PDF on GitHub — WIP (this ledger)
- r26-12 Integrate with the PC properly: no more ssh breakage; script takes it into account; trim leftovers/garbage — OPEN
  (SSH_SERVER=yes must survive update/repair/reboot; firewall permanent; key-only; remove test tools/leftovers)

## r25 — 2026-10-21 17:27 (14 points + additions; src-r25-plan.md)
- r25-1 Font Sumi UI/Term thicker (Shinonome 16 Bold / Kappa 20 Bold) — VERIFIED PC (declared Bold, no smear)
- r25-2 Super+W current wallpaper highlighted; 4-hour toggle text not cut — VERIFIED PC
- r25-3 Bar menus: hover/keys without a click; static rows not selectable — VERIFIED PC
- r25-4 Bar redesign — superseded by r26 (v10)
- r25-5 Notifications alignment — kit ok; re-check in consistency sweep (r26-9)
- r25-6 Terminal prompt/gap/torii; lock redesign — prompt VERIFIED earlier but r26-7 reopens; lock: check in sweep
- r25-7 Boot black box + 2 flicks — DECIDED 23:30: drop plymouth.use-simpledrm (one modeset fewer; PC ran without it since r25); delegated to the installer agent (BOOT_ARGS_GONE plus removal from every entry, verify, report BOOT-30, tests, docs). Was: WAIT (owner video); repo TODO: plymouth.use-simpledrm removed on PC only → check repo BOOT_ARGS, report BOOT-30, theme.sh comment, tests/installer/lib.sh, guide
- r25-8 Snapshots boot read-only — VERIFIED PC
- r25-9 Torrra faster + themed; nvim themed — VERIFIED PC (both themes)
- r25-10 Best audio quality — DONE(code) quality 14, rates to 192k, BT codecs; deployed by apply (verify active: pw-metadata / pactl)
- r25-11a update/repair/install clean — VERIFIED (apply rc=3 only wlrctl/ydotool = my tools); herdr check bug fixed
- r25-11b Launcher live calc — VERIFIED (kit launcher-calc shot)
- r25-12 Launcher toggles; mouse/keyboard unified — VERIFIED earlier
- r25-13 Script TUI looks — DONE (lib/common.sh grammar) VERIFIED PC verify window; check update/setup/repair headings on a run
- r25-14 Full sweep — OPEN (part of r26-11)
- r25-15 dwl animations + fix rapid open/close artifacts — superseded by r26-6
- r25-16 Be the end user: open every app/menu on the PC, fix visual + script bugs — OPEN (final phase)
- r25-17 Learn guide: AI / Claude Code part with exercises + fundamentals — DONE (Part VI 67–72 + appx D); PDF rebuild pending
- r25-x Bar menus/panels transparent like the terminal — VERIFIED PC
- r25-x Docs: design-system §8 v9, README, guide §6.5 — DONE for v9 → redo for v10

## r24 — earlier "final round" list (src-r24-owner-requests.md) — each needs a VERIFY pass
1 update stuck → ? · 2 black box after kernel choice → WAIT (=r25-7) · 3 calc/notes footer glitch → ? ·
4 bar tooltips minimal → ? · 5 launcher icons (duck/sheep) custom pixel seals → ? · 6 clipboard input gap → ? ·
7 theme switch transition → ? · 8 rapid terminals re-layout + prompt + cursor-line spacing in EVERY TUI → reopened r26-7 ·
9 Super+N rapid toggle → ? · 10 screen recording entry in quick settings → ? · 11 calendar prev/next/today glitch → ? ·
12 btop spacing → ? · 13 dropdown hover w/o click → VERIFIED (r25-3) · 14 mixer ◆ spacing → ? (wiremix char_sets ▌) ·
15 torrents pip error → VERIFIED (r25-9) · 16 steam tooltip "starting" while running → ? · 17 launcher calc/currency → calc VERIFIED; currency ? ·
18 smooth open/close/resize, no wrong-size frame → r26-6 · 19 learn guide longer (Python/Rust levels) → ? (check size/levels) ·
20 wallpapers auto 4 h, 100 total, transition → ? · 21 Blasphemous / Proton → ? · 22 yazi file picker jumbled → ? ·
23 font thicker → VERIFIED (r25-1) · 24 screensaver wake slow/black, lock thin → reopened r26-10 · 25 PDF shrink, Super+Z rules, 52 KB bug → ? ·
26 Alt+F / share picker first option highlighted → ? · 27 window screen-share rock solid → ? · 29 sleep/wake Enter → owner said works ·
33 clean mic active → ? · 34 Blasphemous 60 fps cap, black after workspace switch → ? · 35 downloads % + zip/PDF progress → ? ·
36 recording pause/resume + 3-2-1 countdown, fullscreen perf → ? · 37 OCR/screenshot keys on 61-key board → ? ·
38 fast clicking system-wide → ? · 40 boot menu orange bar + 2 blinks → WAIT · 41 every Super+U option works, public repo → ? ·
42 bar kanji/launcher colour change, workspace borders → r26 v10 · 43 every warning serious → standing · 44 token-efficient → standing ·
45 screensaver follows theme → ? (check saver.conf at run time)
Report findings (r24): mako double start; BAR-04/06; RES-03; PERF-05/07/09; UI-02/16; THEME-22 (XCURSOR_THEME) → ?

## Leftovers to remove from the PC at the very end (or keep per r26-12 decision)
my ssh key (claude-fedokawaii) · /etc/sudoers.d/90-claude-temp · claude-awake.service · wlrctl, ydotool(+service) ·
/tmp/px /tmp/sess ~/.cache/claude-sess.log ~/.cache/claude-fontpick /root/claude-bak · test tarballs in /tmp
Mac: tell owner to `sudo rm /etc/sudoers.d/90-claude-temp` on the Mac if present.

## r26 (cont.)
- r26-13 (22:02) Installer: never yet a fully clean run (no ✘, no !) — packages, versions, install paths, future
  updateability; research the web — WIP: dedicated agent a2f29204875d0683b (notes: notes/installer-agent.md); then
  prove on PC: `fedokawaii trial` + full update/repair, zero ✘/!
- r26-12 progress: setup.sh s_ssh SSH_SERVER=yes → /etc/ssh/sshd_config.d/40-fedokawaii.conf (keys only, no root),
  enable+reload sshd; verify checks enabled+active, keys-only, firewall ssh; guide §5.2 row — DONE(code)

## r24 verify pass (2026-10-21 23:00, PC, fresh session)
- 4 tooltips minimal — VERIFIED ("RAM 8% of 30 GB", "volume 100%", "brightness 50%", "Sharjah · clear", "Steam")
- 5 launcher seals — VERIFIED (Torrents 種, Agents 代, Files 箱, Books 本… seals; the duck and sheep icons are gone)
- 6 clipboard gap — VERIFIED (a blank row between the input and the first entry)
- 8 TUIs spacing — VERIFIED (clip, wallpaper, books, notes, help, config: heading, blank, input, blank, list)
- 9 Super+N rapid — VERIFIED (3 presses in 163 ms → toggled 3 times: each press counted)
- 10 record tile in quick settings — VERIFIED
- 11 calendar — VERIFIED (5 Enters on next in a burst → Mar 2027, none lost)
- 12 btop — looked at: block graphs, square corners, consistent; accepted
- 16 steam tooltip — VERIFIED (class ready, tooltip "Steam" while running)
- 17 launcher calc/currency — FIXED+VERIFIED: "100 eur in usd" → $112.15 (was inches nonsense); money to the cent;
  "5 km to miles" → 3.106855961 mi (no mixed units); kawa-calc and kawa-panel share the rule; screenshot lc2
- 20 wallpapers — VERIFIED (111 in the picker, the rotate row first)
- 26 first option highlighted — VERIFIED (launcher, timer, calendar open on their first choice)
- 37 OCR keys on the 61-key board — Super+Shift+X / Super+Shift+S / Super+Shift+A bound (config.h)
- 45 saver follows the theme — VERIFIED (light saver shot gl1-saver: indigo on kinari)
- Leftover found: cliphist entries 29/30 (the owner pasting my access setup: sudoers + ssh key) → delete at cleanup
- r26-14 (23:03) "screen tearing, desktop not vsynced?" — checked PC: 144 Hz HDMI on card1 (dGPU), VRR off, desktop commits
  are vsynced page flips. Only tear path was fullscreen + tearing-control async. FIX(code): async only when m->vrr==1
  (FreeSync on), so with FreeSync off nothing tears. Built (vsync1). Guide row updated. Deploy with full apply; owner told.
- r26-15 (23:06) "tearing during open/close and workspace change" — cause: the unroll/roll-up (a hard horizontal
  edge sweeping down a full-height window) and the full-width slide (a vertical edge crossing the screen) READ as
  tears; the flips were vsynced (wf-recorder: 7 ms/frame at 144 Hz, no failed flips). FIX: dwl open = fade in plus a
  24 px rise; close = ghost fades plus a 24 px sink; workspace = cross-fade plus a 6 % drift (anim_rise/anim_drift in
  config.h); opacity honours alpha-modifier. VERIFIED PC: applied (rc=0), fresh session, recording anim2: fades
  clean, no edges. ASan clean, RSS flat. design-system §5 updated. Tests: test agent to update test_dwl_anim.
- r26-16 (23:13) bar: classier, subtler stitching, better spacing, especially the music widget; (23:15) the clock
  must not look stitched: blend into the bar, separators only — DONE+VERIFIED on the kit and the PC (bar v11): bottom
  hem only; cloth thread sunk 40% into the cloth; no cross arms; seams = three stitches at caps height (rows 9–21);
  hitomezashi tone 0.1; clock on the cloth parted by two seams (8 px each side, measured); wings = 8 thin 2-px columns
  per side, warm grey by height (edge2/faint/muted/text), 16 px from the clock; label = title plus the artist in faint;
  old pictures retired (theme.sh); docs updated. PC shot barv11b.
- 25 shrink — VERIFIED: text on the clipboard → "nothing to shrink" (no stale image)
- 33 clean mic — FOUND inactive: WirePlumber's default.configured.audio.source pinned the raw ALSA mic (overrides
  the clean_mic priority 3000) → set to clean_mic (pw-metadata); the sound panel's clean-mic key shows on/off
- 35 downloads — VERIFIED: a job file gives "50%" on the bar (jobs from kawa-file use it)
- 36 recording — VERIFIED: rec 00:03 → pause "録 停" → again "録 3" countdown → rec; stop writes the mp4 (test file deleted)
- 14 mixer ◆ spacing — VERIFIED (wiremix "▌ HD-Audio Generic": air before the name)
- cleanup done: cliphist 29/30/33/34 deleted, the owner's clipboard restored to entry 28
- 19 learn guide — VERIFIED: 90k words, Python levels 1–4+ and Rust, 71 exercise headings; learn ch. 5's bar table
  rewritten to v11 (order, wings, timer, Steam, keyboard)
- 22 yazi save picker — VERIFIED (portal SaveFile: the tree, the stand-in file, its notes, the footer; no overlap)
- found: `fedokawaii trial` leaves ~/fedokawaii-trial.lock and ~/fedokawaii-trial.d in home → installer agent
- r26-12 cont.: fedokawaii.conf default SSH_SERVER="yes" (keys only); guide rows updated; agent: cockpit always out.
  PC now: sshd enabled+active, PasswordAuthentication yes (the old setup) → keys only after the next update. Push:
  this sandbox cannot push to MoeDia/fedokawaii (proxy 403, add_repo refused) → commit locally, bring the commits to
  the PC copy, the owner pushes (git push in ~/repos/fedokawaii).
- 3 calc footer — VERIFIED (typing at 15 ms/key: the footer whole, the answer live)
- r26-17 (23:43) still doesn't love the bar → 3 drastic variants mocked (r26/mock/mock.py; outputs bar-variant-A-tabi
  (RPG windows), B-noren (cloth strips from a rod, current hangs lower), C-sumi (no bar, mist, ・, ensō)) — WAIT owner pick
- GitHub: the connected account is fluvia4ai and the repo is MoeDia/fedokawaii → asked the owner to add fluvia4ai as a collaborator — WAIT
- r26-18 (23:49) owner likes the separate pieces, wants it more retro and old-Japanese → mocked D ukiyo-e cartouches, E senjafuda slips, F chōchin lanterns (r26/mock/mock2.py) — WAIT owner pick
- r26-19 (23:55) wants more elegant options that survive any wallpaper → G urushi (lacquer+gold), H kami (washi+vermilion seal), I hinoki (cypress tags); each piece has a hairline plus a soft shadow; the title and wings sit on pieces; tested on 8 wallpapers (r26/mock/mock3.py) — WAIT owner pick
- r26-20 (00:03–00:04) owner picked H kami: more symmetry, spacing, centering; dark and light each different; more flair.
  Mock r26/mock/mock4.py: tiles rows 3–27, caps 9–21, ink-exact 8 px pads, 4 px within groups, 10 between, edge 6;
  the clock's kanji on x=959.5, the clock framed as a hanging scroll (lacquer rods, gold caps); the current workspace a worn
  vermilion seal; torii/cat vermilion tiles with a gold rule; dark = 墨染め (ink-dyed paper, pale words), light = 生成り
  (pale paper, sumi). Tried and dropped: seigaiha on red (reads as dashes), gold/bark flecks (read as dust). Sent
  bar-kami-dark/light.png — WAIT the owner's OK, then implement in waybar (CSS box-shadow for the rules and hairline,
  border-image or bg png for the fibres, modules' margins for the gaps, the scroll rods as images).
- r26-21 kami docs: design-system §1/§3/§8/§9, README, guide §6.5 + workspaces, learn 5.1; palette cloth/aizome/kinari/kachi removed; waybar.css trimmed to used defines (@quiet→@muted).
- 38 fast clicking — VERIFIED (cat: 7, 6, 5 clicks at 50–60 ms → open, open, closed: every click counted; no extra panel procs)
- 21/34 Blasphemous — NOT RUN: Steam stopped at a Cloud Conflict over the owner's saves (a choice that could lose his
  progress — his to make); cancelled, Steam shut down. Tell the owner.
- r26-22 (01:06) bar alignment/contrast + prompt cursor gap — bar: layout/title split tiles, scroll symmetric (8/8, centred 959.5), title air, wings air, steam pad, hairline/shadow stronger, rod gap removed + round lacquer rod. Kit + PC measured: all 8/8, 4/10, 6.
- r26-23 (01:09) lock screen consistent — DONE: gtklock/kawa-greet on lock-scroll.png (2x kami scroll) + lock-fibre; setup/verify install them. Kit verified both themes.
- r26-24 (01:19–01:57) prompt: ~20 variants; owner chose the short one-line (torii green/vermilion, parent faint, folder strong, ⑂ branch*, code, took, jobs, › vermilion). Implemented + real foot render kit + docs (guide 11.3, design §7, README). Test agent told.
- Blasphemous: owner chose cloud save (Jan 16); local save backed up ~/blasphemous-save-backup-20261022; game runs, workspace switch back not black.
- r26-25 (02:09) bar to the pixel: seal = clean ellipse drawn to the padding box (26x19 / 25x19 narrow) VERIFIED kit centre 15.5/15; rods meet paper (dark only outer col); text tiles padded by first/last letter air (width.sh air; title, nowplaying, date month) — "Steam" now 8/8.
- r26-26 (02:10) fullscreen game black after workspace switch — CAUSE: Wine game minimises itself on leaving; dwl un-minimised only on focus, and Steam (on every tag) took focus. FIX dwl: focustop prefers visible fullscreen; arrange un-minimises shown X11. VERIFIED PC (Blasphemous away/back: Normal, focused, drawing).
- installer agent DONE (report in its notes); test agent DONE; fixed product bugs it found: kawa-wallpaper show||return, report ✘ regex + BAR-10 skip, _heading full-disk, shellcheck, wait_until WAIT_STEP=5 for network.
- books rebuilt (guide 41.9 MB, learn 7.0 MB) with kami bar/prompt/lock shots; kit: notes via --inside --shown, share via session panel.

## r26 follow-ups — 2026-10-24/25 (cloud session; all pushed by c5798a9)
- Font air column (every letter/digit/symbol keeps its last column free) — VERIFIED render + PC bar
- % sign redrawn by hand (art/signs.txt) — VERIFIED PC bar
- Joystick + 日-sun brightness icons (5 steps) — VERIFIED render; owner wants them better/animated (r27)
- Bar height grew with Arabic/emoji/Thai titles (to 46 px) — VERIFIED headless: span line_height 15360 → 31 px always
- Boot splash ×3 — DONE: initcall_blacklist=simpledrm + split_lock_detect=off; journal shows splash on amdgpu only; owner to confirm visually
- Saver→lock after screens dark: frozen then cut — DONE(code) saverwake+saverkeys+guard+4 s, VERIFIED headless (wlopm off 20 s, key → fade). Owner still saw it after 00:16 (may predate the 00:55 build) → r27 bug 1
- Layout holds 250 → 60/50 ms — VERIFIED (dwl loop watchdog: never blocked ≥20 ms in 1000 random actions)
- Ink-bleed wash 720 ms — VERIFIED 1080p144 headless 121 frames none late; owner: make it 1.2 s (r27)
- kawa-lock killed every gtklock on its 10 s failure — FIXED (only its keeper's child)
- Clean VM install 229/229, snapper undo, restic backup/restore — VERIFIED

## r27 — 2026-10-25 owner notes → see CLAUDE.md "Round 27" (decisions + bug list) and round27-owner-notes.md
(add r27-N lines here as work proceeds)
- r27-1 (reported 26 Oct 14:07) "random restart" — CAUSE found: no reboot that morning (journalctl
  --list-boots: boot -1 ran 25 Oct 14:06 → 26 Oct 23:43, orderly shutdowns only); **dwl crashed** at
  26 Oct 12:22:19 (coredumpctl: SIGSEGV in configurex11; objdump at 0x40b86f = `c->mon->sellt` with
  c->mon NULL) → session closed → greetd login = "restart". c->mon is NULL only with no monitor: the
  LG drops off HDMI when switched off (same root as r27-2); an X11 window (a Wine app in a podman
  container was running) asked for a new size meanwhile. Upstream dwl main has the same bug.
  FIX dwl: configurex11/dirtomon/focusmon/move-snap/animstart NULL-safe. DONE(code), applied
  (rc=0); tools/hotplug-test.sh (root: a test dwl on the iGPU, its HDMI forced on/off via sysfs
  status + amdgpu trigger_hotplug, the LG's EDID): OLD dwl → "Segmentation fault" at check 1 (the
  26 Oct crash reproduced; its core is in coredumpctl as root's dwl, 02:23), NEW → all 12 checks
  pass. VERIFIED live 02:49 (new session on the new dwl, nothing of his unsaved: notes nvim 0
  modified buffers, START terminal idle, no input for 30 s): tag 3 + an X11 window (xconf), real
  HDMI-A-1 unplug (amdgpu trigger_hotplug 0: wlr-randr empty), 40 resize requests with no monitor
  → dwl alive (same pid), replug → 1920x1080@144 back, bar shows workspace 3 (screenshot).
  Crash evidence for next time: journal persistent ✓, coredumps ✓ (dwl's truncated by its GPU
  mappings, the top frame was enough); a kernel panic would leave nothing → efi_pstore (built in,
  off: CONFIG_EFI_VARS_PSTORE_DEFAULT_DISABLE=y) on with `efi_pstore.pstore_disable=0` in the
  boot-args batch (one reboot), systemd-pstore.service (enabled) archives it.
- r27-1 (cont., T01b) crash evidence: dwl is already built with debug info, not stripped (`file`:
  "with debug_info"); the report already lists crashes by program (desktop ones since setup =
  FAIL). New: kawa-crashnote at login — the session before ended in a crash of HIS dwl →
  one critical notice "the desktop restarted · dwl crashed at HH:MM, in FUNCTION" (a root test
  dwl's crash, another program's or none → nothing); tests/session/test_crashnote.sh (11). The
  core stays capped at 1G (systemd's default; dwl's GPU mappings truncate it, the top frame is
  kept). efi_pstore.pstore_disable=0 rides T41's boot-args batch (one reboot).
- r27-2 (26 Oct 14:07) monitor on → always workspace 1 — CAUSE: dwl destroys the output on the
  HDMI drop and createmon starts at tag 1. FIX dwl: monkeep/MonKept — each output's tags,
  layouts, mfact, nmaster, mode and focus kept by name and restored; one turned off (wlopm) before
  it dropped comes back still off (upstream 4953b7e's idea; it reconnects with no wl_output, so
  wlopm can't reach it) and any key PRESS / button / move / pen lights it (never a key release:
  the key that turned it off) at its mode, kawa-display --hotplug then. hotplug-test: tag 3,
  layout |||, 120 Hz (preferred 144) all restored; kept-off stays dark, release leaves it dark,
  press lights it. Tests: tests/session/test_hotplug.sh (new, 6), test_dwl_anim updated.
  VERIFIED live (as r27-1: workspace 3 kept across the real unplug/replug, 144 Hz) and DPMS:
  wlopm --off HDMI-A-1 for 90 s (the LG stayed connected: sysfs never left "connected"), a key
  press (wtype) lit it. (03:20) hotplug-test extended to 5 real cycles × {tags, layout, mode,
  focused window, floating window x/y} + the spiral's mfact: it caught a real bug — after the
  monitor came back the focus was on another window (setmon focused each re-attached window,
  reordering the focus stack) → `monbatch` in closemon/updatemons; now all pass. VERIFIED.
- r27-3 (T03) toolbox — DONE: dwl frame log + framestat.py (--anim: per-window animation steps;
  --strict), perf.sh, hotplug-test.sh + xconf.c, hl-dwl.sh (headless on renderD128, --asan:
  libasan added to PKG_BUILD and installed by apply/repair), shot.sh (--both themes), px.py,
  README-tools.md, tests/static/test_tools.sh 15/15. Verified: hl-dwl leaves no /tmp/hl-dwl.*,
  passes the script's exit status; ASan run: 124 KB "leaked" at exit = one-time EGL/mesa setup +
  2 event sources in setup() — nothing per window (a growth check goes to T52); live bar gaps
  need a flat-ground render (translucent hairline/shadow over the wallpaper) → T14. Finding for T19 (live, 144 Hz, 03:25): every
  animation has its length (open 240 ms/37 steps, switch 236 ms/36, close 180 ms/26–28) and rises
  to 1, but ~half skip 1–4 steps (gaps of 2 refreshes) — a held frame mid-animation.
- r27-0 push blocked: this PC has no GitHub credentials (no credential helper, no gh login, no
  SSH key — `git push` → "could not read Username"). Decided: commit locally, branch `r27` moved
  to every commit (safe from the owner's `git reset --hard origin/main` one-liner; a memory note
  outside the repo says how to restore main from it); CLAUDE.md START step 0. The owner pushes
  once at the end (`git push origin main` with his credentials) — told in the final summary.
  UPDATE 27 Oct 18:18: pushing works — he logged in with gh (credential helper `gh auth
  git-credential`, account MoeDia); origin/main = 93d90fd; every commit is pushed again, r27 kept
  as a mirror. (Commit with -c user.name/user.email: the repo has no identity of its own.)
- r27-loop (27 Oct 18:13, outside a session) tools/claude-loop.sh now runs each pass under
  `timeout 1h` and sleeps 23 h after it — his throttle, left as it is (uncommitted, never
  staged); each pass now ends at a committed point within the hour.
- r27-4 (T04 DONE 03:45 — the BASELINE, all rows in .claude/notes/perf-before.md; dwl = crash fix +
  frame log only): tools/perf.sh → .claude/notes/perf/before-perf.txt (raw: ~/.cache/fedokawaii-perf/r27-before).
  Idle 30 s: CPU 0.3 %, GPU 0 % 3.0 W, VRAM 273 MiB, RAM 3.0 GiB used (PSS: steamwebhelper 1068
  MiB, steam 219, Xwayland 42, dwl 37, waybar 29). Boot 20.4 s (firmware 10.7, loader 1.9, kernel
  1.7, initrd 3.5, userspace 2.6). Frames at 144 Hz: 0 dropped in 65 animation streaks (2,000+
  frames); dwl's build p50 55–74 µs, max 0.67 ms. Key→glass (dwl's part, wtype): windows/switch/
  menus p50 8–10 ms p95 12–25; typing in foot p50 18.6 ms p95 24, one 165 ms outlier (to find in
  the perf task). New terminal press→first frame 7–15 ms. nvim --startuptime 9.8–10.8 ms.
  Tools: dwl frame log (DWL_FRAMELOG, SIGUSR2 → $XDG_RUNTIME_DIR/dwl-frames.log), framestat.py
  (drops = gaps inside 4+-frame runs), perf.sh (--again re-reads a run). Added (03:30–03:45):
  the heavy scene (tools/perf-load.sh: 0 dropped of 10,305 frames, CPU 1.3 %, GPU 10 %), the latency
  suite --full (58 ok; FAIL Brave cold 20 s timeout, lazygit 1010 ms, recording start 1209 ms),
  boot pace (10 boots), nvim in a real pty to VeryLazy 148 ms (tools/ptytime.py; headless said 10).
  The latency suite's "Brave from cold" FAIL is its method: `brave-origin-stable --headless=new
  --dump-dom about:blank` hangs to the timeout here even with --password-store=basic, --disable-gpu
  and --ozone-platform=headless (04:12) → T60 times Brave as he meets it: the key press to its
  window's first frame (frame log W line), cold (caches dropped) and warm; the suite's row fixed.
- r27-6 (T06) the one early notice — DONE+VERIFIED 03:24: facts from the official pages: the
  LG 24G411A-B has one DisplayPort 1.4 and HDMI 2.0, 120 Hz native / 144 Hz overclocked
  (lg.com/cl/monitores/gaming/24g411a-b); the MSI PRO B650M-B shows only HDMI (4K@60, HDMI 2.1)
  and VGA (storage-asset.msi.com/datasheet/mb/us/PRO-B650M-B.pdf: "1. HDMI 2. VGA", no DP).
  Both VM display designs (DDC input switch or Looking Glass) need the same wiring, no adapter:
  the card's DisplayPort → the LG's DisplayPort; his HDMI cable → the board's HDMI. BIOS: nothing
  (IOMMU 39 groups, AMD-V, iGPU enabled). New: kawa-foryou (things only he can do, kept as files
  until he clicks them done: a critical notice at every login — mako [app-name=foryou] click =
  done — and Super+U status's first row "for you"); test_foryou.sh (15). Shown live (shot), and
  `fedokawaii status` leads with it.
- r27-5 (T05) the VM harness — VERIFIED (04:44): tools/vm-create.sh (session VM, kickstart = the README's
  install on this PC's layout: one Btrfs subvol root, /boot XFS outside, UEFI; Fedora 44 from the
  master server https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/
  (.treeinfo "Fedora 44"; the redirector's mirror refused the initrd: 403) + updates repo; no
  password at all — harness key + sudo; base.qcow2 + overlay, boots in 11 s), vm-snap/vm-run/
  vm-smoke, test_vm_tools.sh (20). Fixed on the way: a Minimal Install has no tar (README's first
  step done first); F44 has no @^minimal-environment (custom-environment, as the PC); setup refuses
  a VM display → hw_test_vm (a marker only the harness sets; video decode and DDC/CI become named
  skips, never passes); GPU=amd in the VM's conf (his package set). Green 04:25: setup to "done",
  verify 230 passed + 3 named skips, dwl/waybar/mako up, screenshot ok (resumed at the gate after
  the verify fix — a full fresh run follows). The PC's 27 extra checks were session checks (verify
  ran before the desktop) → vm-smoke now verifies with the desktop up.
  DONE 04:44 — the full fresh run, in one go: a bare Fedora 44 → fedokawaii.sh all through its
  reboots in 16 min → desktop up (dwl, waybar, mako; screenshot ok) → verify 251 passed + 4 named
  skips (H264/HEVC/AV1 decode, DDC/CI; the PC: 257). State "built" saved (vm-snap.sh f44 save built,
  22 s: 12 G overlay over the 61 G base, reflinked — ~/VM is its own Btrfs subvolume, outside the
  system's snapshots) — the update-system tests (T45–T49) start from it.
- r27-7 (T07) fonts — DECIDED 04:45 (the owner may veto): UI = JF Dot Shinonome 14 regular, repaired
  (public domain; 14 px, 7 px cells; 52 touching T pairs + 4 gutter-less kanji fixed in the build;
  fallback Fusion Pixel 12 proportional, OFL); terminal = UDEV Gothic NF 2.2.0, 16 px, cell 8x19,
  no ligatures (OFL). How: a research subagent (Sonnet) measured 33 families from official
  sources (.claude/notes/fonts-r27.md: licences + URLs + sha256, coverage, drawn sizes, touching
  pairs via fontTools; today's UI face: 45 % of L1 kanji touch — the "ugly / spacing" is
  measurable); the finalists rendered in the real bar/notices/foot beside today's (tools/kit.sh,
  font-try.sh; shots in .claude/notes/fonts-r27/). Build + re-grid: T10 (UI), T11 (terminal).
- r27-8 (T08) the Wada palette — DONE+applied 05:00 (live shots both themes): tools/wada-palette.py
  holds every colour as a Wada swatch (mattdesl/dictionary-of-colour-combinations, MIT) or an OKLab
  mix of two; build-themes.py reads P/KAMI/TILE/EDITOR from it (no literal left; its copies check
  green over 15 files — 129 literal copies remapped, 9 two-role colours resolved to their dark
  meaning); build-cursors + build-art re-run. Contrast: every text role ≥ 4.5 on every ground
  (wada-r27.md table; today's had accent_text 4.3 on key). Dark = 鬼 torchlit stone + Jasper Red;
  light = 天 Sulpher Yellow paper + Deep Slate Green ink + Brick Red + Yellow Ocher gold. New roles
  flame, gold (for the lock's torches, the sliders' red ramp, halos). Tests made palette-proof
  (look/test_screenshot, test_wallpaper read colors.sh); launcher fixtures list the new packages;
  PROJECT_TOP gains .claude + CLAUDE.md (static/test_generated 211/0 — fixed its old failure).
  dwl's border colours (config.h) take effect at the next session.
- r27-9 (T09) docs/design-system.md rewritten as the single truth — DONE 05:30 (verified: the new
  tests/static/test_design_doc.sh 10/10, and it fails on a wrong hex, an open "TBD", a wrong contrast
  — mutation-tested). Decided by sketching with the real faces + palette (mock: .claude/notes/
  design-r27/mock.py; shots pair-dark, mock-dark/light; Super+U today: superu-before.png):
  · ONE cell for everything: the terminal's 8 × 20 — GUI rows, terminal lines, the bar's paper are
    all 20 px; GUI and TUI share columns (heading icon at cell 0, name cell 3; rows: icon cell 1,
    name cell 4). So foot's line becomes 20 (T07 said 19): 16 px × 1.25, one rhythm; a full-height
    window 51 rows (today 43, 19 px would give 54).
  · bar 27 rows: 3 air, hairline, paper 4–23, hairline, shadow 25–26; capitals 9–18 (5 px of paper
    above and below); three 16 × 16 emblems (torii, workspace stamp 16 Ø with a 10 × 10 Black
    numeral, the demon/angel face); outer hairlines on x 8 / 1911 = the windows' edges.
  · ONE frame for all that floats (bar tiles, windows, panels, notices, tooltips): 1 px hairline,
    corners left out, the bar's own shadow (2 rows under, 1 column right) — no inner rule (his
    "second frame") anywhere; windows' focused hairline vermilion. 8 px between hairlines
    everywhere → the windows' tops on y 33.
  · headings: 12 px icon (accent_text) + name (strong) + a solid 1 px rule on the minus's row (no
    dashed rule anywhere — bug 17); air: GUI 8 px under / 20 above, TUI one blank line under / two
    above (bug 15: the heading belongs to its rows). No footers of the obvious (Enter/Esc: Super+/
    knows the app's keys); a screen's own key does get one (Super+W's rotate).
  · icons 12 × 12 beside words (1 px strokes — the regular face's weight; centred on the
    capitals), 14 alone, 16 the emblems; kanji in three places only (stamps, the day kanji, the
    lock's quote).
  · the meter (sliders): 20 segments of 6 × 10 px, 5 % each, partial levels by rows (every level its
    own pixels), reddening over 80 % (flame, then accent) — "alive, not a plain rectangle".
  · motion: dissolve (Bayer 4×4 in 3 px blocks — a flag in the private wlroots' GLES2 shader, T19),
    stamp, scroll; a timing table (windows 420/400, workspace 420, menus 200/160, warm windows
    300/240, lock → desktop 600, login → desktop 900, wash 1200, the cursor changing as the wash
    reaches it).
  · the lock's quotes, checked in dictionaries: 口は禍の門 (dark: the mouth is the gate of
    misfortune — the password typed into a demon's mouth; デジタル大辞泉, 精選版 日本国語大辞典 with
    十訓抄 1252: https://kotobank.jp/word/口は禍の門-489587) and 言わぬが花 (light: better left
    unsaid; デジタル大辞泉, 日本国語大辞典 "言ぬが花" 1729: https://kotobank.jp/word/言わぬが花-430611).
  Sections keep their numbers (≈30 comments in the scripts cite §1–§9; §5's motion moved to the new
  §11 — kawa-theme and theme.sh re-pointed; the lock's comments follow in T20). tools/wada-palette.py
  --doc prints §1's hex columns. The size checks join the test surface by surface (BUILT; plan T09
  amended). Kit: a `system` scene (Super+U headless).
  Also fixed on the way (the T08 fallout, all palette-proof now): test_quick (the namespace's UID 0
  vs the stub's), test_panel and test_books and test_fetch (colours read from the theme, not
  literals); notes.lua had a LATENT BUG — its pattern could not read C_EDGE2 (a digit), so the
  stitch was always a literal, and a literal-colour fallback for a missing theme (both gone: it
  reads the dark theme's own file, else says what is missing); VisiData's "working" was 2.9:1 in
  the light palette → 0 on 11 (12.1 / 5.2); tests/content/pty_run.py plays foot (TERM=foot when the
  run has none — the loop's TERM=dumb broke every curses program under test); python3-pyte added
  to the manifest for the self-tests (installed here with dnf at once; repair would do the same).
- r27-9b (T09 follow-up, 05:35) the test suite ran less than it said — found and fixed: `script`
  (util-linux-script) is not installed on this PC, so test_calc skipped itself "passing", six
  Super+U engine blocks counted `_ok` without running, test_glass and test_file's listing failed.
  One tool per job: tests/lib/pty_run.py (moved from tests/content: shared) gained --stdin (piped
  keys typed in) and --flush, and replaced `script` in all four places → test_calc 29/0 (was
  skipped), engine/test_menu 466/0 (six blocks now really run), test_glass 27/0, test_file 256/0
  (also: zstd's calls logged when the real one is here; ImageMagick 7.1.2 prints channels as
  "graya 2.0"). test_configs 332/0 (pyte). Still red, by design until T24 rebuilds the prompt:
  content/test_shell 15 and test_tiles 18 — bash 5.3's readline redraws the prompt line in place
  and PS1 carries OSC 133;A, so a prompt can mark twice (invisible to him; foot's prompt jump
  finds the same row) — T24 emits the mark once per prompt (PROMPT_COMMAND) and rewrites them.
  Known red elsewhere (from the root-run baseline, to re-check as dia in T53): session/
  test_autostart 5 (a <span line_height> the tests don't expect), test_game 4 (gaming leaves the
  host in T35), installer/test_hardware 1, look/test_wallpaper 1.
- r27-10a (T10, the face — 05:52, NOT applied live yet: the configs still say 16 px; apply only
  after T10c) Sumi UI rebuilt: Shinonome Gothic 14 regular (its ASCII, 88 Latin-1 letters, kana,
  kanji, full-width forms, half-width kana) + Latin Extended-A COMPOSED from its own letters and
  accents (the face's capitals a row shorter for a mark, as its own É: Dvořák, Łódź, Ţară, Ľubica
  read in its style) + 45 signs and punctuation drawn on its 7 × 14 grid (‘ ’ “ ” – — … • → ◆ ●
  ✓ ✗ ° ± × ÷ % € ▶ …; its own ° ± × ÷ are two cells wide, JIS) + T redrawn (its 7 px bar was
  the 52 touching pairs) + Cozette 1.30.0 (MIT, github.com/the-moonwitch/Cozette, sha256
  2d54a586…) for Greek, Cyrillic, Vietnamese and the rarer signs, on its baseline — Unifont (8 ×
  16) can no longer fill a 14 px face. Measured on the build: 0 ASCII pairs touching (with
  diagonals), 2340 one-cell glyphs all keep a column of air, every kana/kanji a gutter (only ／＼
  touch, drawn corner to corner); em rows = the design doc's (capitals 2–11, x 5–11, kanji 0–13,
  minus 7). 9414 characters. tools/build-fonts.py: `ui FACE COZETTE` / `term KAPPA UNIFONT`, a
  shared writer, and it now WRITES width.sh's air tables (they were hand-kept). The licence:
  Sumi UI under MIT (Cozette's; Shinonome public domain) — system/fonts/LICENSE. Specimen sheet
  checked at 2× in both moods (fixed after looking: ↑↓ cap-tall beside 5-row ←→, ‹› bigger than
  the face's « »). Kept: declared weight 700 (drawn regular) so fontconfig never synthesises bold.
- r27-10b (T10, the icons — 06:00, not applied live yet: with T10c) every icon drawn again BY HAND
  for Sumi UI 14 in its weight (1 px strokes), from a mechanical first pass (thin + 14→12) that was
  judged by eye and mostly redrawn: 12 × 12 beside words (middle on the capitals' middle), 14 × 14
  alone (the four layouts drawn as what dwl does: master+stack, overlap, monocle, fibonacci), 16 × 16
  emblems (the torii with 2 px pillars; the cats padded until T18's demon/angel), 18 × 12 the volume
  ladder (arcs centred on row 6) and the cassette (its reels + and × as they turn). Decided on
  sight: BRIGHTNESS is now a bulb gaining a pair of rays a level (the owner: the weather's sun and
  brightness looked the same — a ◐ was tried and dropped: it is theme's); every "off" is the thing
  with a small × at its top right (speaker, mic, bell, wifi) — slashes were unreadable at 12 px.
  Checked: every drawing renders pixel-exact from SumiIcons.ttf at 14 px (the six 64/128 px meter
  pieces only clipped by the check's canvas); sheet .claude/notes/design-r27/icons-r27.png, the
  drawings' source icons-new.py. tools/build-icons.py on the 14 px grid (1400 upm, middle 5 px,
  7 px cells, even sizes only); eq/lv/seg parts untouched (their surfaces: T14, T15).
- r27-10c (T10, the sizes — 06:20) every size that named the old face moved to Sumi UI 14: the bar
  (font-size 14px; the title's and the music's line held at 14 px: line_height 14336), mako 14px,
  kawa-panel COL 7 / LINE 14 (its grid otherwise the old one until T13), kawa-osd (Sumi Icons 14px;
  3 px of air after the name so its slider still starts where the panel's does), the lock and
  login (14 px, the clock 56 = ×4, the ◆ 28 = ×2; AM/PM still 6 px off the foot: 8 − 2), the
  saver's letters (glyphs.h at 14, its seal 24), the boot splash's pictures at 28, GRUB's fonts
  remade with grub2-mkfont 2.12 at 28/42/56 (sumi-32/48/64.pf2 gone; theme.sh FS = 14 × GS),
  kawa-books' card 28, MangoHud 28, the fontconfig note, the report's FONT checks (14/28). The
  bar's icon-alone tiles (torii, layout, Steam) a pixel more padding on the right: the new
  14/16 px drawings carry no air of their own (test_bargaps: 8 px paper to ink, both sides).
  Both C helpers compile with the new glyphs. Tests moved with it (and a few that were stale
  before: session/test_autostart's titles never expected the line-height span — 84/0 now,
  its 5 old failures gone); static, status, menus, look, session green but for the known:
  test_game 4 (T35), look/test_wallpaper 1 (old), content/test_shell+test_tiles (T24).
- r27-10d (T10 applied live — 06:15; verify 0 problems after repair, snapshot 257 before it) and a
  REAL BUG found by looking: after the apply the bar drew the wrong kanji (二 as 伜, 三 as 亡, 火 as
  燈) — the running waybar (and mako) shaped text with the NEW SumiUI.ttf's glyph numbers (Pango
  via HarfBuzz) while cairo drew from the face it had opened before. Any font change by apply,
  repair or update would have shown him that until his next login. Fixed: lib/common.sh
  session_fonts_reload — called by theme.sh when ~/.local/share/fonts changes and by upstream.sh's
  install_faces when the system faces change: waybar ended with KILL (autostart.sh's keep starts
  it again; a clean exit would end it), mako restarted as its unit; the terminals keep their face
  until the next login (their server's restart would close every window). Verified live: after
  the restart 一 二 三, 火 and the new torii/layout drawn right (screenshots /dev/shm/r27/live-bar2*).
  Known, unrelated, same before this change: installer/test_theme 6 (its sandbox as a user here:
  no /usr/local python site, flock fd 8, plymouth pictures) and installer/test_upstream (FK_PYLIBS
  unbound) — for T53's baseline.
- r27-11 (T11, the terminal's face — committed 06:30, applied 06:31) "Sumi Term" is now UDEV Gothic NF
  v2.2.0 (github.com/yuru7/udev-gothic; OFL 1.1 with "UDEV Gothic" a Reserved Font Name — so it is
  installed AS IT COMES and named by a fontconfig alias in system/60-fedokawaii-pixel.conf, never a
  renamed copy): lib/upstream.sh install_term_face fetches the release zip (sha256 45faeef7…) and
  installs only UDEVGothicNF-{Regular,Bold,Italic,BoldItalic}.ttf, each pinned by its own sha256
  (b11bbf18…, 63617ebf…, 13587ad9…, fff1d74b…) into /usr/local/share/fonts/fedokawaii — a face in
  place is known by its bytes, no tag to keep. Drawn smoothed in grey (foot's see-through ground:
  no colour fringes) with hintslight. ONE coding face: JetBrainsMono Nerd Font (the old fallback,
  GTK/Qt/mpv/zathura/Syncplay monospace) retired everywhere (configs, dconf, qt6ct, fonts.conf,
  mako; its home folder removed by the installer); the Kappa-based SumiTerm.ttf and its whole build
  path (Unifont fill-in, the term signs, bolding) removed from build-fonts.py — the UI build stays
  byte-identical (cmp). foot: pixelsize 16, line-height 20 (baseline 16 down, caps rows 4–15 — no
  vertical-letter-offset needed, measured), pad 8, zoom ±2 px (8/9/10 px cells), real Bold/Italic.
  Sumi Icons Term rebuilt on a 16 px em: the UI's 12 × 12 drawings pixel for pixel, centred in
  whole 8 px cells, raised 1 px (their middle on UDEV's capitals' middle). verify + the report's
  FONT-16/FONT-17 rewritten (the faces' bytes, the four pins, the Nerd Font gone; FONT-17 reads
  FACES_DIR from the toolkit so it can be tested); the installer's tests fake the zip (four
  stand-ins, pinned) — test_upstream up to Syncplay 114/0, test_report_rows 268/0 (and evidence
  rows for libasan and python3-pyte that PKG-19 asked for), static green, ShellCheck clean on every
  touched file (a few old warnings fixed on the way).
- r27-12 (T12, Super+U — committed 08:22, applied 08:20) Super+U rebuilt as five tabs: system · update ·
  snapshots · backups · learning (system/fedokawaii: SECTIONS, rows SECTION, tabs, tab_at). The tab
  bar is fzf's header, three lines: the tabs, the line under the one shown, a row of paper — at a
  heading's column, one cell out from the rows (design-system §3 indent; a first try put it on the
  rows' column and was taken back for that rule). The tab shown: icon in the accent's ink, name
  strong, ▔ in the accent under the NAME ALONE (measured x 50–97 = the ink of "system": both ends
  flush; under icon + name it overhung the icon's ink by 2 px on the left only); the others their
  icon alone, muted; every icon two columns, every gap three → 26/28/28/28 px of air (px.py gaps;
  before: 26/20/20/20). Tab/Shift+Tab/→/←/l/h and a click change it (click-header: fzf counts the
  column from 1 at the header's first column — measured in a pty with the menu's own fzf.opts and a
  real SGR click: screen column 3 → 1). The list: each section's rows; what is not built yet faint
  with "soon" (held, a file back, restore, the drive, chess, typing, to-do) and "not yet" in the
  pane; the pane: its heading level with the tabs (row 1), its first line level with the list's
  first row (row 4: y 90 in both columns, px.py), every line ≤ 49 columns.
  Window 100×18 (was 22; tools/kit.sh had 27): fzf's margins give the pane 16 rows, 13 status lines
  under the heading; when the rare lines all come at once the routine ones make way — the kernel
  unless a restart waits for it, the disk unless low, the release, its support — never one asking
  for you (pick ROOM; tested at the fullest: 14 lines → the release made way).
  Found while grilling, fixed: a note about the past no longer true stays away (cleared_since: a
  clean verify after a run answers "verify found problems: repair" under updated, and the dnf
  guard's "left something" — the live status showed the first next to "257 checks passed · today");
  retired packages cut with "…" (the owner's rule) → whole names, then "+N"; "1 config file(s)" →
  singular/plural; the next Fedora's "check" → "may be out" (status's own words); change, keys, log,
  lessons showed a bare heading → one line each saying what they open.
  Inherited red tests (red at f22b66a too), fixed: diffutils 3.12 shell-quotes names with spaces in
  `diff -rq` ("Files 'a b' and … differ" — /usr/share/doc/diffutils/NEWS, 3.12) and apply + the
  engine parsed those messages, missing such files → lib/common.sh tree_changes (both trees' BLAKE2
  sums, "STATE<TAB>NAME", exact for any name but one with a newline; run as the desktop user by
  apply), used by apply, the engine's ShellCheck pass and kawa-config's "N not applied" (all three
  count alike now). test_pull's git stand-in counted local calls (status, rev-parse) as could-prompt
  (it passed in the old sandbox only because that set GIT_TERMINAL_PROMPT globally) → it watches the
  network calls: all fgit, no helper, never a prompt. test_torrra assumed sh is not bash (Fedora's
  sh IS bash, BASH_VERSION set) → unsets BASH_VERSION to stand for another shell. Two more seen
  red in one area run (test_torrra "HUP: exit 0", test_term_float "hung up", leaving two orphans
  that held run.sh's pipe for 17 min) were MY run's doing: started under nohup, so SIGHUP was
  ignored in every descendant and bash cannot trap a signal it starts with ignored — reproduced
  under nohup, green 4/4 without it even with every core busy (memory note: tests never under
  nohup). Still, test_torrra's case signalled `$(ps -o ppid= -p $PPID)`, which — kawa-torrra no
  longer waiting for Prowlarr — could after reparenting be the user's systemd manager (HUP =
  daemon-reload, INT = as TERM: exit.target, the whole session's services — man 1 systemd; the
  journal shows it never happened) → now as a terminal does it: kawa-torrra in a process group of
  its own (real setsid), the signal to that group only, the fake torrra held open (fixture
  FAKE_HOLD); 3 runs green. test_bar's `pkill -f "sleep 31.5"` → the exact pid; ShellCheck
  warnings in test_pull/test_torrra/test_bar cleaned.
  Live: the warm Super+U window kept the size it was started with (100×27 since 06:33) until a
  login → kawa-warm --renew clip|system (closes one put away — its loop, then its run's process
  group — and opens it again put away, footclient --no-wait; one showing is left; never the
  notes: they hold your page), called by theme.sh's live part: after this apply the live window
  measures 18 × 100 (stty on its pty), the clipboard's 27 × 80, the notes untouched (same pid).
  tools/kit.sh: Super+U's size read from the installed kawa-warm; scenes system:N (the Nth tab).
  Verified: test_menu 555/0 · test_status 183/0 · test_copy 77/0 · test_front 118/0 · test_pull
  62/0 · test_torrra 191/0 ×3 · test_config 102/0 · test_warm 77/0 · test_bar 241/0 · test_syntax
  680/0 · areas engine, static, menus, session green but test_game (4, the known gaming ones → T35/
  T38); applied live 08:20 (repair: 0 problems after); kit shots of all five tabs in both themes, measured (px.py runs/gaps/zoom).
  Docs: design-system §7 "Tabs" (the grammar, for every screen of several sections); Learn chapter
  8 as rewritten (tabs, the entries table) still true. Deferred, noted in the plan: the running
  row's turning hourglass → T19; Super+U's key sheet → T23; "(BACKUP_TARGET)" out of the words → T48.
- r27-13a (T13, the menus' bugs 3, 7, 8 — committed 08:51; live after the session restart) Found, not
  guessed: tools/kit.sh gained plays (tools/kit-play.sh: the pointer through wlrctl — wlroots'
  virtual pointer, Fedora's wlrctl 0.2.2, added to the manifest for the self-tests — the keys
  through wtype, shots by name), --bin (the repo's scripts before an apply), --time, and dwl itself
  now runs in the kit's home and PATH (before, a key's program started by dwl had the real HOME —
  checked: nothing of ours was written there).
  Bug 3 ("highlighted options not active until I click the menu once"): a menu opened by its KEY
  under a resting pointer never got the pointer — dwl refreshes pointer focus only when a layer
  surface changes the usable area (a menu changes none), so the row under it stayed dark and every
  click went to what was there before, until the hand moved (reproduced: two clicks on "next", the
  month unchanged). Opened by a click it worked, which is why r25-3 looked fixed. → dwl: a layer
  surface's commit asks for a pointer re-check once the commit is done (pointerlater: an idle
  callback — at once it found nothing: the scene takes the buffer after dwl's listener), and a
  button's release re-checks it (a menu that opened while the button was down). Now: the row
  under the pointer lit at open, the first click pages (Oct → Nov → Dec, shots).
  Bug 8 (two popups at once): reproduced in 4 of 4 pairs (calendar + Super+U either way, Super+X +
  Super+V either way): dwl closed popups only for a click on the bar, and focusclient never took
  the keyboard from an overlay menu. → a popup raised (lift: its key, a new one, a click — never
  the pointer passing) drops a menu first; a kawa-panel surface taking the keyboard closes every
  popup (only the panel's namespace: the lock never closes a book). Proven: every ordered pair of
  ten (Super+C U N V X A W R / Space) — 90 shots, each one popup, always the second, at its own
  place (a 4×-pooled, dilated count, nested boxes merged).
  Bug 7 (Super+C on the right): kawa-menu --drop --middle (the calendar, the timer): the top alone
  anchored, layer-shell centres it on the output (the clicked one, or dwl's) — by key, a click on
  the date or on the time: the frame centred at x 959.5, the bar's middle group (854–1065) at 959.5.
  Tests: tests/session/test_popups.sh (new, 15: the patch read); test_panel 408/0 (+middle place
  and request), test_menu 84/0, test_calendar 85/0, test_timer 79/0; static green. design-system §6
  "where it opens" names the date's dropdowns. The headless regression checks (tools/regress, T52)
  come with the redesign's final geometry.
- r27-13b (T13, the redesign — committed with this line; applied live after) Every panel and menu on
  the design's 8 × 20 grid (docs/design-system.md §3–§4; test_design_doc's new `menus` check reads
  the doc's §3 table back against kawa-panel's numbers): a 1 px hairline frame with its corners
  left out and the bar's shadow (two rows under, a column right; KAMI's inks via panel.conf
  hair/shadow1/shadow2), 16 px of pad, headings an icon + name + a solid rule (no kanji heading
  left in any menu: grep in the same check), rows on cells 1/4, keys one row high, no dashed rule.
  Quick settings 410 × 498 (+1/+2 of shadow; was 412 × 554): two meters of 20 segments (6 × 10, a
  cell each, 5 % a segment, the next lit partly from the bottom) — asagi, the 17th–18th flame, the
  19th–20th accent, read back segment by segment from headless shots (tools/kit.sh play, a
  stand-in kawa-quick giving the levels) at 42/50/85/100 % in both themes: 50 → 10 asagi; 85 →
  16 + 1 flame; 100 → 16 + 2 flame + 2 accent; 42 → 8 + the 9th's bottom 4 rows. (In light, T08's
  palette makes flame and accent one Brick Red a84222: the light meter reddens in one step —
  kept, the doc's table says so.) Twelve tiles 120 × 80, each its own pixel picture instead of a
  kanji seal (16 drawings over every state: moon/sun, lantern, wave, wired/Wi-Fi/offline,
  bluetooth, headphones, drive, the backup box, bell/quiet bell, saver, record, read); one light:
  the pointer moves the cursor. Notices 410 wide (mako) so the two stay one column.
  Do not disturb (owner's bar item): the bar's quiet bell opens its own dropdown — kawa-quick dnd:
  off · for an hour · until the morning (8:00) · on, the one in force marked; a timed one ends by
  a transient systemd --user timer (kawa-dnd-end, AccuracySec 1 s); if that timer cannot be set
  it does not go quiet at all and says so (a quiet that never ends would hide every notice). The
  mode tile is lit by that dropdown (DROP_POKE kawa-quick → +12) — no longer by quick settings:
  kawa-dwlstatus's "+15 brings +12" and the panel's extra +12 removed (this pass; their tests
  turned round). The tile's 静 / 共有 → the quiet bell / the monitor, tooltip "do not disturb
  until 11:18" while timed. Found, fixed: kawa-help drew nothing after the icon change (its map
  read icons.sh only on its error path). Static checks: ICON_W/ICON_X (read by test_generated as
  undefined $ICON_ names) → GLYPH_COL/GLYPH_X; test_design_doc's import wrote bin/__pycache__ into
  the tests' copy (python -I ignores PYTHONDONTWRITEBYTECODE) and test_syntax took it for a script
  → sys.dont_write_bytecode.
  Shots (headless, tools/kit.sh --bin --repo-art): quick settings and the DND dropdown, both
  themes — frame + shadow 411 × 500 at x 1502 y 39, the first tile at +17/+101 (px.py boxes).
  Regression checks (T13a): tools/regress/menu-first-click.sh, calendar-middle.sh, one-popup.sh.
  Learn: the bar table, §5.3 and exercise 5.2 speak of the bell. Deferred, noted in the plan:
  the bell's lit tile and the recording dot → T14; the OSD's segments and 410 → T15; the
  launcher's and the TUIs' remaining kanji → T16.
  Also fixed with it: tests that T13b's headings broke (test_drives 123/0, test_record 62/0 — the
  record menu's heading now a 12 px camera, quick settings' own picture, not the cassette —,
  test_weather 170/0, test_downloads 40/0, test_launcher 264/0: apps at their native 16 px, the
  kanji until T16 without a box; wlrctl named in not-launched.txt), test_osd 153/0 (it imported
  the panel's old slider functions: now the OSD's own rule, until T15 rebuilds the level display
  as a surface of the panel's on its twenty segments). Test hygiene: every gated stand-in (a stub
  waiting for a gate file: test_pack's curl, test_theme's gs, test_screenshot's slurp, test_lock,
  test_shrink/test_clip's fzf, test_term_float's inside, look/lib.sh's wait_gate) now ends when
  its test's folder is gone — test_pack's curl stub had polled as an orphan for 4–6 h (three
  found, one of them root's from the 04:25 selftest under sudo); root-owned leftovers of that
  selftest removed from /tmp (the installer tests' lock file among them: unwritable from the
  tests' user namespace, so installer tests ran unlocked; also five hotplug.* dirs of T01's).
  Full suite (10:15, 122 files): red but for the fixed ones — all failing on clean HEAD d8e411d
  too (a worktree run): content/test_shell 15 + test_tiles 18 (readline redraws the whole prompt
  line, its OSC 133;A mark with it, on input and on Enter — pty_run.py types the next line at
  the redraw's mark: → T24, the prompt rebuilt, the tests' typing waits for quiet), look/
  test_wallpaper 12 (the Super+W TUI's rows and heading changed under it: → T16), session/
  test_game 4 (→ T35), installer (run again alone, the lock fixed): test_theme_parts 37 +
  test_theme 9 + test_torture/test_verify/test_upkeep/test_report/test_afterdnf/test_setup/
  test_hardware (the fake machine's /usr/share is a read-only farm of links to this machine's:
  theme.sh writing /usr/share/plymouth/themes/sumi — a folder the live PC now has — hits EROFS
  and the boot part's checks fall after it; verify's UDEV Gothic pin check in a world without
  the four faces; hw_firmware_pkgs reads this machine's firmware) → T53, where the world gets
  its own writable copies of what the installer writes. The live installer is unaffected
  (apply 08:52, verify 257/257).
- r27-13c (T13, live check of the timed quiet — 11:00–11:05, two fixes committed and applied) Fired
  the real transient unit instead of trusting the stubs: (1) it ran kawa-quick from the user
  manager, whose PATH (systemctl --user show-environment: /usr/local/bin:/usr/bin) has no
  ~/.local/bin — makoctl ended the quiet but kawa-state/kawa-dwlstatus were "not found" (exit
  127): the bell would have stayed on the bar → systemd-run --setenv=PATH="$PATH"; (2) the end's
  first step stopped kawa-dnd-end.service — the very service it ran in — so it was killed before
  makoctl and the quiet would never have ended → the timer runs "dnd end": only the timer
  stopped, then off as usual; --collect so a failed unit never keeps the name. Verified live:
  "for an hour" → do-not-disturb mode, the unit's Environment PATH=/home/dia/.local/bin:…, the
  bell with "until 12:03"; `systemctl --user start kawa-dnd-end.service` (the timer's own end, now)
  → mode default, the bell gone, timer and unit gone, the record file gone; off/on by hand as
  before. test_quick 361/0. Seen on the way (→ T14): the mode tile uses ICON_BAR_BELL_OFF, the
  icon-before-a-value form with 8 px of trailing air — an icon alone needs the 14 px "alone" form.
- r27-14a (T14, the bar's geometry — committed with this line; live after T14's apply and session
  restart) 27 rows, every tile §4's frame and nothing inside it: build-themes.py draws kami-tile,
  kami-red (+ kami-red-lit: a vermilion tile under the pointer or open — accent_hi, its own
  picture since the paper's first column is in the slice), the 16 px seal, the scroll (rods
  4 px, gold-capped, a row proud of the hairlines), all sliced 4 2 3 2 (the scroll 4 4 3 6) so
  the stretched edges are the same in every column; the lock keeps its old scroll (lock_scroll)
  until T20. waybar: height 27, margin-bottom -2 — its exclusive zone is gtk-layer-shell's auto
  zone, the height plus the unanchored edge's margin (waybar 0.15.0 src/bar.cpp setMode →
  gtk_layer_auto_exclusive_zone_enable; gtk-layer-shell v0.10.0 layer-surface.c) — so it ends
  on the lower hairline and the shadow lies in the windows' gap; dwl outergappx 5 → 8: the
  windows' tops on y 33, their edges on x 8 / 1911 = the outer tiles' hairlines (measured
  headless: a tiled foot's border rows 33–34, columns 8–9 and 1910–1911, bottom 1070–1071).
  Workspaces: the numerals 一–九 drawn 10 × 10 (art/icons.txt ws-1…9, no air), the stamp a 16 px
  seal laid at 4 2 of the tile's padding box: rows 6–21 round the numeral's 9–18, 5 px of paper
  either side (the old narrow seal for 四 七 九 gone). The layout's mark and the window's name one
  tile (group/focused; "alone" when there is no window). The clock: DD∕MM∕YYYY, its slashes a
  new sign in Sumi UI (∕ U+2215: a clean 2 : 1 stair on the figures' ten rows — the face's "/"
  runs 13 rows in uneven steps), red by a span from colors.sh; 14 px date→kanji→time (月, 日 and
  10–12 o'clock's leading 1 carry classes for their own air), the date's side 7 px wider (the
  time is), so the kanji's ink stands on the screen's middle (x 953–965, centre 959). US in
  accent_text, AR in blue; a click switches: kawa-tag kb next → dwl's fifo "kb next" → kbnext()
  sets the next layout on one keyboard of the group, which wlroots gives to every other one and
  to the group (wlroots 0.20.2 types/wlr_keyboard_group.c handle_keyboard_modifiers, read in the
  Fedora source rpm); a virtual keyboard could not (a layout of its own). Steam's tile, light,
  poke and signal gone from the bar (kawa-steam itself: T35).
  Measured (tools/regress/bar-geometry.sh, new: headless, both themes): rows 0+3 3+1 4+20 24+1
  25+1 26+1; hairlines on x 8 and 1911; gaps 4 within a group, 12 between; 8 px paper→ink both
  sides in every tile (torii 17–32 on 9–40; the cat; 二 三 at 8/8; the layout's mark 8/8 on
  rows 7–20; words on 9–18); the seal x 60–75 rows 6–21 round 一 at 63–72; the clock 15·14·14·8
  (9 from 10 to 12 o'clock — the box keeps its width so the kanji never moves). It fails on the
  installed (old) bar: rows 0+2 2+1 3+24, x 5, 1915. ASan headless run of the new dwl: no error.
  Tests: test_bargaps rewritten for 27 rows (5/0), test_bar 252/0, test_dwlstatus 171/0, test_tag
  78/0 (+ kb next), test_timer 79/0, test_design_doc 35/0 (bar in BUILT), test_panel 481/0.
- r27-14b (T14, the bar's moving and owner items — committed with this line; applied 11:36, the
  session restarted onto the new dwl at 11:37 via greetd's initial_session, no password; nothing
  unsaved: the notes' nvim had 0 changed buffers) The mode tile an icon alone with no air of its
  own (it carried ICON_BAR_*'s 8 px for a value it never has): the quiet bell is quick settings'
  14 px picture (tile-bell-off), sharing a new 14 px monitor (share). Recording: 録 → the red dot,
  whole on even seconds and its ring on odd ones (kawa-record is poked each second: no process
  for it), 停 → the pause mark; the countdown beside the dot. What plays: a television with its
  antenna for a video (tv-0…3, 6 a second: every 10 of cava's 60 frames while it sounds) or the
  cassette (5 a second), still at its first frame while paused (no pause sign), the title, a red
  rule (np-rule: 1 × 10 on the capitals, 8 px either side), the artist or channel faint. Video or
  sound: Brave's MPRIS has no address and its picture is a PNG of its own (Chromium's
  system_media_controls_linux.cc sets title, artist, album, length, trackid and artUrl = a
  file:// temp PNG — read 27 Oct), so the picture's shape decides: wider than 5 : 4 a video, a
  square sleeve sound; mpv by its file's name; no picture: sound (one od per track, never per
  frame). The wings in our red: 10 heights 1–10 px on the capitals' rows (eq-0…9, 2 px wide, 4
  apart; cava ascii_max_range 9), inked from accent_lo to accent (colors.sh C_WING, built by
  build-themes). Downloads: the arrow dropping into its tray (dl-0…5, frame 0 = the old icon),
  kawa-downloads bar --follow long-running — 8 frames a second while anything downloads (line
  times: 125.0 ms apart, measured), the files looked at every 2 s, hidden and asleep on its
  wake fifo when idle (state S, no line), woken by kawa-dwlstatus (the watcher's poke, a menu's
  wake), lit by its menu's marker. Weather's sun and brightness' bulb were already two pictures
  (the owner's item holds: checked in the live shot, 33° under the sun, 0 % beside the bulb).
  The active title's "lighter weight": Sumi UI is one weight of 1 px strokes (T10) — nothing
  heavier left to lighten (checked in the shots).
  Measured: headless (tools/kit.sh play) the arrow's six frames in order 0→5→0 in 24 shots;
  the wings fed through their fifos: rod→wing 15, wing→date 14, date→kanji 14, kanji→time 14,
  time→wing 15 at 11 o'clock (its 1's air: the designed hour case), wing→rod 8, the kanji still
  on x 953–965; live after the restart: a tiled foot's border on rows 33–34, columns 8–9 and
  1910–1911, bottom 1070–1071 — the bar's outer hairlines and the windows' 8 px; the critical
  notice's frame x 1502–1911 from y 33; kawa-tag kb next → AR (blue), again → US (kb.json).
  Tests: test_record 62/0, test_downloads 52/0 (+ follow: frames, 2 s looks, idle sleep, wake,
  lit, its fifo gone with it), test_bar 252/0, test_bargaps 5/0 (wings' air), test_nowplaying
  (rewritten for the label, the picture's kind, the 10 red heights — by a subagent, checked).
  Steam's tile went with the bar's Steam items, but its watch also ran game mode for Steam's
  games (kawa-game start/end): kept, as kawa-steam --watch from autostart (keep: restarted if
  it dies), printing nothing, its wait a fifo of its own — so gaming on this PC is no worse
  until T35 moves it into its VM; --bar, --bar-watch, ingame() gone; the health report's RES-03
  (kawa-downloads bar --follow is a long-running child of waybar now), BAR-11 (a vermilion
  tile's lit picture), BAR-25, PERF-08 follow. The subagent's review of kawa-nowplaying found
  three real faults, fixed: a new track was told by player + title + picture (an mpv song, then
  a video of the same name, kept the cassette) → its address counts; any file's bytes 16–23 were
  read as a size (a wide WebP gave the cassette or the television at random) → only a PNG's
  (signature, IHDR); the picture's frame carried over between tracks → from frame 0. test_steam
  61/0, test_report_rows 268/0, test_nowplaying 204/0, test_configs 65/0 (cava 0–9), test_clicks
  37/0 (+ the keyboard tile's click, read from a stand-in fifo), test_dwl_anim 28/0 (outergappx 8).
  Seen, for T38: the bar's brightness reads 0 % in every shot today — the LG's own setting or a
  DDC read to check.
- r27-15a (T15, the windows' frame — committed with this line; live with the next session restart)
  The doc's frame, not the plan's older band (§4, §12): borderpx 2 → 1, dwl's 8 rects → 7 — the
  hairline's four sides with their corner pixels left out, and the shadow outside the window in
  the gap (the first row from a pixel in to under the right hairline, the second a pixel further
  right, the column from the hairline's second row down to the bottom hairline's row), clipped
  with the window while it slides (its own cut: it lies outside the window's box) and faded with
  it; dwl.colors now RRGGBBAA — focus, border (the tiles' hairline ink: dark text at 50 %, light
  strong at 84 %), urgent, shadow1, shadow2 (KAMI's) — kept premultiplied (the scene's
  colours are). Measured headless (two tiled foots, both themes): hairlines on x 8, 1181 | 1190,
  1911, 8 px between the windows' hairlines with the shadow column in them, the bottom-right
  corner map hairline/cut/column/row1/row2 exactly kawa-panel's frame; tools/regress/
  window-frame.sh (new) holds on the new dwl and fails on the installed one (2 px solid border).
  Lost once and redone: an apply at 11:57 put the repo's patch back over the uncommitted tree
  (CLAUDE.md says so) — the tree's diff is now saved to /dev/shm before any apply.
- r27-15b (T15, the notices — committed with this line; applied 12:14, live at once) Fedora's mako
  1.11 strokes a notice's frame as a path (no corner pixels left out, no shadow), puts "…" where
  text does not fit (pango ELLIPSIZE_END — the owner's never-"…" rule) and escapes the whole
  title (no ink of its own for its icon): read in its source at the pinned tag (render.c,
  config.c, notification.c). So the desktop builds its own: src/mako/mako.patch (132 lines, three
  options, each off until set) — shadow-color (§4's frame: the corners left out, the shadow's
  two rows and column drawn into the margin, the surface two rows taller for the last one),
  summary-icon-color (a title's leading pixel icon, U+FE000–FEFFF, in its own ink, its words 8 px
  on: of the two spaces after it, one), hanging-indent (the summary and body one paragraph — line
  breaks become U+2028 —, a negative Pango indent: every line under the title's words; no "…":
  whole lines, the rest clipped; height 174 = 2 + 32 + 7 × 20). Built like the file dialog:
  fedokawaii.conf MAKO_TAG v1.11.0 / MAKO_COMMIT 91c6b799… (git ls-remote: the annotated tag
  274aa303… → that commit; the release tarball's sha256 e97eb5bd… equals Fedora's mako-1.11.0-1
  source rpm's), setup.sh build_mako (as the user in ~/.local/src/mako, the tag checked against
  the pin, the patch applied, meson -Dwerror=false -Dman-pages=disabled, the binary seen to run
  and to carry the options, then root installs /usr/local/bin/mako + a drop-in for Fedora's
  mako.service — which D-Bus starts too — and records what it was built from), step 3.07b2, the
  repair heal r_mako, the guard's built_files and the release pre-flight's libs_ready, verify's
  two checks, cairo/pango/gdk-pixbuf2-devel in PKG_BUILD (evidence rows). Fedora's package stays
  (its unit, D-Bus name, makoctl); no fallback to it — its config needs ours (the owner's rule).
  Notices: a 1 px hairline in the tiles' ink (critical: vermilion), 20 px rows, the icon in
  accent_text, the body under the title's words. Measured headless (kit play, both themes) and
  live: right hairline x 1911, top y 33, left 1502 (410 wide); the corner maps (top-left cut,
  bottom-right hairline/cut/column/row1/row2) as kawa-panel's frame; a long body: the 7 rows
  kept, no "…". The level display keeps its old 2 px look in its own section until it becomes a
  surface of the panel's (T15c). Tests: test_syntax (the desktop's mako reads its config in both
  themes; skipped where it is not built), test_osd, test_report_rows (PKG-19: evidence),
  test_notices, test_conf, test_theme, test_generated, test_deps green; the installer tests'
  fake machine has a built mako.
- r27-15c (T15, the level display — committed with this line) No longer a mako notice: a window of
  kawa-panel's own (its fifo: "level ICON PCT [off]"; kawa-osd is now a 25-line client writing
  one line, no process on the panel's side, exit 1 with no panel), low in the middle (its frame's
  foot 72 px above the screen's), the overlay layer (over a fullscreen window; and not a notice,
  so do-not-disturb and sharing never hide it), its own namespace "kawa-level" (dwl's one-menu
  rule only knows "kawa-panel": a key pressed while quick settings is open leaves it open),
  keyboard NONE, an empty input region (a click goes through it). §9: one row on the grid — the
  icon in its 16 px column (accent_text; brightness's bulb of its fifth, no more 明), the panel's
  own segments() from cell 3 (to the pixel: the ramp, hollow while off), the value right-aligned
  at 28 cells (muted, "off" faint), 258 × 54 with the frame and shadow, solid surface
  (panel.conf gains it). Drawn anew as each key comes, gone 1.2 s after the last (a GLib
  timeout reset per key); kawa-level.shown while it shows (the report's UI-06 times that now,
  not makoctl). Shots (kit play, both themes): 45 / 92 (16 asagi, 2 flame, the 19th part-lit) /
  60 off (hollow) / the bulb at 70; gone 1.6 s later. mako's osd sections removed (and kawa-osd
  from build-themes' COPIES: no colour in it now). Hardened after a review (a subagent's, checked
  here): the line is written by dd with O_NONBLOCK and nocreat — a stale fifo with no panel
  reading it is refused at once (1, not a silent 0), a hung panel's full pipe drops the line (1)
  instead of leaving the volume/brightness key stuck holding its lock, and a fifo gone between
  the check and the open never becomes a plain file; one whole line, one write (fullblock, under
  PIPE_BUF). tools/regress/level-display.sh (new): 258 × 54, centred, foot 72, 47 % = nine
  segments and the tenth's 4 rows, gone in time — held, both themes. Tests: test_osd 277/0
  (stale fifo, full pipe new), test_volume 112/0, test_brightness 151/0. Found on the way: two
  session tests left a process holding run.sh's pipe (test_clicks' dwl-fifo reader, forever —
  the area run hung 23 min; test_push's sleep 300): both now go with the test (H_CLEANUP).
- r27-15d (T15, tooltips) The bar's tooltips in the frame: kami-tip.png (build-themes: the hairline,
  its corners left out, the shadow; sliced 2 2 3 2 so the right edge it stretches is even) on
  solid surface, one row with 8 px of pad. GTK 3's tooltip window keeps a border of its own
  round its box (not CSS: no rule removes it — measured 5 px at three sides, 4 at the foot), so
  the label is padded by what is left: measured both themes — frame 38 rows (1 + 8 + 20 + 8 +
  1), 8 px of paper to the words either side, the capitals 14 rows from each hairline. Found on
  the way: one property GTK 3 does not know (border-spacing) made waybar drop the whole sheet —
  the bar vanished; test_syntax now parses style.css with GTK itself in both themes (caught it:
  2 failures with it, none without). Super+/ looked at: the text-screen grammar already, in the
  new window frame; its content and context are T23's.
- r27-16 (T16, the text screens to one grammar — committed with this line) No dashed rule left
  (╌ → ─: the shell's part headings, the notes' winbar, nvim's start screen, yazi, torrents;
  grep-tested). Kanji only where §13 has them (stamps, the bar's day, the lock's quote): the text
  screens' headings now their pixel icon (drive, calculator, branch, clipboard, book, together,
  file, picture; the PDF tools' pages/order/take-out), the launcher's entries (X-Fedokawaii-Kanji
  → X-Fedokawaii-Icon, 22 names; nine icons drawn — calculator, two people, a gauge, a robot, a
  magnifier, a wrench, a note, a speech bubble, a globe; an entry with none: the window icon; the
  answer's row: the calculator), the notes' winbar (note), nvim's start screen (code), yazi's
  locked PDF (lock), torrents' banner (download), the shell's Ctrl+T / Alt+C / Ctrl+R headings
  (file, folder, hourglass — read from icons.sh as drawn), the snapshot-boot notice (camera:
  Super+U's snapshots), the mic test's words ("under input"), the panel's warm-up; INK_KANJI →
  INK_ACCENT_TEXT, KawaKanji → KawaIcon; test_notices allows no kanji any more. Report BAR-14
  still measured "Mon 19 Oct" and 一…九: now DD∕MM∕YYYY (70 px each) and the stamp icons (10 px).
  §7's last line (screen_footer → screen_keys): only a screen's own keys — key in text, what it
  does muted, its state strong; never Enter/Esc/arrows (Super+/ has them): clipboard super+z,
  ctrl+d, ctrl+x · books ctrl+a, ctrl+d (adding: tab) · git c, n · calculator ctrl+q · the rest
  none (backup, together, git's list, file contents); fzf.opts' footer ink -1 (fzf maps a reset in
  the footer to the footer's own ink — measured in a pty). Super+W (owner: "a toggle key inside
  Super+W, shown at the bottom"): the switch left the list — r (or a click on its line) turns
  "change every 4 h", its state on the last line, no input line (the letter is the key's); shots
  both themes, r toggled in place. Columns: the clipboard's and books' rows stood a column
  further in than §7 (two spaces) — one now, as screen_row; fzf's prompt chevron moved to the
  rows' icon column and the typed text to their names' (measured: chevron cell x = row icon
  cell x, text x = name x, both themes). Books (bug 16): §7's columns, the reading meter in
  pixels (icons read / read-off, 6 × 10 on the 8 px pitch: done solid accent_text, muted once the
  book is done; to do hollow edge2 — the cursor's row strips inks, the shapes still say it; no
  meter for a book not begun; before: ━/─ lines), the caption under the cover up to three lines
  (a long title lost its end at two). Calculator: its line typed as a search line, the answer's
  = an icon in the chevron's own box (measured: both inks x 1229–1233, middles one row apart),
  "copy" ending at the last column, kept lines at the names' column. Clipboard exit (bug 6,
  "terminated"): Esc or Enter wiped fzf's page before the warm loop told dwl, so dwl's ghost was
  a blank terminal with a cursor (shot 30 ms after Esc); now the window is put away first
  (kawa-warm --away NAME: "hide NAME" to dwl's fifo, read-write — never a wait, never a plain
  file; KAWA_WARM tells the run it is warm) and then fzf ends — the ghost is the page as it was
  (shots: Esc and Enter, both themes); Super+U the same (Esc, q, a job's become). The loop's job
  control printed "Terminated" for a run killed by SIGTERM (reproduced in a pty): the popup now
  ends on TERM by itself, as the clipboard did (a stderr redirect would have taken bash's
  terminal for job control — tried: the window never showed). tools/regress/warm-exit.sh (new):
  holds on this build, fails on the installed one (Enter: 116 of 4356 ink points left). Launcher
  sums (bug 6, flicker): each key dropped the answer row until qalc answered the new text, then
  put it back — the list jumped twice a key; now the last answer stays in place while the new one
  is worked out (pending), changes where it stands, and goes at once when the text is no sum
  (shots: 36 → 408 in place). kit.sh --repo-art also takes screen.sh and fzf.opts. Foot, Foot
  Client, Foot Server: one entry already (NoDisplay). Shots both themes: Super+W (empty, five
  pictures), books (six books, cursor on done/new), clipboard (open, both exits), calculator and
  git (full tile and half tiles), Super+U. Tests: content/look/menus/engine/session/static/yazi/
  status — the new cases: test_warm (--away, KAWA_WARM), test_clip (the binds), test_menu (the
  popup's), test_calc (in place, the line typed), test_books (meter, columns, three lines),
  test_wallpaper (the key line), test_launcher (icons by name, every one in the font).
- r27-17 (T17, the side-by-side audit — committed with this line) tools/gallery.sh (new): every
  surface opened as a person opens it, in a headless dwl on the real GPU, both themes — 27 of
  them, dark | light sheets and an index; --record writes each surface's box to
  tools/regress/gallery-expect.json, --check holds a later build to it (held twice in a row).
  Measured: every surface the same box in both themes (27/27), dropdowns from y 33, the right
  ones ending at x 1913. Fixed: Super+/'s field bare like the launcher's (its "> " gone);
  Super+U, the backup pane and the drive picker no longer show a setting's name
  ("BACKUP_TARGET" → "no drive · quick settings → backup"); the kit paints each theme's own
  ground (light surfaces were shot on sumi, their hairline lost) and links nvim's data (read
  only: nothing written — checked), shots.py reads the ground from each shot; the regress set
  re-run on it — bar-geometry, window-frame, level-display, warm-exit, menu-first-click,
  one-popup held; calendar-middle failed by half a pixel: parity (the clock's scroll is odd —
  its kanji's 13 px with equal sides — the calendar even), no layout makes both exact without a
  1 px asymmetry elsewhere: the check holds them within half a pixel now. The yazi picker's
  own-keys line and heading column went with r27-16's commit. Seen and owned by later tasks:
  notes (T21), yazi's view (T22), the prompt (T24), quick settings (T17b), lock/greeter/saver
  (T20). The list: .claude/notes/grill-r27.md ("nothing left for T17").
- r27-17-owner (owner, 2026-10-27 14:27 and 14:29, written into CLAUDE.md: "fold into the plan")
  — folded, not done yet: the bar's UI font kept unless research and renders show something
  clearly better (T17b's note, T58 checks once) · "clean mic" removed completely · a button to
  switch the monitor off (quick settings) · quick settings made a menu he loves · US/AR in
  capitals while Caps Lock is on, lowercase when off, live — all T17b · copy/paste problems
  everywhere, found and reproduced first — T17c · a better Chromium-based browser than Brave,
  not plain Chromium/Chrome: the less common, well-made ones surveyed from official sources,
  the best 2–3 tried on this PC (start, RAM, 144 Hz smoothness, video decode, extensions),
  migrated (bookmarks, logins, settings, extensions) and themed — T31a · torrents: copy a
  magnet link, stream a video while it downloads — T29.
- r27-17b (T17b, the owner's 14:27 desktop items — partly; committed with this line) Clean mic
  removed completely (a subagent's work, reviewed here): 60-clean-mic.conf gone and retired from
  installs (backed up), kawa-quick's state/switch/source_to parts, kawa-state's setting (an old
  "cleanmic=" line dropped quietly at login), the sound panel's key and live level meter with all
  their listening code (pw-record, peak_pct, listen/heard — the separate level display kept), the
  report rows AUD-18/AUD-20, docs; the microphone's foot is now one row, mute · test mic, like
  mute · mixer above (28 px shorter). The running sound server: theme.sh points the default input
  back at the microphone the clean mic listened to, and restarts PipeWire only when no program
  holds a sound stream (playing or paused — a program's stream names its program, the desktop's
  own module streams do not: read on the live pw-dump); else it leaves "sound-restart" for the
  next login, which autostart takes before anything plays. (Unloading the module alone was tried
  on a throwaway PipeWire: the test daemon did not answer pw-dump — not pursued.) Screen off: a
  square key beside power in quick settings' foot (its own icon: the monitor with the power sign,
  tooltip "screen off"): kawa-lock --screens off after the click's release, then a one-shot
  swayidle lights them at the next key or move and ends itself; shot both themes. US/AR: dwl
  prints "kbcaps 0|1" (the keyboards' group's locked Caps, before kblayout) and the bar's tile is
  "us"/"ar" small, "US"/"AR" while Caps Lock is on (C locale: no dotted İ); bar-geometry now
  always runs with two layouts (the tile measured: 8 px to the ink, small letters too) — live
  with the next session (new dwl); a kernel-level key tool for that check: tools/uinput-key.py.
  Quick settings' design pass (owner: "strong design love … a proper, beautiful menu"; 26–27 Oct
  "every item unique yet aligned"): grilled — twelve identical boxes, a 14 px picture lost in each
  corner, "on" only a vermilion frame. Now each setting a crest (kamon) in the world's own
  language: a seal 28 px across on the tile's middle column (exact pixel masks, the same at every
  size), on — pressed: a vermilion disc, a paper ring 2 px inside its edge, the picture knocked out
  in paper (the bar's workspace stamp and the "chosen" hanko: one mark), off — its outline in
  edge2; name and state centred by their ink; the tiles' frames neutral (the seal carries the
  state). Air measured: 4 px above the seal and 4 under the state line (moved 1 px after the first
  shot: 3/4), seal → name 12, name → state 10. Turned on while it shows, the seal is stamped
  (§11: a pixel larger in accent_hi for 60 ms, then its size; never at an open). Under the
  cursor: the seal in negative (text_on_accent disc, vermilion ring and picture), the outline in
  the cursor's ink — shots both themes (rest, cursor on off/on, after Enter). All inks from
  look() (the panel's rule, its test kept). Mocked first (PIL, two variants: with/without the
  vermilion frames — without won), design-system §4/§11 rewritten first. Tests: test_panel 502/0
  (crest masks symmetric, 28 rows; the stamp's timing; look's crest inks), gallery --check held.
- r27-17c (T17c, copy and paste — the first two problems found, reproduced, fixed; committed with
  this line) Reproduced headless with the session's own helpers (kawa-clipkeep, wl-paste --watch
  kawa-clip --store) and real copies: (1) cliphist 0.7.0 (Fedora's) keeps nothing over 5,000,000
  bytes and says nothing (exit 0; its source: maxStoreSize 5e6, a -max-store-size flag only in
  later versions — github.com/sentriz/cliphist cliphist.go; measured 5000000 kept, 5000001 not):
  a photo or a 4K screenshot never reached Super+V. Now kept by kawa-clip itself up to its 20 MiB
  as a file (~/.cache/kawa-clip/big/, 16 hex of its SHA-256) with a short line standing for it in
  the history (type, size, dimensions, name — under the 100 characters cliphist's list shows);
  listed as a picture, --decode gives the bytes (preview, Enter, Super+Z all read through it),
  pruned when its line leaves the history. (2) The editor and the notes ran with "unnamedplus":
  every x, dd or cw replaced the desktop's clipboard and landed in Super+V's history (shown: a
  link copied, dd → the clipboard held the deleted line, x → one letter). Now
  ~/.config/nvim/lua/config/clipboard.lua (both use it): y copies to the desktop's clipboard,
  deletes stay in the editor, p/P put in the newest copy — the desktop's when one came since, else
  the editor's (dd then p still moves a line); shown in the kit: the browser's copy survives dd
  and x, p puts it in, yy reaches the desktop, the history holds only real copies. Clipkeep,
  quick exits (0.2–1.5 s), pictures and text after their app closed, primary selection, paste
  latency (5 ms): all fine. Tests: test_clip (big copies, the stand-in, pruning, no fall-through
  into the window — a missing exit hung Super+Z's test, found and fixed), test_shrink (stores as the
  session does), test_notes (the clipboard rules with a clipboard provider of its own), fake
  cliphist dropping >5 MB as 0.7 does. X11 programs (checked headless and live, read-only): an
  X client reads the Wayland clipboard only while an Xwayland window has focus — by design, a
  wlroots safeguard (Fedora's wlroots 0.20.2 source, xwayland/selection/outgoing.c,
  xwm_handle_selection_request: "No xwayland surface focused, deny access to clipboard"); so
  xclip from a terminal sees nothing, a focused X11 program pastes as usual — nothing to fix.
  The browser's checks go with T31a (Brave is being replaced). LibreOffice (GTK, Wayland) behaves
  as any GTK program; found on the way: a clean profile opens with its "Welcome / first time"
  dialog and its splash over the CSV import — the installer should pre-seed its profile (T54).
- r27-18 (T18, the old masters' world — in progress; each part committed with its line)
  (a) tools/build-masters.py: a public-domain print or painting → the desktop's own pixel art,
  640 × 360 (shown 3 × 3 at 1080p): reduced in linear light (Lanczos), a 5 × 5 bilateral
  smoothing twice (the paper's grain and mottled colour become a woodblock's flat areas, lines
  kept), its tones over the mood's ramp (kept, or "lacquer": the paper black lacquer, the lines
  light — maki-e), then each pixel a step of the ramp by its lightness, two neighbouring steps
  mixed by a 4 × 4 Bayer threshold, and an accent (vermilion, flame, asagi…) only where the part
  is strongly coloured and of a matching hue. Grilled on a pack print in three passes: nearest
  colour everywhere made noise and teal skies; hue-blind lightness made a sky vermilion; the
  ramp + matching accents gave a print by candlelight (dark) and on kinari paper (light).
  (b) the pack takes the desktop's own pictures from the toolkit ("toolkit:PATH", copied and
  checked by SHA-256 as a download is), and a picture smaller than the screen — pixel art — is
  enlarged by the smallest whole number that covers it, each pixel a square (3 × 3 at 1080p),
  never smoothed (test: a checkerboard read back pixel by pixel). (c) the bar's far right: the
  cat gives way to the mood's face — an oni (horns, scowl, tusks; it roars while quick settings
  is open) by night, a tennin (serene, a nimbus behind it; eyes open and smiling when open) by
  day — drawn in the cat's weight and its 15 px of ink (the tile's 8 px of air: bar-geometry
  held both moods, the gaps test reads both faces and "us"/"US"); a mood switch pokes the tile.
  Sources: a subagent hunts public-domain demons and angels in museums' open-access collections
  (art/masters/SOURCES.md, fetched to ~/.cache/r27-art). (d) fetch shows the mood's face: an
  oni mask (horns, brows, tusks, a vermilion tongue) in the dark, a haloed tennin (nimbus, hair
  knot, scarf) in the light, 20 × 16 cells in the ART_ grammar; `fetch random` and a name pick
  any (tests/content/test_fetch.sh 98/0). (e) art/masters/SOURCES.md: 14 demons and 14 angels
  from museums' open-access collections, each record (object page, licence line) checked
  (4b0226e). Next: the 10 + 10 wallpapers (masters.toml: crops, tones), the lock's scenes.
- r27-19 (T19, dwl's motion — in progress; each part committed with its line) (a) the dissolve,
  dwl's own (no wlroots patch: Fedora's binary copy stays): each frame the thing's picture is
  composed by wlroots' render pass into a buffer of its own, one quad of a GLES 2 shader clears
  the cells not there yet — 3 × 3 px (the wallpapers' pixel: moncell) on the screen's grid, ranks
  of build-masters.py's 4 × 4 Bayer matrix — and the scene shows that buffer while the window
  stays in place at opacity 0 (pointer, keys, frame callbacks go on). Window open 420 ms rising
  9 px, close 400 sinking 9, workspace switch 420 (out 0–280 drifting 24 px, in 140–420), the
  lock leaving 420; cells on a smoothstep (smootherstep lingered 86 ms on the first and last of
  the 16 steps). Verified headless on the GPU (wf-recorder to /dev/shm, frames by pts): every
  cell whole on the 3 px grid (0 mixed; hundreds on a 1 px shifted grid), rank 0 first at (0,0),
  rank 1 at (2,2); frame build p95 249 µs, max 267 with two windows dissolving (budget 6944);
  ASan clean (only setup-time EGL leaks at exit). Source checked: wlroots 0.20.2 (Fedora SRPM)
  render/gles2/pass.c — each pass sets FBO, viewport, blend func, scissor; each draw its
  program, texture, attributes — so a quad inside our own pass is safe. (c) layer surfaces by
  namespace (config.h layeranims): the panels' menus dissolve in 200 ms dropping 4 px and out
  160; a notice 240 · 200; the level display at once, out 300; the saver out 180 (over the lock
  too). Recorded: quick settings ~200/~160, the notice ~240/~200, the level display ~300.
  (d) warm windows (Super+U, N, V) unroll from their top edge over 300 ms, the rod (the frame's
  foot) travelling; put away, a frozen ghost rolls up into the top edge over 240 ms (rolling the
  live window showed fzf blanking mid-roll); bug 9: popups in a scene layer above any
  full-screen window — headless: Super+V over a full-screen terminal shows, Esc gives it back.
  Regress: menu-first-click, one-popup, level-display, warm-exit (now judging the rows above the
  rod: timing-proof), window-frame, bar-geometry, calendar-middle all hold; test_dwl_anim 38/0.
  Live check at 144 Hz waits for the session restart (batch B).
  (e) tiled windows making room slide to their new places, 240 ms eased out (a new place
  mid-slide goes on from where it is); headless frame log: every slide 240 ms, 0 steps skipped.
  (f) the wash moves into dwl (kawa-saver's --wash, its alpha-modifier and grim path gone):
  kawa-wash cover|go|drop through dwl's fifo. cover: each screen composed once into a picture
  of its own over everything, "covered" answered (5–6 ms headless), the change made under it;
  go: bled away over 1200 ms (smootherstep) — five drops of the new mood's darkest ink
  (dwl.colors "ink", written by build-themes.py) along a paper grain, 3 × 3 px cells on the
  screen's grid, a 55 % wet rim at the front; the pointer's new theme loads the moment the ink
  reaches it; drop: the end at once (a second switch pressed); a cover never told to go goes
  after 3 s; none under the lock, with animations off, or on a dark screen. Bug 5: the
  wallpaper picker keeps its page on Enter (fzf --no-clear) and dissolves out over the wash —
  never the bare ground. Headless on the GPU, both themes (tools/regress/wash.sh, 37 s): 199
  and 200 frames over 1204.6 ms, cells whole on the 3 px grid, only the old, the new and the
  rim's ink, the cursor loaded once between go and end; test_wash 28/0, test_theme 263/0,
  test_saver 75/0, test_dwl_anim 64/0. (g) the bar's seal stamps down on a workspace switch:
  a pixel larger all round in accent_hi (kami-seal-thump.png, 18 px) for 60 ms, then its size —
  two frames (GTK 3 reads steps(1, start) as CSS's steps(1, end): measured, the first state
  held to the end); test_bargaps checks its size, one ink and its place. Learn 5.4 and the
  Guide's §40 say the new wash. Not applied live yet: the session's dwl (11:36) has no wash —
  kawa-theme would wait 1 s for an answer; it goes live with batch B's restart.
  (h) tools/anim-check.sh — T19's acceptance check: every animation dwl draws on its own run
  headless on the GPU (9.5 s) and judged from dwl's frame log, not a recording: its pace from
  the steps themselves, its last step within a frame of its end, no step skipped, progress
  rising. Result: open 420.0 / 420 (68 steps, ×2), close 400.0 / 400, slide 240.0 / 240 (39),
  workspace out 280.0 / 280 (46), in 420.0 / 420 (68), wash 1200.0 / 1200 (199); max gap
  6.6 ms at a 6.28 ms frame, 0 skipped. Proven both ways: the same binary judged against a
  config.h saying open 300 → "open: paced 420.0 ms, not 300", exit 1. (A slide needs a
  window's place to change — the master closing; the master only narrowing is a resize, not
  a slide, by T19e's design.) Warm windows, menus, notices, the lock keep their regress checks
  (warm-exit, menu-first-click, level-display). The Learn book has no motion piece yet (T27
  writes it from design-system §11, which matches config.h). Next: login → desktop (the
  greeter's handover), the hourglass.
  (i) the hourglass, step 1 — Super+U knows which job runs: setup.sh writes its mode into root's
  lock once it holds it (opened without emptying it: lib/common.sh take_lock, setup.sh's kernels
  and after-dnf runs — a run waiting for the lock never wipes the holder's name); the menu maps
  it to its row (update · after-dnf → update, repair, upgrade · after-upgrade → upgrade; a run
  naming none — the boot's, an older one — stands as an update, as before) and that row alone
  shows the hourglass in place of its icon and "running" in vermilion; the status and a second
  run say which ("running   a repair, now", "a repair is running now — wait…"). Before: every
  run marked the update row and said "an update or a repair". Tests: test_status 196/0 (+12:
  three modes, one row running each, the words, the second run told), test_common 138/0 (the
  holder's name kept — fails on the old take_lock, 137/1), test_menu 559/0, static 10/10.
  (j) the hourglass turning, step 2: five frames in art/icons.txt (hg-0 … hg-4, the plain
  hourglass's outline: the sand falls 0–2, lies 3 — held a beat —, the glass turns on its side
  4, stands with the sand above 0), drawn at 1× and 10× in both inks; appended (the bar twins
  move up by five as with every new icon — no literal code point of theirs anywhere: searched).
  The rows carry the running row once more per frame (fields 4–9 after the name, frame 3
  twice); `fedokawaii --tick` (kawa-warm starts it as the popup shows, which now also marks the
  menu shown — --renew no longer restarts it under his eyes) tells fzf 6 times a second while
  the popup shows and a job runs, and at the end reads the list again, at rest. Real fzf 0.74.5
  driven through a pty: change-with-nth(4|5|6) sent through the socket starts its rotation
  afresh each time (4, 4, 4 — no turning), so each frame is named (4 5 6 4 5 6 2 drawn as
  sent); and fzf runs the pane again at every switch (1 → 8 runs in 7 ticks) at 42 ms a pane —
  a quarter of a core — so while it turns each pane is made once and kept in the runtime folder
  (750 µs a frame then), dropped when the turning stops. Tests: test_menu 588/0 (+29: nine
  fields, each frame only its icon changed, other rows alike, the ticker's frames named in turn
  and timed, one ticker, nothing when hidden or idle, the panes kept then dropped), test_warm
  88/0, test_status 196/0, launcher/config/copy, static 10/10. Live look (fonts, the popup at
  144 Hz) with the next apply — after batch B's restart (the wash).
- r27-keep (found 27 Oct 16:28) ~/blasphemous-save-backup-20261022 was in the Trash (trashed 26 Oct
  16:15 local, with game-shelf, Games, Balatro — before any round-27 session, the first at 27 Oct
  02:03): restored to ~ (476 K, Blasphemous + userdata-774361 intact), per the standing rule and
  the 27 Oct note (it moves into the gaming VM's import folder with T35).
- r27-33 (T29, findings 04:00 — not fixed yet) Prowlarr: on demand by design (kawa-prowlarr: up while
  torrra searches, asleep 30 min after) — "inactive" is normal. /api/v1/health: 0 now. Its own log
  (~/.config/prowlarr/logs) over 8 days: Warn AllowedHostsCheck "Allowed Hosts is not configured"
  ×156 (every start; also T39); Error Cardigann "Cloudflare protection detected for [Tokyo
  Toshokan], Flaresolverr may be required" ×30 (→ the UI's "indexer unavailable" warning, likely
  what he saw); Warn "Unable to connect to indexer [subsplease.org / torrentdownloads.pro] …
  DNS/SSL issues … ensure IPv6 is working or disabled" (→ bug 12's "failed to resolve": the
  container's IPv6/DNS path); UpdateCheck HTTP errors to prowlarr.servarr.com, SystemTimeCheck
  "Unable to verify system time", ServerSideNotificationService failures (same network path);
  StaticResourceMapper initialize.js not found ×6.
- found: tests failing on clean HEAD already (not from this change): session/test_autostart (5:
  the bar's <span line_height> wrapper), test_game (4: snapper/scrub timers — gaming leaves the
  host anyway), test_glass (2: OSC 11); static/test_generated (2: lock-scroll.png differs from
  build-themes.py's output; PROJECT_TOP lacks a top-level entry), static/test_syntax (1: setup.sh
  :75 SC1010 — shellcheck's newer parse; FIXED 03:57: "done" quoted), installer/test_hardware (1:
  hw_firmware_pkgs expects intel-bt-firmware — the machine's firmware files). → T53.
  UPDATE 27 Oct 18:45: test_autostart 84/0, test_glass 27/0, test_generated pass now (earlier
  passes); test_hardware 103/0 — the first hw_firmware_pkgs call read this PC's /usr/lib/firmware
  (linux-firmware has rtw89/rtw8852b_fw-1 and mediatek/WIFI_RAM_CODE_MT7961_1 here), now the fake
  machine's own empty folder; test_game 73/0 — its systemctl stand-in looked the unit up with
  ${*##* }, which strips each word on its own (POSIX), so no timer ever read "waiting": the
  stand-in's fault, not kawa-game's; it takes the last word now. None of the listed ones fails.
- r27-suite (27 Oct 18:45–19:07, the full suite, cut off at the pass's end in the look area):
  failing — installer: test_setup 47, test_theme_parts 37, test_verify 15, test_setup_wait 12,
  test_theme 9, test_torture 5, test_upkeep 4, test_afterdnf 3, test_report 3, test_setup_hw 2,
  test_guard 1 (those read say "mako's tag v1.11.0 does not point at the pinned commit 91c6b79… —
  refusing to build": lib/upstream.sh's mako pin against the tests' stand-in repo — mako was not
  touched this pass); shell: test_shell 15, test_tiles 18 (the prompt: test_tiles fails the same 18
  at 4b0226e, this pass's start — not from this pass). Every file this pass touched passes on its
  own. NEXT PASS FIRST: the mako pin against its tag (lib/upstream.sh, the stand-in), then the
  prompt's cases, then the full suite again — before any new work.
- r27-suite fixed (28 Oct 12:28–, pass of 12:27): every failure read was the harness, not the
  desktop, except one real bug. Stand-ins: git/meson know mako v1.11.0 (its pinned commit, a
  built binary) → test_setup 232/0, test_setup_wait 70/0; test_tiles 142/0 and test_shell 187/0:
  readline 8.3 (bash 5.3.9 here; the tests were written under 5.2) draws the line again over
  itself as keys come — CR, the prompt and its OSC 133;A anew on the same row (foot marks a row,
  so no double mark for its prompt jumps) — the parsers keep each prompt's fullest drawing; the
  fake machine's python3 turns a leading -I into -E -P, as Fedora reads /usr/local's site folder
  only with the user site on (checked: `python3 -I` never lists it, even when it exists) →
  test_afterdnf 37/0; test_report 118/0 (the host's steam hidden in the fake machine; a mapped
  uid for podman's files — 100999 is outside the 65536 subordinate ids); test_guard 42/0 (the
  guard's message names mako now); test_verify 171/0 (built worlds pin the four UDEV Gothic
  stand-ins, not only those that fetch releases); the fake /usr/share gets its own plymouth
  themes (the host's sumi is read-only through the farm). REAL BUG: Syncplay's chat was set to
  "JetBrainsMono Nerd Font", gone since T11 (fc-match → Noto Sans; his syncplay.ini named it):
  theme.sh sets UDEV Gothic NF (as mpv's OSD and syncplayintf.conf) and counts the old face as
  ours, not his choice — replaced; the report's FONT-08 asked for the old face too (would FAIL):
  now UDEV Gothic NF.
- r27-19k (28 Oct) the owner's 19:19 items (CLAUDE.md, uncommitted until 7e06e6b) were not in the
  plan: now T19k — 1 the bar's flicker on rapid workspace switches (frame log + anim-check
  --bar-burst), 2 highlight contrast (tools/contrast.py, WCAG ≥ 4.5:1 text/icons, 3:1 frames,
  both themes, a static test), 3 quick settings redesigned for real, 4 serious icons (demon/angel
  heads on a larger grid or images, with T18), 5 a to-do icon (with T21), 6 measure always.
- r27-19 batch B LIVE (28 Oct 12:41–12:45): `fedokawaii apply` took the repair path ("packages or
  system parts changed"), verify 1 problem before → 0 after; dwl rebuilt from src/dwl/dwl.patch
  (12:42:26), the notices' mako v1.11.0 in place. The session restarted 12:43:10 through greetd's
  one-time initial_session (his session held only its autostart windows: nothing of his open;
  the file restored at once — 0 initial_session lines). VERIFIED: tools/anim-check.sh --dwl
  /usr/local/bin/dwl (the shipped binary, headless on the GPU): open 420.0 ×2, slide 240.0,
  close 400.0 ×2, workspace out 280.0 / in 420.0, wash 1200.0 ms, 0 skipped, last steps ≤ 6.2 ms
  after their end; live: grim shots 14 ms apart while a window opened beside another (the tiles
  slid to 61 %, the new one's dissolve waiting at its first step for foot's first frame — five
  shots alike), the screen at rest pixel-identical before and after. The 144 Hz look of every
  animation on the monitor itself goes with T19k-1 (the bar's flicker), on this dwl.
- r27-19k-1 (28 Oct 12:50, first look — not fixed yet) the bar through a burst of switches:
  tools/regress/bar-burst.sh (headless kit, the shipped dwl, the real waybar, a terminal on 1 and
  on 2, 1 ↔ 2 every 40 ms × 24, the top 40 rows shot every ~14 ms: 403–413 shots). The bar's own
  rows (0–26): 10 states in 30 runs, all states it rests in (the seals 1/2, the clock's second,
  one status value); the two shown for one shot only are a seal change and the clock / a status
  value ticking a shot later — no torn, blank or mixed bar. Under it (rows 27–39): 56 states,
  203 of 220 runs one shot long — every switch restarts the windows' scroll and dissolve, so the
  windows' top frames against the bar's edge jump sideways and go dashed (the dissolve's 3 px
  cells) at every switch. Most likely what reads as "the bar flickers": the windows meeting it,
  not the bar. His report was on the 15:51 dwl (before batch B). NEXT: the same burst on the PC
  at 144 Hz (Super+1/2 held through wtype in the live session, dwl's frame log), then the fix at
  the cause — a switch arriving while the last one still runs takes over from where the windows
  are (no restart from the edge, no new dissolve) — and the pass/fail rule in bar-burst.sh.
- r27-19k-1 FIXED in code (28 Oct 12:54, headless-proven; live with the next session restart):
  the cause found in view(): a switch during the last one's animation ran animstop() on every
  window still animating — one half dissolved IN snapped whole for a frame, then dissolved OUT
  from 100 %; one half OUT vanished, then came IN from 0. Now such a window turns round where
  it stands (animturn: its AnimIn/AnimOut played backwards from its animp, back over the time it
  took — the same cells and the same drift on the next frame; turned twice it runs forwards
  again; a window going elsewhere ends as before). VERIFIED headless: tools/anim-check.sh on the
  edited dwl all held (open 420.0, slide 240.0, close 400.0, workspace out 280.0 / in 420.0,
  wash 1200.1, 0 skipped); tools/regress/bar-burst.sh (rule: a "flash" = the windows' lit pixels
  under the bar one shot > 300 off both neighbours) — the shipped dwl 17 flashes (a dashed top
  frame at every switch), the fixed one 0; under the bar 56 → 23 states, the bar's own rows 8
  states, none for one shot. src/dwl/dwl.patch rewritten (it reproduces the tree byte for byte
  from v0.9 98bea2c). NEXT PASS: ASan build + bar-burst again, apply, session restart, the burst
  on the PC (live grim shots), bar-burst into tests/session's regression set (T52).
- r27-suite CLEAN (28 Oct 12:56): every file the last full run listed now passes — installer:
  test_setup 232/0, test_setup_wait 70/0, test_setup_hw 84/0, test_verify 171/0, test_theme
  140/0, test_theme_parts 129/0, test_torture 214/0 (the Arabic-locale runs skipped: no
  ar_AE.UTF-8 here), test_upkeep 219/0 (a disk full to the last byte: the job's mark no longer
  fails before the space sentence — a real fix in setup.sh), test_afterdnf 37/0, test_report
  118/0, test_guard 42/0; content: test_shell 187/0, test_tiles 142/0. The whole suite in one
  run is still owed (one-hour passes: run it in two halves next).
- r27-19k-1 ASan (28 Oct 12:56): tools/hl-dwl.sh --asan with bursts 1↔2 at 30–45 ms, 1→2→3→2→1,
  a window closing and one opening mid-burst: 556 turned-round frames (A … r2/r3 in the frame
  log), 0 AddressSanitizer errors; LeakSanitizer only dwl's one-time setup allocations at exit
  (EGL init, event-loop sources — no animation code in any stack).
- r27-19k-1 part 2 (28 Oct 12:58–13:02): LIVE on the PC (the turn fix applied 12:57, session
  restarted 12:57:49): the burst through the real session (two terminals, grim on HDMI-A-1):
  the bar's rows 8 states, none for one shot — and one flicker left right under the bar: the
  leaving window's frame went grey the moment the focus moved and red again when it turned
  back, at every switch. FIXED in code: a window on its way out keeps the frame it had (view:
  bwas), set right once it is gone (animstop). bar-burst.sh now has a slower second burst
  (6 × 180 ms: windows well into their dissolve) and two rules — a pop (the frames' lit pixels
  jumping more than one dissolve step, a quarter line, between two ~14 ms shots) and a frame
  changing colour under the bar: the installed dwl (turn only) 0 pops, 30 colour changes →
  exit 1; the fixed tree 0 and 0 → exit 0 (955 shots). anim-check all held; ASan 0 errors over
  560 turned frames. Patch rewritten (reproduces the tree). Live with the next restart.
- r27-19k-1 VERIFIED on the PC (28 Oct 13:02, the final dwl applied 13:02:19, session restarted
  13:02:27): the burst through the live session (two terminals, 24 switches 40 ms apart, grim on
  HDMI-A-1 every ~14 ms, 362 shots): the bar's rows 7 states, none for one shot; under it 0 pops,
  0 frame-colour changes (362/362 red; before the colour fix: grey/red at every switch, 30 per
  burst headless). The screen at rest after: pixel-identical to before. The owner's eye on a real
  burst of his own is the last word (r27-19k-1 stays VERIFIED by measurement until he says).
- NEXT PASS STARTS HERE (28 Oct 13:04): T19k-2, highlight contrast — .claude/notes/contrast-r27.md
  has the measurements and the candidates (one grammar for "selected" in both themes: cream words
  on a deep lacquer red, ≥ 7:1 for the row's words; faint ≥ 4.5 where it is text); render them with
  tools/gallery.sh --only system,launcher,quick,clipboard, grill, build tools/contrast.py + its
  static test. Then T19k-3 (quick settings, for real). The full suite in two halves (installer /
  the rest) somewhere in the pass: every file that failed is green one by one now.
- r27-19k-2 DONE + VERIFIED on the PC (30 Oct 02:28) — highlight contrast. What is selected is
  now one grammar in both themes: the lacquer (漆) — Wada's Vandyke Red #82241f, new roles
  `select` / `text_on_select` / `select_lo` in tools/wada-palette.py — with the strongest cream on
  it: 7.28 : 1 dark (#f1e1b4), 8.46 light (#f8f3d8); before, near-black on the vermilion, 5.14
  (pure black could not pass 5.8) and light's cream on Brick Red 5.42 — two opposite grammars.
  Where: every fzf menu (foot's new 24/25 = bg+/fg+, `:strip` keeps every ink on the row cream),
  quick settings' and the bar menus' cursor (kawa-panel look(): fill select, inks text_on_select;
  a seal under it: its picture the lacquer on the cream disc; a meter's unlit segments select_lo,
  3.7 : 1 under the lit — the vermilion there would have been 1.6 in light), GTK 3/4 (accent_bg/fg:
  selected rows, default/pressed buttons), Qt (Highlight/HighlightedText; disabled: muted on edge),
  Neovim's completion and wild menus (gruvbox's blue held 3.3 on paper), mpv's console and context
  menu, btop's chosen process, the mixer's dropdown, the lock's selected words. tools/contrast.py
  (new) measures every selected/highlighted pair from the shipped files — 40, both themes, words
  ≥ 7, icons/matched letters ≥ 4.5, a seal's numeral / a meter's level ≥ 3: 0 under;
  tests/static/test_contrast.sh 11/0 (it also proves a 5.1 row fails); test_panel 503/0;
  test_design_doc 54/0 (§1: the three tokens, the selected rule; §4/§5 updated). Headless renders
  (tools/gallery.sh system/launcher/quick/clipboard/sound, both themes; a kit play with the cursor
  on a meter and a tile): one lacquer band in both themes. Applied 02:22 (fedokawaii apply; verify
  257/258 — the one: qbittorrent outside the manifest, see the note below). LIVE: foot reads its
  palette only at start, so the session's foot server (no terminal of his open) and the warm
  windows were restarted in the session's environment (02:26) instead of a session restart (he
  had logged in at 02:14:48 — maybe at the PC); Super+U opened live by wtype, grim: the band
  #82241f, its words #f1e1b4 = 7.28 : 1 measured on the screen, 0 pixels of foot's default 24.
  Left: yazi's cursor row (edge, not the lacquer) → T22 (plan updated). Seen for T19k-3: under the
  cursor a meter's last segment sits flush on the fill's right edge while the icon has 8 px of air
  on the left (as before the change) — fix with the quick-settings redesign.
- r27-note (30 Oct 02:23): `fedokawaii verify` flags "installed outside the manifest — qbittorrent":
  the owner installed it himself (dnf history 74, 28 Oct 22:35 +04, `dnf install qbittorrent`, user
  dia — not a script). Respected: not removed. Decide with the torrents task (T-torrents: likely he
  wants a client that works now; the gaming side's qBittorrent goes into the Windows VM) — either
  the manifest takes it as his choice or the Torrents app replaces it; until then verify shows 1.
- r27-19k-2 part 2 (30 Oct 02:31): VisiData (the Tables window) still filled its cursor row and
  column name with the vermilion (17 on 16) and its menu's active item black on coral / Vandyke
  Red — now 25 on 24 (the lacquer) like every menu; tools/contrast.py reads its config (48 pairs,
  0 under); test_configs 332/0 (its colour check takes slots 16–25). Applied (live config: '25 on
  24'). The doc's cursor (§4) and kawa-panel's comment say lacquer. OPEN, measured: lazygit's
  selected line keeps each file's own colour on `black` (edge) — a red (unstaged) name 4.15 : 1 in
  dark; lazygit has no selected-line foreground, so the lacquer would put red on red: decide with
  the git screen (bold + a darker line, or `reverse`), then add it to contrast.py.
- r27-19k-3 first step (30 Oct 02:31): quick settings in three directions (sketches with the real
  faces and palette: .claude/notes/design-r27/quick-{A-mon,B-ema,C-list}.png), grilled in
  .claude/notes/grill-r27.md — CHOSEN: A, the mon sheet (家紋): no boxes, a crest 36 px across per
  item on four columns, name and state centred under it, the four foot keys on the same columns,
  the demon/angel head on the rod at the top; the refinements to build are listed there. Not built
  yet (it re-measures most of test_panel's 503 checks: a pass of its own).
- r27-event (30 Oct 02:31–11:23): the session was LOCKED at 02:31:07 (kawa-lock "lock up" — gtklock
  locked every screen); the journal has no automated trigger (kawa-idle silent, the round's idle
  inhibitor active, swayidle has no logind lock handler, the test harness's runtime dir is its
  own): a direct kawa-lock — most likely Super+L (he had logged in at 02:14:48). kawa-lock's rule
  "still locked after 90 s: sleep" suspended the PC at 02:32:37 with this pass mid-apply; he woke
  it at 11:22:28 and unlocked 11:23:07; the apply finished then (11:23:10). Nothing lost (all
  committed). While he is at the PC: no wtype/session restart — headless only. Note: the foot
  server restarted at 02:26 runs outside autostart's keep() until the next login (no harm: it is
  the server autostart starts, same environment; a crash would leave Super+Return dead until then).
- r27-19k-3 (a)–(c) ON MAIN (30 Oct 11:34) — quick settings as the mon sheet (家紋): four columns
  of crests in 94 × 88 cells, nothing framed (a short row centred), the crest a seal 36 px across
  6 px down, the name (text) on the row 46 px down, the state on the row 66 px down (strong on,
  muted off — never faint), words up to 86 px ("KINGSTON 58G" whole); the cursor the whole cell in
  the lacquer. The grid question (94 × 88 is off the 8 px / 20 px grid) grilled against an on-grid
  variant (88 × 80, 8 apart: the crest crowded 2 px under the cursor's edge) — 94 × 88 kept, §3
  states it as the grid's one exception; §4 rewritten. Tests: test_panel 503/0, test_quick 369/0,
  test_hotkeys 65/0, test_design_doc 54/0, test_noellipsis 9/0, test_contrast 11/0; the gallery's
  reference box for quick 411 × 420. Rendered headless both themes (kit play with the repo's bin:
  rest, the cursor on an off crest). NOT applied: he was at the PC (an apply restarts nothing he
  sees, but the live check would pop quick settings up on his screen) — next pass, while he is away.
- r27-suite (30 Oct, partial): the whole suite started 02:28 on that tree (a copy) — 52 of 124 files
  passed with 0 failures before the pass ran out (content, drives, engine, installer through
  test_upgrade; it slept with the PC 02:32–11:22). Owed: the rest (installer from test_upkeep, look,
  menus, session, static, status, yazi …) on the current tree.
- NEXT PASS STARTS HERE (30 Oct 11:35): apply (fedokawaii apply) and look at quick settings live
  (only if he is away: kawa-quick in the session's env, grim, Escape through the panel's fifo — no
  wtype into his apps); then T19k-3 (d) the foot keys on the four columns (render both variants,
  grill), (f) px.py: the air left/right of every crest and of the longest word, the cursor cell's
  edges, the meter row under the cursor (flush right today); then T19k-4 (the crests' 28 px
  pictures, the demon/angel head on the rod). The rest of the suite in the pass's first minutes,
  in the background (setsid, never nohup).
- r27-event (31 Oct 00:56–10:58): the owner powered the PC off cleanly at 00:56 (systemd-poweroff,
  journal -b -1) and on at 10:57:54; the pass began at the greeter (no session of his: headless only).
- r27-19k-3 (a)–(c) LIVE-INSTALLED (31 Oct 11:00): fedokawaii apply (rc 3: only qbittorrent outside
  the manifest — his own install, r27-note 30 Oct); ~/.local/bin/kawa-panel is the mon sheet; his next
  login shows it (no session was up to look at it live).
- r27-19k-3 (d)+(f) DONE + VERIFIED kit (31 Oct 11:07, e6ec42c): the sheet's foot — wallpaper,
  screenshot, screen off, power — as four ACTIONS on the crests' four columns (94 × 46 each, an icon
  over its word, 16 px under the sheet), the framed keys gone (they were the last frame on the sheet).
  Rendered both ways, both themes (.claude/notes/grill-r27.md): small outline crests read as a 4th
  row of switches that are off (an outline crest = off on this sheet) — rejected; icon over word kept.
  px.py on the kit's shots (identical in both themes): icons 41 | 41 in every cell; words 16 | 17,
  12 | 13, 12 | 13, 30 | 30 (the odd pixel right); 7 px above the icon's ink, 7 under the baseline
  (the crest cells' 6/7); the cursor's lacquer exactly the cell (x 1801 +94, y 414 +46), then 16 px
  of pad to the hairline, the shadow whole. Panel 410 × 444 (window 411 × 446; gallery-expect
  updated). test_panel 505/0, test_quick 369/0, test_hotkeys 65/0, test_contrast 11/0,
  test_noellipsis 9/0, test_design_doc 54/0; design-system §3 table + §4 "Action".
- r27-fix apply (31 Oct 11:10): apply ran a whole repair (snapshot, packages, firmware …) for
  changes to tests/ and .claude/ — they now only travel with the copy (like docs/, tools/); Python's
  __pycache__ (tools/ leaves one) no longer counts as a change nor reaches the toolkit
  (/usr/local/lib/fedokawaii — a stray file in a root folder). Tests: test_front 125+2 cases,
  test_upkeep (the toolkit holds no __pycache__). Still to decide with the clean-structure task: the
  toolkit carries .claude/ (notes, design renders) — nothing reads them there.
- r27-suite (31 Oct, rest of the 30 Oct run): look 12/12, static 11/11 green; menus' only failure was
  test_panel copied mid-edit (505/0 after); session/test_bar 1 failure — a stale check ("foot's
  palette has no 24") from before T19k-2 put the lacquer at 24/25: rewritten (24/25 = select /
  text_on_select per theme, never the bar's tile) — 257/0.
- r27-19k-4 WIP (31 Oct 11:14): first serious drawings of the mood's face — the hannya (dark, after
  Hokusai's Warai Hannya) and the tennin (light), 18 × 18 in four inks (sumi, ivory, gold, lacquer)
  on the end tile's red, each with its "open" frame (roar / eyes open, smile); renders at 1× and 8×
  in .claude/notes/design-r27/heads-t19k4.png, the grill in grill-r27.md. Not wired yet: next pass
  moves the grids into tools/build-art.py → PNGs for waybar's end tile and quick settings' heading.
- r27-fix (31 Oct 11:13): the toolkit no longer holds __pycache__, so every comparison of a clone
  with it skips __pycache__ too (setup.sh's clone removal, system/fedokawaii same_as_toolkit) —
  else a clone with tools/__pycache__ "differs from the toolkit" and is kept (test_upkeep caught it).
- r27-19k-4 (a) DONE + VERIFIED kit, LIVE-INSTALLED (31 Oct 11:20, 4aa4fb9): the bar's end tile shows
  the drawn face — tools/build-themes.py FACES → themes/<m>/face.png + face-open.png (18 × 18, four
  inks); waybar #custom-menu lays it on the paper (background-position 5px 1px), the open frame on
  .active (quick settings open). Measured on the kit's real bar: 1 | 1 px of paper above/below in
  both themes, across 7 | 8 (hannya) and 6 | 7 (tennin) — the odd pixel right; the tile's right
  hairline still on x 1911. Shots at rest and open, both themes (kit play: Super+X). test_bar 265/0
  (+ the face's case), static 11/11. Applied (6 files: the 4 pictures, style.css, kawa-panel);
  his next login shows it — a live grim of the bar then (no session was up).
- r27-fix verified live (31 Oct 11:20): after this apply /usr/local/lib/fedokawaii holds 0 __pycache__
  (the first apply of the day had copied tools/__pycache__ in).
- NEXT PASS STARTS HERE (31 Oct 11:21): if his session is up and he is away — grim the bar's end tile
  and quick settings live (both from the session's env), px.py against the kit's numbers. Then T19k-4
  (b): quick settings' heading wears the face (open frame) — sketch two ways and grill: (1) the face
  on a 20 × 20 vermilion seal in the icon column, the name at 24 as every heading's (only 4 px of air
  to the name), (2) the same seal with the name at 32 (cells: the meters' names below — a stated
  exception); the hannya's black hair needs the seal (on the dark ground it vanishes). Then (c) the
  crests' 28 px pictures (12 drawings, one ink each on the seal, multi-ink off) and (d) the to-do
  icon (T19k-5). The suite's installer area (started 11:10 on a copy before the __pycache__ fix):
  re-run it whole.
- r27-19k-4 (b) DONE + VERIFIED kit (31 Oct 11:25): quick settings' heading wears the mood's face —
  its open frame on a 20 × 20 vermilion seal on the content's edge, the name moved to the rows'
  column (32); three placements rendered both themes, grilled (grill-r27.md). test_panel 507/0,
  menus 12/12, test_design_doc 54/0; design-system §4 states the exception. Not applied yet.
- r27-19k-4 (b) LIVE-INSTALLED + r27-fix apply VERIFIED live (31 Oct 11:25, 012bbe2): apply of a change
  to bin/, tests/, docs/ and .claude/ ran the theme alone — 5 s, no snapshot, no repair, exit 0 (the
  same kind of change took a ~65 s repair with a snapshot at 10:59); 1 file updated (kawa-panel).
- NEXT PASS STARTS HERE (31 Oct 11:27; replaces the 11:21 note): (1) if his session is up and he is
  away — grim the bar's end tile and quick settings live, px.py against the kit's numbers (face 1 | 1,
  7 | 8 / 6 | 7; the heading's seal x 17–36). (2) T19k-4 (c): the crests' 28 px pictures — one drawing
  per switch (theme moon/sun, night lantern, freesync wave, network ethernet/wifi/offline, bluetooth,
  devices, drives, backup, dnd bell/bell-off, saver, record, read text), 28 × 28 inside the 36 px
  seal (art/icons.txt can hold 28 × 28 — "at 14 px, 28 px, 42 px…"), grilled one by one at 1× both
  themes. (3) T19k-5: the to-do's own icon — direction: a tanzaku (Tanabata's wish slip, hung by its
  string; a tick on it) in place of ICON_BOX_ON (system/fedokawaii learning → to-do), 12 × 12 beside
  words, larger where Super+N's tab shows it (T21). (4) the suite's installer area again on the
  current tree (the 11:10 run used a copy from before the __pycache__ fix: its test_upkeep fails
  for that reason alone).
- r27-suite (31 Oct 11:32, installer area on a copy of 11:10): 23 of 25 green (test_setup 232,
  test_torture 214, test_verify 171, test_upgrade 40 …); test_upkeep 1 — the known stale-copy case
  (fixed in 1e95822: 220/0 on the current tree); **test_upstream 4 failures, OPEN**: "Fedora's
  Twisted missing" and "a copy whose libraries went since" expect Syncplay not to load once the
  harness moves its stand-in twisted away (fake_pylibs, $FK_PYLIBS) — it still loads: the stub
  tests/installer/stubs/python3 turns -I into -E -P and runs /usr/bin/python3, which finds the
  machine's own /usr/lib/python3.14/site-packages/twisted (python3-twisted 25.5.0, installed 19 Oct).
  The suite was clean on 28 Oct 12:56 with the same packages (python3 3.14.8 since 19 Oct; dnf 74 —
  his qbittorrent — added no Python), so something else changed: next pass — run test_upstream
  alone, print sys.path inside syncplay_runs under the harness (as_user/fkrun's namespace: is the
  real site folder hidden there, and since when not?), fix the harness (the stand-ins must be the
  only Python libraries the fake machine has), never the check.
- r27-suite test_upstream CAUSE FOUND (31 Oct 11:35; reproduces alone in 8 s: 242/4): commit 7e06e6b
  (28 Oct 12:38) made tests/installer/stubs/python3 turn -I into -E -P so the fake machine's
  /usr/local stand-ins (fake_pylibs) load — which also leaves this machine's own
  /usr/lib{,64}/python3.14/site-packages on the path (sys.path, outside: ~/.local…, /usr/lib64…,
  /usr/lib…): moving the stand-in twisted away now finds the real one. The 12:56 "CLEAN" re-ran only
  the files that had failed, never test_upstream. FIX (next pass, the harness's own pattern): give
  the fake machine its own site folders — in usr_farm, a farm of links for each real
  /usr/lib{,64}/python3.*/site-packages without twisted, certifi, pem, OpenSSL (and their
  *.dist-info), the real folders bound read-only under $W/.usrpy first (links point there, as
  $W/.usr/bin's do), then FK_INNER binds each farm over its real folder; the stand-ins stay the only
  copies. Verify: test_upstream 246/0, test_afterdnf, test_guard, the whole installer area.
- r27-suite test_upstream, the planned fix TRIED and REVERTED (31 Oct 11:37): a farm of the real site
  folders without Twisted/certifi/pem/pyOpenSSL for every case broke 27 cases — Syncplay's own
  install case loads with the machine's real libraries (the stand-ins in /usr/local never were the
  only copies; they only add what the real ones lack). So: hide the real package only where a case
  simulates its absence — e.g. `fkh py-hide twisted` (a list in the fake machine's state) that
  FK_INNER reads to bind an empty, unreadable folder over /usr/lib{,64}/python3.*/site-packages/NAME
  for that run, used by the two "missing" cases with the stand-in moved away. Then test_upstream,
  test_afterdnf, test_guard and the installer area. (tests/installer/lib.sh as it was: unchanged.)
- r27-suite test_upstream FIXED (31 Oct 11:37): the fake machine reads $FKH/py-hide — each named
  Python library of this machine gets an unreadable empty tmpfs over it (/usr/lib{,64}/python3.*/
  site-packages/NAME) for that run; the two "Twisted missing" cases name twisted besides moving the
  stand-in away (and clear it after). Inert unless a case writes it. test_upstream 246/0 (was 242/4),
  test_afterdnf 37/0, test_guard 42/0. Owed: the whole installer area on this tree (next pass).
- NEXT PASS STARTS HERE (31 Oct 11:38; the 11:27 note's items stand): first read
  ~/.cache/r27-suite-installer-20261031.log — the whole installer area started 11:38 on d83edfd (detached;
  expect "✔ all 25"); a failure there is the first job. Then the 11:27 list: the live grim of the
  bar's face and quick settings (only while he is away), T19k-4 (c) the crests' pictures (the moon
  holds; the sun's diagonals and the lantern grilled in grill-r27.md), T19k-5 the tanzaku.
- r27-suite installer area CLEAN (31 Oct 11:51, on d83edfd, detached): ✔ all 25 files — test_upstream
  246/0, test_upkeep 220/0, test_setup 232/0, test_torture 214/0, test_verify 171/0, test_upgrade 40/0 …
  (log ~/.cache/r27-suite-installer-20261031.log).
- r27-19k-4 (a) VERIFIED LIVE (31 Oct 22:20, grim of his running bar, session env from waybar): the
  hannya on the end tile, 7 | 8 px of paper across its ink and 1 | 1 above/below (px.py runs + boxes) —
  the kit's numbers exactly.
- r27-19k-4 (c) DONE + VERIFIED kit (31 Oct 23:05): quick settings' crests drawn anew — 16 pictures
  28 × 28 in art/crests.txt (kamon grammar in its header and design-system §4/§13: one ink, 2 px
  strokes, 45° as runs of 3, 1 px knock-outs, ink inside r 13, the odd pixel right/below, a line
  across = off): moon and star (月に星), sun, a stone tōrō (night light), water breaking (freesync),
  socket, wifi, offline (arcs + a cross), the rune, headphones, USB stick, a senryō-bako (backup), a
  bonshō and the bell struck through (dnd), a spool and its needle (the saver is sashiko), a cine
  camera, a region's corners (read text). Five render rounds grilled (grill-r27.md). Built by
  tools/build-icons.py → configs/home/.local/share/fedokawaii/crests/NAME.png (masks; the font and
  icons.sh rebuilt byte-identical); kawa-panel paints the mask in the state's ink (crest_pic; none
  there: nothing). Measured on the real panel (kit, both themes): pictures 1:1 (moon 248 px = the
  mask), air to the seal's edge = drawing + 4 (moon 6|7·6|6, socket 8|8·9|9, spool 8|9·7|8).
  test_panel 513/0 (+ drawn/built/PNG-shape cases), test_design_doc 54/0. tools/kit.sh copies the
  crests into its home. Left: the 14 px tile_* glyphs (all but tile_bell_off, the bar's dnd) are
  unused now — out with T53 (removing them renumbers the font: by name only). Owner's verdict pending.
- r27-19k-4 (c) LIVE-INSTALLED (31 Oct 22:33, 80f603a): apply 12 s, rc 0 — the 16 crests in
  ~/.local/share/fedokawaii/crests, kawa-panel updated (the running one keeps its 14 px pictures until
  his next login). verify after it: 257/258 — the one, qbittorrent outside the manifest (his own install,
  28 Oct; decided with T29, see r27-note 30 Oct 02:23).
- r27-19k-5 DONE + VERIFIED kit (31 Oct 22:50): the to-do's own icon — a tanzaku, Tanabata's wish slip
  hung by its string from a bamboo twig, a tick breaking out of its right edge (art/icons.txt @todo,
  12 × 12, 1 px strokes as its neighbours: book, knight, keyboard, keycap; appended last: no base code
  point moved, the -bar twins renumbered by name only). Super+U → learning → to-do shows ICON_TODO in
  place of the filled checkbox (system/fedokawaii); three rounds of drafts: a centred string stub on a
  rectangle read as a battery (V1, V7), lines of writing as a document (V6) → the diagonal string to
  the twig (V11). Kit play both themes (Super+U, 4 × Tab, cursor on to-do): the row's icon and the
  pane's heading, 1 drawing pixel = 1 screen pixel (8× crop). test_menu 589/0 (+ the case: ICON_TODO,
  not ICON_BOX_ON). ICON_BOX_ON now unused (T53's list). Left for T21: the larger tanzaku on Super+N's
  to-do tab.
- r27-19k-4 (d) DONE + VERIFIED kit (31 Oct 23:20): the bar's weather drawn — its night icon, a thin
  1-bit crescent, read as a "C" beside the digits ("C 28°", a unit). Now nine skies, 14 × 14 in a few
  inks of the palette (design-system §8/§13: the weather's pictures may), tools/build-themes.py SKY →
  themes/*/sky-NAME.png: clear (the vermilion sun, gold rays) and clear-night (the gold moon and its
  star), partly and partly-night (sun / moon behind a cloud), cloud, fog, rain (blue), snow, storm (a
  gold bolt); clouds two-toned per theme (dark: ivory, its shade; light: white in a grey edge).
  kawa-weather --bar: the text is the temperature alone, the sky its class (sky-NAME; l1 when it starts
  with a 1 or a minus: their own column of air taken back); style.css lays the picture on the tile's
  paper (two backgrounds over the fibre, 7 px into the padding box = 8 from the paper's edge). Kit play
  (the kit's own waybar told by signal 18, matched by its HOME), all nine both themes, measured on the
  bar: paper → sky 8, sky 14 on the line's rows 3–16, sky → value 8 (15°, -3°, 17°, -5° with l1; 28°,
  21°, 9°, 31° without), value → paper 8. test_weather 229/0 (+ every code's picture, l1, nine pictures
  × two themes × a rule each), test_bargaps 5/0 (the sky's geometry in place of ICON_BAR_), test_bar
  265/0, test_design_doc 54/0, test_generated 256/0. The 12 px sky glyphs stay for the forecast menu.
- r27-19k-4 (d) LIVE + VERIFIED LIVE (31 Oct 22:53, 9f35c86): he was away (a 60 s idle probe — a
  throw-away `swayidle timeout 60` in his session — fired), so: apply (5.5 s, rc 0, 20 files: the
  skies, kawa-weather, style.css …), then SIGUSR2 to his waybar (its style read anew, same pid, no
  crash) and signal 18 (the weather module): the gold moon and its star beside 28°. Measured on his
  screen (grim): paper → sky 8 · sky 14 on the paper's rows 3–16 · sky → value 8 · value → paper 8.
- r27-19k-4 (e) DONE + VERIFIED kit (31 Oct 23:05): Super+U's sections get their own pictures (12 × 12,
  1 px strokes; appended to art/icons.txt): system a pagoda (its storeys: the system's layers — also
  the settings' "system" heading, kawa-config), update a seedling (what is new grows), backups the
  senryō-bako of its crest (10 rows, centred); snapshots keep the camera, learning the cap (drafts of a
  brush, a brush over its stroke and a scroll read as "edit" or "document": rejected). Kit play both
  themes: the tab row's icons on one baseline 40 px apart (px.py boxes). test_menu 589/0, test_config
  105/0 (their icons in the tab row and the settings' heading).
- r27-fix FOUND + FIXED (31 Oct 23:20) — an icon added showed WRONG icons in a running session: tested
  headless (tools/hl-dwl.sh; foot server with the old Sumi Icons Term, the font renamed over as an
  install does, a new footclient window, then a new server): a running foot server keeps the font it
  started with (windows A, B identical), a new server draws the new one (C). And every icon appended
  moved every ICON_BAR_* twin (they followed the base icons), so the old font answered a new code with
  some other drawing (the to-do's code drew the torii's twin) — in his Super+U since the 22:40 apply,
  and the bar's short-lived modules could do the same. Fix: tools/build-icons.py gives each icon its
  own code — FIRST (U+FE000) + its place, its twin TWIN (U+FE800) + the same place — so an appended
  icon moves nothing (base codes unchanged by this: ICON_TODO still U+FE0CC; twins moved once, to
  FE800–FE8CF). test_bargaps 6/0 (+ "an icon appended moves no other and no twin"); test_generated
  258/0, test_tiles 137/0, test_bar 265/0, test_panel 513/0. A new icon still needs a new foot server
  (his next login) to show; until then it is absent, never a wrong one.
- r27 SESSION RESTART (31 Oct 23:08, 6f00a61 applied 23:07 — 66 s, repair path for the fonts, rc 3: only
  qbittorrent): he had been away since 22:52 (two 60 s idle probes fired, 22:53 and 23:06), no editor held
  changes (the notes' nvim: no modified buffer), his terminal an idle shell; greetd's initial_session (the
  file backed up, restored at once: 0 initial_session lines). New session 23:08:03: dwl, waybar, panel,
  foot server — the new fonts everywhere. VERIFIED LIVE (grim, his session's env): the bar — every twin
  icon from the new range (memory, volume, brightness), the moon and its star beside 28°; quick settings
  (opened by kawa-quick, closed again) — the sixteen crests and the hannya heading, measured with a colour
  tolerance (the panel's glass): moon 6|7·6|6 (248 px), socket 8|8·9|9 (180 px), spool 8|9·7|8 (161 px),
  exactly the kit's; Super+U (kawa-warm system, put away again) — the tab row: pagoda (lit) system,
  seedling, camera, chest, cap.

## (owner 2026-10-31 23:23 — now r27-19k-7, below): quick settings rebuilt FROM SCRATCH - drop the mon sheet entirely, no reuse of any earlier layout; super minimal, super creative; several directions rendered and grilled, the best built, tested, live. Then continue the plan.
- r27-19k-7 WIP (31 Oct 23:50) — quick settings from scratch (the owner's 23:23 note above): three
  new directions rendered both moods (design-r27/quick-r4.py: A the dial 和時計, B the soroban, C
  the koto) and grilled — CHOSEN A, the dial: a square 304 px; the twelve switches' 28 px
  pictures on its hours (theme at twelve, then night light, freesync, saver, dnd, network,
  bluetooth, devices, drives, backup, record, read text — clockwise; no adapter: ten, evenly);
  the meters as twenty 6 px beads each on a circle inside them (brightness up the left, sound up
  the right, reddening at the top); the four actions in the corners (new 28 px drawings: a
  still camera, Fuji framed, the monitor gone dark, the power sign); no heading, no words at
  rest — the face ×3 in the middle; the cursor's item echoed there (its picture ×2, its name,
  its state; a meter's level in display size). Keys: arrows go to the nearest item that way
  (toward()), ↑ ↓ on a meter change it, Tab walks the hours clockwise. Rendered headless with
  the kit (play: rest, theme, night light, the sound arc's lacquer band, saver, power) — both
  moods correct. B lost (a crowded row of tiny icons over rods), C lost (a list in disguise).
  The T21 to-do work of the 22:12 pass is in `git stash list` ("T21 to-do WIP") — untouched.
  Also: CLAUDE.md's new INBOX rule; the inbox's 23:47 entry → T19m (the OCD audit) in the plan.
- r27-19k-7 (1 Nov 00:05) — the dial LIVE on his screen: applied (5 s; crests + kawa-panel), the
  running kawa-panel replaced through autostart's keep (SIGKILL → keep starts the new one: pid
  1442607, parent autostart; SIGTERM would have ended it for good — keep returns on exit 0); a
  60 s presence probe said he was away (00:00:40), then one live shot (kawa-quick, grim, "close"
  into the fifo): the dial at x 1574–1911, y 33–370 (338 × 338, 8 px from the screen's right
  edge, top on y 33), identical to the kit's. Measured (px.py, kit, both moods): the ink's
  margins in the content 2 | 2 and 4 | 4; all 40 beads mirror exactly (rows −82 … +82 round the
  middle); the face centred dx 0.0 dy 0.0; the middle's words centred (0.0, an odd word −0.5:
  its odd pixel right, the rule). Grilled + fixed: the corner actions were 14 px icons doubled
  (blocky beside the hours' drawings) → four new 28 px drawings; the dark hannya's black hair
  vanished on the sumi ground → an outline a picture's pixel wide in edge2 (dark only; the angel
  reads whole on paper). Noted, kept: the panel's ground is the terminals' 0.92 glass — over a
  busy terminal its words show faintly through the dial's open middle (the owner's own
  transparency setting, as every panel's). Docs: design-system §3 (dial, hour, bead rows), §4
  (Dial replaces Tile/Action; the heading's face sentence gone), §11 (the stamp), §13
  (pictures); kawa-panel's docstring; art/crests.txt header; build-icons.py's seal-circle rule →
  a pixel of air all round. Static tests green: test_design_doc 54/0, test_noellipsis 9/0,
  test_contrast 11/0. test_panel being rewritten for the dial (a subagent; 406/107 before).
- r27-inbox (1 Nov 00:10) — the owner's inbox entries of 31 Oct 23:52, 23:55, 23:56 rewritten into
  the plan (headings now "— in the plan: …"): 23:52 → T19m (a) a design research digest of 100+
  sources (grids, Japanese masters, interface masters, platform guides, legibility, TUI and
  pixel craft) into design-system.md, (b) the audit in three full visual passes; 23:55 → T53 (no
  over-engineering: every file against a named standard, every hot path measured) and Fedora 45
  in T41 (tuning redone on 45), T46 (44 → 45 the first release upgrade through the button), T56
  (the ISO on 45) — Fedora 45's final targets 3 Nov 2026 after two no-go slips (Phoronix
  "Fedora 45 Hits A Second NO-GO", linuxiac; the official fedorapeople schedule page refused the
  fetch — confirm on the day); 23:56 → T19n, the master: a fresh reviewer on the strongest model
  gates every task (pass/fail on the evidence) and a trace of every request the owner made.
  Also: the dial's gallery reference box (tools/regress/gallery-expect.json quick → 1574 33 1913
  373); the Learn book's quick-settings row describes the dial.
- r27-21a DONE + VERIFIED kit (1 Nov 00:35) — the to-do beside the notes (owner 18:48: "dead simple —
  items with a checkbox, done items struck through; nothing else"): ~/Notes/todo.md, a line an item
  ("[ ] words" / "[x] words", readable anywhere); the page draws the box over "[ ]" on the notes'
  text column (box-off in the icon ink, box-on muted, the words then muted and struck through);
  space ticks/unticks, enter adds the next (an empty one's enter ends the list), backspace never
  into the box, dd takes one away, an empty item tidied as the window goes; its heading the
  tanzaku + "to-do", its footer "~/Notes/todo.md · space ticks · tab: the notes". Tab turns the
  page TYPING OR NOT (found in the kit: the notes open typing, so a normal-mode-only Tab typed a
  tab into the notes and the items went there) — back on the notes, typing at their end; the page
  hides nvim's ~ under the last line (fillchars eob). Super+U → learning → to-do (kawa-notes
  --todo: turned at once while the window shows, else shown on it). Tests: test_notes 115/0 (the
  to-do steps incl. tab typing on either page), test_menu 589/0. Rendered both moods (kit play:
  notes → tab → typed three, ticked one → tab → notes). Live at his next login: the warm notes
  window is never restarted under him (it holds his page); until then the to-do entry shows the
  notes, nothing breaks. (This work was the 22:12 pass's, stashed for the owner's 23:23 note.)
- r27-19k-7 tests (1 Nov 00:35) — tests/menus/test_panel.sh rewritten for the dial (a sonnet
  subagent, verified here): 613/0 (was 406/107); test_quick 369/0. New: the dial's symmetry (12
  and 10 hours, arcs, corners, the middle), arc_level for every bead, arrow walks + reachability
  over both layouts, toward()'s cone and ties, Tab round all 18, ↑ ↓ on an arc, the middle never
  chosen, hit areas never overlapping. The subagent's review found four faults in the dial's
  code, all fixed: (1) smooth scrolls (a touchpad; GTK's wheel on Wayland) skipped the arcs
  (scroll_by knew only "meter") — the beads now step and sum like every meter; (2) arc_polar took
  the middle as cx − ½ for a pointer's place: the arcs' hit zones sat a pixel up-left and the two
  were not mirror images — the middle is the point cx, cy between the four middle pixels (pixels
  measured at their centres), mirrored hit zones now a test; (3) disc_rows/_DISCS (the seals')
  dead — gone; (4) the docstring's keys (↑ ↓ on the dial's beads). Also its fix of an old case
  that popped the wrong pending call (passed by accident).
- r27-31a DONE + VERIFIED kit (1 Nov 00:58) — the owner's inbox of 00:11: the download progress
  drawn INSIDE the bar's download mark. The tray's inside (10 × 2 px under the arrow) fills from
  the left, a column at a time, its bottom pixel first (twenty steps of 5 %, as a meter's partly
  lit segment): art/icons.txt dl-fill-1…20, drawn with no advance (adv=0) and laid before the mark
  (bar_dl_N, its ink from the pen) in its own ink — the level display's teal (C_TEAL), strong
  while the tile is lit (its icon is teal then) — so the arrow keeps dropping over it. One total
  from every source kawa-downloads already counts (torrents, the browser's partial files, jobs).
  Codes stable (icons.sh: 40 lines added, none moved). Tests: test_downloads 60/0 (new: the fill
  at 2 % none, 5 % one step, 62 % twelve, 99 % nineteen, 100 % twenty; strong while lit; no theme:
  the mark alone). Rendered on the kit's real bar, both moods, at 5/25/62/99/100 %
  (design-r27/dl-fill-t31.png): the fill exactly inside the tray's walls. Live at his next login
  (the running bar holds the old font and the old module). Left in T31: each source proven with a
  real download, the notice's icon, the browser's %.
- r27-19k-7-master (1 Nov 00:40, the master's first review — T19n; Fable, fresh, read-only): VERDICT FAIL —
  2 major, 7 minor, 1 nit, and "alive unmet". FIXED (1 Nov 01:00): (1) the middle's block was centred
  only for an hour (a corner with no state, a meter with a level sat high; no level low) → echo_parts():
  each state's block — the picture by its INK (crests/ink.txt, written by build-icons.py), or the level's
  capitals, then 16 px, then only the rows that have words — centred on the middle; measured on the kit
  per state: dx 0.0, dy 0.0 (+1.0 where a descender hangs: "power", "light"); (3) the four corners were
  four ink sizes → camera redrawn 24 × 20 like the print and the monitor, the power ring 22 × 23 (its
  odd row below), and every corner placed by its ink 2 px from the sides and 4 from top or foot (all four
  alike, measured 2|2 4|4 both moods), its place centred on the ink; (4) the sound panel unreachable by
  the pointer → a click on the middle does what it shows (sound: its panel); (5) the wallpaper corner's
  tooltip doubled the middle → gone, its name the middle's second row; (6) §4's "the words never" vs the
  glass → the sentence made true (what lies under shows at 8 %, everything drawn is opaque); (7) the
  evidence predated the code → tools/regress/dial.sh: a kit play both moods that measures the frame, the
  ink margins, the beads' mirror and the middle's centre per state (held, both moods); (8) dead code
  and stale words out (GROUP, pic(), the "cat" and "tile" words, on_arc() shared by inside and
  arc_level, the mood by the theme's name); (9) ↑ ↓ on a meter with no level move on; (10) the
  theme's hour stated in §4 (never off: the mood, the dial's crown). OPEN (next pass, then the master
  again): (2) the face at rest is the bar's 18 × 18 blown up ×3 (three pixel scales on one surface) —
  draw it for the middle at 1 px, ≥ 54 × 54, four inks, both moods, open, no scaling, no outline;
  ALIVE — the beads lighting one after another as a level changes (§11: 12 ms a bead) and the record
  hour moving while it records. Tests: test_panel 616/0 (new: the middle's centre per state from
  echo_parts, the corners' ink margins, the click on the middle), test_design_doc 54/0.
- r27-19n (1 Nov 01:00) — the trace (a sonnet subagent; .claude/notes/master-trace.md): 332 requests
  (r24 46, r25 22, r26 36, r27 228 incl. 8 inbox) — done 120, wip 45, todo 138, dropped 29; flags:
  UNPLANNED 4 (r24-27 screen sharing → T59; r24-40a the boot menu's orange bar → T59; r24-41b the
  update pulls the repo → T45; r27-rule-2 his fk-remote page → T42), UNPROVEN 7 (r24-37, r25-10,
  r26-8, r26-14, r27-1427-2/-4/-8 → T51's verification list), STALE 8 (the saver → lock freeze ×3 →
  T20; T01b's efi_pstore; quick settings ×3 — T19k-7 open; contrast's last two) — all folded into
  the plan. Left in T19n: the master's own check of the trace's gaps; keeping it current.

## (1 Nov 01:00 marker: done — T19k-7 passed the master at 01:55; T19m (a) done 01:45)
- r27-19k-7 alive (1 Nov 01:05) — the master's "alive unmet", done: (a) a level changing on the dial
  lights its beads one after another, BEAD_MS = 12 a bead (§11's rule, now built for the beads):
  Panel.shown holds the beads as drawn, glide() steps them toward the level and redraws that arc
  alone, never at an open and never while closed, no timer when nothing moves; (b) while a recording
  runs and quick settings shows, the record hour's reels turn — two frames (art/crests.txt record /
  record-2: the hubs a cross and a cross turned an eighth, swapped between the two reels), 250 ms each,
  that hour and the middle redrawn; it stops at its first frame when the recording or the panel goes.
  Tests: test_panel 624/0 (the glide's steps up and down, none at an open or while closed; the reels'
  frames, their stop), test_design_doc 54/0. §4 and §11 say it.
- r27-19k-7 face (1 Nov 01:35) — the master's finding (2), done: the dial's middle at rest shows the
  mood's face DRAWN FOR IT, 56 × 56 at 1 px — no scaling, no outline, one pixel scale with the hours:
  the hannya roaring (ringed gold horns, brows sloping up in anguish, glaring all-gold eyes, a fanged
  grin in lacquer with gold lips) and the tennin serene in a gold nimbus (a pinned bun, long hair, the
  urna, gold irises, a small lacquer smile, a gold-edged collar); drawn on the left half and mirrored
  (tools/build-themes.py FACE_BIG → themes/*/face-big.png; the generator kept as
  design-r27/faces-56.py, three rounds grilled: tiger-striped forehead and sleepy eyes → glaring eyes,
  thick horns, a solid tooth band with fangs). Tested: both PNGs 56 × 56, mirror images to the pixel,
  four inks (test_panel). The dial check (tools/regress/dial.sh) caught a real fault before it went
  live: the record hour's frame helper was named frame(), shadowing the drawing's frame() — the
  panel's hairline and shadow vanished (TypeError in draw) → renamed turned(); a static guard now
  fails any two functions sharing a name in one scope. test_panel 625/0; dial.sh held both moods.
- r27-19k-7 DONE + VERIFIED (1 Nov 01:55) — the master's re-review: VERDICT PASS (all ten findings
  and "alive" closed, checked by its own renders: "100" centred 0.0/0.0, the faces 56 × 56 mirror-
  exact, four inks). Its residue, closed now: the dial check's "arc" shot was devices → the pointer
  over a bead (hovered only: a click would set the real brightness); the power corner's place was a
  pixel off the mirror → the four places flush with the corners (mirror images), each ink centred
  in its place (the round power sign's ink 3 | 3 from the edges against the framed 2 | 4 — a
  round form's overshoot); a recording stopping while the dial shows left the reels turned → back
  to the first frame, redrawn; the reels at 6 frames a second (§13's rule; REEL_MS 167); the
  middle's click a disc (r < 78), not its square; §11's row says beads only; tiles_of a lookup;
  the grill written (grill-r27.md "T19k-7") with the three directions' renders kept. test_panel
  626/0; dial.sh held both moods (frame, beads, corners, the middle at rest/hour/arc/corner).
  Noted for T19m/T52: the glide on the frame clock, the glass over busy windows, dial.sh into the
  regression runner. Full suite (01:16–01:36): every area green but installer/test_report 117/1 —
  "the shell probe left a stopped bash behind" (a process left by the run; re-run alone next pass).
- r27-19m (a) DONE (1 Nov 01:45) — the design research (a sonnet subagent; .claude/notes/design-research.md):
  138 sources verified (grids/typography 19, Japanese masters/JLREQ 21, interface masters/research 25,
  platform guides 19, accessibility/legibility 19, TUI 11, pixel art/bitmap fonts 13, motion 11), 43
  rules (21 followed, 10 in part, 2 contradicted, 10 unsaid). Its five shortfalls are T19m (b)'s first
  items (plan): dark-mood contrast by APCA (dark text Lc 68 < 75; muted, accent_text Lc 38 < 60 — the
  owner's own complaint about dark highlights), a legibility floor (x-height ≈ 0.2°), 24 px pointer
  targets, Japanese beside Latin (JLREQ), a closed spacing scale and the 2 : 1 proximity rule.
- r27-tools (1 Nov 01:55) — the full suite's one failure (installer/test_report "the shell probe left a
  stopped bash behind") was a stray of my own kit run: a bar module (the repo's kawa-nowplaying,
  HOME /tmp/kit.…, XDG_RUNTIME_DIR /tmp/hl-dwl.…) left stopped since 23:49 — killed; test_report 118/0.
  tools/hl-dwl.sh now reaps on exit every process whose environment names its run's own runtime dir
  (stopped ones too); a kit run after it left nothing.

## (1 Nov 01:55 marker: superseded below)
- r27-19m (b) groundwork (1 Nov 01:50) — tools/contrast.py --apca: APCA-W3 0.0.98G-4g beside WCAG for
  every highlighted pair and every role's words on the grounds (report only, exit 0; the WCAG check
  unchanged, test_contrast green). Verified against APCA's reference values (black on white 106.04,
  white on black 107.88, #888 on white 63.06, white on #888 68.54 — exact). The "before" saved
  (.claude/notes/apca-before.txt): dark text Lc 68.5 (< 75), muted 38.3 and accent_text 37.9
  (< 60), faint 16.9 (< 30) on the ground — the light mood passes all (text 85.6, muted 63.9,
  accent_text 62.4); 12 pairs under in all, incl. the light workspace seal's black numeral on brick
  red, Lc 23.7 (WCAG 3.08). Next pass sets the dark roles by it (render every surface before/after).
- r27-19k-7 glide on the frame clock (1 Nov 01:55) — the master's minor (4): the beads' glide ran on a
  12 ms GLib timer, landing beads 1 or 2 refreshes apart at 144 Hz → now on the panel window's frame
  clock (UI.frames: GTK's tick callback; Panel._glide(t) steps a bead on the first frame 12 ms or more
  after the last — every second frame at 144 Hz, every frame at 60 Hz). Proven in real GTK under the
  headless dwl on the real GPU (tools/hl-dwl.sh, a probe with the same callback): frames every
  ~6.05 ms there, steps exactly two frames apart (12.07 ms) after the first; test_panel 626/0 (the
  steps at 144 Hz on frames 0, 2, 4; at 60 Hz one a frame). §11 says it.
- r27-19n the master's trace check (1 Nov 02:00; Fable, read-only): TRACE: GAPS — no request missing a
  row; ten status/coverage gaps, all folded into the plan as accept lines (T38: the LG's real power
  cycle over DDC and its button, the bar's brightness reading the LG's real value, the connector named
  and re-proven after the iGPU move; T19: anim-check for layer surfaces, warm windows, lock → desktop,
  greeter → session — the menus' ~200/~160 ms came from a recording; T18: the fetch art as the
  old-master art; T41: kdump decided with its cost; T45: conf/secrets/*.local survive apply and update;
  T44: held packages retried only inside the next press; T35: qBittorrent on the host decided; T52:
  the TV icon frame by frame; T19m: the coherence pass's "done" reopened). Its one most important
  thing not done: the one-button update (T43–T45; Fedora 45 on 3 Nov) → ordered right after T19m (b)'s
  first item.
- r27-52a (1 Nov 02:00) — tools/regress/run.sh: every never-again check in one run (the kit's options
  only to the checks that take them). First run: 8 held, 3 stale — bar-burst could not take kit options
  (now passed none); bar-geometry knew nothing of the bar's 18 px face (now: rows 5–22, ≥ 6 px of paper,
  its odd pixel right — the hannya's ink 16 wide, the tennin's 18); menu-first-click expected the old
  vermilion cursor (now the lacquer, select, since r27-19k-2). All ten held after (bar-burst, bar-geometry,
  calendar-middle, dial, level-display, menu-first-click, one-popup, warm-exit, wash, window-frame).

## (1 Nov 02:05 marker, superseded below): the inbox first. Then T19m (b) item 1 — the dark roles by
## APCA (candidates in the plan's T19m: text Ecru → Ivory Buff 0.77 #e1ca9f; muted 45–48; accent words
## in accent_hi #f1713b; faint #887654) — gallery before/after both moods, tools/regress/run.sh, the
## master. Then, by the master's order, the one-button update: T43 (research) → T44 (design) → T45.

- r27-19m-b1 (1 Nov 02:20; the master's review pending) — the dark words set by APCA (tools/wada-palette.py dark()), on
  every ground words stand on (ground, surface, key, the bar's tile, a marked row's edge): text Ecru → Ivory
  Buff 0.9 #e7cfa1 (Lc 68.5 → 78.1 on the ground, 75.9 on edge), muted Ecru → Ivory Buff 0.2 #cab596 (38.3 →
  62.9; 60.8 on edge), faint LBO → Ecru 0.25 #907e5d (16.9 → 33.8), accent_text = accent_hi = Jasper Red →
  Apricot Orange 0.6 #f27740 (37.9 → 47.5; was 0.5 #f1713b, 44.8 on a hovered GTK button). strong unchanged
  (88.0: the lacquer's 7.28 : 1 stays); the light mood unchanged (all pass: text 85.6, muted 63.9, accent 62.4,
  faint 42.7) — the two moods' steps now within a few Lc. The plan's earlier candidates (text 0.77 = Lc 75.0
  exactly, muted 45–48) rejected: 75.0 left no margin on the key and the tile (75.98/75.67 at 0.85 were the
  first to pass everywhere; 0.9 passes the edge too), and muted 45–48 is under the research's own rule 14
  (≥ 60 for words read) — the hierarchy is kept by the steps (strong 88 · text 78 · muted 63 · faint 34).
  Vermilion is no reading ink on sumi (no red reaches Lc 60 there): the rule, in §1 and in the code — an
  icon, a mark, a short word that needs you; never a sentence. The three sentences that were vermilion now
  draw a vermilion cross before their words (kawa-together's "not a server …" row and its header message,
  kawa-git's said()); the calculator's answer row at rest: strong. tools/contrast.py --apca is a gate now
  (ROLE_LC: 75/75/60/45/30 on ground, surface, key, tile; exit 1 under; the seal's black numeral ◇ shown,
  kept by his word: Lc 40.5 dark, 23.7 light — a cream numeral would read 49/76, not taken: he said black).
  test_contrast 16/0 (+2: the gate; the old text fails it); design-system §1 rows and the table (Lc · ratio,
  the bar's tile added) — test_design_doc 54/0 checks both. Copies moved with the roles: dwl's HAIR default
  e7cfa180 (text at 50 %; the running frames already read it from dwl.colors), MangoHud, lazygit's inactive
  border (now faint), fetch's art inks (each to the nearest palette tone by OKLab L); the dark cursors rebuilt
  (their ":" ink is muted) — test_generated 258/0. Rendered before/after, both moods, every surface
  (tools/gallery.sh on the kit; the foot surfaces again with --themes from a trial palette, since the kit
  links foot's colours only through --themes): /dev/shm/r27/apca-{before,after,after2}, the dark halves
  stacked in /dev/shm/r27/apca-ba/. Looked at: Super+U status (labels and values both readable, the "1 to fix"
  mark lighter), the bar (empty workspaces' numerals visible yet recessive; the date's slashes and the day's
  kanji a lighter vermilion, still the seal's family), the calendar (the other month's days readable, still
  apart), notices (the body clearer), quick settings (the off crests clearer; on/off still by hue), Super+N's
  footer (was hard to read, now plain), yazi/terminal (the text a step brighter). Verified by: contrast.py
  (WCAG 0 under, APCA 0 under), the tests above, the renders.

- r27-42-strays-a (1 Nov 02:50) — Super+U's tab record (fedokawaii-tab.XXXXXX in $XDG_RUNTIME_DIR, from mktemp)
  leaked whenever its menu was killed rather than ending (the warm window restarted by an apply or a theme
  switch): 13 found in /run/user/1000 between 22:14 and 02:31. Now one record per menu by its pid
  (fedokawaii-tab.$$), and each start removes the records whose menu is gone (kill -0); the warm window's
  TERM trap stays. tests/engine/test_menu.sh 590/0 (+1 case: a dead pid's and an old mktemp record swept, a
  live menu's kept, its own removed at its end; curl stubbed to fail there — an earlier case's curl
  stand-in (fzf's socket) answers every call, so a menu run's background release check recorded Fedora 45
  as out and the next case's rows changed: the race behind its first two failures).
  Also seen (for T42/T59): every SIGUSR2 reload of waybar leaves 3–4 zombie children (comm "waybar") that
  waybar never reaps — 7 from 01:57/01:58, 3 more at 02:33.
- r27-19m-b1-master (1 Nov 02:45; Fable, fresh, read-only): VERDICT FAIL — 2 major, 5 minor, 2 nits; it
  verified the APCA function against the reference pairs, recomputed the table, saw the gate fail the
  old text, and found the live PC on the new palette. FIXED (1 Nov 03:05):
  (1, major) vermilion still carried sentences: lib/common.sh's die(), fail() rows, the verdict line and
  dnf's failure lines, setup.sh's and theme.sh's error traps, check.sh's NOT READY, theme.sh's drift
  line → the ✘ vermilion, the words in their own ink; the lock's message (gtklock #error-label) strong;
  Neovim's diagnostics: the sign and the underline in the severity's ink, the message muted at the
  line's end and text in the float; the mixer's default device strong ("a state that is on"); kept by
  rule and written in §1: short values that need you (the bar's memory when high, a running timer,
  "1 to fix"), links (Qt, GTK).
  (2, major) build-art.py's outputs (the boot splash's words, the padlock, the seals) still held the old
  tones → rebuilt; tests/static/test_generated.sh now rebuilds them on a copy and compares byte for byte
  (plymouth, the saver's glyphs.h, gtklock.mo too) — 261/0.
  (3) the old masters' ramp named the retired roles → three art tones in the palette (art_umber 65583f,
  art_olive 9a8767, art_kinari d4bf9a: the dark ramp's even steps), build-masters.py reads its ramp and
  accents by token name; fetch's art inks back on those exact tones; the saver's sashiko thread is art
  too: art_olive (its look before the change, exactly).
  (4) the steps: strong → Sulpher Yellow #f5ecc2 (Lc 94; text 78, muted 63, faint 34: ≥ 15 between
  neighbours, written in §1; the light mood's strong over text by hue and place — both near-black ink);
  the words of apps (GTK 3/4, Qt, zathura, imv's overlay) take text in both moods (was strong in the
  dark: now Lc 94 would glare at length); the lacquer's words 8.0 : 1 (was 7.3).
  (5) the ink's hue: Jasper Red → White 0.2 #f47b58 (h as the seal's; Lc 49 ground, 48 key/tile) over
  → Apricot 0.6 (h 43, toward the flame) — rendered side by side with the seal in the bar, a notice and
  Super+U (/dev/shm/r27/trial-*.png): the tint reads as the seal's red lit, the orange as a second red.
  (6) the gate covers the band behind a selected line (the terminal's black, ansi0) for a row's words
  (text, strong); light text read 73.9 on edge → the light mood's ansi0 a step lighter (Sulpher Yellow →
  Isabella 0.4, e2cfa0: text 75.6), frames keep edge; muted on a band is not a row's ink (§1).
  (7) the saver and the lock rendered before/after in the kit (/dev/shm/r27/ba-{lock-typed,saver}.png;
  no wrong password typed — his account's failure count untouched): the lock's keys and date clearer,
  the padlock and seal on the new inks; the saver's stamps had turned to the ink's tint (before, both
  reds were one hex, so its code's choice never showed) → src/kawa-saver: a stamp in the seal's red
  (accent), the clock's 時 in the ink — rendered again: stamps eb5324, 時 f47b58, thread 9a8767. The
  greeter draws from the same gtklock.css, padlock and seals (system/kawa-greet): not rendered apart.
  (8) §1 says why Lc 75 holds a 14 px regular pixel face (every stem a whole pixel at full coverage).
  (9) the 02:21 run's test_syntax 684/1 was my own bin/__pycache__ (a py_compile check) — removed, 685/0.
- r27-19m-b1-master-2 (1 Nov 03:20; the same master, resumed): VERDICT PASS — every finding of the first
  review checked closed by its own reads and runs (a pixel scan of every tracked PNG finds no retired
  tone; the live bar and colors.sh/saver.conf equal the repo; gates 0 under). Its residue, closed now:
  (1) the ≥ 15 Lc step between word inks is a gate (contrast.py --apca: strong over text 15.9, text over
  muted 15.2, muted over faint 29.1 on the dark ground; test_contrast 18/0, +1 case: strong back at the
  old Lc 88 fails); (2) colorscheme.lua says why the base Diagnostic* groups keep the severity's ink
  (only short marks link to them); (3) one GTK dialog and zathura shot before/after in T19m (b)'s pass 2.
- r27-19m-b1 DONE (1 Nov 03:20; master PASS) — the dark words by APCA, both moods gated; live since 03:08.
- r27-47/48 (1 Nov 03:25) — T43 research: batches 1–4 and 6 in (.claude/notes/update-research.md, 374 distinct
  links after merging; five sonnet subagents, each on its own file, merged by script), the synthesis (28
  failure modes ranked by frequency × damage, each sourced); batch 5 (rollback specifics) still running.
  T44 design drafted (.claude/notes/update-design.md): candidate-first — the transaction stored once
  against the running root, replayed into a writable snapshot (checked, bisected, fixed there), then
  replayed on the running root; the layout (home, log, fk subvolumes); the flow (phases 0–8), 40
  failure modes with their T49 tests, 32 attacks. Checked on this PC (dnf5 5.4.6, its own man pages:
  dnf5-replay(8), dnf5-upgrade(8)): `--installroot` + `--use-host-config`, `upgrade --store=DIR`
  ("instead of running it"), `replay DIR` ("the exact same operations … an error in case of any
  differences in installed packages or their versions"; the directory may hold the packages) — the
  mechanism exists. The master reviews T43 + T44 now; T45's build order is in the plan.
- r27-49-exp1 (1 Nov 03:25; the harness VM, state "built" = a full fedokawaii install of 27 Oct, the PC's
  layout: subvolume root, /boot XFS) — the candidate-first core proven: 57 pending updates (kernel
  7.2.13 among them) `dnf5 upgrade --store` (17 s, 56 packages, 455 MB: transaction.json + packages/);
  a writable snapshot of root on the top level with a scratch tmpfs /boot; `dnf5 --installroot=cand
  --use-host-config replay` rc 0 in 44 s — the new kernel's vmlinuz, initramfs and BLS entry only in
  the scratch /boot (the real /boot untouched), SELinux labels right (shell_exec_t); then `dnf5 replay`
  on the live root rc 0 in 34 s; `rpm -qa` of candidate and live: the same 1,973 packages; each root's
  dnf5 history its own. Found: (1) replay SKIPS OpenPGP checks for stored packages ("skipped OpenPGP
  checks for 56 packages … @stored_transaction(…)") → the design verifies every stored package with
  `rpmkeys --checksig` against the system's keys before any replay; (2) a bare chroot lacks /dev,
  /proc, /sys: dracut falls back to a generic image, grub2-probe/editenv complain → bind them into the
  candidate (as kawa-snap's inside() does) so its initramfs is the host-only one that will boot.
  Output kept: /dev/shm/r27/vm-candidate-exp.txt. VM stopped (revert to "built" before the next run).
- r27-47-master / r27-48-master (1 Nov 03:36; Fable, fresh, read-only): T43 PASS (436 links, 11/11 spot
  checks real and accurate, the synthesis' 28 rows each cited) with nits; T44 FAIL — 9 major, 11 minor, 2 nits.
  FIXED (1 Nov 03:50), the design revised once with batch 5 folded in:
  the candidate's mechanics — the transaction stored once on the live root (`--store` does not run),
  replayed into the candidate inside a container (`systemd-nspawn`: dracut and kernel-install get /proc,
  /sys, /dev; nothing reaches the host's udev or systemd), `--disable-plugin=actions` on every candidate
  run (installroot(7): dnf5 loads the host's plugins — the candidate would have snapshotted the live root
  and armed the guard), a writable snapshot of home bound at /home for the config checks and the fixer,
  the dGPU's render node by path; replay's own "error on any difference" is the same-transaction proof;
  automatic restores only once /home is its own subvolume (before: offered); B5's flat layout
  (snapshots, home, log, fk at the top level; never /var/lib whole) and §3.1 the hardened restore (one
  exch, a sync before /boot, the default set last, no `delete -R` over a subvolume, no blanket relabel);
  a bootloader row (replayed last and apart, previous EFI files kept, never downgraded; Secure Boot off
  here); pins released only by a closed probation and held by snapper itself (no cleanup algorithm),
  timeline off; the one-kernel rule interlocked with probation; the resume unit's session-free subset
  and "restored once"; WAIT a 7-day floor + a green pre-flight; rpm --verify -a; nvim checkhealth;
  machine facts stated (no LUKS, no Flatpak, Secure Boot off); /var/lib/fedokawaii/update; the cost of
  online (≈ 2× the transaction's time). Research nits: the STRATUS bullet's network-repair paper
  labelled, a secondary source marked, synthesis rows 19 and 24 given their own citations. Plan: T45's
  gates and build order, T48's first items (the hardened restore, the flat layout, the split), T49's
  scripts = the design's §5 test column (44 rows). Back to the master.
- r27-42-strays-a live (03:08 apply): the 13 stale tab records swept; one left, the warm menu's own pid.
- r27-49-exp2 (1 Nov 03:41; the harness VM from "built") — the revised candidate (design §2.1) proven: the
  pending set stored on the live root (56 packages), each package `rpmkeys --checksig` good (0 bad); a
  writable snapshot of root replayed INSIDE `systemd-nspawn --register=no --private-network` (tx bound
  read-only, a scratch tmpfs bound at /boot, `dnf5 --disable-plugin=actions -C replay /tx`): rc 0 in 33 s;
  in the scratch /boot the new kernel, its BLS entry (root=UUID, rootflags=subvol=root, our arguments)
  and a host-only initramfs (dracut's hostonly-files inside, amdgpu/btrfs present, 52 MB) — the bare
  chroot's generic fallback gone; the live root untouched by the candidate run: snapper's snapshots 3 → 3
  (the actions plugin off), no guard marker, no new kernel file in the real /boot. Noise: gpg "insecure
  memory" lines inside the container (harmless; silenced in T45). Output: /dev/shm/r27/vm-candidate-exp2.txt.
- r27-48-master-2 (1 Nov 03:51; the same master, resumed): VERDICT PASS for T43 and T44 — all 22 findings
  verified closed, the VM trial accepted as evidence. Its 4 minor + 5 nits closed at once (03:58): phase 5
  is the replay of the stored transaction; the bootloader as a second stored transaction (tx2: grub2-efi*,
  shim*), live only after tx1 is green; kernels: installonly_limit stays 2, no kernel transaction while a
  probation is open (setup.sh's one-kernel rule kept; §3.1, attack 24, plan T48); the candidate's
  /etc/kernel/cmdline a phase-0 precondition (kernel-install ignores /proc/cmdline in a container); the
  actions plugin's reason inside nspawn, the render node's DeviceAllow, the candidate's labels never
  copied out; row 14's test a stub libEGL; attack 17 decided: signed release tags, the key in the
  toolkit, `git verify-tag` before the re-exec; RuntimeWatchdogSec armed only during a probation;
  §5 rows and §6 attacks renumbered in order (1–44, 1–35).
- r27-47 DONE, r27-48 DONE (1 Nov 03:58; master PASS) — T43, T44.
- r27-52a-restore (1 Nov 04:20; T48 FIRST (1), wip — the code and its stub tests; the VM's cut-point proof
  and the master next pass) — system/kawa-snap restore hardened per update-design.md §3.1 (B5's three
  unsafe spots): ONE `exch` (util-linux 2.41.5, renameat2 RENAME_EXCHANGE) instead of two renames —
  never a moment without `root`; `btrfs filesystem sync` before and after it and after the moves; the
  copy's kernels added with its /etc/sysconfig/kernel at UPDATEDEFAULT=no for the add (restored after),
  the default set once, last (grubby after the exchange); nested subvolumes (the snapshots …) moved only
  after the exchange (a cut between leaves them in root.new — and a leftover root.new holding a
  subvolume is never deleted: said, nothing changed); deletions `--commit-after`, never `-R`; the
  copy's /.autorelabel and /system-update removed before it can start; root.old kept, the one before
  with its time, at most two (sorted by the time suffix — the top path itself has a hyphen); the kernels
  the restored system lacks no longer removed at once: setup.sh's new orphan_kernels_out (the boot's
  kernels run, once the start reached the desktop: boot_success=1) takes kernels with no modules in
  /usr/lib/modules out with kernel-install remove. Tests: tests/engine/test_snap.sh 114/0 (+5 cases:
  the exchange and the syncs, UPDATEDEFAULT off during the add and back, the default after the
  exchange, the copy starting clean, a failing exchange changing nothing, a held root.new never
  deleted, two timestamped kept; the fixture's top path now hyphenated like the real one);
  tests/installer/test_upkeep.sh 227/0 (+1: orphans go only after the desktop, the running kernel's
  entry kept; a kernel-install stand-in in tests/installer/stubs); test_deps (exch: util-linux,
  @core), test_pipefail (no pipe into head) green.

- r27-52a-restore (cont., 04:20): a restore cut between the exchange and the moves (the restored system
  running, the snapshots still inside root.new) is now finished by the next `kawa-snap restore`: the
  tail factored into finish() (moves across, root.old, the timestamped ones, sync), run first when a
  leftover root.new holds a subvolume, then said ("was finished … run again"); the snapshot's existence
  checked only after that. test_snap 118/0 (the case built as the real cut leaves it).

- r27-52a-restore PROVEN in the VM (1 Nov 04:16; tools/vm-inject/restore-cut.sh f44, exit 0): for each of
  the six steps a fresh VM ("built"), this repository's kawa-snap, a snapshot, the running root marked,
  the restore cut by an instant restart (sysrq b, nothing synced: KAWA_SNAP_CUT, a seam honoured only
  when set). Every start whole: copied, kernels → the marked system runs, its snapshot listed, the
  kernel's modules there; exchanged → the marked system (the unsynced exchange simply did not happen:
  atomic either way); moved, renamed → the restored system runs and the next `kawa-snap restore`
  finished the cut one (the snapshot listed again: "1*"); defaulted → the restored system, all in
  place. Logs: /dev/shm/r27/restore-cut/. Not yet on the PC (the master first).

- r27-19m-b1 owed shots (1 Nov 04:25; the master-2's nit 3): a GTK 3 dialog and zathura rendered before
  (worktree f958bc3) and after in the kit, dark: the dialog's title and words now text (#e7cfa1) where
  they were strong — a hair warmer, read as well (/dev/shm/r27/ba-gtk.png); zathura draws the PDF's own
  page on the ground, its words only in its hidden status and input bars — nothing visible moved.
  Found for T19m's audit (pass 2): a dialog's two buttons are the same lacquer — the suggested one
  ("Save") does not stand out from "Cancel"; GTK's default action should be the lacquer, the others
  quiet (key fill, text) — fix with the GTK theme in the audit.

- r27-19m-gtk-default (1 Nov 04:30; T19m audit item, found by the owed shots) — two lacquer buttons in a GTK
  dialog: GTK 3 moves the default (the button Enter presses) with the focus, and our theme filled both
  `.default` and `.suggested-action`. By the design system's grammar the lacquer is the keyboard's cursor
  (one at a time, as in the menus): now only `.default` is filled; an app's suggested action not under
  the cursor is framed in the lacquer, its words bright (tools/build-themes.py square_rules, GTK 3 and
  4). Rendered in the kit (dark): a focused Cancel filled, a suggested Save framed — one filled button
  (/dev/shm/r27/gtk4-dialog.png). test_generated 261/0, test_contrast 18/0, test_theme 263/0. The
  dimmer label seen once was the unfocused dialog (GTK's backdrop state; adw-gtk3 dims it); focused,
  both buttons' words measure #f5ecc2 (strong) — adw-gtk3's hard-coded white never reaches the screen.

- r27-52a-master (1 Nov 05:12; Fable, fresh, read-only; the full verdict kept in
  .claude/notes/master-T48-verdict-1.md): T48 FIRST (1) FAIL — 5 major, 10 minor, 8 nits. The exchange
  and its atomicity proven, `.snapshots` carried after it, a cut run finished by the next; but: (1) /boot
  (XFS) and the ESP not synced before the exchange; (2) the default kernel set only after `finish`
  (seconds of commits), the recovery path never sets it, no self-heal when the running kernel has no
  modules; (3) `setup.sh --kernels` inside a boot-menu snapshot boot (systemd.volatile=overlay, the
  real /boot rw) removes the live system's kernels; (4) the VM proof never ran a kernel add (the
  snapshot had the running kernel: "KERNEL ok" by construction), no `restore old`, RUNNING not
  asserted; (5) on the PC /home is inside root: a restore takes his files back while Super+U says
  "your home stays as it is". Minors: a kept ex-root named root.new deleted by the next run; "kernel
  in /boot" = vmlinuz only; no lock; sync failures swallowed; root.old-<ts> entries in the boot menu;
  /etc/system-update; restore impossible from a snapshot boot (overlay /); undo after added kernels;
  a half-bound chroot reused; missing tests. The ledger's "PROVEN … every start whole" holds only for a
  same-kernel restore. Being fixed now (main); the PC keeps the old kawa-snap until the master passes.
- r27-49a (1 Nov 05:45; T45 (a), wip — on branch t45 (07b7058, pushed), NOT on main and not on the PC:
  the candidate must be proven in the VM first, T45 (c)) — lib/update.sh: the button's run as a state
  machine (start · fetch · candidate · snapshot · replay · steps · check · end), the phase written before
  each begins (a full disk fatal only once the running system is about to change); the transaction
  stored once (`dnf5 upgrade --store`, dnf5-upgrade(8)) and tried in a copy (a Btrfs snapshot of / on the
  top level, `systemd-nspawn --register=no --private-network`, `--disable-plugin=actions`), checked there
  by lib/cand-check.sh (our builds' libraries, a new kernel's entry root=/rootflags= and its image's
  btrfs/amdgpu, `foot --check-config`); red → halves in fresh copies (⌈log2 n⌉ rounds; two halves green
  alone but red together held together), the culprits held with `dnf5 versionlock exclude NAME-EVR`
  (dnf5-versionlock(8): only that version) and recorded in UPD/holds with the version held at (let go
  once the package moved on); the stored packages' signatures (`rpmkeys --checksig`, every package must
  answer OK); the snapshot pinned (`snapper modify -c ''`); the same transaction replayed live
  (dnf5-replay(8): the same operations or an error); only new reds count (verify writes
  last-verify-fails, the baseline); red → the set held, the snapshot offered (his files inside /) or
  restored (kawa-snap, once /home is its own subvolume); a run cut in its transaction finished when
  whole (each stored package at its new version, nothing twice, dnf check clean), undone when not; the
  report in UPD/report + a notice. Decided against the design's rpm WAL checkpoint: a Btrfs snapshot
  is one instant and SQLite recovers its WAL from it as after a power cut (no transaction runs under
  the lock). Tests: tests/installer/test_update_flow.sh 87/0 (every branch), test_upkeep 223/0 (its
  update cases on the new flow), test_verify 171/0, static 11/11 (pipefail: sed -n 1p, not head).
  Stubs changed (dnf, rpm, rpmkeys, btrfs + new mountpoint, systemd-nspawn): the WHOLE installer area
  still to re-run on t45 before it merges. Next on t45: (b) phase 0's remaining facts, (c) the
  candidate in the VM.

- r27-52a-fix (1 Nov 06:05; T48 FIRST (1), the master's findings — code and stub tests; the VM proof
  re-run with two kernels and the master's second look next; NOT on the PC yet) — system/kawa-snap:
  (1) /boot and the ESP synced (`sync -f`, checked; else undone) before the exchange; (2) the default
  set at once after the exchange and its sync (grubby, then `sync -f /boot`), before the moves; a
  restore cut after its exchange is finished by the next run WITH its default, and that run does
  nothing else (exit 0, said); setup.sh `kernel_match` (start-up run): a running kernel without
  modules in / → the newest whole kernel that has them the default + a notice; every boot image
  loads xfs and vfat itself (/etc/dracut.conf.d/fedokawaii.conf force_drivers — dracut.conf(5):
  "loaded early via modprobe"), so such a start still mounts /boot; (3) `setup.sh --kernels` only
  on the system itself (on_the_system: FSROOT = /root as fstab mounts it, no systemd.volatile=overlay)
  + ConditionKernelCommandLine=!systemd.volatile on the unit; (5) a restore while /home is inside
  root is refused unless `--with-home`; Super+U says "home goes back to then too" and passes it on
  his yes (and "home stays as it is" once /home is split). Minors: a copy carries a mark
  (.kawa-snap-copy) — a leftover root.new with it is removed, without it it is the system that ran
  (finished, never deleted); the system that ran never left as root.new (root.old, else
  root.old.d/TIME-PID); "whole" = vmlinuz + image + entry; one restore at a time (flock
  /run/kawa-snap.lock; `pre` waits ≤ 10 min), none while dnf5/dnf runs; syncs checked and said;
  root.old's predecessors in root.old.d (out of grub-btrfs's list: IGNORE_PREFIX_PATH; root.swap
  dropped); /etc/system-update stripped; restore from a boot-menu snapshot (/ an overlay: root=UUID=
  and rootflags=subvol= from /proc/cmdline); undo takes the kernels this run added out again; a
  failed bind unbinds; nits: the power-cut seam also needs /run/kawa-snap.cut, `mv --no-copy`,
  grubenv's stale tmp_saved_entry dropped before the adds, missing parent folders made with the
  owner and mode of the ones that ran, "no system before the last restore is kept", a failed delete
  said as such. Tests: tests/engine/test_snap.sh 158/0 (+40: the order sync -f → exch → grubby →
  sync -f → the moves, the mark both ways, the recovery's default, --with-home both ways, the lock,
  dnf running, the failed rename, vmlinuz-only, whole left alone, undo's remove, restore old with
  none, the overlay boot, root.old.d kept two and listed nowhere, /etc/system-update), test_menu
  594/0 (+1: home inside → said, --with-home), test_upkeep (+3: no kernel rule in a snapshot boot
  either way, kernel_match, the dracut drivers), test_deps 197/0 (grub2-editenv: grub2-tools-minimal).
  The installer harness's findmnt stub answers FSROOT now: the whole installer area re-run.
  tools/vm-inject/restore-cut.sh rewritten for the master's finding 4 (two kernels: S has A, the
  system B with A removed; seven cut points incl. one during the add, then restore old; every state
  asserted, every check's output logged). Design §3.1 "As built" added; §4 phase 4: no rpm
  checkpoint (a snapshot is one instant).

- r27-52a-vm2 (1 Nov 06:40; T48 FIRST (1), the master's finding 4) — the restore proven in the VM with
  ANOTHER kernel (tools/vm-inject/restore-cut.sh, rewritten): the state "two-kernels" made once from
  "built" — snapshot S=2 under kernel A 7.2.11, B 7.2.13 installed and started, A removed from the
  system (asserted gone) — so each restore of S puts A back through kernel-install in the copy (dracut
  ≈ 15 s, measured 06:33:56→06:34:11). Eight runs, each from that state with this repo's toolkit and
  kawa-snap: cuts (sysrq b, gated by KAWA_SNAP_CUT + /run/kawa-snap.cut; the guest's page cache lost —
  the model of a lost plug for the OS, the host's cache not modelled) after copied, kernels, exchanged
  (after its sync: the restored root came up under B "7.2.13-nomod", setup.sh --kernels' kernel_match
  made A the default, one restart → A with its modules), defaulted, moved, renamed; adding (a watcher
  inside the VM restarting it 3 s into dracut — /boot then had nothing of A, the system before ran
  under B); old (a whole restore, a start, restore old, a start: the marked system under B again).
  Asserted per run and logged (/dev/shm/r27/restore-cut/*.log): start; the system running (marked
  before the exchange, the snapshot after); the running kernel's modules; the next restore's exit (a
  cut after the exchange finished by it with its default, exit 0; before it, a whole restore + a
  start); at the end the restored kernel the default, whole in /boot (image + entry, read as root),
  root.old present, no root.new, kawa-snap list answers. ALL EIGHT OK. Found by it and fixed: (1) a cut
  right after the copy left an unmarked root.new the next run took for the system that ran — the copy
  is made as root.copy, marked, then renamed (a leftover root.copy always removed; root.copy in
  grub-btrfs's ignore list); (2) the exchanged seam sat before the sync, so the kernel window was never
  hit — moved after it. Harness-only: virtio_net forced into the VM's boot images (ssh under a kernel
  without modules). test_snap 164/0, test_upkeep 239/0, test_menu 594/0, the installer area green.

- r27-52a-master-2 (1 Nov 06:45; the same master, resumed — .claude/notes/master-T48-verdict-2.md):
  VERDICT PASS — 21 of the 23 earlier findings closed, 2 partly (12: the restore from a boot-menu
  snapshot is stub-tested, not yet proven in a real systemd.volatile=overlay start — that proof is
  T48's own acceptance item "a read-only snapshot boot in the VM"; 15: two tests still missing — a
  nested subvolume other than .snapshots, an entry without the machine-id token). New: 0 major,
  3 minor (conditions before apply), 6 nits. Closed at once (06:52, 7b6c683): N1 the boot images made
  again once when /etc/dracut.conf.d/fedokawaii.conf is new (`dracut -f --regenerate-all`, then
  `sync -f /boot`; dracut writes NAME.tmp and renames it: /usr/bin/dracut:2446, 2802) — else the
  kernel_match heal would be inert on the PC until the next kernel; N2 restore refuses while /boot
  or the ESP (when fstab names it) is not mounted; N3 `kawa-snap finish` (the cut-restore branch as a
  verb), called by the start-up run (--kernels) before the kernel rules, and `list` says on stderr that
  a cut restore waits; N4 the last line says "at the next start, choose kernel X" when the default
  could not be set; N7 the PC's top level looked at read-only (mount -o ro,subvolid=5): only `root` —
  no root.new/.copy/.swap/.old leftovers; N8 kernel_match's whole kernel has its entry too; N9 the last
  line: "install nothing before (it would land in the system being replaced)". N5: the clean eight-row
  run of the final restore-cut.sh is running (06:52); N6: test_menu's log kept with the evidence.
  test_snap 177/0, test_menu 594/0.

- r27-52a DONE (1 Nov 07:07; master PASS, its conditions closed) — T48 FIRST (1). The clean run of the
  final tools/vm-inject/restore-cut.sh (N5): eight rows, every one ok, exit 0 in 886 s — the table kept
  in .claude/notes/restore-cut-2026-11-01.txt (copied, kernels, adding → the system before ran;
  exchanged, defaulted, moved, renamed → the restored one; exchanged under the old kernel healed by
  kernel_match + one start; old → back to the marked system). LIVE on the PC (07:05 apply, exit 3 =
  applied with a red left: verify 258/259, the one red qbittorrent installed outside the manifest —
  his, known since 28 Oct, T35's): /usr/local/sbin/kawa-snap = the repo's (sha256 b34e18fe…);
  /etc/dracut.conf.d/fedokawaii.conf in place and the boot image rebuilt 07:05:13 (lsinitrd:
  etc/cmdline.d/20-force_drivers.conf = rd.driver.pre=xfs rd.driver.pre=vfat); the kernels unit
  has ConditionKernelCommandLine=!systemd.volatile; grub-btrfs ignores root.copy and root.old.d; the
  GTK default-button rule (r27-19m-gtk-default) live in both themes' gtk.css (07:05:23). Still owed by
  T48's acceptance, not this item: a restore from a real boot-menu snapshot (overlay) in the VM; the
  two tests the master listed (another nested subvolume, an entry without the machine-id token).

- r27-49c (1 Nov 07:25; T45 (c), wip on t45 — tools/vm-inject/update-green.sh, the VM "built" with its 49–56
  real pending updates, the t45 toolkit): run 1 (06:39) — the container was handed the transaction folder
  as its command (cand_run did not shift its TXDIR: "execv(…/update/tx) failed"), and the bisection then
  held all 56 packages because its halves could not be stored from the cache: fixed (f04e047) — the
  argument shifted, --link-journal=no (the copy has the host's machine id), every copy first started
  with /usr/bin/true (a container that does not start is no verdict: stopped, nothing changed), a half
  that cannot be tried returns 2 (no culprit named, nothing held, stopped), the stored transaction and
  kept downloads removed at every end. Run 2 (07:09): the candidate's replay of 56 packages went
  through in the container ("Complete!", 34 s); its check misread the new kernel's entry (empty
  version) and the halves could not be stored with -C: fixed (the entry's `version` key; halves
  stored with the network allowed; the scratch /boot given loader/entries and grub's grubenv). Run 3
  (07:13, still running at the pass's end; its log in the VM's /tmp/update.log, lost with the next
  revert): candidate red "the boot image of 7.2.13 has no btrfs"; the bisection found the kernel in
  ≈ 5 min ("held: kernel 7.2.13") and the rest was red again for the same reason. Two findings for the
  next pass: (1) inside nspawn dracut cannot see the root's block device ("failed to get device size
  for /dev/vda3") — its host-only image may lack btrfs where the live one would not (a false red), or
  lsinitrd fails in there: run the image checks from the host on the scratch /boot (it is a host
  folder) and give the container the root device read-only (DeviceAllow + bind) so its dracut builds
  what the live one would — compare both images' module lists in the VM; (2) a hold must cover the
  culprit's whole source package (the kernel family: kernel, -core, -modules, -modules-core …, one
  SRPM): bisect over source packages (rpm -qp --qf %{sourcerpm} on the stored rpms), hold every binary
  of the red one — fewer rounds too (56 binaries ≈ 20 sources).

- r27-49c (cont., 07:30, t45 1ade7a9): finding (2) done on stubs — the bisection and the holds work on
  source packages (rpm -qp --qf '%{name} %{sourcerpm}' on the stored rpms → UPD/sources; halves of
  sources; a hold takes every binary of the red one): test_update_flow 131/0 (+ the kernel family —
  kernel, kernel-core, kernel-modules from one source — held whole, bash and zlib applied). Finding (1)
  (the candidate's dracut without the root device) still open: next pass, VM.

- r27-49c (cont., 07:31) — run 3 finished (the code before the source-package holds; 1055 s for the
  whole run): the candidate red twice for "the boot image of 7.2.13 has no btrfs" (finding (1)), the
  kernel and kernel-core held one after the other, then green in the copy (66 packages after the
  re-store), the live replay went through — and u_check found two NEW reds: "brave-origin from
  brave-browser (gpgcheck=1)", "claude-code from claude-code (gpgcheck=1)" → the set held, snapshot 2
  offered (the VM's /home is inside /). Finding (3): a replayed stored transaction records every
  package's origin as `@stored_transaction(REPO)` (dnf5-upgrade(8): the ids are mangled), so
  verify.sh:191's `%{from_repo}` check (and fedokawaii-report PKG-16) read the wrong repository — read
  the origin with the wrapper stripped (or confirm another way that the package came from REPO), and
  check every %{from_repo} user. Timing for the design: a red set with two bisections ≈ 17 min end to end.

- r27-49c (cont., 07:34, t45): finding (3) fixed — verify.sh's origin check and fedokawaii-report PKG-16
  strip `@stored_transaction(…)` (the stored transaction was resolved from REPO and its signatures
  checked before it went in); systemd-container's evidence row added (packages.fedoraproject.org/pkgs/
  systemd/systemd-container, dnf5 repoquery: fedora + updates). test_verify 173/0 (+2), test_report_rows
  269/0. Left for the next pass: finding (1), then update-green.sh to a green run.

- r27-49c (cont., 1 Nov 07:52, t45 66b9252): finding (1) was the CHECK's, not the container's —
  Fedora's kernel has btrfs built in (CONFIG_BTRFS_FS=y in /boot/config-7.2.11-200.fc44.x86_64,
  kernel/fs/btrfs/btrfs.ko in modules.builtin; virtio_blk too in the VM), so "no btrfs.ko in the
  image" was always red. Measured: dracut's host-only image made inside an nspawn candidate (with
  and without the root device bound read-only, DeviceAllow r) and on the host hold the same modules
  — the PC 452 = 452 = 452, the VM 440 = 440 = 440 (dracut 108; the "failed to get device size"
  warning changes nothing). lib/cand-check.sh now wants every driver of the image that starts the
  machine today (bound read-only at /run/fk-ref.img by cand_run) in the new image or built into the
  new kernel (modules.builtin), skipping modules the new kernel no longer ships (modules.dep), plus
  btrfs (+ amdgpu on AMD) the same way. Proven in a real container on the PC: a full image green, an
  image made with --omit-drivers nvme red "lacks what today's has: nvme". test_update_flow 131/0.
  No device bind needed (left out: nothing it changes). The VM run with it: next line.
- r27-52b (1 Nov 07:40–08:05; T48 FIRST (2), wip on branch t48 610a55d, NOT on main or the PC):
  system/fedokawaii-split — arm (repair's r_system, setup's end, `setup.sh --layout`: a snapshot
  first; refused, nothing changed, while another /system-update waits, a top-level home/log/fk/
  snapshots exists, a layout path is mounted from elsewhere, or free < du(home + var/log) + 5 GiB),
  run (fedokawaii-split.service in system-update.target, systemd.offline-updates(7): each of /home,
  /var/log, /var/lib/fedokawaii/update copied into NAME.part with cp -aT --reflink=auto -x — auto,
  because btrfs will not reflink journald's NOCOW files (lsattr: /var/log/journal is C) — compared
  entry by entry (type, mode, owners, SELinux label, time, size) and 64 files by content, then
  named; ~/Downloads and ~/VM (subvolumes) and .snapshots moved by rename, never copied; fstab given
  the four lines (same device and options as /, subvol=NAME), findmnt --verify; each step synced; a
  cut resumes at the next start (the link stays until the end); a failure or a fourth start puts all
  of it back (old fstab, moves undone, copies deleted — never one holding a subvolume) and keeps the
  reason + the program's sha256 in split.failed so repair does not arm the same split again), clean
  (in a later start: root's hidden old /home, /var/log, update copies removed with rm
  --one-file-system, never where a subvolume sits), state, fstab FILE TOP. kawa-snap: snapshots
  read at the top (snapshots) or inside root (before), --with-home only while /home has no
  subvolume of its own, a restored root from before the split gets the layout's fstab lines (so
  his files stay today's). The snapshot-boot notice keys on systemd.volatile=overlay (the flat
  paths have no "/.snapshots/"). verify: the layout row. Measured on the PC: /home 35 G in 236 271
  files outside Downloads/VM, /var/log 552 M, 849 G free; `cp -x` leaves an empty folder where a
  nested subvolume sits (tested), the fstab writer on a copy of /etc/fstab (a stale /home line
  replaced). test_snap 193/0 (+4: list and restore on the flat layout, the fstab lines, a copy
  that cannot take them), test_split 51/0 (new). The VM proof tools/vm-inject/split-cut.sh (none,
  six cut points, two failures, the clean, a restore from before the split) runs next; the PC only
  after it is green (a restart: the owner's PC).

- r27-49c (cont., 08:15, t45 da061e9): two more of the check's own false reds, found by the VM's
  runs: (a) "no amdgpu" on a virtio VM — the VM's record /var/lib/fedokawaii/gpu says amd and
  cand_run fell back to "amd" anyway: the GPU rule and the fallback are gone (today's image carries
  the GPU's driver when the machine needs it); (b) "lacks what today's has: hfs hfsplus jfs minix
  msdos nls_ucs2_utils ntfs" — the VM's image from the install is generic: the rule is now the
  drivers this machine runs on (today's image ∩ /proc/modules, the host's list inside the container
  too), each in the new image or built in. PC re-proven: full green, an image without nvme red.
  update-green.sh re-running on f44.
- r27-52b (cont., 08:12, t48 771853a): the split's first VM run (08:09) — the safety net worked
  for real: plymouth writes /var/log/boot.log through the offline start, the copy of /var/log
  differed, and everything was put back whole (nested, his files identical, the VM started
  normally). Fix: files a process holds open under the folder being copied (/proc/*/fd) are copied
  as they are and left out of the comparison. Second run, case "none" (tools/vm-inject/split-cut.sh
  f44b none, exit 0): the split in 3 s of the offline start (/home, /var/log, the update folder
  copied and compared; ~/Downloads, ~/VM and the snapshots moved; fstab 4 lines), then: state
  "flat, old copies"; his files byte-identical (a newline in a name, a space, a hard-linked pair
  still 2 links, a symlink, a fifo, an 8 MiB NOCOW file, an xattr, 64 MiB noise; Downloads/VM
  files); btrfs subvolume list: home, log, fk, snapshots at the top, Downloads and VM inside home;
  the journal on [/log]; snapper made snapshot 3 in /.snapshots; kawa-snap list 3; the boot
  menu's list 3 entries on subvol="snapshots/N/snapshot"; clean left root's /home and /var/log
  empty; then kawa-snap restore 1 (Oct 27's baseline, from before the split — no --with-home) and
  a start: his files identical, /home and /.snapshots mounted from their subvolumes.
  tools/vm-clone.sh made the clone f44b (reflinked states, port 2223) so both proofs run at once.
  T48 (3), the part that is T48's: snapper_limits sets TIMELINE_CREATE=no for root once a home
  config exists (the system changes only through packages and updates, each snapshotted; /home
  keeps its hourly ones); before the split root keeps its timeline (it holds his files). The book
  (8.2) says so; its example list shows an update's snapshot instead of a root "timeline" one.
  Running: the six cut points and two failures (f44b).

- r27-49c GREEN (1 Nov 08:17; t45 da061e9; tools/vm-inject/update-green.sh f44 ~/repos/fk-t45, exit 0)
  — the button's run end to end on the harness VM's real pending updates (from "built", 27 Oct):
  stored once (61 packages incl. kernel 7.2.13, gcc, util-linux, pipewire, brave-origin,
  claude-code, steam), green in the copy at the first try (the nspawn candidate: replay "Complete!",
  cand-check green — scriptlet noise in there only: grub2-probe cannot see /dev/vda3, harmless on
  a scratch /boot), the pinned snapshot 2, the live replay of the same stored transaction, the
  follow-ups (Prowlarr, nvim plugins, uv, rustup, dracut for 7.2.13, dwl rebuilt, the theme), the
  checks green; report "ok · updated · 61 packages"; no holds; root.cand gone; 269 s end to end;
  7.2.13 installed, 7.2.11 kept until the new one runs. Left after it: 3 lines of `dnf
  check-upgrade` (of 75 before — counted lines, not packages; the next pass reads which). (c) is
  done in the VM; t45 stays OFF main until T48's flat layout is live on the PC (the master's gate
  for (d)/(f) on the PC), then (e) the real checks + the desktop smoke test, (f) probation, (h),
  (i). Note for T46: the run said "Fedora 45 is out — the menu shows when the move to it is
  offered" on 1 Nov (the owner's date for F45 is 3 Nov) — check what fedokawaii reads for that.

- r27-52b (cont., 08:24; f44b, tools/vm-inject/split-cut.sh, table kept in /dev/shm/r27/split-cut.first9.txt):
  every cut point whole — part-home (cut after /home's cp, before its comparison: home.part deleted
  and copied again), copied-home, copied-log, copied-fk, moved, snapshots, fstab: each "ok flat ok
  ok ok" = the next start went on ("start 2" in the log), the layout flat, his files byte-identical,
  clean left root's /home and /var/log empty, snapper/kawa-snap/the boot menu on snapshots/N. Two
  failures made (fail-copied-home, fail-fstab — the latter after fstab was written and Downloads,
  VM and the snapshots moved): put back whole — nested, his files identical, Downloads/VM/.snapshots
  back inside root, the old fstab, snapper lists, /system-update gone, split.failed with the reason
  and the program's sha256; `setup.sh --layout` did not arm it again (state nested) — the table said
  "armed again" only because the proof read the last line of setup's output (its exit footer): the
  proof reads four now; both re-running. overlay-restore.sh f44, first run: inside the snapshot
  started from grub-btrfs's own kernel line (one-time BLS entry + grub2-reboot): / an overlay, the
  system as S had it, /home today's from its subvolume, kawa-snap list marks S booted, `kawa-snap
  restore 3` from inside it rc 0; but the next start was S again: the proof's one-time entry named
  the same kernel file, so the restore's `grubby --set-default /boot/vmlinuz-K` chose it
  (grubenv saved_entry=fk-overlay) — a harness artefact (grub-btrfs's entries are not BLS entries);
  a start after the entry went: the restored root (no mark, flat, /home mounted, root.old kept).
  The proof now removes its entry once S has started; re-running.

- r27-52b (cont., 08:33): the reruns green — split-cut.sh f44b fail-copied-home fail-fstab: both "ok"
  (put back, nested, files identical, not armed again: "the next toolkit tries again", state nested);
  overlay-restore.sh f44 exit 0, all 11 checks: the flat layout made and cleaned; snapshot 3 started
  on a layer in memory from grub-btrfs's own kernel line; the system as S had it (no mark); /home
  from its subvolume; kawa-snap list marks 3 booted; his files today's; `kawa-snap restore 3` from
  inside S; the next start: / the root subvolume again, S's state, the layout flat, his files the
  same. T48 FIRST (2) is proven in the VM in full (whole · 7 cuts · 2 failures · a pre-split restore
  · a restore from a boot-menu snapshot); the master's verdict next, then the PC.

- r27-found-1 (1 Nov 08:26, seen live, not yet fixed — for T53/T60): his waybar (pid 1687605, up since
  00:59) holds 13 zombie children ("[waybar] <defunct>", ppid = waybar) born in bursts at 01:57:08,
  01:58:15, 02:33:19, 03:09:23 — the moments the bar's modules were woken or restarted (kawa-bar
  wake pipes, brightness/DDC at 01:57). No memory held, but a session of weeks would pile them up:
  find which custom module's exec children waybar does not reap (waybar's own source for its
  command runner; our kawa-bar restarts), fix it, and add a regression check (zombies after N
  module restarts = 0).

- r27-52b-master (1 Nov 08:43; Fable, fresh, read-only, 28 min — .claude/notes/master-T48-verdict-3.md):
  PASS WITH CONDITIONS, no MAJOR ("no step at which a file of his can be lost or the PC left
  unbootable"); reproduced test_split 51/0 and test_snap 203/0. Ten MINORs, eight NITs. The evidence as
  it was (its NIT 14): the nine-case table (/dev/shm/r27/split-cut.first9.txt) had the two failure rows
  "armed again" from the proof's own assertion (it read only the last line of setup's output); the two
  failure cases were re-run after that fix (split-cut.fail.summary, both ok); the overlay proof's first
  run came back into the snapshot because of the harness's own one-time entry, the second run is the one
  kept (11/11); "a pinned snapshot" before the split is snapper's `important=yes` (NUMBER_LIMIT_IMPORTANT
  4–10), not a pin; the book's "your files every hour" (§8.2) is true once the split and a repair (or
  `setup.sh --layout`) made /home's config.
- r27-52b-fix (1 Nov 08:45–09:05, t48): the ten fixed, each with its test —
  (1) the content sample goes through the same skip list as the listing (open files, subvolume folders):
  test_split "a file a process holds open and appends to" — red on the program without the fix
  ("the copy of /var/log/boot.log differs"), green with it; (2) `run` checks the link is its own before
  anything else (offline-updates(7) §5): another tool's start on a non-Btrfs root → exit 0; (3) the fstab
  kept before the rewrite is synced (sync -f), the new one fsynced before its rename, and `back` puts the
  kept one back only when it is whole (a / line on Btrfs), else leaves fstab as it was and says so;
  (4) a split put back is verify's red ("nothing for you to do: the next toolkit tries again"), not
  repair's failure (s_layout returns 0 there; r_system calls `s_layout || log`); (5) the start-up run
  (setup.sh --kernels, on the system itself, after boot_success=1) runs `fedokawaii-split clean`; verify
  says "removed at the next start"; (6) one disk-level test in kawa-snap — all four of home, log, fk,
  snapshots at the top — for the --with-home guard and the fstab lines; `state` answers "broken: the
  layout half made (at the top: …) — reason" (read mount-free from `btrfs subvolume list /`), verify
  fails it with the reason, `arm` refuses over it, `back` writes "left behind: …"; (7) a restore gives
  the restored root today's kawa-snap and fedokawaii-split (cp -a: labels kept; the rest of the toolkit is
  that day's until the next update); (8) the snapshot-boot notice and kawa-snap's header true for both
  kinds of snapshot (/home mounted → "your files as they are", not → "the system and your files as
  they were — nothing done here is kept"); (9) home/.snapshots in grub-btrfs's ignore list; (10) kawa-snap
  pre and setup's snapshot_before refuse when fstab names /.snapshots on its subvolume and it is not
  mounted there (pre: a journal line, dnf goes on). NITs taken: tries parsed safely (a damaged file →
  counted from 0), the give-up path keeps its log, a lock on the shared top mount (state/clean), the
  wording, design §3 "As built" paragraph, and a stub run of the whole path (test_split's world: btrfs
  subvolumes as folders tracked by inode, real cp/find/cmp — NIT 16). Left: NIT 17 (copied journal
  files lose NOCOW until they rotate; tmpfiles sets the folders again — performance only). Also found
  by the new tests: kawa-snap's guard had lost its `restore`-only condition when moved (finish was
  refused) — fixed before anything ran. test_split 84/0, test_snap 214/0 (24 restore calls on the nested
  fake disk now say --with-home: that is the PC's layout until the split). The installer tests' fake
  Fedora now has the flat layout (findmnt SOURCE, btrfs subvolume list, a mount stand-in that turns the
  top-level mount into nothing; $FKH/nested for Fedora's own); test_setup/test_upkeep re-running; the
  VM: split-cut none (f44b), fail-fstab + overlay-restore (f44) re-running on the fixed programs.

- r27-52b-pc (1 Nov 09:54–09:57; main c32821b = t48, pushed): the whole suite green before it — 123 of 125
  files at 09:40 (the two red, test_verify and test_deps, from this item: the dependency map lacked chcon,
  shuf (coreutils) and plymouth (rpm -qf), and verify's fake world had no fedokawaii-split) → test_deps
  197/0, the installer area 25/25 (test_verify, test_upkeep 253/0, test_setup 233/0). APPLIED on the PC
  09:54 (apply rc 3: repair, verify 258/259 — the one red his qbittorrent outside the manifest, known
  since 28 Oct, T35's): snapshot 370 "before repair", snapshot 371 "before the disk's new layout"
  (important), `fedokawaii-split arm` → armed (/system-update → /var/lib/fedokawaii/split, tries 0,
  fedokawaii-split.service wanted by system-update.target, the program's sha256 89201bd9… = the repo's);
  verify's row "the disk's new layout is made at the next start". Before-picture kept: ~/.cache/
  r27-split-before.txt (home 269 785 files / 35 994 845 100 bytes outside the nested subvolumes;
  Downloads 191 files 66 GB; VM 44 files 202 GB; Steam 13.5 GB; /var/log 60 files; snapper 46) and
  ~/.cache/r27-split-before.sha256 (561 files). He was away (no input since 09:39, the swayidle logger;
  the notes' nvim 0 modified buffers, his terminals only the warm helpers, Steam idle) → restarted at
  the end of this pass with greetd's one-time initial_session (the file kept in
  /var/lib/fedokawaii/greetd-fedokawaii.toml.r27): the next pass restores it FIRST and checks the split.

- r27-52b-pc (cont., 1 Nov 09:57–10:12): the PC restarted 09:57 (greetd's one-time login); greetd's file put back
  first (`cp -a` the kept copy: 0 initial_session lines). THE SPLIT, on the PC: its log 09:57:13 "start 1" →
  09:57:21 "the disk's new layout is made" (8 s: reflink copies) → state "flat, old copies". At the top: root
  256, home 642, log 643, fk 644, snapshots 259 (the same ID as root/.snapshots had: moved, not copied);
  Downloads 258 and VM 511 inside home (their IDs kept: moved); fstab's four lines; findmnt: /home [/home],
  /var/log [/log] (the journal's files there), /var/lib/fedokawaii/update [/fk], /.snapshots [/snapshots].
  His files: `sha256sum -c` of the 561 kept checksums all OK; the new /home against the old copy the mount
  hides (a read-only bind of /, file list with sizes, C sort): 236 415 old vs 236 422 new — outside Steam's
  runtime churn, the caches and Claude's session files written since the start: 0 missing, 0 new, every
  size equal (Steam's registry.vdf, steam.pid aside). Downloads 191 files / 66 272 717 025 bytes = before;
  VM 44 files (its disks written by the proofs after 09:01); /var/log 60 files = before; snapper 46 + 370 +
  371 = 48; fk-f44, fk-f44b listed by virsh. (The 09:01 count of 269 785 home files was an hour older:
  the copy matches the disk as it was at 09:57, file for file.)
  FOUND: the boot menu's list (grub-btrfs.cfg, written 09:54:56) still named root/.snapshots/N — after the
  move none of its ten entries could have started. The VM proofs had called `kawa-snap boot` themselves
  before reading the list, which hid it. Fixed live: `kawa-snap boot` 10:00 → ten entries snapshots/325 …
  371, each a subvolume on the disk (checked one by one). In the code: the split's end() lists them again
  (after a split and after a put-back: its log says which); verify's boot-menu row fails a list that names
  a snapshot no longer on the disk ("— fedokawaii repair lists them again"); split-cut.sh now reads the
  list the split made (no `kawa-snap boot` first; asserts stale=0). test_split 87/0 (the old program: red),
  test_verify 175/0 (the PC's case: root/.snapshots/371/snapshot named → ✘ with repair named), test_snap
  214/0; the check's logic run on the PC: live list → nothing gone; the stale line → named.
  Then `setup.sh --layout` (10:00): home's snapper config made, root's timeline off, home's on; clean
  removed the old /home and /var/log copies → state "flat". `fedokawaii verify` 259/260 (the red: his
  qbittorrent outside the manifest, T35's); the layout row ✔. T48 FIRST (2) DONE on the PC (the master's
  condition — the PC with its outputs recorded — met here); the VM re-run of split-cut none for the new
  end() is the next pass's first item. Note for the Super+U pane (T48 rest): `kawa-snap list` gives
  snapper's info.xml dates, which are UTC (09:54 shows as 05:54) — the pane shows local time.

- r27-52b-vm (1 Nov 10:08–10:09; worktree of 05eb42e, VM f44b): `split-cut.sh f44b none` → none ok · flat · files ok ·
  clean ok · RESULT ok, rc 0 (71 s). The split's own log in the VM: "10:09:00 the boot menu's snapshots listed
  again"; the list read as the split left it (no `kawa-snap boot` first): grub=2 stale=0. The boot-list fix is
  proven in the VM; the worktree removed.

- r27-found-1 FIXED (1 Nov 10:12–10:22): the cause, from waybar 0.15.0's own source (src/main.cpp,
  include/util/command.hpp, src/client.cpp, src/modules/custom.cpp at tag 0.15.0) and reproduced headless
  (the kit, the installed bar, only the kit's own waybar signalled: pgrep -P): every SIGUSR2 is waybar's
  full reload (Client::reset: every bar and module destroyed and made again) — 3 → 8 → 9 zombie children
  "[waybar]" after three reloads, every module child replaced; with waybar -l trace the zombie's only line is
  "(waybar:PID): CRITICAL … Glib::DispatchNotifier::unreference_instance" after "LOG ERROR … Rethrowing unknown
  exception in logger": a fork made during the teardown that never reached exec, ran exit() through Glib's
  destructors, and whose module (the only one that would waitpid it — command::open's children are not in
  the SIGCHLD reap list) was gone. The session never sends SIGUSR2 to the bar (the theme switch goes through
  the portal's color-scheme: kawa-theme); the senders were the passes' own reloads after an apply (memory
  "Live bar reload") and the configs' comments telling a reader to. FIX: config.jsonc "reload_style_on_change":
  true — waybar watches style.css and its @import (a Gio file monitor) and swaps only the CSS provider
  (client.cpp setupCss): headless, four edits → the same nine children by pid, 0 zombies, the edit drawn
  (106 px of the test green on the torii). The comments in config.jsonc and style.css now say never SIGUSR2.
  Guards: tests/static/test_barreload.sh (the key set; nothing in bin, lib, configs, system, tools, the
  installer or the Learn book sends USR2 to waybar — red on the old config: 0/2, green 2/0) and
  tools/bar-zombies.sh (the kit: 3 style edits, 10 × poke every signal + wake → alive, the same children, 0
  zombies, the edit drawn — exit 0). Live: the running bar (since 09:57) has the old config; it watches its
  style from its next start (the next login), the config installed by the next apply. Left as a note:
  kawa-dwlstatus caches the newest "waybar" by comm, which a zombie fork keeps — harmless once no zombies
  are made (a fork alive pre-exec has waybar's handlers: its poke reaches the bar through the pipe).

- r27-found-2 (1 Nov 10:22, for T53/T42 — not yet fixed): the installer tests leave core dumps on his system:
  62 of /tmp/kawa-test.*/w/.usr/bin/bluetoothctl (SIGABRT, `bluetoothctl show`, users 1000 and the world's
  555287) in coredumpctl's list — the fake machine's /usr/bin links every real binary (tests/installer/lib.sh
  usr_farm), and fedokawaii-report's BT-01/BT-04 rows run the real bluetoothctl in a namespace with no system
  bus, where it aborts. On the PC itself `bluetoothctl show` answers (rc 0, no core). Fix: a stand-in
  tests/installer/stubs/bluetoothctl (show / devices Paired / info / --version, the world's state from $FKH),
  then the whole installer area again (a stub change: memory "harness change → full area re-run"); a
  regression check: no new coredumpctl entry under /tmp/kawa-test.* after tests/run.sh. Also seen: each kit
  run ends with foot --server writing two "Broken pipe" errors to his journal when the headless dwl goes —
  the kit should stop its foot server before dwl ends.
  Checked after the split meanwhile: the new subvolume roots' SELinux labels right (`restorecon -nv` on /home,
  /home/dia, /var/log, /var/log/journal, /.snapshots, /var/lib/fedokawaii/update: nothing to change), 0 AVC
  denials since the boot, no failed unit (system or user).

- r27-45-merge (1 Nov 10:09–10:30, branch t45 → 77fabc1, e8f9597, pushed): main (the flat layout, T48 (2)) merged
  into t45 — no conflict (six files changed on both sides: setup.sh, verify.sh, stubs/btrfs, test_upkeep,
  test_verify, programs.txt; the btrfs stand-in read whole: both sides' cases kept). The merged branch:
  engine 12/12, static 10/11 → the red was t45's own: lib/update.sh's `local x=()` made shellcheck read
  setup.sh's string x (s_gaming) as an array (SC2178/SC2128) → the half renamed pk; test_syntax 691/0,
  test_update_flow 131/0. Installer 22/26: test_setup, _hw, _wait, test_torture red — on main too: next item.
- r27-52b-fstab (1 Nov 10:24–10:32): those four were red because the PC's /etc changed (the installer tests'
  world copies it: memory "installer world copies host /etc"): the split had ended its fstab lines "\t0 0",
  pace_fstab (setup's noatime pass, lib/pace.sh) rebuilds every Btrfs line tab-separated, so the world's
  s_pace saw a change, wrote a candidate and failed `findmnt --verify` on mount points it does not have
  (line 1843, s_pace → fstab_noatime: return 1). Fixed at the writer: the split's lines now "\t0\t0" (the
  form pace_fstab leaves as it is); test_split pins them as pace_fstab's fixed point (red on the old form:
  87/1, green 88/0); test_snap's expected line follows (214/0). APPLIED 10:30–10:31 (main aeb8680): repair's
  pace pass rewrote the PC's four lines in the same form (cat -A: tabs to the end); `fedokawaii verify`
  259/260 — the new row "snapshots in the boot menu" ✔ (every listed snapshot on the disk), the layout ✔,
  the red his qbittorrent (T35's). The bar's config with reload_style_on_change installed (his running bar
  takes it at its next start). Still to do (T53): the world's own fstab, not the PC's (the lesson of this
  item and of the dracut line: the fake Fedora must start as Fedora left it, not as the PC is).

- r27-52b-fstab DONE (1 Nov 10:37–11:05, main 29bbfc7, 2fb0189): the world's missing /etc/fstab found —
  tests/installer/lib.sh removes every copied /etc file naming "fedokawaii" (line 221), and since the split
  the PC's fstab has /var/lib/fedokawaii/update. The fake Fedora now gets anaconda's own fstab (the PC's
  snapshot 1: root subvol=root,compress=zstd:1 · /boot xfs · the ESP) and a finished install (built())
  that fstab through lib/pace.sh's pace_fstab, as setup's noatime pass leaves it; findmnt's stand-in says
  xfs for /boot like it; mount's stand-in records a remount (the noatime pass now runs for real in the
  world, and its remount would have gone to the host's /). Also found: the built world wrote through
  the copied /etc/mpv/scripts/mpris.so — a link to this PC's own /usr/lib64/mpv/mpris.so (refused only
  because the tests run in a user namespace): replaced, never written through. Results: test_setup
  233/0 (was 148/91), test_setup_wait 70/0 (47/31), test_setup_hw 84/0 (79/5), test_torture 214/0,
  test_verify 175/0 (160/15 before built()'s fstab); the whole installer area: 24/25 on the first
  fix, the re-run after built()'s fix below.
- r27-found-2 DONE (1 Nov 10:39, main 29bbfc7): tests/installer/stubs/bluetoothctl (the world's adapter,
  powered, nothing paired; not in the call log: the power cuts' counts stay as they were); tests/run.sh
  fails a run that leaves a core dump under /tmp/kawa-test* (coredumpctl since the run's start) —
  first run with it: 0 new; the kit's foot server --log-no-syslog (checked: two kit runs at 10:58,
  no "Broken pipe" line in the journal).
- r27-found-3 DONE (1 Nov 10:45, main 29bbfc7) — Fedora 45 "out" two days early: setup.sh released()
  asked dl.fedoraproject.org, then the redirector download.fedoraproject.org — which sent the HEAD to
  mirrors.nxthost.com, serving F45's staged tree (200, Last-Modified 28 Oct) while Fedora's own server
  answers 403 (checked 10:41). Bodhi already says F45 "current" and fedoraproject.org/releases.json
  "45 Beta" — neither is the release; the official schedule (fedorapeople.org/groups/schedule/f-45/
  f-45-key-tasks.html) gives Final Release Tue 2026-11-03. Now only Fedora's own server; a test case
  (a staged tree a mirror would serve: "not released yet", no mirror asked, no release day recorded).
  The PC has no /var/lib/fedokawaii/release-45 (nothing wrong recorded); the menu's own release_check
  (system/fedokawaii) always used dl.fedoraproject.org only.
- r27-49e (1 Nov 10:46–11:10, T45 (e), main 29bbfc7 + t45 8dfa60c): the update's checks after its
  transaction, and the same before it as the baseline (red already: not counted against it):
  · tools/regress/session-start.sh — the kit's headless dwl (the installed one), the installed configs,
    the session's pieces as autostart starts them: waybar, mako, the foot server, kawa-panel, the three
    warm windows still running in this session after their time, the bar's rows drawn (more than 16
    colours). Proven both ways on the PC: green (8.9 s); a broken waybar config → "not running: waybar ·
    nothing drawn: the bar's rows hold 1 colour"; a kawa-panel that exits → "panel: no fifo after 3 s ·
    not running: kawa-panel".
  · tools/hl-dwl.sh: the render node of the card the desktop draws on (start-dwl's rule: the most video
    memory) instead of a fixed renderD128 (here 03:00.0 → renderD128, the iGPU 15:00.0 → renderD129);
    pixman on a machine with none (the harness VM).
  · lib/guard.sh desktop_starts (session-start + bar-geometry, as the user, the installed dwl) and
    lib/update.sh up_more (that, and lib/cand-check.sh on the running system: our builds' libraries,
    every boot entry of the real /boot with root=/rootflags=, its image readable, btrfs in it) — in
    u_start's baseline and u_check. On the PC as the update runs them (root → runuser, a bare env):
    session-start 9 s, bar-geometry 7 s (both themes), 157 MB peak; cand-check on the world: green.
  · python3-pillow in the manifest (the shots' measure; on the PC an orphan nothing requires — dnf
    autoremove would have taken it): Fedora 44 updates, python3-pillow-12.3.0 (dnf info).
  · tests: the world's stand-ins for the two checks; a red before the update not counted ("kept, and
    said"); a bar off its measure only after the replay → the set held, the snapshot offered.
  Left for (e): the lock screen's start (gtklock + kawa-lockmod in the kit) → T20, where kawa-lock is
  rebuilt (today it logs to his journal on every lock: a check per update would write there).

- r27-49f (1 Nov 11:00–11:20, T45 (f), on t45 — the probation of the start after an update, design §4.3 as
  built): after every green run, lib/update.sh up_probation writes UPD/probation (SNAPSHOT KERNEL|- DAY);
  when the run brought a kernel newer than the running one, GRUB's own counting is armed
  (grub2-editenv: boot_counter=3 boot_success=0 boot_indeterminate=1 — the menu stays hidden on the
  first try, Fedora's 08_fallback_counting takes entry 1 after three unmarked starts), the new kernel's
  entry alone gets rd.shell=0 rd.emergency=reboot panic=10 (dracut.cmdline(7): a failure restarts
  instead of a shell; a panic restarts after 10 s) and systemd's hardware watchdog goes on
  (system.conf.d RuntimeWatchdogSec=1min; this PC has sp5100_tco, /dev/watchdog0, RuntimeWatchdogUSec=0
  until now). The proof of a good start stays the desktop's own: Fedora's grub-boot-success timer
  (autostart, two minutes into the desktop) writes boot_success=1; fedokawaii-boot-good.path
  (PathChanged=/boot/grub2/grubenv, read on the PC: a plain file) runs setup.sh --boot-good at that
  moment (the service skipped while no probation is open; it waits for the setup lock — a mark during
  an update is never missed; dnf's guard starts the after-dnf service --no-block, so the kernel
  removal under that lock cannot deadlock): on the new kernel → counting off, the trial arguments out,
  the watchdog off, every pinned snapshot back to snapper's number cleanup; on the one before with
  boot_counter=-1 → the new kernel held at its version (versionlock + UPD/holds "did not reach the
  desktop in three starts"), removed, the running one the default, a notice at login; the one before
  chosen in the menu → the trial waits; the trial's kernel gone (a restore took it) → the trial ends.
  Decided against the design's "system-level marker" (one that marks at the login screen): a kernel
  that breaks only the desktop would then lose the one before — the desktop's two minutes stay the
  proof (update-design.md §4.3 rewritten as built). verify: "fedokawaii-boot-good.path enabled".
  Noted for T46: Fedora's offline-update start (system-upgrade) counts as an unmarked start — the
  release move must close or re-arm an open probation first.

- r27-49f PROVEN IN THE VM (1 Nov 11:21–11:31, t45 ad54736 frozen at /dev/shm/r27p/t45-proof;
  tools/vm-inject/probation.sh, both VMs side by side, logs /dev/shm/r27/probation-f44{,b}/): the button's
  real run from "built" (61 packages, kernel 7.2.11 → 7.2.13) armed the trial in both (grubenv
  boot_counter=3 boot_indeterminate=1 boot_success=0, the trial arguments on 7.2.13's entry alone, the
  watchdog drop-in). fail (f44): 7.2.13's boot image replaced by an empty archive → GRUB counted it out
  and started 7.2.11; the desktop (greetd's initial session) ran two minutes, Fedora's timer marked the
  start, fedokawaii-boot-good.path ran at once → "kernel 7.2.13 did not reach the desktop in three
  starts: held, out; 7.2.11 is the default" — running 7.2.11, default 7.2.11, only kernel-core-7.2.11
  left, kernel-core 7.2.13 held, counter off, trial args 0, watchdog off, snapshot 2 back to the number
  cleanup: HELD, 203 s after the restart. pass (f44b): 7.2.13 started, marked good, the trial over —
  running 7.2.13, default 7.2.13, both kernels kept (the kernels run at 15 min takes the old one), no
  hold, args 0, watchdog off, snapshot released: HELD, 142 s.
- r27-49h (1 Nov 11:25–11:41, T45 (h) part 1, t45 44d881b): `fedokawaii update` (Super+U → update) starts
  fedokawaii-update.service (systemd-run: a closed window, a logout or a desktop that stops never cut
  it — before, Super+Q on the job window killed the run) and follows its output (STATE/update/run.log,
  0644; colours through FK_TERM); a press while it runs follows it without a password. The update tab:
  the last run's outcome under "updated" ("61 packages · 1 held"; an undone run "tried 1 Nov · snapshot
  41 undoes it" / "· undone at restart", never "stopped"); "held" no longer a "not yet" entry: its
  count on the row, each held family with why (a source's packages as one, named by what their names
  share: mesa-dri-drivers + mesa-libEGL → mesa; kernel-core + kernel → kernel), "nothing held back"
  when none — rendered headless with the real fonts and measured (names in the ink 231,207,161, the
  why in the muted 202,181,150, as every pane's keys/values; a blank line between items). Decided:
  no "on trial" row — a safety step he never needs to read (a failed trial shows as a hold and a
  notice). Tests: test_front 132/0 (+ the unit, its stand-ins: never the real systemd, no polkit
  prompt on his desktop), test_status 206/0, test_menu 605/0, engine area 12/12.
- r27-50 (1 Nov 11:42, T46 started): tools/vm-create.sh installs a release before its day from its branched
  tree (dl.fedoraproject.org development/45 — 200, while releases/45 answers 403); the F45 harness VM
  (f45, port 2224, 4 CPUs) being created — the first try failed fetching the installer's kernel from a
  slow master server (330 KB/s, release week), retried 11:43.

- r27-found-4 DONE (1 Nov 11:53–12:00, main fd0739a) — EVERY CLEAN INSTALL WAS BROKEN since 28 Oct: the first F45
  VM run (vm-smoke.sh f45 from main 9cfe463) stopped in phase 3 at the dwl build — dwl.c reads anim_wash_ms
  and anim_wash_hold_ms (the ink wash, T19 e), which only src/dwl/config.h declared; setup.sh s_dwl builds with
  the patched config.def.h before theme.sh installs config.h. Not a Fedora 45 matter: reproduced on the PC
  (a copy of ~/.local/src/dwl, config.def.h as config.h: the same two errors). Fixed in the tree's
  config.def.h, tools/dwl-patch.sh (the patch: only those two lines; dwl.c untouched — the PC's dwl is the
  same code), a copy built from config.def.h: rc 0. Never again: tests/static/test_dwlconfig.sh — every
  setting config.h adds beyond dwl's own (tests/static/fixtures/dwl-upstream-config.txt, from the pinned
  commit 98bea2c) that the patch's code reads has its default in the patch's config.def.h: red on the old
  patch ("lacks: anim_wash_hold_ms anim_wash_ms"), green now. The F45 smoke started again from fd0739a.
  Why no test saw it: the installer tests stand in for the build (no compiler run), the harness VM's
  states were made on 27 Oct (before the wash), and the PC builds with config.h — T54's clean VM install
  at the end would have found it; the F45 pre-flight found it 2 days early.

- r27-49-master-efh (1 Nov 11:44–12:09; Fable, fresh, read-only — .claude/notes/master-T45-efh-verdict.md): T45 (e)(f)(h)
  FAIL — six must-fix, twelve should-fix, seven notes; "the core of (f) is sound and proven" (it re-read
  08/10/12 and grub.cfg's order on the PC, probed SELinux with a transient unit, ran session-start.sh as the
  update does: green in 8.97 s); today's main fixes PASS. Done the same pass, on t45 (8589f35, 2b95146,
  39923d8 + the should-fix commit):
  1 a check that could not run (exit 2: the kit, the shot's measure) is no verdict — one retry; before the
    update it stops with nothing changed, after the replay with nothing held or undone and the phase kept
    (the next press checks again against the old baseline — a new one would have taken the damage in);
    a red keeps its own verdict line ("session-start (dark): dwl does not start: …"), never waybar's log
  2 up_exit does make_tmp's exit too (the temp folder, dnf's follower): a test finds none left
  3 setup.sh --kernels closes an open probation too; old_kernels_out keeps the one before while a kernel
    is on trial (the update's own "one kernel" step included) — tests for both
  4 tools/vm-inject/update-button.sh — the button's own path in the VM (three presses, one unit, the
    exit status, a stopped run's status): running on f44b at the end of the pass
  5 re-rendered from HEAD, both moods (/dev/shm/r27p/kit-h/all.png): found and fixed "4 held" in the
    update pane against the held row's "2" (lines vs families) — one count, the families'
  6 dnf_settle (from dnf_detached): a cut run's transaction still writing is followed to its end before
    it is judged; refused while another dnf5 runs — a test with a busy dnf unit
  should-fix done: 9 no "(checks)" from the baseline's reds · 10 a stopped run's reason from this run's
  log only · 12 rd.retry=30 in the trial (dracut's 180 s × 3 was 9 silent minutes) · 13 hl-dwl: a VM's
  virtio screen (no 3D) draws with pixman — the VM proofs will see a green desktop check · 15 the update
  refuses on a start that is not the system itself (a restore waiting for its restart, a snapshot boot) ·
  16 a hold written once · 17 verify: the resume unit's row. 7, decided: the coredump list is not part of
  the session check — every piece is checked running by its own runtime folder, a crash is "not running"
  (nothing restarts in the kit); yazi/greetd/nvim config checks deferred to T45's next step with T58's
  research (each program's own check, from its docs). NEXT (first): 8 (entry 1 = the kernel before,
  checked before arming; no kernel transaction while a trial is open), 11 (versionlock list's TOML),
  14 (a cut run's pinned snapshot and root.cand released), 18 (the whole-set hold written into §4.3 as
  built; "and N more" in the pane), then back to the master.

- r27-50 (cont., 1 Nov 12:17–12:33) — the first Fedora 45 findings (f45 from development/45, vm-smoke from
  main fd0739a): the WHOLE install ran through phase 3 on F45 (dwl built with its private wlroots, the
  faces, the lock module, the saver, the splash in every boot image — every desktop check green); the gate
  stopped on three: (1–2) rpmfusion-free/nonfree-updates disabled — RPM Fusion's release package for a
  Fedora not yet released turns on updates-testing instead (seen in the VM: dnf repo list), so this is
  the pre-release state, re-checked after 3 Nov, not a fault of ours; (3) "sshd: keys only, no root" — a
  REAL F45 change: OpenSSH 10.5 (openssh-server-10.5p1-1.fc45) prints `sshd -T` with its keywords as
  written ("PermitRootLogin no", not "permitrootlogin no"); the values were right. verify.sh compares
  case-blind now (both releases); the sshd stand-in prints F45's casing with $FKH/sshd-camel and
  test_verify checks it (176/0). Only verify parsed `sshd -T` (grep of the repo).
  Also: the clean Fedora 44 install from fd0739a (f44 VM, from fresh): GREEN — verify 253 passed, 4
  named skips, the desktop up in 20 min — the dwl fix (r27-found-4) proven end to end.

- r27-49h (cont., 1 Nov 12:20–12:46, the master's must-fix 4 in the VM — tools/vm-inject/update-button.sh on
  f44b): run 1 — the button's mechanics held (three presses followed one run to the same last line, the
  exit status came back, a stopped run said "another package manager is running (dnf5)"), but every run
  stopped at its start: the 27 Oct VM had no python3-pillow, so the check could not run — and only an
  update could bring it. Fixed: u_start installs the checks' own tool first. Run 2 — still "could not be
  measured": in the VM hl-dwl chose GLES on the virtio screen (its render node's driver is virtio-pci,
  not virtio_gpu as the should-fix 13 change assumed), and there the terminal server never came up.
  Fixed: a virtio screen known by its vendor (0x1af4) → pixman; the check then GREEN inside the VM
  ("the bar, the notices, the terminals, quick settings and the warm windows up"). Run 3 — THE UPDATE
  WENT THROUGH THE BUTTON END TO END: `fedokawaii.sh update` → fedokawaii-update.service 12:32:42–12:38:09
  (5 min 28 s, 2.6 GB peak), exit 0, "update done (ok): updated · 49 packages", the report ok, the stopped
  run's status 1 with its reason — but the 2nd/3rd presses came only after the run (the VM journal: the
  second unit at 12:38:51): the proof's ssh waited for the backgrounded first press (it inherited ssh's
  output). Fixed in the proof (each press detached); run 4 started 12:45.
- Applied main (f18579d) on the PC 12:32–12:34: dwl rebuilt (the patch's config.def.h lines; same code,
  next login), the theme reloaded; verify 259/260 — the one red unchanged (qbittorrent outside the
  manifest, his own: T35's).

- r27-49-master-efh-2 (1 Nov 12:35–12:55; the master's re-review, appended to master-T45-efh-verdict.md): PASS
  WITH CONDITIONS — must-fix 1–6 fixed (it re-ran test_status 204/0, test_verify 178/0, test_dwlconfig 2/0
  at HEAD); should-fix 9, 10, 12, 15, 16, 17 fixed, 13 in its renderer half (b006c8f's vendor rule), 7
  half recorded (now in the plan); 8, 11, 14, 18 safe to defer for the PC's first run (checked on the PC:
  one kernel-core, no rescue entry). Run 4 of update-button.sh (12:46–12:55, t45 c9 frozen proof5): ALL
  HELD — three presses, one unit, the same last line "update done (ok): updated · 61 packages", exit 0,
  the report ok, a stopped run 1 with its reason. Condition (A) done (the plan's T45 line: each deferral
  with its acceptance). (B)–(H) are the next pass's order below.

- r27-49-merge (1 Nov 13:28, pass of 13:27) — the old trial merge's suite (/dev/shm/r27p/all.log, 2159 s) ended
  with only its two known reds (test_setup_wait, test_launcher — both fixed since). t45 (9944a7e) merged into main
  for real: a353613, no conflicts; the WHOLE suite on it started 13:28 (/dev/shm/r27p/merge2.log); main is pushed
  only when it is green.
- r27-49-18 (1 Nov 13:30–13:45; the master's (G) 18, before the PC's first press) — a whole set held at once no
  longer becomes a notice of hundreds of names: the report's line (and so the notice and the run's last line)
  names the holds by family, two at most, then "and N more"; a red only on the running system says "held: all N
  packages together (which one broke it could not be told apart; newer versions are tried)"; the Super+U held
  pane names three families, then "and N more."; an undo with nothing held no longer ends in an empty "— held:".
  The family rule moved from the menu into lib/common.sh hold_families (the pane and the report share it) and
  was fixed on the way: it merged every line with the same version and reason, so a whole set held at once
  (one reason) turned packages that happen to share a version into one family named by a meaningless common
  prefix ("p", or "?") — now only names that begin alike (kernel, kernel-core …) group. The menu skips sourcing
  lib/common.sh when nothing is held (the usual case: no cost). Tests: test_update_flow 220/0 (sixty red only on
  the running system: offered, sixty held, the line ≤ 200 characters with no name in it; four families from
  before: "ant … · bee … and 2 more"), test_menu 611/0 (sixty: the row 60, the pane p01–p03 and "and 57
  more."), test_status 207/0 (sixty: "61 packages · 60 held", ≤ 44 columns); static syntax/pointers green, no new
  shellcheck finding. Design §4.1 "as built" written.

- r27-49-11 (1 Nov 13:45–13:52; the master's (G) 11) — whether a hold is ever written twice, from the official
  source: dnf5 5.4.6.0 (the installed dnf5-5.4.6.0-1.fc44; strings of /usr/bin/dnf5 carry "Package \"{}\" is
  already excluded.") — dnf5/commands/versionlock/versionlock_exclude.cpp at tag 5.4.6.0, exclude_versions():
  an entry of the same name with only `evr !=` conditions gets a condition only for an EVR not already present;
  nothing new → "already excluded", the file not saved. So the TOML need not be read at all. Found on the way:
  up_holds_apply grepped `dnf versionlock list` for "NAME-EVR", which dnf5 never prints on one line (its list:
  "Package name: X" and the conditions under it) — so every press re-ran one `versionlock exclude` per hold, and
  up_hold one per package: a whole set held = ~100 repository loads (minutes) per press. Now each is ONE call
  with all its specs; `versionlock list` is not used any more. The dnf stand-in adds every spec after `exclude`
  (each once, as dnf5). test_update_flow 227/0: one call holds the kernel family (its three specs), the next
  press puts the holds in force in one call, nothing written twice, no list call.

- r27-49-14 (1 Nov 13:52–14:06; the master's (G) 14) — what a run cut before its end leaves (a power cut: no exit
  trap ran) is cleared by the next press, first thing in u_start and before the space is measured (a stale copy
  is gigabytes): lib/update.sh up_leftovers — a root.cand still on the disk's top level (`btrfs subvolume list /`)
  is dropped (the top mounted, cand_drop), and the pinned snapshot in UPD/snap goes back to snapper's number
  cleanup unless a probation lists it (up_probation lists every green run's — those are released when the trial
  closes, as before). Cuts in the transaction or at the check never reach it (the next press resumes, u_start is
  not run). The btrfs stand-in lists root.cand from $FKH/subvolumes and makes it under the (fresh-tmpfs) top, as
  the disk keeps it. test_update_flow 241/0: cut before the transaction → the copy dropped and snapshot 7
  released, both before `filesystem usage`; a green run's snapshot left pinned by the next press; cut in its
  transaction (whole) and cut at the check → the snapshot handed to the probation, never released. Found: two
  "the copy was left behind" checks looked at $W/run, which the fake machine never uses (its /run is a fresh
  tmpfs): vacuous — they read $FKH/subvolumes now.

- r27-49-8 (1 Nov 14:07–14:12; the master's (D) 8, both halves) — (a) the kernel trial is armed only when the boot
  menu is exactly [new, running]: GRUB's way back is the menu's SECOND entry (`set default=1` once boot_counter
  runs out — read on this PC in grub2-tools-2.12-66.fc44's /etc/grub.d/08_fallback_counting), so a third entry (a
  rescue image, a kernel left from before) could put a never-proven kernel there: up_probation reads `grubby
  --info=ALL`'s kernels in menu order and, unless they are "$new $now", arms nothing (no counter, no trial
  arguments, no watchdog) and says why in the log. (b) while a probation names a kernel, u_fetch stores the
  transaction with `--exclude=kernel,kernel-core,…` (KERNEL_PKGS; dnf5(8): "-x/--exclude … This is a list
  option") and says "no new kernel this time: kernel X is still on trial — restart, and the next update brings
  it" — another kernel would take the place of the one GRUB falls back to. Stand-ins: grubby prints $FKH/menu's
  kernels in order when a test gives one; dnf's --store leaves --exclude's names out. test_update_flow 254/0
  (the armed case now names its menu; a third entry → not armed, no watchdog, said; the next press while on
  trial → kernel-core 7.3.1 left out, bash in, said). On the PC: one entry today (7.2.11), so the first press
  ends with [7.2.13, 7.2.11] — armed.

- r27-49-B1 (1 Nov 14:14–14:36; the master's (B), the PC's first press — STOPPED by me before anything changed,
  and its cause fixed) — the merge's whole suite GREEN (128/128 files, 2718 s, /dev/shm/r27p/merge2.log) →
  a353613 pushed (origin/main). Applied HEAD (9c74323) 14:14–14:15: verify 261/262 (the one red: his qbittorrent).
  Presence probe 14:16–14:17 (60 s, swayidle in his session's env): away. Baseline recorded: 1948 rpms, kernel
  7.2.11, mesa 26.2.4, systemd 259.10, glibc 2.43-9; one BLS entry; grubenv boot_success=1 boot_indeterminate=2;
  dnf check-upgrade 117 lines (kernel 7.2.13, mesa 26.2.5 among them); 761 GiB unallocated. Pressed as the menu
  does (`sudo bash /usr/local/lib/fedokawaii/fedokawaii.sh update`, 14:17:31): the run started as
  fedokawaii-update.service, then 14:18:02 "red before the update: the desktop does not start — session-start
  (dark): not running: waybar · nothing drawn" — exactly the baseline the master ruled out (a red desktop label
  in the baseline hides every desktop break after the update). Stopped it at 14:18:27 in its fetch (systemctl
  stop): nothing changed (7.2.11, mesa 26.2.4), no root.cand, the top unmounted, the report "stopped".
  CAUSE, found and proven on the PC: systemd-run executes /usr/bin/bash, labelled shell_exec_t, so SELinux puts
  the unit in initrc_t (`systemd-run … /usr/bin/bash -c 'id -Z'` → initrc_t; `systemd-run … id -Z` →
  unconfined_service_t). There the kit's waybar ends at once with status 0 (its log: the portal's activation
  error, then nothing — "waybar exit 0" recorded in a kept kit), at-spi is denied on the kit's initrc_tmp_t
  folders (32 AVCs, gnome_atspi_t). The same check: green as me, green via sudo + as_user, RED in a transient
  unit, GREEN in the same unit with `-p SELinuxContext=system_u:system_r:unconfined_service_t:s0`. This is the
  master's (E) as well (waybar and mako "not running" in the VM): not VM-only — the unit's domain. FIX:
  fedokawaii.sh update_unit passes `-p SELinuxContext=-system_u:system_r:unconfined_service_t:s0`
  (systemd.exec(5), installed man page: overrides the automated transition, ignored with SELinux off, "-" a
  context it cannot set is no failure); test_front 133/0 asserts it.
  The stop itself showed three faults, fixed: (1) setup.sh's INT/TERM trap printed "✔ Fedokawaii is built —
  reboot" and exited 0 for ANY run on a built system (meant for the install's own final reboot) — now only
  MODE=build says built; every other run says "✘ interrupted — run the same command again / press update
  again (Super+U) to continue" and exits 130 (INT) or 143 (TERM); (2) so the update's report names that line
  instead of "no reason could be written (a full disk?)"; (3) the press returned 0 for a stopped run — now 143.
  The stand-ins: fkh_cut sends TERM to the whole process group (systemctl stop signals the unit's every
  process), and `$FKH/cut-on REGEX` cuts at the first matching stub call. test_update_flow 262/0: stopped
  from outside at the fetch's --store → 143, "interrupted — press update again (Super+U) to continue", never
  "built", report "stopped (fetch): interrupted …", bash not in; the next press goes on to ok.

- r27-49-B2 (1 Nov 14:37–14:44; the master's (B) — THE PC'S FIRST REAL PRESS: OK) — f36e09a applied (14:37–14:38,
  verify 261/262, the red his qbittorrent); both desktop checks GREEN in the fixed unit (`systemd-run -p
  SELinuxContext=-…unconfined_service_t…`: session-start "the bar, the notices, the terminals, quick settings and
  the warm windows up; dwl drawing"; bar-geometry "held — 27 rows, hairlines on x 8 and 1911 …, both themes").
  Presence probe: away. Pressed as the menu does at 14:39:39 (`sudo bash /usr/local/lib/fedokawaii/fedokawaii.sh
  update`; the unit's main process `ps -o label` = unconfined_service_t). The run, from its own log
  (/dev/shm/r27p/update2.out, /var/lib/fedokawaii/update/last.log): the checks before it 14:39:43 — NO red
  before the update (the baseline = verify's one qbittorrent row only); stored 14:40:22–14:41:07 "96 packages to
  update"; "green in the copy: 96 packages" 14:41:48 (41 s: the kernel's posttrans dracut in the copy's scratch
  /boot); signatures checked; snapshot 381 "before update 2026-11-01", pinned (snapper cleanup empty); the replay
  14:41:49; the desktop's steps 14:42:31–14:43:15 (toolkit, pinned binaries "in place", dwl at its commit, theme
  "all 638 files already in sync", guard, sound, GTK); verify after: 1 of 262 (qbittorrent — in the baseline, so
  not new); the desktop check after: green; 14:43:52 "kernel 7.2.13-200.fc44.x86_64 on trial at the next start:
  three starts to reach the desktop, else 7.2.11 again"; "update done (ok): updated · 96 packages — the next one
  in 90 days"; the press's exit 0. 4 min 17 s. The probation as designed: grubenv boot_counter=3 boot_success=0
  boot_indeterminate=1; the menu [7.2.13, 7.2.11] (grubby --info=ALL index 0/1 — the (8) check armed it); the trial
  arguments "rd.shell=0 rd.emergency=reboot rd.retry=30 panic=10" on 7.2.13's entry only; the watchdog drop-in
  /etc/systemd/system.conf.d/90-fedokawaii-probation.conf "RuntimeWatchdogSec=1min" (read by PID 1 at the next
  start: systemd itself was not updated, no re-exec); UPD/probation "381 7.2.13-200.fc44.x86_64 2026-11-01";
  report "ok · updated · 96 packages". Numbers before → after: rpms 1948 → 1952; kernel 7.2.11 → 7.2.11 + 7.2.13;
  mesa-dri-drivers 26.2.4 → 26.2.5; systemd 259.10, glibc 2.43-9 unchanged. Left by dnf itself, rightly: libheif
  1.23.7 (+ libheif-ffmpeg, i686) — RPM Fusion's libheif-freeworld is 1.23.6 and needs its libheif's version
  (`dnf upgrade --assumeno libheif`: "Skipping packages with conflicts" / "broken dependencies:
  libheif-freeworld"): the next press takes it once RPM Fusion has caught up. STILL OPEN: the trial closes at the
  next start (a reboot ends the bulk run r27-bulk-*, 10:36 + 12 h — so after 22:36, or his own restart): then
  fedokawaii-boot-good's journal or the kernels timer, the pin released, 7.2.11 removed.

- r27-49-E1 (1 Nov 14:46–14:52, the VM proof of (E)/(F), run 5: tools/vm-inject/update-button.sh f44b from
  aa9366a) — the mechanics all held (three presses → one unit, ONE InvocationID b2903890… at the first press and
  after the second and third, the presses only past the first unit's checks, exit 0 with the run's own last line,
  the report ok, a stopped run 1 with its reason), and the SELinux fix showed in the VM too: session-start GREEN
  before the update (waybar up — it was red under initrc_t). But the new row was BROKEN: "red before the update:
  the desktop does not start — bar-geometry (light): the clock's gaps:  (want 14 …)" and after it "… —
  session-start (dark): not running: mako", and the run still ended "update done (ok)": one label, "the desktop
  does not start", so the red before masked the red after — the blindness the master named. Causes: (1) the
  proof copied only the toolkit into the 27-Oct VM, so a newer toolkit's bar measure met the VM's older theme
  (bar-geometry red) and the update's theme step then wrote a notices config for the patched mako the VM never
  had (mako red after); the PC is never in that state (apply runs repair); (2) the label granularity.
- r27-49-master-2 (1 Nov 14:46–15:20; .claude/notes/master-T45-efh-verdict.md "Re-review 2"): VERDICT 2 FAIL until
  must-fix 1–5; (B) the PC's press (ok up to the trial's close), (D) 8, (G) 11/14/18, the signal trap and (F)'s
  harness stand. Must-fix: (1) the desktop check compared by label only — any red before hides any after
  (lib/update.sh up_labels) → say a red baseline in the report, a test row; (2) (E) not fixed in the VM — find the
  VM's cause, then the three proofs green; (3) test_setup.sh:303 greps the removed trap line (the suite on HEAD:
  test_setup 232/1); (4) the "-" in SELinuxContext=- is a fallback — an unsettable context runs the unit silently
  in initrc_t (its probe), without "-" it fails loudly (229/SELINUX_CONTEXT): drop it, u_start asserts its
  domain; (5) the fake machine copies this PC's /etc — the PC's real trial drop-in made test_update_flow red
  (261/1 twice): scrub every /etc file the toolkit owns, rows assert their precondition. Should-fix: (1)
  up_leftovers releases an OFFERED run's snapshot at the next press (the one the report pointed him to); (2)
  manifest/hardware installs after the replay run outside the copy-proven transaction (VM: python3-pyte, wlrctl,
  wireless-regdb) — store them or write the exception in the design and the Learn piece; (3) stdbuf's LD_PRELOAD
  reaches dnf's scriptlets: 6 setfiles_t AVCs per update; (4) hold_families merges python3-foo + python3-bar at
  one version and reason (contradicting its comment) — use UPD/sources when present; (5) a stopped unit stays
  "failed" until the next press: a line in the Learn piece. It verified from sources: dnf5 5.4.6.0's dedupe,
  rhboot grub2 blscfg.c (filename vercmp, newest first) = grubby's order, systemd.exec(5), restorecon -n over the
  25 611 updated files (clean), the PC's grubenv 3/0/1, menu [7.2.13, 7.2.11], snapshot 381 pinned.
- r27-49-master-2-fixes (1 Nov 15:00–15:31, on branch `next` = worktree ~/repos/fk-next, so the master's view of
  main stayed still): must-fix 1 — lib/update.sh desk_reds: the desktop check's verdict a line per item, the item
  in the label ("the desktop does not start: not running: waybar", "…: nothing drawn", "…: bar-geometry (light):
  the clock's gaps", "…: dwl does not start"): a red before never hides another after; a kept update with a red
  desktop baseline says so in its line ("· the desktop's check was red before it, so not judged (Super+U → log)")
  and lists them in the report ("red before it: …"); rows: a bar red before + dwl gone after → offered, held; the
  waybar-red baseline's report lines. Whole lines were weighed and not taken: the verdict's details vary run to
  run (a colour count, timing) and would undo good updates. Must-fix 3 — test_setup checks on_signal's form and
  the TERM trap; the behaviour is test_update_flow's TERM row. Must-fix 4 — no "-": a context systemd cannot set
  fails the unit; u_start dies in any domain but unconfined_service_t (the unit) or unconfined_t (by hand) while
  SELinux is on (selinuxenabled), so no run begins blind; test_front asserts the property without "-". Must-fix 5
  — tests/installer/lib.sh scrubs, besides files that say fedokawaii: files NAMED *fedokawaii*/*scriptorium*/
  kawa-*, and the unmarked ones the toolkit or its tools keep (/etc/snapper, /etc/sysconfig/snapper,
  /etc/default/grub-btrfs, /etc/profile.d/editor.sh, the Claude Code repo key, the round's sudo rule — found by
  listing every /etc path setup.sh writes and grepping the PC's copies for the marker); the probation drop-in now
  says "installed by fedokawaii"; the third-entry row asserts its precondition (no drop-in before the run). (A
  pristine /etc instead of this PC's copy: T53.) For (E) in the VM: the update's steps now build the patched mako
  when it is off its pin (before the theme writes its config; test_upkeep row, 255/0), and the three update proofs
  start from `vm-run.sh --apply` (the copy applied as the PC is, then restarted until nothing waits).
- r27-49-E2 (1 Nov 15:15–15:30, VM proof run 6 from `next`): the apply in the VM went through ("verify: 13
  problem(s) before, 0 now"), but every press then stopped at its start: "an earlier update is waiting to be
  installed at the next restart" — the apply had queued the /home split (T48) for the next start through
  /system-update, exactly as on the PC this morning; the update rightly refuses. Fixed: vm-run.sh --apply restarts
  the VM until nothing waits (3d25e97). Run 7 started 15:31.

- r27-49-E3 (1 Nov 15:31–15:40, VM proof run 7: update-button.sh f44b from `next` 3d25e97) — ALL NINE ROWS HELD,
  the master's (E) among them: the VM applied as the PC is (vm-run.sh --apply: "repair done — verify: 13
  problem(s) before, 0 now", dwl re-patched and built, 15:34:55; nothing waited for a restart this time), then the
  three presses: ONE invocation (900aab59… at the first press and after the second and third), each exit 0 with
  the run's own last line "update done (ok): updated · 61 packages"; the checks before it 15:35:30 with NO red
  ("the desktop does not start" appears 0 times in the units' journal + run.log, /dev/shm/r27/update-button-f44b/
  units.txt); "61 packages to update" 15:36:42; "green in the copy" 15:37:21; kernel 7.2.13 on trial 15:39:47;
  the report ok; the stopped run 1 with its reason. So the VM's red was its staleness (a toolkit newer than its
  theme and builds), not the button. Run 6's "an earlier update is waiting … restart first" after the apply did
  not come back in run 7 (same base, newer tree); its cause is not known — its evidence was overwritten by run 7
  (the same out dir): the --apply restart loop stays as the guard, and update-green/probation (both from --apply
  now) watch for it next pass.
- r27-flaky-1 (1 Nov 15:40): the whole suite on aa9366a (3222 s, /dev/shm/r27p/head3.log) had a third red besides
  the two fixed on next — session/test_dwlstatus.sh's "a burst of 1125 lines … one title poke per change" (178/2
  and 179/1 under the VM + two suites + test files at once); 5 re-runs alone or with one suite: 180/0 each.
  kawa-dwlstatus is untouched by this pass: a load-sensitive count in the test (pokes lost under load) — for T52/
  T53: make the count robust (the stand-in's poke log, not signal delivery) without weakening the "one per change".
  FIXED 16:05: the stand-in already queues every poke (real-time signals, sigwaitinfo) and logs a "flush" queued
  after them; tests/session/lib.sh pokes() waited only ~10 s for it, then counted a partial log — now up to a
  minute, and no flush is reported as that, never counted. The "exactly one poke per change" stays. Session area
  19/19.

- r27-49-E4 (1 Nov 15:42–15:52) — update-green.sh f44 from `next` (applied first): exit 0 in 342 s, report "ok ·
  updated · 61 packages", the checks before it 15:46:05 with no red, "green in the copy" 15:47:46, kernel 7.2.13 on
  trial, "the desktop does not start" 0 times in its log (its new assertion held). The `next` areas on fa1beb3:
  installer, static, engine all rc 0 (1365 s, /dev/shm/r27p/next-areas.log); with the whole suite on aa9366a
  (all other areas green but the load-sensitive row, r27-flaky-1) → merged `next` into main (bab147c), PUSHED;
  the worktree and the branch removed. Applied bab147c on the PC 15:53–15:54: verify 261/262 (his qbittorrent);
  the trial intact — its arguments on 7.2.13, boot_counter=3 boot_success=0, the watchdog drop-in — repair's boot
  step adds BOOT_ARGS and removes only BOOT_ARGS_GONE (plymouth.use-simpledrm), never the trial's.
- r27-49-sf1 (1 Nov 15:53–16:00; the master's should-fix 1) — an "offered" report's snapshot (the way back it
  named) is no longer released by the next press: up_leftovers keeps it pinned in UPD/offered, and the next kept
  update's up_probation hands it to the probation, which releases it with its own when the trial closes. (The
  report's first line read with IFS=' ': setup.sh's IFS is newline and tab.) test_update_flow 277/0 (the press
  after an offered run: not released, in the probation, released by --boot-good). Pushed c1841f6; applied on the
  PC 15:59–16:00 (verify 261/262, the trial still armed).

- r27-49-sf2-5 (1 Nov 16:04–16:30; the master's should-fix 2–5 decided, main): (3) stdbuf GONE from dnf_detached —
  measured first, dnf5 5.4.6 without it into the journal (systemd-run, StandardOutput=journal): every line as it
  comes (makecache: "Updating and loading repositories:" 16:04:57.27, the repos' lines 16:05:01.08; a download of
  three packages: kernel-core's line 16:05:30.00, linux-firmware's :35.16, kernel-modules' 16:06:08.43), so the
  window still follows dnf live; the PC's press of 14:39 had 6 AVCs `restorecon (setfiles_t) denied map
  /usr/libexec/coreutils/libstdbuf.so` (ausearch -m avc -ts today | grep -c libstdbuf → 6). test_upkeep asserts no
  stdbuf in the unit; update-button.sh and update-green.sh gained a row "no SELinux denial in the presses/run"
  (ausearch(8) --checkpoint before, the new AVCs after, kept in avc.txt). (4) each hold records its SOURCE package
  (UPD/holds: NAME HELD AT DATE SOURCE WHY; up_hold from up_sources — u_undo now computes it too; the kernel's
  probation hold "kernel"); hold_families groups by source, a package alone by its own name, two sources never
  merged (no prefix guess left; UPD/sources removed with the stored set); no holds existed anywhere (the PC: none),
  so no migration. Rows: python3-foo + python3-bar (python-foo, python-bar) at one version and reason → two
  families; a kernel family named "kernel" in the report, never kernel-core. (2) DECIDED, written: update-design
  §2.5 — the toolkit's own steps after the replay (manifest's missing packages, hardware firmware, pins, fonts,
  builds, theme) are outside the copy by design, proven by the toolkit's own proofs before they reach him, judged
  by the same after-checks; one `dnf5 do --store --action=upgrade --action=install …` was weighed (dnf5-do(8) has
  --store) and not taken: one unresolvable want would stop the whole update. (5) the Learn line (a stopped unit
  stays "failed" until the next press) and (2)'s line: owed to T50, written into its acceptance. Tests:
  test_update_flow 283/0, test_upkeep 256/0, test_menu rc 0, test_status rc 0; static test_syntax 691/0,
  test_tools 15/0, test_pipefail 1/0; ShellCheck (-S warning) clean on the four changed scripts.

- r27-49-R3 (1 Nov 16:21–): the master's Re-review 3 of T45 STARTED 16:25 (Fable, max; brief
  /dev/shm/r27/master/T45-3/brief.md; it reads the frozen checkout /dev/shm/r27w-master = 78ea68c, pushed) with
  the evidence still coming in: probation.sh f44b from 766b434 (fail case HELD 16:19: "held in 213 s after the
  restart · running 7.2.11 · counter off · probation closed · default 7.2.11"; the pass case running),
  update-green.sh f44 re-run from 78ea68c (the new SELinux-denial row) → /dev/shm/r27p/green-78ea68c.txt, and
  the whole suite on 78ea68c from /dev/shm/r27w-suite → /dev/shm/r27p/suite-78ea68c.log — started with the PC's
  kernel still on trial (grubenv boot_counter=3 boot_success=0, the probation drop-in present). RESULTS: probation
  fail HELD (213 s) + pass HELD (173 s), exit 0; the whole suite on 78ea68c rc 0 in 2915 s (every area green, the
  trial open throughout — the world independent of the PC's state); update-green from 78ea68c HUNG (r27-49-hang).

- r27-49-hang (1 Nov 16:26–17:00) — FOUND by the re-run of update-green.sh f44 from 78ea68c: the update HUNG after
  its transaction. Evidence (/dev/shm/r27/update-green/hang.txt, the VM's journal and process tree): the replay's
  unit fedokawaii-dnf-1793536088-1277 "Deactivated successfully" 16:28:47.27 (61 packages, systemd 259.10 among
  them), PID 1 reloaded 0.7 s before (16:28:46.48, "Reload requested from client … systemctl"), the user managers
  re-executed, scriptlets failing "Failed to start transient service unit: Remote peer disconnected" — and
  `systemd-run --wait` (dnf_detached) still waiting 18 min later for a unit already collected, load 0. Intermittent:
  the same set passed in E4, both probation runs and the PC's press. systemd's own %posttrans runs `systemctl
  daemon-reexec` on every upgrade (rpm -q --scripts systemd). Not reproducible bare on the PC: a unit running
  `systemctl daemon-reload` (12×) or `daemon-reexec` (5×) just before its end — --wait returned each time; no
  upstream report found (the nearest: the daemon-reload vs client race, systemd PR #8803 via Launchpad). FIXED (not
  by retrying --wait): dnf_detached starts the unit with RemainAfterExit=yes and no --wait/--collect; dnf_end asks
  `systemctl show -p ActiveState -p SubState -p ExecMainCode -p ExecMainStatus` once a second (a fresh connection
  each time: no signal to lose) → exited N, killed 128+N; the unit then stopped and reset-failed; dnf_settle clears
  ended units a cut run left before looking for a running one (--state=running). Stand-ins: systemd-run records
  "ended UNIT RC", systemctl show/list-units/stop/reset-failed answer from it; rows: no --wait/--collect, the end
  read by show, nothing left; a dnf killed by TERM → "could not be installed now"; two ended units of a cut run
  cleared first, never "still going" (that row first failed: dnf_settle ran under dnf_detached's `local IFS=' '`,
  so two ended units read as one word — now mapfile, a line each). The update-green proof was stopped (the hung
  run; its VM shut down). PROVEN after the fix (local commit 79cd435, from a frozen worktree): update-green.sh f44
  exit 0 in 304 s — "ok · updated · 61 packages" (systemd 259.10's re-exec in it, the end read by asking), the
  checks before it 17:02:03 with no desktop red, green in the copy 17:04:20, 7.2.13 on trial 17:07:03, and
  avc.txt EMPTY: no SELinux denial in the whole update (the PC's press with stdbuf: 6). Kept:
  /dev/shm/r27/master/T45-3/green-79cd435/ (the proofs clear their own folders at the next run — the hang's
  captured output: /dev/shm/r27/master/T45-3/hang-evidence.txt). And update-button.sh f44b from 79cd435: all TEN
  rows held — the three presses exit 0 on one invocation, the desktop check green before and after, the report
  ok, the new "no SELinux denial in the presses", the stopped run 1 with its reason (kept: …/T45-3/button-79cd435/).
- r27-52-file (1 Nov 16:30–17:00; T48's "a file, back", was a "soon" placeholder) — Super+U → snapshots → a file,
  back: /home's snapshots (snapper's hourly and daily ones) listed newest first (number, time, today/yesterday/
  date — one `date -f` for the whole list), a number → kawa-pick in a new `back` mode inside the job window at
  that snapshot's copy of the home (yazi heading "as it was at 16:00 · ~/Documents", keys "space mark · q this
  folder": Enter takes a file or the marked files and folders, Enter on a folder goes in, q takes the folder you
  are in) → copied with reflinks into ~/Restored/DATE-TIME/ (kawa-backup restore's folder rule), a second of one
  name beside it as "name (2)", never over anything, an answer outside the snapshot taken as nothing; no
  password: setup gives /home/.snapshots (0750 root, snapper's) his group — never snapper's ALLOW_USERS, which
  would let anything running as him delete them; verify checks root:GROUP 0750. (acl is not installed here:
  group ownership instead of an ACL — no package for one directory.) Rendered both moods with the kit
  (/dev/shm/r27p/kit-fb/{dark,light}-{1,2}-win.png) → found and fixed: the rows sat one column left of the
  heading's icon and ended two short of its rule — AND the existing "go back" list never ended its rows' lines
  (screen_row prints no newline: in the job window every system snapshot ran into the next — untested, the
  tests ran without a terminal); both lists now a row a line, the icon under the heading's, the date ending
  where the rule ends; rows `aligned` assert it on a pty; re-rendered after the fix (dark-1b-zoom.png, 2×): the
  hourglasses under the heading's page icon, "today"/"26 Oct" ending on the rule's last pixel column. Tests: test_menu 663/0 (homesnaps: three snapshots,
  the flow, a folder + two of a name, cancelled / none / not listed / outside, unreadable, none yet, the pane,
  the popup hand-off; the plain menu's fifteen entries), test_pick 101/0 (back: file, marks, q, Esc, the dress),
  the engine area's other 11 files with the pointed HOME_SNAPS, the yazi area rc 0.

- r27-49-master-3 (1 Nov 16:25–17:15; the master's Re-review 3 of T45 at 78ea68c, appended to
  master-T45-efh-verdict.md): VERDICT 3 FAIL until must-fix 1–3. Proven and standing: Verdict 2's must-fix 3/4/5 and
  1's session half, should-fix 1–5 (built or decided), run 7 (9/9), probation fail + pass (exit 0), the suite on
  78ea68c rc 0 with the PC's kernel on trial throughout, the stdbuf measurement (checked in the PC's journal), the open
  items stated as open. Must-fix: (1) the hang (r27-49-hang) — 79cd435's shape is right; proofs wanted: a stub row,
  update-green ×2 and update-button ×2 from the fixed commit, one under a daemon-reload storm; (2) lib/guard.sh
  desktop_starts kept only the bar check's LAST red line (`tail -n 1`): an old bar red (the clock's gaps, its last
  check) still hid a new one (rows: the bar growing, its first) — Verdict 2's must-fix 1 was closed only for
  session-start; (3) the kept-with-red-desktop suffix (82 characters) overflowed the status row (94 columns in a
  50-column pane, `fedokawaii status` ≤ 44) and was dropped silently with holds — untested. Should-fix: the VM
  proofs' SELinux rows cannot tell "no denial" from "no audit log" (ausearch exits 1 either way); probation fail
  from the fixed commit (the "kernel" SOURCE line is stub-proven only); §2.5's reason must meet --skip-unavailable;
  the ledger to record the 78ea68c green run as hung (done in r27-49-R3 and -hang).
- r27-49-master-3-fixes (1 Nov 17:15–17:22, ad94381, local until its areas pass): (2) desktop_starts passes EVERY
  `^bar-geometry (`/`^session-start (` line on (desk_reds labels each); the stand-in prints a line per item, THEME:
  prefix as bar-geometry.sh says it; replay-breaks-bar puts its rows red FIRST, before a bar red that was there;
  test_update_flow row: light clock's gaps red before + dark rows after → offered, gtk3 held. (3) the report's line 2
  says the fixed short " · desktop red before: not judged"; its lines 3+ "its desktop items red before it were not
  judged:" and the items; the status shows "desktop red before: not judged" on a continuation line of its own (with
  holds or without); test_status 216/0 with rows ≤ 44 both ways and the pane ≤ 50. Should-fix 1: both VM proofs
  record auditd's state and the log's presence (avc-instrument.txt) and fail the row without them; 3: §2.5's reason
  rewritten (--skip-unavailable covers a missing want, not a conflicting one, which stops the one resolve and
  Fedora's upgrade with it; --skip-broken would drop parts of the upgrade: a partial upgrade). update-green.sh got
  STORM=1: `systemctl daemon-reload` in a loop from a second ssh while the run's phase says replay (15 min cap),
  the count kept. Running: the installer, engine, static areas (/dev/shm/r27p/mf-*.log); update-green STORM=1 (f44)
  and update-button (f44b) from ad94381 (/dev/shm/r27p/{green-storm,button}-ad94381.txt). RESULTS: the areas on
  ad94381 installer rc 0 (1355 s), engine 0 (323 s), static 0 (27 s); update-button from ad94381 all TEN rows held
  (avc-instrument: auditd active, its log there); the FIRST STORM wedged the VM's PID 1 — an unthrottled reload
  loop span at ≈440 calls/s (refused fast), 396 414 in its 15 minutes, after which systemctl from ssh timed out and
  ssh could not open a session; dnf_end was alive and polling (a `sleep 1` under it at 1108 s) — a flood no
  transaction makes, recorded in /dev/shm/r27/master/T45-4/storm-1-wedged.txt; the storm is now synchronous and
  throttled (a reload, then 0.2 s) and re-run. probation.sh fail from ad94381 started 17:34 (f44b).

- r27-49-apply6 (1 Nov 17:53–17:54): 9280e4b APPLIED on the PC (the polled dnf end, a file back, the go-back rows,
  every bar line, the short desktop note): repair "3 problem(s) before, 1 now"; verify 262/263 — the one red his
  qbittorrent (outside the manifest, known); the new row "your files' snapshots readable by you" passes:
  /home/.snapshots root:dia 0750, his newest snapshot's home listed as dia; the installed menu has file_back. The
  kernel trial untouched (grubenv boot_counter=3 boot_success=0 before and after).
- r27-inbox-1710 (owner, 1 Nov 17:10): "make sure you study the fedora 45 update well and utilize it fully like they
  switched to a newer python and such" → plan T46b (the F45 ChangeSet triaged into .claude/notes/f45-changes.md,
  Python first: every Python program of ours on F45's Python with no deprecation warning, the uv CPython pins
  moved; adopted changes proven in vm-smoke f45 and on the PC after its upgrade); master-trace row r27-inbox-1710. A
  research agent (sonnet) collects the raw facts now → .claude/notes/f45-changes-raw.md (no decisions). WRITTEN
  18:30 (475 lines): 46 accepted changes (19 system-wide, 27 self-contained; = Category:ChangeAcceptedF45), Final
  GO for Tue 3 Nov (RC-1.4); python3 3.14.8 → 3.15.0 (What's New 3.15's removed/deprecated lists linked), systemd
  259.10 → 262.1 (its 260–262 incompatible changes listed), podman 5 → 6, llvm 22 → 23, ffmpeg-free 8 → 9; Mesa,
  PipeWire, wlroots 0.20.2, waybar, mako, neovim keep their upstream versions; every third-party repo here serves
  F45; all 189 manifest names resolve in F45; a live blocker: RPM Fusion's mesa-va-drivers-freeworld 26.2.6 needs
  mesa-filesystem 26.2.6, F45 stable has 26.2.5; the official F45 release notes not published yet (404).
- r27-49-R4 (1 Nov 17:55–): the master's Re-review 4 started (brief /dev/shm/r27/master/T45-4/brief.md; reads the
  frozen /dev/shm/r27w-review4 = 9280e4b); its evidence still arriving: the whole suite on 9280e4b
  (/dev/shm/r27p/suite-9280e4b.log), update-green STORM=1 throttled from 9280e4b (/dev/shm/r27p/green-storm-9280e4b.txt),
  probation fail from ad94381 (/dev/shm/r27p/prob-ad94381.txt) → HELD in 213 s, exit 0, and its hold line in the VM
  "kernel-core 7.2.13-200.fc44 7.2.11-200.fc44 2026-11-01 kernel did not reach the desktop in three starts" (the
  SOURCE field, the master's should-fix 2, proven outside the stand-ins; kept: T45-4/probation-ad94381/).

- r27-49-pid1 (1 Nov 17:52–18:30) — the THROTTLED storm (update-green STORM=1 from 9280e4b: a synchronous
  daemon-reload every 0.2 s while the phase said replay) made 100 reloads, all answered — then the VM's SYSTEMD
  CRASHED: journal 17:58:51.09 "Reload requested from client … (unit session-7.scope)" [the storm's ssh], 0.02 s
  after one from the replay unit's own scriptlet, "Caught <ABRT>, from our own process … dumped core as pid 87311
  … Freezing execution." (systemd-259.10, during its own upgrade). PID 1 frozen: State S, every systemctl
  "Connection timed out", sudo dead (PAM); dnf_end alive and polling 13 min after the end. The first (unthrottled)
  storm wedged its VM the same way (its journal gone with the revert). So an external reload during systemd's own
  upgrade crashes PID 1 here; the storm cannot force the lost-signal race without killing PID 1 first — reported
  to the master mid-review (evidence /dev/shm/r27/master/T45-4/storm-2-pid1-crash.txt; the run stopped 18:17, the
  VM powered off). BUILT (main, after 9280e4b): dnf_end, when `systemctl show` gets no answer, dnf's own process
  is gone and the journal (read without PID 1) holds PID 1's "Freezing execution" → 125; dnf_detached then stops
  the run: "systemd, the system's own manager, crashed while dnf ran … restart the PC (hold its power button if it
  does not go down); the next start finishes the update, or puts the system before it back" (the phase stays
  replay: fedokawaii-update-resume finishes or undoes it at the next start). Stand-ins: journalctl answers `_PID=1
  -g` from $FKH/journal-pid1; systemctl `show` can stay silent N times ($FKH/fail-show-silent). Rows: the crash →
  said, the run stopped; three silent answers, no crash in the journal → asked again, bat in, no crash said.
  update-design §5 rows 45 (the hang) and 46 (PID 1's crash). Areas running: installer + static
  (/dev/shm/r27p/p1-*.log).

- r27-49-halt (1 Nov 18:56–, the pass's step (0), the last pass's lead) — CONFIRMED by reading: dnf_detached's crash
  answer (125 → die) ran inside a pipe whenever the dnf came through dnf_install/dnf_do (dnf_try_sub's
  `$(dnf … | tee)`) or run, and inside contained in repair's heal: the die ended only that piece, so dnf_install
  read the words as "other" and tried again (4 tries, 15/30/45 s, each new dnf_settle and systemd-run against a
  frozen PID 1: 25 s timeouts in real life), then said "dnf could not install … other" — the crash said four
  times and buried. BUILT: lib/common.sh `halt` — die for the whole run (marks $KAWA_TMP/halt, exits 125) — and
  `pass_halt`, which run, dnf_try_sub and contained call after their pipe/subshell, so a halt from any depth ends
  the run there; dnf_detached halts on 125. AND FOUND (reading u_report for the crash's promise "the next start
  finishes the update, or puts the system before it back"): u_report wrote phase "end" for EVERY stopped run —
  a stop in replay, steps or check (PID 1's crash, a stop from outside, any die there) lost the fact that the
  running system had changed: the next start's update-resume saw "end" and did nothing, and the next press
  started a NEW update over one never judged (its baseline taken after it: a red it caused would read as "red
  before, not judged"). Now a stopped run keeps a changed phase (replay | steps | check); UP_STAY, the one case
  that kept it (the desktop check that could not run), folded into that rule. Stand-in: systemd-run's crash-on
  (a regex: that dnf ends with PID 1 frozen — every `show` unanswered, the journal's "Freezing execution").
  Rows: test_upkeep "…systemd itself crashed while dnf ran": RC 125, said ONCE, no "dnf attempt", no "could not
  install", one systemd-run; test_update_flow: the crash in the live replay → 125, said once, report "stopped
  (replay): systemd …", phase replay, nothing held → the next start (PID 1 whole): every package in → steps,
  "cut off after its packages went in" at login → the next press ok, nothing replayed; stopped from outside
  (TERM) in the transaction → 143, phase replay → the next press "finishing it first", not whole → offered, held.
  tools/vm-inject/update-green.sh STORM=1 now updates systemd's own packages first, outside the run (a storm
  during systemd's own upgrade crashed PID 1: r27-49-pid1), so the storm meets the rest of the set and the
  reloads its scriptlets ask. Tests: test_upkeep + test_update_flow from the tree (/dev/shm/r27p/p3-*.log).
- r27-50b (T46b, 1 Nov 19:10–19:40): .claude/notes/f45-changes.md — the 46 accepted changes and the version
  jumps triaged (adopt · adapt · verify · none), Python first. Done here: all 52 Python programs of ours
  COMPILE under CPython 3.15.0rc3 with -W error (0 failed), their 67 stdlib imports load under 3.15 with
  -W error (no DeprecationWarning), none uses an API 3.15 removed (grep of What's New's lists); nothing of
  ours outside RPM links OpenSSL 3 directly (readelf -d of /usr/local/{bin,sbin}, ~/.local/bin, the private
  wlroots: none; satty only through RPM libraries F45 rebuilt); no nspawn --user=, journalctl -F,
  Type=notify-reload, logind Can*(), SysV/rc-local, pkg_resources in our code (grep); only our own two
  .repo files are read from /etc/yum.repos.d (verify.sh:193); Prowlarr's podman is sqlite · netavark ·
  cgroups v2 (all podman 6 keeps). libtorrent's PyPI wheels still stop at cp313 (pypi.org/pypi/libtorrent/json:
  2.1.1) — but Fedora ships rb_libtorrent-python3 2.0.11 for the system Python (F44 -5, F45 -9): T29 measures
  torrra on Fedora's python3 with it (would drop uv's 3.13). Five things to build, each in its task (the file's
  end). (The 3.15 interpreter came from `uv python install` into /dev/shm — it ALSO linked ~/.local/bin/python3.15:
  removed at once; memory: --no-bin.)

- r27-49-R4b (1 Nov 19:20–): the master's Re-review 4 started again (the 17:55 one never wrote its verdict: its
  pass ended) — on 2b12615, brief /dev/shm/r27/master/T45-5/brief.md (every evidence copy under T45-5/; frozen
  checkout /dev/shm/r27w-review5 = 2b12615). Running from it: the whole suite → /dev/shm/r27p/suite-2b12615.log,
  test_upkeep + test_update_flow alone → /dev/shm/r27p/p4-*.log.
- r27-49-storm3 (1 Nov 19:14–19:31) — update-green STORM=1 from 2b12615 (systemd's packages updated first:
  storm-systemd.txt 259.10): exit 125 in 147 s. PID 1 CRASHED AGAIN without systemd in the set — journal of the
  VM's last boot: 19:21:00.432 Reload from the replay unit's scriptlet, "Reloading finished" .566, 19:21:00.583
  Reload from the storm's session → "Caught <ABRT>, from our own process … dumped core as pid 87416 … Freezing
  execution". The core dump's stack (coredumpctl info 87416): __assert_fail ← method_reload ←
  object_find_and_run ← bus_process_object ← … manager_loop. Upstream source: method_reload in
  src/core/dbus-manager.c asserts !m->pending_reload_message_dbus and !m->pending_reload_message_vl (v259 AND
  v262 — Fedora 45's — the same: raw.githubusercontent.com/systemd/systemd/v259|v262/src/core/dbus-manager.c);
  no upstream issue found (gh search issues "pending_reload_message", "method_reload assertion": none; the
  nearest, #43001, is another reload bug). So: a systemd bug — a Reload from any client while an earlier
  reload's reply is still pending aborts PID 1; sequential clients cannot hit it, an independent one can (the
  storm; on the desktop: rare, never from the update itself). Not ours to fix (we do not build systemd); an
  upstream report drafted for the owner, not posted (outward-facing). THE WHOLE ANSWER PROVEN on the VM as the
  proof left it (booted without a revert): the run's log "19:21:01 ✘ systemd, the system's own manager, crashed
  while dnf ran …" once, report "stopped (replay): …", phase replay kept (2b12615's fix); the VM force-stopped;
  the next start's fedokawaii-update-resume (19:27:37): every package in → phase steps, his notice; the next
  press (19:29–19:31): "the last update was cut off after its transaction — its steps and checks again" →
  "update done (ok): updated · 61 packages", phase end. Evidence: /dev/shm/r27/master/T45-5/storm-3-pid1-crash.txt
  (+ green-storm-2b12615/); told to the master mid-review. update-design §5 row 46 rewritten with the cause.
  The storm cannot force the lost-signal race: every throttled storm (2 of 2) crashed PID 1 first.
- r27-52-restore (T48, 1 Nov 19:18–19:50): Super+U → backups → **restore** and **the drive** built (both were
  "soon"). restore (system/fedokawaii backup_back, as you): kawa-backup's backups newest first — number, time,
  day (the same rows as "a file, back": time_rows, shared now) — a number, then Enter: that backup opened
  read-only (`kawa-backup mount`: restic mount, FUSE, in $XDG_RUNTIME_DIR, its own shell with an EXIT/HUP/TERM
  trap so a closed window never leaves a mount), kawa-pick's back mode inside it under "as it was yesterday at
  21:00", the picked copied into ~/Restored/DATE-TIME (restored_dir + restore_into: configs/home/.config/
  fedokawaii/files.sh, now shared with file_back and kawa-backup restore — a second of one name "name (1).ext"
  as everywhere, a folder never split at a dot); or **a**, then yes: `kawa-backup everything ID` = restic
  restore ID:FOLDER --target ~ --overwrite never (restic 0.19.1's own option: what is missing comes back,
  nothing there is changed — tried first on a scratch repo). the drive: the row shows the drive's short name
  (a path or an address by its last part, only where it fits its 23 columns — the first render showed a long
  path hard-cut by fzf: fixed), the pane (kawa-backup drive: never opens a drive) its whole name in pieces at
  spaces, / and : (never cut), plugged in · free of size / not plugged in (vermilion) / none chosen yet
  (vermilion), and the last backup; Enter = kawa-backup's picker (pick). restore's own icon ICON_UNPACK (it
  shared go back's UNDO). fuse3 in the manifest (restic mount's fusermount3; PACKAGES.md, the deps fixture).
  The pane had to be allowed in explain()'s list (SOON had carried both: the first render showed an empty
  pane — caught by LOOKING). Rendered in the kit, both moods (/dev/shm/r27p/kit-bk/: the list, the choice, the
  dialog inside the backup, the result "as it was yesterday at 21:00, into ~/Restored/…: Documents/notes.md
  ✓ finished", the menu's backups tab with each pane): the rows under the heading's icon, the day ending on the
  rule's last column, the choice's keys in the words' ink and what they do muted (screen_keys' grammar). New
  tool: tools/kit-keys.py (a text screen driven by timed keys in a pty, drawn live — keyed renders several
  screens deep; its own terminal raw, so the terminal's focus reports never echo) and kit.sh --tui-wait S.
  Tests: test_backup 228/0 with the REAL restic (times newest first; mount through FUSE: a file read inside,
  nothing writable, ends with the unmount; everything: the missing folder back, his changed file kept; drive's
  six states, never opening one), test_menu (restore: rows, a pick, a then yes / no, a number not listed, the
  dialog cancelled, a backup that cannot be opened — nothing left behind, no backup yet, not plugged in; the
  drive's pane and row; restore's icon), static 13/13, deps, pick, clipfiles, shrink green. Learn book §8.1:
  both rows. (The PDF waits for his word, as every round-27 edit.)
- r27-suites (1 Nov 19:14–20:12): the whole suite on 2b12615 rc 1 in 3282 s — 126 of 128 green; the two red
  exactly the two fixed after it: installer/test_update_flow (the crash row counted the report's closing
  line too → 878f1fd, the file alone green in 427 s) and content/test_brave (5 rows: the wrapper took ANY
  running Brave of the user for "open" — the owner's own, live — → 0b45f65 reads its profile's SingletonLock;
  30/0 with his Brave running). The suite on 2074718 was stopped (superseded); on 0b45f65 started 20:03.
- r27-19m-p1 (1 Nov 19:58–20:15, T19m (b) pass 1 begun): the gallery rendered from the repository (27
  surfaces, both moods, /dev/shm/r27/audit/p1) — every box the same in both moods; tools/audit-pads.py
  (new) measured every surface's paper round its content; .claude/notes/audit-r27.md holds the table, the
  readings, the method lessons (judge at 1×; measure whole ink boxes, never one row) and two open findings
  for pass 2 (panels' row indent vs text screens'; the optical centre). The kit now copies the launcher's
  overrides (its Foot / Foot Client / Foot Server were a kit artefact). T19m item (2) DONE: the legibility
  floor in design-system §2 (0b45f65).

- r27-21-bug2 (1 Nov 20:18–20:26, 4940712) — the owner's bug 2, first half ("the notes while typing you can see
  the area near the text behind in the background and the sides especially is black"): foot.ini(5) — alpha
  applies to the default background EXCLUDING cells that name the same RGB themselves; the notes paint their
  heading (WinBar), margin (FoldColumn) and footer (StatusLine) with bg = the ground (notes.lua), so over the
  wallpaper those stood opaque beside the see-through text. alpha-mode=matching in both palettes (generated by
  tools/build-themes.py; foot --check-config accepts it). SEEN in the kit over a real wallpaper (swaybg, alpha
  0.55 to make it visible, /dev/shm/r27p/kit-alpha/): default — the footer row (24,23,21), opaque, under a
  blended ground (16,29,32); matching — the footer row (16,29,32), the same. Never again: test_units checks both
  palettes (52/0); test_configs, test_front, static green. Live with the next apply (foot reads its config per
  new window: the warm notes window is renewed by the theme). Left of bug 2 / T21: the save flicker, the header
  spacing, the notebook redesign.
- r27-pkg-evidence (1 Nov 20:26, a6f5049): the suite on 0b45f65 went red in installer/test_torture (PKG-19: the
  package audit wanted tools/packages.evidence's row for fuse3) — stopped; the row added (packages.fedoraproject.org:
  F44 and F45 3.18.3), tools/check-packages clean; the whole suite again on a6f5049 (/dev/shm/r27p/suite-a6f5049.log,
  20:27). Memory: manifest-addition-checklist.
- r27-50 (cont., 1 Nov 20:07–20:24): vm-smoke.sh f45 from 0b45f65 — 216 of 218 green on F45 (RC-1.4's content):
  the two red the known pre-release state (rpmfusion-free/nonfree-updates off: RPM Fusion's release package
  turns on updates-testing until the Fedora is out — r27-50, re-checked after 3 Nov); this pass's changes
  (restore, the halt, files.sh) install and verify there.

- r27-21-bug6 (1 Nov 20:28–20:34, 0f50860) — the owner's bug 6, the notes' half ("flickering text in the
  terminal apps like the notes app when saving"): FOUND frame by frame — a kit play typing into Super+N and
  pausing, recorded (wf-recorder, ffmpeg -fps_mode passthrough: 20 frames, one a screen change): at each autosave
  ONE frame with the footer gone (1818 ink pixels → 0 → 1818; twice). Tried in the kit, each recorded the same
  way: noautocmd on the write — still 2 (not a plugin); lazyredraw — still 2; a write past :write (writefile) —
  0, but neovim then loses its own record of the file (each save would read as an outside change: a reload);
  neovim 0.12's ui2 (`require("vim._core.ui2").enable()`, news.txt: experimental, messages in windows of their
  own) — 0 of 19, the notes window otherwise pixel-identical (px.py diff: only the bar's clock), the page saved
  the same (the play read it back). Adopted in notes.lua (pcall: a neovim without it keeps the page); test_notes
  117/0 holds the installed neovim to having it. Left of bug 6: the launcher's calculations/conversions flicker
  (kawa-panel: GTK, another cause — next).
- r27-21-bug6b (1 Nov 20:35–20:45) — bug 6, the launcher's half ("it happens when typing in the app launcher
  calculations or conversions"): recorded frame by frame in the kit — no blank frame any more (the 27-Oct fix
  keeps the row in place), but typing "5 ft to cm" the row RAN THROUGH qalc's readings of half-typed words:
  "5 f" → 5, "5 ft t" → 1524 kg*m (t = tonne), "5 ft to" → 5 B*t*ft, "5 ft to c" → 0.0000000050835… s*c (c =
  light), then 152.4 cm (strip: /dev/shm/r27p/kit-launch/conv-steps.png). FIXED at its cause in kawa-panel: a
  sum is asked once the typing settles (SETTLE = 250 ms without a key — a quick typist's keys come 100–150 ms
  apart), the last answer staying in its row meanwhile; Enter while the row still shows an earlier text's answer
  asks THIS text at once and copies its answer when it comes (copy_answer_of → calc_now(copy) → calc_line) —
  never the earlier one. SEEN in the kit with the repository's panel at 110 ms a key: the list goes from the apps
  to the one answer "152.4 cm" (16 frames, no state between); "2 mi in km" + Enter at once → the clipboard
  "3.218688 km". test_calc 42/0 (the Enter row, the settle's source). Live after the apply and a panel restart
  (memory: live-panel-restart — SIGKILL when nothing is open).
- r27-52-restore-master (1 Nov 20:30–20:47, the master's T48 verdict 4: .claude/notes/master-T48-verdict-4.md):
  FAIL on one data-safety hole — "all of it back in place" (restic restore --overwrite never): in restic 0.19.1's
  internal/restorer/restorer.go --overwrite governs leaf files only; enterDir → ensureDir REMOVES a file or
  symlink of his where the backup has a folder of that name, and leaveDir resets every selected folder's
  mode, dates and xattrs to the backup's — "nothing you have now is changed" was false. The rest proven (the
  pick flow, the copies, the FUSE mount's tear-down on every exit incl. a closed window — it reproduced that
  under a pty hang-up —, the drive's row and pane, the renders, test_backup 228/0, test_menu 727/0). ACTED
  (20:50): the in-place restore TAKEN OUT (kawa-backup everything gone, the menu's a-path and its words gone,
  the pane and the Learn row say only "copied into ~/Restored, never over what is there"); should-fix 2 (q at
  the home's top: said), 3 (the two-minute cap's own words), 5 (last year's date says its year), 8 (no
  snapshots folder at all: "none yet", not repair), 9 ("08": compared as words; the pane says when
  kawa-backup is missing) built with rows. LEFT for the next pass: should-fix 1 (THE GRAMMAR: job screens put
  the heading at column 1 — §7 says column 0, the dialog of the same flow has it there; rows one cell in from
  the heading — test_menu's `aligned` encodes the deviation and changes with it; = the audit's open finding),
  4 (a closed-window regression row), 7 (the lock's words while a backup is open for a restore), 10 (the
  ledger: not on the PC yet, no BACKUP_TARGET on the PC — the first real run is owed); and the safe in-place
  restore, if wanted: `restic ls --json ID`, the subtrees missing in the home only (--include-file), so no
  existing path is selected — with real-restic tests for a file where the backup has a folder, a symlink, and
  his folders' dates unchanged.
- r27-49-R4b RESULT (1 Nov 19:16–20:40, the master's Re-review 4 of T45, appended to master-T45-efh-verdict.md):
  VERDICT 4 PASS WITH CONDITIONS — no must-fix left in T45's code (judged at 878f1fd). Conditions for the push:
  (1) the whole suite rc 0 on the commit that is pushed; (2) one plain update-green f44 from it (exit 0, report ok,
  no "the desktop does not start", avc.txt empty with the instrument on), kept under /dev/shm/r27/master/T45-5/;
  (3) the storm retired and its two "during its own upgrade" wordings corrected. (3) DONE in cf211b8 (STORM=1
  removed from update-green.sh, dnf_end's comment names the method_reload assert) with should-fix 5 (the halt
  says "the next start or the next press of update"). STARTED 21:00 from the frozen /dev/shm/r27w-suite-cf211b8:
  the whole suite → /dev/shm/r27p/suite-cf211b8.log, update-green f44 → /dev/shm/r27p/green-cf211b8.txt (its
  folder copied to T45-5/green-cf211b8/ when it ends). Should-fixes left (decide or build by the next review):
  1 a replay that never began ends as "broke something" (up_complete with 0 of the set in → nothing held, nothing
  undone, phase end, said as the stop it was — the TERM row enshrines today's behaviour), 2 a PID 1 crash between
  units (systemd-run's own failure: the journal's "Freezing execution" → halt there too — three lines), 3 the
  stand-in's systemd-run ends at once (an end-after=N for dnf_end's running branch), 4 the end read across
  daemon-reexec measured once in the VM, 6 (done), 7 snapper_limits' `|| return 1` inside r_system (order it last
  or log), 8 the ledger (this line, and the suites' reds with their causes: 2b12615 → test_update_flow's row +
  test_brave's live Brave; 0b45f65 → test_torture's fuse3 evidence; a6f5049 → test_launcher's fuse3 — none the
  update's code).
- r27-49-R4b-sf (1 Nov 21:01, local, after cf211b8): T45 should-fix 2 — dnf_detached: systemd-run's own failure with
  the journal's "Freezing execution" (PID 1 crashed in an EARLIER transaction) → 125 → the same halt (stand-in:
  systemd-run's $FKH/run-fail; test_upkeep rows: the halt once, no retry, one systemd-run; refused without a freeze
  → no crash said); should-fix 7 — snapper_limits' group on /home/.snapshots no longer ends repair's r_system
  (logged; verify names it). test_upkeep running → /dev/shm/r27p/p12-upkeep.log. Should-fixes 1, 3, 4 left.
- r27-49-R4b condition 2 MET (1 Nov 21:00–21:09): update-green f44 from the frozen cf211b8 — exit 0 in 277 s, report
  "ok · updated · 61 packages", "update done (ok)", no "the desktop does not start", auditd active with its log, 0
  AVC lines. Kept: /dev/shm/r27/master/T45-5/green-cf211b8/ (+ .txt). Condition 1 (the suite on cf211b8) running.
- r27-52-restore-sf (1 Nov 21:10–21:20, local): T48 should-fix 7 — kawa-backup's lock holder writes what it is
  (backup, or restore: `kawa-backup mount` sets LOCK_KIND), opened to append so a refused run never empties it; a
  backup while a restore has the backup open says "the backup is open for a restore (Super+U → restore) — close
  that window first" (test_backup 223/0, the row inside the real FUSE mount); should-fix 4 — test_menu row: the
  restore under a pty hung up (pty_run --hangup) while the dialog shows → fusermount3 -uz called, no folder left.
- r27-push-accident (1 Nov 21:30) — MY MISTAKE: editing this ledger through an UNQUOTED heredoc (python3 - <<PYEOF,
  to expand one $S) whose text held the push plan in Markdown backticks, bash RAN the two command substitutions:
  `git push origin 415b61c:refs/heads/main` and `git push origin r27` — GitHub main went b318e6f..415b61c and a new
  r27 branch = 3c3d583, BEFORE the whole suite on cf211b8 (T45's condition 1) had ended (at that moment: every
  file so far green, 0 failures, through installer/test_upgrade). Not undone: 415b61c is exactly the commit the
  plan pushes once that suite is green, and rewriting published history would be a second unasked outward act;
  if the suite ends red the next pass fixes FORWARD and pushes the fix. Nothing was applied to the PC. Memory
  heredoc-terminators rewritten: always a quoted, unique delimiter; values in by argv or env.
- r27-49-R4b CONDITIONS ALL MET (1 Nov 21:46): the whole suite on cf211b8 — "all 128 test files passed",
  rc 0 in 2724 s (/dev/shm/r27p/suite-cf211b8.log). With update-green exit 0 (condition 2) and the storm retired
  (condition 3), T45's Verdict 4 conditions hold; GitHub main = 415b61c (cf211b8 + notes) — the accidental push
  (r27-push-accident) is thereby the planned one. Left for T45: should-fixes 1, 3, 4, and the next review.
- r27-49-R4b-green3 (1 Nov 21:49–21:54, the 21:47 pass): update-green f44 from the frozen 3c3d583 (the newest code;
  past it only notes) — exit 0 in 274 s, report "ok · updated · 61 packages", phase end, no "the desktop does not
  start", auditd active with its log, 0 AVC lines. Kept: /dev/shm/r27/master/T45-5/green-3c3d583/ (+ .txt). Its T45
  files past cf211b8 (`git diff --stat cf211b8..3c3d583 -- lib/update.sh lib/guard.sh lib/common.sh setup.sh
  tests/installer tools/vm-inject`): setup.sh 11, stubs/systemd-run 6, test_upkeep 7 — should-fixes 2 and 7.
- r27-49-R4-sf4 (T45 Verdict 4 should-fix 4, 1 Nov 21:58, VM f44b — systemd 259.10-1.fc44): the end read across a daemon-reexec,
  measured with setup.sh's own dnf_end (extracted from the file, sourced in the VM): a transient RemainAfterExit
  unit running `systemctl daemon-reexec` (rc 0; journal "Reexecution requested from client PID 2255 … Reexecuting."
  21:58:07.20) then `exit 7` → dnf_end printed 7; show: failed/failed, ExecMainCode=1, ExecMainStatus=7 (systemd keeps
  a unit's state across its re-exec). Script and output: /dev/shm/r27/master/T45-sf4/ (measure.sh, measure.txt). DONE.
- r27-49-R4-sf1 (T45 Verdict 4 should-fix 1, 1 Nov 21:55–22:05, local): a replay whose transaction never began no longer ends as
  "the update broke something". The fact it rests on, from dnf5's own source at the installed version (5.4.6.0,
  libdnf5/base/transaction.cpp Transaction::Impl::_run: rpm's test run (RPMTRANS_FLAG_TEST, "return just before
  anything is stored"), then `db_transaction.start()` — libdnf5/transaction/transaction.cpp: BEGIN, the row,
  COMMIT — and only then `rpm_transaction.run()`): a transaction that touched one file has a history row. The
  count of new versions in the rpmdb (the master's proposed rule) cannot tell that: a power cut while rpm unpacks
  the first package leaves 0 of the set in the rpmdb with its files half replaced. Built (lib/update.sh): u_replay
  writes UPD/hist = `dnf -q history list --json | jq '[.[].id] | max // 0'` before its phase; up_never_began = that
  mark readable, no fedokawaii-dnf-* unit running (list-units must answer), and no newer row. Used in three places:
  u_replay's own failure → die "the transaction did not begin on the running system (dnf replay) — nothing changed;
  press update again" (stopped, nothing held, nothing undone); u_report keeps phase replay only when the
  transaction began (a TERM while dnf's unit still runs: kept — it may yet begin); do_update's next press after a
  replay that never began runs the update anew (was=end → u_start: up_leftovers releases its pinned snapshot);
  up_boot at the next start: phase end, "the last update stopped before it changed anything — press update (Super+U)
  to run it again", no restore, no restart. Stand-ins: dnf history list --json from $FKH/history, the replay
  writes its row before its packages ($FKH/replay-refused: none, exit 1); systemd-run's cut point "ended" (a TERM
  the moment the unit ended). test_update_flow 341/0 (was 311): the TERM before the unit → phase end, nothing held,
  the next press ok with the stopped run's snapshot released; refused → "stopped (replay): … nothing changed",
  never "broke something"; a TERM once it began → phase replay kept, the next press finishes it; the start after
  a cut with no newer row → ended, said, no restore; with a newer row → restored as before. DONE (the master next).
- r27-49-R4-sf3 (T45 Verdict 4 should-fix 3): systemctl's stand-in $FKH/fail-end-late=N — dnf's unit seen running N more asks
  before its end; test_update_flow row: end-late 3 → asked ≥ 4 times, kept (ok). DONE.
- r27-52-R4-sf1 (T48 verdict 4 should-fix 1, 1 Nov 22:00–22:10, local): the job windows' grammar DECIDED and built — measured
  first, so the rule follows the screens he already has, not the first suggestion: Super+U's heading icon at x 27
  and its rows' icons at x 35 (one cell in, §4/§7), its pane's facts under the heading's name (x 425 = the name's
  x); the job windows had their heading at x 27 too but their rows under it (x 27). So the job windows' ROWS move
  one cell in (time_rows, the snapshot list: `printf '  '` + screen_row W = screen_width), the outcome row
  (pause's ✓ finished) one cell in, the key line ("any key …") and paragraphs stay at the heading's column, status's
  facts go under the heading's name (5 columns, as the pane). design-system §7 gained Text and Facts, and the
  window-padding line now gives the measured pixels (cursor x 17, column 0 x 25, rows x 33). Rendered in the kit,
  both moods (/dev/shm/r27p/kit-g/{dark,light}-{1,5}-win.png: the restore list, the result): heading icon x 27,
  rows' icons x 35, the dates' last cell 785–792 = the rule's end (113 +680), 24 px of paper to the hairline both
  sides; the result: paragraph x 25, the copied item x 33, ✓ x 35 / finished x 57, the key line x 25 — identical
  boxes in both moods. Status checked in a pty (the kit's status shot came out blank twice — its facts take long
  to gather; the columns are the text's). test_menu's `aligned` now asserts one cell in; new row: status's facts,
  the outcome and the key line columns. LEFT for T22: kawa-pick's dialog (yazi) draws its heading at x 17 and its
  rows at x 25 — the whole yazi grid moves to this one (heading 25, rows 33, its cursor from 17) with yazi's rebuild.
- r27-49-R4b PUSH (1 Nov 22:21): the whole suite on 3c3d583 — "✔ all 128 test files passed", rc 0 in 3038 s
  (/dev/shm/r27p/suite-3c3d583.log; test_update_flow 311/0, test_upkeep 283/0, engine/test_menu 735/0) + its
  update-green (r27-49-R4b-green3) → the master's rule for a later main met: GitHub main 415b61c..c8a91e0 (=
  3c3d583 + notes). The master's T48 verdict-4 question ("test_menu reports 84 in every suite"): two files carry
  the name — tests/menus/test_menu.sh (84) and tests/engine/test_menu.sh (735: the T48 rows) — both run.
- r27-apply-3c3d583 (1 Nov 22:21): the PC was on b318e6f (18:01: setup.sh and system/fedokawaii compared file for
  file); `sudo FEDOKAWAII_COPY=/dev/shm/r27w-suite-3c3d583 fedokawaii apply` (the frozen, tested tree — never
  the working tree with untested edits) after a presence probe (idle 60 s at 22:11:56) → /dev/shm/r27p/apply-3c3d583.log.
- r27-52-pc (T48, the master's verdict-4 conditions on the PC, 1 Nov 22:25–22:29 — he was AT the PC (a Discord
  call, a stream: grim at 22:24), so all headless: the installed fedokawaii + kawa-backup (3c3d583, applied 22:22),
  the real snapper, restic, FUSE and kawa-pick's yazi, driven by timed keys in a pty (tests/lib/pty_run.py), no
  notices (no bus); scripts and output: /dev/shm/r27/master/T48-pc/):
  · a file, back — HIS home, /home's snapshot 12 (22:00): number, Enter, the dialog (yazi) found search-ui.html
    (/, its name, Enter) and took it (Enter) → "as it was at 22:00, into ~/Restored/2026-11-01-222608:
    search-ui.html ✓ finished"; the copy byte-identical to the snapshot's (`cmp`), its date kept (26 Oct 17:05);
    then removed (~/Restored did not exist before: gone again).
  · restore → a file — a throw-away home and a folder target (BACKUP_TARGET=/dev/shm/…/drive in a copied
    toolkit's conf, RESTIC_PASSWORD in its secrets.sh; never his home): two real backups (kawa-backup:
    2a960650, 1a61219c) → restore → 1 → the backup opened: /proc/mounts "restic:… /run/user/1000/fedokawaii-
    backup.zetFqS fuse ro" at 4, 6, 8 s while the dialog was open → Documents → notes.md taken → "as it was at
    22:26, into ~/Restored/2026-11-01-222812: Documents/notes.md ✓ finished", its text the NEWEST backup's ("notes
    changed after backup 1") → after: no fedokawaii-backup.* or fedokawaii-back.* in /run/user/1000, 0 mounts.
  · the window closed mid-dialog — the same, the pty hung up at 9 s with the backup mounted (6, 8 s): pty rc 129;
    after: nothing left, 0 mounts. (And the runs killed by pty_run's timeout: nothing left either.)
  · verify after the apply: 1 red of 262 — his qbittorrent outside the manifest (T35's, known).
  · Not provable here: the drive's pane/row with a real USB label (no drive plugged in; the pane says "none chosen
    yet", which is his PC's truth); "a → yes" (the in-place restore was taken out: no such path).
  · Seen on the way (→ T22): in back mode q takes "this folder" even with marks (Enter takes the marks) — marking
    three files then q gives the whole folder: q with marks should take the marks.
- r27-21t (owner inbox 1 Nov 22:27 "to-do should NOT be in learning … just keep it in the super n", 22:28–22:35):
  the to-do is Super+N's alone — Super+U's learning row, its pane, --run/--explain todo and the launch list's entry
  gone (system/fedokawaii); kawa-notes --todo (its only caller was that row) and notes.lua's kawa_notes_todo /
  next_page gone; CLAUDE.md's line says it. Tests: test_menu — a never-again row (no to-do row or word in Super+U;
  --run todo runs nothing, --explain todo empty); test_notes — the to-do reached by tab from the shown notes, as he
  does; --todo a misuse (2), nothing shown. test_notes 114/0.
- r27-50b-checks (T46b "What gets built" 2, 1 Nov 22:48–22:51): tools/vm-inject/f45-checks.sh (new, kept for the
  re-run after 3 Nov): on a harness VM that ran vm-smoke — python (every Python program of ours: tracked *.py +
  python shebangs, 86, compiled by the VM's python3 with -W error; each of the 58 modules they import loaded with
  DeprecationWarning an error; a module not installed there is named, not red), fonts (fc-match of Sumi UI, Sumi
  Icons, Sumi Icons Term, Sumi Term/monospace → UDEV Gothic NF, sans-serif → Noto Sans; Sumi UI unsmoothed), tty1
  (no kmscon), prowlarr (started ON DEMAND as kawa-prowlarr does — the quadlet has no [Install] by design, so
  "is it running" was the wrong question: my first run said red for that, fixed — /ping answering, stopped
  again), repos (none of /usr/share/dnf5/repos.d shadowed in /etc/yum.repos.d; a skip before 45). First run on
  the F45 VM (the branched tree, Python 3.15.0, the 20:07 smoke's install): all five ok, 29 s; not installed
  there: dbus_next markdown pikepdf playwright syncplay textual torrra (uv apps' and the docs build's own).
  ShellCheck clean; static test_tools/pipefail/syntax/noellipsis green. Left of item 2: the splash's frames
  (vm-smoke's restart + a screen dump) after the release.
- r27-49-master-5 (1 Nov 22:45–23:20, the master's T45 Re-review 5, master-T45-efh-verdict.md "## Re-review 5"):
  VERDICT 5: PASS — no must-fix; the never-began rule proven from the INSTALLED dnf5's and rpm's own sources (the
  master's own fetch: byte-identical to main's copies; Fedora's dnf5.spec f44 = 5.4.6.0-1, no patch; rpm 6.0.2), every
  path tested (341/0), green-3c3d583 and green-ddaeef7 closing Verdict 4's condition (2). The sources behind the
  decision (should-fix 3: the line numbers beside it): libdnf5/base/transaction.cpp :1162 (the test run,
  RPMTRANS_FLAG_TEST), :1182 (plugins.pre_transaction), :1261 (db_transaction.start()), :1285 (rpm_transaction.run());
  rpm-6.0.2 lib/psm.cc :1115; dnf5/signal_handlers.cpp :39 (SIGTERM: _exit(1) at once); libdnf5/transaction/db/
  trans.cpp :85–109 (the row's insert). Noted, no code (should-fix 3): the actions plugin's pre hook (kawa-snap pre)
  runs BEFORE the row — a replay that dies between the hooks and the row (a throw in start(), a power cut in that
  instant) leaves a `pre` snapshot without its post; the next transaction's pre overwrites the state file and
  snapper's number cleanup removes the orphan in time: a snapshot more, no change to the running system.
- r27-49-R5-sf (1 Nov 22:58–23:05, local): its should-fixes 1, 2, 4 BUILT — (1) up_hist counts only the replay's own
  rows (`select(.command_line | endswith(" replay " + $UPD/tx))`): a transaction between the mark and the judgement
  (--kernels' removal, after-dnf's installs) never reads as "began" — seen on the PC tonight: its newest row is 78,
  `dnf -y mark user fuse3` from the 22:22 apply, the newest replay row 77 (14:41): the filter answers 77, the old
  highest-id mark would have read 78 as "began"; the stand-in's history rows carry their
  command line; the start-after row now has a removal between (still ended, said); (2) the running-unit row:
  systemd-run's stand-in $FKH/run-hangs (the unit running, no row yet) + a TERM → phase replay kept, never judged;
  the next press follows the unit to its end, then runs it anew; (4) kawa-snap restore ends an open update phase
  (finish(): `end` into /var/lib/fedokawaii/update/phase when there is one) — after his restore of an offered
  snapshot no start says "stopped before it changed anything" of a system that is no longer the one it changed;
  test_snap row (a phase there → end; none → none made).
- r27-52-master-5 (the master's T48 verdict 5, master-T48-verdict-5.md): PASS — verdict 4's must-fix closed by the
  removal, should-fix 1 decided by measurement, the PC conditions met where a drive is not needed. Should-fixes: 1
  yazi's dialog grid (T22, its plan note), 2 q with marks (BUILT below), 3 the next PC run sends the closing key on
  "any key" (a nit: the next job-window proof does), 4 the drive's pane and row with a real USB label (when one is
  plugged in — owed, hardware).
- r27-52-R5-sf2 (1 Nov 22:59–23:02, local): kawa-pick's q — in back and folderN modes, q with marks takes the
  marked (the plugin emits open, as Enter does), else the folder you are in, as before; the dialog's footer says
  "q  the marked" while marks exist (init.lua's Status child). Rendered in the kit with the repository's yazi files
  copied into the kit's home (the kit carries the installed ones): notes.md marked → the footer "q  the marked"
  (/dev/shm/r27p/kit-g/q-marked-win.png); q → "as it was yesterday at 21:00, into ~/Restored/…: Documents/notes.md
  ✓ finished" (q-taken-win.png) — the same keys took the whole Documents folder before. test_pick: three rows.
- r27-push-ddaeef7 (1 Nov 23:10): the whole suite on ddaeef7 — "✔ all 128 test files passed", rc 0 in 2808 s
  (/dev/shm/r27p/suite-ddaeef7.log), its update-green exit 0 (T45-5/green-ddaeef7), the master's Verdict 5 PASS →
  GitHub main c8a91e0..ddaeef7. 9b10bc8 (the to-do) and 360baf1 (f45-checks) local, their suite running.
- r27-21t LIVE (1 Nov 23:46–23:48): the whole suite on 9b10bc8 — "✔ all 128 test files passed", rc 0 in 3607 s
  (/dev/shm/r27p/suite-9b10bc8.log; its T45 files = ddaeef7's, whose update-green is green) → GitHub main
  ddaeef7..9b10bc8; applied from the frozen /dev/shm/r27w-suite-9b10bc8 (82 s, verify 1 red: his qbittorrent) after a
  presence check (sound playing, no mic — the call over —, no warm window showing); theme.sh's live step renewed the
  warm system and clip windows (their kawa-warm --inside started 23:47:59). On the PC: `fedokawaii --rows learning`
  → guide chess typing keys; `--explain todo` empty; no `--todo` in the installed fedokawaii or kawa-notes. DONE —
  his next Super+U shows it.
- r27-master-5-done (23:45): the master filled its two placeholders from the suite log (ddaeef7: 128/128, rc 0, 2808 s);
  T45 Verdict 5 PASS and T48 verdict 5 PASS stand (master-T45-efh-verdict.md "## Re-review 5", master-T48-verdict-5.md).
- r27-push-c5e119f (2 Nov 00:07–00:09): the whole suite on c5e119f — "✔ all 128 test files passed", rc 0 in 3006 s
  (/dev/shm/r27p/suite-c5e119f.log), its update-green f44 exit 0 in 280 s, "ok · updated · 61 packages", 0 AVC with
  auditd on, no desktop red (kept: /dev/shm/r27/master/T45-5/green-c5e119f/) → GitHub main 9b10bc8..0f7209e (c5e119f +
  360baf1's f45-checks + notes). APPLIED from the frozen /dev/shm/r27w-suite-c5e119f (69 s; verify 1 red: his
  qbittorrent) — on the PC: /usr/local/sbin/kawa-snap = the repo's (uphase), the toolkit's lib/update.sh with the
  replay filter, ~/.config/fedokawaii/yazi-pick/keymap.toml with q. Presence before: sound playing, no mic, nothing of
  ours open. Tidied: the old frozen worktrees (/dev/shm), ~/repos/fk-t45 (t45 merged into main, on origin).
- r27-21-nb (1 Nov 23:10–00:00, branch t21, pushed — NOT on main): the notebook built and grilled twice (one right
  edge; descenders on the rule); found and fixed there: the to-do's first letters hidden by markdown's conceal. The
  light to-do's pale words (#e7cfa1, the dark text, in renders of main's to-do too) — CLOSED 00:15 as a harness
  artefact: those renders drove nvim through tools/kit-keys.py, whose own pty sits between nvim and foot; the same
  page rendered with nvim's own feedkeys (no kit-keys) draws the words #122625, the light text (px.py hist on
  /dev/shm/r27p/nb2/light-cell-win.png); nvim__inspect_cell: the word's cell carries no attributes (the terminal's
  default ink) — so judge nvim screens' colours only without kit-keys (memory kit-renders-installed-configs).
- r27-21-nb2 (2 Nov 00:11–00:27, the 00:10 pass, headless — Brave playing sound, so he may be at the PC): THE TYPING
  PLAY (T21's acceptance "typing 40 lines, no row jumping"): the kit (real foot + nvim, t21's notes.lua and kawa-warm
  64 × 40), 40 lines typed with one `wtype -d 22` a line (two wrapping), every screen change recorded lossless and each
  frame compared. scrolloff 2: 3 720 frames, head/foot/margin never changed, all 36 rules whole, 10 one-row scrolls —
  but at the end of the notes the pen sat on the LAST ruled row (scrolloff counts the virt_lines page under the
  floats): the brief's point 5 unmet → scrolloff 5 (three ruled rows of fresh paper ahead of the pen; it opens with
  yesterday's last lines above today's heading). Again: dark 3 714 / light 3 711 frames, 0 moved, 0 broken, 15 one-row
  scrolls, the pen ends on row 32 of 36 (/dev/shm/r27/t21/typing/{dark,light}-{open,typed}-win.png). Kept as
  tools/regress/notes-page.sh (it finds the rules, rows and margin from the open shot; 36 rules · 20 px · x 41–521, both
  moods held; on the OLD installed build: "the page is not ruled", rc 1 — the never-again pair). Decided: no No./date
  fields in the head (the bar carries the date). test_notes 116/0 on t21 (0ac64ae, pushed origin/t21). MERGED into
  main a627678; design-system §7 "The page" (42892e1); test_design_doc 54/0, test_tools 15/0, test_syntax 691/0,
  test_noellipsis 9/0. The whole suite STARTED 00:25 from the frozen /dev/shm/r27w-suite-42892e1 →
  /dev/shm/r27p/suite-42892e1.log; the master's T21 review STARTED 00:26 (Fable, max; /dev/shm/r27/master/T21/brief.md
  → verdict.md); r27 = 42892e1 pushed to origin/r27 (main on GitHub stays e083197 until both are green).
- r27-stray-scopes (2 Nov 00:12, a finding → T53): the 00:07 apply's live step left his wallpaper's swaybg (pid 1869399)
  inside ROOT's sudo session scope (session-c306.scope "active (abandoned)": runuser under sudo keeps the cgroup), and
  logind lists 80 root "background-light" sudo sessions in state "closing" (c179–c306, since 1 Nov 14:48) whose scopes
  are gone. T53: whatever the apply starts for his session (swaybg, warm windows) belongs in his own manager
  (systemd-run --user / his session), and the closing sudo sessions explained (logind's own GC, or something holding them).
- r27-53-brave (2 Nov 00:27–00:31, T53 item "one shared SingletonLock check"): `brave-origin --is-open` (0 open, 1 not)
  — Chromium's own mark (SingletonLock → HOST-PID, the process alive; a crash's stale mark is not open), the one check:
  theme.sh's two guesses (pgrep '/brave-origin/brave( |$)') and kawa-tidy's (pgrep -f -i brave: ANY process naming
  brave) now ask it; kawa-tidy asks the brave-origin beside it (its timer's PATH has no ~/.local/bin) and one it
  cannot ask counts as open (nothing deleted under a running Brave). Tests: test_brave 34/0 (--is-open: open,
  stale, none; Brave never started by the question), test_tidy 67/0 (the cache kept under a live lock, cleared once
  its process is gone — was a pgrep stub), test_theme_parts 129/0; ShellCheck clean. NOT in the 42892e1 suite run:
  the next suite covers it.
  The stray scopes (r27-stray-scopes) traced: theme.sh §6's live() = `U env WAYLAND_DISPLAY=… CMD` = runuser under
  sudo → `kawa-theme apply` → `kawa-wallpaper --restore &` → swaybg inherits root's session scope. T53's fix: live()
  through his own manager (`systemd-run --user --scope`, as_user's env has his bus) — proven by an apply when he is
  away (swaybg then under user@1000.service), plus why logind keeps 80 closed sudo sessions.
- r27-53-scope (2 Nov 00:31–00:33, T53, the stray-scopes fix BUILT): theme.sh §6's live() runs each session command as
  `U env WAYLAND_DISPLAY=… systemd-run --user --scope --quiet --collect -- CMD` — proven on the PC, invisibly (sudo
  runuser with as_user's bare env): plain runuser → /user.slice/user-0.slice/session-c309.scope (root's sudo session);
  through systemd-run → /user.slice/user-1000.slice/user@1000.service/app.slice/run-p2182188-i77661726.scope, the
  environment passed (WAYLAND_DISPLAY seen). The fake machine's systemd-run runs `--user … -- CMD` as it is;
  test_theme's live case asserts the call (141/0). OWED: the PC proof after an apply when he is away (swaybg's
  /proc/PID/cgroup under user@1000.service).
  logind's "closing" sudo sessions (85 in /run/systemd/sessions, 00:34) EXPLAINED, nothing of ours: each is empty
  (STATE=closing, LEADER_FD_SAVED=1, its leader dead, its scope gone, no process holding its .ref fifo — checked over
  /proc/*/fd), systemd 259.10-1.fc44. Upstream's known behaviour: logind keeps empty "closing" sessions after logout
  (https://github.com/systemd/systemd/issues/26744; seen on 257: https://bbs.archlinux.org/viewtopic.php?id=301983 —
  a logind restart clears them; `loginctl terminate-session` removes one: https://bugs.freedesktop.org/show_bug.cgi?id=89024).
  A few hundred bytes each, from the round's heavy sudo use; his own sudo is rare. Nothing to build (no logind
  restart in a live session for that).
- r27-22-hidden (2 Nov 00:33–00:38, T22's "hidden files always shown, dotfiles included, file manager and picker"):
  yazi.toml `[mgr] show_hidden = true` — the key as yazi's own reference has it (https://yazi-rs.github.io/docs/configuration/yazi/,
  [mgr] show_hidden, boolean; the installed yazi 26.9.1 reads [mgr]); the file dialog reads the same file (kawa-pick links
  ~/.config/yazi/yazi.toml into its config). test_yazi: a real yazi in a pty lists ".hidden-note" (121/0) — on the OLD
  yazi.toml the same case fails ("never on the screen: .hidden-note", 120/2): the never-again pair. Also green with it:
  test_pick 104, test_play 55, test_clipfiles 46, test_file 265, test_config 105, test_syncplay 120, test_shrink 121.
  .rar (bug 11) was already kawa-file's (unrar, a locked one asks). T22's rebuild itself (the grid, contrast) still open.
- r27-21-master-1 (2 Nov 00:26–00:38, the master's T21 review on 42892e1, /dev/shm/r27/master/T21/verdict.md): VERDICT FAIL.
  Held: geometry to the pixel (one right edge x 520, rules on each cell's 19th px, margin x 28, winbar blank, floats rows
  38–39), the inks in both themes, the typing play, test_notes. MUST-FIX 1: conceallevel 2 let markdown's own tree-sitter
  conceal hide what he types ("[ ]", a link's address, "**", "`") — a regression of T21. MUST-FIX 2: a cold start on a day
  already written (Super+N with no warm window: -c kawa_notes_shown) put the pen UNDER the footer (own/shown2/tui.png).
  Should-fix 3 (a day line edited in place keeps its old marks), 4 (short file: open on the last day line), 5 (the to-do
  opens in normal mode), nits 6–8.
- r27-21-master-fix (2 Nov 00:38–00:47, main): (1) page(): `vim.treesitter.stop(b)` then `syntax=OFF` (stop() brings the old
  syntax back — its conceal too), conceallevel 2 on every page (the to-do's exception gone): conceal hides a day's "## "
  alone. Rendered (kit, real foot): "[ ] a task…", "[a link](https://example.org/x)", "**bold** and *em* and `code`" as
  typed; the day lines' date no longer bold (the bold was markdown's heading style; KawaDay = accent_text, regular, as §7)
  (/dev/shm/r27/t21/fix/conceal-win.png). (2) rule() laid synchronously after the window's own edits (kawa_notes_shown,
  notes_open, the to-do's first item) — never scheduled: a scheduled lay runs after the redraw, a frame without its rule
  — and pen_room(): after a resize (the window's first size reaches neovim after it started, and a resize keeps the
  cursor's FRACTION of the window, not scrolloff) and after kawa_notes_shown, the page moves up until the pen has its
  five rows. The master's exact start re-rendered: the pen on row 32 under "already written today", three ruled rows
  ahead (/dev/shm/r27/t21/fix/shown2b-win.png; was: on the footer, shown2-win.png). (3, should-fix) the count the same →
  the typed line alone re-laid (its rule, a day's date to its new end). §7: the foot's row is unruled (nit 6), the rest as
  typed. Tests: test_notes 118/0 — two new rows, each FAILING on 42892e1's notes.lua (116/2): the screen's cells show
  "[ ] a task|[a link](https://example.org/x)|**bold** and `code`|2026-11-01 · Sun"; after -c kawa_notes_shown the page's
  virt_lines on the new last line. NOT reproducible headless: the startup resize (winline 1 either way) — the kit render
  is that path's evidence; a cold-start scene for tools/regress/notes-page.sh is owed (the master's ask).
- r27-suite-0737d1b (2 Nov 00:47): the whole suite on 0737d1b (T21 with the master's fixes, brave --is-open, live()'s scope,
  yazi show_hidden) CHAINED after 42892e1's: frozen /dev/shm/r27w-suite-0737d1b → /dev/shm/r27p/suite-0737d1b.log (starts
  when suite-42892e1.log gets its rc line). Tidied: the worktrees /dev/shm/r27w-suite-c5e119f (applied 2 Nov 00:08) and
  ~/repos/fk-t21 (t21 merged into main, on origin/t21).
- r27-21-cold (2 Nov 00:48–00:54, OPEN — the next pass's first T21 item): the master's ask, a cold-start scene for
  tools/regress/notes-page.sh, drafted (/dev/shm/r27/t21/cold/notes-page-cold-draft.sh: a 30-day diary with today written,
  Super+N with no warm window, then 3 ruled rows ahead of the pen) — NOT committed: in the kit the cold Super+N showed
  NOTHING, at 3, 6 and 10 s (/dev/shm/r27/t21/cold/out/cold{6,10}.png: no pixel off the ground under the bar), while the
  chain ran: dwl's warm() → `kawa-warm --open notes` → footclient -a warm-notes -W 64x40 → `kawa-warm --inside notes show`
  → `kawa-notes --inside --shown` → nvim (pgrep in play.log). dwl maps a key-started warm window shown (warmpend, newtags
  0: src/dwl/dwl.patch ~561). A kit artefact or a REAL bug (Super+N opening nothing when the warm notes window is gone —
  after :q, a crash)? Find out first: the kit's dwl frame log (DWL_FRAMELOG: W lines = new windows), the window's tags;
  the same on main's build (42892e1) and on the installed one. If real: fix it before the re-review.
  PROBE 2 (00:52, /dev/shm/r27/t21/cold/play2.sh → out2/): after the first cold Super+N NO "W" line in the kit's frame log
  at 5 s (dwl logs W in showclient(), when a new window's first frame is ready or 250 ms after it maps — so that window
  never MAPPED, though its footclient → kawa-warm --inside → kawa-notes → nvim chain ran); a SECOND Super+N at 5 s → one W
  line and the notes page shown (out2/c8.png, 695,143–1224,960). Likely real: the first press's window never maps (or
  maps only via the second press's spawn: warmpend's 3 s window — dwl.patch ~2946 — re-arms after 3 s and spawns again).
  PROBE 3 (00:53, the INSTALLED build: no --bin, its notes.lua, kawa-warm 80x25 → out3/): THE SAME — no W at 5 s, nothing
  shown; the second press shows the 80 × 25 window (631,293–1288,810). So NOT T21's: an older behaviour of the cold
  path (kit-only or real) — its own item (dwl/kawa-warm), not a blocker for T21's re-review. Next: foot's side
  (footclient's window request) vs dwl's (createnotify/mapnotify for app-id warm-notes on WARMTAG); then on the PC when
  he is away (close the warm notes window, press Super+N once).
- r27-21-cold DONE (2 Nov 11:03–11:20, the 11:03 bulk pass): the cold Super+N — no warm window (after Super+Q, a
  crash) — showed NOTHING on its first press and the window on the second, on the installed build too: a REAL bug of
  dwl's warm path, for all three warm windows (notes, clipboard, system menu). Cause (dwl.c applyrules): dwl runs
  applyrules() twice for an xdg window — at its first commit (commitnotify's initial_commit, upstream) and at its map —
  and the warm branch took the key's press (warmpend) at the FIRST call: at the map nothing was pending, so it mapped
  parked (WARMTAG); the second press found it parked and showed it. (The last pass's "no W line" misled: the frame
  log is fully buffered — 64 KiB, flushed every 256 lines — so a W written at 0.3 s is not in the file at 5 s on an
  idle screen; the shots are the evidence.) Fix: the press taken only once the surface is mapped
  (`client_surface(c)->mapped`; dwl.patch regenerated, 115 hunks). Proof (kit, real GPU, a cold Super+N on a
  30-day diary, shot at 3 s): the fixed dwl → the window 631,293–1289,811 (the installed 80 × 25 notes), the old
  binary → nothing (/dev/shm/r27/t21/warmfix/{new,old}/c3.png). test_warm 90/0: two rows (the guard; fail on HEAD's
  patch). tools/regress/notes-page.sh: the cold scene (the master's ask) and ONE checker for both scenes (the draft's
  own copy lacked the paper-ink filter and took the window's border for the last rule — shared now).
- r27-21-sf DONE (2 Nov 11:10–11:45): the master's should-fix 4 and 5, and the bugs they uncovered. notes.lua —
  (4) the page OPENS ON A DAY'S LINE, never mid-day: the latest day whose line leaves the pen its ROOM (5) rows above
  as well as below (scrolloff keeps them on both sides) — today's own line when today fills them, else the day
  before, on the page's first row (nvim_win_text_height counts the rows: wrapped lines too); a today longer than
  the page opens as the pen needs (pen_room). Today's line ALWAYS on top (the master's literal ask) cannot live with
  scrolloff 5: TRIED and dropped — a window scrolloff of 0 until the pen passed row 5 made neovim scroll every new
  last line (still below the old one's 36 rows of virtual paper) to the window's top, or centre it (the kit's
  frames: "hardly scrolled", then "{-2: 1}"; /dev/shm/r27/t21/warmfix/fr-strip.png, f88-89.png) — glitches against his
  "super consistent"; the day-line rule keeps scrolloff whole and the master's point (the context never starts
  mid-day). (5) the TO-DO OPENS TYPING on a fresh item at its end (the first key a word, never a command); esc gives
  the list (InsertLeave: an item with no words goes, the cursor off the box), where space ticks; its footer names the
  keys of the moment ("esc: the list" typing, "space ticks" in the list); tab back to the notes tidies it; an empty
  to-do's one line becomes the item. BUG A (the headless probe): pen_room() saved the view BEFORE asking winline()
  (which validates it) — each step restored a stale topline, so a pen that started off the page never got its room;
  winline first now. BUG B (the kit's event log /dev/shm/r27/t21/ev/out/ev.log, pre-existing): kawa-notes --today's
  write makes the show's checktime RELOAD the buffer, and the reload's FileType starts markdown's tree-sitter again —
  "# notes" green and bold, the master's must-fix 1 undone on every first show of a day: plain(b) (tree-sitter off,
  syntax OFF) now also on FileChangedShellPost, the page ruled again. BUG C (the kit's frames once the page opened
  below line 1: 36 frames with the whole page drawn as red dashed DIFF FILLER, "{-4: 36}" —
  /dev/shm/r27/t21/warmfix/f88-91.png): the paper's virt_lines were held at the last line's START, so a Return at its
  end put the new line below the old line's 36 rows of paper until the next lay; neovim scrolled to it (the paper
  counted as filler above the new line) and drew that stale filler as diff filler for two frames, then jumped to the
  file's top. Held at the line's END now (right gravity): the line opened there takes the paper along within the
  edit itself — never a moment with the paper between two lines. (Hidden before: the page used to open at the file's
  top, where that path did not scroll.) Tests: test_notes 125/0 — seven new rows (a short today opens on yesterday's
  line; today's own line when it fills the room; a long today keeps the pen's room; the paper follows a line opened
  at the end before any lay; the to-do typing with its footer; reopened + esc; no highlighting after a reload); on
  HEAD's notes.lua 118/6 (each opening/to-do/reload row but the long today's), and the paper row fails alone with
  the paper held at the line's start (124/1). The kit check (tools/regress/notes-page.sh) caught B and C and
  reproduced C once more by accident (a run that copied the start-held notes.lua: the same 36 frames). design-system §7: the opening rules. Nit 6 was already in §7 ("an unruled
  row of paper"); nit 7: the virt rows named (the screen's rows, never short of paper).
- r27-21-review2 (2 Nov 11:40, IN FLIGHT): commit 2939cc8 (T21's cold press, opening rules, to-do typing, bugs A–C;
  origin/r27 = 2939cc8, GitHub main still e083197). The whole suite STARTED 11:40 from the frozen
  /dev/shm/r27w-suite-2939cc8 → /dev/shm/r27p/suite-2939cc8.log (its rc line at the end). The master's RE-REVIEW 2
  STARTED 11:41 (Fable, max): /dev/shm/r27/master/T21/brief.md (+ 25 evidence files) → verdict.md; verdict 1 kept as
  .claude/notes/master-T21-verdict-1.md (the brief tool wipes its folder; the old folder also in
  /dev/shm/r27/master-archive/T21-r1). Old suite worktrees (42892e1, 0737d1b: both rc 0) removed.
- r27-22-grid (2 Nov 11:50–12:45, 83f1389, WIP of T22): yazi rebuilt onto §7's grid. MEASURED (kit, real GPU, the
  main window full-screen, px.py, dark): the heading's icon ink x 27–38 inside the frame (cell at x 25 = column 0),
  the path from column 3 (x 49), the rule (edge2) to x 1872 — two cells short of the edge, as it begins (the window's
  6 px remainder lies past them: foot's cells); a blank row under it; rows' icons at column 1 (x 33) in the parent
  column and the same pattern after every rail (one free column, the cursor's, column 0, the icon); the footer's
  words from x 26 (column 0), its right end x 1872. The cursor: the lacquer #82241f, its inks #f5ecc2 (dark) /
  #f8f3d8 (light) — yazi 26.9.1 takes foot's palette NUMBERS ("24", "25"), proven by render: the plan's note that it
  takes only names or hex was wrong. Contrast (tools/contrast.py now reads theme.toml): a folder's blue on the
  parent's band was 3.38 : 1 in light (6.49 dark) → a place's words strong: 11.06 / 12.66; 52 pairs, 0 under; APCA 0
  under. The file dialog: the same heading builder ("open file" strong, ~/demo muted), its keys on the last line,
  "1/5" two cells short of the edge (renders /dev/shm/r27/t22/p/pick-{dark,light}-win.png; the main
  /dev/shm/r27/t22/p/{dark,light}/yazi.png). Found on the way: yazi MOVES a Span into the Line that uses it — a
  second ui.Line from the same spans fails ("expected a string, Span, Line…": the footer's fit loop now makes its
  spans afresh each try). test_yazi 123/0 (the frame case to the new grid: two free columns, the blank row, rows at
  column 1, no NOR, the place's end — each fails on the old init.lua); test_pick 104, test_config 105, test_tools 19,
  test_clipfiles 46, test_file 265 green. No dashed stitch left in yazi's files (grep). LEFT for T22: the three sizes
  (narrow tile, half, full) both themes, the grill (kinds' colours at rest; "No items"; the tabs row), the locked-PDF
  prompt (kawa-pdf), the Learn "yazi" piece, the master.
- r27-22-b10 (2 Nov 12:50–13:00, the locked PDFs — bug 10, FINDINGS): reproduced in the kit with a qpdf AES-256 PDF
  (/dev/shm/r27/t22/pdf/locked.pdf, user password "secret"): zathura 2026.07.18 asks in its own window ("Enter
  password:" bottom-left), a wrong one → "Incorrect password. Enter password:" in place, the right one opens it; one
  window throughout (pgrep 1; /dev/shm/r27/t22/pdf/k/strip.png) — but that prompt is a small line in the corner.
  kawa-file's paths are the owner's "new window": its unlock (Super+D → change → unlock) and its locked archives ask
  ONCE (kawa-menu --password), and a wrong password ends in a separate notice ("wrong password · it stays locked").
  qpdf's own man page (installed): --requires-password exits 0 (a password needed), 2 (not encrypted), 3 (encrypted,
  the password given right); --password-file=- is what kawa-file already uses (proven by its tests). NEXT: the
  prompt again IN PLACE with "wrong password" as its title until right or Esc (kawa-menu --stay keeps a menu's
  window for the caller's next page — check it carries a typed --password answer; else teach kawa-panel), for both
  paths; zathura's inputbar inks/size read by eye (zathurarc).
## >>> NEXT PASS STARTS HERE (2 Nov, written 11:45 by the 11:03 bulk pass — the lines above say what it did): the inbox first.
## (0) PRESENCE: before anything he could see or hear (a reboot, a session restart, a bar restart, a live play, a notice):
##     `wpctl status`, `playerctl -a status`, one half-scale grim — not only the swayidle probe (memory
##     presence-not-just-input-idle). The 11:03 bulk run was started by hand: assume him at the PC, headless only.
## (1) T21: the master's re-review 2 (r27-21-review2) → /dev/shm/r27/master/T21/verdict.md; the suite on 2939cc8
##     (/dev/shm/r27p/suite-2939cc8.log). Both green → push main (GitHub main = e083197 still), then APPLY from the
##     frozen tree when he is away + a SESSION RESTART (START §4) — the dwl fix (cold Super+N/V/U) needs a new dwl; the
##     warm notes window takes the new page at its next start. A FAIL → fix its must-fixes first, re-review.
## (2) THE KERNEL TRIAL (since 1 Nov 14:43, 7.2.13, snapshot 381 pinned): closes at the next start — only when he is
##     away, START §4's reboot way; then read fedokawaii-boot-good's journal — ledger r27-49-B3. Can go with (1)'s restart.
## (3) T46/T46b (F45 out Tue 3 Nov): after the release — vm-create f45 fresh from the released tree, vm-smoke f45, then
##     tools/vm-inject/f45-checks.sh f45; T46's pre-flight (tools/vm-preflight.sh) and the upgrade's WAIT (60 days).
## (4) T22: grid, cursor, footer, contrast BUILT and seen at three sizes (r27-22-grid, 83f1389); next: bug 10 in place
##     (r27-22-b10), the grill (kinds' colours at rest, "No items", the tabs row), the master. Learn's yazi chapter: still right.
## (5) T19m (b): pass 1 goes on; items 3–5 (24 px hit areas, JLREQ, the spacing scale, the optical centre, a
##     reduce-motion switch) with the next dwl batch (a session restart: only when he is away).
## (6) T53 goes on (the plan's list).
