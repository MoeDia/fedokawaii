# Round 25 plan (owner's 14 points of 2026-10-21 17:27) — work on the REAL PC (ssh helpers on the Mac VM:
# $HOME/pc 'cmd', $HOME/pcput FILE [dest], $HOME/pcget REMOTE NAME; deploy dir ~/Downloads/.fedokawaii-deploy-key)
# Repo: $M = scratchpad/review14/merge/repo. PC state: claude-awake.service (idle inhibitor) — REMOVE at end,
# with the ssh key, /etc/sudoers.d/90-claude-temp, sshd/firewall rule. PC restored to old fonts after proto.

## 1. Font (DECIDED)
- Sumi UI  = 東雲 Shinonome Gothic 16 Bold (JF Dot, public domain) @16px, cell 8, line 16 (asc 14 desc 2), caps 13 (rows 1-13)
- Sumi Term = Kappa 20 Bold (kterm face) @20px, cell 10, line 20 (asc 17 desc 3) — terminal grid unchanged (10x20, line-height 24)
- both: ASCII ~ \ ' " ` redrawn; one-cell signs hand-drawn in art/signs.txt; rest of narrow from Unifont JP 17.0.05 (bolder)
- tools/build-fonts.py (new; replaces build-ui-font.py, build-term-font.py) → committed configs/home/.local/share/fonts/SumiUI.ttf, SumiTerm.ttf
- sources: jfdotfont-20150527.zip (https://ftp.iij.ad.jp/pub/osdn.jp/users/8/8542/jfdotfont-20150527.zip), unifont_jp-17.0.05.otf (unifoundry)
- drop Fusion Pixel entirely (lib/upstream.sh install_fusion, sumi_ui, sumi_term, manifest, verify, report, tests, docs)
- proto finding: Pango fallback can pick another JF font for digits after a PUA icon — never install other dot fonts
- NEW UI GRID (16px): frame 2 · pad 16 · gap 8 · line 16 · row 24 · seal 26 (16 kanji, 4 air) · rule 25 · section 24 ·
  key 32 · tile ~120x84 (content 376) · meter 12 squares 13x10 gap 3 · bar height 31 (caps 13: 9 air each side)
- Sumi Icons: 12px art on a 16px em (upm 1600) so the bar/panel at 16px draw them 1:1; integer advances
- seal fonts (launcher heading), app seals (18→22, kanji 16), lock clock (display = 16×3=48 or 16×4=64), boot splash, GRUB font, handbook

## 2-14 (in order after 1)
2 Super+W: open on current wallpaper highlighted + "current" mark; 4-hour toggle description cut in preview
3 bar menus active w/o click (hover+keys) — focus on map; static rows (weather week) not selectable; sweep all
4 bar: no boxes/stitches; colour only: active = asagi; occupied ws = new green token; launcher active no red box; date kanji no box
5 notifications: alignment, spacing, icon vs text/lines
6 terminal: cursor gap to first entry line; new prompt; torii cut off · lock screen redesign (subtle wallpaper, no stretched box)
7 boot: black box + 2 flicks (plymouth.use-simpledrm then amdgpu takeover at 3.8s "REG_WAIT timeout optc401_disable_crtc";
  greetd at 7.6s) → amdgpu in initrd early KMS, drop use-simpledrm?, check GRUB gfx → kernel handoff
8 snapshots read-only boot
9 torra speed + exact theme; nvim full theme
10 audio quality max
11a update/repair/install clean runs · 11b launcher live calc results; notification shows final result copied
12 launcher icon click toggles (unify mouse/keyboard); menus needing a click before the mouse works
13 script TUI looks + optimize
14 sweep: bugs, perf, research

## Added 18:34 by owner
15 dwl animations: window open (stepped unroll down, kakejiku), close (roll up, saved buffer), workspace switch
   (stepped slide by direction), ~6 frames/100ms, no easing, input jumps to end, never fullscreen/games; measure frame times
16 at the very end: be the end user — open every app/menu on the real PC, watch logs, fix visual + script bugs
## Notes
- bar: removed sep1/sep2 + hem/stitch; lit = asagi (hover/active/selected ws), moegi occupied, urgent vermilion
- launcher: plan to REPLACE fuzzel with kawa-panel launcher (live calc, toggle, one tool) in item 11b/12; drop build-seal/appicons/fuzzel then
- item 2 cause candidate: state "default" vs rows "default" ok?; check on PC
- owner 18:36: animations must also FIX the artifacts/glitches of opening/closing many windows rapidly (relayout mid-animation,
  wrong-size first frames, text not re-laid): one animation per client, retarget on relayout, never show a frame before the
  client acked its configured size (hold/snapshot), stress test with 20 rapid footclient open/close + grim frame captures
- test tools installed on PC (remove at end): wlrctl, ydotool (+ydotool.service started), claude-awake.service, /tmp/px /tmp/sess
- PC kawa-panel restarted by me via /tmp/sess (not under keep)
17 owner 18:59: learn guide — a learning section on using AI fully, especially Claude Code, to a professional
   level that withstands time (principles over tool trivia: context, specs, verification, review, agents, safety)
   owner 19:02: it must have EXERCISES and explain the FUNDAMENTAL CONCEPTS (how models work: tokens, context
   window, attention to instructions, sampling, tools/agents, hallucination) — everything, in the learn guide's own style
## status 19:16
- 1 font: deployed to PC (fresh session via greetd initial_session trick, config restored); faces declared Bold (no synthetic
  bold smear: GTK button labels were smeared); fc-cache stale-cache fix (touch dir) in install_faces + theme.sh
- 2 done+verified on PC (fzf load:pos instead of start:pos race) · 3 verified hover w/o click · 4 verified bar
- 5 notify ok in kit · 6 new prompt (no stitch, no sky icon, time to minute, chevron one space; tilde 4 rows) verified on PC
- panel: line glyphs centred in LINE column (volume icon no longer touches name); keys pass gw
- TODO later: GioUnix.DesktopAppInfo deprecation warning in kawa-panel; greeter/lock on PC after update (setup installs kawa-greet)
## status 19:47
- bar v3 (kakejiku mount): obi.png ichimonji brocade, ensō on selected ws, maru-in seal on day, gold hishi; ICON_BAR_* = air-less
  "-bar" twins + 8px; all hishi gaps 28, groups 16, clock 8 — measured on PC (r25/gaps.py)
- learn guide Part VI (67–72) + appendix D merged; PDFs need rebuild (fonts + Part VI)
- boot: seamless/video= tried (no effect: REG_WAIT still, cage 144) → removed; plymouth.use-simpledrm removed on PC (repo TODO:
  lib/common.sh BOOT_ARGS, report BOOT-30, theme.sh comment, tests/installer/lib.sh:485, guide 11075/11124) — waiting user's boot watch
- device_commit_files CACHES by staged name: always use unique file names per deploy!
- PC: SSH_SERVER set to yes in ~/repos/fedokawaii/fedokawaii.conf and /usr/local/lib/fedokawaii/fedokawaii.conf — REVERT to no at the end; update ran rc=0, 2 verify fails: wlrctl/ydotool (mine), herdr starts (investigate)
