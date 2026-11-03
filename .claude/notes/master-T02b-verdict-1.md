VERDICT: PASS WITH CONDITIONS

# The master's review 1 of T02b (d132345) — 3 Nov 2026, Fable 5.1

## What I checked, and how
- The brief, run5.txt, run-asan.txt, summary.txt (/dev/shm/r27/master/T02b/); `git show d132345`
  (the commit, its message, every file); the live tree ~/.local/src/dwl/dwl.c read at every new
  symbol (monwhole 1737, wholearm 1761, wholesettle 1777, the hold in rendermon 3570-3595, the
  settle re-arm in commitlayersurfacenotify 1362-1366, holdmon/holddone 6112-6136, monkeep 1730,
  createmon's two kept paths 1960-1967 and 2005-2011, monpower 1685-1690, saverwake, saverinput,
  locksession 2766-2768, cleanupmon, updatemons, outputmgrapplyortest, powermgrsetmode).
- wlroots 0.20.2 source (/dev/shm/r27/wlr-src/wlroots-0.20.2): types/output/output.c:666-683
  (needs_enabled: mode/buffer on a disabled output fail the commit), types/wlr_output_layout.c:
  125-133 (output_update_global: no global without width/height), include/wlr/types/wlr_output.h:
  335 (wlr_output_create_global is public), output.c:309-310 (width/height set only by a mode),
  wlr_output_layout.c handle_output_commit (the global updated only on SCALE/TRANSFORM/MODE),
  output.c wlr_output_schedule_frame + schedule_frame_handle_idle_timer, types/scene/surface.c:376.
- Round trip: regenerated the patch from the tree in scratch exactly as tools/dwl-patch.sh does
  (git show HEAD:file vs the tree, diff -u -p) — byte-identical to src/dwl/dwl.patch.
- Re-ran the runtime test myself: `sudo bash tools/hotplug-test.sh` (card1, fenced env) —
  26/26, whole at 2-12 ms, shown settled at 142-152 ms, 7 layer commits, 0 F lines before, on all
  6 returns (/dev/shm/r27/master/T02b/own/run-master.txt). No /tmp/hotplug.* left behind.
- Ran tests/session/test_hotplug.sh in a fenced home: 9/0. `git status`: only the pre-existing
  `M tools/claude-loop.sh` — nothing of mine touched either repository.
- The real bar's config (configs/home/.config/waybar/config: ~30 custom exec modules, bash + one
  python; style.css:105 one 60 ms one-shot CSS animation), bin/kawa-display --hotplug (sleep 1,
  modes, kawa-wallpaper --restore), src/kawa-saver/kawa-saver.c (surfaces only for outputs present
  at its start, lines 955-966; tick-driven at pace 80 ms, not frame-driven).
- The installed binary: `ls -l /usr/local/bin/dwl` 02:29:04 516480 B vs ~/.local/src/dwl/dwl
  06:30:44 518776 B, `cmp` differs; /usr/local/bin/start-dwl:112 `DWL=/usr/local/bin/dwl`.

## Judgements the brief asked for
1. The wlroots constraint is real (lines verified). The one public bypass — dwl calling
   wlr_output_create_global() itself for the kept-dark output (which is outside the layout, so the
   layout would not fight it) — gives every client a wl_output whose mode is 0 x 0 and no xdg_output
   (not in the layout) and dwl would configure layer surfaces 0 x 0; rejecting that is sound. What
   the ledger does not weigh is the root-cause alternative (finding 6 below).
2. Correctness: a client hold cannot cut the whole hold short (holdmon:6114 returns while
   `holding`); wholesettle only ever lengthens the shared timer (min(left,100), the cap kept);
   wholearm's `holding = 0` is what lets it replace the 60 ms layout hold updatemons armed first;
   a drop mid-hold is safe (cleanupmon: monkeep reads the layers before they are destroyed, the
   timer is removed before free; ASan clean); multi-monitor is per Monitor; a dead waybar/swaybg
   ends at the cap; the per-frame cost outside a hold is two int tests. Found: one light path
   without the hold (3), the settle counting the wrong surfaces and unthrottled callbacks (4).
3. 100 ms / 1 s are guesses, acknowledged as LEFT in the ledger (5).
4. The test proves, for a 2-module synthetic bar: every return held, whole reached, no dwl frame
   before the shown one, the shown one after 100 ms of layer quiet, the late module in by
   construction (40 ms < 100 ms), the shot 2.5 s later whole. It does not prove: the real bar's
   modules in the first frame (LEFT), the locked path (2), the live PC (1). wlroots' blank
   modeset buffer is the first thing on the glass; "0 frames drawn before" is dwl's F lines
   only — the ledger and the design row say so; keep saying so.
5. Not over-engineered (~120 lines on the existing hold). Missed: 1, 2, 3, 6.

## Findings

