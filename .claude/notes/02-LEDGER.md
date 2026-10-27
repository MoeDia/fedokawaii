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
