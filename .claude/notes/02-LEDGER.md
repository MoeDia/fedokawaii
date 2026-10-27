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
