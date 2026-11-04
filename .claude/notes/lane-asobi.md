# lane-asobi — ASOBI 遊び (T33–T35 replaced, owner 4 Nov 17:38)

Started 4 Nov 17:42. Finish line 21:30.

## State (newest first)
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
