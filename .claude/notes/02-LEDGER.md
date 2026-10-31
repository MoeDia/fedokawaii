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