### must-fix
1. **Not installed — "live at his next session" is false as the PC stands.** /usr/local/bin/dwl
   is the 02:29 build (516480 B); the T02b binary is only in ~/.local/src/dwl (06:30, 518776 B);
   start-dwl runs /usr/local/bin/dwl. `fedokawaii apply` was not run after d132345 (theme.sh:692
   dwl_current would rebuild). Scenario: he logs out and in tonight, the LG drops its line, a
   key — the bar is built in front of him exactly as reported, while the ledger says fixed.
   Fix: run apply (and say so in the ledger with the binary's size/time), or strike "live at
   his next session" until it is.
2. **The locked path is claimed, not proven.** Commit message and ledger: "locked, the lock too";
   wholearm:1768-1769 sets lockhold, rendermon:3580-3581 waits for the lock surface's buffer. No
   test runs a session-lock client (tools/hotplug-test.sh section 4 has swaybg + waybar only;
   test_hotplug greps). After T20 (lock → screens off after 5 s) this is his daily wake: lock,
   dark, the LG drops its line at ~3.5 min, back dark, a key next morning → monpower → wholearm
   with locked. Unknowns: gtklock's lock surface on an output that appears while locked, its
   first frame's time against the 1 s cap, the bar's wait under it. Fix: a lock client on the
   test dwl (gtklock unfenced as the greeter tests do, or a small ext-session-lock client in
   tools/), asserting D held/whole/shown settled with the lock surface buffered first, 0 F
   before, and a shot that shows the lock — then the "locked" claim stands.

### should-fix
3. **One light path lights without the hold.** outputmgrapplyortest (~line +57 of the function):
   `if (m->fresh && wlr_output->enabled) { m->fresh = 0; m->wakemode = NULL; spawn kawa-display }`
   — no wholearm. Any wlr-output-management client enabling the kept-dark output (wlr-randr
   --on, a future kawa-display mode, kanshi) shows the bar being built. Today's tools do not take
   it (kawa-display waits while dark; kawa-lock uses wlopm), so should-fix: call wholearm(m)
   there as createmon:2010 and monpower:1688 do, and add it to the runtime test (a `wlr-randr
   --on` return as the 7th).
4. **The settle counts surfaces monwhole ignores, and held frame callbacks are unthrottled.**
   commitlayersurfacenotify:1362-1366 re-arms wholesettle for every layer-surface commit on the
   monitor (a notice, a menu, the OSD, a saver — not only the background and exclusive-zone
   surfaces the hold waits for), and the commit check `committed == 0` comes after it, so even a
   frame-only commit counts. rendermon:3586-3595 answers every layer surface's frame callbacks
   on every frame event, and wlroots sends a frame event at idle whenever no flip is pending
   (output.c wlr_output_schedule_frame → schedule_frame_handle_idle_timer; scene/surface.c:376
   schedules one on each commit with callbacks). Scenario: a layer client that redraws on each
   frame callback (a CSS animation in waybar — today only the 60 ms kawa-stamp, but the planned
   antenna/joystick/download icons if done in CSS; any GTK spinner) spins at CPU speed for the
   whole hold and the picture always lands "at the cap", never settled. Fix: in the commit
   handler re-arm only for `i == BACKGROUND || exclusive_zone > 0` and `!l->saver`; in the hold
   answer frame callbacks at most once per m->refresh_ms (or on a refresh-paced timer).
5. **100 ms and 1 s are unmeasured.** The real bar starts ~30 exec scripts at once (bash; one
   python); the 100 ms must bracket the gaps of that burst, and a slow first answer (weather,
   nowplaying waiting on a player) fills in front of him after the reveal. The LG's own time from
   signal to picture (the thing the 1 s cap hides behind) is unmeasured. The ledger marks both
   LEFT — keep it a condition: measure the L-line burst live (SIGUSR2 frame log), set
   WHOLE_SETTLE_MS from it with the number in the ledger, and record what the cap hid if any
   return is "at the cap".
6. **The root-cause alternative is not weighed.** The problem exists because the LG's deep
   standby drops the hot-plug line and wlroots destroys the output. The test itself keeps card1's
   connector forced; the same for the live card — `video=HDMI-A-1:e` with `drm.edid_firmware`
   from the LG's captured EDID (lib/common.sh BOOT_ARGS) — would keep the output, its layer
   surfaces, its lock surface and T02's state alive through the drop: nothing rebuilt, no hold
   needed for this case. Its own risks (the HDMI link after the monitor's standby — at 1080p144
   the pixel clock is under 340 MHz, no SCDC re-set needed, but measure; plymouth/boot on a
   forced connector; a real unplug) make it a measured decision, not a given. The ledger's
   "closed by wlroots itself" describes one approach's closure, not the problem's: evaluate it
   on the PC, decide, and write the decision down either way.

### nit
7. dwl.c:727-744 (the frame-log header) lists F H P K B M W U A C and not the new D and L lines;
   tools/framestat.py skips them (fine) but its doc does not name them.
8. monpower:1679 and createmon:1968 leave wlr_output_commit_state unchecked; a failed enable
   leaves `wholehold = 1` with no timer (holdmon returns on `!enabled`). Self-heals on the next
   light (holding stays 0, nothing held) but frame callbacks are double-answered meanwhile;
   wholearm should bail when holdmon did not arm.
9. rendermon answers the lock surface's frame callbacks twice in one call when lockhold and
   wholehold are both set (3573-3576, 3592-3593): a no-op second time.
10. WHOLE_BAR means "any exclusive-zone surface": a monitor that had only a notice with a zone
    (no bar) when it dropped waits the full second for one that never returns. Bounded.
11. The "shown" frame is inferred (settled ⇒ whole reached and 100 ms quiet), not captured;
    acceptable for the synthetic bar, and the reason the live L-line measurement (5) matters.

## Verified sound (for the record)
The design premise — a DPMS'd output keeps its place and wl_output — holds in the source
(output.c sets width/height only with a mode; the layout touches the global only on
SCALE/TRANSFORM/MODE; updatemons keeps asleep outputs in the layout, `if (m->asleep) continue`).
The kept `whole` survives a drop mid-hold (monkeep:1730). The round trip patch == tree. The
runtime test is reproducible (my run matches theirs to the millisecond). ASan clean.
