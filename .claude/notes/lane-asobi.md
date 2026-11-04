# lane-asobi — ASOBI 遊び (T33–T35 replaced, owner 4 Nov 17:38)

Started 4 Nov 17:42. Finish line 21:30.

## State (newest first)
- 20:16 FORCED REBOOT by main about 20:25 (PID 1 and the user manager stuck in D since 19:51, cause unknown; main said nothing points at my IOWeight change, and it is gone from the code anyway). Everything committed and pushed. NEXT after the boot, in this order: (1) `sudo bash tools/asobi-step.sh asobi_system` then `asobi_drop` (the drop folder becomes a subvolume); install bin/kawa-asobi and bin/kawa-display into ~/.local/bin; (2) re-prove on the real screen, notice first: `sudo env ASOBI_PROOF_STACK=~/.cache/r27-asobi/elfu bash tools/asobi-proof.sh vt2` (frozen game by the kernel's freezer, thaw, Steam closed for Bottles: the 19:45 run failed there, the fixes are untested), then `vt`; (3) finish the sweep's tests (the sweep agent's edits are committed as they stood, its report is the next lines of this file if it arrived; re-run tests/installer, tests/static, tests/session, tests/menus, tests/status), add tests/installer/test_asobi.sh (lib/asobi.sh in the fake machine: stubs useradd, groupadd, flatpak exist), report rows for the world; (4) VM r27-asobi proof again from a frozen tree (~/.cache/r27-asobi/vm-proof.sh; the tree at ~/.cache/r27-asobi/tree is a git worktree: `git worktree remove` it, or update it): the Steam move must now happen there; (5) a Windows program through Bottles on the real screen without sign-in. Scratch scripts: ~/.cache/r27-asobi/. Evidence copied out of /dev/shm: ~/.cache/r27-asobi/evidence-1920, evidence-2000.
- 20:06 real-screen proof `tools/asobi-proof.sh vt` passed at 19:20 (evidence below); VM proof over a built desktop: apply exit 0, walls + reset 61 checks held. Second real-screen proof (`vt2`: frozen game, thaw, Steam closed for Bottles) found real bugs, fixed in code, NOT yet re-proved: PID 1 has been in D state since 19:51 (cause unknown, main told), so no VT test now.
- Built on this PC by tools/asobi-step.sh, nothing by hand: user asobi (uid 1001), /home/asobi subvolume, /home/.asobi/{snapshots,drop}, ~/Drop link, Steam 1.0.0.87 and Bottles 67.5 per user, snapshot clean, his games reflink-copied into the world (6.8 GB, no room taken).

## Decisions (mine; the owner asked me to decide)
- The TUI is `kawa-asobi`, not kawa-play: kawa-play is already the mpv opener.
- One key back = Super+G, in gamescope's own keymap (XF86Switch_VT_1 under Super, /etc/xkb/rules/kawa-asobi): no program reads the keyboard. Source: gamescope src/wlserver.cpp wlserver_handle_key, XKB_DEFAULT_* in wlserver_update_keymap.
- Behind the desktop: with a game running the world is frozen (kernel cgroup freezer on app.slice), Steam alone goes on (a download finishes).
- Network wall while the world runs (nft table kawa_asobi): Internet yes; no loopback service of anyone else, no RFC1918/link-local. Not in the brief; "locked-down" needs it: Prowlarr, Ollama, fk-remote all listen on this machine.
- Input wall while the world runs: /run/udev/rules.d/60-kawa-asobi.rules ignores virtual input devices in libinput, because steam-devices gives the active seat /dev/uinput and a kept fd could type into the desktop afterwards.
- Bottles is a second face (kawa-asobi-bottles.service, its own gamescope without -e, Steam closes first): gamescope -e focuses only what Steam's own process tree starts, and Flatpak Steam cannot start a host Flatpak without flatpak-spawn --host, which would void its sandbox.
- steam-devices stays Fedora's own package (built from ValveSoftware/steam-devices, `rpm -qi`). Flathub wiki: udev rules must be on the host.
- FreeSync: Steam writes GAMESCOPE_VRR_ENABLED=0 over --adaptive-sync; kawa-asobi-world holds it at 1 (xprop -spy). Proved: VRR_ENABLED on from DRM (kawa-display --vrr).

## Evidence
- 19:20 vt proof, all held: gamescope on /dev/dri/card0, "1920x1080": 144 (debugfs state), VRR_ENABLED on, GameMode active, card at high, seat session Active=yes VTNr=8, /dev/uinput writable only while in front, sound moved to the world and back, Super+G through a uinput keyboard, Steam's first picture 11 s after the key. ~/.cache/r27-asobi/evidence-1920/ (vt-4.log, world.png, vrr.txt).
- VM r27-asobi (clone of f44, 4 GB, port 2294), apply over state built with the tree at 51c6f9a: apply exit 0, steam and mangohud gone, flatpak, gamescope, gamemode in, walls + reset all held. ~/.cache/r27-asobi/vm/. NOT re-run since: the Steam move ran before the user existed there (fixed: setup.sh heal order), so ~/.local/share/Steam stayed.
- Bar after a VT switch: waybar 0.15 can hang for good tearing down a bar (pthread_cancel + join in SleeperThread, main thread in Custom::~Custom, the joined thread stuck on a lock in __malloc_arena_thread_freeres; stacks ~/.cache/r27-asobi/vtplay/out4/stack.txt). Reproduced offscreen. Fix: bar_unstuck in bin/kawa-display --hotplug; tools/regress/bar-cycles.sh held over 30 cycles (bar restarted 3 times). It restarts a stuck bar, it does not remove the hang.

## The sweep agent's report (20:17), still true of the tree
Passed before the reboot: test_hush 21, test_report_rows 265, test_manifest 68, test_verify 184, test_setup 232, test_setup_wait 72, test_downloads 59, and test_audio, configs, power, quick, front, copy, autostart, bar, clicks, state, cursor, keybinds_meaning, crashnote, startdwl, units, config, tidy, launcher 268, calc, deps, notices, tools, pipefail, noellipsis, masters, dwlconfig, pointers, barreload. Its three findings are fixed by me but not re-run: test_conf (CONF_RETIRED has STEAM now), test_menu (the asobi row guarded by $desk), test_syntax (shellcheck clean by hand). Not Steam's: test_generated, test_design_doc (art/crests.txt missing, main's), test_contrast, test_bargaps. NOT RUN, must run after the boot: tests/installer/test_asobi.sh (new, never run), test_state_keep, test_theme, test_theme_parts, test_torture, test_report, test_conf_scripts, test_upstream; and because the harness changed (memory: harness change → full area re-run) test_afterdnf, test_check, test_clean, test_common, test_guard, test_hardware, test_pace, test_setup_hw, test_theme_users, test_update_flow, test_upgrade, test_upkeep, test_vm_tools.
For main: src/dwl/dwl.patch lines 1494 and 2567 still name Steam in comments (yours, not touched).

## Not done yet
- Re-prove vt2 once PID 1 answers. Real game: the owner must sign in to Steam, I have no credentials and his rule forbids me typing a password (19:27 he wrote "test it yourself"; I tell him this plainly). A Windows program through Bottles without sign-in: to do.
- tests/installer for lib/asobi.sh (stubs arriving from the sweep agent); the Steam/guide sweep of docs/fedokawaii-guide.md outside chapter 21; report rows for the world.

## What main must do to merge and apply
- Filled in when done. Known already: re-run tools/build-icons.py after merging (koma, tokkuri appended to art/icons.txt; codepoints depend on order), lane-learning's syllabus line for chapter 18 must be renamed (chapter 18 asobi | ASOBI: the play world | koma | needs 4), and the build-icons crests step fails on main already (art/crests.txt missing; not mine).

## Open questions for the owner
- Steam sign-in is his (see Not done yet).

## OWNER 18:15 — memory
The PC is at 26 of 31 GB RAM with 21 agents. Your VMs: at most 4 GB RAM each, shut them down as soon as a test ends, never two of yours at once.

## OWNER ANSWER 2026-11-04 19:04 — to your question «2026-11-04 18:20 — question from lane-asobi»
test it yourself no worries the screen is yours

## OWNER ANSWER 2026-11-04 19:27 — to your question «2026-11-04 19:21 — question from lane-asobi»
you test it yourself fully deal with it

## OWNER 21:30 — YOUR user@.service.d drop-in broke the owner's login services (moved to /etc/systemd/off-by-fix5). Sandboxing only in user@1001.service.d. Prove user@1000 starts after every change.

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.
