> Historical notes from the cloud sessions. Paths (S=/tmp/claude-0/…, the Mac relay, /opt/dwltest) no longer exist — CLAUDE.md has the current procedures.

# Progress log (newest last)
- 10-21 20:40 torrra: background Prowlarr, healthcheck→first search, theme "fedokawaii", welcome screen — VERIFIED PC dark+light
- 10-21 20:50 nvim: transparent, no italics, 編 editor dashboard (look.lua); foot italic = upright face
- 10-21 20:55 verify herdr check: unset XDG_* (talked to the owner's own server) — VERIFIED PC
- 10-21 21:05 lib/common.sh: design-system script grammar (headings with stitch, rows, wrap) — VERIFIED PC verify window
- 10-21 21:12 full apply on PC: verify 251/252 (only my wlrctl/ydotool)
- 10-21 21:40 kit full re-shoot dark+light + apps (shots in $S/real/shots) — bar now superseded by v10
- 10-21 22:00 notes/ created; bar v10 generator + style.css + config written (not yet rendered)
- 10-21 22:05 installer agent launched (owns setup.sh/manifest/upstream/check/fedokawaii.sh/installer tests)
- 10-21 22:10 bar v10 rendered in kit dark+light: every gap measured exact (cells 8/8, clock 12/12, wings 12, layout 16; clock threads centred 959.5); r26 22:08 owner: free to patch/extend open-source software
- 10-21 22:20 dwl: animations rewritten frame-driven (eased out, 220 ms); unlock busy-cursor fix (motionnotify after the
  lock leaves the scene). FIRST deploy OOM-killed dwl on the PC (held screen kept asking frames → endless frame-done
  loop, ~20 GB): fixed (no frame asked while held), reproduced+verified in sandbox stress ($S/r26/stress.sh: RSS flat 13 MB,
  ASan clean). LESSON: always run $S/r26/stress.sh (headless dwl + 36 rapid foot opens/closes) before deploying dwl.
- 22:46 prompt dup fixed (3J after clear), 0/17 bursts; PC bashrc = repo; next: saver #189
- 22:53 saver: instant exit plus stitched design, verified on the PC; fresh session started (lock test)
- 22:55 design sweep: gallery in both themes; design-system motion and frame rules updated
- 23:02 r24 verify pass part 1 (14 items) + calc in/to fix
- 23:25 bar v11 live on PC; dwl fades live; vsync policy
- 23:32 waiting on agents; full kit shoot running (b57q5iqk2)
- r26 PUSHED 1b8b7b8 (from Mac /tmp/fkpush clone; base for next commit). PC repo = same tree, applied (apply30).
